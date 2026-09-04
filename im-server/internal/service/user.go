package service

import (
	"context"
	"strings"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/store"
)

// GetProfile 我的资料
func GetProfile(ctx context.Context, userID int64) (*model.User, error) {
	var u model.User
	if err := store.DB.First(&u, userID).Error; err != nil {
		return nil, errs.Unauthorized
	}
	// 我的邀请码：优先取 user.my_invite_code；为空则回退到 invite_code.used_by = 本人
	// （后台在 invite_code 表把某个码关联到该用户时也视为「我的邀请码」）
	if u.MyInviteCode == "" {
		var ic model.InviteCode
		if err := store.DB.Where("used_by = ?", userID).Order("id desc").First(&ic).Error; err == nil {
			u.MyInviteCode = ic.Code
		}
	}
	return &u, nil
}

type UpdateProfileReq struct {
	Nickname     string  `json:"nickname"`
	Avatar       string  `json:"avatar"`
	Signature    *string `json:"signature"` // 指针语义：传了就更新（允许清空为空串），不传不动
	DepartmentID int64   `json:"departmentId"`
}

// UpdateProfile 更新资料
func UpdateProfile(ctx context.Context, userID int64, req *UpdateProfileReq) error {
	updates := map[string]interface{}{}
	if req.Nickname != "" {
		updates["nickname"] = req.Nickname
	}
	if req.Avatar != "" {
		updates["avatar"] = req.Avatar
	}
	if req.Signature != nil {
		updates["signature"] = *req.Signature
	}
	if req.DepartmentID > 0 {
		updates["department_id"] = req.DepartmentID
	}
	if len(updates) == 0 {
		return nil
	}
	return store.DB.Model(&model.User{}).Where("id = ?", userID).Updates(updates).Error
}

// SearchUsers 搜索用户（全员可见：昵称/手机号/邮箱/账号/靓号 ID）
func SearchUsers(ctx context.Context, kw string) ([]model.User, error) {
	kw = strings.TrimSpace(kw)
	if kw == "" {
		return nil, nil
	}
	var users []model.User
	// 需求12：纯数字 → 优先按靓号 short_id 精确匹配（通过 ID 添加好友）
	if isNumeric(kw) {
		var byShort model.User
		if err := store.DB.Where("status = ? AND short_id = ?", model.StatusNormal, kw).First(&byShort).Error; err == nil {
			return []model.User{byShort}, nil
		}
	}
	// 注意：short_id 也要 LIKE（比如搜 "1888" 能命中 short_id=18888 的用户）
	like := "%" + kw + "%"
	err := store.DB.Where("status = ? AND (short_id LIKE ? OR nickname LIKE ? OR account LIKE ? OR phone LIKE ? OR email LIKE ?)",
		model.StatusNormal, like, like, like, like, like).
		Limit(50).Find(&users).Error
	return users, err
}

// isNumeric 是否纯数字（靓号 ID 判断）
func isNumeric(s string) bool {
	if s == "" {
		return false
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return true
}

// GetUserDetail 用户详情（含在线状态——阶段 3 接入 Redis 路由表后补充）
func GetUserDetail(ctx context.Context, targetID int64) (*model.User, error) {
	var u model.User
	if err := store.DB.First(&u, targetID).Error; err != nil {
		return nil, &errs.Err{Code: 3001, Msg: "用户不存在"}
	}
	return &u, nil
}

// IsVipShortID 用户的短 ID 是否为后台靓号（reserved_short_id 池中已分配给该用户的号）
func IsVipShortID(ctx context.Context, userID int64, shortID *string) bool {
	if shortID == nil || *shortID == "" || userID <= 0 {
		return false
	}
	var cnt int64
	store.DB.Model(&model.ReservedShortID{}).
		Where("short_id = ? AND status = ? AND used_by = ?", *shortID, model.ReservedShortIDUsed, userID).
		Count(&cnt)
	return cnt > 0
}

// DeptTree 部门树（双语字段由客户端按语言取 nameZh/nameEn）
func DeptTree(ctx context.Context) ([]*model.Department, error) {
	var depts []*model.Department
	if err := store.DB.Order("sort asc, id asc").Find(&depts).Error; err != nil {
		return nil, err
	}
	return depts, nil
}

// DeptMembers 部门成员
func DeptMembers(ctx context.Context, deptID int64) ([]model.User, error) {
	var users []model.User
	err := store.DB.Where("department_id = ? AND status = ?", deptID, model.StatusNormal).
		Order("id asc").Find(&users).Error
	return users, err
}
