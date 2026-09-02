package service

import (
	"context"
	"encoding/json"
	"log"
	"strings"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/store"
)

// ============ 客服 ============
// 后台把普通用户设为客服（user.role = RoleKefu = 3）；
// 系统配置 kefu_config：是否自动添加客服 + 添加方式（轮流 round / 全部 all）。
// 新用户注册后按配置自动与其建立好友关系（不走申请审批，仿 FriendRequestHandle 的双向 FirstOrCreate）。

// KefuConfig 客服配置（存 sys_config 键 kefu_config，通用 PUT /admin/configs/:key 整体 JSON 存取）
type KefuConfig struct {
	AutoAdd  bool   `json:"autoAdd"`            // 是否自动添加客服
	Mode     string `json:"mode"`               // "round" 轮流 / "all" 全部
	Greeting string `json:"greeting,omitempty"` // 客服自动打招呼内容（空字符串 = 不发；支持 {nickname} 占位符替换为客服昵称）
}

// DefaultKefuGreeting 默认打招呼文案（KefuConfigGet 在 greeting 为空时返回，让前端首次进入有占位可改）
const DefaultKefuGreeting = "你好，我是 {nickname}，很高兴为您服务~"

// KefuConfigGet 读客服配置（默认关闭 + 轮流 + 默认打招呼）。
// 注意：SysConfigGet 对 {"value": {...}} 包装会解包返回内层对象（map[string]interface{}），
// 这里 JSON round-trip 转回结构体；mode 非法时按 round 处理；greeting 为空时填充默认文案。
func KefuConfigGet(ctx context.Context) KefuConfig {
	def := KefuConfig{AutoAdd: false, Mode: "round", Greeting: DefaultKefuGreeting}
	v := SysConfigGet(ctx, "kefu_config", nil)
	if v == nil {
		return def
	}
	b, err := json.Marshal(v)
	if err != nil {
		return def
	}
	var kc KefuConfig
	if json.Unmarshal(b, &kc) != nil {
		return def
	}
	if kc.Mode != "all" {
		kc.Mode = "round"
	}
	if kc.Greeting == "" {
		kc.Greeting = DefaultKefuGreeting
	}
	return kc
}

// KefuList 在职客服列表：role=RoleKefu 且状态正常（StatusNormal=1；StatusDisabled=2 为封禁，不参与分配）
func KefuList(ctx context.Context) ([]model.User, error) {
	var list []model.User
	err := store.DB.Where("role = ? AND status = ?", model.RoleKefu, model.StatusNormal).
		Order("id ASC").Find(&list).Error
	return list, err
}

// KefuAddForUser 新用户注册后按配置自动添加客服好友（失败不阻断注册，调用方记 log）
func KefuAddForUser(ctx context.Context, userID int64) error {
	if userID <= 0 {
		return nil
	}
	kc := KefuConfigGet(ctx)
	if !kc.AutoAdd {
		return nil
	}
	list, err := KefuList(ctx)
	if err != nil {
		return err
	}
	if len(list) == 0 {
		return nil
	}

	if kc.Mode == "all" {
		for _, k := range list {
			if err := kefuBind(ctx, userID, k.ID); err != nil {
				return err
			}
			// 加完好友顺手发一条招呼（失败仅 log，不阻断后续客服分配）
			kefuGreet(ctx, userID, k, kc.Greeting)
		}
		return nil
	}

	// round：sys_config 键 kefu_rr_index 存计数器（读→+1→写回，非严格原子可接受）
	idx := 0
	if v := SysConfigGet(ctx, "kefu_rr_index", nil); v != nil {
		if f, ok := v.(float64); ok && f >= 0 {
			idx = int(f)
		}
	}
	_ = SysConfigSet(ctx, "kefu_rr_index", idx+1)
	k := list[idx%len(list)]
	if err := kefuBind(ctx, userID, k.ID); err != nil {
		return err
	}
	kefuGreet(ctx, userID, k, kc.Greeting)
	return nil
}

// kefuGreet 客服自动打招呼：客服以自己身份向新用户发一条文本消息。
// 行为对齐 AssistantNotify（CreateDirect + SendMessage），复用同一个单聊会话，
// 消息走 WS 广播 + 极光离线推送，无需新接口。
// greeting 为空、客服昵称为空时直接跳过（不打扰）。
func kefuGreet(ctx context.Context, userID int64, kefu model.User, greeting string) {
	if greeting == "" || userID <= 0 || kefu.ID <= 0 {
		return
	}
	text := greeting
	if kefu.Nickname != "" {
		text = strings.ReplaceAll(greeting, "{nickname}", kefu.Nickname)
	}
	conv, err := CreateDirect(ctx, userID, kefu.ID)
	if err != nil || conv == nil {
		log.Printf("[kefuGreet] CreateDirect failed: user=%d kefu=%d err=%v", userID, kefu.ID, err)
		return
	}
	if _, err := SendMessage(ctx, kefu.ID, &SendMsgReq{
		ConversationID: conv.ID,
		Type:           model.MsgText,
		Content:        text,
		ClientMsgID:    newUUID(), // 防止重复发送场景下因空 ClientMsgID 被服务端生成多份
	}); err != nil {
		log.Printf("[kefuGreet] SendMessage failed: user=%d kefu=%d err=%v", userID, kefu.ID, err)
	}
}

// kefuBind 双向建立 user↔kefu 好友关系（已存在则跳过，仿 friend.go FriendRequestHandle 的 FirstOrCreate 写法）
func kefuBind(ctx context.Context, userID, kefuID int64) error {
	if userID <= 0 || kefuID <= 0 || userID == kefuID {
		return nil
	}
	if err := store.DB.FirstOrCreate(&model.FriendRelation{UserID: userID, FriendID: kefuID, Source: 1}, model.FriendRelation{UserID: userID, FriendID: kefuID}).Error; err != nil {
		return err
	}
	return store.DB.FirstOrCreate(&model.FriendRelation{UserID: kefuID, FriendID: userID, Source: 1}, model.FriendRelation{UserID: kefuID, FriendID: userID}).Error
}
