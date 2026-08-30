package service

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strings"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/captcha"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/pkg/id"
	jwtx "github.com/yourcompany/im-server/internal/pkg/jwt"
	"github.com/yourcompany/im-server/internal/store"

	"golang.org/x/crypto/bcrypt"
)

const (
	authModeNone  = "none"
	authModeSMS   = "sms"
	authModeEmail = "email"
)

// ============ 管理员初始化 ============

// EnsureAdmin 启动时根据环境变量创建第一个管理员（幂等）
func EnsureAdmin(cfg *config.Config) error {
	if cfg.AdminInitUser == "" {
		return nil
	}
	var u model.User
	if err := store.DB.Where("account = ?", cfg.AdminInitUser).First(&u).Error; err == nil {
		return nil // 已存在
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(cfg.AdminInitPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	admin := model.User{
		ID:           id.Next(),
		Account:      cfg.AdminInitUser,
		PasswordHash: string(hash),
		Nickname:     "系统管理员",
		CountryCode:  "+86",
		Status:       model.StatusNormal,
		Role:         model.RoleAdmin,
	}
	if err := store.DB.Create(&admin).Error; err != nil {
		return err
	}
	log.Printf("admin account initialized: %s", cfg.AdminInitUser)
	return nil
}

// ============ 注册 ============

type RegisterReq struct {
	Account      string `json:"account" binding:"required"`  // 手机号或邮箱
	Password     string `json:"password" binding:"required"` // 8-20 位含字母数字
	Nickname     string `json:"nickname"`
	CountryCode  string `json:"countryCode"`
	DepartmentID int64  `json:"departmentId"`
	Code         string `json:"code"`       // 短信/邮箱验证码
	InviteCode   string `json:"inviteCode"` // 邀请码（开关开启时必填）
	CaptchaID    string `json:"captchaId"`  // 图形验证码 ID（防刷）
	CaptchaCode  string `json:"captchaCode"`
	DeviceID     string `json:"deviceId"`
	DeviceType   int    `json:"deviceType"`
}

// Register 注册（按认证模式校验验证码 / 邀请码 / 注册开关）
func Register(ctx context.Context, cfg *config.Config, req *RegisterReq) (*model.User, string, string, error) {
	// 1. 注册开关
	if !cfg.RegisterOn {
		return nil, "", "", errs.RegisterOff
	}
	// 2. 图形验证码（后台配置 captcha_enabled=true 才校验；默认关闭——前端已不再收集）
	if boolVal(SysConfigGet(ctx, "captcha_enabled", false)) {
		if err := verifyCaptcha(ctx, req.CaptchaID, req.CaptchaCode); err != nil {
			return nil, "", "", err
		}
	}
	// 3. 账号格式校验
	account := strings.TrimSpace(req.Account)
	if !isEmail(account) && !isPhone(account) {
		return nil, "", "", &errs.Err{Code: 1001, Msg: "账号需为邮箱或手机号"}
	}
	// 4. 密码强度
	if !validPassword(req.Password) {
		return nil, "", "", &errs.Err{Code: 1001, Msg: "密码需为 8-20 位且包含字母和数字"}
	}
	// 5. 邀请码（后台配置 invite_code_enabled 开启时校验）
	inviteOn := cfg.InviteCodeOn
	if v := SysConfigGet(ctx, "invite_code_enabled", cfg.InviteCodeOn); v != nil {
		inviteOn = boolVal(v)
	}
	if inviteOn {
		if err := consumeInviteCode(ctx, req.InviteCode, account); err != nil {
			return nil, "", "", err
		}
	}
	// 6. 按认证模式校验验证码
	switch cfg.AuthMode {
	case authModeSMS:
		if !isPhone(account) {
			return nil, "", "", &errs.Err{Code: 1001, Msg: "短信认证模式需使用手机号"}
		}
		if err := verifyCode(ctx, "sms", account, req.Code); err != nil {
			return nil, "", "", err
		}
	case authModeEmail:
		if !isEmail(account) {
			return nil, "", "", &errs.Err{Code: 1001, Msg: "邮箱认证模式需使用邮箱"}
		}
		if err := verifyCode(ctx, "email", account, req.Code); err != nil {
			return nil, "", "", err
		}
	case authModeNone:
		// 不认证：无需验证码
	default:
		return nil, "", "", &errs.Err{Code: 1001, Msg: "未知认证模式"}
	}

	// 7. 唯一性
	var cnt int64
	store.DB.Model(&model.User{}).Where("account = ?", account).Count(&cnt)
	if cnt > 0 {
		return nil, "", "", errs.AccountExists
	}

	// 8. 创建用户
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, "", "", err
	}
	nickname := req.Nickname
	if nickname == "" {
		nickname = defaultNickname(account)
	}
	cc := req.CountryCode
	if cc == "" {
		cc = "+86"
	}
	u := model.User{
		ID:           id.Next(),
		Account:      account,
		PasswordHash: string(hash),
		Nickname:     nickname,
		CountryCode:  cc,
		DepartmentID: req.DepartmentID,
		Status:       model.StatusNormal,
		Role:         model.RoleUser,
		ShortID:      genShortID(ctx),
	}
	// 需求9：默认头像（后台可配置 default_avatar，新注册用户使用）
	if av, ok := SysConfigGet(ctx, "default_avatar", "").(string); ok && av != "" {
		u.Avatar = av
	}
	if isEmail(account) {
		u.Email = account
	} else {
		u.Phone = account
	}
	if err := store.DB.Create(&u).Error; err != nil {
		return nil, "", "", err
	}

	// 9. 注册成功自动添加小助手（后台开启时）
	AssistantAddForUser(ctx, cfg, u.ID)

	// 10. 注册成功即登录，签发 token
	access, refresh, err := issueTokens(ctx, cfg, &u, req.DeviceID, req.DeviceType)
	return &u, access, refresh, err
}

// ============ 登录 ============

type LoginReq struct {
	Account    string `json:"account" binding:"required"`
	Password   string `json:"password" binding:"required"`
	DeviceID   string `json:"deviceId"`
	DeviceType int    `json:"deviceType"`
}

func Login(ctx context.Context, cfg *config.Config, req *LoginReq, ip string) (*model.User, string, string, error) {
	// 限流：每账号 5 次/分钟
	if err := rateLimit(ctx, "login:"+req.Account, 5, time.Minute); err != nil {
		return nil, "", "", err
	}

	var u model.User
	if err := store.DB.Where("account = ?", req.Account).First(&u).Error; err != nil {
		writeLoginLog(req.Account, ip, "", 0)
		return nil, "", "", errs.LoginFailed
	}
	if u.Status != model.StatusNormal {
		writeLoginLog(req.Account, ip, "", 0)
		return nil, "", "", errs.Forbidden
	}
	if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash), []byte(req.Password)) != nil {
		writeLoginLog(req.Account, ip, "", 0)
		return nil, "", "", errs.LoginFailed
	}

	// 更新最后登录时间
	now := time.Now()
	store.DB.Model(&u).Update("last_login_at", now)
	u.LastLoginAt = &now

	access, refresh, err := issueTokens(ctx, cfg, &u, req.DeviceID, req.DeviceType)
	writeLoginLog(req.Account, ip, deviceName(req.DeviceType), 1)
	return &u, access, refresh, err
}

// Refresh 刷新 access token
func Refresh(ctx context.Context, cfg *config.Config, refreshToken string) (string, error) {
	claims, err := jwtx.Parse(cfg.JWTSecret, refreshToken)
	if err != nil {
		return "", errs.Unauthorized
	}
	// 校验 Redis 白名单
	key := fmt.Sprintf("refresh:%d", claims.UserID)
	stored, err := store.RDB.Get(ctx, key).Result()
	if err != nil || stored != refreshToken {
		return "", errs.Unauthorized
	}
	var u model.User
	if err := store.DB.First(&u, claims.UserID).Error; err != nil || u.Status != model.StatusNormal {
		return "", errs.Unauthorized
	}
	return jwtx.Generate(cfg.JWTSecret, u.ID, u.Role, cfg.JWTAccessTTLHours)
}

// Logout 登出：删除 refresh 白名单
func Logout(ctx context.Context, userID int64) error {
	return store.RDB.Del(ctx, fmt.Sprintf("refresh:%d", userID)).Err()
}

// ============ 验证码 ============

type SendCodeReq struct {
	Account     string `json:"account" binding:"required"` // 手机号（短信模式）或邮箱（邮箱模式）
	CountryCode string `json:"countryCode"`                // 国际区号，默认 +86
	CaptchaID   string `json:"captchaId" binding:"required"`
	CaptchaCode string `json:"captchaCode" binding:"required"`
}

// SendCode 发送注册/找回验证码（按认证模式）
func SendCode(ctx context.Context, cfg *config.Config, req *SendCodeReq) error {
	if err := verifyCaptcha(ctx, req.CaptchaID, req.CaptchaCode); err != nil {
		return err
	}
	// 限流：每账号 1 次/60s
	if err := rateLimit(ctx, "sendcode:"+req.Account, 1, 60*time.Second); err != nil {
		return err
	}

	code, err := genCode(6)
	if err != nil {
		return err
	}

	switch cfg.AuthMode {
	case authModeSMS:
		if !isPhone(req.Account) {
			return &errs.Err{Code: 1001, Msg: "请输入手机号"}
		}
		if err := sendSMSCode(cfg, req.CountryCode, req.Account, code); err != nil {
			log.Printf("send sms failed: %v", err)
			return &errs.Err{Code: 2002, Msg: "短信发送失败，请检查配置"}
		}
		if err := storeCode(ctx, "sms", req.Account, code); err != nil {
			return err
		}
	case authModeEmail:
		if !isEmail(req.Account) {
			return &errs.Err{Code: 1001, Msg: "请输入邮箱"}
		}
		if err := sendEmailCode(cfg, req.Account, code); err != nil {
			log.Printf("send email failed: %v", err)
			return &errs.Err{Code: 2002, Msg: "邮件发送失败，请检查配置"}
		}
		if err := storeCode(ctx, "email", req.Account, code); err != nil {
			return err
		}
	default:
		return &errs.Err{Code: 1001, Msg: "当前为不认证模式，无需验证码"}
	}
	return nil
}

// Captcha 生成图形验证码，返回 captchaID 与 base64 图片
func Captcha(ctx context.Context) (string, string, error) {
	code, b64, err := captcha.Generate()
	if err != nil {
		return "", "", err
	}
	cid := "c" + hex.EncodeToString([]byte(fmt.Sprintf("%d-%d", time.Now().UnixNano(), codeLenRand())))
	if err := store.RDB.Set(ctx, "code:captcha:"+cid, code, 5*time.Minute).Err(); err != nil {
		return "", "", err
	}
	return cid, b64, nil
}

// ============ 内部工具 ============

func issueTokens(ctx context.Context, cfg *config.Config, u *model.User, deviceID string, deviceType int) (string, string, error) {
	access, err := jwtx.Generate(cfg.JWTSecret, u.ID, u.Role, cfg.JWTAccessTTLHours)
	if err != nil {
		return "", "", err
	}
	refresh, err := jwtx.Generate(cfg.JWTSecret, u.ID, u.Role, cfg.JWTRefreshTTLDays*24)
	if err != nil {
		return "", "", err
	}
	// refresh 白名单（Redis，TTL=refresh 有效期）
	if err := store.RDB.Set(ctx, fmt.Sprintf("refresh:%d", u.ID), refresh, time.Duration(cfg.JWTRefreshTTLDays)*24*time.Hour).Err(); err != nil {
		return "", "", err
	}
	// 设备登记
	if deviceID != "" {
		store.DB.Where("user_id = ? AND device_id = ?", u.ID, deviceID).Assign(model.Device{
			DeviceType:   deviceType,
			PushToken:    "",
			Status:       1,
			LastActiveAt: time.Now(),
		}).FirstOrCreate(&model.Device{UserID: u.ID, DeviceID: deviceID})
	}
	return access, refresh, nil
}

func verifyCaptcha(ctx context.Context, cid, code string) error {
	if cid == "" || code == "" {
		return &errs.Err{Code: 1001, Msg: "请先获取图形验证码"}
	}
	key := "code:captcha:" + cid
	stored, err := store.RDB.Get(ctx, key).Result()
	if err != nil || stored != strings.ToLower(code) {
		return &errs.Err{Code: 2002, Msg: "图形验证码错误或过期"}
	}
	store.RDB.Del(ctx, key)
	return nil
}

func storeCode(ctx context.Context, typ, account, code string) error {
	key := fmt.Sprintf("code:%s:%s", typ, account)
	return store.RDB.Set(ctx, key, code, 5*time.Minute).Err()
}

func verifyCode(ctx context.Context, typ, account, code string) error {
	key := fmt.Sprintf("code:%s:%s", typ, account)
	stored, err := store.RDB.Get(ctx, key).Result()
	if err != nil || stored != code {
		return errs.CodeInvalid
	}
	store.RDB.Del(ctx, key)
	return nil
}

func consumeInviteCode(ctx context.Context, code, account string) error {
	if code == "" {
		return errs.InviteInvalid
	}
	var ic model.InviteCode
	if err := store.DB.Where("code = ? AND enabled = 1", code).First(&ic).Error; err != nil {
		return errs.InviteInvalid
	}
	if ic.UsedBy != nil {
		return errs.InviteInvalid
	}
	if ic.ExpiresAt != nil && time.Now().After(*ic.ExpiresAt) {
		return errs.InviteInvalid
	}
	now := time.Now()
	return store.DB.Model(&ic).Updates(map[string]interface{}{
		"used_by": account, "used_at": now,
	}).Error
}

func rateLimit(ctx context.Context, key string, limit int, window time.Duration) error {
	k := "rl:" + key
	n, err := store.RDB.Incr(ctx, k).Result()
	if err != nil {
		return err
	}
	if n == 1 {
		store.RDB.Expire(ctx, k, window)
	}
	if n > int64(limit) {
		return errs.RateLimited
	}
	return nil
}

func writeLoginLog(account, ip, device string, result int) {
	var u model.User
	uid := int64(0)
	if err := store.DB.Where("account = ?", account).First(&u).Error; err == nil {
		uid = u.ID
	}
	store.DB.Create(&model.LoginLog{UserID: uid, IP: ip, Device: device, Result: result})
}

func genCode(n int) (string, error) {
	var sb strings.Builder
	for i := 0; i < n; i++ {
		b, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			return "", err
		}
		sb.WriteByte(byte('0' + b.Int64()))
	}
	return sb.String(), nil
}

func codeLenRand() int64 {
	b, _ := rand.Int(rand.Reader, big.NewInt(100000))
	return b.Int64()
}

func defaultNickname(account string) string {
	if isEmail(account) {
		return strings.Split(account, "@")[0]
	}
	if len(account) >= 4 {
		return "用户" + account[len(account)-4:]
	}
	return "用户"
}

// genShortID 生成用户靓号 ID（需求12：可通过 ID 添加好友）
// 规则：10 位纯数字（如 8600000001），避开已占用 + 后台保留号段（reserved_short_ids 配置）
func genShortID(ctx context.Context) string {
	reserved := map[string]bool{}
	if v, ok := SysConfigGet(ctx, "reserved_short_ids", "").(string); ok && v != "" {
		for _, s := range strings.Split(v, ",") {
			s = strings.TrimSpace(s)
			if s != "" {
				reserved[s] = true
			}
		}
	}
	prefix := "86"
	for i := int64(1); i < 999999999; i++ {
		short := prefix + fmt.Sprintf("%08d", i)
		if reserved[short] {
			continue
		}
		var cnt int64
		store.DB.Model(&model.User{}).Where("short_id = ?", short).Count(&cnt)
		if cnt == 0 {
			return short
		}
	}
	return fmt.Sprintf("%d", time.Now().UnixNano()%1000000000+8600000000)
}

func validPassword(p string) bool {
	if len(p) < 8 || len(p) > 20 {
		return false
	}
	hasLetter, hasDigit := false, false
	for _, c := range p {
		if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') {
			hasLetter = true
		}
		if c >= '0' && c <= '9' {
			hasDigit = true
		}
	}
	return hasLetter && hasDigit
}

func isEmail(s string) bool {
	return strings.Contains(s, "@") && strings.Contains(s, ".")
}

func isPhone(s string) bool {
	if len(s) < 5 || len(s) > 20 {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

func deviceName(t int) string {
	switch t {
	case 1:
		return "Android"
	case 2:
		return "iOS"
	case 3:
		return "Web"
	case 4:
		return "Windows"
	case 5:
		return "macOS"
	}
	return "Unknown"
}

var _ = errors.New
