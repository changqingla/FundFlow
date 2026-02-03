package controller

import (
	"context"

	"fund-analyzer/internal/middleware"
	"fund-analyzer/internal/model"
	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// AIController AI 分析控制器
type AIController struct {
	aiService     service.AIService
	marketService service.MarketService
	newsService   service.NewsService
	sectorService service.SectorService
	fundService   service.FundService
	logger        *zap.Logger
}

// NewAIController 创建 AI 控制器
func NewAIController(
	aiService service.AIService,
	marketService service.MarketService,
	newsService service.NewsService,
	sectorService service.SectorService,
	fundService service.FundService,
	logger *zap.Logger,
) *AIController {
	return &AIController{
		aiService:     aiService,
		marketService: marketService,
		newsService:   newsService,
		sectorService: sectorService,
		fundService:   fundService,
		logger:        logger,
	}
}

// Chat AI 聊天 (SSE)
// POST /api/v1/ai/chat
func (c *AIController) Chat(ctx *gin.Context) {
	// 解析请求
	var req model.ChatRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	// 创建 SSE 写入器
	sseWriter := middleware.NewSSEWriter(ctx)
	if sseWriter == nil {
		response.InternalError(ctx, "SSE not supported")
		return
	}
	defer sseWriter.Close()

	// 创建 channel 接收聊天响应
	chunks := make(chan model.ChatChunk, 100)

	// 启动 goroutine 调用 AI 服务
	go func() {
		err := c.aiService.Chat(sseWriter.Context(), &req, chunks)
		if err != nil {
			c.logger.Error("AI Chat failed", zap.Error(err))
			// 错误已在 service 层通过 channel 发送
		}
	}()

	// 流式发送响应
	if err := sseWriter.StreamChatChunks(chunks); err != nil {
		c.logger.Debug("SSE stream ended", zap.Error(err))
	}
}

// AnalyzeStandard 标准分析 (SSE)
// POST /api/v1/ai/analyze/standard
func (c *AIController) AnalyzeStandard(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	// 创建 SSE 写入器
	sseWriter := middleware.NewSSEWriter(ctx)
	if sseWriter == nil {
		response.InternalError(ctx, "SSE not supported")
		return
	}
	defer sseWriter.Close()

	// 发送状态：正在获取数据
	if err := sseWriter.SendStatus("正在获取市场数据..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 获取市场数据
	marketData, err := c.fetchMarketData(sseWriter.Context(), userID)
	if err != nil {
		c.logger.Error("Failed to fetch market data", zap.Error(err))
		_ = sseWriter.SendError("获取市场数据失败")
		return
	}

	// 发送状态：正在生成分析
	if err := sseWriter.SendStatus("正在生成分析报告..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 创建 channel 接收分析内容
	contents := make(chan string, 100)

	// 启动 goroutine 调用 AI 服务
	go func() {
		err := c.aiService.AnalyzeStandard(sseWriter.Context(), marketData, contents)
		if err != nil {
			c.logger.Error("AI AnalyzeStandard failed", zap.Error(err))
		}
	}()

	// 流式发送响应
	if err := sseWriter.StreamStrings(contents); err != nil {
		c.logger.Debug("SSE stream ended", zap.Error(err))
	}
}

// AnalyzeFast 快速分析 (SSE)
// POST /api/v1/ai/analyze/fast
func (c *AIController) AnalyzeFast(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	// 创建 SSE 写入器
	sseWriter := middleware.NewSSEWriter(ctx)
	if sseWriter == nil {
		response.InternalError(ctx, "SSE not supported")
		return
	}
	defer sseWriter.Close()

	// 发送状态：正在获取数据
	if err := sseWriter.SendStatus("正在获取市场数据..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 获取市场数据（快速分析只获取核心数据）
	marketData, err := c.fetchCoreMarketData(sseWriter.Context(), userID)
	if err != nil {
		c.logger.Error("Failed to fetch market data", zap.Error(err))
		_ = sseWriter.SendError("获取市场数据失败")
		return
	}

	// 发送状态：正在生成分析
	if err := sseWriter.SendStatus("正在生成快速分析..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 创建 channel 接收分析内容
	contents := make(chan string, 100)

	// 启动 goroutine 调用 AI 服务
	go func() {
		err := c.aiService.AnalyzeFast(sseWriter.Context(), marketData, contents)
		if err != nil {
			c.logger.Error("AI AnalyzeFast failed", zap.Error(err))
		}
	}()

	// 流式发送响应
	if err := sseWriter.StreamStrings(contents); err != nil {
		c.logger.Debug("SSE stream ended", zap.Error(err))
	}
}

// AnalyzeDeep 深度研究 (SSE)
// POST /api/v1/ai/analyze/deep
func (c *AIController) AnalyzeDeep(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	// 创建 SSE 写入器
	sseWriter := middleware.NewSSEWriter(ctx)
	if sseWriter == nil {
		response.InternalError(ctx, "SSE not supported")
		return
	}
	defer sseWriter.Close()

	// 发送状态：正在获取数据
	if err := sseWriter.SendStatus("正在获取市场数据..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 获取市场数据
	marketData, err := c.fetchMarketData(sseWriter.Context(), userID)
	if err != nil {
		c.logger.Error("Failed to fetch market data", zap.Error(err))
		_ = sseWriter.SendError("获取市场数据失败")
		return
	}

	// 发送状态：正在进行深度研究
	if err := sseWriter.SendStatus("正在进行深度研究，可能需要搜索相关新闻..."); err != nil {
		c.logger.Debug("SSE send status failed", zap.Error(err))
		return
	}

	// 创建 channel 接收分析内容
	contents := make(chan string, 100)

	// 启动 goroutine 调用 AI 服务
	go func() {
		err := c.aiService.AnalyzeDeep(sseWriter.Context(), marketData, contents)
		if err != nil {
			c.logger.Error("AI AnalyzeDeep failed", zap.Error(err))
		}
	}()

	// 流式发送响应
	if err := sseWriter.StreamStrings(contents); err != nil {
		c.logger.Debug("SSE stream ended", zap.Error(err))
	}
}

// fetchMarketData 获取完整市场数据
func (c *AIController) fetchMarketData(ctx context.Context, userID int64) (*model.MarketData, error) {
	data := &model.MarketData{}

	// 获取市场指数
	indices, err := c.marketService.GetGlobalIndices(ctx)
	if err == nil {
		data.Indices = indices
	}

	// 获取贵金属
	metals, err := c.marketService.GetPreciousMetals(ctx)
	if err == nil {
		data.PreciousMetals = metals
	}

	// 获取快讯
	news, err := c.newsService.GetNewsList(ctx, 20)
	if err == nil {
		data.News = news
	}

	// 获取板块
	sectors, err := c.sectorService.GetSectorList(ctx)
	if err == nil {
		// 只取前 20 个板块
		if len(sectors) > 20 {
			sectors = sectors[:20]
		}
		data.Sectors = sectors
	}

	// 获取用户自选基金
	if userID > 0 {
		funds, err := c.fundService.GetFundList(ctx, userID)
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

	return data, nil
}

// fetchCoreMarketData 获取核心市场数据（用于快速分析）
func (c *AIController) fetchCoreMarketData(ctx context.Context, userID int64) (*model.MarketData, error) {
	data := &model.MarketData{}

	// 获取快讯
	news, err := c.newsService.GetNewsList(ctx, 10)
	if err == nil {
		data.News = news
	}

	// 获取板块（只取前 10 个）
	sectors, err := c.sectorService.GetSectorList(ctx)
	if err == nil {
		if len(sectors) > 10 {
			sectors = sectors[:10]
		}
		data.Sectors = sectors
	}

	// 获取用户自选基金
	if userID > 0 {
		funds, err := c.fundService.GetFundList(ctx, userID)
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

	return data, nil
}
