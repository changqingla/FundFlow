package crawler

import (
	"errors"
	"sync"
	"time"
)

// CircuitState 熔断器状态
type CircuitState int

const (
	StateClosed   CircuitState = iota // 关闭状态（正常）
	StateOpen                         // 打开状态（熔断）
	StateHalfOpen                     // 半开状态（探测）
)

var (
	ErrCircuitOpen = errors.New("circuit breaker is open")
)

// CircuitBreakerConfig 熔断器配置
type CircuitBreakerConfig struct {
	MaxFailures     int           // 最大失败次数
	Timeout         time.Duration // 熔断超时时间
	HalfOpenMaxReqs int           // 半开状态最大请求数
}

// DefaultCircuitBreakerConfig 默认配置
func DefaultCircuitBreakerConfig() CircuitBreakerConfig {
	return CircuitBreakerConfig{
		MaxFailures:     5,
		Timeout:         30 * time.Second,
		HalfOpenMaxReqs: 3,
	}
}

// CircuitBreaker 熔断器
type CircuitBreaker struct {
	config CircuitBreakerConfig

	mu              sync.RWMutex
	state           CircuitState
	failures        int
	successes       int
	lastFailureTime time.Time
	halfOpenReqs    int
}

// NewCircuitBreaker 创建熔断器
func NewCircuitBreaker(config CircuitBreakerConfig) *CircuitBreaker {
	return &CircuitBreaker{
		config: config,
		state:  StateClosed,
	}
}

// Execute 执行函数（带熔断保护）
func (cb *CircuitBreaker) Execute(fn func() error) error {
	if !cb.allowRequest() {
		return ErrCircuitOpen
	}

	err := fn()

	cb.recordResult(err)

	return err
}

// allowRequest 检查是否允许请求
func (cb *CircuitBreaker) allowRequest() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case StateClosed:
		return true

	case StateOpen:
		// 检查是否超时，可以进入半开状态
		if time.Since(cb.lastFailureTime) > cb.config.Timeout {
			cb.state = StateHalfOpen
			cb.halfOpenReqs = 0
			cb.successes = 0
			return true
		}
		return false

	case StateHalfOpen:
		// 半开状态限制请求数
		if cb.halfOpenReqs < cb.config.HalfOpenMaxReqs {
			cb.halfOpenReqs++
			return true
		}
		return false
	}

	return false
}

// recordResult 记录请求结果
func (cb *CircuitBreaker) recordResult(err error) {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	if err != nil {
		cb.onFailure()
	} else {
		cb.onSuccess()
	}
}

// onSuccess 成功处理
func (cb *CircuitBreaker) onSuccess() {
	switch cb.state {
	case StateClosed:
		cb.failures = 0

	case StateHalfOpen:
		cb.successes++
		// 半开状态下连续成功，恢复到关闭状态
		if cb.successes >= cb.config.HalfOpenMaxReqs {
			cb.state = StateClosed
			cb.failures = 0
			cb.successes = 0
		}
	}
}

// onFailure 失败处理
func (cb *CircuitBreaker) onFailure() {
	cb.failures++
	cb.lastFailureTime = time.Now()

	switch cb.state {
	case StateClosed:
		// 失败次数达到阈值，打开熔断器
		if cb.failures >= cb.config.MaxFailures {
			cb.state = StateOpen
		}

	case StateHalfOpen:
		// 半开状态下失败，重新打开熔断器
		cb.state = StateOpen
	}
}

// State 获取当前状态
func (cb *CircuitBreaker) State() CircuitState {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}

// Failures 获取失败次数
func (cb *CircuitBreaker) Failures() int {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.failures
}

// Reset 重置熔断器
func (cb *CircuitBreaker) Reset() {
	cb.mu.Lock()
	defer cb.mu.Unlock()
	cb.state = StateClosed
	cb.failures = 0
	cb.successes = 0
	cb.halfOpenReqs = 0
}

// CircuitBreakerManager 熔断器管理器
type CircuitBreakerManager struct {
	breakers map[string]*CircuitBreaker
	config   CircuitBreakerConfig
	mu       sync.RWMutex
}

// NewCircuitBreakerManager 创建熔断器管理器
func NewCircuitBreakerManager(config CircuitBreakerConfig) *CircuitBreakerManager {
	return &CircuitBreakerManager{
		breakers: make(map[string]*CircuitBreaker),
		config:   config,
	}
}

// Get 获取或创建熔断器
func (m *CircuitBreakerManager) Get(name string) *CircuitBreaker {
	m.mu.RLock()
	cb, ok := m.breakers[name]
	m.mu.RUnlock()

	if ok {
		return cb
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// 双重检查
	if cb, ok = m.breakers[name]; ok {
		return cb
	}

	cb = NewCircuitBreaker(m.config)
	m.breakers[name] = cb
	return cb
}
