package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"

	"fund-analyzer/internal/model"

	"github.com/gin-gonic/gin"
)

// SSEWriter SSE 流式响应写入器
type SSEWriter struct {
	ctx        context.Context
	cancel     context.CancelFunc
	writer     gin.ResponseWriter
	flusher    http.Flusher
	mu         sync.Mutex
	closed     bool
	closedOnce sync.Once
}

// NewSSEWriter 创建 SSE 写入器
// 设置正确的 SSE 响应头并返回写入器
func NewSSEWriter(c *gin.Context) *SSEWriter {
	// 设置 SSE 响应头
	c.Header("Content-Type", "text/event-stream")
	c.Header("Cache-Control", "no-cache")
	c.Header("Connection", "keep-alive")
	c.Header("X-Accel-Buffering", "no") // 禁用 nginx 缓冲

	// 获取 flusher
	flusher, ok := c.Writer.(http.Flusher)
	if !ok {
		return nil
	}

	// 创建可取消的 context
	ctx, cancel := context.WithCancel(c.Request.Context())

	return &SSEWriter{
		ctx:     ctx,
		cancel:  cancel,
		writer:  c.Writer,
		flusher: flusher,
		closed:  false,
	}
}

// Context 返回 SSE 写入器的 context
// 当客户端断开连接时，context 会被取消
func (w *SSEWriter) Context() context.Context {
	return w.ctx
}

// IsClosed 检查连接是否已关闭
func (w *SSEWriter) IsClosed() bool {
	w.mu.Lock()
	defer w.mu.Unlock()
	return w.closed
}

// SendEvent 发送 SSE 事件
// eventType 为事件类型（可选），data 为事件数据
func (w *SSEWriter) SendEvent(eventType string, data string) error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.closed {
		return fmt.Errorf("SSE connection closed")
	}

	// 检查 context 是否已取消（客户端断开）
	select {
	case <-w.ctx.Done():
		w.closed = true
		return fmt.Errorf("client disconnected")
	default:
	}

	// 写入事件类型（如果有）
	if eventType != "" {
		if _, err := fmt.Fprintf(w.writer, "event: %s\n", eventType); err != nil {
			w.closed = true
			return fmt.Errorf("failed to write event type: %w", err)
		}
	}

	// 写入数据
	if _, err := fmt.Fprintf(w.writer, "data: %s\n\n", data); err != nil {
		w.closed = true
		return fmt.Errorf("failed to write data: %w", err)
	}

	// 立即刷新
	w.flusher.Flush()

	return nil
}

// SendJSON 发送 JSON 格式的 SSE 事件
func (w *SSEWriter) SendJSON(data interface{}) error {
	jsonData, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal JSON: %w", err)
	}
	return w.SendEvent("", string(jsonData))
}

// SendChatChunk 发送 ChatChunk 类型的 SSE 事件
func (w *SSEWriter) SendChatChunk(chunk model.ChatChunk) error {
	return w.SendJSON(chunk)
}

// SendStatus 发送状态消息
func (w *SSEWriter) SendStatus(message string) error {
	return w.SendChatChunk(model.ChatChunk{
		Type:    model.ChunkTypeStatus,
		Message: message,
	})
}

// SendContent 发送内容块
func (w *SSEWriter) SendContent(content string) error {
	return w.SendChatChunk(model.ChatChunk{
		Type:  model.ChunkTypeContent,
		Chunk: content,
	})
}

// SendToolCall 发送工具调用状态
func (w *SSEWriter) SendToolCall(tools []string) error {
	return w.SendChatChunk(model.ChatChunk{
		Type:  model.ChunkTypeToolCall,
		Tools: tools,
	})
}

// SendDone 发送完成消息
func (w *SSEWriter) SendDone() error {
	return w.SendChatChunk(model.ChatChunk{
		Type: model.ChunkTypeDone,
	})
}

// SendError 发送错误消息
func (w *SSEWriter) SendError(message string) error {
	return w.SendChatChunk(model.ChatChunk{
		Type:    model.ChunkTypeError,
		Message: message,
	})
}

// Close 关闭 SSE 连接
func (w *SSEWriter) Close() {
	w.closedOnce.Do(func() {
		w.mu.Lock()
		w.closed = true
		w.mu.Unlock()
		w.cancel()
	})
}

// StreamChatChunks 从 channel 流式发送 ChatChunk
// 自动处理客户端断开和 channel 关闭
func (w *SSEWriter) StreamChatChunks(chunks <-chan model.ChatChunk) error {
	for {
		select {
		case <-w.ctx.Done():
			// 客户端断开连接
			return fmt.Errorf("client disconnected")

		case chunk, ok := <-chunks:
			if !ok {
				// channel 已关闭
				return nil
			}

			if err := w.SendChatChunk(chunk); err != nil {
				return err
			}

			// 如果是 done 或 error 类型，结束流
			if chunk.Type == model.ChunkTypeDone || chunk.Type == model.ChunkTypeError {
				return nil
			}
		}
	}
}

// StreamStrings 从 channel 流式发送字符串内容
// 自动处理客户端断开和 channel 关闭，最后发送 done 消息
func (w *SSEWriter) StreamStrings(contents <-chan string) error {
	for {
		select {
		case <-w.ctx.Done():
			// 客户端断开连接
			return fmt.Errorf("client disconnected")

		case content, ok := <-contents:
			if !ok {
				// channel 已关闭，发送完成消息
				return w.SendDone()
			}

			if err := w.SendContent(content); err != nil {
				return err
			}
		}
	}
}

// SSEHandler SSE 处理函数类型
type SSEHandler func(w *SSEWriter) error

// SSE 创建 SSE 中间件/处理器
// 自动设置响应头，处理客户端断开，并在结束时关闭连接
func SSE(handler SSEHandler) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 创建 SSE 写入器
		w := NewSSEWriter(c)
		if w == nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"code":    500,
				"message": "SSE not supported",
			})
			return
		}

		// 确保连接关闭
		defer w.Close()

		// 监听客户端断开
		go func() {
			<-c.Request.Context().Done()
			w.Close()
		}()

		// 执行处理函数
		if err := handler(w); err != nil {
			// 如果连接未关闭，发送错误消息
			if !w.IsClosed() {
				_ = w.SendError(err.Error())
			}
		}
	}
}

// SSEConnectionLimiter SSE 连接数限制器
type SSEConnectionLimiter struct {
	maxConnections int
	current        int
	mu             sync.Mutex
}

// NewSSEConnectionLimiter 创建 SSE 连接数限制器
func NewSSEConnectionLimiter(maxConnections int) *SSEConnectionLimiter {
	return &SSEConnectionLimiter{
		maxConnections: maxConnections,
		current:        0,
	}
}

// Acquire 获取连接许可
func (l *SSEConnectionLimiter) Acquire() bool {
	l.mu.Lock()
	defer l.mu.Unlock()

	if l.current >= l.maxConnections {
		return false
	}

	l.current++
	return true
}

// Release 释放连接许可
func (l *SSEConnectionLimiter) Release() {
	l.mu.Lock()
	defer l.mu.Unlock()

	if l.current > 0 {
		l.current--
	}
}

// Current 获取当前连接数
func (l *SSEConnectionLimiter) Current() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.current
}

// SSEWithLimit 带连接数限制的 SSE 中间件
func SSEWithLimit(limiter *SSEConnectionLimiter, handler SSEHandler) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 尝试获取连接许可
		if !limiter.Acquire() {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"code":    429,
				"message": "Too many SSE connections",
			})
			return
		}

		// 确保释放连接许可
		defer limiter.Release()

		// 创建 SSE 写入器
		w := NewSSEWriter(c)
		if w == nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"code":    500,
				"message": "SSE not supported",
			})
			return
		}

		// 确保连接关闭
		defer w.Close()

		// 监听客户端断开
		go func() {
			<-c.Request.Context().Done()
			w.Close()
		}()

		// 执行处理函数
		if err := handler(w); err != nil {
			// 如果连接未关闭，发送错误消息
			if !w.IsClosed() {
				_ = w.SendError(err.Error())
			}
		}
	}
}
