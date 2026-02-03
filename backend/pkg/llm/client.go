// Package llm provides a client for OpenAI-compatible LLM APIs with streaming support.
package llm

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Config holds the configuration for the LLM client.
type Config struct {
	BaseURL string        // API base URL (e.g., "https://api.openai.com/v1")
	APIKey  string        // API key for authentication
	Model   string        // Model name (e.g., "gpt-4", "gpt-3.5-turbo")
	Timeout time.Duration // Request timeout
}

// Client is an OpenAI-compatible LLM client with streaming support.
type Client struct {
	config     Config
	httpClient *http.Client
}

// Message represents a chat message.
type Message struct {
	Role    string `json:"role"`    // "system", "user", "assistant", "tool"
	Content string `json:"content"` // Message content
	Name    string `json:"name,omitempty"` // Optional name for the message author
}

// ToolCall represents a tool call from the assistant.
type ToolCall struct {
	ID       string       `json:"id"`
	Type     string       `json:"type"` // "function"
	Function FunctionCall `json:"function"`
}

// FunctionCall represents a function call within a tool call.
type FunctionCall struct {
	Name      string `json:"name"`
	Arguments string `json:"arguments"` // JSON string of arguments
}

// Tool represents a tool that can be called by the model.
type Tool struct {
	Type     string   `json:"type"` // "function"
	Function Function `json:"function"`
}

// Function represents a function definition for tool calling.
type Function struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description,omitempty"`
	Parameters  map[string]interface{} `json:"parameters,omitempty"`
}

// ChatRequest represents a chat completion request.
type ChatRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	Stream      bool      `json:"stream,omitempty"`
	Temperature float64   `json:"temperature,omitempty"`
	MaxTokens   int       `json:"max_tokens,omitempty"`
	Tools       []Tool    `json:"tools,omitempty"`
	ToolChoice  string    `json:"tool_choice,omitempty"` // "auto", "none", or specific tool
}

// ChatResponse represents a non-streaming chat completion response.
type ChatResponse struct {
	ID      string   `json:"id"`
	Object  string   `json:"object"`
	Created int64    `json:"created"`
	Model   string   `json:"model"`
	Choices []Choice `json:"choices"`
	Usage   Usage    `json:"usage"`
}

// Choice represents a completion choice.
type Choice struct {
	Index        int       `json:"index"`
	Message      Message   `json:"message"`
	FinishReason string    `json:"finish_reason"`
	Delta        *Delta    `json:"delta,omitempty"` // For streaming responses
	ToolCalls    []ToolCall `json:"tool_calls,omitempty"`
}

// Delta represents the delta content in a streaming response.
type Delta struct {
	Role      string     `json:"role,omitempty"`
	Content   string     `json:"content,omitempty"`
	ToolCalls []ToolCall `json:"tool_calls,omitempty"`
}

// Usage represents token usage information.
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

// StreamChunk represents a chunk of streaming response.
type StreamChunk struct {
	ID      string         `json:"id"`
	Object  string         `json:"object"`
	Created int64          `json:"created"`
	Model   string         `json:"model"`
	Choices []StreamChoice `json:"choices"`
}

// StreamChoice represents a choice in a streaming response.
type StreamChoice struct {
	Index        int    `json:"index"`
	Delta        Delta  `json:"delta"`
	FinishReason string `json:"finish_reason,omitempty"`
}

// StreamEvent represents an event from the streaming response.
type StreamEvent struct {
	Content      string     // Text content chunk
	ToolCalls    []ToolCall // Tool calls (if any)
	FinishReason string     // Finish reason (if done)
	Error        error      // Error (if any)
	Done         bool       // Whether the stream is done
}

// APIError represents an error response from the API.
type APIError struct {
	Error struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Code    string `json:"code"`
	} `json:"error"`
}

// Common errors
var (
	ErrEmptyAPIKey    = errors.New("llm: API key is required")
	ErrEmptyBaseURL   = errors.New("llm: base URL is required")
	ErrEmptyModel     = errors.New("llm: model is required")
	ErrEmptyMessages  = errors.New("llm: messages cannot be empty")
	ErrRequestFailed  = errors.New("llm: request failed")
	ErrStreamClosed   = errors.New("llm: stream closed unexpectedly")
	ErrContextCanceled = errors.New("llm: context canceled")
)

// NewClient creates a new LLM client with the given configuration.
func NewClient(cfg Config) (*Client, error) {
	if cfg.APIKey == "" {
		return nil, ErrEmptyAPIKey
	}
	if cfg.BaseURL == "" {
		return nil, ErrEmptyBaseURL
	}
	if cfg.Model == "" {
		return nil, ErrEmptyModel
	}

	// Set default timeout if not specified
	timeout := cfg.Timeout
	if timeout == 0 {
		timeout = 120 * time.Second
	}

	return &Client{
		config: cfg,
		httpClient: &http.Client{
			Timeout: timeout,
		},
	}, nil
}

// Chat sends a chat completion request and returns the response.
func (c *Client) Chat(ctx context.Context, messages []Message) (*ChatResponse, error) {
	return c.ChatWithOptions(ctx, messages, nil)
}

// ChatWithOptions sends a chat completion request with additional options.
func (c *Client) ChatWithOptions(ctx context.Context, messages []Message, opts *ChatOptions) (*ChatResponse, error) {
	if len(messages) == 0 {
		return nil, ErrEmptyMessages
	}

	req := ChatRequest{
		Model:    c.config.Model,
		Messages: messages,
		Stream:   false,
	}

	if opts != nil {
		if opts.Temperature > 0 {
			req.Temperature = opts.Temperature
		}
		if opts.MaxTokens > 0 {
			req.MaxTokens = opts.MaxTokens
		}
		if len(opts.Tools) > 0 {
			req.Tools = opts.Tools
		}
		if opts.ToolChoice != "" {
			req.ToolChoice = opts.ToolChoice
		}
	}

	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("llm: failed to marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.chatEndpoint(), bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("llm: failed to create request: %w", err)
	}

	c.setHeaders(httpReq)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ErrContextCanceled
		}
		return nil, fmt.Errorf("%w: %v", ErrRequestFailed, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, c.parseError(resp)
	}

	var chatResp ChatResponse
	if err := json.NewDecoder(resp.Body).Decode(&chatResp); err != nil {
		return nil, fmt.Errorf("llm: failed to decode response: %w", err)
	}

	return &chatResp, nil
}

// ChatOptions holds optional parameters for chat requests.
type ChatOptions struct {
	Temperature float64
	MaxTokens   int
	Tools       []Tool
	ToolChoice  string
}

// ChatStream sends a streaming chat completion request.
// It returns a channel that receives StreamEvent objects.
// The channel is closed when the stream ends or an error occurs.
func (c *Client) ChatStream(ctx context.Context, messages []Message) (<-chan StreamEvent, error) {
	return c.ChatStreamWithOptions(ctx, messages, nil)
}

// ChatStreamWithOptions sends a streaming chat completion request with additional options.
func (c *Client) ChatStreamWithOptions(ctx context.Context, messages []Message, opts *ChatOptions) (<-chan StreamEvent, error) {
	if len(messages) == 0 {
		return nil, ErrEmptyMessages
	}

	req := ChatRequest{
		Model:    c.config.Model,
		Messages: messages,
		Stream:   true,
	}

	if opts != nil {
		if opts.Temperature > 0 {
			req.Temperature = opts.Temperature
		}
		if opts.MaxTokens > 0 {
			req.MaxTokens = opts.MaxTokens
		}
		if len(opts.Tools) > 0 {
			req.Tools = opts.Tools
		}
		if opts.ToolChoice != "" {
			req.ToolChoice = opts.ToolChoice
		}
	}

	body, err := json.Marshal(req)
	if err != nil {
		return nil, fmt.Errorf("llm: failed to marshal request: %w", err)
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.chatEndpoint(), bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("llm: failed to create request: %w", err)
	}

	c.setHeaders(httpReq)

	resp, err := c.httpClient.Do(httpReq)
	if err != nil {
		if ctx.Err() != nil {
			return nil, ErrContextCanceled
		}
		return nil, fmt.Errorf("%w: %v", ErrRequestFailed, err)
	}

	if resp.StatusCode != http.StatusOK {
		defer resp.Body.Close()
		return nil, c.parseError(resp)
	}

	eventChan := make(chan StreamEvent, 100)

	go c.processStream(ctx, resp.Body, eventChan)

	return eventChan, nil
}

// processStream reads the SSE stream and sends events to the channel.
func (c *Client) processStream(ctx context.Context, body io.ReadCloser, eventChan chan<- StreamEvent) {
	defer close(eventChan)
	defer body.Close()

	reader := bufio.NewReader(body)

	// Track accumulated tool calls across chunks
	toolCallsMap := make(map[int]*ToolCall)

	for {
		select {
		case <-ctx.Done():
			eventChan <- StreamEvent{Error: ErrContextCanceled, Done: true}
			return
		default:
		}

		line, err := reader.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				eventChan <- StreamEvent{Done: true}
				return
			}
			eventChan <- StreamEvent{Error: fmt.Errorf("llm: failed to read stream: %w", err), Done: true}
			return
		}

		line = strings.TrimSpace(line)

		// Skip empty lines
		if line == "" {
			continue
		}

		// Check for SSE data prefix
		if !strings.HasPrefix(line, "data: ") {
			continue
		}

		data := strings.TrimPrefix(line, "data: ")

		// Check for stream end
		if data == "[DONE]" {
			// Send accumulated tool calls if any
			if len(toolCallsMap) > 0 {
				toolCalls := make([]ToolCall, 0, len(toolCallsMap))
				for _, tc := range toolCallsMap {
					toolCalls = append(toolCalls, *tc)
				}
				eventChan <- StreamEvent{ToolCalls: toolCalls}
			}
			eventChan <- StreamEvent{Done: true}
			return
		}

		var chunk StreamChunk
		if err := json.Unmarshal([]byte(data), &chunk); err != nil {
			// Skip malformed chunks
			continue
		}

		if len(chunk.Choices) == 0 {
			continue
		}

		choice := chunk.Choices[0]

		// Handle content
		if choice.Delta.Content != "" {
			eventChan <- StreamEvent{Content: choice.Delta.Content}
		}

		// Handle tool calls (accumulate across chunks)
		for _, tc := range choice.Delta.ToolCalls {
			idx := tc.ID
			if idx == "" {
				// Use index as key if ID is empty
				idx = fmt.Sprintf("%d", len(toolCallsMap))
			}
			
			existing, ok := toolCallsMap[len(toolCallsMap)]
			if !ok || tc.ID != "" {
				// New tool call
				toolCallsMap[len(toolCallsMap)] = &ToolCall{
					ID:   tc.ID,
					Type: tc.Type,
					Function: FunctionCall{
						Name:      tc.Function.Name,
						Arguments: tc.Function.Arguments,
					},
				}
			} else {
				// Append to existing tool call arguments
				existing.Function.Arguments += tc.Function.Arguments
			}
		}

		// Handle finish reason
		if choice.FinishReason != "" {
			eventChan <- StreamEvent{FinishReason: choice.FinishReason}
		}
	}
}

// chatEndpoint returns the chat completions endpoint URL.
func (c *Client) chatEndpoint() string {
	baseURL := strings.TrimSuffix(c.config.BaseURL, "/")
	return baseURL + "/chat/completions"
}

// setHeaders sets the required headers for API requests.
func (c *Client) setHeaders(req *http.Request) {
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.config.APIKey)
	req.Header.Set("Accept", "text/event-stream")
}

// parseError parses an error response from the API.
func (c *Client) parseError(resp *http.Response) error {
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Errorf("llm: API error (status %d): failed to read response body", resp.StatusCode)
	}

	var apiErr APIError
	if err := json.Unmarshal(body, &apiErr); err != nil {
		return fmt.Errorf("llm: API error (status %d): %s", resp.StatusCode, string(body))
	}

	return fmt.Errorf("llm: API error (status %d, type %s): %s", 
		resp.StatusCode, apiErr.Error.Type, apiErr.Error.Message)
}

// GetModel returns the configured model name.
func (c *Client) GetModel() string {
	return c.config.Model
}

// SetModel updates the model name.
func (c *Client) SetModel(model string) {
	c.config.Model = model
}
