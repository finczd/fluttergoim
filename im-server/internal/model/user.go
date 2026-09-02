package model

import "time"

// StrPtr 返回 s 的指针（构造 *string 用）
func StrPtr(s string) *string { return &s }

// StrVal 返回 *string 的值；nil 返回空串
func StrVal(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}

const (
	RoleUser  = 1
	RoleAdmin = 2
	RoleKefu  = 3 // 客服（后台可把普通用户设为客服；新注册可自动添加客服）

	StatusNormal   = 1
	StatusDisabled = 2
)

// User 用户表
type User struct {
	ID           int64      `gorm:"primaryKey" json:"id,string"`
	Account      string     `gorm:"size:64;uniqueIndex" json:"account"`
	PasswordHash string     `gorm:"size:255" json:"-"`
	Nickname     string     `gorm:"size:64" json:"nickname"`
	Avatar       string     `gorm:"size:512" json:"avatar"`
	Signature    string     `gorm:"size:200" json:"signature"` // 个人签名（AutoMigrate 自动加列）
	Phone        string     `gorm:"size:32" json:"phone"`
	Email        string     `gorm:"size:128" json:"email"`
	CountryCode  string     `gorm:"size:8" json:"countryCode"`
	ShortID      *string    `gorm:"size:32;uniqueIndex" json:"shortId"`          // 靓号/用户ID（可通过 ID 加好友，后台可预留）；nil 表示未分配，数据库写 NULL 不会触发 UNIQUE 冲突
	Balance      float64    `gorm:"type:decimal(12,2);default:0" json:"balance"` // 零钱余额（可自由使用）
	Frozen       float64    `gorm:"type:decimal(12,2);default:0" json:"frozen"`  // 冻结金额（发出的红包/转账尚未被领取的部分）
	DepartmentID int64      `gorm:"index" json:"departmentId,string"`
	Status       int        `gorm:"default:1" json:"status"`
	Role         int        `gorm:"default:1" json:"role"`
	LastLoginAt  *time.Time `json:"lastLoginAt"`
	CreatedAt    time.Time  `json:"createdAt"`
	UpdatedAt    time.Time  `json:"updatedAt"`
}

func (User) TableName() string { return "user" }

// Department 部门（双语字段，i18n）
type Department struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	NameZh    string    `gorm:"size:64" json:"nameZh"`
	NameEn    string    `gorm:"size:64" json:"nameEn"`
	ParentID  int64     `gorm:"index" json:"parentId,string"`
	Sort      int       `json:"sort"`
	CreatedAt time.Time `json:"createdAt"`
}

func (Department) TableName() string { return "department" }

// SysConfig 系统配置 KV
type SysConfig struct {
	ID          int64     `gorm:"primaryKey" json:"id,string"`
	ConfigKey   string    `gorm:"size:64;uniqueIndex" json:"key"`
	ConfigValue string    `gorm:"type:json" json:"value"`
	UpdatedAt   time.Time `json:"updatedAt"`
}

func (SysConfig) TableName() string { return "sys_config" }

// 保留靓号状态
const (
	ReservedShortIDOpen   = 1 // 未分配
	ReservedShortIDFrozen = 2 // 冻结（暂不出售/分配）
	ReservedShortIDUsed   = 3 // 已分配
)

// 保留靓号来源
const (
	ReservedSourceManual = 1 // 手动录入
	ReservedSourceRange  = 2 // 范围生成
	ReservedSourceRule   = 3 // 规则生成
)

// ReservedShortID 预留给后台分配的短ID池（管理员可批量生成/冻结/备注，分配时与 user.short_id 联动）
type ReservedShortID struct {
	ID        int64      `gorm:"primaryKey;autoIncrement" json:"id,string"`
	ShortID   string     `gorm:"size:32;uniqueIndex" json:"shortId"` // 预留 short_id（唯一）
	Source    int        `gorm:"index;default:1" json:"source"`      // 1 手动 / 2 范围 / 3 规则
	Type      int        `gorm:"index;default:1" json:"type"`        // 1 普通 / 2 豹子号 / 3 顺子号 / 4 VIP
	Status    int        `gorm:"index;default:1" json:"status"`      // 1 未分配 / 2 冻结 / 3 已用
	Remark    string     `gorm:"size:255" json:"remark"`             // 备注（价格说明/来源等）
	Price     float64    `gorm:"type:decimal(12,2);default:0" json:"price"`
	UsedBy    int64      `gorm:"index;default:0" json:"usedBy,string"` // 被哪个用户占用（0 = 未占用）
	UsedAt    *time.Time `json:"usedAt"`
	CreatedAt time.Time  `json:"createdAt"`
}

func (ReservedShortID) TableName() string { return "reserved_short_id" }
