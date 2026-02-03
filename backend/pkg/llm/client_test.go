package llm

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestNewClient(t *testing.T) {
	tests := []struct {
		name    string
		config  Config
		wantErr error
	}{
		{
			name: "valid config",
			config: Config{
				BaseURL: "https://api.openai.com/v1",
				APIKey:  "test-key",
				Model:   "gpt-4",
			},
			wantErr: nil,
		},
		{
			name: "missing API key",
			config: Config{
				BaseURL: "https://api.openai.com/v1",
				Model:   "gpt-4",
			},
			wantErr: ErrEmptyAPIKey,
		},
		{
			name: "missing base URL",
			config: Config{
				APIKey: "test-key",
				Model:  "gpt-4",
			},
			wantErr: ErrEmptyBaseURL,
		},
		{
			name: "missing model",
			config: Config{
				BaseURL: "https://api.openai.com/v1",
				APIKey:  "test-key",
			},
			wantErr: ErrEmptyModel,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			client, err := NewClient(tt.config)
			if tt.wantErr != nil {
				if err != tt.wantErr {
					t.Errorf("NewClient() error = %v, wantErr %v", err, tt.wantErr)
				}
				return
			}
			if err != nil {
				t.Errorf("NewClient() unexpected error = %v", err)
				return
			}
			if client == nil {
				t.Error("NewClient() returned nil client")
			}
		})
	}
}

func TestClient_Chat(t *testing.T) {
	// Create a mock server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request
		if r.Method != http.MethodPost {
			t.Errorf("expected POST method, got %s", r.Method)
		}
		if !strings.HasSuffix(r.URL.Path, "/chat/completions") {
			t.Errorf("expected /chat/completions path, got %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer test-key" {
			t.Errorf("expected Bearer test-key, got %s", r.Header.Get("Authorization"))
		}

		// Parse request body
		var req ChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("failed to decode request: %v", err)
			return
		}

		if req.Model != "gpt-4" {
			t.Errorf("expected model gpt-4, got %s", req.Model)
		}
		if len(req.Messages) == 0 {
			t.Error("expected messages, got empty")
		}

		// Send response
		resp := ChatResponse{
			ID:      "chatcmpl-123",
			Object:  "chat.completion",
			Created: time.Now().Unix(),
			Model:   "gpt-4",
			Choices: []Choice{
				{
					Index: 0,
					Message: Message{
						Role:    "assistant",
						Content: "Hello! How can I help you?",
					},
					FinishReason: "stop",
				},
			},
			Usage: Usage{
				PromptTokens:     10,
				CompletionTokens: 8,
				TotalTokens:      18,
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client, err := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-key",
		Model:   "gpt-4",
		Timeout: 10 * time.Second,
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	messages := []Message{
		{Role: "user", Content: "Hello"},
	}

	resp, err := client.Chat(context.Background(), messages)
	if err != nil {
		t.Fatalf("Chat() error = %v", err)
	}

	if resp.ID != "chatcmpl-123" {
		t.Errorf("expected ID chatcmpl-123, got %s", resp.ID)
	}
	if len(resp.Choices) != 1 {
		t.Errorf("expected 1 choice, got %d", len(resp.Choices))
	}
	if resp.Choices[0].Message.Content != "Hello! How can I help you?" {
		t.Errorf("unexpected content: %s", resp.Choices[0].Message.Content)
	}
}

func TestClient_Chat_EmptyMessages(t *testing.T) {
	client, err := NewClient(Config{
		BaseURL: "https://api.openai.com/v1",
		APIKey:  "test-key",
		Model:   "gpt-4",
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	_, err = client.Chat(context.Background(), []Message{})
	if err != ErrEmptyMessages {
		t.Errorf("expected ErrEmptyMessages, got %v", err)
	}
}

func TestClient_ChatStream(t *testing.T) {
	// Create a mock SSE server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Verify request
		if r.Method != http.MethodPost {
			t.Errorf("expected POST method, got %s", r.Method)
		}

		// Parse request body
		var req ChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("failed to decode request: %v", err)
			return
		}

		if !req.Stream {
			t.Error("expected stream=true")
		}

		// Send SSE response
		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")

		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Error("expected http.Flusher")
			return
		}

		// Send chunks
		chunks := []string{
			`{"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4","choices":[{"index":0,"delta":{"role":"assistant","content":""},"finish_reason":null}]}`,
			`{"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}`,
			`{"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}`,
			`{"id":"chatcmpl-123","object":"chat.completion.chunk","created":1234567890,"model":"gpt-4","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}`,
		}

		for _, chunk := range chunks {
			fmt.Fprintf(w, "data: %s\n\n", chunk)
			flusher.Flush()
		}

		fmt.Fprintf(w, "data: [DONE]\n\n")
		flusher.Flush()
	}))
	defer server.Close()

	client, err := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-key",
		Model:   "gpt-4",
		Timeout: 10 * time.Second,
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	messages := []Message{
		{Role: "user", Content: "Hello"},
	}

	eventChan, err := client.ChatStream(context.Background(), messages)
	if err != nil {
		t.Fatalf("ChatStream() error = %v", err)
	}

	var content strings.Builder
	var finishReason string
	var done bool

	for event := range eventChan {
		if event.Error != nil {
			t.Fatalf("unexpected error: %v", event.Error)
		}
		if event.Content != "" {
			content.WriteString(event.Content)
		}
		if event.FinishReason != "" {
			finishReason = event.FinishReason
		}
		if event.Done {
			done = true
		}
	}

	if !done {
		t.Error("expected done=true")
	}
	if content.String() != "Hello!" {
		t.Errorf("expected content 'Hello!', got '%s'", content.String())
	}
	if finishReason != "stop" {
		t.Errorf("expected finish_reason 'stop', got '%s'", finishReason)
	}
}

func TestClient_ChatStream_ContextCanceled(t *testing.T) {
	// Create a slow server
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		
		// Wait for context cancellation
		time.Sleep(5 * time.Second)
	}))
	defer server.Close()

	client, err := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-key",
		Model:   "gpt-4",
		Timeout: 10 * time.Second,
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
	defer cancel()

	messages := []Message{
		{Role: "user", Content: "Hello"},
	}

	eventChan, err := client.ChatStream(ctx, messages)
	if err != nil {
		// Context may be canceled before stream starts
		return
	}

	for event := range eventChan {
		if event.Error == ErrContextCanceled {
			return // Expected
		}
	}
}

func TestClient_ChatWithOptions(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var req ChatRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			t.Errorf("failed to decode request: %v", err)
			return
		}

		// Verify options
		if req.Temperature != 0.7 {
			t.Errorf("expected temperature 0.7, got %f", req.Temperature)
		}
		if req.MaxTokens != 100 {
			t.Errorf("expected max_tokens 100, got %d", req.MaxTokens)
		}

		resp := ChatResponse{
			ID:      "chatcmpl-123",
			Object:  "chat.completion",
			Created: time.Now().Unix(),
			Model:   "gpt-4",
			Choices: []Choice{
				{
					Index: 0,
					Message: Message{
						Role:    "assistant",
						Content: "Test response",
					},
					FinishReason: "stop",
				},
			},
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client, err := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "test-key",
		Model:   "gpt-4",
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	messages := []Message{
		{Role: "user", Content: "Hello"},
	}

	opts := &ChatOptions{
		Temperature: 0.7,
		MaxTokens:   100,
	}

	resp, err := client.ChatWithOptions(context.Background(), messages, opts)
	if err != nil {
		t.Fatalf("ChatWithOptions() error = %v", err)
	}

	if resp.Choices[0].Message.Content != "Test response" {
		t.Errorf("unexpected content: %s", resp.Choices[0].Message.Content)
	}
}

func TestClient_APIError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(APIError{
			Error: struct {
				Message string `json:"message"`
				Type    string `json:"type"`
				Code    string `json:"code"`
			}{
				Message: "Invalid API key",
				Type:    "invalid_request_error",
				Code:    "invalid_api_key",
			},
		})
	}))
	defer server.Close()

	client, err := NewClient(Config{
		BaseURL: server.URL,
		APIKey:  "invalid-key",
		Model:   "gpt-4",
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	messages := []Message{
		{Role: "user", Content: "Hello"},
	}

	_, err = client.Chat(context.Background(), messages)
	if err == nil {
		t.Error("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "Invalid API key") {
		t.Errorf("expected error to contain 'Invalid API key', got: %v", err)
	}
}

func TestClient_GetSetModel(t *testing.T) {
	client, err := NewClient(Config{
		BaseURL: "https://api.openai.com/v1",
		APIKey:  "test-key",
		Model:   "gpt-4",
	})
	if err != nil {
		t.Fatalf("failed to create client: %v", err)
	}

	if client.GetModel() != "gpt-4" {
		t.Errorf("expected model gpt-4, got %s", client.GetModel())
	}

	client.SetModel("gpt-3.5-turbo")
	if client.GetModel() != "gpt-3.5-turbo" {
		t.Errorf("expected model gpt-3.5-turbo, got %s", client.GetModel())
	}
}

func TestClient_ChatEndpoint(t *testing.T) {
	tests := []struct {
		baseURL  string
		expected string
	}{
		{"https://api.openai.com/v1", "https://api.openai.com/v1/chat/completions"},
		{"https://api.openai.com/v1/", "https://api.openai.com/v1/chat/completions"},
		{"http://localhost:8080", "http://localhost:8080/chat/completions"},
	}

	for _, tt := range tests {
		client, err := NewClient(Config{
			BaseURL: tt.baseURL,
			APIKey:  "test-key",
			Model:   "gpt-4",
		})
		if err != nil {
			t.Fatalf("failed to create client: %v", err)
		}

		endpoint := client.chatEndpoint()
		if endpoint != tt.expected {
			t.Errorf("chatEndpoint() = %s, want %s", endpoint, tt.expected)
		}
	}
}
