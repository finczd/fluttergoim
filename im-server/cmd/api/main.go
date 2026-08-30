package main

import (
	"log"
	"os"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/handler"
	"github.com/yourcompany/im-server/internal/pkg/id"
	"github.com/yourcompany/im-server/internal/service"
	"github.com/yourcompany/im-server/internal/store"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	// 雪花 ID 初始化（节点 ID 来自 NODE_ID 末尾数字，默认 0）
	nodeID := int64(0)
	if n, err := id.ParseNodeID(cfg.NodeID); err == nil {
		nodeID = n
	}
	id.Init(nodeID)

	// 初始化数据层
	if err := store.InitMySQL(cfg); err != nil {
		log.Fatalf("init mysql failed: %v", err)
	}
	if err := store.InitRedis(cfg); err != nil {
		log.Fatalf("init redis failed: %v", err)
	}
	if err := store.InitMongo(cfg); err != nil {
		log.Fatalf("init mongo failed: %v", err)
	}
	// 幂等迁移（启动时自动执行）
	if err := store.MigrateMySQL(); err != nil {
		log.Fatalf("migrate failed: %v", err)
	}
	// 管理员初始化（环境变量）
	if err := service.EnsureAdmin(cfg); err != nil {
		log.Fatalf("ensure admin failed: %v", err)
	}

	r := gin.Default()
	handler.RegisterRoutes(r, cfg)

	port := cfg.HTTPPort
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}
	log.Printf("im api server listening on :%s (node=%s)", port, cfg.NodeID)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}
