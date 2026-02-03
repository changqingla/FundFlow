package service

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"fund-analyzer/internal/config"
	"fund-analyzer/internal/crawler"
	"fund-analyzer/internal/model"
	"fund-analyzer/pkg/llm"
)

// AIService AI 分析服务接口
type AIService interface {
	Chat(ctx context.Context, req *model.ChatRequest, stream chan<- model.ChatChunk) error
	AnalyzeStandard(ctx context.Context, data *model.MarketData, stream chan<- string) error
	AnalyzeFast(ctx context.Context, data *model.MarketData, stream chan<- string) error
	AnalyzeDeep(ctx context.Context, data *model.MarketData, stream chan<- string) error
	SearchNews(ctx context.Context, query string) ([]model.SearchResult, error)
	FetchWebpage(ctx context.Context, url string) (string, error)
}

// aiService AI 服务实现
type aiService struct {
	llmClient       *llm.Client
	ddgCrawler      crawler.DuckDuckGoCrawler
	webpageFetcher  crawler.WebpageFetcher
	dataMatcher     DataMatcher
	marketService   MarketService
	newsService     NewsService
	sectorService   SectorService
	fundService     FundService
}

// NewAIService 创建 AI 服务
func NewAIService(
	cfg *config.LLMConfig,
	ddgCrawler crawler.DuckDuckGoCrawler,
	webpageFetcher crawler.WebpageFetcher,
	dataMatcher DataMatcher,
	marketService MarketService,
	newsService NewsService,
	sectorService SectorService,
	fundService FundService,
) (AIService, error) {
	// 创建 LLM 客户端
	timeout := time.Duration(cfg.Timeout) * time.Second
	if timeout == 0 {
		timeout = 120 * time.Second
	}

	llmClient, err := llm.NewClient(llm.Config{
		BaseURL: cfg.BaseURL,
		APIKey:  cfg.APIKey,
		Model:   cfg.Model,
		Timeout: timeout,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create LLM client: %w", err)
	}

	return &aiService{
		llmClient:      llmClient,
		ddgCrawler:     ddgCrawler,
		webpageFetcher: webpageFetcher,
		dataMatcher:    dataMatcher,
		marketService:  marketService,
		newsService:    newsService,
		sectorService:  sectorService,
		fundService:    fundService,
	}, nil
}

// Chat 多轮对话
func (s *aiService) Chat(ctx context.Context, req *model.ChatRequest, stream chan<- model.ChatChunk) error {
	defer close(stream)

	// 发送状态：正在分析问题
	stream <- model.ChatChunk{
		Type:    model.ChunkTypeStatus,
		Message: "正在分析您的问题...",
	}

	// 使用数据匹配器确定需要获取的数据模块
	modules := s.dataMatcher.Match(req.Message)

	// 发送状态：正在获取数据
	if len(modules) > 0 {
		moduleNames := make([]string, len(modules))
		for i, m := range modules {
			moduleNames[i] = GetModuleDisplayName(m)
		}
		stream <- model.ChatChunk{
			Type:    model.ChunkTypeStatus,
			Message: fmt.Sprintf("正在获取相关数据：%s", strings.Join(moduleNames, "、")),
		}
	}

	// 获取相关数据
	marketData, err := s.fetchMarketData(ctx, modules, 0)
	if err != nil {
		stream <- model.ChatChunk{
			Type:    model.ChunkTypeError,
			Message: fmt.Sprintf("获取数据失败: %v", err),
		}
		return err
	}

	// 构建系统提示词
	systemPrompt := buildChatSystemPrompt(marketData)

	// 构建消息列表
	messages := []llm.Message{
		{Role: "system", Content: systemPrompt},
	}

	// 添加历史消息
	for _, msg := range req.History {
		messages = append(messages, llm.Message{
			Role:    msg.Role,
			Content: msg.Content,
		})
	}

	// 添加当前用户消息
	messages = append(messages, llm.Message{
		Role:    "user",
		Content: req.Message,
	})

	// 发送状态：正在生成回复
	stream <- model.ChatChunk{
		Type:    model.ChunkTypeStatus,
		Message: "正在生成回复...",
	}

	// 调用 LLM 流式生成
	eventChan, err := s.llmClient.ChatStream(ctx, messages)
	if err != nil {
		stream <- model.ChatChunk{
			Type:    model.ChunkTypeError,
			Message: fmt.Sprintf("AI 服务调用失败: %v", err),
		}
		return err
	}

	// 处理流式响应
	for event := range eventChan {
		if event.Error != nil {
			stream <- model.ChatChunk{
				Type:    model.ChunkTypeError,
				Message: event.Error.Error(),
			}
			return event.Error
		}

		if event.Content != "" {
			stream <- model.ChatChunk{
				Type:  model.ChunkTypeContent,
				Chunk: event.Content,
			}
		}

		if event.Done {
			stream <- model.ChatChunk{
				Type: model.ChunkTypeDone,
			}
			break
		}
	}

	return nil
}

// AnalyzeStandard 标准分析
func (s *aiService) AnalyzeStandard(ctx context.Context, data *model.MarketData, stream chan<- string) error {
	defer close(stream)

	// 构建标准分析提示词
	systemPrompt := buildStandardAnalysisPrompt()
	userPrompt := buildMarketDataPrompt(data)

	messages := []llm.Message{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userPrompt},
	}

	// 调用 LLM 流式生成
	eventChan, err := s.llmClient.ChatStream(ctx, messages)
	if err != nil {
		return err
	}

	// 处理流式响应
	for event := range eventChan {
		if event.Error != nil {
			return event.Error
		}

		if event.Content != "" {
			stream <- event.Content
		}

		if event.Done {
			break
		}
	}

	return nil
}

// AnalyzeFast 快速分析
func (s *aiService) AnalyzeFast(ctx context.Context, data *model.MarketData, stream chan<- string) error {
	defer close(stream)

	// 构建快速分析提示词（更简洁）
	systemPrompt := buildFastAnalysisPrompt()
	userPrompt := buildMarketDataPrompt(data)

	messages := []llm.Message{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userPrompt},
	}

	// 调用 LLM 流式生成
	eventChan, err := s.llmClient.ChatStream(ctx, messages)
	if err != nil {
		return err
	}

	// 处理流式响应
	for event := range eventChan {
		if event.Error != nil {
			return event.Error
		}

		if event.Content != "" {
			stream <- event.Content
		}

		if event.Done {
			break
		}
	}

	return nil
}

// AnalyzeDeep 深度研究（ReAct Agent）
func (s *aiService) AnalyzeDeep(ctx context.Context, data *model.MarketData, stream chan<- string) error {
	defer close(stream)

	// 定义可用工具
	tools := []llm.Tool{
		{
			Type: "function",
			Function: llm.Function{
				Name:        "search_news",
				Description: "搜索最近一周的相关新闻，用于获取更多市场信息和背景资料",
				Parameters: map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"query": map[string]interface{}{
							"type":        "string",
							"description": "搜索关键词，如'A股市场'、'科技板块'等",
						},
					},
					"required": []string{"query"},
				},
			},
		},
		{
			Type: "function",
			Function: llm.Function{
				Name:        "fetch_webpage",
				Description: "获取网页内容，用于深入了解某个新闻或文章的详细信息",
				Parameters: map[string]interface{}{
					"type": "object",
					"properties": map[string]interface{}{
						"url": map[string]interface{}{
							"type":        "string",
							"description": "要获取的网页 URL",
						},
					},
					"required": []string{"url"},
				},
			},
		},
	}

	// 构建深度分析提示词
	systemPrompt := buildDeepAnalysisPrompt()
	userPrompt := buildMarketDataPrompt(data)

	messages := []llm.Message{
		{Role: "system", Content: systemPrompt},
		{Role: "user", Content: userPrompt},
	}

	// ReAct 循环
	maxIterations := 5
	for i := 0; i < maxIterations; i++ {
		// 调用 LLM（带工具）
		eventChan, err := s.llmClient.ChatStreamWithOptions(ctx, messages, &llm.ChatOptions{
			Tools:      tools,
			ToolChoice: "auto",
		})
		if err != nil {
			return err
		}

		// 收集响应
		var contentBuilder strings.Builder
		var toolCalls []llm.ToolCall
		var finishReason string

		for event := range eventChan {
			if event.Error != nil {
				return event.Error
			}

			if event.Content != "" {
				contentBuilder.WriteString(event.Content)
				stream <- event.Content
			}

			if len(event.ToolCalls) > 0 {
				toolCalls = append(toolCalls, event.ToolCalls...)
			}

			if event.FinishReason != "" {
				finishReason = event.FinishReason
			}

			if event.Done {
				break
			}
		}

		// 如果没有工具调用，结束循环
		if len(toolCalls) == 0 || finishReason == "stop" {
			break
		}

		// 添加助手消息
		assistantContent := contentBuilder.String()
		messages = append(messages, llm.Message{
			Role:    "assistant",
			Content: assistantContent,
		})

		// 处理工具调用
		for _, tc := range toolCalls {
			// 发送工具调用状态
			stream <- fmt.Sprintf("\n\n🔧 正在调用工具: %s\n", tc.Function.Name)

			// 执行工具
			result, err := s.executeToolCall(ctx, tc)
			if err != nil {
				result = fmt.Sprintf("工具调用失败: %v", err)
			}

			// 发送工具结果摘要
			resultSummary := result
			if len(resultSummary) > 200 {
				resultSummary = resultSummary[:200] + "..."
			}
			stream <- fmt.Sprintf("📋 工具结果: %s\n\n", resultSummary)

			// 添加工具结果消息
			messages = append(messages, llm.Message{
				Role:    "tool",
				Content: result,
				Name:    tc.Function.Name,
			})
		}
	}

	return nil
}

// SearchNews 搜索新闻
func (s *aiService) SearchNews(ctx context.Context, query string) ([]model.SearchResult, error) {
	return s.ddgCrawler.Search(ctx, query, 10)
}

// FetchWebpage 获取网页内容
func (s *aiService) FetchWebpage(ctx context.Context, url string) (string, error) {
	return s.webpageFetcher.Fetch(ctx, url)
}

// executeToolCall 执行工具调用
func (s *aiService) executeToolCall(ctx context.Context, tc llm.ToolCall) (string, error) {
	switch tc.Function.Name {
	case "search_news":
		var args struct {
			Query string `json:"query"`
		}
		if err := json.Unmarshal([]byte(tc.Function.Arguments), &args); err != nil {
			return "", fmt.Errorf("invalid arguments: %w", err)
		}

		results, err := s.SearchNews(ctx, args.Query)
		if err != nil {
			return "", err
		}

		// 格式化搜索结果
		var sb strings.Builder
		sb.WriteString(fmt.Sprintf("搜索 \"%s\" 的结果:\n\n", args.Query))
		for i, r := range results {
			sb.WriteString(fmt.Sprintf("%d. %s\n", i+1, r.Title))
			sb.WriteString(fmt.Sprintf("   URL: %s\n", r.URL))
			sb.WriteString(fmt.Sprintf("   摘要: %s\n\n", r.Snippet))
		}
		return sb.String(), nil

	case "fetch_webpage":
		var args struct {
			URL string `json:"url"`
		}
		if err := json.Unmarshal([]byte(tc.Function.Arguments), &args); err != nil {
			return "", fmt.Errorf("invalid arguments: %w", err)
		}

		content, err := s.FetchWebpage(ctx, args.URL)
		if err != nil {
			return "", err
		}

		// 限制内容长度
		if len(content) > 5000 {
			content = content[:5000] + "\n\n[内容已截断...]"
		}

		return fmt.Sprintf("网页内容 (%s):\n\n%s", args.URL, content), nil

	default:
		return "", fmt.Errorf("unknown tool: %s", tc.Function.Name)
	}
}

// fetchMarketData 获取市场数据
func (s *aiService) fetchMarketData(ctx context.Context, modules []DataModule, userID int64) (*model.MarketData, error) {
	data := &model.MarketData{}

	for _, module := range modules {
		switch module {
		case ModuleMarketIndices:
			indices, err := s.marketService.GetGlobalIndices(ctx)
			if err == nil {
				data.Indices = indices
			}

		case ModulePreciousMetals:
			metals, err := s.marketService.GetPreciousMetals(ctx)
			if err == nil {
				data.PreciousMetals = metals
			}

		case ModuleNews:
			news, err := s.newsService.GetNewsList(ctx, 20)
			if err == nil {
				data.News = news
			}

		case ModuleSectors:
			sectors, err := s.sectorService.GetSectorList(ctx)
			if err == nil {
				// 只取前 20 个板块
				if len(sectors) > 20 {
					sectors = sectors[:20]
				}
				data.Sectors = sectors
			}

		case ModuleFunds:
			if userID > 0 {
				funds, err := s.fundService.GetFundList(ctx, userID)
				if err == nil {
					valuations := make([]model.FundValuation, 0, len(funds))
					for _, f := range funds {
						if f.Valuation != nil {
							valuations = append(valuations, *f.Valuation)
						}
					}
					data.Funds = valuations
				}
			}
		}
	}

	return data, nil
}

// buildChatSystemPrompt 构建聊天系统提示词
func buildChatSystemPrompt(data *model.MarketData) string {
	var sb strings.Builder

	sb.WriteString(`你是一个专业的基金投资分析助手，名叫"小基"。你的职责是帮助用户分析市场行情、解答投资问题、提供投资建议。

## 你的特点
- 专业：具备丰富的金融知识和市场分析能力
- 客观：基于数据分析，不做主观臆断
- 谨慎：始终提醒用户投资有风险
- 友好：用通俗易懂的语言解释复杂概念

## 当前市场数据
`)

	// 添加市场指数数据
	if len(data.Indices) > 0 {
		sb.WriteString("\n### 市场指数\n")
		for _, idx := range data.Indices {
			status := "📈"
			if !idx.IsUp {
				status = "📉"
			}
			sb.WriteString(fmt.Sprintf("- %s %s: %s (%s)\n", status, idx.Name, idx.Price, idx.Change))
		}
	}

	// 添加贵金属数据
	if len(data.PreciousMetals) > 0 {
		sb.WriteString("\n### 贵金属\n")
		for _, metal := range data.PreciousMetals {
			status := "📈"
			if metal.Change < 0 {
				status = "📉"
			}
			sb.WriteString(fmt.Sprintf("- %s %s: %.2f %s (%s)\n", status, metal.Name, metal.Price, metal.Unit, metal.ChangeRate))
		}
	}

	// 添加快讯数据
	if len(data.News) > 0 {
		sb.WriteString("\n### 最新快讯\n")
		count := len(data.News)
		if count > 10 {
			count = 10
		}
		for i := 0; i < count; i++ {
			news := data.News[i]
			evaluate := ""
			if news.Evaluate == "利好" {
				evaluate = "🔴利好"
			} else if news.Evaluate == "利空" {
				evaluate = "🟢利空"
			}
			sb.WriteString(fmt.Sprintf("- %s %s\n", evaluate, news.Title))
		}
	}

	// 添加板块数据
	if len(data.Sectors) > 0 {
		sb.WriteString("\n### 热门板块\n")
		count := len(data.Sectors)
		if count > 10 {
			count = 10
		}
		for i := 0; i < count; i++ {
			sector := data.Sectors[i]
			sb.WriteString(fmt.Sprintf("- %s: %s (主力净流入: %s)\n", sector.Name, sector.ChangeRate, sector.MainNetInflow))
		}
	}

	// 添加基金数据
	if len(data.Funds) > 0 {
		sb.WriteString("\n### 用户自选基金\n")
		for _, fund := range data.Funds {
			status := "📈"
			if strings.HasPrefix(fund.DayGrowth, "-") {
				status = "📉"
			}
			sb.WriteString(fmt.Sprintf("- %s %s: 估值 %s (%s)\n", status, fund.Name, fund.Valuation, fund.DayGrowth))
		}
	}

	sb.WriteString(`
## 回复要求
1. 基于上述市场数据回答用户问题
2. 如果用户问题与数据无关，可以基于你的知识回答
3. 投资建议要谨慎，始终提醒风险
4. 使用 Markdown 格式组织回复
5. 回复要简洁明了，重点突出
`)

	return sb.String()
}

// buildStandardAnalysisPrompt 构建标准分析提示词
func buildStandardAnalysisPrompt() string {
	return `你是一个专业的基金投资分析师。请根据提供的市场数据，生成一份全面的市场分析报告。

## 报告结构要求

### 一、市场趋势分析
- 分析主要指数的走势
- 判断当前市场处于什么阶段（牛市/熊市/震荡）
- 分析成交量变化的含义

### 二、板块机会分析
- 分析涨幅靠前的板块及其原因
- 分析资金流向，找出主力关注的方向
- 预判可能的轮动方向

### 三、基金组合建议
- 根据市场情况给出配置建议
- 推荐关注的基金类型
- 给出仓位建议

### 四、风险提示
- 分析当前市场的主要风险
- 需要关注的利空因素
- 给出风险控制建议

## 输出要求
1. 使用 Markdown 格式
2. 分析要有理有据，引用具体数据
3. 建议要具体可操作
4. 语言专业但易懂
5. 总字数控制在 1500-2000 字`
}

// buildFastAnalysisPrompt 构建快速分析提示词
func buildFastAnalysisPrompt() string {
	return `你是一个专业的基金投资分析师。请根据提供的市场数据，生成一份简明扼要的市场分析报告。

## 报告要求
1. 用 3-5 句话概括今日市场整体表现
2. 列出 3 个最值得关注的板块及原因
3. 给出一句话投资建议
4. 提示一个主要风险点

## 输出要求
1. 使用 Markdown 格式
2. 总字数控制在 300-500 字
3. 重点突出，言简意赅
4. 数据引用要准确`
}

// buildDeepAnalysisPrompt 构建深度分析提示词
func buildDeepAnalysisPrompt() string {
	return `你是一个专业的基金投资研究员，具备深度研究能力。你可以使用以下工具来获取更多信息：

## 可用工具
1. search_news: 搜索最近的相关新闻
2. fetch_webpage: 获取网页详细内容

## 研究流程
1. 首先分析提供的市场数据
2. 根据数据中的热点，使用 search_news 搜索相关新闻
3. 如果需要深入了解某个新闻，使用 fetch_webpage 获取详情
4. 综合所有信息，生成深度研究报告

## 报告结构
### 一、市场概况
- 主要指数表现
- 市场情绪分析

### 二、热点追踪
- 当前市场热点
- 热点背后的逻辑
- 相关新闻和事件

### 三、深度分析
- 行业/板块深度分析
- 政策影响分析
- 资金流向分析

### 四、投资策略
- 短期策略建议
- 中长期布局建议
- 风险控制建议

## 注意事项
1. 每次最多调用 3 次工具
2. 搜索关键词要精准
3. 分析要有深度，不要泛泛而谈
4. 引用新闻时要注明来源`
}

// buildMarketDataPrompt 构建市场数据提示词
func buildMarketDataPrompt(data *model.MarketData) string {
	var sb strings.Builder

	sb.WriteString("# 当前市场数据\n\n")

	// 市场指数
	if len(data.Indices) > 0 {
		sb.WriteString("## 市场指数\n")
		sb.WriteString("| 指数名称 | 最新价 | 涨跌幅 |\n")
		sb.WriteString("|---------|--------|--------|\n")
		for _, idx := range data.Indices {
			sb.WriteString(fmt.Sprintf("| %s | %s | %s |\n", idx.Name, idx.Price, idx.Change))
		}
		sb.WriteString("\n")
	}

	// 贵金属
	if len(data.PreciousMetals) > 0 {
		sb.WriteString("## 贵金属\n")
		sb.WriteString("| 品种 | 价格 | 涨跌幅 |\n")
		sb.WriteString("|------|------|--------|\n")
		for _, metal := range data.PreciousMetals {
			sb.WriteString(fmt.Sprintf("| %s | %.2f %s | %s |\n", metal.Name, metal.Price, metal.Unit, metal.ChangeRate))
		}
		sb.WriteString("\n")
	}

	// 快讯
	if len(data.News) > 0 {
		sb.WriteString("## 最新快讯\n")
		for i, news := range data.News {
			if i >= 15 {
				break
			}
			evaluate := ""
			if news.Evaluate != "" {
				evaluate = fmt.Sprintf("[%s]", news.Evaluate)
			}
			sb.WriteString(fmt.Sprintf("- %s %s\n", evaluate, news.Title))
		}
		sb.WriteString("\n")
	}

	// 板块
	if len(data.Sectors) > 0 {
		sb.WriteString("## 行业板块（按涨跌幅排序）\n")
		sb.WriteString("| 板块名称 | 涨跌幅 | 主力净流入 | 主力占比 |\n")
		sb.WriteString("|---------|--------|-----------|----------|\n")
		for i, sector := range data.Sectors {
			if i >= 20 {
				break
			}
			sb.WriteString(fmt.Sprintf("| %s | %s | %s | %s |\n",
				sector.Name, sector.ChangeRate, sector.MainNetInflow, sector.MainInflowRatio))
		}
		sb.WriteString("\n")
	}

	// 基金
	if len(data.Funds) > 0 {
		sb.WriteString("## 用户自选基金\n")
		sb.WriteString("| 基金名称 | 估值 | 日涨幅 | 连涨/跌 |\n")
		sb.WriteString("|---------|------|--------|--------|\n")
		for _, fund := range data.Funds {
			consecutive := fmt.Sprintf("%d天", fund.ConsecutiveDays)
			if fund.ConsecutiveDays > 0 {
				consecutive = fmt.Sprintf("连涨%d天", fund.ConsecutiveDays)
			} else if fund.ConsecutiveDays < 0 {
				consecutive = fmt.Sprintf("连跌%d天", -fund.ConsecutiveDays)
			}
			sb.WriteString(fmt.Sprintf("| %s | %s | %s | %s |\n",
				fund.Name, fund.Valuation, fund.DayGrowth, consecutive))
		}
		sb.WriteString("\n")
	}

	sb.WriteString("\n请根据以上数据进行分析。")

	return sb.String()
}
