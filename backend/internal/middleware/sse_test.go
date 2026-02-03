package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"fund-analyzer/internal/model"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func init() {
	gin.SetMode(gin.TestMode)
}

// TestNewSSEWriter tests SSE writer creation and header setting
func TestNewSSEWriter(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Check headers
	assert.Equal(t, "text/event-stream", w.Header().Get("Content-Type"))
	assert.Equal(t, "no-cache", w.Header().Get("Cache-Control"))
	assert.Equal(t, "keep-alive", w.Header().Get("Connection"))
	assert.Equal(t, "no", w.Header().Get("X-Accel-Buffering"))
}

// TestSSEWriter_SendEvent tests sending SSE events
func TestSSEWriter_SendEvent(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Send event without type
	err := sseWriter.SendEvent("", `{"type":"content","chunk":"Hello"}`)
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `data: {"type":"content","chunk":"Hello"}`)
	assert.Contains(t, body, "\n\n")
}

// TestSSEWriter_SendEventWithType tests sending SSE events with event type
func TestSSEWriter_SendEventWithType(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Send event with type
	err := sseWriter.SendEvent("message", `{"content":"test"}`)
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, "event: message\n")
	assert.Contains(t, body, `data: {"content":"test"}`)
}

// TestSSEWriter_SendJSON tests sending JSON data
func TestSSEWriter_SendJSON(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	data := map[string]string{"key": "value"}
	err := sseWriter.SendJSON(data)
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `data: {"key":"value"}`)
}

// TestSSEWriter_SendChatChunk tests sending ChatChunk
func TestSSEWriter_SendChatChunk(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	chunk := model.ChatChunk{
		Type:  model.ChunkTypeContent,
		Chunk: "Hello World",
	}
	err := sseWriter.SendChatChunk(chunk)
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"content"`)
	assert.Contains(t, body, `"chunk":"Hello World"`)
}

// TestSSEWriter_SendStatus tests sending status message
func TestSSEWriter_SendStatus(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	err := sseWriter.SendStatus("正在分析...")
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"status"`)
	assert.Contains(t, body, `"message":"正在分析..."`)
}

// TestSSEWriter_SendContent tests sending content chunk
func TestSSEWriter_SendContent(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	err := sseWriter.SendContent("Hello")
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"content"`)
	assert.Contains(t, body, `"chunk":"Hello"`)
}

// TestSSEWriter_SendToolCall tests sending tool call status
func TestSSEWriter_SendToolCall(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	err := sseWriter.SendToolCall([]string{"search_news", "fetch_webpage"})
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"tool_call"`)
	assert.Contains(t, body, `"tools":["search_news","fetch_webpage"]`)
}

// TestSSEWriter_SendDone tests sending done message
func TestSSEWriter_SendDone(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	err := sseWriter.SendDone()
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"done"`)
}

// TestSSEWriter_SendError tests sending error message
func TestSSEWriter_SendError(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	err := sseWriter.SendError("Something went wrong")
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"error"`)
	assert.Contains(t, body, `"message":"Something went wrong"`)
}

// TestSSEWriter_Close tests closing SSE connection
func TestSSEWriter_Close(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	assert.False(t, sseWriter.IsClosed())

	sseWriter.Close()
	assert.True(t, sseWriter.IsClosed())

	// Sending after close should fail
	err := sseWriter.SendContent("test")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "closed")
}

// TestSSEWriter_CloseIdempotent tests that Close is idempotent
func TestSSEWriter_CloseIdempotent(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Close multiple times should not panic
	sseWriter.Close()
	sseWriter.Close()
	sseWriter.Close()

	assert.True(t, sseWriter.IsClosed())
}

// TestSSEWriter_StreamChatChunks tests streaming ChatChunks from channel
func TestSSEWriter_StreamChatChunks(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	chunks := make(chan model.ChatChunk, 3)
	chunks <- model.ChatChunk{Type: model.ChunkTypeStatus, Message: "Starting..."}
	chunks <- model.ChatChunk{Type: model.ChunkTypeContent, Chunk: "Hello"}
	chunks <- model.ChatChunk{Type: model.ChunkTypeDone}
	close(chunks)

	err := sseWriter.StreamChatChunks(chunks)
	assert.NoError(t, err)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"status"`)
	assert.Contains(t, body, `"type":"content"`)
	assert.Contains(t, body, `"type":"done"`)
}

// TestSSEWriter_StreamStrings tests streaming strings from channel
func TestSSEWriter_StreamStrings(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	contents := make(chan string, 3)
	contents <- "Hello"
	contents <- " "
	contents <- "World"
	close(contents)

	err := sseWriter.StreamStrings(contents)
	assert.NoError(t, err)

	body := w.Body.String()
	// Should contain content chunks
	assert.Contains(t, body, `"chunk":"Hello"`)
	assert.Contains(t, body, `"chunk":" "`)
	assert.Contains(t, body, `"chunk":"World"`)
	// Should end with done
	assert.Contains(t, body, `"type":"done"`)
}

// TestSSEConnectionLimiter tests connection limiting
func TestSSEConnectionLimiter(t *testing.T) {
	limiter := NewSSEConnectionLimiter(2)

	// Should allow first two connections
	assert.True(t, limiter.Acquire())
	assert.Equal(t, 1, limiter.Current())

	assert.True(t, limiter.Acquire())
	assert.Equal(t, 2, limiter.Current())

	// Should reject third connection
	assert.False(t, limiter.Acquire())
	assert.Equal(t, 2, limiter.Current())

	// Release one connection
	limiter.Release()
	assert.Equal(t, 1, limiter.Current())

	// Should allow new connection
	assert.True(t, limiter.Acquire())
	assert.Equal(t, 2, limiter.Current())
}

// TestSSEConnectionLimiter_Concurrent tests concurrent access to limiter
func TestSSEConnectionLimiter_Concurrent(t *testing.T) {
	limiter := NewSSEConnectionLimiter(10)

	var wg sync.WaitGroup
	acquired := make(chan bool, 20)

	// Try to acquire 20 connections concurrently
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			acquired <- limiter.Acquire()
		}()
	}

	wg.Wait()
	close(acquired)

	// Count successful acquisitions
	successCount := 0
	for success := range acquired {
		if success {
			successCount++
		}
	}

	// Should only allow 10 connections
	assert.Equal(t, 10, successCount)
	assert.Equal(t, 10, limiter.Current())
}

// TestSSE_Handler tests the SSE middleware
func TestSSE_Handler(t *testing.T) {
	router := gin.New()

	router.GET("/sse", SSE(func(w *SSEWriter) error {
		_ = w.SendStatus("Starting...")
		_ = w.SendContent("Hello")
		_ = w.SendDone()
		return nil
	}))

	req := httptest.NewRequest(http.MethodGet, "/sse", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "text/event-stream", w.Header().Get("Content-Type"))

	body := w.Body.String()
	assert.Contains(t, body, `"type":"status"`)
	assert.Contains(t, body, `"type":"content"`)
	assert.Contains(t, body, `"type":"done"`)
}

// TestSSE_HandlerError tests SSE middleware error handling
func TestSSE_HandlerError(t *testing.T) {
	router := gin.New()

	router.GET("/sse", SSE(func(w *SSEWriter) error {
		_ = w.SendStatus("Starting...")
		return assert.AnError
	}))

	req := httptest.NewRequest(http.MethodGet, "/sse", nil)
	w := httptest.NewRecorder()

	router.ServeHTTP(w, req)

	body := w.Body.String()
	assert.Contains(t, body, `"type":"error"`)
}

// TestSSEWithLimit tests SSE with connection limit
func TestSSEWithLimit(t *testing.T) {
	limiter := NewSSEConnectionLimiter(1)
	router := gin.New()

	router.GET("/sse", SSEWithLimit(limiter, func(w *SSEWriter) error {
		_ = w.SendContent("Hello")
		_ = w.SendDone()
		return nil
	}))

	// First request should succeed
	req1 := httptest.NewRequest(http.MethodGet, "/sse", nil)
	w1 := httptest.NewRecorder()
	router.ServeHTTP(w1, req1)
	assert.Equal(t, http.StatusOK, w1.Code)

	// Connection should be released after request completes
	assert.Equal(t, 0, limiter.Current())
}

// TestSSEEventFormat tests the SSE event format
func TestSSEEventFormat(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Send multiple events
	_ = sseWriter.SendStatus("正在分析...")
	_ = sseWriter.SendContent("Hello")
	_ = sseWriter.SendDone()

	body := w.Body.String()

	// Parse events
	events := strings.Split(body, "\n\n")
	events = events[:len(events)-1] // Remove last empty element

	assert.Len(t, events, 3)

	// Verify each event format
	for _, event := range events {
		assert.True(t, strings.HasPrefix(event, "data: "))
		jsonStr := strings.TrimPrefix(event, "data: ")

		var chunk model.ChatChunk
		err := json.Unmarshal([]byte(jsonStr), &chunk)
		assert.NoError(t, err)
		assert.NotEmpty(t, chunk.Type)
	}
}

// TestSSEWriter_Context tests context cancellation
func TestSSEWriter_Context(t *testing.T) {
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)

	ctx, cancel := context.WithCancel(context.Background())
	c.Request = httptest.NewRequest(http.MethodGet, "/test", nil).WithContext(ctx)

	sseWriter := NewSSEWriter(c)
	require.NotNil(t, sseWriter)

	// Context should not be done initially
	select {
	case <-sseWriter.Context().Done():
		t.Fatal("Context should not be done")
	default:
		// OK
	}

	// Cancel the context
	cancel()

	// Wait a bit for cancellation to propagate
	time.Sleep(10 * time.Millisecond)

	// Now sending should fail
	err := sseWriter.SendContent("test")
	assert.Error(t, err)
}
