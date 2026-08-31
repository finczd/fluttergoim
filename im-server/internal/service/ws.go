package service

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/pkg/jwt"
	"github.com/yourcompany/im-server/internal/store"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// ============ 连接管理 ============

type ConnManager struct {
	mu    sync.RWMutex
	conns map[int64]map[*websocket.Conn]struct{}
}

var connMgr = &ConnManager{conns: make(map[int64]map[*websocket.Conn]struct{})}

func (m *ConnManager) add(uid int64, c *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.conns[uid] == nil {
		m.conns[uid] = make(map[*websocket.Conn]struct{})
	}
	m.conns[uid][c] = struct{}{}
}

func (m *ConnManager) remove(uid int64, c *websocket.Conn) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if set, ok := m.conns[uid]; ok {
		delete(set, c)
		if len(set) == 0 {
			delete(m.conns, uid)
		}
	}
}

// push 推送消息给本节点上线的用户
func (m *ConnManager) push(uid int64, frame []byte) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for c := range m.conns[uid] {
		_ = c.WriteMessage(websocket.TextMessage, frame)
	}
}

// ============ Redis 事件订阅（api 发布，gateway 推送） ============

// Event 跨服务事件（api → redis channel → gateway → 客户端）
type Event struct {
	Type    string          `json:"type"`    // message / recall / read / system / typing / call
	UserIDs []int64         `json:"userIds"` // 接收方
	Data    json.RawMessage `json:"data"`
}

const eventChannel = "im:events"

// PublishEvent 发布事件（api 侧调用，把消息推给在线用户）
func PublishEvent(ctx context.Context, ev *Event) error {
	b, err := json.Marshal(ev)
	if err != nil {
		return err
	}
	return store.RDB.Publish(ctx, eventChannel, string(b)).Err()
}

// StartEventConsumer 启动事件消费（gateway 进程启动时调用）
func StartEventConsumer(ctx context.Context) {
	sub := store.RDB.Subscribe(ctx, eventChannel)
	go func() {
		defer sub.Close()
		for msg := range sub.Channel() {
			var ev Event
			if err := json.Unmarshal([]byte(msg.Payload), &ev); err != nil {
				continue
			}
			for _, uid := range ev.UserIDs {
				frame, _ := json.Marshal(map[string]interface{}{
					"type": ev.Type,
					"data": ev.Data,
				})
				connMgr.push(uid, frame)
			}
		}
	}()
	log.Println("event consumer started")
}

// ============ WebSocket 处理 ============

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// RegisterWSRoutes 注册 WebSocket 路由（网关）
func RegisterWSRoutes(r *gin.Engine, cfg *config.Config) {
	r.GET("/ws", func(c *gin.Context) { handleWS(c, cfg) })
}

// ClientFrame 客户端 → 服务端帧
type ClientFrame struct {
	Action string          `json:"action"` // ping / typing
	Data   json.RawMessage `json:"data"`
}

func handleWS(c *gin.Context, cfg *config.Config) {
	// 鉴权：?token=JWT
	token := c.Query("token")
	claims, err := jwt.Parse(cfg.JWTSecret, token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"code": 1002, "message": "未登录或登录过期"})
		return
	}
	uid := claims.UserID

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	defer conn.Close()

	// 在线状态注册：按设备类型存集合（多端同时在线互不覆盖）
	// 前端 WS 连接带 deviceType 参数（1 Android/2 iOS/3 Web/4 Windows/5 macOS）
	dt := c.Query("deviceType")
	if dt == "" {
		dt = "3" // 默认 Web
	}
	deviceName := deviceNameOf(dt)
	onlineKey := "online:" + stringInt64(uid)
	markOnline(c.Request.Context(), onlineKey, deviceName, cfg.NodeID)
	// 需求8：记录客户端 IP（带设备前缀，多端各自一个 IP；格式 device:ip）
	clientIP := c.ClientIP()
	if clientIP == "" {
		clientIP = "unknown"
	}
	store.RDB.Set(c.Request.Context(), onlineKey+":ip:"+deviceName, clientIP, 90*time.Second)
	connMgr.add(uid, conn)
	defer func() {
		connMgr.remove(uid, conn)
		clearOnline(c.Request.Context(), onlineKey, deviceName)
	}()

	// 心跳
	conn.SetReadDeadline(time.Now().Add(90 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(90 * time.Second))
		return nil
	})
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for range ticker.C {
			if err := conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}()

	log.Printf("ws connected uid=%d node=%s device=%s", uid, cfg.NodeID, deviceName)
	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var frame ClientFrame
		if err := json.Unmarshal(raw, &frame); err != nil {
			continue
		}
		switch frame.Action {
		case "ping":
			// 心跳续期在线状态
			markOnline(c.Request.Context(), onlineKey, deviceName, cfg.NodeID)
			conn.WriteMessage(websocket.TextMessage, []byte(`{"type":"pong"}`))
		case "typing":
			// 转发输入状态（阶段 3 辅助，可后续完善）
			PublishEvent(c.Request.Context(), &Event{Type: "typing", Data: frame.Data})
		}
	}
}

func deviceNameOf(dt string) string {
	switch dt {
	case "1":
		return "android"
	case "2":
		return "ios"
	case "3":
		return "web"
	case "4":
		return "windows"
	case "5":
		return "macos"
	default:
		return "web"
	}
}

// markOnline 把设备加入在线集合（Redis Set：online:{uid}）
func markOnline(ctx context.Context, key, deviceName, nodeID string) {
	store.RDB.SAdd(ctx, key, deviceName)
	store.RDB.Expire(ctx, key, 90*time.Second)
}

// clearOnline 连接断开时把设备从集合移除
func clearOnline(ctx context.Context, key, deviceName string) {
	store.RDB.SRem(ctx, key, deviceName)
}

// IsUserOnline 查询用户是否在线（任意设备），返回在线设备名列表
func IsUserOnline(ctx context.Context, uid int64) (bool, []string) {
	key := "online:" + stringInt64(uid)
	devices, err := store.RDB.SMembers(ctx, key).Result()
	if err != nil || len(devices) == 0 {
		return false, nil
	}
	return true, devices
}

// OnlineIPs 查询用户在线设备的 IP（key online:{uid}:ip:{device}，device 为设备名）
func OnlineIPs(ctx context.Context, uid int64) []string {
	key := "online:" + stringInt64(uid)
	devices, err := store.RDB.SMembers(ctx, key).Result()
	if err != nil || len(devices) == 0 {
		return nil
	}
	ips := []string{}
	for _, d := range devices {
		ip, err := store.RDB.Get(ctx, key+":ip:"+d).Result()
		if err == nil && ip != "" {
			ips = append(ips, ip)
		}
	}
	return ips
}

// OnlineDeviceZh 设备名 → 中文展示（手机在线/H5在线/电脑在线等）
func OnlineDeviceZh(devices []string) string {
	if len(devices) == 0 {
		return ""
	}
	for _, d := range devices {
		switch d {
		case "ios", "android":
			return "手机在线"
		case "web":
			return "H5在线"
		case "windows", "macos":
			return "电脑在线"
		}
	}
	return ""
}

func stringInt64(v int64) string {
	b := make([]byte, 0, 20)
	return string(appendInt64(b, v))
}

func appendInt64(b []byte, v int64) []byte {
	if v == 0 {
		return append(b, '0')
	}
	neg := v < 0
	if neg {
		v = -v
	}
	var tmp [20]byte
	i := len(tmp)
	for v > 0 {
		i--
		tmp[i] = byte('0' + v%10)
		v /= 10
	}
	if neg {
		i--
		tmp[i] = '-'
	}
	return append(b, tmp[i:]...)
}
