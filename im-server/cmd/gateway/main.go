package main

import (
	"context"
	"log"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/service"
	"github.com/yourcompany/im-server/internal/store"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()

	if err := store.InitRedis(cfg); err != nil {
		log.Fatalf("init redis failed: %v", err)
	}
	if err := store.InitMongo(cfg); err != nil {
		log.Fatalf("init mongo failed: %v", err)
	}

	// 启动事件消费：api 发布的消息经 Redis 广播，本节点推送给在线客户端
	service.StartEventConsumer(context.Background())

	r := gin.Default()
	service.RegisterWSRoutes(r, cfg)

	log.Printf("im gateway listening on :%s", cfg.WSPort)
	if err := r.Run(":" + cfg.WSPort); err != nil {
		log.Fatal(err)
	}
}
