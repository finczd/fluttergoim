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
		fillDirectAvatar(ctx, &conv, otherID)
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
	fillDirectAvatar(ctx, &conv, otherID)
	return &conv, nil
}

// fillDirectAvatar 单聊会话裸记录通常不带头像：实时补对方用户头像与最近上线时间。
// 与 ConversationList 的补齐逻辑对齐——否则通讯录"创建会话→进资料页"路径
// 拿到的 avatar 恒为空，资料页头图只能显示首字母（聊天窗口走列表接口所以正常）。
func fillDirectAvatar(ctx context.Context, conv *model.Conversation, otherID int64) {
	u, err := GetUserDetail(ctx, otherID)
	if err != nil {
		return
	}
	conv.LastLoginAt = u.LastLoginAt
	if conv.Avatar == "" && u.Avatar != "" {
		conv.Avatar = u.Avatar
	}
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
	PeerID           int64              `json:"peerId,string"`    // 单聊对方雪花用户 ID（PC 转账 toUserId 精确识别收款人）
	PeerOnline       bool               `json:"peerOnline"`       // 单聊对方是否在线
	PeerOnlineDev    []string           `json:"peerOnlineDev"`    // 对方在线设备
	PeerOnlineZh     string             `json:"peerOnlineZh"`     // 对方在线类型中文（手机在线/H5在线/电脑在线）
	PeerOnlineIP     []string           `json:"peerOnlineIp"`     // 对方在线 IP（需求8）
	PeerShortID      string             `json:"peerShortId"`      // 对方靓号 ID（需求12：小助手固定 10000）
	PeerVipShortID   bool               `json:"peerVipShortId"`   // 对方是否靓号（预留池已绑定）→ 客户端资料页显示「靓ID」徽标
	PeerRemark       string             `json:"peerRemark"`       // 我对对方设置的备注
}

// ConvMemberInfo 会话成员（含群内角色与好友备注）
// 嵌入 model.User 内联用户字段，Role 覆盖为用户表全局角色（群内角色以本字段为准）
type ConvMemberInfo struct {
	model.User
	Role            int    `json:"role"`            // 群内角色：1=群主 2=管理员 3=普通成员
	Remark          string `json:"remark"`          // 好友备注（按当前用户视角，非好友为空）
	VipShortID      bool   `json:"vipShortId"`      // 是否靓号（预留池已绑定）→ 客户端资料页显示「靓ID」徽标
	SpeakMutedUntil int64  `json:"speakMutedUntil"` // 禁言截止时间戳（秒），0=未禁言（群主/管理员管理用）
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
					// 小助手虚拟账号（靓号 ID 固定 10000——需求12），昵称/头像取后台助手配置
					ac := GetAssistantConfig(ctx, nil)
					item.ConversationName = ac.Name
					item.PeerShortID = "10000"
					// 小助手永远在线（官方账号）
					item.PeerOnline = true
					item.PeerOnlineZh = "在线"
					// 后台设置的小助手头像下发到会话列表/聊天页
					if av := ac.Avatar; av != "" {
						item.Conversation.Avatar = av
					}
				} else {
				if u, err := GetUserDetail(ctx, otherID); err == nil {
					item.ConversationName = u.Nickname
					item.PeerShortID = model.StrVal(u.ShortID)
					item.PeerVipShortID = IsVipShortID(ctx, otherID, u.ShortID)
						if item.Conversation.Avatar == "" {
							item.Conversation.Avatar = u.Avatar
						}
						// 资料页"最近上线"数据源：聊天窗口路径的会话来自本列表
						item.Conversation.LastLoginAt = u.LastLoginAt
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

// getConv 加载会话（不存在/已解散返回 ConvNotFound）
func getConv(ctx context.Context, convID int64) (*model.Conversation, error) {
	var conv model.Conversation
	if err := store.DB.First(&conv, convID).Error; err != nil {
		return nil, errs.ConvNotFound
	}
	if conv.Status == model.ConvDisband {
		return nil, errs.ConvNotFound
	}
	return &conv, nil
}

func GroupInvite(ctx context.Context, userID, convID int64, memberIDs []int64) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		// 普通成员仅在群允许时才能邀请（群管理开关：允许成员邀请）
		conv, err := getConv(ctx, convID)
		if err != nil {
			return err
		}
		if conv.AllowMemberInvite != 1 {
			return errs.Forbidden
		}
	}
	added := make([]int64, 0, len(memberIDs))
	for _, uid := range memberIDs {
		var cnt int64
		store.DB.Model(&model.ConversationMember{}).
			Where("conversation_id = ? AND user_id = ?", convID, uid).Count(&cnt)
		if cnt == 0 {
			store.DB.Create(&model.ConversationMember{
				ConversationID: convID, UserID: uid, Role: model.MemberNormal, JoinedAt: time.Now(),
			})
			added = append(added, uid)
		}
	}
	// 群事件系统提示：邀请人进群（每新增一人一条，聊天流灰色提示）
	if actor := userName(userID); actor != "" {
		for _, uid := range added {
			b, _ := json.Marshal(map[string]interface{}{
				"kind": "invite", "actor": actor, "target": userName(uid),
			})
			sendGroupSystemMsg(ctx, convID, string(b))
		}
	}
	return nil
}

func GroupRemove(ctx context.Context, userID, convID, targetID int64) error {
	if userID == targetID {
		// 移除自己请走退出群（quit），这里直接拒绝避免误触
		return errs.Forbidden
	}
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	// 层级约束：不能移除群主；管理员只能移除普通成员
	targetRole := memberRole(ctx, convID, targetID)
	if targetRole == model.MemberOwner {
		return errs.Forbidden
	}
	if role == model.MemberAdmin && targetRole == model.MemberAdmin {
		return errs.Forbidden
	}
	targetName := userName(targetID)
	if err := store.DB.Where("conversation_id = ? AND user_id = ?", convID, targetID).
		Delete(&model.ConversationMember{}).Error; err != nil {
		return err
	}
	// 群事件系统提示：成员被移出群聊
	if actor := userName(userID); actor != "" && targetName != "" {
		b, _ := json.Marshal(map[string]interface{}{
			"kind": "kick", "actor": actor, "target": targetName,
		})
		sendGroupSystemMsg(ctx, convID, string(b))
	}
	return nil
}

func GroupQuit(ctx context.Context, userID, convID int64) error {
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&cnt)
	if cnt <= 1 {
		// 最后一人退出 → 解散（不再发退出提示）
		store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Update("status", model.ConvDisband)
	}
	name := userName(userID)
	if err := store.DB.Where("conversation_id = ? AND user_id = ?", convID, userID).
		Delete(&model.ConversationMember{}).Error; err != nil {
		return err
	}
	// 群事件系统提示：成员退出群聊
	if name != "" && cnt > 1 {
		b, _ := json.Marshal(map[string]interface{}{"kind": "quit", "target": name})
		sendGroupSystemMsg(ctx, convID, string(b))
	}
	return nil
}

func GroupDisband(ctx context.Context, userID, convID int64) error {
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner {
		return errs.Forbidden
	}
	store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Update("status", model.ConvDisband)
	return store.DB.Where("conversation_id = ?", convID).Delete(&model.ConversationMember{}).Error
}

func GroupUpdate(ctx context.Context, userID, convID int64, nameZh, nameEn, announcementZh, announcementEn, avatar string) error {
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
	if avatar != "" {
		updates["avatar"] = avatar
	}
	if len(updates) == 0 {
		return nil
	}
	return store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Updates(updates).Error
}

// ============ 群聊管理（群主/管理员） ============

// GroupSettings 群管理设置（群管理页读写）
type GroupSettings struct {
	MuteAll           bool `json:"muteAll"`           // 全员禁言：仅群主/管理员可发言
	PrivacyEnabled    bool `json:"privacyEnabled"`    // 成员隐私：普通成员不可查看成员列表
	AllowMemberInvite bool `json:"allowMemberInvite"` // 允许群成员邀请成员
	QrJoinEnabled     bool `json:"qrJoinEnabled"`     // 二维码进群
}

// GetGroupSettings 读取群管理设置（全体成员可读：成员页需要按"允许邀请"决定是否显示邀请入口）
func GetGroupSettings(ctx context.Context, userID, convID int64) (*GroupSettings, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	conv, err := getConv(ctx, convID)
	if err != nil {
		return nil, err
	}
	return &GroupSettings{
		MuteAll:           conv.MuteAll == 1,
		PrivacyEnabled:    conv.PrivacyEnabled == 1,
		AllowMemberInvite: conv.AllowMemberInvite == 1,
		QrJoinEnabled:     conv.QrJoinEnabled == 1,
	}, nil
}

// SetGroupSettings 更新群管理设置（仅群主）
func SetGroupSettings(ctx context.Context, userID, convID int64, s *GroupSettings) error {
	if memberRole(ctx, convID, userID) != model.MemberOwner {
		return errs.Forbidden
	}
	old, err := getConv(ctx, convID)
	if err != nil {
		return err
	}
	b2i := map[bool]int{true: 1, false: 0}
	if err := store.DB.Model(&model.Conversation{}).Where("id = ?", convID).Updates(map[string]interface{}{
		"mute_all":            b2i[s.MuteAll],
		"privacy_enabled":     b2i[s.PrivacyEnabled],
		"allow_member_invite": b2i[s.AllowMemberInvite],
		"qr_join_enabled":     b2i[s.QrJoinEnabled],
	}).Error; err != nil {
		return err
	}
	// 群事件系统提示：全员禁言开启/解除（仅状态变化时发）
	if (old.MuteAll == 1) != s.MuteAll {
		kind := "muteAllOff"
		if s.MuteAll {
			kind = "muteAllOn"
		}
		payload := map[string]interface{}{"kind": kind, "actor": userName(userID)}
		b, _ := json.Marshal(payload)
		sendGroupSystemMsg(ctx, convID, string(b))
	}
	return nil
}

// SetGroupAdmin 设置/取消管理员（仅群主；目标必须是普通成员/管理员，不能操作群主）
func SetGroupAdmin(ctx context.Context, userID, convID, targetID int64, admin bool) error {
	if memberRole(ctx, convID, userID) != model.MemberOwner {
		return errs.Forbidden
	}
	if targetID == userID {
		return errs.Forbidden
	}
	targetRole := memberRole(ctx, convID, targetID)
	if targetRole == model.MemberOwner {
		return errs.Forbidden
	}
	want := model.MemberAdmin
	if !admin {
		want = model.MemberNormal
	}
	// 目标不是成员或已是期望角色则拒绝
	if targetRole != model.MemberAdmin && targetRole != model.MemberNormal {
		return errs.ConvNotFound
	}
	if targetRole == want {
		return nil
	}
	return store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, targetID).
		Update("role", want).Error
}

// MuteMember 禁言/解除禁言成员（群主/管理员；不能禁言群主；管理员不能禁言管理员）
func MuteMember(ctx context.Context, userID, convID, targetID int64, mute bool, minutes int) error {
	if userID == targetID {
		return errs.Forbidden
	}
	role := memberRole(ctx, convID, userID)
	if role != model.MemberOwner && role != model.MemberAdmin {
		return errs.Forbidden
	}
	targetRole := memberRole(ctx, convID, targetID)
	if targetRole == model.MemberOwner {
		return errs.Forbidden
	}
	if role == model.MemberAdmin && targetRole == model.MemberAdmin {
		return errs.Forbidden
	}
	until := int64(0)
	if mute {
		if minutes <= 0 {
			minutes = 10
		}
		if minutes > 43200 { // 上限 30 天
			minutes = 43200
		}
		until = time.Now().Add(time.Duration(minutes) * time.Minute).Unix()
	}
	if err := store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, targetID).
		Update("speak_muted_until", until).Error; err != nil {
		return err
	}
	// 群事件系统提示：禁言/解除禁言
	if actor := userName(userID); actor != "" {
		kind := "unmute"
		payload := map[string]interface{}{
			"kind": kind, "actor": actor, "target": userName(targetID),
		}
		if mute {
			payload["kind"] = "mute"
			payload["minutes"] = minutes
		}
		b, _ := json.Marshal(payload)
		sendGroupSystemMsg(ctx, convID, string(b))
	}
	return nil
}

// GroupJoin 扫群二维码进群（需群开启"二维码进群"；群未解散；未满员）
func GroupJoin(ctx context.Context, userID, convID int64) (*model.Conversation, error) {
	conv, err := getConv(ctx, convID)
	if err != nil {
		return nil, err
	}
	if conv.Type != model.ConvGroup {
		return nil, errs.ConvNotFound
	}
	if conv.QrJoinEnabled != 1 {
		return nil, errs.Forbidden
	}
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&cnt)
	if cnt >= int64(conv.MaxMembers) {
		return nil, errs.GroupFull
	}
	var exist int64
	store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, userID).Count(&exist)
	if exist == 0 {
		store.DB.Create(&model.ConversationMember{
			ConversationID: convID, UserID: userID, Role: model.MemberNormal, JoinedAt: time.Now(),
		})
		// 群事件系统提示：扫码新成员加入
		if name := userName(userID); name != "" {
			b, _ := json.Marshal(map[string]interface{}{"kind": "join", "target": name})
			sendGroupSystemMsg(ctx, convID, string(b))
		}
	}
	return conv, nil
}

// GroupPreview 扫码进群前的群信息预览（二次确认页用；已登录即可，不要求是成员）
func GroupPreview(ctx context.Context, convID int64) (*model.Conversation, int64, error) {
	conv, err := getConv(ctx, convID)
	if err != nil || conv.Type != model.ConvGroup {
		return nil, 0, errs.ConvNotFound
	}
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&cnt)
	return conv, cnt, nil
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
// 返回值：成员列表 + 群成员总数。
// 成员隐私开启时，普通成员只下发前 15 个成员（资料页 2 排预览），总数照实返回。
func ConvMembers(ctx context.Context, userID, convID int64) ([]ConvMemberInfo, int64, error) {
	if !isMember(ctx, convID, userID) {
		return nil, 0, errs.ConvNotFound
	}
	conv, err := getConv(ctx, convID)
	if err != nil {
		return nil, 0, err
	}
	privacyLimited := conv.PrivacyEnabled == 1 && memberRole(ctx, convID, userID) == model.MemberNormal
	var members []model.ConversationMember
	q := store.DB.Where("conversation_id = ?", convID)
	// 群主(1)→管理员(2)→普通成员(3)，同角色按进群时间先后（群主永远排第一）
	q = q.Order("role ASC, joined_at ASC, id ASC")
	if privacyLimited {
		q = q.Limit(15)
	}
	if err := q.Find(&members).Error; err != nil {
		return nil, 0, err
	}
	var total int64
	if privacyLimited {
		store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", convID).Count(&total)
	} else {
		total = int64(len(members))
	}
	ids := make([]int64, 0, len(members))
	roleMap := make(map[int64]int, len(members))
	muteMap := make(map[int64]int64, len(members))
	for _, m := range members {
		ids = append(ids, m.UserID)
		roleMap[m.UserID] = m.Role
		muteMap[m.UserID] = m.SpeakMutedUntil
	}
	if len(ids) == 0 {
		return []ConvMemberInfo{}, total, nil
	}
	var users []model.User
	if err := store.DB.Where("id IN ?", ids).Find(&users).Error; err != nil {
		return nil, 0, err
	}
	userMap := make(map[int64]model.User, len(users))
	for _, u := range users {
		userMap[u.ID] = u
	}
	// 按当前用户视角补好友备注（群聊 @ 昵称等场景可用备注名）
	remarks := friendRemarkMap(ctx, userID, ids)
	// 输出顺序跟随 members 排序：群主→管理员→普通成员，同角色按进群时间
	out := make([]ConvMemberInfo, 0, len(members))
	for _, m := range members {
		u, ok := userMap[m.UserID]
		if !ok {
			continue
		}
		out = append(out, ConvMemberInfo{
			User:            u,
			Role:            roleMap[u.ID],
			Remark:          remarks[u.ID],
			VipShortID:      IsVipShortID(ctx, u.ID, u.ShortID),
			SpeakMutedUntil: muteMap[u.ID],
		})
	}
	return out, total, nil
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
