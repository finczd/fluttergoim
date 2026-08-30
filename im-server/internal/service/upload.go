package service

import (
	"context"
	"fmt"
	"mime/multipart"
	"path/filepath"
	"strings"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	"github.com/yourcompany/im-server/internal/config"
)

// ============ MinIO 文件上传 ============

var minioClient *minio.Client

// EnsureMinioClient 懒初始化 MinIO 客户端
func EnsureMinioClient(cfg *config.Config) (*minio.Client, error) {
	if minioClient != nil {
		return minioClient, nil
	}
	client, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: false,
	})
	if err != nil {
		return nil, err
	}
	// 确保 bucket 存在
	ctx := context.Background()
	exists, err := client.BucketExists(ctx, cfg.MinIOBucket)
	if err == nil && !exists {
		client.MakeBucket(ctx, cfg.MinIOBucket, minio.MakeBucketOptions{})
	}
	minioClient = client
	return minioClient, nil
}

// UploadFile 上传文件到 MinIO，返回可访问 URL
// objectPrefix：chat/ 或 avatar/ 等分类
func UploadFile(ctx context.Context, cfg *config.Config, objectPrefix string, file multipart.File, filename string, contentType string) (string, string, int64, error) {
	client, err := EnsureMinioClient(cfg)
	if err != nil {
		return "", "", 0, err
	}
	// 对象名：分类/时间戳_随机.ext（防重名）
	ext := filepath.Ext(filename)
	if ext == "" {
		ext = guessExt(contentType)
	}
	objectName := fmt.Sprintf("%s%d_%d%s", objectPrefix, time.Now().UnixMilli(), time.Now().Nanosecond(), strings.ToLower(ext))

	info, err := client.PutObject(ctx, cfg.MinIOBucket, objectName, file, -1, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", "", 0, err
	}

	// 公开访问 URL（浏览器可达地址，生产可配置 MINIO_PUBLIC_URL 域名）
	base := cfg.MinIOPublicURL
	if base == "" {
		base = "http://" + cfg.MinIOEndpoint
	}
	url := fmt.Sprintf("%s/%s/%s", strings.TrimRight(base, "/"), cfg.MinIOBucket, objectName)
	return url, objectName, info.Size, nil
}

func guessExt(contentType string) string {
	switch contentType {
	case "image/png":
		return ".png"
	case "image/jpeg":
		return ".jpg"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	case "video/mp4":
		return ".mp4"
	default:
		return ".bin"
	}
}
