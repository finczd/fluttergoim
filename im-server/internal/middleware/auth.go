package middleware

import (
	"net/http"
	"strings"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	jwtx "github.com/yourcompany/im-server/internal/pkg/jwt"

	"github.com/gin-gonic/gin"
)

const (
	CtxUserID = "uid"
	CtxRole   = "role"
)

// Auth JWT 鉴权中间件
func Auth(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusOK, errs.Unauthorized)
			return
		}
		token := strings.TrimPrefix(header, "Bearer ")
		claims, err := jwtx.Parse(cfg.JWTSecret, token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusOK, errs.Unauthorized)
			return
		}
		c.Set(CtxUserID, claims.UserID)
		c.Set(CtxRole, claims.Role)
		c.Next()
	}
}

// RequireAdmin 管理员中间件（配合 Auth 使用）
func RequireAdmin() gin.HandlerFunc {
	return func(c *gin.Context) {
		if role, ok := c.Get(CtxRole); !ok || role.(int) != model.RoleAdmin {
			c.AbortWithStatusJSON(http.StatusOK, errs.Forbidden)
			return
		}
		c.Next()
	}
}

// CurrentUserID 从上下文取当前用户 ID
func CurrentUserID(c *gin.Context) int64 {
	if v, ok := c.Get(CtxUserID); ok {
		return v.(int64)
	}
	return 0
}
