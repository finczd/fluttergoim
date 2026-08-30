package service

import (
	"context"
	"encoding/json"
	"time"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/store"
)

// FriendList 我的好友列表
func FriendList(ctx context.Context, userID int64) ([]model.User, error) {
	var ids []int64
	store.DB.Model(&model.FriendRelation{}).
		Where("user_id = ?", userID).Pluck("friend_id", &ids)

	// 兼容单向往反（对方添加我但未回填）——建好友时双向写入，此处再补查反向
	var reverse []int64
	store.DB.Model(&model.FriendRelation{}).
		Where("friend_id = ?", userID).Pluck("user_id", &reverse)
	ids = append(ids, reverse...)

	if len(ids) == 0 {
		return []model.User{}, nil
	}
	var users []model.User
	store.DB.Where("id IN ? AND status = ?", ids, model.StatusNormal).
		Order("id asc").Find(&users)
	return users, nil
}

// FriendRequestAdd 发起好友申请（全员可见，直接搜索添加）
func FriendRequestAdd(ctx context.Context, fromID, toID int64, message string) error {
	if fromID == toID {
		return &errs.Err{Code: 1001, Msg: "不能添加自己"}
	}
	var target model.User
	if err := store.DB.First(&target, toID).Error; err != nil || target.Status != model.StatusNormal {
		return &errs.Err{Code: 3001, Msg: "用户不存在"}
	}
	// 已是好友
	var cnt int64
	store.DB.Model(&model.FriendRelation{}).
		Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
			fromID, toID, toID, fromID).Count(&cnt)
	if cnt > 0 {
		return &errs.Err{Code: 3002, Msg: "你们已经是好友"}
	}
	// 重复申请拦截
	var pending int64
	store.DB.Model(&model.FriendRequest{}).
		Where("from_user = ? AND to_user = ? AND status = ?", fromID, toID, model.FriendReqPending).
		Count(&pending)
	if pending > 0 {
		return &errs.Err{Code: 3003, Msg: "申请已发送，请等待对方处理"}
	}
	if message == "" {
		message = "我是 " + selfNickname(fromID)
	}
	if err := store.DB.Create(&model.FriendRequest{
		FromUser: fromID, ToUser: toID, Message: message, Status: model.FriendReqPending,
	}).Error; err != nil {
		return err
	}
	// 通知对方：有新的好友申请（前端刷新申请列表 + 红点）
	data, _ := json.Marshal(map[string]interface{}{
		"fromUserId":   fromID,
		"fromUserName": selfNickname(fromID),
		"message":      message,
	})
	_ = PublishEvent(ctx, &Event{Type: "friend.request", UserIDs: []int64{toID}, Data: data})
	return nil
}

// FriendRequestIncoming 我收到的申请
func FriendRequestIncoming(ctx context.Context, userID int64) ([]model.FriendRequest, error) {
	var reqs []model.FriendRequest
	err := store.DB.Where("to_user = ? AND status = ?", userID, model.FriendReqPending).
		Order("id desc").Limit(50).Find(&reqs).Error
	return reqs, err
}

// FriendRequestOutgoing 我发出的申请
func FriendRequestOutgoing(ctx context.Context, userID int64) ([]model.FriendRequest, error) {
	var reqs []model.FriendRequest
	err := store.DB.Where("from_user = ? AND status = ?", userID, model.FriendReqPending).
		Order("id desc").Limit(50).Find(&reqs).Error
	return reqs, err
}

// FriendRequestHandle 处理申请（同意：双向写入好友关系）
func FriendRequestHandle(ctx context.Context, userID int64, reqID int64, agree bool) error {
	var req model.FriendRequest
	if err := store.DB.First(&req, reqID).Error; err != nil || req.ToUser != userID {
		return errs.FriendReqNotFound
	}
	now := time.Now()
	if agree {
		// 双向好友
		store.DB.FirstOrCreate(&model.FriendRelation{UserID: req.FromUser, FriendID: req.ToUser, Source: 1, CreatedAt: now},
			model.FriendRelation{UserID: req.FromUser, FriendID: req.ToUser})
		store.DB.FirstOrCreate(&model.FriendRelation{UserID: req.ToUser, FriendID: req.FromUser, Source: 1, CreatedAt: now},
			model.FriendRelation{UserID: req.ToUser, FriendID: req.FromUser})
		// 需求：通过后自动建会话 + 发一条欢迎消息给对方（"我已通过你的好友申请，请和我开始聊天吧！"）
		if conv, err := CreateDirect(ctx, req.ToUser, req.FromUser); err == nil && conv != nil {
			// 以通过者（req.ToUser）身份发送欢迎消息
			SendMessage(ctx, req.ToUser, &SendMsgReq{
				ConversationID: conv.ID,
				Type:           1,
				Content:        "我已通过你的好友申请，请和我开始聊天吧！",
			})
		}
		// 通知对方：好友申请已通过
		evData, _ := json.Marshal(map[string]interface{}{
			"fromUserId": req.ToUser,
			"message":    "我已通过你的好友申请",
		})
		_ = PublishEvent(ctx, &Event{Type: "friend.accepted", UserIDs: []int64{req.FromUser}, Data: evData})
	}
	return store.DB.Model(&req).Update("status",
		map[bool]int{true: model.FriendReqAgreed, false: model.FriendReqRejected}[agree]).Error
}

// FriendDelete 删除好友（双向删除）
func FriendDelete(ctx context.Context, userID, friendID int64) error {
	res := store.DB.Where("user_id = ? AND friend_id = ?", userID, friendID).
		Delete(&model.FriendRelation{})
	store.DB.Where("user_id = ? AND friend_id = ?", friendID, userID).
		Delete(&model.FriendRelation{})
	if res.RowsAffected == 0 {
		return &errs.Err{Code: 3004, Msg: "不是好友关系"}
	}
	return nil
}

// FriendSetRemark 设置备注
func FriendSetRemark(ctx context.Context, userID, friendID int64, remark string) error {
	return store.DB.Model(&model.FriendRelation{}).
		Where("user_id = ? AND friend_id = ?", userID, friendID).
		Update("remark", remark).Error
}

// BlacklistAdd 拉黑（并自动解除好友）
func BlacklistAdd(ctx context.Context, userID, blockID int64) error {
	store.DB.FirstOrCreate(&model.Blacklist{UserID: userID, BlockUserID: blockID},
		model.Blacklist{UserID: userID, BlockUserID: blockID})
	FriendDelete(ctx, userID, blockID)
	return nil
}

// BlacklistRemove 移出黑名单
func BlacklistRemove(ctx context.Context, userID, blockID int64) error {
	return store.DB.Where("user_id = ? AND block_user_id = ?", userID, blockID).
		Delete(&model.Blacklist{}).Error
}

// BlacklistList 我的黑名单
func BlacklistList(ctx context.Context, userID int64) ([]model.User, error) {
	var ids []int64
	store.DB.Model(&model.Blacklist{}).Where("user_id = ?", userID).Pluck("block_user_id", &ids)
	if len(ids) == 0 {
		return []model.User{}, nil
	}
	var users []model.User
	store.DB.Where("id IN ?", ids).Find(&users)
	return users, nil
}

func selfNickname(userID int64) string {
	var u model.User
	if err := store.DB.First(&u, userID).Error; err == nil {
		return u.Nickname
	}
	return "用户"
}
