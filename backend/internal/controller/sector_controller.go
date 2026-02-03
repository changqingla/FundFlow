package controller

import (
	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// SectorController 板块控制器
type SectorController struct {
	sectorService service.SectorService
	logger        *zap.Logger
}

// NewSectorController 创建板块控制器
func NewSectorController(sectorService service.SectorService, logger *zap.Logger) *SectorController {
	return &SectorController{
		sectorService: sectorService,
		logger:        logger,
	}
}

// GetSectors 获取板块列表
// GET /api/v1/sectors?sort=changeRate&order=desc
func (c *SectorController) GetSectors(ctx *gin.Context) {
	sortField := ctx.DefaultQuery("sort", "changeRate")
	order := ctx.DefaultQuery("order", "desc")

	sectors, err := c.sectorService.GetSectorList(ctx.Request.Context())
	if err != nil {
		c.logger.Error("GetSectors failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get sectors")
		return
	}

	// 排序
	descending := order == "desc"
	sectors = c.sectorService.SortSectors(sectors, sortField, descending)

	response.Success(ctx, sectors)
}

// GetSectorFunds 获取板块基金
// GET /api/v1/sectors/:id/funds?sort=year1&order=desc
func (c *SectorController) GetSectorFunds(ctx *gin.Context) {
	sectorID := ctx.Param("id")
	sortField := ctx.DefaultQuery("sort", "year1")
	order := ctx.DefaultQuery("order", "desc")

	funds, err := c.sectorService.GetSectorFunds(ctx.Request.Context(), sectorID)
	if err != nil {
		c.logger.Error("GetSectorFunds failed", zap.Error(err), zap.String("sectorID", sectorID))
		response.InternalError(ctx, "Failed to get sector funds")
		return
	}

	// 排序
	descending := order == "desc"
	funds = service.SortSectorFunds(funds, sortField, descending)

	response.Success(ctx, funds)
}

// GetCategories 获取板块分类
// GET /api/v1/sectors/categories
func (c *SectorController) GetCategories(ctx *gin.Context) {
	categories := c.sectorService.GetSectorCategories()
	response.Success(ctx, categories)
}
