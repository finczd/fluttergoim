package handler

import (
	"net/http"
	"strconv"

	"github.com/yourcompany/im-server/internal/middleware"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/service"

	"github.com/gin-gonic/gin"
)

// SendMessageHandler 发送消息
func SendMessageHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var req service.SendMsgReq
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		msg, err := service.SendMessage(c.Request.Context(), uid, &req)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": msg})
	}
}

// HistoryHandler 历史消息（?convId=&beforeMsgId=&limit=）
func HistoryHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Query("convId"), 10, 64)
		before, _ := strconv.ParseInt(c.Query("beforeMsgId"), 10, 64)
		limit, _ := strconv.ParseInt(c.Query("limit"), 10, 64)
		msgs, err := service.History(c.Request.Context(), uid, convID, before, limit)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": msgs})
	}
}

// RecallMessageHandler 撤回
func RecallMessageHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		msgID, _ := strconv.ParseInt(c.Param("id"), 10, 64)
		if err := service.RecallMessage(c.Request.Context(), uid, msgID); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// MarkReadHandler 上报已读
func MarkReadHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var body struct {
			ConversationID int64 `json:"conversationId,string" binding:"required"`
			MsgID          int64 `json:"msgId,string"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.ConversationID == 0 {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		service.MarkRead(c.Request.Context(), uid, body.ConversationID, body.MsgID)
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// ReceiptsHandler 已读成员列表（群按人）
func ReceiptsHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Query("convId"), 10, 64)
		msgID, _ := strconv.ParseInt(c.Query("msgId"), 10, 64)
		receipts, err := service.Receipts(c.Request.Context(), uid, convID, msgID)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": receipts})
	}
}

// SyncHandler 增量补拉（重连补偿/上线拉取）：?convId=&afterSeq=&limit=
func SyncHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		convID, _ := strconv.ParseInt(c.Query("convId"), 10, 64)
		afterSeq, _ := strconv.ParseInt(c.Query("afterSeq"), 10, 64)
		limit, _ := strconv.ParseInt(c.Query("limit"), 10, 64)
		msgs, err := service.Sync(c.Request.Context(), uid, convID, afterSeq, limit)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": msgs})
	}
}

// SearchMessagesHandler 消息搜索：?kw=&convId=&page=&size=（仅自己参与的会话）
func SearchMessagesHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		kw := c.Query("kw")
		convID, _ := strconv.ParseInt(c.Query("convId"), 10, 64)
		page, _ := strconv.Atoi(c.Query("page"))
		size, _ := strconv.Atoi(c.Query("size"))
		msgs, total, err := service.SearchMessages(c.Request.Context(), uid, kw, convID, page, size)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": errCode(err), "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": gin.H{"list": msgs, "total": total}})
	}
}

// FavoriteAddHandler 收藏
func FavoriteAddHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		var body struct {
			ConversationID int64 `json:"conversationId,string" binding:"required"`
			MsgID          int64 `json:"msgId,string" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 1001, "message": "参数错误"})
			return
		}
		if err := service.FavoriteAdd(c.Request.Context(), uid, body.ConversationID, body.MsgID); err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "收藏失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok"})
	}
}

// FavoriteListHandler 我的收藏
func FavoriteListHandler() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := middleware.CurrentUserID(c)
		limit, _ := strconv.ParseInt(c.Query("limit"), 10, 64)
		msgs, err := service.FavoriteList(c.Request.Context(), uid, limit)
		if err != nil {
			c.JSON(http.StatusOK, gin.H{"code": 500, "message": "获取失败"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"code": 0, "message": "ok", "data": msgs})
	}
}

var _ = errs.Forbidden
