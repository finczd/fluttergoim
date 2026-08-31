package handler

import (
	"net/http"
	"strconv"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// ConvListHandler 会话列表
func ConvListHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		items, err := service.ConvList(c.Request.Context(), uid)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "获取会话失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": items})
	}
}

// CreateDirectHandler 创建单聊
func CreateDirectHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var body struct {
			UserID int64 `json:"userId,string" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.UserID == 0 {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		conv, err := service.CreateDirect(c.Request.Context(), uid, body.UserID)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": conv})
	}
}

// CreateGroupHandler 创建群聊（memberIds 为字符串数组，雪花 ID 精度安全）
func CreateGroupHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var body struct {
			NameZh    string   `json:"nameZh"`
			NameEn    string   `json:"nameEn"`
			MemberIDs []string `json:"memberIds"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		memberIDs := make([]int64, 0, len(body.MemberIDs))
		for _, s := range body.MemberIDs {
			if v, err := strconv.ParseInt(s, 10, 64); err == nil {
				memberIDs = append(memberIDs, v)
			}
		}
		conv, err := service.CreateGroup(c.Request.Context(), uid, body.NameZh, body.NameEn, memberIDs)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "创建失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": conv})
	}
}

// GroupInviteHandler 邀请成员（memberIds 字符串数组）
func GroupInviteHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			MemberIDs []string `json:"memberIds"`
		}
		c.ShouldBindJSON(&body)
		memberIDs := make([]int64, 0, len(body.MemberIDs))
		for _, s := range body.MemberIDs {
			if v, err := strconv.ParseInt(s, 10, 64); err == nil {
				memberIDs = append(memberIDs, v)
			}
		}
		if err := service.GroupInvite(c.Request.Context(), uid, convID, memberIDs); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// GroupRemoveHandler 移除成员
func GroupRemoveHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		targetID, _ := strconv.ParseInt(c.Param("userId"), 10, 64)
		if err := service.GroupRemove(c.Request.Context(), uid, convID, targetID); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// GroupQuitHandler 退出群
func GroupQuitHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		service.GroupQuit(c.Request.Context(), uid, convID)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// GroupDisbandHandler 解散群
func GroupDisbandHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		if err := service.GroupDisband(c.Request.Context(), uid, convID); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// GroupUpdateHandler 更新群信息
func GroupUpdateHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			NameZh         string `json:"nameZh"`
			NameEn         string `json:"nameEn"`
			AnnouncementZh string `json:"announcementZh"`
			AnnouncementEn string `json:"announcementEn"`
		}
		c.ShouldBindJSON(&body)
		if err := service.GroupUpdate(c.Request.Context(), uid, convID, body.NameZh, body.NameEn, body.AnnouncementZh, body.AnnouncementEn); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// SetPinHandler 置顶
func SetPinHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			Pinned bool `json:"pinned"`
		}
		c.ShouldBindJSON(&body)
		service.SetPin(c.Request.Context(), uid, convID, body.Pinned)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// SetMuteHandler 免打扰
func SetMuteHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			Mute bool `json:"mute"`
		}
		c.ShouldBindJSON(&body)
		service.SetMute(c.Request.Context(), uid, convID, body.Mute)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// ConvMembersHandler 会话成员列表
func ConvMembersHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		users, err := service.ConvMembers(c.Request.Context(), uid, convID)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": users})
	}
}

// SetPinMessageHandler 置顶/取消置顶消息（群主/管理员）
func SetPinMessageHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			MsgID   int64  `json:"msgId,string"`
			Content string `json:"content"`
			Pinned  *bool  `json:"pinned"` // true=置顶 false=取消；缺省按 msgId>0 置顶
		}
		c.ShouldBindJSON(&body)
		pinned := true
		if body.Pinned != nil {
			pinned = *body.Pinned
		} else if body.MsgID <= 0 {
			pinned = false
		}
		if err := service.SetPinMessage(c.Request.Context(), uid, convID, body.MsgID, body.Content, pinned); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// PinnedMessagesHandler 置顶消息列表（返回 msgId 数组）
func PinnedMessagesHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		ids, err := service.PinnedMessages(c.Request.Context(), uid, convID)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": ids})
	}
}

// UpdateAnnouncementHandler 更新群公告（群主/管理员）
func UpdateAnnouncementHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		var body struct {
			AnnouncementZh string `json:"announcementZh"`
			AnnouncementEn string `json:"announcementEn"`
		}
		c.ShouldBindJSON(&body)
		if err := service.UpdateAnnouncement(c.Request.Context(), uid, convID, body.AnnouncementZh, body.AnnouncementEn); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

var _ = errs.Forbidden
var _ = config.Config{}
