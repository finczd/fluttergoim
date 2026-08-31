package model

import "time"

// RedPacketClaim 红包领取记录（一个红包多条领取，msg_id 关联 mongo 消息）
type RedPacketClaim struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	MsgID     int64     `gorm:"index" json:"msgId,string"` // 红包消息 ID
	UserID    int64     `gorm:"index" json:"userId,string"`
	Amount    float64   `gorm:"type:decimal(12,2)" json:"amount"`
	Seq       int       `gorm:"default:0" json:"seq"` // 第几个领取（从 1 开始）
	CreatedAt time.Time `json:"createdAt"`
}

func (RedPacketClaim) TableName() string { return "red_packet_claim" }

// TransferClaim 转账领取记录（一笔转账只能被领一次，msg_id 唯一索引兜底并发重复领取）
// 作用：收款入账改为服务端按消息内容入账，客户端不能再自己报金额给自己加钱（B-21）
type TransferClaim struct {
	ID        int64     `gorm:"primaryKey" json:"id,string"`
	MsgID     int64     `gorm:"uniqueIndex:uk_msg;index" json:"msgId,string"` // 转账消息 ID
	UserID    int64     `gorm:"index" json:"userId,string"`                   // 收款人
	Amount    float64   `gorm:"type:decimal(12,2)" json:"amount"`
	CreatedAt time.Time `json:"createdAt"`
}

func (TransferClaim) TableName() string { return "transfer_claim" }
