# ChatPulse IM 后端 API 接口文档

> **本文件是后端接口的唯一权威文档。** 修改 / 新增 / 优化任何后端功能时，**必须同步更新本文件**（见文末《维护约定》）。以后加功能或排障无需再翻 Go 源码。
>
> 文档由 `internal/handler/*.go` 的路由注册与处理函数逐接口提取，字段名、类型、必填项、错误码均与源码一致。

## 通用约定

- **Base URL 前缀**：`/api/v1`（管理后台为 `/api/v1/admin`）。
- **统一响应信封**：`{"code":0,"message":"ok","data":{...}}`。`code=0` 表示成功；非 0 为业务错误，`message` 为可读说明。个别接口可能直接返回数据形态，以各接口“成功响应 data”为准。
- **鉴权**：除特别标注「公开」的接口外，`/api/v1/*` 其余接口需在 Header 携带 `Authorization: Bearer <token>`。管理后台接口另需管理员角色（`middleware.RequireAdmin`）。
- **时间**：时间字段一般为 RFC3339 字符串。
- **金额**：钱包相关金额单位为「分」（整数），以服务端为准，禁止客户端上报金额入账（见各钱包接口备注）。
- **分页**：列表类接口通常用 `page` / `size`（或 `limit`）查询参数，响应 `data` 含 `list` + `total`（部分含 `has_more`）。

## 端点索引

### 认证与通用

- `GET /api/v1/health`
- `GET /api/v1/access/nodes`
- `GET /api/v1/trtc/config`
- `GET /api/v1/auth/captcha`
- `POST /api/v1/auth/send-code`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `GET /api/v1/auth/config`
- `POST /api/v1/auth/qr/ticket`
- `GET /api/v1/auth/qr/status`
- `POST /api/v1/auth/logout`
- `POST /api/v1/upload`
- `POST /api/v1/auth/qr/scanned`
- `POST /api/v1/auth/qr/confirm`
- `GET /api/v1/trtc/usersig`
- `GET /api/v1/app/list`

### 用户与好友

- `GET /api/v1/user/profile`
- `PUT /api/v1/user/profile`
- `PUT /api/v1/user/password`
- `DELETE /api/v1/user`
- `GET /api/v1/user/search`
- `GET /api/v1/user/:id`
- `GET /api/v1/friend/list`
- `POST /api/v1/friend/request`
- `GET /api/v1/friend/request/incoming`
- `GET /api/v1/friend/request/outgoing`
- `POST /api/v1/friend/request/:id/handle`
- `DELETE /api/v1/friend/:id`
- `PUT /api/v1/friend/:id/remark`
- `POST /api/v1/friend/blacklist`
- `DELETE /api/v1/friend/blacklist/:id`
- `GET /api/v1/friend/blacklist`

### 会话与群组

- `GET /api/v1/conversation/list`
- `POST /api/v1/conversation/direct`
- `POST /api/v1/conversation/group`
- `GET /api/v1/conversation/:id/members`
- `PUT /api/v1/conversation/:id/pin-message`
- `GET /api/v1/conversation/:id/pins`
- `PUT /api/v1/conversation/:id/announcement`
- `POST /api/v1/conversation/:id/invite`
- `DELETE /api/v1/conversation/:id/members/:userId`
- `POST /api/v1/conversation/:id/quit`
- `POST /api/v1/conversation/:id/disband`
- `PUT /api/v1/conversation/:id`
- `PUT /api/v1/conversation/:id/pin`
- `PUT /api/v1/conversation/:id/mute`
- `GET /api/v1/conversation/:id/settings`
- `PUT /api/v1/conversation/:id/settings`
- `PUT /api/v1/conversation/:id/admin`
- `PUT /api/v1/conversation/:id/mute-member`
- `POST /api/v1/conversation/:id/join`
- `GET /api/v1/conversation/:id/preview`

### 消息

- `POST /api/v1/message/send`
- `GET /api/v1/message/history`
- `GET /api/v1/message/sync`
- `GET /api/v1/message/search`
- `POST /api/v1/message/:id/recall`
- `POST /api/v1/message/read`
- `GET /api/v1/message/receipts`
- `POST /api/v1/message/favorite`
- `GET /api/v1/message/favorites`

### 钱包 / 支付 / 朋友圈

- `GET /api/v1/wallet/me`
- `POST /api/v1/wallet/record`
- `POST /api/v1/wallet/transfer/:msgId/accept`
- `POST /api/v1/wallet/redpacket/:msgId/claim`
- `GET /api/v1/wallet/redpacket/:msgId`
- `GET /api/v1/wallet/records`
- `GET /api/v1/pay/config`
- `POST /api/v1/wallet/recharge/submit`
- `GET /api/v1/wallet/recharge/orders`
- `GET /api/v1/wallet/withdraw-account`
- `PUT /api/v1/wallet/withdraw-account`
- `POST /api/v1/wallet/withdraw/submit`
- `GET /api/v1/wallet/withdraw/orders`
- `GET /api/v1/moments`
- `GET /api/v1/moments/:ownerId`
- `POST /api/v1/moments`
- `POST /api/v1/moments/:id/like`


### 管理后台（一）：用户/配置/应用/助手/财务

- `GET /api/v1/admin/users`
- `POST /api/v1/admin/users`
- `PUT /api/v1/admin/users/:id/status`
- `PUT /api/v1/admin/users/:id/password`
- `GET /api/v1/admin/configs/:key`
- `PUT /api/v1/admin/configs/:key`
- `GET /api/v1/admin/app-entries`
- `POST /api/v1/admin/app-entries`
- `PUT /api/v1/admin/app-entries/:id`
- `DELETE /api/v1/admin/app-entries/:id`
- `GET /api/v1/admin/assistant/config`
- `POST /api/v1/admin/assistant/config`
- `GET /api/v1/admin/assistant/conversations`
- `GET /api/v1/admin/assistant/messages`
- `POST /api/v1/admin/assistant/push`
- `POST /api/v1/admin/wallet/adjust`
- `GET /api/v1/admin/users/:id/wallet`
- `POST /api/v1/admin/users/:id/recharge`
- `GET /api/v1/admin/finances`
- `GET /api/v1/admin/wallet/transactions`
- `GET /api/v1/admin/wallet/reconcile`
- `POST /api/v1/admin/wallet/refund-expired`
- `GET /api/v1/admin/pay-config`
- `PUT /api/v1/admin/pay-config`
- `GET /api/v1/admin/recharge-orders`
- `PUT /api/v1/admin/recharge-orders/:id/approve`
- `PUT /api/v1/admin/recharge-orders/:id/reject`


### 管理后台（二）：提现/群组/消息/统计/日志/靓号/邀请码/系统

- `GET /api/v1/admin/withdraw-orders`
- `PUT /api/v1/admin/withdraw-orders/:id/approve`
- `PUT /api/v1/admin/withdraw-orders/:id/reject`
- `DELETE /api/v1/admin/withdraw-orders/:id`
- `GET /api/v1/admin/groups`
- `DELETE /api/v1/admin/groups/:id`
- `GET /api/v1/admin/groups/:id/members`
- `GET /api/v1/admin/groups/:id/messages`
- `GET /api/v1/admin/messages`
- `POST /api/v1/admin/messages/:msgId/block`
- `DELETE /api/v1/admin/messages/:msgId`
- `GET /api/v1/admin/moments`
- `POST /api/v1/admin/moments`
- `PUT /api/v1/admin/moments/:id/hidden`
- `DELETE /api/v1/admin/moments/:id`
- `GET /api/v1/admin/stats/overview`
- `GET /api/v1/admin/stats/messages`
- `GET /api/v1/admin/logs`
- `GET /api/v1/admin/logs/login`
- `GET /api/v1/admin/reserved-short-ids`
- `POST /api/v1/admin/reserved-short-ids/batch`
- `PUT /api/v1/admin/reserved-short-ids/:id/remark`
- `PUT /api/v1/admin/reserved-short-ids/:id/frozen`
- `DELETE /api/v1/admin/reserved-short-ids/:id`
- `PUT /api/v1/admin/reserved-short-ids/:id/assign`
- `PUT /api/v1/admin/reserved-short-ids/:id/relieve`
- `GET /api/v1/admin/invite-friend-codes`
- `POST /api/v1/admin/invite-friend-codes`
- `PUT /api/v1/admin/invite-friend-codes/:id`
- `DELETE /api/v1/admin/invite-friend-codes/:id`
- `GET /api/v1/admin/health/:key`
- `POST /api/v1/admin/system/restart`
- `POST /api/v1/admin/upload`

---

> 统一响应信封：所有接口均返回 `HTTP 200`，体为 `{"code":0,"message":"ok","data":{...}}`。`code=0` 成功；非 0 为业务错误（读取 `message`）。错误码由 `handler.errCode(err)` 提取（`*errs.Err.Code`），未知错误回退为 `500`。

> `user` 子组（仍挂在 `/api/v1` 下）经 `middleware.Auth` 鉴权，需在 Header 带 `Authorization: Bearer <accessToken>`。公开接口见各块标注。

> 公共错误码（节选自 `internal/pkg/errs`）：1001 参数错误 / 1002 未登录或登录过期 / 1003 无权限 / 1004 账号已被封禁 / 2001 账号已存在 / 2002 验证码错误或过期 / 2003 邀请码无效 / 2004 注册已关闭 / 2005 账号或密码错误 / 4001 二维码无效或已过期（此处） / 4002 二维码已处理 / 5001 文件过大或类型不允许 / 7001 操作过于频繁。

---

### `GET /api/v1/health`

- 鉴权: 公开
- 说明: 健康检查，返回服务存活状态。
- 请求体: 无
- 成功响应 data: `{"status":"string // 固定 \"up\""}`
- 错误码: 无（恒成功）
- 备注: 无副作用。

### `GET /api/v1/access/nodes`

- 鉴权: 公开
- 说明: 返回就近接入节点列表（后台 `sys_config.access_nodes` 优先，回退 `cfg.AccessNodes`）。
- 请求体: 无
- 成功响应 data: `[]object // 节点数组（结构为后台配置的 JSON，元素字段不定），无配置时回退为 cfg.AccessNodes`
- 错误码: 无（恒成功，含回退）
- 备注: 客户端用于测速选路；data 可能为 `[]map[string]interface{}`。

### `GET /api/v1/trtc/config`

- 鉴权: 公开
- 说明: 返回 TRTC 配置（不含 secretKey）。
- 请求体: 无
- 成功响应 data: `{"enabled":"bool // 是否启用","appId":"int // SDKAppID","sdkUrl":"string // TRTC SDK 入口"}`
- 错误码: 无（恒成功）
- 备注: 由 `service.GetTRTCConfig` 读取后台 `trtc_app_id` 等，回退环境变量。

### `GET /api/v1/auth/captcha`

- 鉴权: 公开
- 说明: 生成图形验证码（防刷），返回验证码 ID 与 base64 图片。
- 请求体: 无
- 成功响应 data: `{"captchaId":"string // 图形验证码 ID","image":"string // 验证码图片 base64"}`
- 错误码: 500（验证码生成失败）
- 备注: 后续 `/auth/send-code` 需回传 `captchaId` + `captchaCode`。


### `POST /api/v1/auth/send-code`

- 鉴权: 公开
- 说明: 发送短信/邮箱验证码（按认证模式或显式指定渠道），发送前校验图形验证码。
- 请求体:
  ```json
  {"account":"string(必填) // 手机号(短信模式)或邮箱(邮箱模式)",
   "countryCode":"string(可选) // 国际区号，默认 +86",
   "captchaId":"string(必填) // 图形验证码 ID",
   "captchaCode":"string(必填) // 图形验证码内容",
   "channel":"string(可选) // sms 或 email；为空时按服务端 AUTH_MODE 决定"}
  ```
- 成功响应 data: `{"channel":"string // 实际发送渠道：sms / email"}`
- 错误码: 1001（参数错误）/ 2002（验证码错误或过期 / 短信或邮件服务未配置或发送失败）/ 7001（操作过于频繁，每账号 1 次/60s）
- 备注: 渠道与服务配置强相关——
  - `sms` 走阿里云短信。配置读取优先级：**后台 `sys_config`（`sms_access_key`/`sms_secret`/`sms_sign_name`/`sms_template_code`，即管理后台「系统设置-短信」）> 环境变量 `ALIYUN_SMS_ACCESS_KEY`/`ALIYUN_SMS_SECRET_KEY`/`ALIYUN_SMS_SIGN_NAME`/`ALIYUN_SMS_TEMPLATE_CODE`**。两者皆为空才返回「短信服务未配置」。**在后台配置短信后即可生效，无需改环境变量重启。**
  - `email` 走 SMTP。配置读取优先级：**后台 `sys_config`（`smtp_host`/`smtp_user`/`smtp_password`/`smtp_from`，可选 `smtp_port`）> 环境变量 `SMTP_HOST`/`SMTP_USER`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_PORT`**。两者皆为空才返回「邮件服务未配置」。
  - 若 `AUTH_MODE=none` 且未显式指定 `channel`，返回「当前未开启验证码服务」。
  - 图形验证码校验失败或限流时返回对应业务码；发送失败会在 message 中带上底层错误，便于排查。

### `POST /api/v1/auth/register`

- 鉴权: 公开
- 说明: 注册账号并返回登录令牌。
- 请求体:
  ```json
  {"account":"string(必填) // 手机号或邮箱",
   "password":"string(必填) // 8-20 位含字母数字",
   "nickname":"string(可选)",
   "countryCode":"string(可选)",
   "departmentId":"int(可选) // 部门 ID",
   "code":"string(可选) // 短信/邮箱验证码",
   "inviteCode":"string(可选) // 邀请码（邀请开关开启时必填）",
   "captchaId":"string(可选) // 图形验证码 ID（防刷）",
   "captchaCode":"string(可选) // 图形验证码内容",
   "channel":"string(可选) // sms 或 email；为空时按 AUTH_MODE 决定，需与发送验证码时所用渠道一致",
   "deviceId":"string(可选)",
   "deviceType":"int(可选)"}
  ```
- 成功响应 data: `{"user":"object(User) // 见 model.User","accessToken":"string","refreshToken":"string"}`
- 错误码: 1001（参数错误）/ 2001（账号已存在）/ 2002（验证码错误或过期）/ 2003（邀请码无效）/ 2004（注册已关闭）
- 备注: 受 `registerOn` 开关控制；`user` 字段为 `model.User`（注意 `id`/`departmentId` 以**字符串**形式输出，因 json tag `,string`；`shortId` 为可空字符串指针，未分配时为 `null`）。

### `POST /api/v1/auth/login`

- 鉴权: 公开
- 说明: 账号密码登录，返回用户信息与双令牌。
- 请求体:
  ```json
  {"account":"string(必填) // 手机号或邮箱",
   "password":"string(必填)",
   "deviceId":"string(可选)",
   "deviceType":"int(可选)"}
  ```
- 成功响应 data: `{"user":"object(User) // 见 model.User","accessToken":"string","refreshToken":"string"}`
- 错误码: 1001（参数错误）/ 1004（账号已被封禁，提示「您当前已经被封禁」）/ 2005（账号或密码错误）/ 7001（操作过于频繁，每账号 5 次/分钟）
- 备注: 记录登录 IP（入参 `c.ClientIP()`）；`user` 同上含 `id`/`departmentId` 字符串化字段。被封禁账号返回 1004（专用错误，不复用通用的「无权限」1003），客户端应明确提示封禁。

### `POST /api/v1/auth/refresh`

- 鉴权: 公开
- 说明: 用 refreshToken 换取新的 accessToken。
- 请求体:
  ```json
  {"refreshToken":"string(必填)"}
  ```
- 成功响应 data: `{"accessToken":"string"}`
- 错误码: 1001（参数错误，含 refreshToken 为空）/ errCode（刷新失败时的业务码）
- 备注: 仅返回新的 accessToken，refreshToken 不变。

### `GET /api/v1/auth/config`

- 鉴权: 公开
- 说明: 返回注册/登录页所需配置（数据库优先，回退环境变量）。
- 请求体: 无
- 成功响应 data: `{"authMode":"string","inviteCodeOn":"bool","registerOn":"bool","e2eOn":"bool","appName":"string","appLogo":"string","brandName":"string","brandLogo":"string","announcement":"string","appVersion":"string","updateLog":"string","androidUrl":"string","iosUrl":"string","hotUpdateUrl":"string"}`
- 错误码: 无（恒成功）
- 备注: 客户端据此渲染注册/登录页、品牌与公告跑马灯、版本更新检查。

### `POST /api/v1/auth/qr/ticket`

- 鉴权: 公开
- 说明: 创建扫码登录 ticket，返回二维码内容（payload）与状态信息。
- 请求体: 无
- 成功响应 data: `{"ticket":"string","secret":"string","payload":"string // chatpulse://qr?ticket=...&secret=...&v=1","status":"string // 初始 pending","expires":"int // Unix 秒级过期时间","accessToken":"string // 已确认前为空","refreshToken":"string","user":"object(User) // 已确认前为 null"}`
- 错误码: 500（生成二维码失败）
- 备注: ticket 用于 PC 端轮询；secret 不应对客户端暴露，仅用于生成 payload。

### `GET /api/v1/auth/qr/status`

- 鉴权: 公开
- 说明: PC 端轮询二维码状态；confirmed 且用户有效时直接下发令牌。
- 查询参数: `ticket:string`（必填，二维码 ticket）
- 请求体: 无
- 成功响应 data: `{"ticket":"string","secret":"string","payload":"string","status":"string // pending/scanned/confirmed/expired","expires":"int","accessToken":"string // confirmed 且有用户时返回","refreshToken":"string","user":"object(User) // confirmed 时返回，否则 null"}`
- 错误码: errCode（service 错误码，实际轮询失败也走 errCode，但代码见 err.Error()）；ticket 不存在/过期时返回 `status:"expired"` 且 code=0
- 备注: confirmed 后保留 60s 供轮询取 token；未确认时 `accessToken`/`refreshToken`/`user` 为空或 null。

### `POST /api/v1/auth/logout`

- 鉴权: 需要Token
- 说明: 登出（当前实现仅取 uid 调 Logout，未做令牌吊销）。
- 请求体: 无
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1002（未登录或登录过期，由 middleware.Auth 返回）
- 备注: 无状态令牌场景下登出多为客户端丢弃令牌。

### `POST /api/v1/upload`

- 鉴权: 需要Token
- 说明: 文件上传至 MinIO，支持 chat/avatar 目录分类。
- 请求体: multipart/form-data
  - `file`: 文件（必填，字段名 `file`）
  - `dir`: 字符串（可选，`chat` 或 `avatar`；缺省为 `chat/`，自动补 `/` 后缀）
- 成功响应 data: `{"url":"string // 可访问 URL","name":"string // 原始文件名","object":"string // 对象名(含前缀)","size":"int // 字节数","mimeType":"string // Content-Type"}`
- 错误码: 1001（缺少文件，即 `file` 字段缺失）/ 500（上传失败）/ 5001（文件过大或类型不允许，由 service 判定）
- 备注: 字段取自 `c.Request.FormFile("file")` 与 `c.PostForm("dir")`；`name` 取上传原始文件名。

### `POST /api/v1/auth/qr/scanned`

- 鉴权: 需要Token
- 说明: 手机端扫码成功，将 ticket 状态 pending → scanned（幂等，重复上报不报错）。
- 请求体:
  ```json
  {"ticket":"string // 二维码 ticket（未做必填校验，空 ticket 会被 service 判无效）"}
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1002（未登录）/ 4001（二维码无效或已过期）
- 备注: `uid` 取自 Token；已 scanned/confirmed 直接成功。

### `POST /api/v1/auth/qr/confirm`

- 鉴权: 需要Token
- 说明: 手机端确认登录，ticket pending/scanned → confirmed（兼容无 scanned 直接 confirm）。
- 请求体:
  ```json
  {"ticket":"string // 二维码 ticket"}
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1002（未登录）/ 4001（二维码无效或已过期）/ 4002（二维码已处理，状态非 pending/scanned）
- 备注: 确认后保留 60s 供 PC 端 `/auth/qr/status` 取令牌。

### `GET /api/v1/trtc/usersig`

- 鉴权: 需要Token
- 说明: 为当前用户生成 TRTC UserSig（后端用 secretKey 签名后下发）。
- 查询参数: `room:string`（可选，房间号，原样回显到 data.roomId）
- 请求体: 无
- 成功响应 data: `{"appId":"int","userId":"string // 当前用户 ID 字符串","userSig":"string","expire":"int // 过期秒数(相对值, 7*24*3600)","roomId":"string // 回显的 room 参数"}`
- 错误码: 1002（未登录）/ 500（TRTC 未配置 或 签名生成失败）
- 备注: TRTC 未启用时返回 `code:500`；`userId` 取自 Token 的 uid。

### `GET /api/v1/app/list`

- 鉴权: 需要Token
- 说明: 已上架小程序列表（发现页）。
- 请求体: 无
- 成功响应 data: `[{"id":"string // ID 字符串化","nameZh":"string","nameEn":"string","icon":"string","url":"string","category":"string","sort":"int","enabled":"int","createdAt":"string"}]`
- 错误码: 1002（未登录）/ 500（获取失败）
- 备注: 仅返回 `enabled = 1` 且按 `sort asc, id asc` 排序的 `model.AppEntry`；`id` 以字符串输出（json tag `,string`）。

---

> 基址 `/api/v1`，以下全部接口位于 `user` 子组，**需要 Bearer Token**（middleware.Auth）。>   
> 统一信封：`{"code":0,"message":"ok","data":{...}}`，非 0 为业务错误。>   
> 注意：所有 `id` 路径/返回字段在代码内为 `int64`，但 JSON 中以字符串形式传输（Go json tag `,string`），文档中标注 `int64(string)`。

---

### `GET /api/v1/user/profile`

- 鉴权: 需要Token
- 说明: 获取当前登录用户自己的资料，附带在线设备、在线状态与靓号标识。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `model.User` 全部字段（`id:int64(string)`、`account`、`nickname`、`avatar`、`signature`、`phone`、`email`、`countryCode`、`shortId:string?`、`balance:number`、`frozen:number`、`departmentId:int64(string)`、`status:int`、`role:int`、`myInviteCode:string`、`lastLoginAt:string?`、`createdAt`、`updatedAt`）+ 额外字段 `online:bool`、`onlineDevice:[]string`、`vipShortId:bool`
- 错误码: 服务错误走 `errCode(err)`（如用户不存在等）
- 备注: 额外三字段由 handler 注入，非 User 表字段；`shortId` 为指针类型，未分配时为 `null`；`lastLoginAt` 可为 `null`。`myInviteCode` 为空时服务端按回退链自动回填：①`user.my_invite_code` → ②`invite_code.used_by`=本人 → ③`invite_friend_code.friend_ids` 包含本人（后台自定义码关联的好友，带引号整串匹配防误伤）。

---

### `PUT /api/v1/user/profile`

- 鉴权: 需要Token
- 说明: 更新当前用户资料；非必填字段仅在提供时更新，且 `nickname/avatar/departmentId` 空值视为不更新。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "nickname": "string(可选) // 昵称，非空才更新",
    "avatar": "string(可选) // 头像，非空才更新",
    "signature": "string(可选) // 个人签名，传 null 或字符串都会覆盖（指针语义，可清空为空串）",
    "departmentId": "int64(string)(可选) // 部门ID，>0 才更新"
  }
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 4001-类参数错误为 `1001`（绑定失败）；其余走 `errCode(err)`
- 备注: `signature` 为 `*string`，不传该 key 则不动原值；传 `"signature":null` 或 `""` 均会写入（清空）。`nickname/avatar` 为空字符串时跳过更新（不会清空）。

---

### `PUT /api/v1/user/password`

- 鉴权: 需要Token
- 说明: 修改登录密码，需先校验原密码。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "oldPassword": "string(必填) // 原密码",
    "newPassword": "string(必填) // 新密码"
  }
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数错误 `1001`；原密码错误/更新失败走 `errCode(err)`
- 备注: 请求体为内联匿名结构体，字段无 `binding` 标记，空串不在此层拦截（由 service 校验原密码）。

---

### `DELETE /api/v1/user`

- 鉴权: 需要Token
- 说明: 注销当前登录账户。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 失败走 `errCode(err)`
- 备注: 无副作用参数；直接按当前 uid 删除/停用账户。

---

### `POST /api/v1/user/bind-phone/send-code`

- 鉴权: 需要Token
- 说明: 绑定手机号时发送短信验证码。需先校验图形验证码（防刷），再经已配置的短信服务（阿里云）下发。
- 请求体:
  ```json
  {"phone":"string(必填) // 待绑定的手机号",
   "countryCode":"string(可选) // 国际区号，默认 +86",
   "captchaId":"string(必填) // 图形验证码 ID",
   "captchaCode":"string(必填) // 图形验证码内容"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（参数错误/手机号格式不对）/ 2002（图形验证码错误或过期 / 短信服务未配置或发送失败）/ 7001（操作过于频繁，每手机号 1 次/60s）
- 备注: 仅校验图形验证码与下发短信，不写入手机号；真正绑定在 `/user/bind-phone`。

### `POST /api/v1/user/bind-phone`

- 鉴权: 需要Token
- 说明: 校验短信验证码后写入当前账号的手机号（含国家区号）。
- 请求体:
  ```json
  {"phone":"string(必填) // 待绑定的手机号",
   "countryCode":"string(可选) // 国际区号，默认 +86",
   "code":"string(必填) // 短信验证码"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（参数错误 / 该手机号已被其他账号绑定）/ 2002（验证码错误或过期）
- 备注: 校验通过后更新 `user.phone` 与 `user.country_code`；若手机号已被其它账号占用则拒绝绑定。

---

### `GET /api/v1/user/search`

- 鉴权: 需要Token
- 说明: 按关键字搜索用户（全员可见），结果附带在线状态。
- 路径参数: 无
- 查询参数: `kw:string(可选) // 关键字；为空时直接返回空数组`
- 请求体: 无
- 成功响应 data: `[User+online+onlineDevice+onlineText]` 数组；每项含 `online:bool`、`onlineDevice:[]string`、`onlineText:string`（中文设备描述）
- 错误码: 服务失败 `500`
- 备注: 纯数字 `kw` 会优先按靓号 `short_id` 精确匹配；无分页，返回全部匹配（服务端未限制条数）。

---

### `GET /api/v1/user/:id`

- 鉴权: 需要Token
- 说明: 获取指定用户详情，附带在线状态。
- 路径参数: `id:int64(string) // 目标用户ID`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `User+online+onlineDevice+onlineText`；同 `/user/search` 的单对象形式
- 错误码: 参数非整数 `1001`；用户不存在 `3001`（errCode 透传）
- 备注: `id` 由 `strconv.ParseInt` 解析，非数字直接 `1001`。

---

### `GET /api/v1/friend/list`

- 鉴权: 需要Token
- 说明: 获取我的好友列表，附带在线状态、备注与靓号标识。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[FriendInfo+online+onlineDevice+vipShortId]` 数组；`FriendInfo` = `User` 全部字段 + `remark:string`（我对他的备注，未设置则空）
- 错误码: 服务失败 `500`
- 备注: 无分页；handler 自行将 `remark` 与 `vipShortId` 注入；好友关系双向兼容（含反向关系补全）。

---

### `POST /api/v1/friend/request`

- 鉴权: 需要Token
- 说明: 向指定用户发起好友申请。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "toId": "int64(string)(必填) // 目标用户ID",
    "message": "string(可选) // 验证消息"
  }
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数错误/`toId` 为 0 `1001`；业务失败（如已是好友）走 `errCode(err)`
- 备注: `toId` 带 `binding:"required"` 且为 `,string` 数字串；`toId==0` 也会判为参数错误。

---

### `GET /api/v1/friend/request/incoming`

- 鉴权: 需要Token
- 说明: 获取我收到的待处理好友申请，并附带对方昵称/账号/头像。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[FriendRequest+fromUserName+fromUserAccount+fromUserAvatar+online]` 数组；`FriendRequest` = `id:int64(string)`、`fromUser:int64(string)`、`toUser:int64(string)`、`message:string`、`status:int`、`createdAt`。额外注入 `fromUserName:string`、`fromUserAccount:string`、`fromUserAvatar:string`、`online:bool`(硬编码 true)
- 错误码: 服务失败 `500`
- 备注: 仅返回 `status=待处理` 且 `to_user=我` 的申请，按 `id desc` 最多 50 条；`online` 固定 `true`（修复 PC "新朋友" 不显示昵称/账号）。

---

### `GET /api/v1/friend/request/outgoing`

- 鉴权: 需要Token
- 说明: 获取我发出的待处理好友申请。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[FriendRequest]` 数组（字段同 incoming 的 `FriendRequest` 部分，无对方附加字段）
- 错误码: 服务失败 `500`
- 备注: 仅返回 `status=待处理` 且 `from_user=我` 的申请，按 `id desc` 最多 50 条。

---

### `POST /api/v1/friend/request/:id/handle`

- 鉴权: 需要Token
- 说明: 处理（同意/拒绝）一条收到的好友申请。
- 路径参数: `id:int64(string) // 好友申请记录 ID`
- 查询参数: `agree:string(可选) // 默认同意；传 "0" 表示拒绝，其它值视为同意`
- 请求体: 无
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数非整数 `1001`；业务失败（如记录不存在/非收件人）走 `errCode(err)`
- 备注: `agree` 取 `c.Query("agree") != "0"` 判定；同意时双向写入好友关系。

---

### `DELETE /api/v1/friend/:id`

- 鉴权: 需要Token
- 说明: 删除指定好友。
- 路径参数: `id:int64(string) // 好友用户ID`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数非整数 `1001`；业务失败走 `errCode(err)`
- 备注: 按当前 uid 与好友 id 删除双向好友关系。

---

### `PUT /api/v1/friend/:id/remark`

- 鉴权: 需要Token
- 说明: 设置/清空对某好友的备注。
- 路径参数: `id:int64(string) // 好友用户ID`
- 查询参数: 无
- 请求体:
  ```json
  {
    "remark": "string(可选) // 备注内容，可传空串清空"
  }
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数非整数 `1001`；写入失败 `500`（注意：此接口绑定失败被忽略，不返回 1001）
- 备注: `c.ShouldBindJSON` 失败不拦截；`remark` 不传则保持原值（传空串清空）。

---

### `POST /api/v1/friend/blacklist`

- 鉴权: 需要Token
- 说明: 将指定用户加入黑名单。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "blockId": "int64(string)(必填) // 要拉黑的用户ID"
  }
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数错误/`blockId` 为 0 `1001`；服务失败 `500`
- 备注: `blockId` 带 `binding:"required"` 且为 `,string` 数字串。

---

### `DELETE /api/v1/friend/blacklist/:id`

- 鉴权: 需要Token
- 说明: 将指定用户移出黑名单。
- 路径参数: `id:int64(string) // 被拉黑用户ID`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 参数非整数 `1001`
- 备注: 调用 `service.BlacklistRemove` 即使出错也不检查返回值（静默成功）。

---

### `GET /api/v1/friend/blacklist`

- 鉴权: 需要Token
- 说明: 获取我的黑名单列表（返回对应用户信息）。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[User]` 数组（`model.User` 全部字段，无在线状态附加）
- 错误码: 服务失败 `500`
- 备注: 无分页；返回 `block_user_id` 对应的 `User` 对象列表。

---

> 基础前缀 `/api/v1`，本文件所有接口均挂在 `user` 子组下，**需要 Bearer Token**（`middleware.Auth`）。>   
> 统一响应：`{"code":0,"message":"ok","data":...}`，`code=0` 成功；错误时 `code≠0` 且通常无 `data`。>   
> 路径/请求体中的 ID 均为雪花 ID，JSON 中以**字符串**传输（`json:"...,string"`），Go 侧为 `int64`。>   
> 返回对象 `Conversation`（多个接口复用）字段：`id:string` `type:int(1=单聊 2=群聊)` `nameZh:string` `nameEn:string` `avatar:string` `ownerId:string` `announcementZh:string` `announcementEn:string` `maxMembers:int` `status:int(1=正常 2=解散)` `pinnedMsgId:string` `pinnedMsgContent:string` `pinnedMsgIds:string(JSON数组)` `muteAll:int(0/1)` `privacyEnabled:int(0/1)` `allowMemberInvite:int(0/1)` `qrJoinEnabled:int(0/1)` `createdAt:string` `updatedAt:string` `lastLoginAt:string|null`。

---

### `GET /api/v1/conversation/list`

- 鉴权: 需要Token
- 说明: 获取当前用户会话列表（聚合未读、最后一条消息、单聊对方在线状态）。
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `数组<ConvItem>`（无分页，返回全部）。ConvItem 含：`conversation:object(Conversation)` `unread:int64` `lastMessage:object|null(最后一条消息)` `memberCount:int64` `mute:bool` `pinned:bool` `conversationName:string` `peerId:string(单聊对方ID)` `peerOnline:bool` `peerOnlineDev:[]string` `peerOnlineZh:string` `peerOnlineIp:[]string` `peerShortId:string` `peerVipShortId:bool` `peerRemark:string`。
- 错误码: 500（获取失败）
- 备注: 单聊对象字段填充对方昵称/头像/在线状态，群聊 `conversationName` 取群名；已解散会话不出现。

---

### `POST /api/v1/conversation/direct`

- 鉴权: 需要Token
- 说明: 创建（或复用）单聊会话。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"userId":"string(必填) // 对方用户ID(雪花)"}
  ```
- 成功响应 data: `object(Conversation)`（创建者非成员；单聊双方各一条 member 记录）。
- 错误码: 1001（参数错误 / 不能和自己聊天）、500（服务内部错误）
- 备注: `userId` 为 `0` 或非数字会被 `binding:"required"` + 业务校验拒绝；已存在单聊则复用原会话。

---

### `POST /api/v1/conversation/group`

- 鉴权: 需要Token
- 说明: 创建群聊，当前用户为群主。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"nameZh":"string(可选) // 群名中文","nameEn":"string(可选) // 群名英文","memberIds":["string",...](可选) // 初始成员ID字符串数组(雪花)"}
  ```
- 成功响应 data: `object(Conversation)`（`ownerId`=当前用户）。
- 错误码: 1001（参数错误，仅 JSON 解析失败）、500（创建失败）
- 备注: 所有字段无 `binding`，均为可选；`memberIds` 中解析失败的元素被忽略，不阻断；创建者默认已是成员（role=群主）。

---

### `GET /api/v1/conversation/:id/members`

- 鉴权: 需要Token
- 说明: 获取会话成员列表（含角色与好友备注）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `数组<ConvMemberInfo>`；顶层另含 `memberCount:int64`（真实成员总数，非分页）。ConvMemberInfo = 内联 `User` 字段（`id:string` `nickname:string` `avatar:string` `shortId:string|null` `role`全局角色等）+ `role:int(群内角色 1群主/2管理员/3普通)` `remark:string(好友备注)` `vipShortId:bool` `speakMutedUntil:int64(禁言截止时间戳秒,0=未禁言)`。
- 错误码: 4001（会话不存在或非成员）、500
- 备注: 成员隐私（`privacyEnabled=1`）开启时，普通成员**仅返回前 15 个**成员，`memberCount` 仍为真实总数；排序：群主→管理员→普通成员，同角色按进群时间。

---

### `PUT /api/v1/conversation/:id/pin-message`

- 鉴权: 需要Token
- 说明: 置顶 / 取消置顶消息（支持多条）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"msgId":"string(可选) // 消息ID","content":"string(可选) // 置顶卡片展示内容","pinned":"bool(可选) // true=置顶 false=取消；缺省按 msgId>0 置顶"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在或非成员）、500
- 备注: 所有成员可操作；`pinned` 缺省且 `msgId>0` 视为置顶，`msgId<=0` 或 `pinned=false` 视为取消；多条以 `pinnedMsgIds` 列表维护。

---

### `GET /api/v1/conversation/:id/pins`

- 鉴权: 需要Token
- 说明: 获取置顶消息列表（按置顶顺序）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `数组<PinnedMsgBrief>`：`msgId:string` `content:string` `senderName:string` `type:int` `createdAt:string`。
- 错误码: 4001（会话不存在或非成员）、500
- 备注: 非分页，返回全部置顶项。

---

### `PUT /api/v1/conversation/:id/announcement`

- 鉴权: 需要Token
- 说明: 更新群公告。**仅群主 / 管理员**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"announcementZh":"string(可选) // 公告中文","announcementEn":"string(可选) // 公告英文"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在或非成员）、1003（无权限，非群主/管理员）、500
- 备注: 空字符串字段不更新对应列；双语文案可单独更新。

---

### `POST /api/v1/conversation/:id/invite`

- 鉴权: 需要Token
- 说明: 邀请成员加入群。**群主/管理员可邀；普通成员仅当群开启「允许成员邀请」**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"memberIds":["string",...](可选) // 邀请成员ID字符串数组(雪花)"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在）、1003（普通成员且群未开启允许邀请）、500
- 备注: 解析失败的元素忽略；已是成员者不去重重复添加；会触发入群系统提示。

---

### `DELETE /api/v1/conversation/:id/members/:userId`

- 鉴权: 需要Token
- 说明: 移除群成员。**仅群主/管理员，且有层级约束**。
- 路径参数: `id:int64`、`userId:int64`（目标成员）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在）、1003（无权限：非群主/管理员、或试图移除群主、或管理员移除管理员、或移除自己）、500
- 备注: 不能移除自己（请走 quit）；不能移除群主；管理员只能移除普通成员；触发「被移出」系统提示。

---

### `POST /api/v1/conversation/:id/quit`

- 鉴权: 需要Token
- 说明: 退出群聊（成员本人）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 500（仅数据库错误）
- 备注: 无权限校验（任何成员可退）；若退出后群内无人则自动解散；触发「退出」系统提示。

---

### `POST /api/v1/conversation/:id/disband`

- 鉴权: 需要Token
- 说明: 解散群。**仅群主**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在）、1003（无权限，非群主）、500
- 备注: 群 `status` 置为解散并删除全部成员关系；不可恢复。

---

### `PUT /api/v1/conversation/:id`

- 鉴权: 需要Token
- 说明: 更新群信息（群名/公告/头像）。**仅群主/管理员**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"nameZh":"string(可选) // 群名中文","nameEn":"string(可选) // 群名英文","announcementZh":"string(可选) // 公告中文","announcementEn":"string(可选) // 公告英文","avatar":"string(可选) // 群头像URL(先调/upload获取)"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在或非成员）、1003（无权限，非群主/管理员）、500
- 备注: 空字符串字段不更新对应列；头像需先经上传接口得到 URL。

---

### `PUT /api/v1/conversation/:id/pin`

- 鉴权: 需要Token
- 说明: 个人置顶 / 取消置顶会话（仅影响本人）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"pinned":"bool(可选，默认false) // 是否置顶"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 500（仅数据库错误）
- 备注: 写入 `conversation_member.pinned`（个人维度）；非群级设置。

---

### `PUT /api/v1/conversation/:id/mute`

- 鉴权: 需要Token
- 说明: 个人会话免打扰开关（仅影响本人）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"mute":"bool(可选，默认false) // 是否免打扰"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 500（仅数据库错误）
- 备注: 写入 `conversation_member.mute`（个人维度，与全员禁言 `muteAll` 无关）。

---

### `GET /api/v1/conversation/:id/settings`

- 鉴权: 需要Token
- 说明: 读取群管理设置。**全体成员可读**（成员页依「允许邀请」决定入口）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `object(GroupSettings)`：`muteAll:bool` `privacyEnabled:bool` `allowMemberInvite:bool` `qrJoinEnabled:bool`。
- 错误码: 4001（会话不存在或非成员）、500
- 备注: `bool` 由库表 `int(0/1)` 转换而来。

---

### `PUT /api/v1/conversation/:id/settings`

- 鉴权: 需要Token
- 说明: 更新群管理设置。**仅群主**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"muteAll":"bool(可选) // 全员禁言","privacyEnabled":"bool(可选) // 成员隐私","allowMemberInvite":"bool(可选) // 允许成员邀请","qrJoinEnabled":"bool(可选) // 二维码进群"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在）、1003（无权限，非群主）、500
- 备注: **指针语义**：字段为 `*bool`，未传（null）的开关保持原值（先读旧值再覆盖）；全员禁言状态变化会触发系统提示。

---

### `PUT /api/v1/conversation/:id/admin`

- 鉴权: 需要Token
- 说明: 设置 / 取消管理员。**仅群主**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"userId":"string(必填) // 目标成员ID(雪花)","admin":"bool(可选，默认false) // true=设为管理员 false=取消"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（目标非成员）、1003（无权限：非群主 / 不能操作自己 / 不能操作群主）、500
- 备注: 目标须为普通成员或管理员（群主不可被改）；取消即降为普通成员。

---

### `PUT /api/v1/conversation/:id/mute-member`

- 鉴权: 需要Token
- 说明: 禁言 / 解除禁言成员。**群主/管理员**。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体:
  ```json
  {"userId":"string(必填) // 目标成员ID(雪花)","mute":"bool(可选，默认false) // true=禁言 false=解除","minutes":"int(可选) // 禁言时长(分钟)，mute=false时忽略"}
  ```
- 成功响应 data: 无（仅 `code:0`）
- 错误码: 4001（会话不存在或非成员）、1003（无权限：非群主/管理员、不能禁言群主、管理员不能禁言管理员、不能禁言自己）、500
- 备注: `minutes<=0` 默认 10，`>43200`(30天) 截断为 43200；`mute=false` 解除（忽略分钟）；写入 `speakMutedUntil`（unix 秒，0=未禁言）。

---

### `POST /api/v1/conversation/:id/join`

- 鉴权: 需要Token
- 说明: 扫码二维码进群（需群开启「二维码进群」）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `object(Conversation)`（加入后的会话；已成员则直接返回，不重复添加）。
- 错误码: 4001（会话不存在 / 非群）、1003（未开启二维码进群）、4002（群人数已达上限）、500
- 备注: 仅群 `qrJoinEnabled=1` 可加入；满员（`maxMembers`）拒绝；触发「加入」系统提示。

---

### `GET /api/v1/conversation/:id/preview`

- 鉴权: 需要Token（由 `user` 组中间件统一校验；handler 本身不读取 uid）
- 说明: 扫码进群前的群信息预览（二次确认页：群名/头像/成员数）。
- 路径参数: `id:int64`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `{"conversation":object(Conversation),"memberCount":int64}`。
- 错误码: 4001（会话不存在 / 非群）、500
- 备注: 不要求是当前群成员；仅群（`type=2`）可预览。

---

> 统一响应包：`{"code":0,"message":"ok","data":{...}}`，HTTP 200。所有接口位于 `user` 子组，需 `Authorization: Bearer <token>`（middleware.Auth）。>   
> 消息类型枚举 `type`：1 文本 / 2 图片 / 3 文件 / 4 语音 / 5 视频 / 6 系统 / 7 音视频通话 / 8 红包 / 9 转账。>   
> 注意：所有 `conversationId`、`msgId`、`senderId` 等在 JSON 中以**字符串形式的雪花 ID** 返回（`json:"...,string"`），避免 JS 精度丢失。时间字段为 RFC3339 字符串。

### `POST /api/v1/message/send`

- 鉴权: 需要Token
- 说明: 发送一条消息（幂等落库 + 未读计数 + Redis 广播推送），红包/转账会先冻结资金。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "conversationId": "string(必填) // 会话ID，雪花ID字符串",
    "clientMsgId": "string(可选) // 客户端幂等UUID，不传则服务端生成（重试去重）",
    "type": "int(可选) // 消息类型，默认1文本",
    "content": "string(必填) // 消息内容/文件JSON/红包JSON等",
    "file": "object(可选) // 文件元信息 map",
    "mention": "array<int64>(可选) // @成员列表（雪花ID）",
    "replyTo": "string(可选) // 引用消息的msgId，雪花ID字符串"
  }
  ```
- 成功响应 data: `消息对象 model.Message`（见备注字段表）
- 错误码: 1001 参数错误 / 4001 会话不存在或非成员 / 4004 群全员禁言 / 4005 已被禁言 / 500 其他错误
- 备注: 返回消息对象包含 `msgId`(雪花ID)、`seq`(会话内单调递增序号)、`clientMsgId`(幂等ID)；引用消息时返回 `replySnapshot`(content/senderName/senderId/type)。幂等：同一 sender+clientMsgId 重复提交直接返回原消息。群聊按 `memberRole` 校验禁言。

### `GET /api/v1/message/history`

- 鉴权: 需要Token
- 说明: 拉取某会话历史消息（游标分页：beforeMsgId 之前 limit 条，按时间正序）。
- 路径参数: 无
- 查询参数: `convId:string(必填,雪花ID)`, `beforeMsgId:string(可选,雪花ID,不传则最新)`, `limit:int(可选,默认50,<=100)`
- 请求体: 无
- 成功响应 data: `[消息对象,...]`（数组；分页靠 beforeMsgId+limit 游标，无 total）
- 错误码: 4001 会话不存在或非成员 / 500 其他错误
- 备注: 单聊时服务端为「我发出」且对方已读的消息填充 `deliveryState:"read"`，否则 `"sent"`。被后台屏蔽(`blocked`)的消息不下发。limit 越界自动收敛为 50。

### `GET /api/v1/message/sync`

- 鉴权: 需要Token
- 说明: 增量补拉（重连补偿/上线拉取）：拉取 `seq > afterSeq` 的消息，按 seq 升序。
- 路径参数: 无
- 查询参数: `convId:string(必填,雪花ID)`, `afterSeq:int(可选,不传则从头)`, `limit:int(可选,默认100,<=200)`
- 请求体: 无
- 成功响应 data: `[消息对象,...]`（数组；分页靠 afterSeq+limit 游标，无 total）
- 错误码: 4001 会话不存在或非成员 / 500 其他错误
- 备注: `afterSeq` 为上次断点 seq（见 `GET .../conversations` 等返回的会话最新 seq），用于重连补偿。被屏蔽消息不下发。limit 越界自动收敛为 100。

### `GET /api/v1/message/search`

- 鉴权: 需要Token
- 说明: 关键词搜索自己参与会话内的消息（分页）。
- 路径参数: 无
- 查询参数: `kw:string(必填)`, `convId:string(可选,雪花ID,限定会话)`, `page:int(可选,默认1)`, `size:int(可选,默认20,<=100)`
- 请求体: 无
- 成功响应 data: `{"list":[消息对象,...],"total":int64}`（分页：list/total，按 msgId 倒序）
- 错误码: 1001 请输入搜索关键词 / 4001 会话不存在或非成员 / 500 其他错误
- 备注: 仅搜索当前用户参与的会话；空 kw 返回 1001。被屏蔽消息不出现。size 越界收敛为 20，page 默认 1。

### `POST /api/v1/message/:id/recall`

- 鉴权: 需要Token
- 说明: 撤回一条消息（本人 2 分钟内；群主/管理员不限时撤群成员消息）。
- 路径参数: `id:string(必填,雪花ID,目标消息 msgId)`
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 4003 消息不存在 / 4003 撤回超时或无权限 / 500 其他错误（如更新失败）
- 备注: 路径 `:id` 为 msgId 雪花字符串。成功后广播 `recall` 事件（携带 conversationId/msgId/recalledBy），消息标记 `recalled=true,status=2`。

### `POST /api/v1/message/read`

- 鉴权: 需要Token
- 说明: 上报已读（更新已读位点 + 清未读 + 写回执 + 广播 read 事件）。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "conversationId": "string(必填) // 会话ID，雪花ID字符串",
    "msgId": "string(可选) // 已读到的消息msgId，雪花ID字符串；>0 才写群已读回执"
  }
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1001 参数错误 / 4001 会话不存在或非成员 / 500 其他错误
- 备注: `conversationId` 缺失或解析为 0 返回 1001。群聊且 `msgId>0` 时写入按人回执（`message_receipt`），用于「已读成员列表」展示。

### `GET /api/v1/message/receipts`

- 鉴权: 需要Token
- 说明: 获取某条消息的已读成员回执列表（群聊按人展示）。
- 路径参数: 无
- 查询参数: `convId:string(必填,雪花ID)`, `msgId:string(必填,雪花ID)`
- 请求体: 无
- 成功响应 data: `[回执对象,...]`（数组，空时为 `[]`）
- 错误码: 4001 会话不存在或非成员 / 500 其他错误
- 备注: 回执对象 `model.MessageReceipt` 字段：`conversationId`(string雪花ID)、`msgId`(string雪花ID)、`userId`(string雪花ID)、`readAt`(time)。未读成员不在列表中。

### `POST /api/v1/message/favorite`

- 鉴权: 需要Token
- 说明: 收藏一条消息。
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {
    "conversationId": "string(必填) // 会话ID，雪花ID字符串",
    "msgId": "string(必填) // 消息msgId，雪花ID字符串"
  }
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1001 参数错误 / 500 收藏失败
- 备注: 写入 `message_favorite`（user_id/conversation_id/msg_id）。同一消息重复收藏会插入多条（无唯一约束去重）。


### `GET /api/v1/message/favorites`

- 鉴权: 需要Token
- 说明: 获取我的收藏消息列表（按收藏时间倒序）。
- 路径参数: 无
- 查询参数: `limit:int(可选,默认50,<=100)`
- 请求体: 无
- 成功响应 data: `[消息对象,...]`（数组；游标 limit 截断，无 total）
- 错误码: 500 获取失败
- 备注: 先查 `message_favorite`（user_id 匹配），再按 msgId 回查消息组装。limit 越界收敛为 50。被删除的消息不会出现在结果中（msg 查不到则跳过）。

---

**消息对象（model.Message）JSON 字段表**（send/history/sync/search/favorites 返回的元素）：

| 字段             | 类型                | 说明                                     |
| -------------- | ----------------- | -------------------------------------- |
| conversationId | string(雪花ID)      | 会话ID                                   |
| msgId          | string(雪花ID)      | 消息全局ID                                 |
| clientMsgId    | string            | 客户端幂等ID(UUID)                          |
| seq            | int               | 会话内单调递增序号（补拉游标）                        |
| senderId       | string(雪花ID)      | 发送者ID                                  |
| type           | int               | 消息类型(1~9)                              |
| content        | string            | 内容（文本/文件JSON/红包JSON等）                  |
| file           | object(opt)       | 文件元信息                                  |
| mention        | array<int64>(opt) | @成员                                    |
| replyTo        | string(opt,雪花ID)  | 引用消息ID                                 |
| replySnapshot  | object(opt)       | 引用快照{content,senderName,senderId,type} |
| recalled       | bool              | 是否已撤回                                  |
| recalledBy     | string(opt,雪花ID)  | 撤回操作者                                  |
| status         | int               | 状态 1正常/2已撤回                            |
| deliveryState  | string(opt)       | 仅单聊历史填充："read"/"sent"                  |
| encrypted      | bool              | 是否端到端加密                                |
| blocked        | bool              | 是否被后台屏蔽                                |
| createdAt      | time              | 创建时间(RFC3339)                          |

---

> 统一响应信封：`{"code":0,"message":"ok","data":{...}}`，HTTP 200；`code!=0` 为业务错误。>   
> 以下接口均在 `/api/v1` 下、位于 `user` 子组、需 `Authorization: Bearer <token>`（middleware.Auth）。>   
> 通用分页查询参数：`page`(int, 默认1)、`size`(int, 默认20)。>   
> 金额安全：转账收款(`/wallet/transfer/:msgId/accept`)与红包领取(`/wallet/redpacket/:msgId/claim`)的金额**一律以服务端按消息内容核算**，不接受客户端上报金额；入账类记账(`red_in`/`tr_in`)接口已停用，防自助充值。旧 `/wallet/record` 仅对出账类(`red_out`/`tr_out`)做幂等 no-op。

---

### `GET /api/v1/wallet/me`

- 鉴权: 需要Token
- 说明: 查我的钱包余额、冻结额及最近 100 条流水。
- 请求体: 无
- 成功响应 data: `{"balance":float64 // 可用余额, "frozen":float64 // 冻结金额(已发出未领取的红包/转账), "records":[WalletTransaction] // 最近100条,倒序}`
- 错误码: 1001
- 备注: `records` 元素字段见 `GET /wallet/records` 的 `list` 项。

---

### `POST /api/v1/wallet/record`

- 鉴权: 需要Token
- 说明: 旧记账接口（已废弃 B-21）；入账类拒绝，出账类幂等 no-op 直接返回当前余额，不再重复扣款。
- 请求体:
  ```json
  {"type":"string(必填) // red_out/tr_out 才处理; 传入 red_in/tr_in 或其它值返回1001", "amount":"float64(可选) // 客户端上报,服务端忽略", "refId":"string(可选) // 幂等键"}
  ```
- 成功响应 data: `{"balance":float64 // 当前可用余额}`
- 错误码: 1001
- 备注: 该接口不再修改余额，仅作兼容；真实收款走 `/wallet/transfer/:msgId/accept` 与 `/wallet/redpacket/:msgId/claim`。同 `refId` 已记过账则直接返回余额（防老客户端二次扣款）。

---

### `POST /api/v1/wallet/transfer/:msgId/accept`

- 鉴权: 需要Token
- 说明: 转账收款（金额服务端按消息内容核算 + 会话成员校验 + 唯一索引幂等）。
- 路径参数: `msgId:string`
- 请求体: 无
- 成功响应 data: `{"msgId":"string", "amount":float64 // 本次到账金额(服务端核算), "balance":float64 // 收款后可用余额, "already":bool // 是否重复领取(幂等命中)}`
- 错误码: 1001(参数/非转账/已撤回), 4201(转账不存在或已过期/已撤回), 4202(已被领取), 4203(已被他人领取), 4204(已领取过), 4205(不能领自己发的/无权领取), 4207(超过24h未领已退回)
- 备注: **金额以服务端为准**——只从 mongo 转账消息 `content.amount` 读取，不信任客户端。领取人须为会话成员且非发送者；`transfer_claim` 表 `msg_id` 唯一索引保证并发只成功一次；资金从发送方冻结额结算。

---

### `POST /api/v1/wallet/redpacket/:msgId/claim`

- 鉴权: 需要Token
- 说明: 领取红包（结算发送方冻结资金 + 写领取记录，返回本次金额与领取列表）。
- 路径参数: `msgId:string`
- 请求体: 无
- 成功响应 data: `{"msgId":"string", "senderId":"string", "senderName":"string", "senderAvatar":"string", "note":"string", "mode":"string // lucky/normal", "totalAmount":float64, "count":int, "claimedCnt":int, "claimedSum":float64, "status":int // 1进行中 2已领完 3已过期退回 4已关闭, "expireAt":"string // 2006-01-02 15:04:05", "list":[RedPacketClaim], "myAmount":float64 // 本次领取金额}`
- 错误码: 4201(红包不存在/非红包), 4202(已领完), 4204(已领取过), 4206(旧版本数据停止领取), 4207(超过24h未领完已退回)
- 备注: **金额以服务端为准**——`lucky` 拼手气按剩余金额/剩余人数随机、`normal` 取消息内单个金额；同 `msg_id+user_id` 不能重复领；钱从发送方冻结额结算，无冻结记录拒绝。

---

### `GET /api/v1/wallet/redpacket/:msgId`

- 鉴权: 需要Token
- 说明: 红包详情（不含本人本次金额）。
- 路径参数: `msgId:string`
- 请求体: 无
- 成功响应 data: `{"msgId":"string", "senderId":"string", "senderName":"string", "senderAvatar":"string", "note":"string", "mode":"string", "totalAmount":float64, "count":int, "claimedCnt":int, "claimedSum":float64, "status":int // 1进行中 2已领完 3已过期退回 4已关闭, "expireAt":"string", "list":[RedPacketClaim]}`
- 错误码: 4201
- 备注: `list` 每项 `{"userId":"string","userName":"string","avatar":"string","amount":float64,"seq":int,"createdAt":"string // 2006-01-02 15:04"}`。

---

### `GET /api/v1/wallet/records`

- 鉴权: 需要Token
- 说明: 账单流水（按时间筛选 + 分页）。
- 查询参数: `page:int(可选,默认1)`, `size:int(可选,默认20)`, `start:string(可选,格式 2006-01-02)`, `end:string(可选,格式 2006-01-02)`
- 请求体: 无
- 成功响应 data: `{"total":int // 命中总数, "list":[WalletTransaction序列化]}`
- 错误码: 500
- 备注: `list` 每项 `{"id":"string","userId":"string","userName":"string","type":"string","typeName":"string // 中文类型名","amount":float64,"frozenDelta":float64,"balance":float64,"frozen":float64,"title":"string","remark":"string","operatorId":"string","createdAt":"string // 2006-01-02 15:04:05"}`。

---

### `GET /api/v1/pay/config`

- 鉴权: 需要Token
- 说明: 获取充值/提现通道配置（收款码、提示、提现限额与费率）。
- 请求体: 无
- 成功响应 data: `{"enabled":bool, "receiveWechatQrcodeUrl":"string", "receiveAlipayQrcodeUrl":"string", "receiveBankQrcodeUrl":"string", "receiveBankInfo":{"bankName":"string","cardNo":"string","accountName":"string"}, "rechargeTips":"string", "withdrawEnabled":bool, "withdrawMin":float64, "withdrawMax":float64, "withdrawFeeRate":float64 // 0~0.1, "withdrawFeeMin":float64}`
- 错误码: 无（取不到返回默认值）
- 备注: `payMethod`/`withdrawType` 取值 1微信 2支付宝 3银行卡。

---

### `POST /api/v1/wallet/recharge/submit`

- 鉴权: 需要Token
- 说明: 提交充值订单（上传支付凭证，待后台审核）。
- 请求体:
  ```json
  {"amount":"float64(必填) // 充值金额>0", "payMethod":"int(必填) // 1微信 2支付宝 3银行卡", "proofImage":"string(必填) // 支付凭证截图URL", "payTxNo":"string(可选)", "remark":"string(可选)"}
  ```
- 成功响应 data: `{"id":int64, "status":int // 1待审核, "tips":"string // 充值提示语}`
- 错误码: 1001(通道未启用/金额非法/方式不支持/缺凭证/重复订单命中)
- 备注: 600s 内同用户+同金额+同凭证+同方式若已有 pending 订单则直接返回该订单（幂等）。下单时快照当前收款码 URL。

---

### `GET /api/v1/wallet/recharge/orders`

- 鉴权: 需要Token
- 说明: 我的充值订单列表（分页）。
- 查询参数: `page:int(可选,默认1)`, `size:int(可选,默认20)`
- 请求体: 无
- 成功响应 data: `{"list":[RechargeOrder], "total":int}`
- 错误码: 1001
- 备注: `RechargeOrder` 字段 `{"id":"string","userId":"string","amount":float64,"payMethod":int,"receiveQrcodeUrl":"string","proofImage":"string","payTxNo":"string","status":int // 1待审 2通过 3拒绝,"rejectReason":"string","reviewerId":"string","reviewedAt":"string|null","remark":"string","createdAt":"string"}`。

---

### `GET /api/v1/wallet/withdraw-account`

- 鉴权: 需要Token
- 说明: 获取我的提现收款账户绑定（未绑定返回空对象）。
- 请求体: 无
- 成功响应 data: `WithdrawAccount` —— `{"id":"string","userId":"string","accountType":int // 1微信 2支付宝 3银行卡,"wechatQrcodeUrl":"string","wechatName":"string","alipayQrcodeUrl":"string","alipayAccount":"string","alipayName":"string","bankCardNo":"string","bankName":"string","bankAccountName":"string","updatedAt":"string","createdAt":"string"}`
- 错误码: 1001
- 备注: 未绑定时各字段为空/零值，前端据此渲染默认表单。

---

### `PUT /api/v1/wallet/withdraw-account`

- 鉴权: 需要Token
- 说明: 绑定/更新我的提现收款账户（按 `accountType` 校验必填项，其余类型字段清空）。
- 请求体: `WithdrawAccount`（同 GET 响应结构；至少 `accountType` 必填）
  ```json
  {"accountType":"int(必填) // 1/2/3", "wechatQrcodeUrl":"string(可选)","wechatName":"string(可选)","alipayQrcodeUrl":"string(可选)","alipayAccount":"string(可选)","alipayName":"string(可选)","bankCardNo":"string(可选)","bankName":"string(可选)","bankAccountName":"string(可选)"}
  ```
- 成功响应 data: 无（仅 `{"code":0,"message":"ok"}`）
- 错误码: 1001(方式不支持/对应类型必填项缺失)
- 备注: 微信需 `wechatName`；支付宝需 `alipayAccount`+`alipayName`；银行卡需 `bankCardNo`+`bankName`+`bankAccountName`。按 `user_id` 唯一索引 upsert。

---

### `POST /api/v1/wallet/withdraw/submit`

- 鉴权: 需要Token
- 说明: 提交提现申请（可用余额→冻结，写提现订单待审核）。
- 请求体:
  ```json
  {"amount":"float64(必填) // 提现金额,需满足 min/max", "withdrawType":"int(必填) // 1微信 2支付宝 3银行卡,须与已绑定账户一致"}
  ```
- 成功响应 data: `{"id":int64, "amount":float64 // 申请金额, "fee":float64 // 手续费, "actualAmount":float64 // 实际到账=amount-fee, "status":int // 1待审核}`
- 错误码: 1001(未开启提现/低于最低/高于最高/方式不支持/未绑定或未完善对应账户)
- 备注: 手续费 `fee = max(amount*withdrawFeeRate, withdrawFeeMin)`；提交时原子建单+冻结（`balance-amount, frozen+amount`）；未绑定对应 `withdrawType` 账户将被拒。

---

### `GET /api/v1/wallet/withdraw/orders`

- 鉴权: 需要Token
- 说明: 我的提现订单列表（分页）。
- 查询参数: `page:int(可选,默认1)`, `size:int(可选,默认20)`
- 请求体: 无
- 成功响应 data: `{"list":[WithdrawOrder], "total":int}`
- 错误码: 1001
- 备注: `WithdrawOrder` 字段 `{"id":"string","userId":"string","amount":float64,"fee":float64,"actualAmount":float64,"withdrawType":int,"accountSnapshot":map // 脱敏账户快照,"status":int // 1待审 2通过 3拒绝,"rejectReason":"string","reviewerId":"string","reviewedAt":"string|null","remark":"string","createdAt":"string"}`。

---

### `GET /api/v1/moments`

- 鉴权: 需要Token
- 说明: 朋友圈时间线（含自己全部、小助手公开、好友公开动态，分页）。
- 查询参数: `page:int(可选,默认1)`, `size:int(可选,默认20,上限50)`
- 请求体: 无
- 成功响应 data: `{"total":int, "list":[Moment]}`
- 错误码: 1001
- 备注: `Moment` 每项 `{"id":"string","userId":"string","senderName":"string","senderAvatar":"string","assistant":bool // 是否小助手(uid=-1),"content":"string","images":[string],"likeCount":int,"liked":bool // 当前用户是否已赞,"hidden":bool // 是否被屏蔽(仅自己可见),"mine":bool,"createdAt":"string // 2006-01-02 15:04"}`。

---

### `GET /api/v1/moments/:ownerId`

- 鉴权: 需要Token
- 说明: 查看指定用户的朋友圈（他人仅见非屏蔽动态，分页）。
- 路径参数: `ownerId:string`
- 查询参数: `page:int(可选,默认1)`, `size:int(可选,默认20,上限50)`
- 请求体: 无
- 成功响应 data: `{"total":int, "list":[Moment]}`
- 错误码: 1001
- 备注: `Moment` 结构同 `GET /moments`。`ownerId` 非数字返回 1001。

---

### `POST /api/v1/moments`

- 鉴权: 需要Token
- 说明: 发布一条朋友圈动态。
- 请求体:
  ```json
  {"content":"string(可选) // 正文","images":"[]string(可选) // 图片URL数组；content 与 images 至少一项非空"}
  ```
- 成功响应 data: `MomentsPost` —— `{"id":"string","userId":"string","content":"string","images":"string // JSON数组原文","likes":"string // JSON数组原文","hidden":bool,"createdAt":"string","updatedAt":"string"}`
- 错误码: 1001(内容为空)
- 备注: 发布后 `likes="[]"`。返回 `images`/`likes` 为数据库存储的原始 JSON 字符串。

---

### `POST /api/v1/moments/:id/like`

- 鉴权: 需要Token
- 说明: 点赞/取消点赞（toggle），返回切换后状态。
- 路径参数: `id:string`
- 请求体: 无
- 成功响应 data: `{"liked":bool // true=已赞, false=已取消}`
- 错误码: 1001(动态不存在)
- 备注: 重复调用在已赞/未赞间切换；`id` 非数字或动态不存在返回 1001。

---

> 通用说明：所有接口前缀 `/api/v1/admin`，均经 `middleware.Auth` + `middleware.RequireAdmin`，即**需 Bearer Token 且当前用户具备管理员角色**。>   
> 响应统一信封：`{"code":0,"message":"ok","data":{...}}`，`code=0` 成功。错误时 `code` 为 `1001`（参数错误）、`500`（服务错误）或业务错误码（由 `errCode(err)` 映射，如账号已存在等），`message` 为可读信息。

---

### `GET /api/v1/admin/users`

- 鉴权: 需管理员
- 说明: 用户列表，支持关键字/状态/部门筛选与分页。
- 查询参数: `kw:string`（账号/昵称/靓号/手机/邮箱模糊）、`status:int`（1 正常 2 禁用，0/缺省=全部）、`dept:int64`（部门 ID，0=全部）、`page:int`（默认 1）、`size:int`（默认 20，最大 100）
- 请求体: 无
- 成功响应 data: `{"list":User[], "total":int64}`（User 见 `model.User`：`id,string` `account` `nickname` `avatar` `phone` `email` `shortId` `balance` `frozen` `departmentId,string` `status` `role` `createdAt` `updatedAt` 等；密码字段不外发）
- 错误码: 500（查询失败）
- 备注: 分页由 `page/size` 控制，`total` 为总数。

### `POST /api/v1/admin/users`

- 鉴权: 需管理员
- 说明: 后台新建账号。
- 请求体:
  ```json
  {"account":"string(必填) // 登录账号", "password":"string(必填) // 明文密码，服务端 bcrypt", "nickname":"string(可选)", "departmentId":"int64(可选)", "role":"int(可选) // 默认普通用户 1"}
  ```
- 成功响应 data: `User`（新建用户对象，`passwordHash` 不外发）
- 错误码: 1001（参数错误）、业务码（账号已存在等，由 `errCode(err)` 映射）
- 备注: 成功后写管理员操作日志 `user.create`。

### `PUT /api/v1/admin/users/:id/status`

- 鉴权: 需管理员
- 说明: 启用/禁用用户。
- 路径参数: `id:int64`
- 请求体:
  ```json
  {"status":"int(可选 默认0) // 1 正常 2 禁用"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 无显式错误码（写库失败仅记日志；`id` 解析失败静默忽略）
- 备注: 写日志 `user.status`。
- 禁用立即生效（关键）：当 `status=2`（禁用）时，除更新库外服务端还会做两件事，确保禁用"立刻踢人"而不是等 token 自然过期：
  1. 删除该用户的 refresh 白名单（`refresh:{uid}`），使其 access token 过期后无法用 refresh 续命，刷新即失败 → 客户端 401 清登录态；
  2. 通过 Redis 事件总线向该用户所有在线设备推送 `forceLogout` WebSocket 事件，客户端收到即清本地登录态并跳登录页（见下方「强制下线事件」）。
- 此外鉴权中间件对每次请求复核账号状态，禁用账号的 access token 在下次任意请求即被 401 拦截；新登录 / 刷新也已被 `Login` / `Refresh` 拒绝（两者都校验 `u.Status != StatusNormal`）。

### 强制下线（WebSocket 事件）`forceLogout`

- 触发：后台 `PUT /admin/users/:id/status` 将账号置为禁用时，服务端经 Redis 事件总线下发。
- 帧格式（网关透传，客户端 WS 收到）：
  ```json
  {"type":"forceLogout","data":{"reason":"account_disabled"}}
  ```
- 客户端行为（三端一致）：收到后立即清本地登录态（access/refresh + 用户缓存）、关闭 WS 长连接、跳转到登录页。该事件与"群成员被踢（`kick`，属群系统消息）"无关，仅用于账号级强制下线。

### `PUT /api/v1/admin/users/:id/password`

- 鉴权: 需管理员
- 说明: 重置用户密码。
- 路径参数: `id:int64`
- 请求体:
  ```json
  {"password":"string(必填) // 新明文密码，服务端 bcrypt"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（参数错误）
- 备注: 写日志 `user.password`。

### `GET /api/v1/admin/configs/:key`

- 鉴权: 需管理员
- 说明: 读取单条系统配置（`sys_config` 表）。
- 路径参数: `key:string`（配置键，如 `auth_flags` `assistant_config` `pay_config`）
- 成功响应 data: 该配置的值（任意 JSON：对象/字符串/数字/scalar，取决于存储内容；缺省键返回 `null`）
- 错误码: 无（读不到返回 `null`）
- 备注: 值以 `{value:...}` 解包后返回其 `value` 字段；若整体为对象且无 `value` 则原样返回。

### `PUT /api/v1/admin/configs/:key`

- 鉴权: 需管理员
- 说明: 写入/新建系统配置（存为 `{"value": <body.value>}`）。
- 路径参数: `key:string`
- 请求体:
  ```json
  {"value":"any(可选) // 任意 JSON，作为该键的值"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 500（保存失败，含错误详情）
- 备注: 写库失败**必须**返回错误（注释明确：不可静默吞错）；写日志 `config.set`。

### `GET /api/v1/admin/app-entries`

- 鉴权: 需管理员
- 说明: 小程序（H5 容器）列表。
- 请求体: 无
- 成功响应 data: `AppEntry[]`（`id,string` `nameZh` `nameEn` `icon` `url` `category` `sort` `enabled` `createdAt`）
- 错误码: 500（查询失败）
- 备注: 无分页，全量返回。

### `POST /api/v1/admin/app-entries`

- 鉴权: 需管理员
- 说明: 新建小程序入口。
- 请求体:
  ```json
  {"nameZh":"string(可选)", "nameEn":"string(可选)", "icon":"string(可选)", "url":"string(可选)", "category":"string(可选)", "sort":"int(可选)", "enabled":"bool(可选)"}
  ```
- 成功响应 data: `AppEntry`（新建对象）
- 错误码: 500（创建失败）
- 备注: 写日志 `app.create`。

### `PUT /api/v1/admin/app-entries/:id`

- 鉴权: 需管理员
- 说明: 更新小程序入口。
- 路径参数: `id:int64`
- 请求体:
  ```json
  {"nameZh":"string(可选)", "nameEn":"string(可选)", "icon":"string(可选)", "url":"string(可选)", "category":"string(可选)", "sort":"int(可选)", "enabled":"bool(可选)"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 无（写库失败仅记日志）
- 备注: 写日志 `app.update`。

### `DELETE /api/v1/admin/app-entries/:id`

- 鉴权: 需管理员
- 说明: 删除小程序入口。
- 路径参数: `id:int64`
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 无（删除失败仅记日志）
- 备注: 写日志 `app.delete`。

### `GET /api/v1/admin/assistant/config`

- 鉴权: 需管理员
- 说明: 读取智能小助手配置。
- 成功响应 data: `AssistantConfig`（`enabled:bool` `name:string` `avatar:string` `autoAdd:bool` `welcomeText:string`）；取不到返回默认配置
- 错误码: 无
- 备注: 默认 `enabled=false`、`name="小助手"`。

### `POST /api/v1/admin/assistant/config`

- 鉴权: 需管理员
- 说明: 保存智能小助手配置。
- 请求体:
  ```json
  {"enabled":"bool // 是否启用", "name":"string // 助手昵称", "avatar":"string // 头像URL", "autoAdd":"bool // 新注册自动添加", "welcomeText":"string // 欢迎语"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 500（保存失败）
- 备注: 写日志 `assistant.config`。

### `GET /api/v1/admin/assistant/conversations`

- 鉴权: 需管理员
- 说明: 小助手与用户会话列表（含最后一条消息）。
- 成功响应 data: `AssistantConvItem[]`（`userId:string` `nickname:string` `account:string` `avatar:string` `lastMessage:Message|null`）
- 错误码: 业务码（由 `errCode(err)` 映射）
- 备注: `userId` 为字符串（防止前端精度丢失）。

### `GET /api/v1/admin/assistant/messages`

- 鉴权: 需管理员
- 说明: 某用户与小助手的会话消息（按时间正序，支持游标翻页）。
- 查询参数: `userId:int64`（目标用户）、`beforeMsgId:int64`（向前翻页游标，0=最新）、`limit:int64`（默认 50，范围 1~100）
- 成功响应 data: `Message[]`（字段见 `model.Message`：`conversationId,string` `msgId,string` `senderId,string` `type` `content` `file` `createdAt` `recalled` 等）
- 错误码: 1001（userId 无效）、业务码（`errCode(err)`）
- 备注: `beforeMsgId>0` 时向前翻页。

### `POST /api/v1/admin/assistant/push`

- 鉴权: 需管理员
- 说明: 以助手身份向一个或多个用户推送消息（文字/图片）。
- 请求体:
  ```json
  {"userId":"int64(可选) // 单选目标用户", "userIds":"[]string(可选) // 多选/全选；字符串防精度丢失", "content":"string(可选) // 文字内容", "fileUrl":"string(可选) // 图片URL，非空则发图片"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（未选目标用户）、业务码（`errCode(err)`：如小助手未启用 500、用户无效 1001）
- 备注: `userId` 与 `userIds` 二选一，均空返回 `1001`；写日志 `assistant.push`。

### `POST /api/v1/admin/wallet/adjust`

- 鉴权: 需管理员
- 说明: 手工调整用户余额（加款/扣款），写 `adjust` 流水并实时推送。
- 请求体:
  ```json
  {"userId":"string(必填) // 目标用户ID，字符串防精度丢失", "delta":"float64(必填 非零) // 正=加款 负=扣款", "reason":"string(可选) // 调整原因"}
  ```
- 成功响应 data: `{"balance":float64 // 调整后余额}`
- 错误码: 1001（参数错误：uid≤0 或 delta=0）、业务码（`errCode(err)`：如余额不足）
- 备注: `delta=0` 或非数字 uid 返回 1001；调整后调 `PublishWalletUpdate` 实时推送给在线客户端；写日志 `wallet.adjust`。

### `GET /api/v1/admin/users/:id/wallet`

- 鉴权: 需管理员
- 说明: 查询指定用户的真实钱包（余额+冻结）。
- 路径参数: `id:int64`
- 成功响应 data: `{"userId":int64, "balance":float64, "frozen":float64}`
- 错误码: 1001（id≤0）、业务码（`errCode(err)`）
- 备注: 与用户表 `balance/frozen` 字段一致，是后台权威数据源。

### `POST /api/v1/admin/users/:id/recharge`

- 鉴权: 需管理员
- 说明: 用户管理页充值/扣款（统一入口，原子入账+实时推送）。
- 路径参数: `id:int64`
- 请求体:
  ```json
  {"amount":"float64(必填 非零) // 正=充值 负=扣款", "remark":"string(可选) // 备注"}
  ```
- 成功响应 data: `{"balance":float64 // 变动后余额}`
- 错误码: 1001（参数错误：uid≤0 或 amount=0）、业务码（`errCode(err)`：扣款余额不足返回 4101 等）
- 备注: `amount>0` 记 `recharge` 流水、`<0` 记 `adjust` 流水；实时推送余额；写日志 `wallet.recharge`/`wallet.deduct`。

### `GET /api/v1/admin/finances`

- 鉴权: 需管理员
- 说明: 财务记录（读 `wallet_transaction`，仅含 `amount≠0` 的流水）。
- 查询参数: `kw:string`（账号/昵称/靓号/备注）、`side:string`（`IN`/`OUT`）、`type:string`（财务大类：`RECHARGE/WITHDRAW/TRANSFER/REDPACKET/REFUND/FREEZE/OTHER`），`from:int64` `to:int64`（毫秒时间戳区间）、`page:int`（默认 1）、`size:int`（默认 15，最大 100）
- 成功响应 data: `{"total":int64, "list":FinanceItem[]}`，每项为    
  `{"id":int64, "orderNo":string, "createdAt":string(RFC3339), "side":string, "type":string, "rawType":string, "status":int, "userId":int64, "userAccount":string, "userNickname":string, "userShortId":string, "amount":float64, "balanceAfter":float64, "frozenAfter":float64, "remark":string}`
- 错误码: 500（查询失败）
- 备注: 列表金额合计恒等于 Σ(user.balance)，与对账接口一致。

### `GET /api/v1/admin/wallet/transactions`

- 鉴权: 需管理员
- 说明: 钱包流水列表（按类型过滤，分页）。
- 查询参数: `type:string`（流水类型过滤：`recharge/withdraw/adjust/freeze/...`，空=全部）、`page:int`（默认 1）、`size:int`（默认 20，最大 100）
- 成功响应 data: `{"total":int64, "list":WalletTransaction[]}`（`WalletTransaction` 字段：`id,string` `userId,string` `type` `amount` `frozenDelta` `balance` `frozen` `title` `remark` `refId` `operatorId,string` `createdAt`）
- 错误码: 500（查询失败）
- 备注: 分页由 `page/size` 控制。

### `GET /api/v1/admin/wallet/reconcile`

- 鉴权: 需管理员
- 说明: 钱包三方对账（后台金额/用户余额/财务流水是否一致）。
- 成功响应 data: `{"balanceSum":float64, "frozenSum":float64, "txAmountSum":float64, "txFrozenSum":float64, "pendingSum":float64, "balanceDiff":float64, "frozenDiff":float64, "frozenVsPacket":float64, "mismatchUsers":[{id,string,account,nickname,balance,frozen,txAmount,txFrozen,amountGap,frozenGap}], "ok":bool, "checkedAt":string}`
- 错误码: 500（对账失败）
- 备注: `balanceDiff/frozenDiff/frozenVsPacket` 应≈0；非0见 `mismatchUsers`；`ok=true` 表示三方一致。

### `POST /api/v1/admin/wallet/refund-expired`

- 鉴权: 需管理员
- 说明: 手动触发一次到期红包/转账退回（兜底开关，正常由后台任务每分钟自动跑）。
- 请求体: 无
- 成功响应 data: `{"count":int // 本次退回的资金包数量}`
- 错误码: 500（执行失败）
- 备注: 固定退款上限 500 条；写日志 `wallet.refundExpired`。

### `GET /api/v1/admin/pay-config`

- 鉴权: 需管理员
- 说明: 读取支付配置（`sys_config.pay_config`）。
- 成功响应 data: `PayConfig`（`enabled:bool` `receiveWechatQrcodeUrl:string` `receiveAlipayQrcodeUrl:string` `receiveBankQrcodeUrl:string` `receiveBankInfo:{bankName,cardNo,accountName}` `rechargeTips:string` `withdrawEnabled:bool` `withdrawMin:float64` `withdrawMax:float64` `withdrawFeeRate:float64(0~0.1)` `withdrawFeeMin:float64`）；取不到返回默认值
- 错误码: 无
- 备注: 默认 `enabled=true`、`withdrawEnabled=true`、`withdrawMin=10`。

### `PUT /api/v1/admin/pay-config`

- 鉴权: 需管理员
- 说明: 保存支付配置（后端做范围校验，如手续费率 0~0.1）。
- 请求体:
  ```json
  {"enabled":"bool", "receiveWechatQrcodeUrl":"string", "receiveAlipayQrcodeUrl":"string", "receiveBankQrcodeUrl":"string", "receiveBankInfo":"{bankName,cardNo,accountName}", "rechargeTips":"string", "withdrawEnabled":"bool", "withdrawMin":"float64", "withdrawMax":"float64", "withdrawFeeRate":"float64", "withdrawFeeMin":"float64"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（JSON 解析失败）、业务码（`errCode(err)`：范围校验失败）
- 备注: 写日志 `pay.config.update`。

### `GET /api/v1/admin/recharge-orders`

- 鉴权: 需管理员
- 说明: 充值订单列表（分页）。
- 查询参数: `kw:string`、`status:int`（订单状态，0=全部）、`page:int`（默认 1）、`size:int`（默认 20）
- 成功响应 data: `{"list":RechargeOrder[], "total":int64}`（`RechargeOrder` 字段：`id,string` `userId,string` `amount` `payMethod` `receiveQrcodeUrl` `proofImage` `payTxNo` `status` `rejectReason` `reviewerId,string` `reviewedAt` `createdAt`）
- 错误码: 500（查询失败）
- 备注: 分页由 `page/size` 控制。

### `PUT /api/v1/admin/recharge-orders/:id/approve`

- 鉴权: 需管理员
- 说明: 审核通过充值订单（加余额+改状态，幂等；通过后小助手系统提醒）。
- 路径参数: `id:int64`
- 请求体: 无
- 成功响应 data: `{"orderId":int64, "userId":int64, "amount":float64, "balance":float64}`
- 错误码: 1001（id≤0 或订单已处理）、业务码（`errCode(err)`）
- 备注: 已审核订单幂等返回；写日志 `rechargeOrder.approve`；实时推送余额。

### `PUT /api/v1/admin/recharge-orders/:id/reject`

- 鉴权: 需管理员
- 说明: 驳回充值订单（不扣钱，置状态+原因）。
- 路径参数: `id:int64`
- 请求体:
  ```json
  {"reason":"string(可选) // 驳回原因"}
  ```
- 成功响应 data: 无（`{"code":0,"message":"ok"}`）
- 错误码: 1001（id≤0）、业务码（`errCode(err)`）
- 备注: 写日志 `rechargeOrder.reject`。

---

> 通用约定：所有接口位于 `/api/v1/admin` 下，**鉴权均要求 `Authorization: Bearer <token>` 且用户角色为管理员**（中间件 `middleware.Auth` + `middleware.RequireAdmin`）。>   
> 响应统一信封：`{"code":0,"message":"ok","data":{...}}`，`code=0` 成功，非 0 失败。以下仅列出 handler 中实际出现的错误码：`0` 成功、`1001` 参数错误、`400` 参数错误、`500` 服务错误；业务错误另返回 `errCode(err)`（多数为 `1001`）。

---

### `GET /api/v1/admin/withdraw-orders`

- 鉴权: 需管理员
- 说明: 后台提现订单列表（联表用户账号/昵称/靓号 + 账户快照）
- 路径参数: 无
- 查询参数: `kw:string`(可选, 搜账号/昵称/靓号), `status:int`(可选, 0=全部), `type:int`(可选, 提现方式, 0=全部), `page:int`(默认1), `size:int`(默认20)
- 请求体: 无
- 成功响应 data: `{"list":[{id:int,userId:int,userAccount:string,userNickname:string,userShortId:string,amount:number,fee:number,actualAmount:number,withdrawType:int,accountSnapshot:object,status:int,rejectReason:string,reviewerId:int,reviewedAt:time,remark:string,createdAt:time}],"total":int}`（分页：list + total）
- 错误码: 500 查询失败
- 备注: `status` 取值 1 待审核 / 2 已通过 / 3 已驳回。`accountSnapshot` 为提现账户快照对象（按方式含微信/支付宝/银行卡字段，卡号 `bankCardNo` 已脱敏，`bankCardNoFull` 为原始卡号仅审核用）。

### `PUT /api/v1/admin/withdraw-orders/:id/approve`

- 鉴权: 需管理员
- 说明: 审核通过提现（释放冻结本金、扣手续费、小助手推送到账通知）
- 路径参数: `id:int`（提现单 id；`<=0` 报 1001）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `{"orderId":int,"userId":int,"amount":number,"fee":number}`
- 错误码: 1001 参数错误；`errCode(err)`（订单非待审核/重复审核=1001）
- 备注: 幂等（已通过直接返回）；审核通过会触发小助手系统提醒。

### `PUT /api/v1/admin/withdraw-orders/:id/reject`

- 鉴权: 需管理员
- 说明: 驳回提现（解冻退回余额，记录驳回原因）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体:
  ```json
  {"reason":"string(可选) // 驳回原因"}
  ```
- 成功响应 data: 无（仅 `code/message`）
- 错误码: 1001 参数错误；`errCode(err)`
- 备注: 仅 `Pending` 状态可驳回；写 `reject_reason` + `reviewer_id` 并记后台操作日志。

### `DELETE /api/v1/admin/withdraw-orders/:id`

- 鉴权: 需管理员
- 说明: **当前源码未实现该路由**（admin.go 中仅有 GET 列表与 approve/reject，无 DELETE 提现单）
- 路径参数: —
- 请求体: —
- 成功响应 data: —
- 错误码: —
- 备注: 不在 admin.go 注册表中，调用将命中 404/路由未匹配。如需删除提现记录，应另行在代码中补充实现。

---

### `GET /api/v1/admin/groups`

- 鉴权: 需管理员
- 说明: 群组列表（含成员数）
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[{Conversation字段...,memberCount:int}]`（无分页，最多 200 条）
- 错误码: 500 查询失败
- 备注: 仅返回 `type=群聊` 且 `status=正常` 的会话。Conversation 字段含 `id(string),type,nameZh,nameEn,avatar,ownerId(string),maxMembers,status,createdAt,updatedAt` 等。

### `DELETE /api/v1/admin/groups/:id`

- 鉴权: 需管理员
- 说明: 解散群组（置群状态为已解散并删除群成员）
- 路径参数: `id:int`（ParseInt 忽略错误）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无
- 错误码: 无（handler 未对 `AdminGroupDisband` 错误做返回处理）
- 备注: 静默解散，记后台日志 `group.disband`。

### `GET /api/v1/admin/groups/:id/members`

- 鉴权: 需管理员
- 说明: 群成员列表（关联用户账号/昵称/头像/靓号）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: `page:int`(默认1), `size:int`(默认50)
- 请求体: 无
- 成功响应 data: `{"list":[{id:int,conversationId:string,userId:string,role:int,memberNickname:string,mute:int,joinedAt:time,account:string,nickname:string,avatar:string,shortId:string,status:int}],"total":int}`（分页）
- 错误码: 1001 参数错误；`errCode(err)`
- 备注: `role` 1 群主/2 管理员/3 普通；按 `role asc, joinedAt desc` 排序。

### `GET /api/v1/admin/groups/:id/messages`

- 鉴权: 需管理员
- 说明: 指定群的消息记录（Mongo 消息集合）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: `kw:string`(可选, 内容模糊), `page:int`(默认1), `size:int`(默认50)
- 请求体: 无
- 成功响应 data: `{"list":[Message...],"total":int}`（分页）
- 错误码: 1001 参数错误；`errCode(err)`
- 备注: Message 项含 `conversationId(string),msgId(string),clientMsgId,senderId(string),type,content,file,seq,status,createdAt,encrypted` 等。

---

### `GET /api/v1/admin/messages`

- 鉴权: 需管理员
- 说明: 全站消息审计查询（按会话/用户/关键词/时间/类型筛选）
- 路径参数: 无
- 查询参数: `convId:int`(可选), `userId:int`(可选), `kw:string`(可选), `from:int`(可选,unix ms), `to:int`(可选,unix ms), `type:int`(可选,消息类型), `page:int`, `size:int`
- 请求体: 无
- 成功响应 data: `{"list":[AdminMessageOut...],"total":int}`（分页）
- 错误码: 500 查询失败
- 备注: `AdminMessageOut` = Message + 冗余字段：`senderName,senderAvatar,senderShortId,receiverId,receiverName,receiverAvatar,receiverShortId,convType,convName,convAvatar`（单聊接收者为对方，群聊为群本身）。

### `POST /api/v1/admin/messages/:msgId/block`

- 鉴权: 需管理员
- 说明: 屏蔽/恢复屏蔽单条消息（屏蔽后用户端历史/同步不再下发）
- 路径参数: `msgId:int`（`<=0` 或非整数报 400）
- 查询参数: 无
- 请求体:
  ```json
  {"blocked":"bool(可选) // 默认 true=屏蔽；传 false=恢复"}
  ```
- 成功响应 data: 无
- 错误码: 400 参数错误；500 操作失败
- 备注: 仅置 `blocked` 字段；记后台日志 `message.block` / `message.unblock`。

### `DELETE /api/v1/admin/messages/:msgId`

- 鉴权: 需管理员
- 说明: **当前源码未实现该路由**（admin.go 中仅有 `GET /messages` 与 `POST /messages/:msgId/block`，无 DELETE 消息）
- 路径参数: —
- 请求体: —
- 成功响应 data: —
- 错误码: —
- 备注: 不在 admin.go 注册表中。消息删除需求可走 block 屏蔽，或另行补充实现。

---

### `GET /api/v1/admin/moments`

- 鉴权: 需管理员
- 说明: 朋友圈列表（全部，含屏蔽状态，带发布者）
- 路径参数: 无
- 查询参数: `page:int`(默认1), `size:int`(默认20)
- 请求体: 无
- 成功响应 data: `{"total":int,"list":[{id:string,userId:string,senderName,senderAvatar,assistant:bool,content,images:[]string,likeCount:int,liked:bool,hidden:bool,mine:bool,createdAt:string}]}`（分页：total + list）
- 错误码: 500 查询失败
- 备注: 发布者 `userId=-1` 表示小助手（后台发布的朋友圈）。

### `POST /api/v1/admin/moments`

- 鉴权: 需管理员
- 说明: 以小助手身份发布朋友圈
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"content":"string(可选) // 文本","images":"[]string(可选) // 图片URL数组"}
  ```
- 成功响应 data: `MomentsPost 对象 {id:string,userId:string,content,images,likes,hidden:bool,createdAt,updatedAt}`（images/likes 为 JSON 字符串，原始 model 字段）
- 错误码: 1001 内容不能为空；`errCode(err)`
- 备注: `content` 与 `images` 至少一项非空；`userId` 固定为 `-1`。

### `PUT /api/v1/admin/moments/:id/hidden`

- 鉴权: 需管理员
- 说明: 屏蔽/取消屏蔽某条朋友圈（屏蔽后仅发布者自己可见）
- 路径参数: `id:int`（ParseInt 忽略错误，非法 id 静默无效果）
- 查询参数: 无
- 请求体:
  ```json
  {"hidden":"bool(必填/可选) // true=屏蔽"}
  ```
- 成功响应 data: 无
- 错误码: 500 操作失败
- 备注: 记后台日志 `moment.hide`/`moment.unhide`。

### `DELETE /api/v1/admin/moments/:id`

- 鉴权: 需管理员
- 说明: 删除违规朋友圈
- 路径参数: `id:int`（ParseInt 忽略错误）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无
- 错误码: 500 删除失败
- 备注: 记后台日志 `moment.delete`。

---

### `GET /api/v1/admin/stats/overview`

- 鉴权: 需管理员
- 说明: 数据概览统计
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `{"userTotal":int,"online":int,"msgTotal":int,"convTotal":int,"storageMB":int}`（无分页）
- 错误码: 500 统计失败
- 备注: `online` 取自 Redis `online:*` 键数；`storageMB` 为消息数/1000 的粗略估值。

### `GET /api/v1/admin/stats/messages`

- 鉴权: 需管理员
- 说明: 按天统计消息量
- 路径参数: 无
- 查询参数: `days:int`(可选, 默认7)
- 请求体: 无
- 成功响应 data: `{"days":int,"series":[{day:string("YYYY-MM-DD"),count:int}]}`（无分页）
- 错误码: 500 统计失败
- 备注: 基于 Mongo 消息集合按创建日期 `$group` 聚合。

---

### `GET /api/v1/admin/logs`

- 鉴权: 需管理员
- 说明: 后台操作日志列表
- 路径参数: 无
- 查询参数: `page:int`, `size:int`
- 请求体: 无
- 成功响应 data: `{"list":[AdminLog...],"total":int}`（分页）
- 错误码: 500 查询失败
- 备注: `AdminLog` 字段：`id(string),adminId(string),action,target,detail(JSON字符串),ip,createdAt`。

### `GET /api/v1/admin/logs/login`

- 鉴权: 需管理员
- 说明: 登录日志列表
- 路径参数: 无
- 查询参数: `page:int`, `size:int`
- 请求体: 无
- 成功响应 data: `{"list":[LoginLog...],"total":int}`（分页）
- 错误码: 500 查询失败
- 备注: `LoginLog` 字段：`id(string),userId(string),ip,device,result(1成功/0失败),createdAt`。

---

### `GET /api/v1/admin/reserved-short-ids`

- 鉴权: 需管理员
- 说明: 保留靓号列表（按状态/来源/关键词筛选）
- 路径参数: 无
- 查询参数: `page:int`(默认1), `size:int`(默认20), `status:int`(默认0=全部), `source:int`(默认0=全部), `kw:string`(可选)
- 请求体: 无
- 成功响应 data: `{"list":[{id:int,shortId:string,source:int,type:int,status:int,remark:string,price:number,usedBy:int,usedAt:time,createdAt:time,userNickname?:string,userAccount?:string,userShortId?:string}],"total":int}`（分页）
- 错误码: `errCode(err)`
- 备注: `source` 1 手动/2 范围/3 规则；`type` 1 普通/2 豹子号/3 顺子号/4 VIP；`status` 1 未分配/2 冻结/3 已用。已分配行附带占用者昵称/账号/靓号。

### `POST /api/v1/admin/reserved-short-ids/batch`

- 鉴权: 需管理员
- 说明: 批量生成保留靓号（范围/手动列表/规则三种模式）
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"mode":"string(可选) // range|list|rule；旧前端不传则按 list 兼容","from":"int64(可选, range模式起)","to":"int64(可选, range模式止)","list":"[]string(可选, 手动列表)","ids":"[]string(可选, 兼容字段=list)","prefix":"string(可选, rule模式前缀)","digits":"int(可选, rule模式位数<=16)","count":"int(可选, rule模式个数<=100000)","remark":"string(可选)","price":"float64(可选)","source":"int(可选, 默认按 mode 推断)","type":"int(可选, 1~4, 越界归1)"}
  ```
- 成功响应 data: `{"added":int,"count":int}`（均为新增条数）
- 错误码: 1001 参数错误；`errCode(err)`
- 备注: 三种模式互斥，取第一个满足条件的；已存在靓号自动跳过；`type<1||>4` 归一到 1。

### `PUT /api/v1/admin/reserved-short-ids/:id/remark`

- 鉴权: 需管理员
- 说明: 修改靓号备注/价格/类型
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体:
  ```json
  {"remark":"string(可选)","price":"float64(可选, >0才更新)","type":"int(可选, 1~4)"}
  ```
- 成功响应 data: 无
- 错误码: 1001 参数错误；`errCode(err)`
- 备注: 空 remark / price<=0 / type 越界则对应字段不更新。

### `PUT /api/v1/admin/reserved-short-ids/:id/frozen`

- 鉴权: 需管理员
- 说明: 冻结/解冻靓号
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体:
  ```json
  {"frozen":"bool(必填/可选) // true=冻结(status=2), false=解冻(status=1)"}
  ```
- 成功响应 data: 无
- 错误码: 1001 参数错误；`errCode(err)`（已用靓号不可冻结/解冻=1001）
- 备注: 冻结置 status=2；已分配(status=3)拒绝操作。

### `DELETE /api/v1/admin/reserved-short-ids/:id`

- 鉴权: 需管理员
- 说明: 删除靓号（仅未分配/冻结）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无
- 错误码: 1001 参数错误；`errCode(err)`（已用靓号不可删=1001）
- 备注: 已分配(status=3)拒绝删除。

### `PUT /api/v1/admin/reserved-short-ids/:id/assign`

- 鉴权: 需管理员
- 说明: 将靓号分配给指定用户（事务+行锁，回收旧靓号）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体:
  ```json
  {"userId":"int64|string(必填) // 目标用户ID，兼容数字/字符串/JSON 字符串"}
  ```
- 成功响应 data: `{"userId":int,"nickname":string,"account":string,"shortId":string}`
- 错误码: 1001 参数错误/缺少 userId/用户不存在/已冻结/被占用；`errCode(err)`
- 备注: 要求靓号 status=1(未分配) 或 3(已占用强行改分配)；分配成功置 status=3 + usedBy + usedAt；用户原预留靓号自动回收。

### `PUT /api/v1/admin/reserved-short-ids/:id/relieve`

- 鉴权: 需管理员
- 说明: 解除靓号分配（回收为未分配并清空用户 short_id）
- 路径参数: `id:int`（`<=0` 报 1001）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无
- 错误码: 1001 参数错误；`errCode(err)`（该靓号未被分配=1001）
- 备注: 仅当 status=3 且 usedBy>0 可解除；仅当用户 short_id 仍等于该靓号时才清空，避免误覆盖。

---

### `GET /api/v1/admin/invite-friend-codes`

- 鉴权: 需管理员
- 说明: 自定义邀请码列表（一码关联多好友，附带好友昵称）
- 路径参数: 无
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `[{id:string,code:string,friendIds:string(JSON数组字符串),remark:string,enabled:int(1启用/0停用),usedCount:int,createdAt:time,friendNames:[]string}]`（无分页，最多 500 条）
- 错误码: 500 查询失败
- 备注: `friendIds` 为原始 JSON 字符串如 `["123","456"]`；`friendNames` 为对应昵称（查不到显示 `#id`）。

### `POST /api/v1/admin/invite-friend-codes`

- 鉴权: 需管理员
- 说明: 创建自定义邀请码（注册后自动添加关联好友）
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"code":"string(必填, ≤32, 唯一)","friendIds":"[]string(必填, 至少1个, 字符串形式int64)","remark":"string(可选)"}
  ```
- 成功响应 data: `InviteFriendCode {id:string,code:string,friendIds:string,remark:string,enabled:int,usedCount:int,createdAt:time}`
- 错误码: 1001 参数错误/邀请码空/已存在/至少1好友；`errCode(err)`
- 备注: 默认 `enabled=1`；记后台日志 `invite_code.create`。

### `PUT /api/v1/admin/invite-friend-codes/:id`

- 鉴权: 需管理员
- 说明: 更新邀请码（code/friendIds/remark/enabled，nil 不改）
- 路径参数: `id:int`（ParseInt 忽略错误）
- 查询参数: 无
- 请求体:
  ```json
  {"code":"*string(可选)","friendIds":"[]string(可选, 至少1个)","remark":"*string(可选)","enabled":"*int(可选, 1/0)"}
  ```
- 成功响应 data: 无
- 错误码: 1001 参数错误/邀请码不存在/至少1好友；`errCode(err)`


- 备注: 指针字段 nil 表示不更新；记后台日志 `invite_code.update`。

### `DELETE /api/v1/admin/invite-friend-codes/:id`

- 鉴权: 需管理员
- 说明: 删除邀请码
- 路径参数: `id:int`（ParseInt 忽略错误）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: 无
- 错误码: 500 删除失败
- 备注: 记后台日志 `invite_code.delete`。

---

### `GET /api/v1/admin/health/:key`

- 鉴权: 需管理员
- 说明: 系统健康检测（真实连接探测）
- 路径参数: `key:string`（检测项，或 `all`/`空` 返回全部）
- 查询参数: 无
- 请求体: 无
- 成功响应 data: `key=all` → `{"mysql":{...},"redis":{...},"mongo":{...},"minio":{...},"api":{...},"wss":{...},"jpush":{...},"version":{...}}`；否则 `{"<key>":{status:string("ok"|"warn"|"err"),message:string,details:map[string]string,latencyMs:int}}`
- 错误码: `errCode(err)`
- 备注: 检测项 `mysql/redis/mongo/minio/api/wss/jpush/version`；未知 key 返回 err 项。

### `POST /api/v1/admin/system/restart`

- 鉴权: 需管理员
- 说明: 重启服务（需 systemd 托管；Windows 开发环境仅提示）
- 路径参数: 无
- 查询参数: 无
- 请求体:
  ```json
  {"target":"string(可选, api|gateway; 默认非法)"}
  ```
- 成功响应 data: 无（返回 message 提示“重启指令已下发…”）
- 错误码: 1001 参数错误（target 非法）；400 Windows 环境不支持
- 备注: `api`→unit `im-api`，`gateway/wss`→unit `im-gateway`；先返回响应再延迟 800ms 执行 `systemctl restart`；非 systemd 环境直接报 400。

### `POST /api/v1/admin/upload`

- 鉴权: 需管理员
- 说明: 管理员文件上传（multipart/form-data）
- 路径参数: 无
- 查询参数: 无
- 请求体: `multipart/form-data`：`file`(必填文件), `dir`(可选, 存储目录, 默认 `common/`)
- 成功响应 data: `{"url":string,"name":string(原文件名),"object":string(对象名),"size":int,"mimeType":string}`
- 错误码: 1001 缺少文件；500 上传失败
- 备注: 与用户端 `/api/v1/upload` 逻辑一致，落到对象存储（MinIO）。

---

## 维护约定

1. **改后端必改文档**：任何对 `internal/handler/*.go`（路由、入参、出参、错误码）或对应 `service`/`model` 结构体的改动，完成后必须同步更新本文档对应接口块。新增接口 → 新增一个 `###` 块并补进“端点索引”；删除接口 → 同时删块与索引项。
2. **字段即真相**：文档中的 JSON 键名、类型、必填/可选、错误码直接来自源码，不要凭记忆写。改动后请用 `grep` 核对结构体 `json` tag 与实际返回。
3. **钱包/资金类铁律**：凡涉及余额、转账、红包、充值、提现的接口，文档必须写明“金额以服务端为准 / 幂等 / 冻结模型 / 领取唯一索引”等安全约束，避免后人踩坑。
4. **单一来源**：本文档为唯一权威接口文档。根目录 `docs/` 下的旧版 `企业IM-API文档.md` / `企业IM-API接口清单.md` 已过时，新功能请以本文件为准；如仍需维护旧文档，请先同步本文件再反向更新。
5. **自验**：改完跑 `go build ./...` 与后端启动冒烟；接口行为变化（尤其是错误码、分页字段）务必反映在文档。

---

*本文件由 WorkBuddy 基于 `im-server` 源码自动提取生成，生成时间 2026-09-04。*
