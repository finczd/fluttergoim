package service

import (
	"context"
	"encoding/json"
	"regexp"
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
	AppName  string `json:"appName"`
	AppLogo  string `json:"appLogo"`
	BrandName string `json:"brandName"`
	BrandLogo string `json:"brandLogo"`
	// 公告（移动端消息页跑马灯，后台可配）
	Announcement string `json:"announcement"`
	// App 版本信息（后台可配，客户端关于页/更新检查）
	AppVersion    string `json:"appVersion"`
	UpdateLog     string `json:"updateLog"`
	AndroidURL    string `json:"androidUrl"`
	IOSURL        string `json:"iosUrl"`
	HotUpdateURL  string `json:"hotUpdateUrl"`
	// 在线状态：当前登录设备（web/ios/android/windows/macos）
	OnlineDevice string `json:"onlineDevice"`
}

func GetAuthFlags(ctx context.Context, cfg *config.Config) AuthFlags {
	return AuthFlags{
		AuthMode:      strVal(SysConfigGet(ctx, "auth_mode", cfg.AuthMode)),
		InviteCodeOn:  boolVal(SysConfigGet(ctx, "invite_code_enabled", cfg.InviteCodeOn)),
		RegisterOn:    boolVal(SysConfigGet(ctx, "register_enabled", cfg.RegisterOn)),
		E2EOn:         boolVal(SysConfigGet(ctx, "e2e_enabled", cfg.E2EOn)),
		AppName:       strVal(SysConfigGet(ctx, "app_name", "ChatPulse")),
		AppLogo:       strVal(SysConfigGet(ctx, "app_logo", "")),
		BrandName:     strVal(SysConfigGet(ctx, "brand_name", "ChatPulse")),
		BrandLogo:     strVal(SysConfigGet(ctx, "brand_logo", "")),
		Announcement:  strVal(SysConfigGet(ctx, "announcement", "欢迎使用 ChatPulse! 请注意账号安全，不要泄露验证码。")),
		AppVersion:    strVal(SysConfigGet(ctx, "app_version", "1.0.0")),
		UpdateLog:     strVal(SysConfigGet(ctx, "update_log", "")),
		AndroidURL:    strVal(SysConfigGet(ctx, "android_url", "")),
		IOSURL:        strVal(SysConfigGet(ctx, "ios_url", "")),
		HotUpdateURL:  strVal(SysConfigGet(ctx, "hot_update_url", "")),
		OnlineDevice:  strVal(SysConfigGet(ctx, "online_device", "")),
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
		q = q.Where("nickname LIKE ? OR account LIKE ? OR phone LIKE ? OR email LIKE ?", like, like, like, like)
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

func AdminUserSetStatus(ctx context.Context, id int64, status int) error {
	return store.DB.Model(&model.User{}).Where("id = ?", id).Update("status", status).Error
}

func AdminUserResetPassword(ctx context.Context, id int64, newPass string) error {
	hash, _ := bcrypt.GenerateFromPassword([]byte(newPass), bcrypt.DefaultCost)
	return store.DB.Model(&model.User{}).Where("id = ?", id).Update("password_hash", string(hash)).Error
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

func AdminGroupList(ctx context.Context) ([]model.Conversation, error) {
	var groups []model.Conversation
	err := store.DB.Where("type = ? AND status = ?", model.ConvGroup, model.ConvNormal).
		Order("id desc").Limit(200).Find(&groups).Error
	return groups, err
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
}

func AdminMessageQuery(ctx context.Context, q *AdminMsgQuery, page, size int) ([]model.Message, int64, error) {
	filter := bson.M{}
	if q.ConvID > 0 {
		filter["conversation_id"] = q.ConvID
	}
	if q.UserID > 0 {
		filter["sender_id"] = q.UserID
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
			SetSkip(int64((page - 1) * size)).SetLimit(int64(size)))
	if err != nil {
		return nil, 0, err
	}
	var msgs []model.Message
	cur.All(ctx, &msgs)
	return msgs, total, nil
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
		"userTotal":  userTotal,
		"online":     online,
		"msgTotal":   msgTotal,
		"convTotal":  convTotal,
		"storageMB":  storageMB,
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
