package service

import (
	"context"
	"fmt"
	"sort"
	"time"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/pkg/id"
	"github.com/yourcompany/im-server/internal/store"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ============ 创建会话 ============

// CreateDirect 创建/获取单聊会话（双方各一条 member 记录）
func CreateDirect(ctx context.Context, userID, otherID int64) (*model.Conversation, error) {
	if userID == otherID {
		return nil, &errs.Err{Code: 1001, Msg: "不能和自己聊天"}
	}
	// 查已有单聊会话
	var conv model.Conversation
	err := store.DB.Raw(`
		SELECT c.* FROM conversation c
		JOIN conversation_member m1 ON m1.conversation_id = c.id AND m1.user_id = ?
		JOIN conversation_member m2 ON m2.conversation_id = c.id AND m2.user_id = ?
		WHERE c.type = 1 AND c.status = 1 LIMIT 1`, userID, otherID).Scan(&conv).Error
	if err == nil && conv.ID > 0 {
		return &conv, nil
	}

	// 创建
	now := time.Now()
	cid := id.Next()
	conv = model.Conversation{ID: cid, Type: model.ConvDirect, MaxMembers: 2, Status: model.ConvNormal, CreatedAt: now}
	if err := store.DB.Create(&conv).Error; err != nil {
		return nil, err
	}
	store.DB.Create(&model.ConversationMember{ConversationID: cid, UserID: userID, Role: model.MemberNormal, JoinedAt: now})
	store.DB.Create(&model.ConversationMember{ConversationID: cid, UserID: otherID, Role: model.MemberNormal, JoinedAt: now})
	return &conv, nil
}

// CreateGroup 创建群聊
func CreateGroup(ctx context.Context, ownerID int64, nameZh, nameEn string, memberIDs []int64) (*model.Conversation, error) {
	cid := id.Next()
	now := time.Now()
	conv := model.Conversation{
		ID: cid, Type: model.ConvGroup, NameZh: nameZh, NameEn: nameEn,
		OwnerID: ownerID, MaxMembers: 500, Status: model.ConvNormal, CreatedAt: now,
	}
	if err := store.DB.Create(&conv).Error; err != nil {
		return nil, err
	}
	store.DB.Create(&model.ConversationMember{ConversationID: cid, UserID: ownerID, Role: model.MemberOwner, JoinedAt: now})
	for _, uid := range memberIDs {
		if uid == ownerID {
			continue
		}
		store.DB.Create(&model.ConversationMember{ConversationID: cid, UserID: uid, Role: model.MemberNormal, JoinedAt: now})
	}
	return &conv, nil
}

// ============ 会话列表（聚合未读 + 最后消息） ============

// ConvItem 会话列表项
type ConvItem struct {
	Conversation  model.Conversation `json:"conversation"`
	Unread        int64              `json:"unread"`
	LastMessage   *model.Message     `json:"lastMessage"`
	MemberCount   int64              `json:"memberCount"`
	Mute          bool               `json:"mute"`
	Pinned        bool               `json:"pinned"`
	ConversationName string          `json:"conversationName"` // 单聊显示对方昵称
	PeerOnline    bool               `json:"peerOnline"`       // 单聊对方是否在线
	PeerOnlineDev []string           `json:"peerOnlineDev"`     // 对方在线设备
}

// PeerOnline 查询会话中对方的在线状态（单聊返回对方设备，群聊返回空）
func PeerOnline(ctx context.Context, conv model.Conversation, userID int64) (bool, []string) {
	if conv.Type != model.ConvDirect {
		return false, nil
	}
	otherID := directOtherID(ctx, conv.ID, userID)
	if otherID <= 0 {
		return false, nil
	}
	return IsUserOnline(ctx, otherID)
}

func ConvList(ctx context.Context, userID int64) ([]*ConvItem, error) {
	var members []model.ConversationMember
	if err := store.DB.Where("user_id = ?", userID).Find(&members).Error; err != nil {
		return nil, err
	}
	items := make([]*ConvItem, 0, len(members))
	for _, m := range members {
		var conv model.Conversation
		if err := store.DB.First(&conv, m.ConversationID).Error; err != nil || conv.Status != model.ConvNormal {
			continue
		}
		item := &ConvItem{
			Conversation: conv,
			Unread:       unreadCount(ctx, userID, m.ConversationID),
			Mute:         m.Mute == 1,
			Pinned:       m.Pinned == 1,
			MemberCount:  memberCount(ctx, m.ConversationID),
		}
		// 单聊显示对方昵称 + 在线状态
		if conv.Type == model.ConvDirect {
			if otherID := directOtherID(ctx, m.ConversationID, userID); otherID != 0 {
				if otherID == -1 {
					// 小助手虚拟账号（名称固定"小助手"，头像空；后台配置名暂不联动）
					item.ConversationName = "小助手"
				} else {
					if u, err := GetUserDetail(ctx, otherID); err == nil {
						item.ConversationName = u.Nickname
						if item.Conversation.Avatar == "" {
							item.Conversation.Avatar = u.Avatar
						}
					}
					online, devs := IsUserOnline(ctx, otherID)
					item.PeerOnline = online
					item.PeerOnlineDev = devs
				}
			}
		} else {
			item.ConversationName = conv.NameZh
		}
		// 最后一条消息 + 单聊 delivery_state 标记
		var last model.Message
		err := msgColl().FindOne(ctx,
			bson.M{"conversation_id": m.ConversationID},
			options.FindOne().SetSort(bson.D{{Key: "msg_id", Value: -1}})).Decode(&last)
		if err == nil {
			item.LastMessage = &last
			// 需求4：单聊我发的消息，对方已读 → delivery_state=read
			if conv.Type == model.ConvDirect && last.SenderID == userID {
				otherID := directOtherID(ctx, m.ConversationID, userID)
				if otherID > 0 {
					var other model.ConversationMember
					if err := store.DB.Where("conversation_id = ? AND user_id = ?", m.ConversationID, otherID).
						First(&other).Error; err == nil {
						if other.LastReadMsgID >= last.MsgID {
							item.LastMessage.Delivery = "read"
						} else {
							item.LastMessage.Delivery = "sent"
						}
					}
				}
			}
		}
		items = append(items, item)
	}
	// 排序：置顶优先，再按最后消息时间倒序
	sort.Slice(items, func(i, j int) bool {
		if items[i].Pinned != items[j].Pinned {
			return items[i].Pinned
		}
		ti := lastTime(items[i])
		tj := lastTime(items[j])
		return ti.After(tj)
	})
	return items, nil
}

func lastTime(it *ConvItem) time.Time {
	if it.LastMessage != nil {
		return it.LastMessage.CreatedAt
	}
	return it.Conversation.CreatedAt
}

func unreadCount(ctx context.Context, uid, convID int64) int64 {
	n, _ := store.RDB.HGet(ctx, fmt.Sprintf("unread:%d", uid), fmt.Sprintf("%d", convID)).Int64()
	return n
}

func memberCount(ctx context.Context, convID int64) int64 {
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&cnt)
	return cnt
}

func directOtherID(ctx context.Context, convID, userID int64) int64 {
	var ids []int64
	store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id != ?", convID, userID).Pluck("user_id", &ids)
	if len(ids) > 0 {
		return ids[0]
	}
	return 0
}

// ============ 群管理 ============

func GroupInvite(ctx context.Context, userID, convID int64, memberIDs []int64) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	for _, uid := range memberIDs {
		var cnt int64
		store.DB.Model(&model.ConversationMember{}).
			Where("conversation_id = ? AND user_id = ?", convID, uid).Count(&cnt)
		if cnt == 0 {
			store.DB.Create(&model.ConversationMember{
				ConversationID: convID, UserID: uid, Role: model.MemberNormal, JoinedAt: time.Now(),
			})
		}
	}
	return nil
}

func GroupRemove(ctx context.Context, userID, convID, targetID int64) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	return store.DB.Where("conversation_id = ? AND user_id = ?", convID, targetID).
		Delete(&model.ConversationMember{}).Error
}

func GroupQuit(ctx context.Context, userID, convID int64) error {
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&cnt)
	if cnt <= 1 {
		// 最后一人退出 → 解散
		store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Update("status", model.ConvDisband)
	}
	return store.DB.Where("conversation_id = ? AND user_id = ?", convID, userID).
		Delete(&model.ConversationMember{}).Error
}

func GroupDisband(ctx context.Context, userID, convID int64) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner {
		return errs.Forbidden
	}
	store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Update("status", model.ConvDisband)
	return store.DB.Where("conversation_id = ?", convID).Delete(&model.ConversationMember{}).Error
}

func GroupUpdate(ctx context.Context, userID, convID int64, nameZh, nameEn, announcementZh, announcementEn string) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	updates := map[string]interface{}{}
	if nameZh != "" {
		updates["name_zh"] = nameZh
	}
	if nameEn != "" {
		updates["name_en"] = nameEn
	}
	if announcementZh != "" {
		updates["announcement_zh"] = announcementZh
	}
	if announcementEn != "" {
		updates["announcement_en"] = announcementEn
	}
	if len(updates) == 0 {
		return nil
	}
	return store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Updates(updates).Error
}

// SetPin / SetMute 置顶 / 免打扰
func SetPin(ctx context.Context, userID, convID int64, pinned bool) error {
	return store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, userID).
		Update("pinned", map[bool]int{true: 1, false: 0}[pinned]).Error
}

func SetMute(ctx context.Context, userID, convID int64, mute bool) error {
	return store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, userID).
		Update("mute", map[bool]int{true: 1, false: 0}[mute]).Error
}

// ConvMembers 会话成员（含用户信息，群设置展示）
func ConvMembers(ctx context.Context, userID, convID int64) ([]model.User, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	var members []model.ConversationMember
	if err := store.DB.Where("conversation_id = ?", convID).Find(&members).Error; err != nil {
		return nil, err
	}
	ids := make([]int64, 0, len(members))
	for _, m := range members {
		ids = append(ids, m.UserID)
	}
	if len(ids) == 0 {
		return []model.User{}, nil
	}
	var users []model.User
	if err := store.DB.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return nil, err
	}
	return users, nil
}

// SetPinMessage 置顶/取消置顶消息（群主/管理员；msgID=0 取消）
func SetPinMessage(ctx context.Context, userID, convID, msgID int64, content string) error {
	// 需求8：所有会话成员均可置顶消息（对齐微信：群主/管理员/普通成员都可置顶）
	if !isMember(ctx, convID, userID) {
		return errs.ConvNotFound
	}
	return store.DB.Model(&model.Conversation{}).
		Where("id = ?", convID).
		Updates(map[string]interface{}{"pinned_msg_id": msgID, "pinned_msg_content": content}).Error
}

// UpdateAnnouncement 更新群公告（群主/管理员）
func UpdateAnnouncement(ctx context.Context, userID, convID int64, zh, en string) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	updates := map[string]interface{}{}
	if zh != "" {
		updates["announcement_zh"] = zh
	}
	if en != "" {
		updates["announcement_en"] = en
	}
	if len(updates) == 0 {
		return nil
	}
	return store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Updates(updates).Error
}
