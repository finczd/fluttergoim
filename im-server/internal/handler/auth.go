package handler

import (
	"net/http"
	"strings"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// CaptchaHandler 图形验证码（防刷）
func CaptchaHandler(c *gin.Context) {
	cid, b64, err := service.Captcha(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"code": 500, "message": "验证码生成失败"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
		"captchaId": cid, "image": b64,
	}})
}

// SendCodeHandler 发送短信/邮箱验证码
func SendCodeHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req service.SendCodeReq
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		channel, err := service.SendCode(c.Request.Context(), cfg, &req)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"channel": channel}})
	}
}

// RegisterHandler 注册
func RegisterHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req service.RegisterReq
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		u, access, refresh, err := service.Register(c.Request.Context(), cfg, &req, c.ClientIP())
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
			"user": u, "accessToken": access, "refreshToken": refresh,
		}})
	}
}

// LoginHandler 登录
func LoginHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req service.LoginReq
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		u, access, refresh, err := service.Login(c.Request.Context(), cfg, &req, c.ClientIP())
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
			"user": u, "accessToken": access, "refreshToken": refresh,
		}})
	}
}

// GuestRegisterHandler 游客注册/登录（按设备号幂等：已存在游客则直接登录，否则新建）
func GuestRegisterHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var req service.GuestRegisterReq
		if err := c.ShouldBindJSON(&req); err != nil || req.DeviceID == "" {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		u, access, refresh, isNew, err := service.GuestRegister(c.Request.Context(), cfg, &req, c.ClientIP())
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
			"user": u, "accessToken": access, "refreshToken": refresh, "isNewGuest": isNew,
		}})
	}
}

// InviteBindHandler 登录后补填邀请码（游客/普通用户通用）。
// 复用现有邀请码逻辑：一次性码 consume + 自定义好友码自动加好友，无需客户端关心细节。
func InviteBindHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			Code string `json:"code"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || strings.TrimSpace(body.Code) == "" {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		uid := middleware.CurrentUserID(c)
		if err := service.BindInviteCode(c.Request.Context(), body.Code, uid); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// RefreshHandler 刷新 token
func RefreshHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			RefreshToken string `json:"refreshToken"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.RefreshToken == "" {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		access, err := service.Refresh(c.Request.Context(), cfg, body.RefreshToken)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"accessToken": access}})
	}
}

// LogoutHandler 登出
func LogoutHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		service.Logout(c.Request.Context(), uid)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// 统一错误码提取
func errCode(err error) int {
	if e, ok := err.(*errs.Err); ok {
		return e.Code
	}
	return 500
}
