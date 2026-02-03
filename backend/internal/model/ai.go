package model

// ChatRequest 聊天请求
type ChatRequest struct {
	Message string        `json:"message" binding:"required"`
	History []ChatMessage `json:"history"`
}

// ChatMessage 聊天消息
type ChatMessage struct {
	Role    string `json:"role"` // user/assistant
	Content string `json:"content"`
}

// ChatChunkType 聊天响应块类型
type ChatChunkType string

const (
	ChunkTypeStatus   ChatChunkType = "status"
	ChunkTypeContent  ChatChunkType = "content"
	ChunkTypeToolCall ChatChunkType = "tool_call"
	ChunkTypeDone     ChatChunkType = "done"
	ChunkTypeError    ChatChunkType = "error"
)

// ChatChunk 聊天响应块
type ChatChunk struct {
	Type    ChatChunkType `json:"type"`
	Message string        `json:"message,omitempty"`
	Chunk   string        `json:"chunk,omitempty"`
	Tools   []string      `json:"tools,omitempty"`
}

// MarketData 市场数据（用于 AI 分析）
type MarketData struct {
	Indices       []MarketIndex   `json:"indices"`
	PreciousMetals []PreciousMetal `json:"preciousMetals"`
	News          []NewsItem      `json:"news"`
	Sectors       []Sector        `json:"sectors"`
	Funds         []FundValuation `json:"funds"`
}

// SearchResult 搜索结果
type SearchResult struct {
	Title   string `json:"title"`
	URL     string `json:"url"`
	Snippet string `json:"snippet"`
}
