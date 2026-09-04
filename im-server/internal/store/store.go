package store

import (
	"context"
	"log"
	"time"

	"github.com/yourcompany/im-server/internal/config"
	"github.com/yourcompany/im-server/internal/model"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

var (
	DB    *gorm.DB
	RDB   *redis.Client
	Mongo *mongo.Database
)

func InitMySQL(cfg *config.Config) error {
	var err error
	DB, err = gorm.Open(mysql.Open(cfg.MySQLDSN), &gorm.Config{})
	if err != nil {
		return err
	}
	sqlDB, _ := DB.DB()
	sqlDB.SetMaxOpenConns(50)
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetConnMaxLifetime(time.Hour)
	// 幂等建表/加列：钱包流水、朋友圈、群聊；user 表补 balance 列
	if err := DB.AutoMigrate(
		&model.WalletTransaction{},
		&model.MomentsPost{},
		&model.MomentsComment{},
		&model.RedPacketClaim{},
		&model.TransferClaim{},
		&model.MoneyPacket{},
		&model.User{},
		&model.InviteFriendCode{},
		&model.Conversation{},
		&model.ConversationMember{},
	); err != nil {
		return err
	}
	log.Println("mysql connected")
	return nil
}

func InitRedis(cfg *config.Config) error {
	RDB = redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddr,
		Password: cfg.RedisPass,
		DB:       cfg.RedisDB,
	})
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := RDB.Ping(ctx).Err(); err != nil {
		return err
	}
	log.Println("redis connected")
	return nil
}

func InitMongo(cfg *config.Config) error {
	opts := options.Client().ApplyURI(cfg.MongoURI)
	if cfg.MongoUser != "" {
		opts.SetAuth(options.Credential{Username: cfg.MongoUser, Password: cfg.MongoPassword})
	}
	client, err := mongo.Connect(context.Background(), opts)
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	if err := client.Ping(ctx, nil); err != nil {
		return err
	}
	Mongo = client.Database(cfg.MongoDB)
	// 消息集合索引：幂等去重 + 补拉 + 历史分页
	msgIdx := Mongo.Collection("message").Indexes()
	_, _ = msgIdx.CreateMany(ctx, []mongo.IndexModel{
		{Keys: bsonxDoc("sender_id", 1, "client_msg_id", 1), Options: options.Index().SetUnique(true)},
		{Keys: bsonxDoc("conversation_id", 1, "seq", 1)},
		{Keys: bsonxDoc("conversation_id", 1, "msg_id", -1)},
	})
	_, _ = Mongo.Collection("message_receipt").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys: bsonxDoc("conversation_id", 1, "msg_id", 1),
	})
	log.Println("mongo connected, indexes ensured")
	return nil
}

// bsonxDoc 简化 bson.D 构造
func bsonxDoc(pairs ...interface{}) bson.D {
	var d bson.D
	for i := 0; i+1 < len(pairs); i += 2 {
		d = append(d, bson.E{Key: pairs[i].(string), Value: pairs[i+1]})
	}
	return d
}
