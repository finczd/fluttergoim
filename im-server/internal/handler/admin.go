package handler

import (
	"net/http"
	"strconv"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// RegisterAdminRoutes 管理后台路由（Auth + RequireAdmin）
func RegisterAdminRoutes(r *gin.Engine, cfg *config.Config) {
	admin := r.Group("/api/v1/admin", middleware.Auth(cfg), middleware.RequireAdmin())
	{
		// 用户管理
		admin.GET("/users", func(c *gin.Context) {
			kw := c.Query("kw")
			status, _ := strconv.Atoi(c.Query("status"))
			deptID, _ := strconv.ParseInt(c.Query("dept"), 10, 64)
			page, _ := strconv.Atoi(c.Query("page"))
			size, _ := strconv.Atoi(c.Query("size"))
			res, err := service.AdminUserList(c.Request.Context(), kw, status, deptID, page, size)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": res})
		})
		admin.POST("/users", func(c *gin.Context) {
			var body struct {
				Account  string `json:"account" binding:"required"`
				Password string `json:"password" binding:"required"`
				Nickname string `json:"nickname"`
				DeptID   int64  `json:"departmentId"`
				Role     int    `json:"role"`
			}
			if err := c.ShouldBindJSON(&body); err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
				return
			}
			u, err := service.AdminUserCreate(c.Request.Context(), body.Account, body.Password, body.Nickname, body.DeptID, body.Role)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
				return
			}
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "user.create", body.Account, c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": u})
		})
		admin.PUT("/users/:id/status", func(c *gin.Context) {
			id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
			var body struct {
				Status int `json:"status"` // 1 正常 2 禁用
			}
			c.ShouldBindJSON(&body)
			service.AdminUserSetStatus(c.Request.Context(), id, body.Status)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "user.status", strconv.FormatInt(id, 10), c.ClientIP(), body)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})
		admin.PUT("/users/:id/password", func(c *gin.Context) {
			id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
			var body struct {
				Password string `json:"password" binding:"required"`
			}
			if err := c.ShouldBindJSON(&body); err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
				return
			}
			service.AdminUserResetPassword(c.Request.Context(), id, body.Password)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "user.password", strconv.FormatInt(id, 10), c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})

		// 系统配置
		admin.GET("/configs/:key", func(c *gin.Context) {
			key := c.Param("key")
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": service.SysConfigGet(c.Request.Context(), key, nil)})
		})
		admin.PUT("/configs/:key", func(c *gin.Context) {
			key := c.Param("key")
			var body struct {
				Value interface{} `json:"value"`
			}
			c.ShouldBindJSON(&body)
			service.SysConfigSet(c.Request.Context(), key, body.Value)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "config.set", key, c.ClientIP(), body)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})

		// 小程序管理（H5 容器）
		admin.GET("/app-entries", func(c *gin.Context) {
			apps, err := service.AdminAppList(c.Request.Context())
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": apps})
		})
		admin.POST("/app-entries", func(c *gin.Context) {
			var body struct {
				NameZh   string `json:"nameZh"`
				NameEn   string `json:"nameEn"`
				Icon     string `json:"icon"`
				URL      string `json:"url"`
				Category string `json:"category"`
				Sort     int    `json:"sort"`
				Enabled  bool   `json:"enabled"`
			}
			c.ShouldBindJSON(&body)
			a, err := service.AdminAppCreate(c.Request.Context(), body.NameZh, body.NameEn, body.Icon, body.URL, body.Category, body.Sort, body.Enabled)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "创建失败"})
				return
			}
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "app.create", body.NameZh, c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": a})
		})
		admin.PUT("/app-entries/:id", func(c *gin.Context) {
			id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
			var body struct {
				NameZh   string `json:"nameZh"`
				NameEn   string `json:"nameEn"`
				Icon     string `json:"icon"`
				URL      string `json:"url"`
				Category string `json:"category"`
				Sort     int    `json:"sort"`
				Enabled  bool   `json:"enabled"`
			}
			c.ShouldBindJSON(&body)
			service.AdminAppUpdate(c.Request.Context(), id, body.NameZh, body.NameEn, body.Icon, body.URL, body.Category, body.Sort, body.Enabled)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "app.update", strconv.FormatInt(id, 10), c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})
		admin.DELETE("/app-entries/:id", func(c *gin.Context) {
			id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
			service.AdminAppDelete(c.Request.Context(), id)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "app.delete", strconv.FormatInt(id, 10), c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})

		// 智能小助手：配置读写 + 推送
		admin.GET("/assistant/config", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": service.GetAssistantConfig(c.Request.Context(), cfg)})
		})
		admin.POST("/assistant/config", func(c *gin.Context) {
			var ac service.AssistantConfig
			c.ShouldBindJSON(&ac)
			if err := service.SaveAssistantConfig(c.Request.Context(), ac); err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "保存失败"})
				return
			}
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "assistant.config", "save", c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})
		admin.POST("/assistant/push", func(c *gin.Context) {
			var body struct {
				UserID  int64  `json:"userId,string"`
				Content string `json:"content"`
				FileURL string `json:"fileUrl"`
			}
			c.ShouldBindJSON(&body)
			if err := service.AssistantPush(c.Request.Context(), cfg, body.UserID, body.Content, body.FileURL); err != nil {
				c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
				return
			}
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "assistant.push", strconv.FormatInt(body.UserID, 10), c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})

		// 群组管理
		admin.GET("/groups", func(c *gin.Context) {
			groups, err := service.AdminGroupList(c.Request.Context())
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": groups})
		})
		admin.DELETE("/groups/:id", func(c *gin.Context) {
			id, _ := strconv.ParseInt(c.Param("id"), 10, 64)
			service.AdminGroupDisband(c.Request.Context(), id)
			service.AdminLog(c.Request.Context(), middleware.CurrentUserID(c), "group.disband", strconv.FormatInt(id, 10), c.ClientIP(), nil)
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
		})

		// 消息记录（审计）
		admin.GET("/messages", func(c *gin.Context) {
			var q service.AdminMsgQuery
			q.ConvID, _ = strconv.ParseInt(c.Query("convId"), 10, 64)
			q.UserID, _ = strconv.ParseInt(c.Query("userId"), 10, 64)
			q.Kw = c.Query("kw")
			q.From, _ = strconv.ParseInt(c.Query("from"), 10, 64)
			q.To, _ = strconv.ParseInt(c.Query("to"), 10, 64)
			page, _ := strconv.Atoi(c.Query("page"))
			size, _ := strconv.Atoi(c.Query("size"))
			msgs, total, err := service.AdminMessageQuery(c.Request.Context(), &q, page, size)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"list": msgs, "total": total}})
		})

		// 数据统计
		admin.GET("/stats/overview", func(c *gin.Context) {
			st, err := service.AdminStatsOverview(c.Request.Context())
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "统计失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": st})
		})
		admin.GET("/stats/messages", func(c *gin.Context) {
			days, _ := strconv.Atoi(c.Query("days"))
			st, err := service.AdminStatsMessages(c.Request.Context(), days)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "统计失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": st})
		})

		// 日志
		admin.GET("/logs", func(c *gin.Context) {
			page, _ := strconv.Atoi(c.Query("page"))
			size, _ := strconv.Atoi(c.Query("size"))
			logs, total, err := service.AdminLogList(c.Request.Context(), page, size)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"list": logs, "total": total}})
		})
		admin.GET("/logs/login", func(c *gin.Context) {
			page, _ := strconv.Atoi(c.Query("page"))
			size, _ := strconv.Atoi(c.Query("size"))
			logs, total, err := service.AdminLoginLogList(c.Request.Context(), page, size)
			if err != nil {
				c.JSON(http.StatusOK, gin.H{"code": 500, "message": "查询失败"})
				return
			}
			c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"list": logs, "total": total}})
		})
	}
}
