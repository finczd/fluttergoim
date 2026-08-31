package service

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/store"
)

// ============ 极光推送（离线消息兜底，后台可配置） ============
//
// 设计：
//   - alias = 用户 ID 字符串（客户端登录后 setAlias(uid)，登出 deleteAlias），
//     服务端不需要维护 registration_id 映射表，一个 alias 天然覆盖用户的多台设备。
//   - 配置存 sys_config（后台「推送配置」页可改），回退环境变量 JPUSH_ENABLED /
//     JPUSH_APP_KEY / JPUSH_MASTER_SECRET；读库结果缓存 60s，改配置最迟 1 分钟生效。
//   - 推送时机：SendMessage 落库 + WS 广播之后，只推「当前不在 WS 在线集合」的接收者，
//     在线用户走长连接不需要系统通知。异步 goroutine 执行，失败只记日志不影响消息主流程。

// JPushConfig 推送配置（sys_config 键：jpush_enabled / jpush_app_key / jpush_master_secret / jpush_apns_production）
type JPushConfig struct {
	Enabled        bool   `json:"enabled"`
	AppKey         string `json:"appKey"`
	MasterSecret   string `json:"masterSecret"`
	ApnsProduction bool   `json:"apnsProduction"` // iOS APNs 生产环境（开发调试应为 false）
}

var (
	jpushMu     sync.Mutex
	jpushCache  *JPushConfig
	jpushLoaded time.Time
)

// GetJPushConfig 读取推送配置（数据库优先，回退环境变量；60s 缓存）
func GetJPushConfig(ctx context.Context) *JPushConfig {
	jpushMu.Lock()
	defer jpushMu.Unlock()
	if jpushCache != nil && time.Since(jpushLoaded) < 60*time.Second {
		return jpushCache
	}
	c := &JPushConfig{
		Enabled: boolVal(SysConfigGet(ctx, "jpush_enabled", os.Getenv("JPUSH_ENABLED") == "true")),
		AppKey:  strVal(SysConfigGet(ctx, "jpush_app_key", os.Getenv("JPUSH_APP_KEY"))),
		MasterSecret: strVal(SysConfigGet(ctx, "jpush_master_secret",
			os.Getenv("JPUSH_MASTER_SECRET"))),
		ApnsProduction: boolVal(SysConfigGet(ctx, "jpush_apns_production", false)),
	}
	jpushCache = c
	jpushLoaded = time.Now()
	return c
}

// PushMessageOffline 离线消息推送（异步调用）：只推不在线的接收者。
// 标题/内容：单聊 = 昵称 + 内容预览；群聊 = 群名 + 「昵称：预览」。
func PushMessageOffline(ctx context.Context, senderID int64, receiverIDs []int64, msg *model.Message) {
	c := GetJPushConfig(ctx)
	if !c.Enabled || c.AppKey == "" || c.MasterSecret == "" {
		return
	}
	// 过滤出离线接收者（在线用户已通过 WS 实时收到）
	aliases := make([]string, 0, len(receiverIDs))
	for _, uid := range receiverIDs {
		if online, _ := IsUserOnline(ctx, uid); !online {
			aliases = append(aliases, fmt.Sprintf("%d", uid))
		}
	}
	if len(aliases) == 0 {
		return
	}

	// 标题：群聊用群名，单聊用发送者昵称
	var conv model.Conversation
	_ = store.DB.First(&conv, msg.ConversationID).Error
	var sender model.User
	senderName := ""
	if err := store.DB.First(&sender, senderID).Error; err == nil {
		senderName = sender.Nickname
	}
	title := senderName
	preview := msgPushPreview(msg)
	if conv.ID != 0 && conv.Type == model.ConvGroup {
		title = conv.NameZh
		if title == "" {
			title = conv.NameEn
		}
		if senderName != "" {
			preview = senderName + ": " + preview
		}
	}

	// 会话名：群聊用群名，单聊用发送者昵称（客户端点击通知跳会话页显示标题）
	convName := senderName
	if conv.ID != 0 && conv.Type == model.ConvGroup && conv.NameZh != "" {
		convName = conv.NameZh
	}
	extras := map[string]string{
		"conversationId": fmt.Sprintf("%d", msg.ConversationID),
		"msgId":          fmt.Sprintf("%d", msg.MsgID),
		"senderId":       fmt.Sprintf("%d", senderID),
		"convType":       fmt.Sprintf("%d", conv.Type),
		"convName":       convName,
	}
	if err := jpushToAliases(ctx, c, aliases, title, preview, extras); err != nil {
		log.Printf("[jpush] push failed: %v", err)
	}
}

// jpushToAliases 调极光 REST API v3/push 按 alias 群发通知
func jpushToAliases(ctx context.Context, c *JPushConfig, aliases []string, title, alert string, extras map[string]string) error {
	body := map[string]interface{}{
		"platform": "all",
		"audience": map[string]interface{}{"alias": aliases},
		"notification": map[string]interface{}{
			"android": map[string]interface{}{
				"alert":  alert,
				"title":  title,
				"extras": extras,
			},
			"ios": map[string]interface{}{
				"alert":  alert,
				"sound":  "default",
				"badge":  "+1",
				"extras": extras,
			},
		},
		"options": map[string]interface{}{
			"apns_production": c.ApnsProduction,
			"time_to_live":    86400,
		},
	}
	b, _ := json.Marshal(body)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.jpush.cn/v3/push", bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	// 极光 HTTP Basic 认证：base64(appKey:masterSecret)
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.
		EncodeToString([]byte(c.AppKey+":"+c.MasterSecret)))

	client := &http.Client{Timeout: 8 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var r struct {
		Error *struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		} `json:"error"`
		MsgID int64 `json:"msg_id"`
	}
	if err := json.Unmarshal(raw, &r); err != nil {
		return fmt.Errorf("jpush bad response: %s", strings.TrimSpace(string(raw)))
	}
	if r.Error != nil {
		return fmt.Errorf("jpush error %d: %s", r.Error.Code, r.Error.Message)
	}
	return nil
}

// msgPushPreview 消息内容 → 通知预览文案
func msgPushPreview(msg *model.Message) string {
	const maxLen = 50
	cut := func(s string) string {
		r := []rune(s)
		if len(r) > maxLen {
			return string(r[:maxLen]) + "…"
		}
		return s
	}
	switch msg.Type {
	case model.MsgText:
		return cut(msg.Content)
	case model.MsgImage:
		return "[图片]"
	case model.MsgFile:
		return "[文件]"
	case model.MsgVoice:
		return "[语音]"
	case model.MsgVideo:
		return "[视频]"
	case model.MsgRedPacket:
		return "[红包]"
	case model.MsgTransfer:
		return "[转账]"
	default:
		return "[新消息]"
	}
}
