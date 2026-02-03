package crawler

import (
	"context"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"time"
)

// HTTPClient HTTP 客户端配置
type HTTPClientConfig struct {
	Timeout       time.Duration
	MaxRetries    int
	RetryBaseWait time.Duration
	RetryMaxWait  time.Duration
}

// DefaultHTTPClientConfig 默认配置
func DefaultHTTPClientConfig() HTTPClientConfig {
	return HTTPClientConfig{
		Timeout:       30 * time.Second,
		MaxRetries:    3,
		RetryBaseWait: 1 * time.Second,
		RetryMaxWait:  10 * time.Second,
	}
}

// HTTPClient 带重试和超时的 HTTP 客户端
type HTTPClient struct {
	client *http.Client
	config HTTPClientConfig
}

// NewHTTPClient 创建 HTTP 客户端
func NewHTTPClient(config HTTPClientConfig) *HTTPClient {
	return &HTTPClient{
		client: &http.Client{
			Timeout: config.Timeout,
		},
		config: config,
	}
}

// UserAgents 常用 User-Agent 列表
var UserAgents = []string{
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
	"Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
	"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
	"Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
}

// RandomUserAgent 随机获取 User-Agent
func RandomUserAgent() string {
	return UserAgents[rand.Intn(len(UserAgents))]
}

// Get 发送 GET 请求（带重试）
func (c *HTTPClient) Get(ctx context.Context, url string, headers map[string]string) ([]byte, error) {
	return c.doWithRetry(ctx, "GET", url, nil, headers)
}

// Post 发送 POST 请求（带重试）
func (c *HTTPClient) Post(ctx context.Context, url string, body io.Reader, headers map[string]string) ([]byte, error) {
	return c.doWithRetry(ctx, "POST", url, body, headers)
}

// doWithRetry 带重试的请求
func (c *HTTPClient) doWithRetry(ctx context.Context, method, url string, body io.Reader, headers map[string]string) ([]byte, error) {
	var lastErr error

	for attempt := 0; attempt <= c.config.MaxRetries; attempt++ {
		if attempt > 0 {
			// 指数退避
			wait := c.calculateBackoff(attempt)
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(wait):
			}
		}

		resp, err := c.do(ctx, method, url, body, headers)
		if err == nil {
			return resp, nil
		}

		lastErr = err

		// 检查是否应该重试
		if !c.shouldRetry(err) {
			return nil, err
		}
	}

	return nil, fmt.Errorf("max retries exceeded: %w", lastErr)
}

// do 执行单次请求
func (c *HTTPClient) do(ctx context.Context, method, url string, body io.Reader, headers map[string]string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, method, url, body)
	if err != nil {
		return nil, fmt.Errorf("create request failed: %w", err)
	}

	// 设置默认 User-Agent
	req.Header.Set("User-Agent", RandomUserAgent())

	// 设置自定义 headers
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return nil, fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read response failed: %w", err)
	}

	return data, nil
}

// calculateBackoff 计算退避时间
func (c *HTTPClient) calculateBackoff(attempt int) time.Duration {
	// 指数退避 + 随机抖动
	wait := c.config.RetryBaseWait * time.Duration(1<<uint(attempt-1))
	if wait > c.config.RetryMaxWait {
		wait = c.config.RetryMaxWait
	}
	// 添加 0-25% 的随机抖动
	jitter := time.Duration(rand.Int63n(int64(wait / 4)))
	return wait + jitter
}

// shouldRetry 判断是否应该重试
func (c *HTTPClient) shouldRetry(err error) bool {
	// 超时、连接错误等可以重试
	// 4xx 客户端错误不重试
	if err == nil {
		return false
	}
	errStr := err.Error()
	// 不重试 4xx 错误
	if len(errStr) > 5 && errStr[:5] == "HTTP " {
		code := errStr[5:8]
		if code[0] == '4' {
			return false
		}
	}
	return true
}
