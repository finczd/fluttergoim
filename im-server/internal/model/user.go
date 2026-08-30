package model

import "time"

const (
	RoleUser  = 1
	RoleAdmin = 2

	StatusNormal   = 1
	StatusDisabled = 2
)

// User 用户表
type User struct {
	ID           int64     `gorm:"primaryKey" json:"id,string"`
	Account      string    `gorm:"size:64;uniqueIndex" json:"account"`
	PasswordHash string    `gorm:"size:255" json:"-"`
	Nickname     string    `gorm:"size:64" json:"nickname"`
	Avatar       string    `gorm:"size:512" json:"avatar"`
	Phone        string    `gorm:"size:32" json:"phone"`
	Email        string    `gorm:"size:128" json:"email"`
	CountryCode  string    `gorm:"size:8" json:"countryCode"`
	ShortID      string    `gorm:"size:32;uniqueIndex" json:"shortId"` // 靓号/用户ID（可通过 ID 加好友，后台可预留）
	DepartmentID int64     `gorm:"index" json:"departmentId,string"`
	Status       int       `gorm:"default:1" json:"status"`
	Role         int       `gorm:"default:1" json:"role"`
	LastLoginAt  *time.Time `json:"lastLoginAt"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
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
