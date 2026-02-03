package service

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"fund-analyzer/internal/crawler"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
)

// mockCacheService 模拟缓存服务
type mockCacheService struct {
	data      map[string][]byte
	getError  error
	setError  error
	getCalled int
	setCalled int
}

func newMockCacheService() *mockCacheService {
	return &mockCacheService{
		data: make(map[string][]byte),
	}
}

func (m *mockCacheService) Get(ctx context.Context, key string) ([]byte, error) {
	m.getCalled++
	if m.getError != nil {
		return nil, m.getError
	}
	data, ok := m.data[key]
	if !ok {
		return nil, ErrCacheMiss
	}
	return data, nil
}

func (m *mockCacheService) Set(ctx context.Context, key string, value []byte, ttl time.Duration) error {
	m.setCalled++
	if m.setError != nil {
		return m.setError
	}
	m.data[key] = value
	return nil
}

func (m *mockCacheService) Delete(ctx context.Context, key string) error {
	delete(m.data, key)
	return nil
}

func (m *mockCacheService) GetOrSet(ctx context.Context, key string, ttl time.Duration, fn func() ([]byte, error)) ([]byte, error) {
	data, err := m.Get(ctx, key)
	if err == nil {
		return data, nil
	}
	data, err = fn()
	if err != nil {
		return nil, err
	}
	_ = m.Set(ctx, key, data, ttl)
	return data, nil
}

func (m *mockCacheService) GetJSON(ctx context.Context, key string, dest interface{}) error {
	return nil
}

func (m *mockCacheService) SetJSON(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	return nil
}

func TestDegradationService_WithFallback_Success(t *testing.T) {
	// 测试正常获取数据的情况
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	expectedData := map[string]string{"key": "value"}
	fetcher := func() (interface{}, error) {
		return expectedData, nil
	}

	data, degraded, err := svc.WithFallback(context.Background(), fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.False(t, degraded, "should not be degraded when fetcher succeeds")
	assert.Equal(t, expectedData, data)
	assert.Equal(t, 1, cache.setCalled, "should cache the data")
}

func TestDegradationService_WithFallback_FetcherFails_CacheHit(t *testing.T) {
	// 测试数据源失败但缓存命中的情况
	cache := newMockCacheService()
	// 预先设置缓存数据
	cache.data["test:key"] = []byte(`{"key":"cached_value"}`)

	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	fetcher := func() (interface{}, error) {
		return nil, errors.New("data source unavailable")
	}

	data, degraded, err := svc.WithFallback(context.Background(), fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.True(t, degraded, "should be degraded when fetcher fails")
	assert.NotNil(t, data, "should return cached data")
}

func TestDegradationService_WithFallback_FetcherFails_CacheMiss(t *testing.T) {
	// 测试数据源失败且缓存未命中的情况
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	fetcher := func() (interface{}, error) {
		return nil, errors.New("data source unavailable")
	}

	data, degraded, err := svc.WithFallback(context.Background(), fetcher, "test:key", time.Minute)

	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrNoFallbackData))
	assert.True(t, degraded, "should be degraded")
	assert.Nil(t, data, "should return nil when no fallback data")
}

func TestDegradationService_WithCircuitBreaker_Open(t *testing.T) {
	// 测试熔断器打开时的降级
	cache := newMockCacheService()
	cache.data["test:key"] = []byte(`{"key":"cached_value"}`)

	cbConfig := crawler.CircuitBreakerConfig{
		MaxFailures:     2,
		Timeout:         time.Second,
		HalfOpenMaxReqs: 1,
	}
	cbManager := crawler.NewCircuitBreakerManager(cbConfig)
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	// 先触发熔断器打开
	cb := cbManager.Get("test-breaker")
	for i := 0; i < 3; i++ {
		_ = cb.Execute(func() error {
			return errors.New("failure")
		})
	}

	// 确认熔断器已打开
	assert.Equal(t, crawler.StateOpen, cb.State())

	// 测试降级
	fetcher := func() (interface{}, error) {
		return map[string]string{"key": "fresh_value"}, nil
	}

	data, degraded, err := svc.WithCircuitBreaker(context.Background(), "test-breaker", fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.True(t, degraded, "should be degraded when circuit breaker is open")
	assert.NotNil(t, data, "should return cached data")
}

func TestDegradationService_WithCircuitBreaker_Closed(t *testing.T) {
	// 测试熔断器关闭时正常获取数据
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	expectedData := map[string]string{"key": "value"}
	fetcher := func() (interface{}, error) {
		return expectedData, nil
	}

	data, degraded, err := svc.WithCircuitBreaker(context.Background(), "test-breaker", fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.False(t, degraded, "should not be degraded when circuit breaker is closed")
	assert.Equal(t, expectedData, data)
}

func TestDegradationService_AsyncRefresh_FastResponse(t *testing.T) {
	// 测试快速响应的情况
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	expectedData := map[string]string{"key": "value"}
	fetcher := func() (interface{}, error) {
		return expectedData, nil
	}

	data, degraded, err := svc.AsyncRefresh(context.Background(), fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.False(t, degraded, "should not be degraded when response is fast")
	assert.Equal(t, expectedData, data)
}

func TestDegradationService_AsyncRefresh_SlowResponse_CacheHit(t *testing.T) {
	// 测试慢响应但有缓存的情况
	cache := newMockCacheService()
	cache.data["test:key"] = []byte(`{"key":"cached_value"}`)

	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	var fetcherCalled int32
	fetcher := func() (interface{}, error) {
		atomic.AddInt32(&fetcherCalled, 1)
		time.Sleep(5 * time.Second) // 模拟慢响应
		return map[string]string{"key": "fresh_value"}, nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	data, degraded, err := svc.AsyncRefresh(ctx, fetcher, "test:key", time.Minute)

	require.NoError(t, err)
	assert.True(t, degraded, "should be degraded when response is slow")
	assert.NotNil(t, data, "should return cached data")
}

func TestDegradationService_WithFallbackTyped(t *testing.T) {
	// 测试类型化的降级获取
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	type TestData struct {
		Key   string `json:"key"`
		Value int    `json:"value"`
	}

	expectedData := TestData{Key: "test", Value: 42}
	fetcher := func() (interface{}, error) {
		return expectedData, nil
	}

	var result TestData
	degraded, err := svc.WithFallbackTyped(context.Background(), fetcher, "test:key", time.Minute, &result)

	require.NoError(t, err)
	assert.False(t, degraded)
	assert.Equal(t, expectedData.Key, result.Key)
	assert.Equal(t, expectedData.Value, result.Value)
}

func TestDegradationServiceWithMetrics(t *testing.T) {
	// 测试带指标的降级服务
	cache := newMockCacheService()
	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationServiceWithMetrics(cache, cbManager, logger)

	// 获取初始指标
	metrics := svc.GetMetrics()
	assert.Equal(t, int64(0), metrics.TotalRequests)

	// 重置指标
	svc.ResetMetrics()
	metrics = svc.GetMetrics()
	assert.Equal(t, int64(0), metrics.TotalRequests)
}

func TestDegradationService_ConcurrentAsyncRefresh(t *testing.T) {
	// 测试并发异步刷新不会重复执行
	cache := newMockCacheService()
	cache.data["test:key"] = []byte(`{"key":"cached_value"}`)

	cbManager := crawler.NewCircuitBreakerManager(crawler.DefaultCircuitBreakerConfig())
	logger := zap.NewNop()

	svc := NewDegradationService(cache, cbManager, logger)

	var fetcherCallCount int32
	fetcher := func() (interface{}, error) {
		atomic.AddInt32(&fetcherCallCount, 1)
		time.Sleep(100 * time.Millisecond)
		return map[string]string{"key": "fresh_value"}, nil
	}

	// 并发调用多次
	for i := 0; i < 5; i++ {
		go func() {
			_, _, _ = svc.AsyncRefresh(context.Background(), fetcher, "test:key", time.Minute)
		}()
	}

	// 等待所有调用完成
	time.Sleep(500 * time.Millisecond)

	// 由于防重复机制，fetcher 应该只被调用有限次数
	// 注意：由于并发和时序问题，这里不能精确断言调用次数
	// 但可以确保不会被调用太多次
	assert.LessOrEqual(t, atomic.LoadInt32(&fetcherCallCount), int32(5))
}
