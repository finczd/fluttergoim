package service

import (
	"context"
	"encoding/json"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/pkg/errs"
)

// ============ 智能小助手 ============
// 后台配置：助手昵称/头像/新注册自动添加开关
// 助手用固定虚拟 uid（-1 不占真实用户表），向用户发消息

// AssistantConfig 小助手配置（存 sys_config assistant_config JSON）
type AssistantConfig struct {
	Enabled     bool   `json:"enabled"`
	Name        string `json:"name"`
	Avatar      string `json:"avatar"`
	AutoAdd     bool   `json:"autoAdd"`     // 新注册是否自动添加助手
	WelcomeText string `json:"welcomeText"` // 自动添加后发送的欢迎语
}

// GetAssistantConfig 读小助手配置（默认关闭）
func GetAssistantConfig(ctx context.Context, cfg *config.Config) AssistantConfig {
	def := AssistantConfig{
		Enabled:     false,
		Name:        "小助手",
		Avatar:      "",
		AutoAdd:     false,
		WelcomeText: "你好，我是小助手，有问题随时找我～",
	}
	v := SysConfigGet(ctx, "assistant_config", "")
	if s, ok := v.(string); ok && s != "" && s != "null" {
		var ac AssistantConfig
		if jsonUnmarshal([]byte(s), &ac) == nil {
			return ac
		}
	}
	return def
}

// SaveAssistantConfig 保存小助手配置
func SaveAssistantConfig(ctx context.Context, ac AssistantConfig) error {
	b, _ := jsonMarshal(ac)
	return SysConfigSet(ctx, "assistant_config", string(b))
}

// AssistantAddForUser 新用户注册后自动添加小助手 + 发送欢迎语
func AssistantAddForUser(ctx context.Context, cfg *config.Config, userID int64) error {
	ac := GetAssistantConfig(ctx, cfg)
	if !ac.Enabled || !ac.AutoAdd || userID <= 0 {
		return nil
	}
	// 建会话（assistant 虚拟 uid = -1）
	conv, err := CreateDirect(ctx, userID, -1)
	if err != nil {
		return err
	}
	// 发欢迎消息
	if ac.WelcomeText != "" {
		SendMessage(ctx, -1, &SendMsgReq{
			ConversationID: conv.ID,
			Type:           1,
			Content:        ac.WelcomeText,
		})
	}
	return nil
}

// AssistantPush 以助手身份向指定用户推送消息（后台新建推送：文字/图片）
func AssistantPush(ctx context.Context, cfg *config.Config, userID int64, content string, fileURL string) error {
	ac := GetAssistantConfig(ctx, cfg)
	if !ac.Enabled {
		return &errs.Err{Code: 500, Msg: "小助手未启用"}
	}
	if userID <= 0 {
		return &errs.Err{Code: 1001, Msg: "用户无效"}
	}
	conv, err := CreateDirect(ctx, userID, -1)
	if err != nil {
		return err
	}
	req := &SendMsgReq{
		ConversationID: conv.ID,
		Type:           1,
		Content:        content,
	}
	if fileURL != "" {
		req.Type = 2 // 图片
		req.File = map[string]interface{}{
			"url":  fileURL,
			"name": "assistant-image",
			"size": 0,
		}
	}
	_, err = SendMessage(ctx, -1, req)
	return err
}

func jsonMarshal(v interface{}) ([]byte, error) { return json.Marshal(v) }
func jsonUnmarshal(b []byte, v interface{}) error { return json.Unmarshal(b, v) }
