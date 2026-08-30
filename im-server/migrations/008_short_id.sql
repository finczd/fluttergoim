-- 008: 用户靓号 ShortID（可通过 ID 添加好友，后台可预留）
ALTER TABLE `user` ADD COLUMN `short_id` VARCHAR(32) NULL AFTER `country_code`;
CREATE UNIQUE INDEX `uk_user_short_id` ON `user` (`short_id`);
