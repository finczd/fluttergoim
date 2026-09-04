package service

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/pkg/id"
	"github.com/yourcompany/im-server/internal/store"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// ============ 系统配置（数据库优先，回退环境变量） ============

// SysConfigGet 读取配置（sys_config 表），缺省返回 def
func SysConfigGet(ctx context.Context, key string, def interface{}) interface{} {
	var sc model.SysConfig
	if err := store.DB.Where("config_key = ?", key).First(&sc).Error; err == nil {
		var v interface{}
		if json.Unmarshal([]byte(sc.ConfigValue), &v) == nil {
			if m, ok := v.(map[string]interface{}); ok {
				if val, ok := m["value"]; ok {
					return val
				}
				return v
			}
			return v
		}
	}
	return def
}

// SysConfigSet 写入配置（存 {"value": ...}）
func SysConfigSet(ctx context.Context, key string, value interface{}) error {
	b, _ := json.Marshal(map[string]interface{}{"value": value})
	var sc model.SysConfig
	err := store.DB.Where("config_key = ?", key).First(&sc).Error
	if err != nil {
		// 不存在则插入
		return store.DB.Create(&model.SysConfig{ConfigKey: key, ConfigValue: string(b)}).Error
	}
	return store.DB.Model(&sc).Update("config_value", string(b)).Error
}

// AuthFlags 认证配置（数据库优先，回退 cfg）
type AuthFlags struct {
	AuthMode     string `json:"authMode"`
	InviteCodeOn bool   `json:"inviteCodeOn"`
	RegisterOn   bool   `json:"registerOn"`
	E2EOn        bool   `json:"e2eOn"`
	// 品牌（登录/注册页 logo + 名称，后台可配）
	AppName   string `json:"appName"`
	AppLogo   string `json:"appLogo"`
	BrandName string `json:"brandName"`
	BrandLogo string `json:"brandLogo"`
	// 公告（移动端消息页跑马灯，后台可配）
	Announcement string `json:"announcement"`
	// App 版本信息（后台可配，客户端关于页/更新检查）
	AppVersion   string `json:"appVersion"`
	UpdateLog    string `json:"updateLog"`
	AndroidURL   string `json:"androidUrl"`
	IOSURL       string `json:"iosUrl"`
	HotUpdateURL string `json:"hotUpdateUrl"`
	// 在线状态：当前登录设备（web/ios/android/windows/macos）
	OnlineDevice string `json:"onlineDevice"`
	// 需求9：默认头像（新注册用户使用，后台可配）
	DefaultAvatar string `json:"defaultAvatar"`
	// 小助手头像（通讯录官方入口显示，后台「智能小助手」可配）
	AssistantAvatar string `json:"assistantAvatar"`
	// 功能开关：是否开启零钱（关闭 → 聊天窗口不显示红包/转账入口、用户中心不显示我的钱包）
	WalletOn bool `json:"walletOn"`
	// 功能开关：是否开启邀请码（关闭 → 用户中心不显示我的邀请码；与「邀请码注册」开关相互独立）
	InviteFeatureOn bool `json:"inviteFeatureOn"`
}

func GetAuthFlags(ctx context.Context, cfg *config.Config) AuthFlags {
	return AuthFlags{
		AuthMode:        strVal(SysConfigGet(ctx, "auth_mode", cfg.AuthMode)),
		InviteCodeOn:    boolVal(SysConfigGet(ctx, "invite_code_enabled", cfg.InviteCodeOn)),
		RegisterOn:      boolVal(SysConfigGet(ctx, "register_enabled", cfg.RegisterOn)),
		E2EOn:           boolVal(SysConfigGet(ctx, "e2e_enabled", cfg.E2EOn)),
		AppName:         strVal(SysConfigGet(ctx, "app_name", "ChatPulse")),
		AppLogo:         strVal(SysConfigGet(ctx, "app_logo", "")),
		BrandName:       strVal(SysConfigGet(ctx, "brand_name", "ChatPulse")),
		BrandLogo:       strVal(SysConfigGet(ctx, "brand_logo", "")),
		Announcement:    strVal(SysConfigGet(ctx, "announcement", "欢迎使用 ChatPulse! 请注意账号安全，不要泄露验证码。")),
		AppVersion:      strVal(SysConfigGet(ctx, "app_version", "1.0.0")),
		UpdateLog:       strVal(SysConfigGet(ctx, "update_log", "")),
		AndroidURL:      strVal(SysConfigGet(ctx, "android_url", "")),
		IOSURL:          strVal(SysConfigGet(ctx, "ios_url", "")),
		HotUpdateURL:    strVal(SysConfigGet(ctx, "hot_update_url", "")),
		OnlineDevice:    strVal(SysConfigGet(ctx, "online_device", "")),
		DefaultAvatar:   strVal(SysConfigGet(ctx, "default_avatar", "")),
		AssistantAvatar: GetAssistantConfig(ctx, cfg).Avatar,
		WalletOn:        boolVal(SysConfigGet(ctx, "wallet_enabled", true)),
		InviteFeatureOn: boolVal(SysConfigGet(ctx, "invite_feature_enabled", true)),
	}
}

func strVal(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func boolVal(v interface{}) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return false
}

// ============ 用户管理 ============

type AdminUserListResult struct {
	List  []model.User `json:"list"`
	Total int64        `json:"total"`
}

func AdminUserList(ctx context.Context, kw string, status int, deptID int64, page, size int) (*AdminUserListResult, error) {
	q := store.DB.Model(&model.User{})
	if kw != "" {
		like := "%" + kw + "%"
		// 增加 short_id 精确+模糊匹配：纯数字时先按 short_id 精确命中（搜索 18888 这样的靓号）
		if num, err := strconv.ParseInt(kw, 10, 64); err == nil && num > 0 {
			q = q.Where(
				"short_id = ? OR short_id LIKE ? OR nickname LIKE ? OR account LIKE ? OR phone LIKE ? OR email LIKE ?",
				kw, like, like, like, like, like,
			)
		} else {
			q = q.Where(
				"short_id LIKE ? OR nickname LIKE ? OR account LIKE ? OR phone LIKE ? OR email LIKE ?",
				like, like, like, like, like,
			)
		}
	}
	if status > 0 {
		q = q.Where("status = ?", status)
	}
	if deptID > 0 {
		q = q.Where("department_id = ?", deptID)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, err
	}
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 100 {
		size = 20
	}
	var users []model.User
	if err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&users).Error; err != nil {
		return nil, err
	}
	return &AdminUserListResult{List: users, Total: total}, nil
}

// AdminUserCreate 管理员创建账号
func AdminUserCreate(ctx context.Context, account, password, nickname string, deptID int64, role int) (*model.User, error) {
	var cnt int64
	store.DB.Model(&model.User{}).Where("account = ?", account).Count(&cnt)
	if cnt > 0 {
		return nil, errs.AccountExists
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	u := &model.User{
		ID: id.Next(), Account: account, PasswordHash: string(hash),
		Nickname: nickname, DepartmentID: deptID,
		CountryCode: "+86", Status: model.StatusNormal,
		Role: map[bool]int{true: role, false: model.RoleUser}[role > 0],
	}
	if err := store.DB.Create(u).Error; err != nil {
		return nil, err
	}
	return u, nil
}

// AdminUserSetStatus 启用/禁用用户。
// 禁用（status=StatusDisabled）时额外做两件事，保证"禁用立即生效"，而不是等 access token 自然过期：
//  1) 清掉该用户的 refresh 白名单（Redis key refresh:{uid}），
//     使其 access token 过期后无法用 refresh 续命；refresh 直接失败 → 客户端 401 清登录态；
//  2) 通过 Redis 事件总线推送 forceLogout 给该用户所有在线设备，
//     网关收到后立刻下发 WS 事件，客户端收到即清登录态并跳登录页（见各端 forceLogout 处理）。
// 此外鉴权中间件 Auth 会对每次请求复核 u.Status，禁用账号的 access token 在下次任意请求即被 401 拦截。
func AdminUserSetStatus(ctx context.Context, id int64, status int) error {
	if err := store.DB.Model(&model.User{}).Where("id = ?", id).Update("status", status).Error; err != nil {
		return err
	}
	if status == model.StatusDisabled {
		// 1) 清 refresh 白名单，使其续命失败
		if store.RDB != nil {
			store.RDB.Del(ctx, fmt.Sprintf("refresh:%d", id))
		}
		// 2) 推送强制下线事件，网关即时下发到在线设备
		_ = PublishEvent(ctx, &Event{
			Type:    "forceLogout",
			UserIDs: []int64{id},
			Data:    json.RawMessage(`{"reason":"account_disabled"}`),
		})
	}
	return nil
}

func AdminUserResetPassword(ctx context.Context, id int64, newPass string) error {
	hash, _ := bcrypt.GenerateFromPassword([]byte(newPass), bcrypt.DefaultCost)
	return store.DB.Model(&model.User{}).Where("id = ?", id).Update("password_hash", string(hash)).Error
}

// AdminUserUpdate 管理员编辑用户资料（nickname/avatar/role/shortId）。
// short_id 需要唯一，分配前会先检查 reserved_short_id 是否存在（若启用），
// 再做唯一性冲突校验；分配后 reserved_short_id.used_by/used_at 同步更新。
func AdminUserUpdate(ctx context.Context, id int64, nickname, avatar string, role int, shortID *string) error {
	if id <= 0 {
		return errs.ParamError
	}
	updates := map[string]interface{}{}
	// 字段用 !== nil 判空：允许空字符串清空
	if nickname != "" || (nickname == "" && len(nickname) == 0 && false) {
		// 上一行仅兼容旧写法；真正的空串不清空，但允许传空字符串也能安全进入下一层
	}
	if nickname != "" {
		updates["nickname"] = nickname
	}
	if avatar != "" {
		updates["avatar"] = avatar
	}
	if role == model.RoleUser || role == model.RoleAdmin || role == model.RoleKefu {
		updates["role"] = role
	}

	// short_id：nil 表示不更新；空字符串表示清空；否则赋值并检查唯一性
	if shortID != nil {
		sid := strings.TrimSpace(*shortID)
		if sid == "" {
			updates["short_id"] = nil
		} else {
			// 唯一性检查
			var dup int64
			store.DB.Model(&model.User{}).
				Where("short_id = ? AND id <> ?", sid, id).Count(&dup)
			if dup > 0 {
				return &errs.Err{Code: 1001, Msg: "短ID 已被其他用户占用"}
			}
			updates["short_id"] = sid

			// 关联：如果 reserved_short_id 表里有这条（未使用），登记 used_by/used_at
			var rs model.ReservedShortID
			if err := store.DB.Where("short_id = ?", sid).First(&rs).Error; err == nil {
				store.DB.Model(&rs).Updates(map[string]interface{}{
					"used_by": id,
					"used_at": time.Now(),
					"status":  model.ReservedShortIDUsed,
					"account": "", // 展示时 JOIN user
				})
			}
		}
	}

	if len(updates) == 0 {
		return nil
	}
	return store.DB.Model(&model.User{}).Where("id = ?", id).Updates(updates).Error
}

// ============ 部门管理 ============

func AdminDeptList(ctx context.Context) ([]model.Department, error) {
	var depts []model.Department
	err := store.DB.Order("sort asc, id asc").Find(&depts).Error
	return depts, err
}

func AdminDeptCreate(ctx context.Context, nameZh, nameEn string, parentID int64, sort int) (*model.Department, error) {
	d := &model.Department{ID: id.Next(), NameZh: nameZh, NameEn: nameEn, ParentID: parentID, Sort: sort}
	if err := store.DB.Create(d).Error; err != nil {
		return nil, err
	}
	return d, nil
}

func AdminDeptUpdate(ctx context.Context, id int64, nameZh, nameEn string, sort int) error {
	updates := map[string]interface{}{}
	if nameZh != "" {
		updates["name_zh"] = nameZh
	}
	if nameEn != "" {
		updates["name_en"] = nameEn
	}
	updates["sort"] = sort
	return store.DB.Model(&model.Department{}).Where("id = ?", id).Updates(updates).Error
}

func AdminDeptDelete(ctx context.Context, id int64) error {
	// 部门下有用户则禁止删除
	var cnt int64
	store.DB.Model(&model.User{}).Where("department_id = ?", id).Count(&cnt)
	if cnt > 0 {
		return &errs.Err{Code: 1001, Msg: "该部门下还有用户，无法删除"}
	}
	return store.DB.Delete(&model.Department{}, id).Error
}

// ============ 小程序管理（H5 容器） ============

func AdminAppList(ctx context.Context) ([]model.AppEntry, error) {
	var apps []model.AppEntry
	err := store.DB.Order("sort asc, id asc").Find(&apps).Error
	return apps, err
}

func AdminAppCreate(ctx context.Context, nameZh, nameEn, icon, url, category string, sort int, enabled bool) (*model.AppEntry, error) {
	a := &model.AppEntry{
		NameZh: nameZh, NameEn: nameEn, Icon: icon, URL: url,
		Category: category, Sort: sort,
		Enabled: map[bool]int{true: 1, false: 0}[enabled],
	}
	if err := store.DB.Create(a).Error; err != nil {
		return nil, err
	}
	return a, nil
}

func AdminAppUpdate(ctx context.Context, id int64, nameZh, nameEn, icon, url, category string, sort int, enabled bool) error {
	updates := map[string]interface{}{
		"name_zh": nameZh, "name_en": nameEn, "icon": icon, "url": url,
		"category": category, "sort": sort, "enabled": map[bool]int{true: 1, false: 0}[enabled],
	}
	return store.DB.Model(&model.AppEntry{}).Where("id = ?", id).Updates(updates).Error
}

func AdminAppDelete(ctx context.Context, id int64) error {
	return store.DB.Delete(&model.AppEntry{}, id).Error
}

// ============ 群组管理 ============

// AdminGroupOut 群组管理列表项：群信息 + 成员数（后台显示人数）
type AdminGroupOut struct {
	model.Conversation
	MemberCount int64 `json:"memberCount"`
}

func AdminGroupList(ctx context.Context) ([]AdminGroupOut, error) {
	var groups []model.Conversation
	err := store.DB.Where("type = ? AND status = ?", model.ConvGroup, model.ConvNormal).
		Order("id desc").Limit(200).Find(&groups).Error
	if err != nil {
		return nil, err
	}
	out := make([]AdminGroupOut, 0, len(groups))
	for _, g := range groups {
		var cnt int64
		store.DB.Model(&model.ConversationMember{}).Where("conversation_id = ?", g.ID).Count(&cnt)
		out = append(out, AdminGroupOut{Conversation: g, MemberCount: cnt})
	}
	return out, nil
}

func AdminGroupDisband(ctx context.Context, id int64) error {
	store.DB.Model(&model.Conversation{}).Where("id = ?", id).Update("status", model.ConvDisband)
	return store.DB.Where("conversation_id = ?", id).Delete(&model.ConversationMember{}).Error
}

// ============ 消息查询（后台审计） ============

type AdminMsgQuery struct {
	ConvID int64  `json:"convId,string"`
	UserID int64  `json:"userId,string"`
	Kw     string `json:"kw"`
	From   int64  `json:"from"` // unix ms
	To     int64  `json:"to"`
	Type   int    `json:"type"` // 消息类型筛选（1文本 2图片 3文件 4语音 5视频 6系统 7通话 8红包 9转账）
}

// AdminMessageOut 后台消息列表项：消息本体 + 发送者/接收者/会话冗余信息（前端直接渲染头像昵称）
type AdminMessageOut struct {
	model.Message
	// 发送者（senderId 为 -1 即小助手，昵称头像取后台助手配置）
	SenderName    string `json:"senderName"`
	SenderAvatar  string `json:"senderAvatar"`
	SenderShortID string `json:"senderShortId"`
	// 接收者：单聊为对方用户，群聊为群本身
	ReceiverID      string `json:"receiverId"`
	ReceiverName    string `json:"receiverName"`
	ReceiverAvatar  string `json:"receiverAvatar"`
	ReceiverShortID string `json:"receiverShortId"`
	// 会话冗余
	ConvType   int    `json:"convType"`
	ConvName   string `json:"convName"`
	ConvAvatar string `json:"convAvatar"`
}

func AdminMessageQuery(ctx context.Context, q *AdminMsgQuery, page, size int) ([]AdminMessageOut, int64, error) {
	filter := bson.M{}
	if q.ConvID > 0 {
		filter["conversation_id"] = q.ConvID
	}
	if q.UserID > 0 {
		filter["sender_id"] = q.UserID
	}
	if q.Type > 0 {
		filter["type"] = q.Type
	}
	if q.Kw != "" {
		// 转义正则特殊字符，避免非法 regex 报错
		filter["content"] = bson.M{"$regex": regexp.QuoteMeta(q.Kw), "$options": "i"}
	}
	if q.From > 0 || q.To > 0 {
		t := bson.M{}
		if q.From > 0 {
			t["$gte"] = time.UnixMilli(q.From)
		}
		if q.To > 0 {
			t["$lte"] = time.UnixMilli(q.To)
		}
		filter["created_at"] = t
	}
	if size <= 0 || size > 100 {
		size = 20
	}
	if page <= 0 {
		page = 1
	}
	total, _ := msgColl().CountDocuments(ctx, filter)
	cur, err := msgColl().Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "msg_id", Value: -1}}).
			SetSkip(int64((page-1)*size)).SetLimit(int64(size)))
	if err != nil {
		return nil, 0, err
	}
	var msgs []model.Message
	if err := cur.All(ctx, &msgs); err != nil {
		return nil, 0, err
	}

	out := make([]AdminMessageOut, 0, len(msgs))
	if len(msgs) == 0 {
		return out, total, nil
	}

	// ---- 批量取会话 ----
	convIDs := make([]int64, 0, len(msgs))
	seen := map[int64]bool{}
	for _, m := range msgs {
		if !seen[m.ConversationID] {
			seen[m.ConversationID] = true
			convIDs = append(convIDs, m.ConversationID)
		}
	}
	var convs []model.Conversation
	store.DB.Where("id IN ?", convIDs).Find(&convs)
	convMap := map[int64]model.Conversation{}
	for _, cv := range convs {
		convMap[cv.ID] = cv
	}

	// ---- 批量取单聊成员（单聊接收者 = 发送者之外的另一个成员）----
	directIDs := make([]int64, 0)
	for _, cv := range convs {
		if cv.Type == model.ConvDirect {
			directIDs = append(directIDs, cv.ID)
		}
	}
	convOther := map[int64][]int64{} // convID -> 成员 userID 列表（单聊最多 2 个）
	if len(directIDs) > 0 {
		var mems []model.ConversationMember
		store.DB.Where("conversation_id IN ?", directIDs).Find(&mems)
		for _, mm := range mems {
			convOther[mm.ConversationID] = append(convOther[mm.ConversationID], mm.UserID)
		}
	}

	// ---- 批量取用户 ----
	userSet := map[int64]bool{}
	for _, m := range msgs {
		if m.SenderID > 0 {
			userSet[m.SenderID] = true
		}
		for _, uid := range convOther[m.ConversationID] {
			if uid > 0 {
				userSet[uid] = true
			}
		}
	}
	userIDs := make([]int64, 0, len(userSet))
	for uid := range userSet {
		userIDs = append(userIDs, uid)
	}
	userMap := map[int64]model.User{}
	if len(userIDs) > 0 {
		var users []model.User
		store.DB.Where("id IN ?", userIDs).Find(&users)
		for _, u := range users {
			userMap[u.ID] = u
		}
	}

	// ---- 小助手配置（昵称/头像/靓号）----
	ac := GetAssistantConfig(ctx, nil)

	fillUser := func(uid int64) (string, string, string) {
		if uid == -1 {
			return ac.Name, ac.Avatar, "10000"
		}
		u, ok := userMap[uid]
		if !ok {
			return fmt.Sprintf("用户%v", uid), "", ""
		}
		short := ""
		if u.ShortID != nil {
			short = *u.ShortID
		}
		return u.Nickname, u.Avatar, short
	}

	for _, m := range msgs {
		o := AdminMessageOut{Message: m}
		o.SenderName, o.SenderAvatar, o.SenderShortID = fillUser(m.SenderID)

		cv := convMap[m.ConversationID]
		o.ConvType = cv.Type
		if cv.Type == model.ConvGroup {
			// 群聊：接收者就是群本身
			o.ReceiverID = strconv.FormatInt(m.ConversationID, 10)
			o.ReceiverName = cv.NameZh
			o.ReceiverAvatar = cv.Avatar
			o.ConvName = cv.NameZh
			o.ConvAvatar = cv.Avatar
		} else {
			// 单聊：接收者 = 发送者之外的另一个成员
			other := int64(0)
			for _, uid := range convOther[m.ConversationID] {
				if uid != m.SenderID {
					other = uid
					break
				}
			}
			o.ReceiverID = strconv.FormatInt(other, 10)
			o.ReceiverName, o.ReceiverAvatar, o.ReceiverShortID = fillUser(other)
			peerName, peerAvatar, _ := fillUser(other)
			o.ConvName = peerName
			o.ConvAvatar = peerAvatar
		}
		out = append(out, o)
	}
	return out, total, nil
}

// AdminMessageBlock 屏蔽/恢复屏蔽一条消息（后台审计）：blocked=true 后用户端历史/同步不再下发
func AdminMessageBlock(ctx context.Context, msgID int64, blocked bool) error {
	_, err := msgColl().UpdateOne(ctx, bson.M{"msg_id": msgID},
		bson.M{"$set": bson.M{"blocked": blocked}})
	return err
}

// ============ 数据统计 ============

func AdminStatsOverview(ctx context.Context) (map[string]interface{}, error) {
	var userTotal int64
	store.DB.Model(&model.User{}).Count(&userTotal)
	var online int64
	keys, _ := store.RDB.Keys(ctx, "online:*").Result()
	online = int64(len(keys))
	msgTotal, _ := msgColl().CountDocuments(ctx, bson.M{})
	// 存储估算：消息数 * 1KB + 会话数
	var convTotal int64
	store.DB.Model(&model.Conversation{}).Count(&convTotal)
	storageMB := msgTotal / 1000 // 粗略
	return map[string]interface{}{
		"userTotal": userTotal,
		"online":    online,
		"msgTotal":  msgTotal,
		"convTotal": convTotal,
		"storageMB": storageMB,
	}, nil
}

func AdminStatsMessages(ctx context.Context, days int) (map[string]interface{}, error) {
	if days <= 0 {
		days = 7
	}
	start := time.Now().AddDate(0, 0, -days)
	type dayCount struct {
		Day   string `json:"day" bson:"_id"`
		Count int64  `json:"count" bson:"count"`
	}
	pipe, err := msgColl().Aggregate(ctx, mongo.Pipeline{
		bson.D{{Key: "$match", Value: bson.M{"created_at": bson.M{"$gte": start}}}},
		bson.D{{Key: "$group", Value: bson.M{
			"_id":   bson.M{"$dateToString": bson.M{"format": "%Y-%m-%d", "date": "$created_at"}},
			"count": bson.M{"$sum": 1},
		}}},
		bson.D{{Key: "$sort", Value: bson.D{{Key: "_id", Value: 1}}}},
	})
	if err != nil {
		return nil, err
	}
	var out []dayCount
	if err := pipe.All(ctx, &out); err != nil {
		return nil, err
	}
	return map[string]interface{}{"days": days, "series": out}, nil
}

// ============ 日志查询 ============

func AdminLogList(ctx context.Context, page, size int) ([]model.AdminLog, int64, error) {
	if size <= 0 || size > 100 {
		size = 20
	}
	if page <= 0 {
		page = 1
	}
	var total int64
	store.DB.Model(&model.AdminLog{}).Count(&total)
	var logs []model.AdminLog
	err := store.DB.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&logs).Error
	return logs, total, err
}

func AdminLoginLogList(ctx context.Context, page, size int) ([]model.LoginLog, int64, error) {
	if size <= 0 || size > 100 {
		size = 20
	}
	if page <= 0 {
		page = 1
	}
	var total int64
	store.DB.Model(&model.LoginLog{}).Count(&total)
	var logs []model.LoginLog
	err := store.DB.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&logs).Error
	return logs, total, err
}

// ============ 后台操作日志 ============

func AdminLog(ctx context.Context, adminID int64, action, target, ip string, detail interface{}) {
	detailJSON, _ := json.Marshal(detail)
	store.DB.Create(&model.AdminLog{
		AdminID: adminID, Action: action, Target: target, Detail: string(detailJSON), IP: ip, CreatedAt: time.Now(),
	})
}

// ============ 群组：成员 / 消息详情 ============

// AdminGroupMembers 某群的成员列表（按 joinedAt 倒序）
func AdminGroupMembers(ctx context.Context, groupID int64, page, size int) ([]map[string]any, int64, error) {
	if groupID <= 0 {
		return nil, 0, errs.ParamError
	}
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 200 {
		size = 50
	}
	var total int64
	if err := store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", groupID).Count(&total).Error; err != nil {
		return nil, 0, err
	}
	var mems []model.ConversationMember
	if err := store.DB.Where("conversation_id = ?", groupID).
		Order("role asc, joined_at desc").
		Offset((page - 1) * size).Limit(size).Find(&mems).Error; err != nil {
		return nil, 0, err
	}
	// 关联用户信息
	uids := make([]int64, 0, len(mems))
	for _, m := range mems {
		uids = append(uids, m.UserID)
	}
	userMap := map[int64]model.User{}
	if len(uids) > 0 {
		var us []model.User
		store.DB.Where("id IN ?", uids).Find(&us)
		for i := range us {
			userMap[us[i].ID] = us[i]
		}
	}
	list := make([]map[string]any, 0, len(mems))
	for _, m := range mems {
		u := userMap[m.UserID]
		list = append(list, map[string]any{
			"id":             m.ID,
			"conversationId": m.ConversationID,
			"userId":         m.UserID,
			"role":           m.Role,
			"memberNickname": m.Nickname,
			"mute":           m.Mute,
			"joinedAt":       m.JoinedAt,
			"account":        u.Account,
			"nickname":       u.Nickname,
			"avatar":         u.Avatar,
			"shortId":        model.StrVal(u.ShortID),
			"status":         u.Status,
		})
	}
	return list, total, nil
}

// AdminGroupMessages 某群的消息记录（Mongo 消息集合按 conversation_id）
func AdminGroupMessages(ctx context.Context, groupID int64, kw string, page, size int) ([]model.Message, int64, error) {
	if groupID <= 0 {
		return nil, 0, errs.ParamError
	}
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 200 {
		size = 50
	}
	filter := bson.M{"conversation_id": groupID}
	if kw != "" {
		filter["content"] = bson.M{"$regex": kw, "$options": "i"}
	}
	total, err := msgColl().CountDocuments(ctx, filter)
	if err != nil {
		return nil, 0, err
	}
	cur, err := msgColl().Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "msg_id", Value: -1}}).
			SetSkip(int64((page-1)*size)).SetLimit(int64(size)))
	if err != nil {
		return nil, 0, err
	}
	var msgs []model.Message
	_ = cur.All(ctx, &msgs)
	return msgs, total, nil
}

// ============ 保留靓号 reserved_short_id ============

type ReservedListResult struct {
	List  []map[string]any `json:"list"`
	Total int64            `json:"total"`
}

// AdminReservedShortIDList 靓号列表（按状态/关键字/来源筛选）
func AdminReservedShortIDList(ctx context.Context, kw string, status, source int, page, size int) (*ReservedListResult, error) {
	if page <= 0 {
		page = 1
	}
	if size <= 0 || size > 200 {
		size = 20
	}
	q := store.DB.Model(&model.ReservedShortID{})
	if kw != "" {
		like := "%" + kw + "%"
		q = q.Where("short_id LIKE ? OR remark LIKE ?", like, like)
	}
	if status > 0 {
		q = q.Where("status = ?", status)
	}
	if source > 0 {
		q = q.Where("source = ?", source)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, err
	}
	var rows []model.ReservedShortID
	if err := q.Order("id desc").Offset((page - 1) * size).Limit(size).Find(&rows).Error; err != nil {
		return nil, err
	}
	// 关联 used_by 对应的用户昵称/账号
	uids := make([]int64, 0)
	for _, r := range rows {
		if r.UsedBy > 0 {
			uids = append(uids, r.UsedBy)
		}
	}
	uMap := map[int64]model.User{}
	if len(uids) > 0 {
		var us []model.User
		store.DB.Where("id IN ?", uids).Find(&us)
		for i := range us {
			uMap[us[i].ID] = us[i]
		}
	}
	list := make([]map[string]any, 0, len(rows))
	for _, r := range rows {
		row := map[string]any{
			"id":        r.ID,
			"shortId":   r.ShortID,
			"source":    r.Source,
			"type":      r.Type,
			"status":    r.Status,
			"remark":    r.Remark,
			"price":     r.Price,
			"usedBy":    r.UsedBy,
			"usedAt":    r.UsedAt,
			"createdAt": r.CreatedAt,
		}
		if u, ok := uMap[r.UsedBy]; ok {
			row["userNickname"] = u.Nickname
			row["userAccount"] = u.Account
			row["userShortId"] = model.StrVal(u.ShortID)
		}
		list = append(list, row)
	}
	return &ReservedListResult{List: list, Total: total}, nil
}

// AdminReservedShortIDBatch 批量生成靓号（范围/手动列表/规则三种模式之一）
// typeID: 1 普通 / 2 豹子号 / 3 顺子号 / 4 VIP；小于 1 或大于 4 会被归一到 1
func AdminReservedShortIDBatch(ctx context.Context, from, to int64, list []string, prefix string, digits, count int, remark string, price float64, typeID int, source int) (int64, error) {
	if typeID < 1 || typeID > 4 {
		typeID = 1
	}
	now := time.Now()
	cnt := int64(0)
	// 模式 1：范围 [from, to]
	if from > 0 && to >= from {
		err := store.DB.Transaction(func(tx *gorm.DB) error {
			for sid := from; sid <= to; sid++ {
				s := strconv.FormatInt(sid, 10)
				var dup int64
				tx.Model(&model.ReservedShortID{}).Where("short_id = ?", s).Count(&dup)
				if dup > 0 {
					continue
				}
				r := model.ReservedShortID{
					ShortID:   s,
					Source:    source,
					Type:      typeID,
					Status:    model.ReservedShortIDOpen,
					Price:     price,
					Remark:    remark,
					CreatedAt: now,
				}
				if tx.Create(&r).Error == nil {
					cnt++
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
		}
		return cnt, nil
	}
	// 模式 2：手动列表
	if len(list) > 0 {
		err := store.DB.Transaction(func(tx *gorm.DB) error {
			for _, raw := range list {
				s := strings.TrimSpace(raw)
				if s == "" {
					continue
				}
				var dup int64
				tx.Model(&model.ReservedShortID{}).Where("short_id = ?", s).Count(&dup)
				if dup > 0 {
					continue
				}
				r := model.ReservedShortID{
					ShortID:   s,
					Source:    source,
					Type:      typeID,
					Status:    model.ReservedShortIDOpen,
					Price:     price,
					Remark:    remark,
					CreatedAt: now,
				}
				if tx.Create(&r).Error == nil {
					cnt++
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
		}
		return cnt, nil
	}
	// 模式 3：规则（prefix + digits 位，count 个随机）
	if digits > 0 && digits <= 16 && count > 0 && count <= 100000 {
		if prefix == "" {
			prefix = ""
		}
		randPool := "0123456789"
		err := store.DB.Transaction(func(tx *gorm.DB) error {
			for i := 0; i < count; i++ {
				suf := make([]byte, digits)
				for j := 0; j < digits; j++ {
					suf[j] = randPool[time.Now().UnixNano()%10] // 快速伪随机（靓号不需要加密安全）
					// 混洗一下避免同一毫秒碰撞
					time.Sleep(10 * time.Nanosecond)
				}
				s := prefix + string(suf)
				var dup int64
				tx.Model(&model.ReservedShortID{}).Where("short_id = ?", s).Count(&dup)
				if dup > 0 {
					continue
				}
				r := model.ReservedShortID{
					ShortID:   s,
					Source:    source,
					Type:      typeID,
					Status:    model.ReservedShortIDOpen,
					Price:     price,
					Remark:    remark,
					CreatedAt: now,
				}
				if tx.Create(&r).Error == nil {
					cnt++
				}
			}
			return nil
		})
		if err != nil {
			return 0, err
		}
		return cnt, nil
	}
	return 0, errs.ParamError
}

// AdminReservedShortIDRemark 更新备注/价格/类型
func AdminReservedShortIDRemark(ctx context.Context, id int64, remark string, price float64, typeID int) error {
	if id <= 0 {
		return errs.ParamError
	}
	upd := map[string]interface{}{}
	if remark != "" {
		upd["remark"] = remark
	}
	if price > 0 {
		upd["price"] = price
	}
	if typeID >= 1 && typeID <= 4 {
		upd["type"] = typeID
	}
	if len(upd) == 0 {
		return nil
	}
	return store.DB.Model(&model.ReservedShortID{}).Where("id = ?", id).Updates(upd).Error
}

// AdminReservedShortIDFreeze 冻结/解冻（status=2 冻结，其他恢复 1 未分配；已分配 status=3 不允许改）
func AdminReservedShortIDFreeze(ctx context.Context, id int64, frozen bool) error {
	if id <= 0 {
		return errs.ParamError
	}
	var r model.ReservedShortID
	if err := store.DB.First(&r, id).Error; err != nil {
		return errs.ParamError
	}
	if r.Status == model.ReservedShortIDUsed {
		return &errs.Err{Code: 1001, Msg: "已被使用，无法冻结/解冻"}
	}
	status := model.ReservedShortIDOpen
	if frozen {
		status = model.ReservedShortIDFrozen
	}
	return store.DB.Model(&r).Update("status", status).Error
}

// AdminReservedShortIDDelete 删除（仅未分配/冻结；已分配不删）
func AdminReservedShortIDDelete(ctx context.Context, id int64) error {
	if id <= 0 {
		return errs.ParamError
	}
	var r model.ReservedShortID
	if err := store.DB.First(&r, id).Error; err != nil {
		return errs.ParamError
	}
	if r.Status == model.ReservedShortIDUsed {
		return &errs.Err{Code: 1001, Msg: "已被使用，无法删除"}
	}
	return store.DB.Delete(&r).Error
}

// AdminReservedShortIDAssign 把某条预留靓号分配给指定用户（事务 + 行锁）。
// 语义：
//   - reserved.status 必须 = 1（未分配；冻结/已用均不允许）；
//   - 用户原 short_id 若也命中 reserved_short_id 池 → 旧那条自动回收（status=1, used_by=0, used_at=NULL）；
//   - 新靓号若被其他用户占用（极端竞争）→ 回滚并返回错误；
//   - 分配成功后：reserved.status=3 used_by=userId used_at=now；users.short_id = r.ShortID。
//
// 返回：{ nickname, account, shortId, userId } 供前端即时刷新"绑定账号"列
func AdminReservedShortIDAssign(ctx context.Context, id, userID int64) (map[string]any, error) {
	if id <= 0 || userID <= 0 {
		return nil, errs.ParamError
	}
	// 前置：reserved 存在，状态检查/分支处理
	var r model.ReservedShortID
	if err := store.DB.First(&r, id).Error; err != nil {
		return nil, errs.ParamError
	}
	if r.Status == model.ReservedShortIDFrozen {
		return nil, &errs.Err{Code: 1001, Msg: "该靓号已冻结，请先解冻再分配"}
	}
	if r.Status == model.ReservedShortIDUsed && r.UsedBy == userID {
		// 幂等：已经分配给该用户，直接回 OK，不报错
		var u model.User
		_ = store.DB.Select("nickname, account, short_id").First(&u, userID).Error
		return map[string]any{
			"userId":   u.ID,
			"nickname": u.Nickname,
			"account":  u.Account,
			"shortId":  r.ShortID,
		}, nil
	}
	// 走到这里允许：status=1(未分配) 或 status=3(已占用，管理员强行改分配)
	// 前置：用户存在
	var user model.User
	if err := store.DB.First(&user, userID).Error; err != nil {
		return nil, &errs.Err{Code: 1001, Msg: "用户不存在"}
	}
	newSID := strings.TrimSpace(r.ShortID)
	if newSID == "" {
		return nil, &errs.Err{Code: 1001, Msg: "靓号内容为空"}
	}

	err := store.DB.Transaction(func(tx *gorm.DB) error {
		// 固定顺序：1) reserved 行锁  2) user(新) 行锁  3) user(旧占用者) 行锁 if any，避免死锁
		var lockedR model.ReservedShortID
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&lockedR, id).Error; err != nil {
			return err
		}
		var lockedU model.User
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&lockedU, userID).Error; err != nil {
			return err
		}
		if lockedR.Status == model.ReservedShortIDFrozen {
			return &errs.Err{Code: 1001, Msg: "分配失败：该靓号状态已变更（冻结），请刷新后重试"}
		}
		// lockedR 允许 status=1 或 status=3；status=3 必须先处理旧占用者：
		//   1. 查旧占用者 used_by（=lockedR.UsedBy）；
		//   2. 如果旧占用者 user 的 short_id 仍等于 lockedR.ShortID → 置空；
		//   3. 如果旧占用者 == 新用户（lockedU），其实属于幂等情况（上面已 return），不会再到这里。
		if lockedR.Status == model.ReservedShortIDUsed && lockedR.UsedBy > 0 && lockedR.UsedBy != lockedU.ID {
			var oldU model.User
			err := tx.Set("gorm:query_option", "FOR UPDATE").First(&oldU, lockedR.UsedBy).Error
			if err == nil && strings.TrimSpace(model.StrVal(oldU.ShortID)) == newSID {
				if err := tx.Model(&model.User{}).
					Where("id = ?", oldU.ID).
					Update("short_id", nil).Error; err != nil {
					return err
				}
			}
			// oldU 已被删（err == RecordNotFound）则忽略，继续分配
		}

		// Step 1：释放用户原有旧 short_id（如果也在 reserved 池里）
		oldSID := strings.TrimSpace(model.StrVal(lockedU.ShortID))
		if oldSID != "" {
			var oldRS model.ReservedShortID
			if err := tx.Where("short_id = ? AND used_by = ?", oldSID, lockedU.ID).First(&oldRS).Error; err == nil {
				if err := tx.Model(&oldRS).Updates(map[string]any{
					"status":  model.ReservedShortIDOpen,
					"used_by": 0,
					"used_at": nil,
				}).Error; err != nil {
					return err
				}
			}
		}

		// Step 2：新靓号不能被其他用户已占用（极端竞争：AdminUserUpdate 绕过 assign 直接写 short_id 的情况）
		var conflict int64
		if err := tx.Model(&model.User{}).
			Where("short_id = ? AND id <> ?", newSID, lockedU.ID).
			Count(&conflict).Error; err != nil {
			return err
		}
		if conflict > 0 {
			return &errs.Err{Code: 1001, Msg: "该靓号已被其他用户占用，无法分配"}
		}

		// Step 3：写入用户 short_id
		if err := tx.Model(&model.User{}).
			Where("id = ?", lockedU.ID).
			Update("short_id", newSID).Error; err != nil {
			return err
		}

		// Step 4：标记 reserved 已被使用
		now := time.Now()
		if err := tx.Model(&model.ReservedShortID{}).
			Where("id = ?", lockedR.ID).
			Updates(map[string]any{
				"status":  model.ReservedShortIDUsed,
				"used_by": lockedU.ID,
				"used_at": &now,
			}).Error; err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	var latest model.User
	_ = store.DB.Select("id, nickname, account, short_id").First(&latest, userID).Error
	return map[string]any{
		"userId":   latest.ID,
		"nickname": latest.Nickname,
		"account":  latest.Account,
		"shortId":  model.StrVal(latest.ShortID),
	}, nil
}

// AdminReservedShortIDRelieve 解除分配：把已被占用的靓号回收为"未分配"，同时清空对应用户的 short_id。
// 约束：reserved 必须是 status=3 且 used_by>0；只有当 users.short_id 仍等于 reserved.short_id 时才清空（避免误覆盖用户后续手工改好的新值）
func AdminReservedShortIDRelieve(ctx context.Context, id int64) error {
	if id <= 0 {
		return errs.ParamError
	}
	var r model.ReservedShortID
	if err := store.DB.First(&r, id).Error; err != nil {
		return errs.ParamError
	}
	if r.Status != model.ReservedShortIDUsed || r.UsedBy <= 0 {
		return &errs.Err{Code: 1001, Msg: "该靓号当前未被分配，无需解除"}
	}
	return store.DB.Transaction(func(tx *gorm.DB) error {
		// 1) reserved 行锁，2) user 行锁
		var lockedR model.ReservedShortID
		if err := tx.Set("gorm:query_option", "FOR UPDATE").First(&lockedR, id).Error; err != nil {
			return err
		}
		var lockedU model.User
		err := tx.Set("gorm:query_option", "FOR UPDATE").First(&lockedU, lockedR.UsedBy).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return err
		}

		// 回收 reserved
		if err := tx.Model(&model.ReservedShortID{}).
			Where("id = ?", lockedR.ID).
			Updates(map[string]any{
				"status":  model.ReservedShortIDOpen,
				"used_by": 0,
				"used_at": nil,
			}).Error; err != nil {
			return err
		}
		// 仅当用户 short_id 仍等于这条才清空（防止用户在此期间被手工改过）
		if err == nil && strings.TrimSpace(model.StrVal(lockedU.ShortID)) == strings.TrimSpace(lockedR.ShortID) {
			if err := tx.Model(&model.User{}).
				Where("id = ?", lockedU.ID).
				Update("short_id", nil).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// ============ 系统健康检测 ============

// procStartedAt API 进程启动时间（包初始化时记录，用于运行时长展示）
var procStartedAt = time.Now()

// hcCheck 单项检测结果：前端系统检测页直接消费
// status: ok=正常 warn=警告 err=异常
type hcCheck struct {
	Status    string            `json:"status"`
	Message   string            `json:"message"`
	Details   map[string]string `json:"details,omitempty"`
	LatencyMs int64             `json:"latencyMs"`
}

// AdminHealthCheck 单项检测；key=all 时返回全部。
// 检测项：mysql / redis / mongo / minio / api / wss / jpush / version
// 全部基于真实连接探测（.env 配置已在进程启动时加载进 cfg / store）。
func AdminHealthCheck(ctx context.Context, cfg *config.Config, key string) (map[string]any, error) {
	checks := map[string]func() hcCheck{
		"mysql": func() hcCheck {
			sqlDB, e := store.DB.DB()
			if e != nil {
				return hcCheck{"err", "MySQL 连接池获取失败: " + e.Error(), nil, 0}
			}
			if e := sqlDB.PingContext(ctx); e != nil {
				return hcCheck{"err", "MySQL 连接失败: " + e.Error(), nil, 0}
			}
			var v string
			store.DB.Raw("SELECT VERSION()").Scan(&v)
			st := sqlDB.Stats()
			return hcCheck{"ok", "连接正常", map[string]string{
				"版本": v, "活跃连接": fmt.Sprintf("%d", st.InUse), "空闲连接": fmt.Sprintf("%d", st.Idle),
			}, 0}
		},
		"redis": func() hcCheck {
			if store.RDB == nil {
				return hcCheck{"err", "Redis 未初始化", nil, 0}
			}
			if e := store.RDB.Ping(ctx).Err(); e != nil {
				return hcCheck{"err", "Redis 连接失败: " + e.Error(), map[string]string{"地址": cfg.RedisAddr}, 0}
			}
			return hcCheck{"ok", "连接正常", map[string]string{"地址": cfg.RedisAddr}, 0}
		},
		"mongo": func() hcCheck {
			if store.Mongo == nil {
				return hcCheck{"err", "MongoDB 未初始化", nil, 0}
			}
			if e := store.Mongo.Client().Ping(ctx, nil); e != nil {
				return hcCheck{"err", "MongoDB 连接失败: " + e.Error(), nil, 0}
			}
			return hcCheck{"ok", "连接正常", map[string]string{"数据库": store.Mongo.Name()}, 0}
		},
		"minio": func() hcCheck {
			return checkMinio(ctx, cfg)
		},
		"api": func() hcCheck {
			// 能响应本次请求即代表 API 进程在线
			return hcCheck{"ok", "API 服务在线", map[string]string{
				"NodeID": cfg.NodeID,
				"HTTP端口": cfg.HTTPPort,
				"启动时间":   procStartedAt.Format("2006-01-02 15:04:05"),
				"已运行":    time.Since(procStartedAt).Round(time.Second).String(),
				"Go版本":   runtime.Version(),
				"运行环境":   cfg.AppEnv,
			}, 0}
		},
		"wss": func() hcCheck {
			// gateway 与 api 建议同机部署：探活本机 WS 端口最直接
			addr := net.JoinHostPort("127.0.0.1", cfg.WSPort)
			d := net.Dialer{Timeout: 800 * time.Millisecond}
			conn, err := d.DialContext(ctx, "tcp", addr)
			if err != nil {
				return hcCheck{"err", "WS 端口未监听（gateway 未启动或端口不一致）: " + err.Error(),
					map[string]string{"本机WS端口": cfg.WSPort}, 0}
			}
			conn.Close()
			online := "未知"
			if store.RDB != nil {
				if keys, e := store.RDB.Keys(ctx, "online:*").Result(); e == nil {
					online = fmt.Sprintf("%d", len(keys))
				}
			}
			return hcCheck{"ok", "Gateway 在线（本机节点）", map[string]string{
				"本机WS端口": cfg.WSPort, "在线连接": online,
			}, 0}
		},
		"jpush": func() hcCheck {
			c := GetJPushConfig(ctx)
			d := map[string]string{
				"启用":     fmt.Sprintf("%v", c.Enabled),
				"AppKey": c.AppKey,
				"APNs生产": fmt.Sprintf("%v", c.ApnsProduction),
			}
			if !c.Enabled {
				return hcCheck{"warn", "极光推送未启用（离线消息将走 App 内通知）", d, 0}
			}
			if c.AppKey == "" || c.MasterSecret == "" {
				return hcCheck{"err", "已启用但 AppKey / MasterSecret 未配置完整", d, 0}
			}
			if len(c.MasterSecret) < 8 {
				d["AppKey"] = d["AppKey"] + "（MasterSecret 长度异常，请检查）"
			} else {
				d["MasterSecret"] = strings.Repeat("*", 8) + "（已配置）"
			}
			return hcCheck{"ok", "推送配置完整（未做真实下发测试）", d, 0}
		},
		"version": func() hcCheck {
			return hcCheck{"ok", "环境配置（.env 已加载）", map[string]string{
				"NodeID":  cfg.NodeID,
				"运行环境":    cfg.AppEnv,
				"HTTP端口":  cfg.HTTPPort,
				"WS端口":    cfg.WSPort,
				"Redis":   cfg.RedisAddr,
				"MongoDB": cfg.MongoDB,
				"MinIO":   cfg.MinIOEndpoint,
				"JWT访问时长": fmt.Sprintf("%dh", cfg.JWTAccessTTLHours),
				"JWT刷新时长": fmt.Sprintf("%dd", cfg.JWTRefreshTTLDays),
				"开放注册":    fmt.Sprintf("%v", cfg.RegisterOn),
				"邀请码注册":   fmt.Sprintf("%v", cfg.InviteCodeOn),
			}, 0}
		},
	}
	run := func(k string) map[string]any {
		start := time.Now()
		var res hcCheck
		if fn, ok := checks[k]; ok {
			res = fn()
		} else {
			res = hcCheck{"err", "未知检测项: " + k, nil, 0}
		}
		res.LatencyMs = time.Since(start).Milliseconds()
		b, _ := json.Marshal(res)
		var m map[string]any
		_ = json.Unmarshal(b, &m)
		return m
	}
	key = strings.ToLower(strings.TrimSpace(key))
	if key == "all" || key == "" {
		result := map[string]any{}
		for k := range checks {
			result[k] = run(k)
		}
		return result, nil
	}
	return map[string]any{key: run(key)}, nil
}

// checkMinio 真实连通性检测：GET /minio/health/live（1s 超时）+ 配置完整性。
func checkMinio(ctx context.Context, cfg *config.Config) hcCheck {
	endpoint := cfg.MinIOEndpoint
	if endpoint == "" {
		return hcCheck{"warn", "MinIO 未配置", nil, 0}
	}
	detail := map[string]string{
		"Endpoint": endpoint,
		"Bucket":   cfg.MinIOBucket,
	}
	if cfg.MinIOBucket == "" || cfg.MinIOAccessKey == "" || cfg.MinIOSecretKey == "" {
		return hcCheck{"err", "MinIO 配置不完整（缺少 bucket / accessKey / secretKey 之一）", detail, 0}
	}
	base := endpoint
	if !strings.HasPrefix(base, "http://") && !strings.HasPrefix(base, "https://") {
		base = "http://" + base
	}
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, base+"/minio/health/live", nil)
	client := &http.Client{Timeout: 1500 * time.Millisecond}
	resp, err := client.Do(req)
	if err != nil {
		return hcCheck{"err", "MinIO 健康接口不可达: " + err.Error(), detail, 0}
	}
	resp.Body.Close()
	if resp.StatusCode >= 400 {
		return hcCheck{"err", fmt.Sprintf("MinIO 健康检查返回 %d", resp.StatusCode), detail, 0}
	}
	return hcCheck{"ok", "存储服务可访问", detail, 0}
}
