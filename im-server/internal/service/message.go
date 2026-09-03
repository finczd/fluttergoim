package service

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"regexp"
	"time"

	"github.com/yourcompany/im-server/internal/model"
	"github.com/yourcompany/im-server/internal/pkg/errs"
	"github.com/yourcompany/im-server/internal/pkg/id"
	"github.com/yourcompany/im-server/internal/store"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func msgColl() *mongo.Collection     { return store.Mongo.Collection("message") }
func receiptColl() *mongo.Collection { return store.Mongo.Collection("message_receipt") }

// ============ 发送消息 ============

type SendMsgReq struct {
	ConversationID int64                  `json:"conversationId,string" binding:"required"`
	ClientMsgID    string                 `json:"clientMsgId"` // 客户端幂等 ID（UUID），重试重发去重
	Type           int                    `json:"type"`        // 1 文本
	Content        string                 `json:"content" binding:"required"`
	File           map[string]interface{} `json:"file"`
	Mention        []int64                `json:"mention"`
	ReplyTo        int64                  `json:"replyTo,string"`
}

// SendMessage 发送消息：幂等落库（先落库后确认）→ 未读 → Redis 广播推送
func SendMessage(ctx context.Context, senderID int64, req *SendMsgReq) (*model.Message, error) {
	if !isMember(ctx, req.ConversationID, senderID) {
		return nil, errs.ConvNotFound
	}
	// 群禁言校验（在幂等判断之前，直接拒绝不落库）：
	//   1. 全员禁言：开启后仅群主/管理员可发言；
	//   2. 单人禁言：speak_muted_until 未到期不可发言。
	var conv model.Conversation
	if err := store.DB.First(&conv, req.ConversationID).Error; err == nil && conv.Type == model.ConvGroup {
		if conv.MuteAll == 1 && memberRole(ctx, req.ConversationID, senderID) == model.MemberNormal {
			return nil, errs.GroupMutedAll
		}
		var mem model.ConversationMember
		if err := store.DB.Where("conversation_id = ? AND user_id = ?", req.ConversationID, senderID).
			First(&mem).Error; err == nil && mem.SpeakMutedUntil > time.Now().Unix() {
			return nil, errs.MemberMuted
		}
	}
	if req.Type == 0 {
		req.Type = model.MsgText
	}
	// client_msg_id 必填：客户端未传时服务端生成（保证幂等索引唯一性）
	if req.ClientMsgID == "" {
		req.ClientMsgID = newUUID()
	}
	// 幂等：同 sender + client_msg_id 重复提交直接返回已存在消息（重试安全）
	if req.ClientMsgID != "" {
		var exist model.Message
		err := msgColl().FindOne(ctx,
			bson.M{"sender_id": senderID, "client_msg_id": req.ClientMsgID}).Decode(&exist)
		if err == nil {
			return &exist, nil // 已发送过，返回原消息
		}
	}

	// 红包(8) / 转账(9)：**落库前冻结资金**（B-19 + B-22）
	// 注意两点：
	//   1. 放在幂等判断之后：clientMsgId 重复提交会提前 return，保证重试不会重复冻结；
	//   2. 是**冻结**不是扣款 —— 钱从 balance 挪到 frozen，没人领时 24h 后原路退回，
	//      不会像以前那样「发出即扣款、没人领就凭空蒸发」。
	// msgID 必须在冻结前生成，资金包要按 msgID 记账。
	isMoney := req.Type == model.MsgRedPacket || req.Type == model.MsgTransfer
	msgID := id.Next()
	if isMoney {
		if err := SendMoneyFreeze(ctx, senderID, msgID, req.Type, req.Content); err != nil {
			return nil, err
		}
	}

	msg := &model.Message{
		ConversationID: req.ConversationID,
		MsgID:          msgID,
		ClientMsgID:    req.ClientMsgID,
		Seq:            nextSeq(ctx, req.ConversationID), // 会话内单调递增序号
		SenderID:       senderID,
		Type:           req.Type,
		Content:        req.Content,
		File:           req.File,
		Mention:        req.Mention,
		ReplyTo:        req.ReplyTo,
		Status:         model.MsgStatusNormal,
		CreatedAt:      time.Now(),
	}
	// 引用快照：被引用消息内容/发送者（前端引用条显示原内容）
	if req.ReplyTo > 0 {
		var ref model.Message
		if err := msgColl().FindOne(ctx, bson.M{"msg_id": req.ReplyTo}).Decode(&ref); err == nil {
			refSender := ""
			var refUser model.User
			if err := store.DB.First(&refUser, ref.SenderID).Error; err == nil {
				refSender = refUser.Nickname
			}
			msg.ReplySnapshot = map[string]interface{}{
				"content":    ref.Content,
				"senderName": refSender,
				"senderId":   ref.SenderID,
				"type":       ref.Type,
			}
		}
	}
	// 先落库，成功后确认（保证不丢消息）
	if _, err := msgColl().InsertOne(ctx, msg); err != nil {
		// 钱已冻结但消息没落库 → 立刻解冻退回，避免"钱被冻住、消息没了"。
		// MySQL(余额) 与 MongoDB(消息) 是两套存储，没法用数据库事务包住，
		// 所以用**补偿解冻**兜底（幂等，见 RefundMoneyPacket）。
		if isMoney {
			RefundMoneyPacket(ctx, msgID)
		}
		return nil, err
	}

	// 接收方 = 会话成员（排除发送者自己，自己消息直接回显）
	memberIDs := convMemberIDs(ctx, req.ConversationID)
	receivers := make([]int64, 0, len(memberIDs))
	for _, uid := range memberIDs {
		if uid == senderID {
			continue
		}
		receivers = append(receivers, uid)
		store.RDB.HIncrBy(ctx, fmt.Sprintf("unread:%d", uid), fmt.Sprintf("%d", req.ConversationID), 1)
	}

	// Redis 广播（gateway 推送给本节点在线用户）
	_ = PublishEvent(ctx, &Event{
		Type:    "message",
		UserIDs: append(receivers, senderID),
		Data:    marshalJSON(msg),
	})

	// 离线推送兜底（极光，后台可配置）：异步执行不阻塞主流程，
	// 只推当前不在 WS 在线集合的接收者（在线用户已通过长连接实时收到）
	go PushMessageOffline(context.Background(), senderID, receivers, msg)
	return msg, nil
}

// nextSeq 会话内单调递增序号（Redis INCR；并发安全）
func nextSeq(ctx context.Context, convID int64) int64 {
	seq, err := store.RDB.Incr(ctx, fmt.Sprintf("conv:seq:%d", convID)).Result()
	if err != nil {
		// Redis 不可用时退化为时间戳序号
		return time.Now().UnixMilli()
	}
	return seq
}

// Sync 增量补拉：重连补偿/上线拉取 seq > afterSeq 的消息（按 seq 升序，limit 上限）
func Sync(ctx context.Context, userID, convID, afterSeq int64, limit int64) ([]model.Message, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	if limit <= 0 || limit > 200 {
		limit = 100
	}
	filter := bson.M{
		"conversation_id": convID,
		"seq":             bson.M{"$gt": afterSeq},
		"blocked":         bson.M{"$ne": true}, // 后台屏蔽的消息不下发
	}
	opts := options.Find().SetSort(bson.D{{Key: "seq", Value: 1}}).SetLimit(limit)
	cur, err := msgColl().Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	var msgs []model.Message
	if err := cur.All(ctx, &msgs); err != nil {
		return nil, err
	}
	return msgs, nil
}

// LastSeq 会话当前最新 seq（客户端保存断点）
func LastSeq(ctx context.Context, convID int64) int64 {
	seq, _ := store.RDB.Get(ctx, fmt.Sprintf("conv:seq:%d", convID)).Int64()
	return seq
}

// ============ 历史消息 ============

// History 分页拉取：beforeMsgId 之前 limit 条
func History(ctx context.Context, userID, convID, beforeMsgID int64, limit int64) ([]model.Message, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	filter := bson.M{"conversation_id": convID, "blocked": bson.M{"$ne": true}}
	if beforeMsgID > 0 {
		filter["msg_id"] = bson.M{"$lt": beforeMsgID}
	}
	opts := options.Find().SetSort(bson.D{{Key: "msg_id", Value: -1}}).SetLimit(limit)
	cur, err := msgColl().Find(ctx, filter, opts)
	if err != nil {
		return nil, err
	}
	var msgs []model.Message
	if err := cur.All(ctx, &msgs); err != nil {
		return nil, err
	}
	// 倒序返回（时间正序）
	for i, j := 0, len(msgs)-1; i < j; i, j = i+1, j-1 {
		msgs[i], msgs[j] = msgs[j], msgs[i]
	}

	// 需求4：单聊我发的消息，对方已读 → delivery_state=read（fill Delivery 字段）
	var conv model.Conversation
	if err := store.DB.First(&conv, convID).Error; err == nil && conv.Type == model.ConvDirect {
		otherID := directOtherID(ctx, convID, userID)
		if otherID > 0 {
			var other model.ConversationMember
			if err := store.DB.Where("conversation_id = ? AND user_id = ?", convID, otherID).
				First(&other).Error; err == nil {
				for i := range msgs {
					if msgs[i].SenderID == userID {
						if other.LastReadMsgID >= msgs[i].MsgID {
							msgs[i].Delivery = "read"
						} else {
							msgs[i].Delivery = "sent"
						}
					}
				}
			}
		}
	}
	return msgs, nil
}

// ============ 撤回 ============

// RecallMessage 撤回：本人 2 分钟内；群主/管理员不限时撤群成员
func RecallMessage(ctx context.Context, userID int64, msgID int64) error {
	var msg model.Message
	err := msgColl().FindOne(ctx, bson.M{"msg_id": msgID}).Decode(&msg)
	if err != nil {
		return &errs.Err{Code: 4003, Msg: "消息不存在"}
	}
	// 权限
	if msg.SenderID != userID {
		role := memberRole(ctx, msg.ConversationID, userID)
		if role != model.MemberOwner && role != model.MemberAdmin {
			return errs.RecallDenied
		}
	} else if time.Since(msg.CreatedAt) > 2*time.Minute {
		return errs.RecallDenied
	}

	update := bson.M{
		"$set": bson.M{
			"recalled": true, "recalled_by": userID, "status": model.MsgStatusRecalled,
		},
	}
	if _, err := msgColl().UpdateOne(ctx, bson.M{"msg_id": msgID}, update); err != nil {
		return err
	}
	// 广播撤回通知
	_ = PublishEvent(ctx, &Event{
		Type:    "recall",
		UserIDs: convMemberIDs(ctx, msg.ConversationID),
		Data:    marshalJSON(map[string]interface{}{"conversationId": fmt.Sprintf("%d", msg.ConversationID), "msgId": fmt.Sprintf("%d", msgID), "recalledBy": fmt.Sprintf("%d", userID)}),
	})
	return nil
}

// ============ 已读上报 ============

// MarkRead 上报已读：写回执 + 清未读 + 广播 read 事件
func MarkRead(ctx context.Context, userID, convID, msgID int64) error {
	if !isMember(ctx, convID, userID) {
		return errs.ConvNotFound
	}
	// 更新成员已读位点
	store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, userID).
		Update("last_read_msg_id", msgID)
	// 清未读
	store.RDB.HDel(ctx, fmt.Sprintf("unread:%d", userID), fmt.Sprintf("%d", convID))

	// 群聊按人展示：写入回执
	if msgID > 0 {
		_, _ = receiptColl().UpdateOne(ctx,
			bson.M{"conversation_id": convID, "msg_id": msgID, "user_id": userID},
			bson.M{"$setOnInsert": bson.M{
				"conversation_id": convID, "msg_id": msgID, "user_id": userID, "read_at": time.Now(),
			}},
			options.Update().SetUpsert(true))
	}
	// 广播已读事件给会话成员（ID 用字符串，避免 H5 JS 精度丢失导致前端匹配失败）
	_ = PublishEvent(ctx, &Event{
		Type:    "read",
		UserIDs: convMemberIDs(ctx, convID),
		Data:    marshalJSON(map[string]interface{}{"conversationId": fmt.Sprintf("%d", convID), "userId": fmt.Sprintf("%d", userID), "msgId": fmt.Sprintf("%d", msgID)}),
	})
	return nil
}

// Receipts 已读成员列表（群按人展示）
func Receipts(ctx context.Context, userID, convID, msgID int64) ([]model.MessageReceipt, error) {
	if !isMember(ctx, convID, userID) {
		return nil, errs.ConvNotFound
	}
	cur, err := receiptColl().Find(ctx, bson.M{"conversation_id": convID, "msg_id": msgID})
	if err != nil {
		return nil, err
	}
	var receipts []model.MessageReceipt
	cur.All(ctx, &receipts)
	if receipts == nil {
		receipts = []model.MessageReceipt{}
	}
	return receipts, nil
}

// ============ 消息搜索 ============

// SearchMessages 关键词搜索（仅搜索自己参与的会话；convID 为空则全局）
func SearchMessages(ctx context.Context, userID int64, kw string, convID int64, page, size int) ([]model.Message, int64, error) {
	if kw == "" {
		return nil, 0, &errs.Err{Code: 1001, Msg: "请输入搜索关键词"}
	}
	// 用户参与的所有会话
	var myConvs []int64
	store.DB.Model(&model.ConversationMember{}).
		Where("user_id = ?", userID).Pluck("conversation_id", &myConvs)
	if len(myConvs) == 0 {
		return []model.Message{}, 0, nil
	}

	filter := bson.M{
		"conversation_id": bson.M{"$in": myConvs},
		"content":         bson.M{"$regex": regexp.QuoteMeta(kw), "$options": "i"},
		"blocked":         bson.M{"$ne": true}, // 后台屏蔽的消息不出现在搜索结果
	}
	if convID > 0 {
		if !isMember(ctx, convID, userID) {
			return nil, 0, errs.ConvNotFound
		}
		filter["conversation_id"] = convID
	}
	if size <= 0 || size > 100 {
		size = 20
	}
	if page <= 0 {
		page = 1
	}
	total, _ := msgColl().CountDocuments(ctx, filter)
	cur, err := msgColl().Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "msg_id", Value: -1}}).
			SetSkip(int64((page-1)*size)).SetLimit(int64(size)))
	if err != nil {
		return nil, 0, err
	}
	var msgs []model.Message
	cur.All(ctx, &msgs)
	return msgs, total, nil
}

// ============ 收藏 ============

func FavoriteAdd(ctx context.Context, userID, convID, msgID int64) error {
	_, err := store.Mongo.Collection("message_favorite").InsertOne(ctx, &model.MessageFavorite{
		UserID: userID, ConversationID: convID, MsgID: msgID, CreatedAt: time.Now(),
	})
	return err
}

func FavoriteList(ctx context.Context, userID int64, limit int64) ([]model.Message, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	cur, err := store.Mongo.Collection("message_favorite").
		Find(ctx, bson.M{"user_id": userID}, options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(limit))
	if err != nil {
		return nil, err
	}
	var favs []model.MessageFavorite
	if err := cur.All(ctx, &favs); err != nil {
		return nil, err
	}
	var msgs []model.Message
	for _, f := range favs {
		var m model.Message
		if err := msgColl().FindOne(ctx, bson.M{"msg_id": f.MsgID}).Decode(&m); err == nil {
			msgs = append(msgs, m)
		}
	}
	return msgs, nil
}

// ============ 内部辅助 ============

func marshalJSON(v interface{}) []byte {
	b, _ := json.Marshal(v)
	return b
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16])
}

func isMember(ctx context.Context, convID, userID int64) bool {
	var cnt int64
	store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ? AND user_id = ?", convID, userID).Count(&cnt)
	return cnt > 0
}

func memberRole(ctx context.Context, convID, userID int64) int {
	var m model.ConversationMember
	if err := store.DB.Where("conversation_id = ? AND user_id = ?", convID, userID).First(&m).Error; err != nil {
		return 0
	}
	return m.Role
}

func convMemberIDs(ctx context.Context, convID int64) []int64 {
	var ids []int64
	store.DB.Model(&model.ConversationMember{}).
		Where("conversation_id = ?", convID).Pluck("user_id", &ids)
	return ids
}

// sendGroupSystemMsg 群事件系统消息（type=6）：落 Mongo + 实时广播，不写未读数。
// content 为 JSON：{"kind":"invite|join|quit|kick|mute|unmute|muteAllOn|muteAllOff",
// "actor":"操作者昵称","target":"当事成员昵称","minutes":N}
// 客户端按 kind 用本语言词条渲染灰色居中提示条（对齐微信群事件提示）。
func sendGroupSystemMsg(ctx context.Context, convID int64, content string) {
	msg := &model.Message{
		ConversationID: convID,
		MsgID:          id.Next(),
		ClientMsgID:    newUUID(),
		Seq:            nextSeq(ctx, convID),
		SenderID:       0, // 系统消息无发送者
		Type:           model.MsgSystem,
		Content:        content,
		Status:         model.MsgStatusNormal,
		CreatedAt:      time.Now(),
	}
	if _, err := msgColl().InsertOne(ctx, msg); err != nil {
		return
	}
	_ = PublishEvent(ctx, &Event{
		Type:    "message",
		UserIDs: convMemberIDs(ctx, convID),
		Data:    marshalJSON(msg),
	})
}

// userName 取用户昵称（群系统消息文案用），查不到返回空串
func userName(userID int64) string {
	var u model.User
	if err := store.DB.First(&u, userID).Error; err != nil {
		return ""
	}
	return u.Nickname
}
