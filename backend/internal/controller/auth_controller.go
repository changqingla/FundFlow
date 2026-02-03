package controller

import (
	"errors"
	"strings"

	"fund-analyzer/internal/middleware"
	"fund-analyzer/internal/model"
	"fund-analyzer/internal/repository"
	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// AuthController 认证控制器
type AuthController struct {
	authService service.AuthService
	logger      *zap.Logger
}

// NewAuthController 创建认证控制器
func NewAuthController(authService service.AuthService, logger *zap.Logger) *AuthController {
	return &AuthController{
		authService: authService,
		logger:      logger,
	}
}

// Register 用户注册
func (c *AuthController) Register(ctx *gin.Context) {
	var req model.RegisterRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	err := c.authService.Register(ctx.Request.Context(), &req)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidEmail):
			response.BadRequest(ctx, "Invalid email format")
		case errors.Is(err, service.ErrWeakPassword):
			response.BadRequest(ctx, "Password must be at least 8 characters with letters and numbers")
		case errors.Is(err, repository.ErrUserExists):
			response.Conflict(ctx, "Email already registered")
		default:
			c.logger.Error("Register failed", zap.Error(err))
			response.InternalError(ctx, "Registration failed")
		}
		return
	}

	response.SuccessWithMessage(ctx, "Verification code sent to your email", nil)
}

// VerifyEmail 验证邮箱
func (c *AuthController) VerifyEmail(ctx *gin.Context) {
	var req model.VerifyEmailRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	_, err := c.authService.VerifyEmail(ctx.Request.Context(), req.Email, req.Code)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidCode):
			response.BadRequest(ctx, "Invalid verification code")
		case errors.Is(err, service.ErrCodeExpired):
			response.BadRequest(ctx, "Verification code expired")
		default:
			c.logger.Error("VerifyEmail failed", zap.Error(err))
			response.InternalError(ctx, "Verification failed")
		}
		return
	}

	response.SuccessWithMessage(ctx, "Email verified successfully", nil)
}

// Login 用户登录
func (c *AuthController) Login(ctx *gin.Context) {
	var req model.LoginRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	resp, err := c.authService.Login(ctx.Request.Context(), req.Email, req.Password)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidCredentials):
			response.Unauthorized(ctx, "Invalid email or password")
		case errors.Is(err, service.ErrUserLocked):
			response.Forbidden(ctx, "Account is locked, please try again later")
		default:
			c.logger.Error("Login failed", zap.Error(err))
			response.InternalError(ctx, "Login failed")
		}
		return
	}

	response.Success(ctx, resp)
}

// Logout 用户登出
func (c *AuthController) Logout(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	// 获取 Token
	authHeader := ctx.GetHeader("Authorization")
	parts := strings.SplitN(authHeader, " ", 2)
	if len(parts) != 2 {
		response.BadRequest(ctx, "Invalid authorization header")
		return
	}
	token := parts[1]

	err := c.authService.Logout(ctx.Request.Context(), userID, token)
	if err != nil {
		c.logger.Error("Logout failed", zap.Error(err))
		response.InternalError(ctx, "Logout failed")
		return
	}

	response.SuccessWithMessage(ctx, "Logged out successfully", nil)
}

// RefreshToken 刷新 Token
func (c *AuthController) RefreshToken(ctx *gin.Context) {
	var req model.RefreshTokenRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	tokenPair, err := c.authService.RefreshToken(ctx.Request.Context(), req.RefreshToken)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidToken):
			response.Unauthorized(ctx, "Invalid refresh token")
		case errors.Is(err, service.ErrTokenExpired):
			response.Unauthorized(ctx, "Refresh token expired")
		default:
			c.logger.Error("RefreshToken failed", zap.Error(err))
			response.InternalError(ctx, "Token refresh failed")
		}
		return
	}

	response.Success(ctx, tokenPair)
}

// ForgotPassword 忘记密码
func (c *AuthController) ForgotPassword(ctx *gin.Context) {
	var req model.ForgotPasswordRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	err := c.authService.ForgotPassword(ctx.Request.Context(), req.Email)
	if err != nil {
		c.logger.Error("ForgotPassword failed", zap.Error(err))
		// 为了安全，不暴露具体错误
	}

	// 无论成功失败都返回相同消息
	response.SuccessWithMessage(ctx, "If the email exists, a reset code has been sent", nil)
}

// ResetPassword 重置密码
func (c *AuthController) ResetPassword(ctx *gin.Context) {
	var req model.ResetPasswordRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		response.BadRequest(ctx, "Invalid request body")
		return
	}

	err := c.authService.ResetPassword(ctx.Request.Context(), req.Email, req.Code, req.NewPassword)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidCode):
			response.BadRequest(ctx, "Invalid verification code")
		case errors.Is(err, service.ErrCodeExpired):
			response.BadRequest(ctx, "Verification code expired")
		case errors.Is(err, service.ErrWeakPassword):
			response.BadRequest(ctx, "Password must be at least 8 characters with letters and numbers")
		default:
			c.logger.Error("ResetPassword failed", zap.Error(err))
			response.InternalError(ctx, "Password reset failed")
		}
		return
	}

	response.SuccessWithMessage(ctx, "Password reset successfully", nil)
}

// GetCurrentUser 获取当前用户信息
func (c *AuthController) GetCurrentUser(ctx *gin.Context) {
	userID := middleware.GetUserID(ctx)

	user, err := c.authService.GetUserByID(ctx.Request.Context(), userID)
	if err != nil {
		c.logger.Error("GetCurrentUser failed", zap.Error(err))
		response.InternalError(ctx, "Failed to get user info")
		return
	}

	response.Success(ctx, user)
}
