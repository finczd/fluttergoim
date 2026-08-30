# 企业级即时通讯系统（企业 IM）

Go + Vue3 + Flutter + MySQL + Redis + MongoDB 自研企业内部 IM。
中英双语、多端（H5 / App / PC / 管理后台）、实时音视频（腾讯云 TRTC）、
文件存储（MinIO）、多节点就近接入。

## 功能总览

| 端 | 说明 |
|---|---|
| **im-app**（Flutter） | 移动端 H5 + App：登录/注册（扫码登录）、会话列表（在线状态/滑动操作）、聊天（文本/图片/红包/转账/引用/撤回/置顶/已读/收藏/长按菜单）、群聊（@提醒/公告/群管理）、通讯录（加好友/靓号搜索/好友详情）、发现（后台小程序 + 内置浏览器）、我的（个人资料/二维码/版本更新）、语音视频通话（TRTC） |
| **im-pc**（Vue3） | PC 网页版：三栏布局、消息/通讯录/群聊/收藏/文件、实时 WS 推送、桌面通知、音视频通话（TRTC Web SDK）、已读回执 |
| **im-web**（Vue3） | 工作台 + **管理后台**：用户/群组/消息记录/数据统计/系统配置（品牌/版本/短信/TRTC/MinIO/节点）/小程序管理/智能小助手/节点管理/日志 |
| **im-server**（Go） | REST API（:8080）+ WebSocket 网关（:9090）：雪花 ID（字符串传输防精度丢失）、clientMsgId 幂等、会话内 seq、增量补拉、多端在线、已读回执、引用快照、靓号 ID、小助手 |

## 仓库结构

```
├── im-server/          # Go 后端
│   ├── cmd/api/        # REST API 服务（:8080）
│   ├── cmd/gateway/    # WebSocket 长连接网关（:9090）
│   ├── internal/       # config / model / handler / service / store / middleware / pkg
│   ├── migrations/     # SQL 迁移（幂等，容器首次启动自动执行）
│   └── Dockerfile*     # api / gateway 镜像
├── im-web/             # Vue3 工作台 + 管理后台（Arco Design）
├── im-pc/              # Vue3 PC 网页版（qingniao 壳 + API 适配层）
├── im-app/             # Flutter 移动端（H5 + App + 小程序）
├── deploy/             # Docker Compose 一键部署（含 nginx 反代配置）
└── README.md
```

## 快速启动

### Docker Compose 一键部署（推荐）

```bash
cd deploy
cp .env.example .env        # 修改密码、JWT_SECRET、MinIO 等
docker compose up -d        # 自动建表、初始化管理员
# 访问：H5 :8090，工作台 :8081，管理后台 :8082，PC :8091，MinIO :9000
```

### 本地开发

```bash
# 后端
cd im-server && cp .env.example .env && go run ./cmd/api & go run ./cmd/gateway

# Vue 工作台/后台
cd im-web && npm install && npm run dev

# PC 网页版
cd im-pc && npm install && npm run dev

# Flutter 移动端
cd im-app && flutter pub get && flutter build web --dart-define=API_BASE_URL=/api --dart-define=WS_BASE_URL=/ws --no-tree-shake-icons
```

## 关键设计

- **雪花 ID 全程字符串**：Go 端 19 位 ID 超出 JS Number 精度，所有 ID 字段 JSON 输出/接收统一字符串（`,string`），杜绝精度丢失
- **消息幂等 + 补拉**：`clientMsgId` 唯一索引去重；会话内 `seq`（Redis INCR）；断线 `/message/sync` 增量补拉
- **多端在线**：Redis 按设备类型登记（mobile/web/desktop），会话列表返回 `peerOnline` + `peerOnlineDev`
- **已读回执**：单聊对方 `last_read_msg_id ≥ msg_id` → `deliveryState=read`；群聊按人写回执
- **引用快照**：发送时冗余被引用消息内容/发送者，前端引用条直接显示原内容
- **靓号 ID**：注册自动生成 10 位 shortId（可后台保留号段），支持按 ID 精确搜索加好友
- **TRTC 音视频**：后端 HMAC-SHA256 签发 UserSig（密钥不下发），PC 用官方 trtc-js-sdk，App 用官方 tencent_trtc_cloud
- **MinIO 文件存储**：统一上传接口 `/api/v1/upload`，后台 Logo/默认头像直接传 MinIO

## 管理后台

| 页面 | 功能 |
|---|---|
| 用户管理 | 增删改查、禁用/启用、重置密码、靓号 |
| 群组管理 | 群列表、解散 |
| 消息记录 | 关键词/时间范围/会话筛选 |
| 数据统计 | 用户/在线/消息量 + 近 7 天柱状图 |
| 系统配置 | 注册认证、品牌（Logo 上传 MinIO）、版本更新、阿里云短信、腾讯云 TRTC、MinIO、节点、默认头像、保留靓号、公告 |
| 小程序管理 | 发现页小程序上架/排序 |
| 智能小助手 | 名称/头像/自动添加/欢迎语 + 以助手身份推送 |
| 节点管理 | 多节点接入地址 |
| 日志 | 操作日志 / 登录日志 |

## 默认账号

- 管理员：`admin` / `Admin@123456`
- 演示用户：`zhangwei@example.com` / `Passw0rd123`、`lina@example.com` / `Passw0rd123`

## 许可证

企业内部项目，私有部署。
