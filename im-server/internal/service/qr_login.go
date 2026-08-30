package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/store"
)

// ============ 扫码登录（二维码状态机） ============
// PC 端展示二维码：payload = chatpulse://qr?ticket=xxx&secret=xxx&v=1
// 手机端扫一扫 → 解析 ticket → POST /auth/qr/confirm（携带登录态 token）
// PC 端轮询 GET /auth/qr/status?ticket=xxx → confirmed 后取 accessToken 登录

type QrTicketInfo struct {
	Ticket       string     `json:"ticket"`
	Secret       string     `json:"secret"`
	Payload      string     `json:"payload"`
	Status       string     `json:"status"` // pending / scanned / confirmed / expired
	Expires      int64      `json:"expires"`
	AccessToken  string     `json:"accessToken"`
	RefreshToken string     `json:"refreshToken"`
	User         *model.User `json:"user"`
}

const qrTicketTTL = 3 * time.Minute

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

// QrCreateTicket 创建二维码 ticket（PC 端登录页调用，无需登录态）
func QrCreateTicket(ctx context.Context, cfg *config.Config) (*QrTicketInfo, error) {
	ticket := randomHex(16)
	secret := randomHex(32)
	payload := fmt.Sprintf("chatpulse://qr?ticket=%s&secret=%s&v=1", ticket, secret)
	key := "qr:ticket:" + ticket
	if err := store.RDB.HSet(ctx, key, "secret", secret, "status", "pending", "uid", "0").Err(); err != nil {
		return nil, err
	}
	store.RDB.Expire(ctx, key, qrTicketTTL)
	return &QrTicketInfo{
		Ticket:  ticket,
		Secret:  secret,
		Payload: payload,
		Status:  "pending",
		Expires: time.Now().Add(qrTicketTTL).Unix(),
	}, nil
}

// QrConfirm 手机端扫码确认（需登录态：uid 来自 JWT）
func QrConfirm(ctx context.Context, cfg *config.Config, ticket string, uid int64) error {
	key := "qr:ticket:" + ticket
	status, err := store.RDB.HGet(ctx, key, "status").Result()
	if err != nil {
		return &errs.Err{Code: 4001, Msg: "二维码无效或已过期"}
	}
	if status != "pending" {
		return &errs.Err{Code: 4002, Msg: "二维码已处理"}
	}
	store.RDB.HSet(ctx, key, "status", "confirmed", "uid", fmt.Sprintf("%d", uid))
	// 已确认后保留 60s 供 PC 端轮询取 token
	store.RDB.Expire(ctx, key, 60*time.Second)
	return nil
}

// QrPollStatus PC 端轮询二维码状态
func QrPollStatus(ctx context.Context, cfg *config.Config, ticket string) (*QrTicketInfo, error) {
	key := "qr:ticket:" + ticket
	vals, err := store.RDB.HMGet(ctx, key, "secret", "status", "uid").Result()
	if err != nil || vals[0] == nil {
		return &QrTicketInfo{Ticket: ticket, Status: "expired"}, nil
	}
	status, _ := vals[1].(string)
	uidStr, _ := vals[2].(string)
	info := &QrTicketInfo{Ticket: ticket, Status: status}
	if status == "confirmed" && uidStr != "" && uidStr != "0" {
		var uid int64
		fmt.Sscanf(uidStr, "%d", &uid)
		u, err := GetUserDetail(ctx, uid)
		if err == nil {
			access, refresh, err := issueTokens(ctx, cfg, u, "qr-scan", 2)
			if err == nil {
				info.AccessToken = access
				info.RefreshToken = refresh
				info.User = u
			}
		}
		// 一次性：取完删除
		store.RDB.Del(ctx, key)
	}
	return info, nil
}
