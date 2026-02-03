package controller

import (
	"strconv"

	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// MarketController 市场数据控制器
type MarketController struct {
	marketService service.MarketService
	logger        *zap.Logger
}

// NewMarketController 创建市场数据控制器
func NewMarketController(marketService service.MarketService, logger *zap.Logger) *MarketController {
	return &MarketController{
		marketService: marketService,
		logger:        logger,
	}
}

// GetIndices 获取全球市场指数
// GET /api/v1/market/indices
func (c *MarketController) GetIndices(ctx *gin.Context) {
	indices, err := c.marketService.GetGlobalIndices(ctx.Request.Context())
	if err != nil {
		c.logger.Error("GetIndices failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get market indices")
		return
	}

	response.Success(ctx, indices)
}

// GetPreciousMetals 获取贵金属实时价格
// GET /api/v1/market/precious-metals
func (c *MarketController) GetPreciousMetals(ctx *gin.Context) {
	metals, err := c.marketService.GetPreciousMetals(ctx.Request.Context())
	if err != nil {
		c.logger.Error("GetPreciousMetals failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get precious metals")
		return
	}

	response.Success(ctx, metals)
}

// GetGoldHistory 获取历史金价
// GET /api/v1/market/gold-history?days=30
func (c *MarketController) GetGoldHistory(ctx *gin.Context) {
	days, _ := strconv.Atoi(ctx.DefaultQuery("days", "30"))

	history, err := c.marketService.GetGoldHistory(ctx.Request.Context(), days)
	if err != nil {
		c.logger.Error("GetGoldHistory failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get gold history")
		return
	}

	response.Success(ctx, history)
}

// GetVolumeTrend 获取成交量趋势
// GET /api/v1/market/volume?days=7
func (c *MarketController) GetVolumeTrend(ctx *gin.Context) {
	days, _ := strconv.Atoi(ctx.DefaultQuery("days", "7"))

	volumes, err := c.marketService.GetVolumeTrend(ctx.Request.Context(), days)
	if err != nil {
		c.logger.Error("GetVolumeTrend failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get volume trend")
		return
	}

	response.Success(ctx, volumes)
}

// GetMinuteData 获取上证分时数据
// GET /api/v1/market/minute-data?minutes=30
func (c *MarketController) GetMinuteData(ctx *gin.Context) {
	minutes, _ := strconv.Atoi(ctx.DefaultQuery("minutes", "30"))

	data, err := c.marketService.GetMinuteData(ctx.Request.Context(), minutes)
	if err != nil {
		c.logger.Error("GetMinuteData failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get minute data")
		return
	}

	response.Success(ctx, data)
}
