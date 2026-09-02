package config

import (
	"bufio"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// loadDotEnv 加载当前工作目录或父目录（最多 5 层）的 .env 到环境变量。
// 已存在的真实环境变量优先级更高，不会被 .env 覆盖。
// 不依赖 godotenv 第三方库，避免 GOPROXY 拉取失败。
func loadDotEnv() {
	wd, err := os.Getwd()
	if err != nil {
		return
	}
	for i := 0; i < 6; i++ {
		p := filepath.Join(wd, ".env")
		if f, e := os.Open(p); e == nil {
			scanner := bufio.NewScanner(f)
			for scanner.Scan() {
				line := strings.TrimSpace(scanner.Text())
				if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, "//") {
					continue
				}
				// 跳过 export FOO=bar 前缀
				if strings.HasPrefix(line, "export ") {
					line = strings.TrimSpace(strings.TrimPrefix(line, "export "))
				}
				idx := strings.Index(line, "=")
				if idx <= 0 {
					continue
				}
				k := strings.TrimSpace(line[:idx])
				v := strings.TrimSpace(line[idx+1:])
				if len(v) >= 2 {
					if (v[0] == '"' && v[len(v)-1] == '"') || (v[0] == '\'' && v[len(v)-1] == '\'') {
						v = v[1 : len(v)-1]
					} else {
						v = stripInlineComment(v)
					}
				} else {
					v = stripInlineComment(v)
				}
				if _, exists := os.LookupEnv(k); !exists {
					_ = os.Setenv(k, v)
				}
			}
			f.Close()
			log.Printf("[info] loaded env: %s", p)
			return
		}
		parent := filepath.Dir(wd)
		if parent == wd {
			break
		}
		wd = parent
	}
}

// stripInlineComment 剥离 .env 值的行内注释（` #` / `\t#` / ` //`），与 godotenv 行为一致。
// 只有注释标记前存在空白时才截断，避免误伤 URL 中的 `//`（如 mongodb://）。
func stripInlineComment(v string) string {
	for _, marker := range []string{" #", "\t#", " //", "\t//"} {
		if i := strings.Index(v, marker); i >= 0 {
			return strings.TrimSpace(v[:i])
		}
	}
	return strings.TrimSpace(v)
}

// Config 全局配置（环境变量驱动）
type Config struct {
	AppEnv string
	NodeID string

	HTTPPort string
	WSPort   string

	MySQLDSN      string
	RedisAddr     string
	RedisPass     string
	RedisDB       int
	MongoURI      string
	MongoDB       string
	MongoUser     string
	MongoPassword string

	MinIOEndpoint  string
	MinIOAccessKey string
	MinIOSecretKey string
	MinIOBucket    string
	MinIOPublicURL string // 浏览器可访问的公网地址（默认同 Endpoint）

	JWTSecret         string
	JWTAccessTTLHours int
	JWTRefreshTTLDays int

	AuthMode     string // none / sms / email
	InviteCodeOn bool
	RegisterOn   bool
	E2EOn        bool
	E2EMasterKey string

	AdminInitUser     string
	AdminInitPassword string

	TRTCAppID     string
	TRTCSecretKey string

	// 阿里云短信
	AliyunSMSAccessKey       string
	AliyunSMSSecretKey       string
	AliyunSMSSignName        string
	AliyunSMSTemplateCode    string
	AliyunSMSInternationalOn bool

	// SMTP 邮件
	SMTPHost     string
	SMTPPort     int
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string

	AccessNodes string // JSON 数组
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvBool(key string, def bool) bool {
	if v := os.Getenv(key); v != "" {
		b, err := strconv.ParseBool(v)
		if err == nil {
			return b
		}
	}
	return def
}

func getenvInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		n, err := strconv.Atoi(v)
		if err == nil {
			return n
		}
	}
	return def
}

func Load() *Config {
	// 先读 .env（im-server/.env 或父目录），再回落到默认值
	loadDotEnv()

	cfg := &Config{
		AppEnv: getenv("APP_ENV", "dev"),
		NodeID: getenv("NODE_ID", "node-a"),

		HTTPPort: getenv("HTTP_PORT", "8080"),
		WSPort:   getenv("WS_PORT", "9090"),

		MySQLDSN:      getenv("MYSQL_DSN", "root:change_me@tcp(127.0.0.1:3306)/im?charset=utf8mb4&parseTime=True&loc=UTC"),
		RedisAddr:     getenv("REDIS_ADDR", "127.0.0.1:6379"),
		RedisPass:     getenv("REDIS_PASSWORD", ""),
		RedisDB:       getenvInt("REDIS_DB", 0),
		MongoURI:      getenv("MONGO_URI", "mongodb://127.0.0.1:27017"),
		MongoDB:       getenv("MONGO_DB", "im"),
		MongoUser:     getenv("MONGO_USER", ""),
		MongoPassword: getenv("MONGO_PASSWORD", ""),

		MinIOEndpoint:  getenv("MINIO_ENDPOINT", "127.0.0.1:9000"),
		MinIOAccessKey: getenv("MINIO_ACCESS_KEY", "minioadmin"),
		MinIOSecretKey: getenv("MINIO_SECRET_KEY", "minioadmin"),
		MinIOBucket:    getenv("MINIO_BUCKET", "im-files"),
		MinIOPublicURL: getenv("MINIO_PUBLIC_URL", "http://127.0.0.1:9000"),

		JWTSecret: getenv("JWT_SECRET", "dev-secret"),
		// 需求：长时保持登录（默认 24h，刷新 token 30 天；可被 .env 覆盖）
		JWTAccessTTLHours: getenvInt("JWT_ACCESS_TTL_HOURS", 24),
		JWTRefreshTTLDays: getenvInt("JWT_REFRESH_TTL_DAYS", 30),

		AuthMode:     getenv("AUTH_MODE", "none"),
		InviteCodeOn: getenvBool("INVITE_CODE_ENABLED", false),
		RegisterOn:   getenvBool("REGISTER_ENABLED", true),
		E2EOn:        getenvBool("E2E_ENABLED", false),
		E2EMasterKey: getenv("E2E_MASTER_KEY", ""),

		AdminInitUser:     getenv("ADMIN_INIT_USERNAME", "admin"),
		AdminInitPassword: getenv("ADMIN_INIT_PASSWORD", "Admin@123456"),

		TRTCAppID:     getenv("TRTC_APP_ID", ""),
		TRTCSecretKey: getenv("TRTC_SECRET_KEY", ""),

		AliyunSMSAccessKey:       getenv("ALIYUN_SMS_ACCESS_KEY", ""),
		AliyunSMSSecretKey:       getenv("ALIYUN_SMS_SECRET_KEY", ""),
		AliyunSMSSignName:        getenv("ALIYUN_SMS_SIGN_NAME", ""),
		AliyunSMSTemplateCode:    getenv("ALIYUN_SMS_TEMPLATE_CODE", ""),
		AliyunSMSInternationalOn: getenvBool("ALIYUN_SMS_INTERNATIONAL_ENABLED", false),

		SMTPHost:     getenv("SMTP_HOST", ""),
		SMTPPort:     getenvInt("SMTP_PORT", 465),
		SMTPUser:     getenv("SMTP_USER", ""),
		SMTPPassword: getenv("SMTP_PASSWORD", ""),
		SMTPFrom:     getenv("SMTP_FROM", ""),

		AccessNodes: getenv("ACCESS_NODES", `[{"id":"node-a","name":"主节点","wss":"wss://im.example.com/ws","api":"https://im.example.com","weight":100}]`),
	}
	if cfg.JWTSecret == "dev-secret" {
		log.Println("[warn] JWT_SECRET 使用默认值，生产环境必须修改")
	}
	return cfg
}
