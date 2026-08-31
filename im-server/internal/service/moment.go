package service

import (
	"context"
	"encoding/json"
	"strconv"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/store"
)

// ============ 朋友圈 ============
// user_id = -1 为小助手（管理员后台以小助手身份发布）
// hidden = true 屏蔽：仅发布者自己可见，好友不可见

const AssistantUID = int64(-1)

// MomentsPublish 发布朋友圈
func MomentsPublish(ctx context.Context, userID int64, content string, images []string) (*model.MomentsPost, error) {
	imgJSON, _ := json.Marshal(images)
	post := model.MomentsPost{
		UserID:  userID,
		Content: content,
		Images:  string(imgJSON),
		Likes:   "[]",
	}
	if err := store.DB.Create(&post).Error; err != nil {
		return nil, err
	}
	return &post, nil
}

// isFriendBidir 双向好友判定
func isFriendBidir(a, b int64) bool {
	var cnt int64
	store.DB.Model(&model.FriendRelation{}).
		Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)", a, b, b, a).
		Count(&cnt)
	return cnt > 0
}

// MomentsList 朋友圈时间线（可见性规则）：
// - 自己的所有动态（含被屏蔽的）
// - 小助手（uid=-1）的动态（未被屏蔽）
// - 好友的动态（被屏蔽的不可见）
func MomentsList(ctx context.Context, viewerID int64, page, size int) (map[string]interface{}, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 50 {
		size = 20
	}
	// 好友 id 列表
	var friendIDs []int64
	store.DB.Model(&model.FriendRelation{}).Where("user_id = ?", viewerID).
		Pluck("friend_id", &friendIDs)
	store.DB.Model(&model.FriendRelation{}).Where("friend_id = ?", viewerID).
		Pluck("user_id", &friendIDs)

	q := store.DB.Model(&model.MomentsPost{})
	if len(friendIDs) == 0 {
		// 无好友：只见自己的 + 小助手的
		q = q.Where("user_id = ? OR (user_id = ? AND hidden = false)", viewerID, AssistantUID)
	} else {
		q = q.Where(
			"user_id = ? OR (user_id = ? AND hidden = false) OR (user_id IN (?) AND hidden = false)",
			viewerID, AssistantUID, friendIDs,
		)
	}
	var total int64
	q.Count(&total)
	var posts []model.MomentsPost
	if err := q.Order("id DESC").Offset((page - 1) * size).Limit(size).Find(&posts).Error; err != nil {
		return nil, err
	}
		return map[string]interface{}{
		"total": total,
		"list":  momentOut(ctx, posts, viewerID),
	}, nil
}

// MomentsListByUser 查看指定用户的朋友圈（好友资料页"朋友圈"入口）
// 可见性：自己可见全部（含 hidden）；他人仅可见非 hidden 动态
func MomentsListByUser(ctx context.Context, viewerID, ownerID int64, page, size int) (map[string]interface{}, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 50 {
		size = 20
	}
	q := store.DB.Model(&model.MomentsPost{}).Where("user_id = ?", ownerID)
	if viewerID != ownerID {
		q = q.Where("hidden = false")
	}
	var total int64
	q.Count(&total)
	var posts []model.MomentsPost
	if err := q.Order("id DESC").Offset((page - 1) * size).Limit(size).Find(&posts).Error; err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"total": total,
		"list":  momentOut(ctx, posts, viewerID),
	}, nil
}

// momentOut 序列化（带发布者昵称/头像、点赞状态）
func momentOut(ctx context.Context, posts []model.MomentsPost, viewerID int64) []map[string]interface{} {
	// 收集发布者 + 点赞者
	uidSet := make(map[int64]bool)
	type likePair struct {
		postID int64
		uids   []int64
	}
	likes := make(map[int64][]int64, len(posts))
	for _, p := range posts {
		uidSet[p.UserID] = true
		uids := []int64{}
		if p.Likes != "" {
			_ = json.Unmarshal([]byte(p.Likes), &uids)
		}
		likes[p.ID] = uids
		for _, u := range uids {
			uidSet[u] = true
		}
	}
	ids := make([]int64, 0, len(uidSet))
	for u := range uidSet {
		ids = append(ids, u)
	}
	nameMap := userNameMap(ctx, ids)
	var users []model.User
	if len(ids) > 0 {
		store.DB.Where("id IN (?)", ids).Find(&users)
	}
	avatarMap := make(map[int64]string)
	for _, u := range users {
		avatarMap[u.ID] = u.Avatar
		if nameMap[u.ID] == "" {
			nameMap[u.ID] = u.Nickname
		}
	}
	ac := GetAssistantConfig(ctx, nil)

	out := make([]map[string]interface{}, 0, len(posts))
	for _, p := range posts {
		uids := likes[p.ID]
		liked := false
		for _, u := range uids {
			if u == viewerID {
				liked = true
				break
			}
		}
		images := []string{}
		if p.Images != "" {
			_ = json.Unmarshal([]byte(p.Images), &images)
		}
		name := nameMap[p.UserID]
		avatar := avatarMap[p.UserID]
		if p.UserID == AssistantUID {
			name = ac.Name
			avatar = ac.Avatar
		}
		out = append(out, map[string]interface{}{
			"id":           strconv.FormatInt(p.ID, 10),
			"userId":       strconv.FormatInt(p.UserID, 10),
			"senderName":   name,
			"senderAvatar": avatar,
			"assistant":    p.UserID == AssistantUID,
			"content":      p.Content,
			"images":       images,
			"likeCount":    len(uids),
			"liked":        liked,
			"hidden":       p.Hidden,
			"mine":         p.UserID == viewerID,
			"createdAt":    p.CreatedAt.Format("2006-01-02 15:04"),
		})
	}
	return out
}

// MomentLike 点赞 / 取消点赞（toggle），返回点赞后状态
func MomentLike(ctx context.Context, viewerID, postID int64) (bool, error) {
	var post model.MomentsPost
	if err := store.DB.First(&post, postID).Error; err != nil {
		return false, errs.ParamError
	}
	uids := []int64{}
	if post.Likes != "" {
		_ = json.Unmarshal([]byte(post.Likes), &uids)
	}
	found := false
	newUIDs := make([]int64, 0, len(uids))
	for _, u := range uids {
		if u == viewerID {
			found = true
			continue
		}
		newUIDs = append(newUIDs, u)
	}
	if !found {
		newUIDs = append(newUIDs, viewerID)
	}
	b, _ := json.Marshal(newUIDs)
	if err := store.DB.Model(&model.MomentsPost{}).Where("id = ?", postID).
		Update("likes", string(b)).Error; err != nil {
		return false, err
	}
	return !found, nil
}

// ============ 后台管理 ============

// AdminMomentList 后台朋友圈列表（全部，含屏蔽状态，带发布者）
func AdminMomentList(ctx context.Context, page, size int) (map[string]interface{}, error) {
	if page < 1 {
		page = 1
	}
	if size < 1 || size > 100 {
		size = 20
	}
	q := store.DB.Model(&model.MomentsPost{})
	var total int64
	q.Count(&total)
	var posts []model.MomentsPost
	if err := q.Order("id DESC").Offset((page - 1) * size).Limit(size).Find(&posts).Error; err != nil {
		return nil, err
	}
	return map[string]interface{}{"total": total, "list": momentOut(ctx, posts, 0)}, nil
}

// AdminMomentCreate 管理员以小助手身份发朋友圈
func AdminMomentCreate(ctx context.Context, content string, images []string, operator int64) (*model.MomentsPost, error) {
	post, err := MomentsPublish(ctx, AssistantUID, content, images)
	if err != nil {
		return nil, err
	}
	serviceAdminLog(ctx, operator, "moment.create", strconv.FormatInt(post.ID, 10))
	return post, nil
}

// AdminMomentHidden 屏蔽 / 取消屏蔽用户朋友圈（屏蔽后仅自己可见）
func AdminMomentHidden(ctx context.Context, postID int64, hidden bool, operator int64) error {
	if err := store.DB.Model(&model.MomentsPost{}).Where("id = ?", postID).
		Update("hidden", hidden).Error; err != nil {
		return err
	}
	action := "moment.unhide"
	if hidden {
		action = "moment.hide"
	}
	serviceAdminLog(ctx, operator, action, strconv.FormatInt(postID, 10))
	return nil
}

// AdminMomentDelete 删除违规朋友圈
func AdminMomentDelete(ctx context.Context, postID int64, operator int64) error {
	if err := store.DB.Delete(&model.MomentsPost{}, postID).Error; err != nil {
		return err
	}
	serviceAdminLog(ctx, operator, "moment.delete", strconv.FormatInt(postID, 10))
	return nil
}

// serviceAdminLog 复用 admin 服务日志
func serviceAdminLog(ctx context.Context, operator int64, action, detail string) {
	AdminLog(ctx, operator, action, detail, "", nil)
}
