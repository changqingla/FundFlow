package middleware

import (
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func init() {
	gin.SetMode(gin.TestMode)
}

func TestTokenBucketLimiter_Allow(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             5,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	key := "test-key"

	// 应该允许前 5 个请求（突发容量）
	for i := 0; i < 5; i++ {
		assert.True(t, limiter.Allow(key), "Request %d should be allowed", i+1)
	}

	// 第 6 个请求应该被拒绝（令牌耗尽）
	assert.False(t, limiter.Allow(key), "Request 6 should be denied")
}

func TestTokenBucketLimiter_AllowN(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             10,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	key := "test-key"

	// 一次请求 5 个令牌
	assert.True(t, limiter.AllowN(key, 5), "Should allow 5 tokens")

	// 再请求 5 个令牌
	assert.True(t, limiter.AllowN(key, 5), "Should allow another 5 tokens")

	// 再请求 1 个令牌应该被拒绝
	assert.False(t, limiter.AllowN(key, 1), "Should deny 1 more token")
}

func TestTokenBucketLimiter_Refill(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10, // 每秒 10 个令牌
		Burst:             5,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	key := "test-key"

	// 消耗所有令牌
	for i := 0; i < 5; i++ {
		limiter.Allow(key)
	}
	assert.False(t, limiter.Allow(key), "Should be denied after exhausting tokens")

	// 等待 200ms，应该补充约 2 个令牌
	time.Sleep(200 * time.Millisecond)

	// 应该允许 1-2 个请求
	assert.True(t, limiter.Allow(key), "Should allow after refill")
}

func TestTokenBucketLimiter_DifferentKeys(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             2,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	key1 := "user:1"
	key2 := "user:2"

	// 消耗 key1 的所有令牌
	assert.True(t, limiter.Allow(key1))
	assert.True(t, limiter.Allow(key1))
	assert.False(t, limiter.Allow(key1))

	// key2 应该不受影响
	assert.True(t, limiter.Allow(key2))
	assert.True(t, limiter.Allow(key2))
	assert.False(t, limiter.Allow(key2))
}

func TestTokenBucketLimiter_Concurrent(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 100,
		Burst:             50,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	key := "concurrent-key"
	var wg sync.WaitGroup
	var allowed, denied int64
	var mu sync.Mutex

	// 并发发送 100 个请求
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if limiter.Allow(key) {
				mu.Lock()
				allowed++
				mu.Unlock()
			} else {
				mu.Lock()
				denied++
				mu.Unlock()
			}
		}()
	}

	wg.Wait()

	// 应该有约 50 个请求被允许（突发容量）
	assert.LessOrEqual(t, allowed, int64(50), "Allowed requests should not exceed burst")
	assert.Equal(t, int64(100), allowed+denied, "Total should be 100")
}

func TestSlidingWindowLimiter_Allow(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 5,
		Burst:             5, // 滑动窗口不使用 Burst，但保持接口一致
	}
	limiter := NewSlidingWindowLimiter(config)
	defer limiter.Stop()

	key := "test-key"

	// 应该允许前 5 个请求
	for i := 0; i < 5; i++ {
		assert.True(t, limiter.Allow(key), "Request %d should be allowed", i+1)
	}

	// 第 6 个请求应该被拒绝
	assert.False(t, limiter.Allow(key), "Request 6 should be denied")
}

func TestSlidingWindowLimiter_WindowSlide(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 5,
		Burst:             5,
	}
	limiter := NewSlidingWindowLimiter(config)
	defer limiter.Stop()

	key := "test-key"

	// 消耗所有配额
	for i := 0; i < 5; i++ {
		limiter.Allow(key)
	}
	assert.False(t, limiter.Allow(key))

	// 等待窗口滑动
	time.Sleep(1100 * time.Millisecond)

	// 应该允许新的请求
	assert.True(t, limiter.Allow(key), "Should allow after window slides")
}

func TestRateLimitMiddleware_Allow(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             5,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	router := gin.New()
	router.Use(RateLimitByIP(limiter))
	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// 前 5 个请求应该成功
	for i := 0; i < 5; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code, "Request %d should succeed", i+1)
	}

	// 第 6 个请求应该被限流
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code, "Request 6 should be rate limited")
}

func TestRateLimitMiddleware_DifferentIPs(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             2,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	router := gin.New()
	router.Use(RateLimitByIP(limiter))
	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// IP1 的请求
	for i := 0; i < 2; i++ {
		w := httptest.NewRecorder()
		req, _ := http.NewRequest("GET", "/test", nil)
		req.RemoteAddr = "192.168.1.1:12345"
		router.ServeHTTP(w, req)
		assert.Equal(t, http.StatusOK, w.Code)
	}

	// IP1 被限流
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusTooManyRequests, w.Code)

	// IP2 不受影响
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.2:12345"
	router.ServeHTTP(w, req)
	assert.Equal(t, http.StatusOK, w.Code)
}

func TestIPKeyExtractor(t *testing.T) {
	tests := []struct {
		name           string
		remoteAddr     string
		xForwardedFor  string
		xRealIP        string
		expectedPrefix string
	}{
		{
			name:           "Use RemoteAddr when no headers",
			remoteAddr:     "192.168.1.1:12345",
			expectedPrefix: "192.168.1.1",
		},
		{
			name:           "Use X-Forwarded-For when present",
			remoteAddr:     "10.0.0.1:12345",
			xForwardedFor:  "203.0.113.1, 70.41.3.18, 150.172.238.178",
			expectedPrefix: "203.0.113.1",
		},
		{
			name:           "Use X-Real-IP when X-Forwarded-For not present",
			remoteAddr:     "10.0.0.1:12345",
			xRealIP:        "203.0.113.2",
			expectedPrefix: "203.0.113.2",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := httptest.NewRecorder()
			c, _ := gin.CreateTestContext(w)
			c.Request, _ = http.NewRequest("GET", "/", nil)
			c.Request.RemoteAddr = tt.remoteAddr

			if tt.xForwardedFor != "" {
				c.Request.Header.Set("X-Forwarded-For", tt.xForwardedFor)
			}
			if tt.xRealIP != "" {
				c.Request.Header.Set("X-Real-IP", tt.xRealIP)
			}

			key := IPKeyExtractor(c)
			assert.Contains(t, key, tt.expectedPrefix)
		})
	}
}

func TestCombinedKeyExtractor(t *testing.T) {
	t.Run("Use user ID when authenticated", func(t *testing.T) {
		w := httptest.NewRecorder()
		c, _ := gin.CreateTestContext(w)
		c.Request, _ = http.NewRequest("GET", "/", nil)
		c.Request.RemoteAddr = "192.168.1.1:12345"
		c.Set(ContextKeyUserID, int64(123))

		key := CombinedKeyExtractor(c)
		assert.Equal(t, "user:123", key)
	})

	t.Run("Use IP when not authenticated", func(t *testing.T) {
		w := httptest.NewRecorder()
		c, _ := gin.CreateTestContext(w)
		c.Request, _ = http.NewRequest("GET", "/", nil)
		c.Request.RemoteAddr = "192.168.1.1:12345"

		key := CombinedKeyExtractor(c)
		assert.Contains(t, key, "ip:")
	})
}

func TestDefaultConfigs(t *testing.T) {
	t.Run("DefaultRateLimitConfig", func(t *testing.T) {
		config := DefaultRateLimitConfig()
		assert.Equal(t, float64(10), config.RequestsPerSecond)
		assert.Equal(t, 20, config.Burst)
	})

	t.Run("StrictRateLimitConfig", func(t *testing.T) {
		config := StrictRateLimitConfig()
		assert.Equal(t, float64(1), config.RequestsPerSecond)
		assert.Equal(t, 5, config.Burst)
	})

	t.Run("RelaxedRateLimitConfig", func(t *testing.T) {
		config := RelaxedRateLimitConfig()
		assert.Equal(t, float64(50), config.RequestsPerSecond)
		assert.Equal(t, 100, config.Burst)
	})
}

func TestTokenBucketLimiter_GetBucketCount(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 10,
		Burst:             5,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	assert.Equal(t, 0, limiter.GetBucketCount())

	limiter.Allow("key1")
	assert.Equal(t, 1, limiter.GetBucketCount())

	limiter.Allow("key2")
	assert.Equal(t, 2, limiter.GetBucketCount())

	// 同一个 key 不会增加计数
	limiter.Allow("key1")
	assert.Equal(t, 2, limiter.GetBucketCount())
}

func TestFormatInt64(t *testing.T) {
	tests := []struct {
		input    int64
		expected string
	}{
		{0, "0"},
		{1, "1"},
		{123, "123"},
		{-1, "-1"},
		{-123, "-123"},
		{9223372036854775807, "9223372036854775807"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := formatInt64(tt.input)
			assert.Equal(t, tt.expected, result)
		})
	}
}

func TestRateLimitMiddleware_ResponseFormat(t *testing.T) {
	config := RateLimitConfig{
		RequestsPerSecond: 1,
		Burst:             1,
	}
	limiter := NewTokenBucketLimiter(config)
	defer limiter.Stop()

	router := gin.New()
	router.Use(RateLimitByIP(limiter))
	router.GET("/test", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// 第一个请求成功
	w := httptest.NewRecorder()
	req, _ := http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)
	require.Equal(t, http.StatusOK, w.Code)

	// 第二个请求被限流，检查响应格式
	w = httptest.NewRecorder()
	req, _ = http.NewRequest("GET", "/test", nil)
	req.RemoteAddr = "192.168.1.1:12345"
	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusTooManyRequests, w.Code)
	assert.Contains(t, w.Body.String(), "429")
	assert.Contains(t, w.Body.String(), "Too many requests")
}
