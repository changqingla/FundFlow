package middleware

import (
	"strings"

	"fund-analyzer/internal/service"
	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
)

// ContextKeyUserID 用户 ID 上下文键
const ContextKeyUserID = "user_id"

// ContextKeyUserEmail 用户邮箱上下文键
const ContextKeyUserEmail = "user_email"

// Auth 认证中间件
func Auth(authService service.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		// 获取 Authorization 头
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			response.Unauthorized(c, "Missing authorization header")
			c.Abort()
			return
		}

		// 解析 Bearer Token
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			response.Unauthorized(c, "Invalid authorization header format")
			c.Abort()
			return
		}

		token := parts[1]

		// 验证 Token
		claims, err := authService.ValidateToken(c.Request.Context(), token)
		if err != nil {
			response.Unauthorized(c, "Invalid or expired token")
			c.Abort()
			return
		}

		// 将用户信息存入 Context
		c.Set(ContextKeyUserID, claims.UserID)
		c.Set(ContextKeyUserEmail, claims.Email)

		c.Next()
	}
}

// GetUserID 从 Context 获取用户 ID
func GetUserID(c *gin.Context) int64 {
	userID, _ := c.Get(ContextKeyUserID)
	if id, ok := userID.(int64); ok {
		return id
	}
	return 0
}

// GetUserEmail 从 Context 获取用户邮箱
func GetUserEmail(c *gin.Context) string {
	email, _ := c.Get(ContextKeyUserEmail)
	if e, ok := email.(string); ok {
		return e
	}
	return ""
}
