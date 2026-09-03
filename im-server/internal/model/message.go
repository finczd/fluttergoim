package model

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

// 消息类型
const (
	MsgText   = 1
	MsgImage  = 2
	MsgFile   = 3
	MsgVoice  = 4
	MsgVideo  = 5
	MsgSystem = 6
	MsgCall   = 7 // 音视频通话信令：content = JSON {"action":"invite|accept|reject|hangup","callType":"voice|video","roomId":xxx}
	// 8 红包 / 9 转账：content = JSON {"kind":"redpacket|transfer","amount":xx,"note":"","mode":"lucky|normal","count":n,"toUserId":""}
	// 发这类消息时**服务端必须原子扣款**（见 service.SendMoneyCharge），不能靠客户端事后记账
	MsgRedPacket = 8
	MsgTransfer  = 9
)

// 消息状态
const (
	MsgStatusNormal   = 1
	MsgStatusRecalled = 2
)

// Message MongoDB 消息
type Message struct {
	ID             primitive.ObjectID     `bson:"_id,omitempty" json:"-"`
	ConversationID int64                  `bson:"conversation_id" json:"conversationId,string"`
	MsgID          int64                  `bson:"msg_id" json:"msgId,string"`       // 全局雪花 ID
	ClientMsgID    string                 `bson:"client_msg_id" json:"clientMsgId"` // 客户端幂等 ID（UUID）
	Seq            int64                  `bson:"seq" json:"seq"`                   // 会话内单调递增序号（服务端生成，用于顺序/补拉）
	SenderID       int64                  `bson:"sender_id" json:"senderId,string"`
	Type           int                    `bson:"type" json:"type"`
	Content        string                 `bson:"content" json:"content"`
	File           map[string]interface{} `bson:"file,omitempty" json:"file,omitempty"`
	Mention        []int64                `bson:"mention,omitempty" json:"mention,omitempty"`
	ReplyTo        int64                  `bson:"reply_to,omitempty" json:"replyTo,string"`
	// 引用快照：被引用消息内容/发送者（发送时冗余，前端引用条直接显示原内容，不查库）
	ReplySnapshot map[string]interface{} `bson:"reply_snapshot,omitempty" json:"replySnapshot,omitempty"`
	Recalled      bool                   `bson:"recalled" json:"recalled"`
	RecalledBy    int64                  `bson:"recalled_by,omitempty" json:"recalledBy,string"`
	Status        int                    `bson:"status" json:"status"`
	// 派送状态（需求4：单聊对方 last_read_msg_id ≥ msg_id → "read"，否则 "sent"；非持久化字段，查询时填充）
	Delivery string `bson:"-" json:"deliveryState,omitempty"`
	// E2E：开启时 content 为密文（服务端可解密）
	Encrypted bool `bson:"encrypted" json:"encrypted"`
	// 屏蔽：后台消息审计中被管理员屏蔽的消息（历史拉取/增量同步不再下发）
	Blocked   bool      `bson:"blocked,omitempty" json:"blocked"`
	CreatedAt time.Time `bson:"created_at" json:"createdAt"`
}

// MessageReceipt 已读回执
type MessageReceipt struct {
	ID             primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	ConversationID int64              `bson:"conversation_id" json:"conversationId,string"`
	MsgID          int64              `bson:"msg_id" json:"msgId,string"`
	UserID         int64              `bson:"user_id" json:"userId,string"`
	ReadAt         time.Time          `bson:"read_at" json:"readAt"`
}

// MessageFavorite 收藏
type MessageFavorite struct {
	ID             primitive.ObjectID `bson:"_id,omitempty" json:"-"`
	UserID         int64              `bson:"user_id" json:"userId,string"`
	ConversationID int64              `bson:"conversation_id" json:"conversationId,string"`
	MsgID          int64              `bson:"msg_id" json:"msgId,string"`
	CreatedAt      time.Time          `bson:"created_at" json:"createdAt"`
}
