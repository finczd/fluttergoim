package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// GetProfileHandler 我的资料（附带我的在线设备）
func GetProfileHandler(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		u, err := service.GetProfile(c.Request.Context(), uid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		// 附加在线状态（我当前在哪些设备在线）
		online, devs := service.IsUserOnline(c.Request.Context(), uid)
		uJSON, _ := json.Marshal(u)
		extra := map[string]interface{}{
			"online":       online,
			"onlineDevice": devs,
			// 靓号标识：short_id 来自后台靓号池（已分配）→ 客户端 ID 前显示红色「靓ID」徽标
			"vipShortId": service.IsVipShortID(c.Request.Context(), uid, u.ShortID),
		}
		var body map[string]interface{}
		json.Unmarshal(uJSON, &body)
		for k, v := range extra {
			body[k] = v
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": body})
	}
}

// UpdateProfileHandler 更新资料
func UpdateProfileHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var req service.UpdateProfileReq
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		if err := service.UpdateProfile(c.Request.Context(), uid, &req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// SearchUsersHandler 搜索用户（全员可见，附带在线状态）
func SearchUsersHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		kw := c.Query("kw")
		users, err := service.SearchUsers(c.Request.Context(), kw)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "搜索失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": attachOnline(c, users)})
	}
}

// GetUserDetailHandler 用户详情（附带在线状态）
func GetUserDetailHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		u, err := service.GetUserDetail(c.Request.Context(), id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": attachOnlineOne(c, u)})
	}
}

// attachOnline 批量附加在线状态（用户列表）
func attachOnline(c *gin.Context, users []model.User) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(users))
	for i := range users {
		out = append(out, attachOnlineOne(c, &users[i]))
	}
	return out
}

// attachOnlineOne 单个用户附加在线状态
func attachOnlineOne(c *gin.Context, u *model.User) map[string]interface{} {
	online, devs := service.IsUserOnline(c.Request.Context(), u.ID)
	b, _ := json.Marshal(u)
	var m map[string]interface{}
	json.Unmarshal(b, &m)
	m["online"] = online
	m["onlineDevice"] = devs
	m["onlineText"] = service.OnlineDeviceZh(devs)
	return m
}

// DeptTreeHandler 部门树（双语字段）
func DeptTreeHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		depts, err := service.DeptTree(c.Request.Context())
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "获取部门失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": depts})
	}
}

// DeptMembersHandler 部门成员
func DeptMembersHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		id, err := strconv.ParseInt(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		users, err := service.DeptMembers(c.Request.Context(), id)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "获取成员失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": users})
	}
}

// ChangePasswordHandler 修改登录密码（需校验原密码）
func ChangePasswordHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var body struct {
			OldPassword string `json:"oldPassword"`
			NewPassword string `json:"newPassword"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		if err := service.ChangePassword(c.Request.Context(), uid, body.OldPassword, body.NewPassword); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// DeleteAccountHandler 注销账户
func DeleteAccountHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		if err := service.DeleteAccount(c.Request.Context(), uid); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

var _ = errs.Forbidden
