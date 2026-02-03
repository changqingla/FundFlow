package controller

import (
	"errors"

	"fund-analyzer/internal/middleware"
	"fund-analyzer/internal/repository"
	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// FundController 基金控制器
type FundController struct {
	fundService service.FundService
	logger      *zap.Logger
}

// NewFundController 创建基金控制器
func NewFundController(fundService service.FundService, logger *zap.Logger) *FundController {
	return &FundController{
		fundService: fundService,
		logger:      logger,
	}
}

// GetFunds 获取自选基金列表
// GET /api/v1/funds
func (c *FundController) GetFunds(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	funds, err := c.fundService.GetFundList(ctx.Request.Context(), userID)
	if err != nil {
		c.logger.Error("GetFunds failed", zap.Error(err), zap.Int64("userID", userID))
		response.InternalError(ctx, "Failed to get funds")
		return
	}

	response.Success(ctx, funds)
}

// AddFund 添加基金
// POST /api/v1/funds
func (c *FundController) AddFund(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	var req struct {
		Code string `json:"code" binding:"required"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	fund, err := c.fundService.AddFund(ctx.Request.Context(), userID, req.Code)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrFundExists):
			response.Conflict(ctx, "Fund already exists")
		default:
			c.logger.Error("AddFund failed", zap.Error(err), zap.String("code", req.Code))
			response.BadRequest(ctx, "Invalid fund code")
		}
		return
	}

	response.Success(ctx, fund)
}

// DeleteFund 删除基金
// DELETE /api/v1/funds/:code
func (c *FundController) DeleteFund(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)
	code := ctx.Param("code")

	err := c.fundService.DeleteFund(ctx.Request.Context(), userID, code)
	if err != nil {
		if errors.Is(err, repository.ErrFundNotFound) {
			response.NotFound(ctx, "Fund not found")
			return
		}
		c.logger.Error("DeleteFund failed", zap.Error(err), zap.String("code", code))
		response.InternalError(ctx, "Failed to delete fund")
		return
	}

	response.SuccessWithMessage(ctx, "Fund deleted successfully", nil)
}

// UpdateHoldStatus 更新持有状态
// PUT /api/v1/funds/:code/hold
func (c *FundController) UpdateHoldStatus(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)
	code := ctx.Param("code")

	var req struct {
		IsHold bool `json:"isHold"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	err := c.fundService.UpdateHoldStatus(ctx.Request.Context(), userID, code, req.IsHold)
	if err != nil {
		if errors.Is(err, repository.ErrFundNotFound) {
			response.NotFound(ctx, "Fund not found")
			return
		}
		c.logger.Error("UpdateHoldStatus failed", zap.Error(err), zap.String("code", code))
		response.InternalError(ctx, "Failed to update hold status")
		return
	}

	response.SuccessWithMessage(ctx, "Hold status updated", nil)
}

// UpdateSectors 更新板块标记
// PUT /api/v1/funds/:code/sectors
func (c *FundController) UpdateSectors(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)
	code := ctx.Param("code")

	var req struct {
		Sectors []string `json:"sectors"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	err := c.fundService.UpdateSectors(ctx.Request.Context(), userID, code, req.Sectors)
	if err != nil {
		if errors.Is(err, repository.ErrFundNotFound) {
			response.NotFound(ctx, "Fund not found")
			return
		}
		c.logger.Error("UpdateSectors failed", zap.Error(err), zap.String("code", code))
		response.InternalError(ctx, "Failed to update sectors")
		return
	}

	response.SuccessWithMessage(ctx, "Sectors updated", nil)
}

// GetValuation 获取基金估值
// GET /api/v1/funds/:code/valuation
func (c *FundController) GetValuation(ctx *gin.Context) {
	code := ctx.Param("code")

	// 先搜索基金获取 fundKey
	fund, err := c.fundService.SearchFund(ctx.Request.Context(), code)
	if err != nil {
		response.NotFound(ctx, "Fund not found")
		return
	}

	valuation, err := c.fundService.GetFundValuation(ctx.Request.Context(), fund.FundKey)
	if err != nil {
		c.logger.Error("GetValuation failed", zap.Error(err), zap.String("code", code))
		response.InternalError(ctx, "Failed to get valuation")
		return
	}

	response.Success(ctx, valuation)
}
