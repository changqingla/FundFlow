package service

import (
	"context"
	"encoding/json"
	"errors"
	"sync"
	"time"

	"fund-analyzer/internal/crawler"

	"go.uber.org/zap"
)

var (
	// ErrNoFallbackData 没有可用的降级数据
	ErrNoFallbackData = errors.New("no fallback data available")
	// ErrFetcherFailed 数据获取失败
	ErrFetcherFailed = errors.New("fetcher failed")
)

// DegradationResult 降级结果
type DegradationResult struct {
	Data       interface{} // 返回的数据
	Degraded   bool        // 是否降级
	FromCache  bool        // 是否来自缓存
	Error      error       // 错误信息（如果有）
}

// DegradationService 降级服务接口
type DegradationService interface {
	// WithFallback 带降级的数据获取
	// fetcher: 数据获取函数
	// cacheKey: 缓存键
	// ttl: 缓存过期时间
	// 返回: 数据、是否降级、错误
	WithFallback(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error)

	// WithFallbackTyped 带类型的降级数据获取（泛型版本）
	// 用于需要类型安全的场景
	WithFallbackTyped(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration, dest interface{}) (bool, error)

	// WithCircuitBreaker 带熔断器的降级数据获取
	// breakerName: 熔断器名称
	WithCircuitBreaker(ctx context.Context, breakerName string, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error)

	// AsyncRefresh 异步刷新缓存
	// 当数据源响应缓慢时，先返回缓存数据，然后异步刷新
	AsyncRefresh(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error)
}

// degradationService 降级服务实现
type degradationService struct {
	cache          CacheService
	cbManager      *crawler.CircuitBreakerManager
	logger         *zap.Logger
	asyncRefreshMu sync.Map // 用于防止重复的异步刷新
}

// NewDegradationService 创建降级服务
func NewDegradationService(cache CacheService, cbManager *crawler.CircuitBreakerManager, logger *zap.Logger) DegradationService {
	return &degradationService{
		cache:     cache,
		cbManager: cbManager,
		logger:    logger,
	}
}

// WithFallback 带降级的数据获取
func (s *degradationService) WithFallback(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error) {
	// 1. 尝试从数据源获取新数据
	data, err := fetcher()
	if err == nil {
		// 成功获取数据，更新缓存
		if cacheErr := s.cacheData(ctx, cacheKey, data, ttl); cacheErr != nil {
			s.logger.Warn("Failed to cache data",
				zap.String("cacheKey", cacheKey),
				zap.Error(cacheErr),
			)
		}
		return data, false, nil
	}

	// 2. 数据源获取失败，记录日志
	s.logger.Warn("Fetcher failed, attempting fallback to cache",
		zap.String("cacheKey", cacheKey),
		zap.Error(err),
	)

	// 3. 尝试从缓存获取降级数据
	cachedData, cacheErr := s.getCachedData(ctx, cacheKey)
	if cacheErr == nil && cachedData != nil {
		s.logger.Info("Degradation: returning cached data",
			zap.String("cacheKey", cacheKey),
		)
		return cachedData, true, nil
	}

	// 4. 缓存也没有数据，返回错误
	s.logger.Error("Degradation failed: no cached data available",
		zap.String("cacheKey", cacheKey),
		zap.Error(err),
	)
	return nil, true, ErrNoFallbackData
}

// WithFallbackTyped 带类型的降级数据获取
func (s *degradationService) WithFallbackTyped(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration, dest interface{}) (bool, error) {
	data, degraded, err := s.WithFallback(ctx, fetcher, cacheKey, ttl)
	if err != nil {
		return degraded, err
	}

	// 将数据转换为目标类型
	jsonData, err := json.Marshal(data)
	if err != nil {
		return degraded, err
	}

	if err := json.Unmarshal(jsonData, dest); err != nil {
		return degraded, err
	}

	return degraded, nil
}

// WithCircuitBreaker 带熔断器的降级数据获取
func (s *degradationService) WithCircuitBreaker(ctx context.Context, breakerName string, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error) {
	cb := s.cbManager.Get(breakerName)

	// 检查熔断器状态
	if cb.State() == crawler.StateOpen {
		s.logger.Warn("Circuit breaker is open, returning cached data",
			zap.String("breakerName", breakerName),
			zap.String("cacheKey", cacheKey),
		)
		// 熔断器打开，直接返回缓存数据
		cachedData, err := s.getCachedData(ctx, cacheKey)
		if err == nil && cachedData != nil {
			return cachedData, true, nil
		}
		return nil, true, ErrNoFallbackData
	}

	// 使用熔断器执行
	var data interface{}
	var fetchErr error

	err := cb.Execute(func() error {
		data, fetchErr = fetcher()
		return fetchErr
	})

	if err == nil {
		// 成功获取数据，更新缓存
		if cacheErr := s.cacheData(ctx, cacheKey, data, ttl); cacheErr != nil {
			s.logger.Warn("Failed to cache data",
				zap.String("cacheKey", cacheKey),
				zap.Error(cacheErr),
			)
		}
		return data, false, nil
	}

	// 熔断器返回错误（可能是熔断打开或执行失败）
	if errors.Is(err, crawler.ErrCircuitOpen) {
		s.logger.Warn("Circuit breaker opened during execution",
			zap.String("breakerName", breakerName),
			zap.String("cacheKey", cacheKey),
		)
	} else {
		s.logger.Warn("Fetcher failed with circuit breaker",
			zap.String("breakerName", breakerName),
			zap.String("cacheKey", cacheKey),
			zap.Error(err),
		)
	}

	// 尝试返回缓存数据
	cachedData, cacheErr := s.getCachedData(ctx, cacheKey)
	if cacheErr == nil && cachedData != nil {
		s.logger.Info("Degradation: returning cached data after circuit breaker failure",
			zap.String("breakerName", breakerName),
			zap.String("cacheKey", cacheKey),
		)
		return cachedData, true, nil
	}

	return nil, true, ErrNoFallbackData
}

// AsyncRefresh 异步刷新缓存
// 当数据源响应缓慢时，先返回缓存数据，然后异步刷新
func (s *degradationService) AsyncRefresh(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) (interface{}, bool, error) {
	// 1. 先尝试从缓存获取数据
	cachedData, cacheErr := s.getCachedData(ctx, cacheKey)
	hasCachedData := cacheErr == nil && cachedData != nil

	// 2. 创建一个带超时的 context 用于快速获取
	fastCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	// 3. 尝试快速获取新数据
	dataChan := make(chan interface{}, 1)
	errChan := make(chan error, 1)

	go func() {
		data, err := fetcher()
		if err != nil {
			errChan <- err
		} else {
			dataChan <- data
		}
	}()

	select {
	case data := <-dataChan:
		// 快速获取成功
		if cacheErr := s.cacheData(ctx, cacheKey, data, ttl); cacheErr != nil {
			s.logger.Warn("Failed to cache data",
				zap.String("cacheKey", cacheKey),
				zap.Error(cacheErr),
			)
		}
		return data, false, nil

	case err := <-errChan:
		// 获取失败
		s.logger.Warn("Fetcher failed",
			zap.String("cacheKey", cacheKey),
			zap.Error(err),
		)
		if hasCachedData {
			return cachedData, true, nil
		}
		return nil, true, ErrNoFallbackData

	case <-fastCtx.Done():
		// 超时，返回缓存数据并启动异步刷新
		if hasCachedData {
			s.logger.Info("Fetcher timeout, returning cached data and starting async refresh",
				zap.String("cacheKey", cacheKey),
			)
			// 启动异步刷新（防止重复刷新）
			s.startAsyncRefresh(ctx, fetcher, cacheKey, ttl)
			return cachedData, true, nil
		}

		// 没有缓存数据，等待获取完成
		select {
		case data := <-dataChan:
			if cacheErr := s.cacheData(ctx, cacheKey, data, ttl); cacheErr != nil {
				s.logger.Warn("Failed to cache data",
					zap.String("cacheKey", cacheKey),
					zap.Error(cacheErr),
				)
			}
			return data, false, nil
		case err := <-errChan:
			return nil, true, err
		case <-ctx.Done():
			return nil, true, ctx.Err()
		}
	}
}

// startAsyncRefresh 启动异步刷新
func (s *degradationService) startAsyncRefresh(ctx context.Context, fetcher func() (interface{}, error), cacheKey string, ttl time.Duration) {
	// 使用 sync.Map 防止重复刷新
	if _, loaded := s.asyncRefreshMu.LoadOrStore(cacheKey, true); loaded {
		// 已经有刷新任务在进行
		return
	}

	go func() {
		defer s.asyncRefreshMu.Delete(cacheKey)

		// 创建新的 context，不受原 context 取消影响
		refreshCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		data, err := fetcher()
		if err != nil {
			s.logger.Warn("Async refresh failed",
				zap.String("cacheKey", cacheKey),
				zap.Error(err),
			)
			return
		}

		if cacheErr := s.cacheData(refreshCtx, cacheKey, data, ttl); cacheErr != nil {
			s.logger.Warn("Failed to cache async refreshed data",
				zap.String("cacheKey", cacheKey),
				zap.Error(cacheErr),
			)
			return
		}

		s.logger.Info("Async refresh completed",
			zap.String("cacheKey", cacheKey),
		)
	}()
}

// cacheData 缓存数据
func (s *degradationService) cacheData(ctx context.Context, key string, data interface{}, ttl time.Duration) error {
	jsonData, err := json.Marshal(data)
	if err != nil {
		return err
	}
	return s.cache.Set(ctx, key, jsonData, ttl)
}

// getCachedData 获取缓存数据
func (s *degradationService) getCachedData(ctx context.Context, key string) (interface{}, error) {
	data, err := s.cache.Get(ctx, key)
	if err != nil {
		return nil, err
	}

	var result interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return result, nil
}

// DegradationMetrics 降级指标（用于监控）
type DegradationMetrics struct {
	TotalRequests     int64
	DegradedRequests  int64
	CacheHits         int64
	CacheMisses       int64
	CircuitBreakerHits int64
}

// DegradationServiceWithMetrics 带指标的降级服务
type DegradationServiceWithMetrics struct {
	DegradationService
	metrics *DegradationMetrics
	mu      sync.RWMutex
}

// NewDegradationServiceWithMetrics 创建带指标的降级服务
func NewDegradationServiceWithMetrics(cache CacheService, cbManager *crawler.CircuitBreakerManager, logger *zap.Logger) *DegradationServiceWithMetrics {
	return &DegradationServiceWithMetrics{
		DegradationService: NewDegradationService(cache, cbManager, logger),
		metrics:            &DegradationMetrics{},
	}
}

// GetMetrics 获取降级指标
func (s *DegradationServiceWithMetrics) GetMetrics() DegradationMetrics {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return *s.metrics
}

// ResetMetrics 重置指标
func (s *DegradationServiceWithMetrics) ResetMetrics() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.metrics = &DegradationMetrics{}
}
