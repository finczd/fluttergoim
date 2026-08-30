package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// RegisterRoutes 注册 REST 路由
func RegisterRoutes(r *gin.Engine, cfg *config.Config) {
	r.Use(middleware.CORS())

	RegisterAdminRoutes(r, cfg)

	api := r.Group("/api/v1")
	{
		api.GET("/health", Health)
		api.GET("/access/nodes", func(c *gin.Context) { Nodes(c, cfg) })
		api.GET("/trtc/config", TRTCConfigHandler(cfg))

		// 认证（公开）
		api.GET("/auth/captcha", CaptchaHandler)
		api.POST("/auth/send-code", SendCodeHandler(cfg))
		api.POST("/auth/register", RegisterHandler(cfg))
		api.POST("/auth/login", LoginHandler(cfg))
		api.POST("/auth/refresh", RefreshHandler(cfg))
		api.GET("/auth/config", func(c *gin.Context) { AuthConfig(c, cfg) })

		// 扫码登录：创建 ticket（公开）+ 手机确认（需登录）+ PC 轮询（公开）
		api.POST("/auth/qr/ticket", func(c *gin.Context) {
			info, err := service.QrCreateTicket(c.Request.Context(), cfg)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "生成二维码失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": info})
		})
		api.GET("/auth/qr/status", func(c *gin.Context) {
			info, err := service.QrPollStatus(c.Request.Context(), cfg, c.Query("ticket"))
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": info})
		})

		// 用户（需登录）
		user := api.Group("", middleware.Auth(cfg))
		{
			user.POST("/auth/logout", LogoutHandler())
			// 文件上传（MinIO）：multipart form，字段 file + 可选 dir(chat/avatar)
			user.POST("/upload", func(c *gin.Context) {
				file, header, err := c.Request.FormFile("file")
				if err != nil {
					c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "缺少文件"})
					return
				}
				defer file.Close()
				dir := c.PostForm("dir")
				if dir == "" {
					dir = "chat/"
				}
				if !strings.HasSuffix(dir, "/") {
					dir += "/"
				}
				url, name, size, err := service.UploadFile(c.Request.Context(), cfg, dir, file, header.Filename, header.Header.Get("Content-Type"))
				if err != nil {
					c.JSON(http.StatusOK, gin.H{"code": 500, "message": "上传失败: " + err.Error()})
					return
				}
				c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
					"url": url, "name": header.Filename, "object": name, "size": size,
					"mimeType": header.Header.Get("Content-Type"),
				}})
			})
			user.POST("/auth/qr/confirm", func(c *gin.Context) {
				uid := middleware.CurrentUserID(c)
				var body struct {
					Ticket string `json:"ticket"`
				}
				c.ShouldBindJSON(&body)
				if err := service.QrConfirm(c.Request.Context(), cfg, body.Ticket, uid); err != nil {
					c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
					return
				}
				c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
			})
			user.GET("/user/profile", GetProfileHandler(cfg))
			user.PUT("/user/profile", UpdateProfileHandler())
			user.GET("/user/search", SearchUsersHandler())
			user.GET("/user/:id", GetUserDetailHandler())
			user.GET("/app/list", AppListHandler())
			user.GET("/trtc/usersig", TRTCUserSigHandler(cfg))

			// 好友（阶段 2）
			user.GET("/friend/list", FriendListHandler())
			user.POST("/friend/request", FriendRequestAddHandler())
			user.GET("/friend/request/incoming", FriendRequestIncomingHandler())
			user.GET("/friend/request/outgoing", FriendRequestOutgoingHandler())
			user.POST("/friend/request/:id/handle", FriendRequestHandleHandler())
			user.DELETE("/friend/:id", FriendDeleteHandler())
			user.PUT("/friend/:id/remark", FriendSetRemarkHandler())
			user.POST("/friend/blacklist", BlacklistAddHandler())
			user.DELETE("/friend/blacklist/:id", BlacklistRemoveHandler())
			user.GET("/friend/blacklist", BlacklistListHandler())

			// 会话（阶段 3）
			user.GET("/conversation/list", ConvListHandler())
			user.POST("/conversation/direct", CreateDirectHandler())
			user.POST("/conversation/group", CreateGroupHandler())
			user.GET("/conversation/:id/members", ConvMembersHandler())
			user.PUT("/conversation/:id/pin-message", SetPinMessageHandler())
			user.PUT("/conversation/:id/announcement", UpdateAnnouncementHandler())
			user.POST("/conversation/:id/invite", GroupInviteHandler())
			user.DELETE("/conversation/:id/members/:userId", GroupRemoveHandler())
			user.POST("/conversation/:id/quit", GroupQuitHandler())
			user.POST("/conversation/:id/disband", GroupDisbandHandler())
			user.PUT("/conversation/:id", GroupUpdateHandler())
			user.PUT("/conversation/:id/pin", SetPinHandler())
			user.PUT("/conversation/:id/mute", SetMuteHandler())

			// 消息（阶段 3）
			user.POST("/message/send", SendMessageHandler())
			user.GET("/message/history", HistoryHandler())
			user.GET("/message/sync", SyncHandler())
			user.GET("/message/search", SearchMessagesHandler())
			user.POST("/message/:id/recall", RecallMessageHandler())
			user.POST("/message/read", MarkReadHandler())
			user.GET("/message/receipts", ReceiptsHandler())
			user.POST("/message/favorite", FavoriteAddHandler())
			user.GET("/message/favorites", FavoriteListHandler())
		}
	}
}

func Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"status": "up"}})
}

// Nodes 就近接入节点列表（客户端测速选路）
func Nodes(c *gin.Context, cfg *config.Config) {
	// 节点列表：后台 sys_config access_nodes 优先，回退环境变量（需求：后台可增删节点）
	if v := service.SysConfigGet(c.Request.Context(), "access_nodes", cfg.AccessNodes); v != nil {
		if s, ok := v.(string); ok && s != "" && s != "null" {
			var nodes []map[string]interface{}
			if json.Unmarshal([]byte(s), &nodes) == nil && len(nodes) > 0 {
				c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": nodes})
				return
			}
		}
	}
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": cfg.AccessNodes})
}

// AuthConfig 注册配置（数据库优先，回退环境变量）——客户端据此渲染注册页
func AuthConfig(c *gin.Context, cfg *config.Config) {
	flags := service.GetAuthFlags(c.Request.Context(), cfg)
	c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": flags})
}

// TRTCConfigHandler 返回 TRTC 配置（不含 secretKey）
func TRTCConfigHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		conf := service.GetTRTCConfig(c.Request.Context(), cfg)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": conf})
	}
}

// TRTCUserSigHandler 为调用方生成 TRTC UserSig（后端用 secretKey 签名后下发）
// 请求：GET /trtc/usersig?room=room123 （user 来自 token）
func TRTCUserSigHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		conf := service.GetTRTCConfig(c.Request.Context(), cfg)
		if !conf.Enabled {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "TRTC 未配置", "data": gin.H{}})
			return
		}
		secretKey, _ := service.SysConfigGet(c.Request.Context(), "trtc_secret_key", "").(string)
		userIDStr := fmt.Sprintf("%d", uid)
		sig, exp, err := service.GenerateUserSig(conf.AppID, secretKey, userIDStr, 7*24*3600)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{
			"appId":    conf.AppID,
			"userId":   userIDStr,
			"userSig":  sig,
			"expire":   exp,
			"roomId":   c.Query("room"),
		}})
	}
}
