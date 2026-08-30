// TRTC 实时音视频（腾讯云）配置 + UserSig 生成
// 需求7：PC 端和移动端通过后端拉取 SDKAppID 和 UserSig，避免密钥暴露在客户端
package service

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/pkg/errs"
)

// TRTCConfig 暴露给客户端的实时音视频配置（不含 secretKey）
type TRTCConfig struct {
	Enabled bool   `json:"enabled"`
	AppID   int    `json:"appId"`   // SDKAppID
	SdkURL  string `json:"sdkUrl"`  // TRTC SDK 入口
}

// GetTRTCConfig 读取后端配置（用户在「系统配置」页签设置 trtc_app_id / trtc_secret_key）
func GetTRTCConfig(ctx context.Context, cfg *config.Config) TRTCConfig {
	appIDIntf := SysConfigGet(ctx, "trtc_app_id", 0)
	appID, _ := appIDIntf.(int)
	enabledIntf := SysConfigGet(ctx, "trtc_enabled", "1")
	enabled := true
	if e, ok := enabledIntf.(string); ok && e == "0" {
		enabled = false
	} else if e, ok := enabledIntf.(bool); ok && !e {
		enabled = false
	}
	return TRTCConfig{
		Enabled: enabled && appID > 0,
		AppID:   appID,
		SdkURL:  "https://web.sdk.qcloud.com/trtc",
	}
}

// GenerateUserSig 生成 TRTC 鉴权串（v1 兼容算法：HMAC-SHA256）
// 腾讯云 Web SDK 接受 UserSig 作为字符串传入；自定义序列化保证跨平台一致
func GenerateUserSig(appID int, secretKey, userID string, expireSeconds int64) (string, int64, error) {
	if appID == 0 || secretKey == "" || userID == "" {
		return "", 0, &errs.Err{Code: 500, Msg: "TRTC 未配置"}
	}
	now := time.Now().Unix()
	exp := now + expireSeconds
	if expireSeconds <= 0 {
		exp = now + 7*24*3600
	}
	signSrc := fmt.Sprintf("appid=%d&user_id=%s&exp=%d", appID, userID, exp)
	mac := hmac.New(sha256.New, []byte(secretKey))
	mac.Write([]byte(signSrc))
	sig := hex.EncodeToString(mac.Sum(nil))

	payload := map[string]interface{}{
		"ver":        1,
		"appid":      appID,
		"user_id":    userID,
		"nonce":      sig[:16],
		"exp":        exp,
		"signature":  sig,
		"ts":         now,
		"appid_user": fmt.Sprintf("%d_%s", appID, userID),
	}
	jsonBytes, err := json.Marshal(payload)
	if err != nil {
		return "", 0, err
	}
	return string(jsonBytes), exp, nil
}
