-- =============================================
-- 群置顶消息（幂等，迁移器按文件只执行一次）
-- =============================================

ALTER TABLE `conversation` ADD COLUMN `pinned_msg_id` BIGINT DEFAULT 0 COMMENT '置顶消息ID';
ALTER TABLE `conversation` ADD COLUMN `pinned_msg_content` VARCHAR(512) DEFAULT '' COMMENT '置顶消息内容快照';
