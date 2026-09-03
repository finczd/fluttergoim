package model

import "time"

const (
	ConvDirect = 1
	ConvGroup  = 2

	ConvNormal  = 1
	ConvDisband = 2

	MemberOwner  = 1
	MemberAdmin  = 2
	MemberNormal = 3
)

// Conversation 会话（单聊也建一条，member 2 人，统一会话列表）
type Conversation struct {
	ID               int64     `gorm:"primaryKey" json:"id,string"`
	Type             int       `gorm:"default:1" json:"type"`
	NameZh           string    `gorm:"size:64" json:"nameZh"`
	NameEn           string    `gorm:"size:64" json:"nameEn"`
	Avatar           string    `gorm:"size:512" json:"avatar"`
	OwnerID          int64     `gorm:"index" json:"ownerId,string"`
	AnnouncementZh   string    `gorm:"type:text" json:"announcementZh"`
	AnnouncementEn   string    `gorm:"type:text" json:"announcementEn"`
	MaxMembers       int       `gorm:"default:500" json:"maxMembers"`
	Status           int       `gorm:"default:1" json:"status"`
	PinnedMsgID      int64     `gorm:"default:0" json:"pinnedMsgId,string"`
	PinnedMsgContent string    `gorm:"size:512" json:"pinnedMsgContent"`
	PinnedMsgIDs     string    `gorm:"type:text" json:"pinnedMsgIds"` // 多条置顶：JSON 数组 ["id1","id2"]（兼容旧单条字段）
	MuteAll          int       `gorm:"default:0" json:"muteAll"`           // 全员禁言：1=开启（仅群主/管理员可发言）
	PrivacyEnabled   int       `gorm:"default:0" json:"privacyEnabled"`    // 成员隐私：1=开启（普通成员不可查看成员列表）
	AllowMemberInvite int      `gorm:"default:1" json:"allowMemberInvite"` // 允许群成员邀请成员：1=允许
	QrJoinEnabled    int       `gorm:"default:1" json:"qrJoinEnabled"`     // 二维码进群：1=开启
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`

	// 非持久化展示字段：单聊接口（CreateDirect）实时填充对方最近上线时间，不落库
	LastLoginAt *time.Time `gorm:"-" json:"lastLoginAt,omitempty"`
}

func (Conversation) TableName() string { return "conversation" }

// ConversationMember 会话成员
type ConversationMember struct {
	ID             int64     `gorm:"primaryKey" json:"id,string"`
	ConversationID int64     `gorm:"index:uk_conv_user,unique" json:"conversationId,string"`
	UserID         int64     `gorm:"index:uk_conv_user,unique;index:idx_user" json:"userId,string"`
	Role           int       `gorm:"default:3" json:"role"`
	Nickname       string    `gorm:"size:64" json:"nickname"`
	Mute           int       `gorm:"default:0" json:"mute"`
	// 禁言（发言）：群主/管理员对成员设置，unix 秒时间戳，0=未禁言。
	// 与 Mute（免打扰，个人开关）互不相干。
	SpeakMutedUntil int64     `gorm:"default:0" json:"speakMutedUntil"`
	Pinned          int       `gorm:"default:0" json:"pinned"`
	LastReadMsgID   int64     `gorm:"default:0" json:"lastReadMsgId,string"`
	JoinedAt        time.Time `json:"joinedAt"`
}

func (ConversationMember) TableName() string { return "conversation_member" }
