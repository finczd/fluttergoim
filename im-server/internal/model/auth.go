package model

import "time"

// Device 设备（多端登录 / 离线推送 token）
type Device struct {
	ID           int64     `gorm:"primaryKey" json:"id,string"`
	UserID       int64     `gorm:"index" json:"userId,string"`
	DeviceType   int       `gorm:"default:1" json:"deviceType"` // 1 Android / 2 iOS / 3 Web / 4 Windows / 5 macOS
	DeviceID     string    `gorm:"size:128" json:"deviceId"`
	PushToken    string    `gorm:"size:512" json:"-"`
	Status       int       `gorm:"default:1" json:"status"` // 1 在线 / 0 离线
	LastActiveAt time.Time `json:"lastActiveAt"`
	CreatedAt    time.Time `json:"createdAt"`
}

func (Device) TableName() string { return "device" }

// LoginLog 登录日志（后台可查）
type LoginLog struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	UserID    int64     `gorm:"index" json:"userId,string"`
	IP        string    `gorm:"size:64" json:"ip"`
	Device    string    `gorm:"size:255" json:"device"`
	Result    int       `gorm:"default:1" json:"result"` // 1 成功 / 0 失败
	CreatedAt time.Time `json:"createdAt"`
}

func (LoginLog) TableName() string { return "login_log" }

// InviteCode 邀请码（后台批量生成）
type InviteCode struct {
	ID        int64      `gorm:"primaryKey" json:"id,string"`
	Code      string     `gorm:"size:32;uniqueIndex" json:"code"`
	Batch     string     `gorm:"size:64" json:"batch"`
	UsedBy    *int64     `gorm:"index" json:"usedBy,string"`
	UsedAt    *time.Time `json:"usedAt"`
	ExpiresAt *time.Time `json:"expiresAt"`
	Enabled   int        `gorm:"default:1" json:"enabled"`
	CreatedAt time.Time  `json:"createdAt"`
}

func (InviteCode) TableName() string { return "invite_code" }

// InviteFriendCode 自定义邀请码（后台创建）：一个码可关联多个好友，
// 通过该码注册的用户会自动添加这些好友（双向好友关系，多用不限次数）
type InviteFriendCode struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	Code      string    `gorm:"size:32;uniqueIndex" json:"code"`
	FriendIDs string    `gorm:"type:json" json:"friendIds"` // JSON 数组字符串，如 ["123","456"]
	Remark    string    `gorm:"size:255" json:"remark"`     // 备注（这个码发给谁用）
	Enabled   int       `gorm:"default:1" json:"enabled"`   // 1 启用 / 0 停用
	UsedCount int       `gorm:"default:0" json:"usedCount"` // 使用次数（注册成功并绑定好友 +1）
	CreatedAt time.Time `json:"createdAt"`
}

func (InviteFriendCode) TableName() string { return "invite_friend_code" }

// AdminLog 后台操作日志
type AdminLog struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	AdminID   int64     `gorm:"index" json:"adminId,string"`
	Action    string    `gorm:"size:64" json:"action"`
	Target    string    `gorm:"size:255" json:"target"`
	Detail    string    `gorm:"type:json" json:"detail"`
	IP        string    `gorm:"size:64" json:"ip"`
	CreatedAt time.Time `json:"createdAt"`
}

func (AdminLog) TableName() string { return "admin_log" }

// UserKey E2E 用户密钥（阶段 1 预留表，V1.0 启用加密时使用）
type UserKey struct {
	ID                  int64     `gorm:"primaryKey" json:"id,string"`
	UserID              int64     `gorm:"uniqueIndex" json:"userId,string"`
	PublicKey           string    `gorm:"type:text" json:"-"`
	EncryptedPrivateKey string    `gorm:"type:text" json:"-"`
	KeyVersion          int       `gorm:"default:1" json:"keyVersion"`
	UpdatedAt           time.Time `json:"updatedAt"`
}

func (UserKey) TableName() string { return "user_keys" }
