package controller

import (
	"strconv"

	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// NewsController 快讯控制器
type NewsController struct {
	newsService service.NewsService
	logger      *zap.Logger
}

// NewNewsController 创建快讯控制器
func NewNewsController(newsService service.NewsService, logger *zap.Logger) *NewsController {
	return &NewsController{
		newsService: newsService,
		logger:      logger,
	}
}

// GetNews 获取快讯列表
// GET /api/v1/news?count=50
func (c *NewsController) GetNews(ctx *gin.Context) {
	count, _ := strconv.Atoi(ctx.DefaultQuery("count", "50"))

	news, err := c.newsService.GetNewsList(ctx.Request.Context(), count)
	if err != nil {
		c.logger.Error("GetNews failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get news")
		return
	}

	response.Success(ctx, news)
}
