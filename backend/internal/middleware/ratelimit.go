package middleware

import (
	"sync"
	"time"

	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
)

// RateLimiter 限流器接口
type RateLimiter interface {
	// Allow 检查是否允许一个请求
	Allow(key string) bool
	// AllowN 检查是否允许 n 个请求
	AllowN(key string, n int) bool
}

// RateLimitConfig 限流配置
type RateLimitConfig struct {
	// RequestsPerSecond 每秒允许的请求数
	RequestsPerSecond float64
	// Burst 突发请求数（令牌桶容量）
	Burst int
}

// tokenBucket 令牌桶
type tokenBucket struct {
	tokens         float64   // 当前令牌数
	lastRefillTime time.Time // 上次填充时间
	rate           float64   // 每秒填充速率
	capacity       float64   // 桶容量
	mu             sync.Mutex
}

// newTokenBucket 创建令牌桶
func newTokenBucket(rate float64, capacity int) *tokenBucket {
	return &tokenBucket{
		tokens:         float64(capacity),
		lastRefillTime: time.Now(),
		rate:           rate,
		capacity:       float64(capacity),
	}
}

// refill 填充令牌
func (tb *tokenBucket) refill() {
	now := time.Now()
	elapsed := now.Sub(tb.lastRefillTime).Seconds()
	tb.tokens += elapsed * tb.rate
	if tb.tokens > tb.capacity {
		tb.tokens = tb.capacity
	}
	tb.lastRefillTime = now
}

// take 尝试获取 n 个令牌
func (tb *tokenBucket) take(n int) bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	tb.refill()

	if tb.tokens >= float64(n) {
		tb.tokens -= float64(n)
		return true
	}
	return false
}

// TokenBucketLimiter 基于令牌桶的限流器
type TokenBucketLimiter struct {
	buckets  map[string]*tokenBucket
	config   RateLimitConfig
	mu       sync.RWMutex
	cleanupInterval time.Duration
	stopCleanup     chan struct{}
}

// NewTokenBucketLimiter 创建令牌桶限流器
func NewTokenBucketLimiter(config RateLimitConfig) *TokenBucketLimiter {
	limiter := &TokenBucketLimiter{
		buckets:         make(map[string]*tokenBucket),
		config:          config,
		cleanupInterval: 5 * time.Minute,
		stopCleanup:     make(chan struct{}),
	}

	// 启动清理协程
	go limiter.cleanup()

	return limiter
}

// Allow 检查是否允许一个请求
func (l *TokenBucketLimiter) Allow(key string) bool {
	return l.AllowN(key, 1)
}

// AllowN 检查是否允许 n 个请求
func (l *TokenBucketLimiter) AllowN(key string, n int) bool {
	bucket := l.getBucket(key)
	return bucket.take(n)
}

// getBucket 获取或创建令牌桶
func (l *TokenBucketLimiter) getBucket(key string) *tokenBucket {
	// 先尝试读取
	l.mu.RLock()
	bucket, exists := l.buckets[key]
	l.mu.RUnlock()

	if exists {
		return bucket
	}

	// 不存在则创建
	l.mu.Lock()
	defer l.mu.Unlock()

	// 双重检查
	if bucket, exists = l.buckets[key]; exists {
		return bucket
	}

	bucket = newTokenBucket(l.config.RequestsPerSecond, l.config.Burst)
	l.buckets[key] = bucket
	return bucket
}

// cleanup 定期清理过期的令牌桶
func (l *TokenBucketLimiter) cleanup() {
	ticker := time.NewTicker(l.cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			l.doCleanup()
		case <-l.stopCleanup:
			return
		}
	}
}

// doCleanup 执行清理
func (l *TokenBucketLimiter) doCleanup() {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	expireThreshold := 10 * time.Minute

	for key, bucket := range l.buckets {
		bucket.mu.Lock()
		// 如果令牌桶已满且超过阈值时间未使用，则删除
		if bucket.tokens >= bucket.capacity && now.Sub(bucket.lastRefillTime) > expireThreshold {
			delete(l.buckets, key)
		}
		bucket.mu.Unlock()
	}
}

// Stop 停止限流器（停止清理协程）
func (l *TokenBucketLimiter) Stop() {
	close(l.stopCleanup)
}

// GetBucketCount 获取当前令牌桶数量（用于监控）
func (l *TokenBucketLimiter) GetBucketCount() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return len(l.buckets)
}

// SlidingWindowLimiter 基于滑动窗口的限流器
type SlidingWindowLimiter struct {
	windows         map[string]*slidingWindow
	config          RateLimitConfig
	windowSize      time.Duration
	mu              sync.RWMutex
	cleanupInterval time.Duration
	stopCleanup     chan struct{}
}

// slidingWindow 滑动窗口
type slidingWindow struct {
	timestamps []time.Time
	mu         sync.Mutex
}

// NewSlidingWindowLimiter 创建滑动窗口限流器
func NewSlidingWindowLimiter(config RateLimitConfig) *SlidingWindowLimiter {
	limiter := &SlidingWindowLimiter{
		windows:         make(map[string]*slidingWindow),
		config:          config,
		windowSize:      time.Second,
		cleanupInterval: 5 * time.Minute,
		stopCleanup:     make(chan struct{}),
	}

	// 启动清理协程
	go limiter.cleanup()

	return limiter
}

// Allow 检查是否允许一个请求
func (l *SlidingWindowLimiter) Allow(key string) bool {
	return l.AllowN(key, 1)
}

// AllowN 检查是否允许 n 个请求
func (l *SlidingWindowLimiter) AllowN(key string, n int) bool {
	window := l.getWindow(key)
	return window.allow(n, l.config.RequestsPerSecond, l.windowSize)
}

// getWindow 获取或创建滑动窗口
func (l *SlidingWindowLimiter) getWindow(key string) *slidingWindow {
	l.mu.RLock()
	window, exists := l.windows[key]
	l.mu.RUnlock()

	if exists {
		return window
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	if window, exists = l.windows[key]; exists {
		return window
	}

	window = &slidingWindow{
		timestamps: make([]time.Time, 0),
	}
	l.windows[key] = window
	return window
}

// allow 检查滑动窗口是否允许请求
func (sw *slidingWindow) allow(n int, rate float64, windowSize time.Duration) bool {
	sw.mu.Lock()
	defer sw.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-windowSize)

	// 清理过期的时间戳
	validTimestamps := make([]time.Time, 0, len(sw.timestamps))
	for _, ts := range sw.timestamps {
		if ts.After(windowStart) {
			validTimestamps = append(validTimestamps, ts)
		}
	}
	sw.timestamps = validTimestamps

	// 检查是否超过限制
	maxRequests := int(rate * windowSize.Seconds())
	if len(sw.timestamps)+n > maxRequests {
		return false
	}

	// 添加新的时间戳
	for i := 0; i < n; i++ {
		sw.timestamps = append(sw.timestamps, now)
	}

	return true
}

// cleanup 定期清理过期的滑动窗口
func (l *SlidingWindowLimiter) cleanup() {
	ticker := time.NewTicker(l.cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			l.doCleanup()
		case <-l.stopCleanup:
			return
		}
	}
}

// doCleanup 执行清理
func (l *SlidingWindowLimiter) doCleanup() {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	expireThreshold := 10 * time.Minute

	for key, window := range l.windows {
		window.mu.Lock()
		// 如果窗口为空且超过阈值时间，则删除
		if len(window.timestamps) == 0 {
			delete(l.windows, key)
		} else {
			// 检查最后一个时间戳是否过期
			lastTs := window.timestamps[len(window.timestamps)-1]
			if now.Sub(lastTs) > expireThreshold {
				delete(l.windows, key)
			}
		}
		window.mu.Unlock()
	}
}

// Stop 停止限流器
func (l *SlidingWindowLimiter) Stop() {
	close(l.stopCleanup)
}

// GetWindowCount 获取当前窗口数量（用于监控）
func (l *SlidingWindowLimiter) GetWindowCount() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return len(l.windows)
}

// KeyExtractor 限流 key 提取函数类型
type KeyExtractor func(c *gin.Context) string

// IPKeyExtractor 基于 IP 地址的 key 提取器
func IPKeyExtractor(c *gin.Context) string {
	// 优先使用 X-Forwarded-For 头（代理场景）
	if xff := c.GetHeader("X-Forwarded-For"); xff != "" {
		// 取第一个 IP（原始客户端 IP）
		for i := 0; i < len(xff); i++ {
			if xff[i] == ',' {
				return xff[:i]
			}
		}
		return xff
	}

	// 使用 X-Real-IP 头
	if xri := c.GetHeader("X-Real-IP"); xri != "" {
		return xri
	}

	// 使用 ClientIP
	return c.ClientIP()
}

// UserIDKeyExtractor 基于用户 ID 的 key 提取器
// 如果用户未登录，则回退到 IP 地址
func UserIDKeyExtractor(c *gin.Context) string {
	userID := GetUserID(c)
	if userID > 0 {
		return "user:" + string(rune(userID))
	}
	return "ip:" + IPKeyExtractor(c)
}

// CombinedKeyExtractor 组合 key 提取器
// 优先使用用户 ID，如果未登录则使用 IP
func CombinedKeyExtractor(c *gin.Context) string {
	userID := GetUserID(c)
	if userID > 0 {
		return "user:" + formatInt64(userID)
	}
	return "ip:" + IPKeyExtractor(c)
}

// formatInt64 将 int64 转换为字符串
func formatInt64(n int64) string {
	if n == 0 {
		return "0"
	}

	var buf [20]byte
	i := len(buf)
	negative := n < 0
	if negative {
		n = -n
	}

	for n > 0 {
		i--
		buf[i] = byte(n%10) + '0'
		n /= 10
	}

	if negative {
		i--
		buf[i] = '-'
	}

	return string(buf[i:])
}

// RateLimit 限流中间件
// 使用提供的限流器和 key 提取器进行限流
func RateLimit(limiter RateLimiter, keyExtractor KeyExtractor) gin.HandlerFunc {
	return func(c *gin.Context) {
		key := keyExtractor(c)

		if !limiter.Allow(key) {
			response.RateLimited(c, "Too many requests, please try again later")
			c.Abort()
			return
		}

		c.Next()
	}
}

// RateLimitByIP 基于 IP 的限流中间件
func RateLimitByIP(limiter RateLimiter) gin.HandlerFunc {
	return RateLimit(limiter, IPKeyExtractor)
}

// RateLimitByUser 基于用户 ID 的限流中间件（未登录时回退到 IP）
func RateLimitByUser(limiter RateLimiter) gin.HandlerFunc {
	return RateLimit(limiter, CombinedKeyExtractor)
}

// DefaultRateLimitConfig 默认限流配置
func DefaultRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		RequestsPerSecond: 10,  // 每秒 10 个请求
		Burst:             20,  // 突发 20 个请求
	}
}

// StrictRateLimitConfig 严格限流配置（用于敏感接口）
func StrictRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		RequestsPerSecond: 1,   // 每秒 1 个请求
		Burst:             5,   // 突发 5 个请求
	}
}

// RelaxedRateLimitConfig 宽松限流配置（用于普通接口）
func RelaxedRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		RequestsPerSecond: 50,  // 每秒 50 个请求
		Burst:             100, // 突发 100 个请求
	}
}
