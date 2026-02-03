package middleware

import (
	"net/http"
	"runtime/debug"

	"fund-analyzer/pkg/response"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// Recovery 恢复中间件
func Recovery(logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				// 记录堆栈信息
				logger.Error("Panic recovered",
					zap.Any("error", err),
					zap.String("stack", string(debug.Stack())),
					zap.String("request_id", c.GetString("request_id")),
				)

				// 返回 500 错误
				c.AbortWithStatusJSON(http.StatusInternalServerError, response.Response{
					Code:    response.CodeInternalError,
					Message: "Internal server error",
				})
			}
		}()
		c.Next()
	}
}
