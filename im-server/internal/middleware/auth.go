package middleware

import (
	"net/http"
	"strings"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/store"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	jwtx "github.com/yourcompany/im-server/internal/pkg/jwt"

	"github.com/gin-gonic/gin"
)

const (
	CtxUserID = "uid"
	CtxRole   = "role"
)

// Auth JWT 鉴权中间件
// 注意：鉴权失败必须返回 HTTP 401（不是 200+code）——
// 三端（App dio onError / PC fetch response.ok / 后台 axios 拦截器）的
// 自动刷新 token 逻辑全部依赖 HTTP 状态码 401 触发。
// 之前返回 200 导致 token 过期后客户端静默拿到空数据：
// 列表页全显示"暂无会话/暂无好友"，空列表还会污染本地缓存（bug：过段时间打开 App 全空）。
func Auth(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, errs.Unauthorized)
			return
		}
		token := strings.TrimPrefix(header, "Bearer ")
		claims, err := jwtx.Parse(cfg.JWTSecret, token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, errs.Unauthorized)
			return
		}
		// 复核账号状态：禁用账号的 access token 在有效期内本应继续可用，
		// 但后台"禁用"必须即时生效 —— 任何请求都返回 401，
		// 三端据此清登录态并跳登录页（见各端 onUnauthorized / forceLogout 处理）。
		// 仅在能确认查到用户且状态非"正常"时才拦截；DB 瞬时故障则放行，
		// 避免一次数据库抖动把全体在线用户踢下线。
		var u model.User
		if err := store.DB.Select("status").Where("id = ?", claims.UserID).First(&u).Error; err == nil && u.Status != model.StatusNormal {
			c.AbortWithStatusJSON(http.StatusUnauthorized, errs.Unauthorized)
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
