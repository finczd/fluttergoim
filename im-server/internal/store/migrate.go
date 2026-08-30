package store

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// MigrateMySQL 幂等执行 migrations/*.sql
// 已执行过的文件记录在 schema_migrations 表，重复启动不会重复执行。
func MigrateMySQL() error {
	if DB == nil {
		return fmt.Errorf("mysql not initialized")
	}

	// 建迁移记录表（幂等）
	if err := DB.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		id BIGINT AUTO_INCREMENT PRIMARY KEY,
		filename VARCHAR(255) NOT NULL UNIQUE,
		applied_at DATETIME DEFAULT CURRENT_TIMESTAMP
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4`).Error; err != nil {
		return err
	}

	entries, err := os.ReadDir("migrations")
	if err != nil {
		// 兼容 Docker（WORKDIR /app 下 migrations 存在）与本地运行
		if _, err2 := os.Stat("../migrations"); err2 == nil {
			entries, err = os.ReadDir("../migrations")
		} else {
			return fmt.Errorf("migrations dir not found: %v", err)
		}
	}

	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)

	for _, f := range files {
		var cnt int64
		DB.Model(&struct{}{}).Table("schema_migrations").Where("filename = ?", f).Count(&cnt)
		if cnt > 0 {
			continue // 已执行
		}
		content, err := os.ReadFile(filepath.Join("migrations", f))
		if err != nil {
			if _, err2 := os.Stat("../migrations"); err2 == nil {
				content, err = os.ReadFile(filepath.Join("../migrations", f))
			}
			if err != nil {
				return fmt.Errorf("read %s: %w", f, err)
			}
		}
		// 按分号分割逐条执行（迁移文件为简单 DDL/DML，无存储过程）
		for _, stmt := range strings.Split(string(content), ";") {
			stmt = strings.TrimSpace(stmt)
			if stmt == "" {
				continue
			}
			if err := DB.Exec(stmt).Error; err != nil {
				return fmt.Errorf("exec %s: %w\nstmt: %s", f, err, stmt[:min(len(stmt), 200)])
			}
		}
		if err := DB.Exec("INSERT INTO schema_migrations (filename) VALUES (?)", f).Error; err != nil {
			return err
		}
		log.Printf("migration applied: %s", f)
	}
	log.Println("mysql migrations up to date")
	return nil
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
