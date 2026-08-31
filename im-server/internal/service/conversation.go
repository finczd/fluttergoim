package service

import (
	"context"
	"encoding/json"
	"fmt"
	"sort"
	"strconv"
	"strings"
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
	Conversation     model.Conversation `json:"conversation"`
	Unread           int64              `json:"unread"`
	LastMessage      *model.Message     `json:"lastMessage"`
	MemberCount      int64              `json:"memberCount"`
	Mute             bool               `json:"mute"`
	Pinned           bool               `json:"pinned"`
	ConversationName string             `json:"conversationName"` // 单聊显示对方昵称
	PeerID           int64              `json:"peerId,string"`     // 单聊对方雪花用户 ID（PC 转账 toUserId 精确识别收款人）
	PeerOnline       bool               `json:"peerOnline"`       // 单聊对方是否在线
	PeerOnlineDev    []string           `json:"peerOnlineDev"`    // 对方在线设备
	PeerOnlineZh     string             `json:"peerOnlineZh"`     // 对方在线类型中文（手机在线/H5在线/电脑在线）
	PeerOnlineIP     []string           `json:"peerOnlineIp"`     // 对方在线 IP（需求8）
	PeerShortID      string             `json:"peerShortId"`      // 对方靓号 ID（需求12：小助手固定 10000）
	PeerRemark       string             `json:"peerRemark"`       // 我对对方设置的备注
}

// ConvMemberInfo 会话成员（含群内角色与好友备注）
// 嵌入 model.User 内联用户字段，Role 覆盖为用户表全局角色（群内角色以本字段为准）
type ConvMemberInfo struct {
	model.User
	Role   int    `json:"role"`   // 群内角色：1=群主 2=管理员 3=普通成员
	Remark string `json:"remark"` // 好友备注（按当前用户视角，非好友为空）
}

// friendRemark 查询当前用户对某好友设置的备注（无则返回空）
func friendRemark(ctx context.Context, userID, friendID int64) string {
	var rel model.FriendRelation
	if err := store.DB.Where("user_id = ? AND friend_id = ?", userID, friendID).
		First(&rel).Error; err != nil {
		return ""
	}
	return rel.Remark
}

// friendRemarkMap 批量查询当前用户对多个好友的备注
func friendRemarkMap(ctx context.Context, userID int64, friendIDs []int64) map[int64]string {
	out := make(map[int64]string, len(friendIDs))
	if len(friendIDs) == 0 {
		return out
	}
	var rels []model.FriendRelation
	store.DB.Where("user_id = ? AND friend_id IN ?", userID, friendIDs).Find(&rels)
	for _, r := range rels {
		if r.Remark != "" {
			out[r.FriendID] = r.Remark
		}
	}
	return out
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
				item.PeerID = otherID
				if otherID == -1 {
					// 小助手虚拟账号（名称固定"小助手"，靓号 ID 固定 10000——需求12）
					item.ConversationName = "小助手"
					item.PeerShortID = "10000"
				} else {
					if u, err := GetUserDetail(ctx, otherID); err == nil {
						item.ConversationName = u.Nickname
						item.PeerShortID = model.StrVal(u.ShortID)
						if item.Conversation.Avatar == "" {
							item.Conversation.Avatar = u.Avatar
						}
					}
					// 需求：设置了备注则优先显示备注名
					item.PeerRemark = friendRemark(ctx, userID, otherID)
					if item.PeerRemark != "" {
						item.ConversationName = item.PeerRemark
					}
					online, devs := IsUserOnline(ctx, otherID)
					item.PeerOnline = online
					item.PeerOnlineDev = devs
					item.PeerOnlineZh = OnlineDeviceZh(devs)
					item.PeerOnlineIP = OnlineIPs(ctx, otherID)
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
func ConvMembers(ctx context.Context, userID, convID int64) ([]ConvMemberInfo, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	var members []model.ConversationMember
	if err := store.DB.Where("conversation_id = ?", convID).Find(&members).Error; err != nil {
		return nil, err
	}
	ids := make([]int64, 0, len(members))
	roleMap := make(map[int64]int, len(members))
	for _, m := range members {
		ids = append(ids, m.UserID)
		roleMap[m.UserID] = m.Role
	}
	if len(ids) == 0 {
		return []ConvMemberInfo{}, nil
	}
	var users []model.User
	if err := store.DB.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return nil, err
	}
	// 按当前用户视角补好友备注（群聊 @ 昵称等场景可用备注名）
	remarks := friendRemarkMap(ctx, userID, ids)
	out := make([]ConvMemberInfo, 0, len(users))
	for _, u := range users {
		out = append(out, ConvMemberInfo{
			User:   u,
			Role:   roleMap[u.ID],
			Remark: remarks[u.ID],
		})
	}
	return out, nil
}

// SetPinMessage 置顶/取消置顶消息（所有成员可置顶；支持多条 pinnedMsgIDs 列表）
// pinned=true 追加；pinned=false 或 msgID=0 时移除
func SetPinMessage(ctx context.Context, userID, convID, msgID int64, content string, pinned bool) error {
	if !isMember(ctx, convID, userID) {
		return errs.ConvNotFound
	}
	var conv model.Conversation
	if err := store.DB.First(&conv, convID).Error; err != nil {
		return errs.ConvNotFound
	}
	ids := []string{}
	if conv.PinnedMsgIDs != "" {
		_ = json.Unmarshal([]byte(conv.PinnedMsgIDs), &ids)
	}
	key := strconv.FormatInt(msgID, 10)
	if msgID > 0 && pinned {
		// 追加（去重）
		found := false
		for _, v := range ids {
			if v == key {
				found = true
				break
			}
		}
		if !found {
			ids = append(ids, key)
		}
	} else {
		// 移除
		out := ids[:0]
		for _, v := range ids {
			if v != key {
				out = append(out, v)
			}
		}
		ids = out
	}
	idsJSON, _ := json.Marshal(ids)
	updates := map[string]interface{}{
		"pinned_msg_ids": string(idsJSON),
	}
	// 兼容旧单条字段：最新一条作为 pinnedMsgId/Content
	if len(ids) > 0 {
		updates["pinned_msg_id"] = msgID
		updates["pinned_msg_content"] = content
	} else {
		updates["pinned_msg_id"] = 0
		updates["pinned_msg_content"] = ""
	}
	return store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Updates(updates).Error
}

// PinnedMsgBrief 置顶消息简项（按置顶顺序，前端渲染卡片 + 点击跳转）
type PinnedMsgBrief struct {
	MsgID      string `json:"msgId,string"`
	Content    string `json:"content"`
	SenderName string `json:"senderName"`
	Type       int    `json:"type"`
	CreatedAt  string `json:"createdAt"`
}

// PinnedMessages 置顶消息列表（按置顶顺序返回完整简项，需求：支持多条 + 切换）
func PinnedMessages(ctx context.Context, userID, convID int64) ([]PinnedMsgBrief, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	var conv model.Conversation
	if err := store.DB.First(&conv, convID).Error; err != nil {
		return nil, errs.ConvNotFound
	}
	ids := []string{}
	if conv.PinnedMsgIDs != "" {
		_ = json.Unmarshal([]byte(conv.PinnedMsgIDs), &ids)
	}
	if len(ids) == 0 && conv.PinnedMsgID > 0 {
		// 兼容旧单条字段
		ids = []string{strconv.FormatInt(conv.PinnedMsgID, 10)}
	}
	if len(ids) == 0 {
		return []PinnedMsgBrief{}, nil
	}
	intIDs := make([]int64, 0, len(ids))
	for _, v := range ids {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil && n > 0 {
			intIDs = append(intIDs, n)
		}
	}
	if len(intIDs) == 0 {
		return []PinnedMsgBrief{}, nil
	}
	// 消息存 MongoDB，发送者存 MySQL——两个数据源分别查
	cur, err := msgColl().Find(ctx, bson.M{"msg_id": bson.M{"$in": intIDs}})
	if err != nil {
		return nil, err
	}
	var msgs []model.Message
	if err := cur.All(ctx, &msgs); err != nil {
		return nil, err
	}
	if len(msgs) == 0 {
		return []PinnedMsgBrief{}, nil
	}
	msgMap := make(map[int64]model.Message, len(msgs))
	for _, m := range msgs {
		msgMap[m.MsgID] = m
	}
	// 发送者昵称（MySQL user 表）
	senderIDs := make([]int64, 0, len(msgs))
	for _, m := range msgs {
		senderIDs = append(senderIDs, m.SenderID)
	}
	senderMap := make(map[int64]string)
	if len(senderIDs) > 0 {
		senders := make([]model.User, 0)
		sIn := buildInInt64(senderIDs)
		store.DB.Raw(
			"SELECT * FROM user WHERE id IN (" + sIn + ")",
		).Scan(&senders)
		for _, u := range senders {
			senderMap[u.ID] = u.Nickname
		}
	}
	// 按置顶顺序组装
	out := make([]PinnedMsgBrief, 0, len(intIDs))
	for _, id := range intIDs {
		m, ok := msgMap[id]
		if !ok {
			continue
		}
		out = append(out, PinnedMsgBrief{
			MsgID:      strconv.FormatInt(m.MsgID, 10),
			Content:    m.Content,
			SenderName: senderMap[m.SenderID],
			Type:       m.Type,
			CreatedAt:  m.CreatedAt.Format("2006-01-02 15:04"),
		})
	}
	return out, nil
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

// buildInInt64 把 int64 列表拼成 SQL IN 子句（绕开 GORM 1.25+ IN ? 大整数 bug）
func buildInInt64(ids []int64) string {
	parts := make([]string, 0, len(ids))
	for _, v := range ids {
		parts = append(parts, strconv.FormatInt(v, 10))
	}
	return strings.Join(parts, ",")
}
