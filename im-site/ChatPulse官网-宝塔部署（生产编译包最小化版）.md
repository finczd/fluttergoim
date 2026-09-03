# ChatPulse 官网 · 宝塔最小化部署（生产编译包版）

> 本方法无需在服务器安装完整源码、无需 `npm install` 全量依赖、无需 `npm run build`，只需要上传编译产物 + 10 个运行时文件。
> 对比：上传整站源码 = 约 500MB（含 node\_modules）。
> 使用本方法：上传 `chatpulse-site-deploy.tar.gz` 约 **13 MB**，压缩比约 25 倍。
> 两种部署（源码版 vs 编译包版）都能用，**推荐中小企业用编译包版**。

***

## 一、两种部署方案对比

| 方案                | 需要上传                                   | 服务器是否要 npm install 全量依赖                      | 服务器是否要 npm run build         | 大小          | 适用人群            |
| ----------------- | -------------------------------------- | -------------------------------------------- | ---------------------------- | ----------- | --------------- |
| **A. 编译包版（推荐）**   | chatpulse-site-deploy.tar.gz (\~13 MB) | 只在 `.output/server` 目录安装生产依赖（约 10 秒）         | **否**，服务器不跑 build            | 13 MB       | 多数用户、发布正式环境     |
| **B. 源码版（前一份教程）** | 整个 im-site 目录除 node\_modules（或完整目录）    | **是**，npm install 10+ 分钟，better-sqlite3 还需编译 | **是**，npm run build 30\~60 秒 | 100\~500 MB | 需要在服务器直接改代码二次开发 |

***

## 二、前置条件（宝塔端）

### 1. 服务器与宝塔

- Linux 服务器（**Alibaba Cloud Linux 3**、**Ubuntu 22.04 LTS**、**CentOS 7+**）均可，宝塔面板 7.x / 11.x+

- 宝塔「软件商店」已安装：

  - **Nginx 1.22+**（或者 Tengine，AAPanel 用户直接用 OpenResty 也行）

  - **Node.js 版本管理器**（宝塔最新版内置 PM2 Manager 模块；若找不到则装「PM2 管理器 5.5+」）

  - Node 版本要求 **20.x 或 22.x**（20.x 推荐，更稳），**低于 18 不能跑**

- 放行端口：宝塔面板防火墙 + 云服务器安全组同时放行 80、443、8888（宝塔面板）、22(SSH)

### 2. Node 版本切换（关键！）

进入「宝塔左侧 → 软件商店 → Node.js 版本管理器 → 设置 → 版本切换」

- 默认版本设置成 **20.x LTS**（比如 20.15+）

- 命令行检查（宝塔「终端」登录）：

```bash
node -v       # v20.x.x  ✅
npm -v        # 10.x+    ✅
pm2 -v        # 若提示 command not found，宝塔→PM2管理器 装一次
```

如 `node -v` 显示 16/14/10 → 继续去面板切换到 20；否则装 better-sqlite3 会因 Node 版本不匹配编译失败。

### 3. Linux 依赖（better-sqlite3 本地编译需要）

某些 CentOS 最小化镜像缺 `python3 / make / gcc / g++`，提前装上：

```bash
# Ubuntu / Debian
sudo apt update && sudo apt install -y build-essential python3

# CentOS 7 / Aliyun Linux 3
sudo yum groupinstall -y "Development Tools"
sudo yum install -y python3
```

***

## 三、本地打包（你现在的 Windows 电脑）

```powershell
# 进入你本地 im-site 目录
cd d:\im-project\im-site

# 只需要这一条：自动 build → 同步 docs → 组装 → 打包 tar.gz
npm run deploy-pack
```

脚本会做 4 件事：

1. 预同步 `d:\im-project\docs` → `im-site\content\docs`（Markdown 源）
2. `npm run build` 生成 `.output/` SSR 生产包（20 MB）
3. 抽取最小运行时文件集合 + **本地完整 data/ 目录**（chatpulse.db + 文章 JSON 等）
4. 用 Windows `tar.exe` 打包生成同目录 **`chatpulse-site-deploy.tar.gz`**（13 MB）

**生成的部署包里 exactly 包含：**

```
chatpulse-site-deploy.tar.gz
├─ .output/                 ← Nuxt Nitro SSR 编译产物（所有路由/API/页面）
│   ├─ server/
│   │   ├─ index.mjs        ← 应用入口（node index.mjs 启动）
│   │   └─ package.json     ← 声明生产依赖 better-sqlite3 等
│   └─ public/              ← 构建后静态资源（已含 hash）
├─ public/                  ← 原静态资源（favicon.svg、robots.txt、上传的 logo/截图图）
├─ content/
│   └─ docs/                ← 所有 Markdown 文档源（后台文档管理 Tab 读写这些文件）
├─ logs/                    ← 空目录（PM2 输出日志放这里）
├─ data/                    ← 随包带上本地完整 chatpulse.db（含 9 张表、账号、定价、文章/联系记录）
│                            首次部署无需任何数据库初始化/迁移操作
├─ ecosystem.config.cjs     ← PM2 启动配置（3000 端口、env_file=.env.production、内存上限 512M 重启）
├─ .env.example             ← 环境变量模板
├─ _repair-db.cjs           ← 未来升级补表/补列用（首次部署不需要跑；DB_SCHEMA_VERSION 升级后才执行一次）
└─ (.env.production)        ← 如果本地有这个文件会一并打包
```

不需要的（源码、组件、配置、依赖包）全部被排除。

***

## 四、上传到宝塔服务器

### 1. 创建站点目录

宝塔面板「网站 → 添加站点」先跑一下（即使还没绑域名也没关系），目的是创建 `/www/wwwroot/im-project/im-site/` 目录：

- 域名填：`chatpulse.cn`（如没准备好先随便填 `temp.chatpulse.cn`，以后可以改）

- PHP 版本选 **纯静态**

- 数据库、FTP：都不创建

- 根目录：**保持 /www/wwwroot/im-project/im-site**

### 2. 上传 tar.gz

- 宝塔「文件」进入 `/www/wwwroot/im-project/im-site/`

- 点击「上传」，把你本地 `d:\im-project\im-site\chatpulse-site-deploy.tar.gz` 拖进来

- 或用 WinSCP / Xftp / FileZilla 以 SFTP 上传（建议，大文件断点续传）

### 3. 解压

宝塔终端：

```bash
cd /www/wwwroot/im-project/im-site
tar -xzf chatpulse-site-deploy.tar.gz
ls -la
# 能看到 .output/  public/  content/  ecosystem.config.cjs  _repair-db.cjs ...
```

***

## 五、服务器配置

### 1. 环境变量配置

```bash
cd /www/wwwroot/im-project/im-site
cp .env.example .env.production
vim .env.production
```

填入（至少改 SITE\_URL）：

```ini
# .env.production
SITE_URL=https://你的官网域名.com           # 影响 sitemap / canonical 生成，SEO 用
ADMIN_PASSWORD=                            # 已废弃不用，现在密码在 SQLite admin_users 表，保留这个键也行
NODE_ENV=production
NITRO_PORT=3000                            # 跟 ecosystem.config.cjs port 对应
```

保存退出（`:wq` Vim）。

### 2. 数据库（随包已带好，首次部署不需要任何初始化命令）

> **`node _repair-db.cjs`** **是"升级补表/补列工具"，首次部署不用跑。**
>
> `npm run deploy-pack` 打包时已经把你本地 `data/chatpulse.db`（含 9 张表 + 默认账号 `admin/admin123` + 三档 USDT 定价 + AI 配置 + 已存在的文章/联系记录）**原样打进压缩包**，解压后就可用，不需要再创建/初始化/迁移数据库。
>
> 只有一种情况才需要跑：未来某次代码升级，`DB_SCHEMA_VERSION` 升高（新增表 / 新增列），这时升级流程里**再**执行一次 `node _repair-db.cjs` 把 schema 补齐。

### 3. 安装生产依赖（better-sqlite3 在 Linux 重新编译 .node）

这一步**不能省**。因为 Windows 编译的 `.output/server/node_modules/better-sqlite3/build/Release/better_sqlite3.node` 是 PE 格式，Linux 是 ELF 格式，直接拷贝必然崩。

```bash
cd /www/wwwroot/im-project/im-site/.output/server
ls -la
# 你能看到 package.json，里面声明了 better-sqlite3 / bcryptjs / node-cron / marked 等运行时依赖

npm install --omit=dev --no-audit --no-fund --no-update-notifier
# 加上国内镜像加速（选一行，看你的服务器网络）：
# npm --registry=https://registry.npmmirror.com install --omit=dev --no-audit --no-fund --no-update-notifier
```

输出如果看到 `prebuild-install warn install No prebuilt binaries found... Trying compile ... 编译成功` → 正常，就是 Linux 本地重编了 better-sqlite3。
出现红色 Error → 看上面「一、前置条件 3」是否装了 build-essential 和 python3。

### 4. 启动 PM2

```bash
cd /www/wwwroot/im-project/im-site
ls -la ecosystem.config.cjs

pm2 start ecosystem.config.cjs
# 输出应该显示 chatpulse-site  online
pm2 list
```

**检查状态**：

```bash
pm2 status                 # 看 status = online，restarts 不大于 0
pm2 logs chatpulse-site --lines 80 --nostream
curl -I http://127.0.0.1:3000/   # HTTP/1.1 200 OK  ✅
curl http://127.0.0.1:3000/api/site-config  # 返回 JSON code:0 data: {...}
```

如果 status 是 errored，且日志里写 `Error: Cannot find module better-sqlite3` → 说明上一步 npm install 没跑成功或跑错目录（要在 `.output/server` 下跑）。

### 5. 保存开机自启

```bash
pm2 save
# 让 pm2 在服务器重启后自动拉起
pm2 startup
# 运行后 pm2 会在下方输出一条 super long command，复制粘贴到终端再执行。
# 宝塔环境如已安装 PM2 管理器面板自带 startup，一般已配置完成。
```

***

## 六、宝塔 Nginx 反向代理 + HTTPS（最小增量插入，不破坏面板 SSL 块）

### 1. 新建反向代理

宝塔面板「网站 → chatpulse.cn → 设置 → 反向代理 → 添加反向代理」：

```
代理名称：   chatpulse-site
目标URL：    http://127.0.0.1:3000
发送域名：   $host
```

保存后宝塔会生成一段标准 location /。

### 2. 再追加 location 优化（面板「设置 → 配置文件」在 server{} 里追加）

**不要整文件替换**（否则会破坏 `#SSL-START/END` 面板标记块，导致 SSL 无法签发/续期）。找到最末尾 location `@nodejs` 或宝塔写入的 proxy 块之前，**追加**这几段：

```nginx
# =====================================================
#  A. 让 Nuxt 构建产物（_nuxt/* 的带哈希 chunk）直接由 Nginx 从
#     .output/public/_nuxt 读出来，绝对不要反代到 Node。
#     文件名带 hash，缓存 1 年 immutable（彻底解决 chunk 404）。
#     root 必须写到 /www/wwwroot/im-project/im-site/.output/public
# =====================================================
location ^~ /_nuxt/ {
    root  /www/wwwroot/im-project/im-site/.output/public;
    expires 1y;
    add_header Cache-Control "public, max-age=31536000, immutable";
    add_header X-Content-Type-Options "nosniff";
    access_log off;
    try_files $uri =404;
}

# =====================================================
#  A2. 用户后台上传的 logo / 截图等文件保存在 <项目根>/public/uploads。
#      部署升级时 NEVER 删 public/uploads！路径独立于 .output，
#      升级只覆盖 .output/ 不会丢失用户上传的图片数据。
# =====================================================
location ^~ /uploads/ {
    root  /www/wwwroot/im-project/im-site/public;
    expires 7d;
    add_header Cache-Control "public, max-age=604800";
    add_header X-Content-Type-Options "nosniff";
    try_files $uri =404;
}

# B. 其它静态文件 Nginx 直接响应（比反代到 Node 快 10 倍）
location ~* \.(?:jpg|jpeg|gif|png|svg|webp|ico|css|js|woff2?|ttf|eot|txt|xml)$ {
    expires 30d;
    add_header Cache-Control "public, immutable";
    try_files $uri @nuxt;
}

# 2. sitemap.xml 走 Node 动态生成（SEO 关键）
location = /sitemap.xml { proxy_pass http://127.0.0.1:3000; }

# 3. 安全：禁止访问 data/ （含 SQLite 数据库）和隐藏文件
location ^~ /data/ { deny all; }
location ~ /\.(env|git|production) { deny all; }

# 4. gzip
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/svg+xml;
gzip_min_length 1k;
gzip_comp_level 6;
```

保存。配置面板如果提示错误，最常见是 `try_files $uri @nuxt;` 这个 `@nuxt` 还没定义 → 把最后反代的 location 改名成 @nuxt：

```nginx
location / { try_files $uri @nuxt; }
location @nuxt {
    # 宝塔生成的反代指令（proxy_pass 等）放在这里
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

### 3. HTTPS 证书

宝塔「网站 → chatpulse.cn → SSL → Let's Encrypt → 一键申请」，勾选「证书申请后强制 HTTPS」。

> 如果你是国内云服务器 + 大陆域名实名做过备案 → 强烈建议上阿里 CDN 或腾讯云 CDN，把全站静态资源（.js/.css/.图片）加速。

***

## 七、8 项部署验收清单

依次在浏览器/终端跑一遍，全部通过才算部署成功：

| # | 验证方式                                   | 期望结果                                                           |
| - | -------------------------------------- | -------------------------------------------------------------- |
| 1 | 打开 `https://chatpulse.cn/`             | 官网首页正常，Hero 显示"ChatPulse 企业级即时通讯系统"                            |
| 2 | `https://chatpulse.cn/robots.txt`      | 显示 User-agent:\* 等文本                                           |
| 3 | `https://chatpulse.cn/sitemap.xml`     | 显示 XML 文档（含站点所有路径 + 文章）                                        |
| 4 | `https://chatpulse.cn/api/site-config` | 返回 JSON `{"code":0,"data":{..., pricing:{...}}}`（包含 USDT 三档定价） |
| 5 | `https://chatpulse.cn/admin/login`     | 打开登录页 → 输入 admin / admin123 登录成功                               |
| 6 | 后台 → 文档管理 Tab → 点开「架构方案.md」编辑          | 保存无报错，打开 `/api-docs` 架构方案那篇内容正确                                |
| 7 | 登录后 → 修改密码 → 改完退出再用新密码登录一遍             | OK                                                             |
| 8 | 联系我们页提交「姓名 + 联系方式」→ 后台 → 联系记录          | 能看到刚提交的记录                                                      |

***

## 八、更新/升级流程（以后代码改了，只跑 5 条命令）

**本地**：

```powershell
cd d:\im-project\im-site
npm run deploy-pack
# 上传新生成的 chatpulse-site-deploy.tar.gz 到服务器
```

**服务器（宝塔终端）**：

```bash
cd /www/wwwroot/im-project/im-site

# 【非常重要】先备份原 data/！
tar -czf /root/chatpulse-data-backup-$(date +%Y%m%d).tar.gz data/

# 解压新代码包（会覆盖 .output / public / content / ecosystem 等；不会覆盖带数据的 data/，因为新包里也是你的本地 data 全量）
tar -xzf chatpulse-site-deploy.tar.gz

# 如果"升级"后 DB_SCHEMA_VERSION 升级过，这里才执行一次补表/补列
node _repair-db.cjs

# 重新安装生产依赖（主要是 better-sqlite3 的 Linux 原生 addon）
cd .output/server && npm install --omit=dev --no-audit --no-fund

# 零停机热重载
cd ../.. && pm2 reload chatpulse-site
pm2 logs chatpulse-site --lines 30 --nostream
```

> **关于 data/ 的黄金规则：**
>
> - 升级时**不要手动 rm -rf data/**，否则你的账号、定价、文章、AI 配置、联系记录全部丢失。
>
> - 解压时：新包自带本地 `data/`，会把本地 chatpulse.db 上传覆盖到服务器上。
>
> - 如果你的**线上运行数据**（服务器上的文章/配置）比本地新，升级前就不该让 tar 覆盖 data/ → 先备份，然后使用：
>
>   ```bash
>   tar -xzf chatpulse-site-deploy.tar.gz --exclude='./data/*'
>   ```
>
>   然后再跑一次 `node _repair-db.cjs` 只做 schema 补列，不覆盖数据。

### 定时数据库备份（宝塔面板计划任务）

宝塔左侧「计划任务 → Shell 脚本 → 每日 3:00 执行」：

```bash
#!/bin/bash
DEST=/root/chatpulse-backups
SRC=/www/wwwroot/im-project/im-site/data
mkdir -p "$DEST"
tar -czf "$DEST/db-$(date +\%Y\%m\%d).tar.gz" "$SRC"
# 保留最近 15 天
find "$DEST" -name "db-*.tar.gz" -mtime +15 -delete
```

***

## 九、故障速查表

| 症状                                             | 大概率原因                                             | 操作                                                                      |
| ---------------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------- |
| 宝塔面板反代 502 Bad Gateway                         | PM2 没起起来 / 3000 端口没监听                             | `pm2 status && pm2 logs chatpulse-site --lines 100`                     |
| 登录后台 `no such table: admin_users`              | 非常罕见，多是部署时 data/ 没拷对或权限错                          | `cd /www/wwwroot/im-project/im-site && node _repair-db.cjs` （仅补表不覆盖数据）  |
| better-sqlite3 模块报错 `.node` invalid ELF header | Windows 的 .node 没在 Linux 重新编译                     | 去 `.output/server` 下跑 `npm install --omit=dev`                          |
| npm install 报 gyp / python3: not found         | 缺 build-essential 和 python3                       | 见「一、前置条件 3」apt install                                                  |
| HTTPS 正常，后台提交登录报 401                           | 反代丢了 `X-Forwarded-Proto` header，丢 HttpOnly cookie | 看第六步 location @nuxt 的 proxy\_set\_header 是否完整                           |
| 官网能访问，但上传 logo / 截图后刷新不显示                      | public/uploads/ 目录没写入权限                           | `chown -R www:www /www/wwwroot/im-project/im-site/public` + `chmod 755` |
| AI 定时任务没执行                                     | 后台 AI 管理 → 定时发布 → 启用开关 还在 0                       | 打开 启用开关 → 保存 → 立即生成按钮先跑一次验证                                             |
| npm install 404 commander\@13 镜像缺包             | 切换 npmmirror 源                                    | `npm config set registry https://registry.npmmirror.com`                |

***

## 十、文件大小参考（实测本地）

| 项目                                           | 大小                                 |
| -------------------------------------------- | ---------------------------------- |
| 整站源码工程（含 node\_modules）                      | 327.81 MB                          |
| 最小部署 tar.gz                                  | 12.91 MB                           |
| 解压后运行目录                                      | 约 60 MB（含 SQLite 数据库增长后再加）         |
| `.output/server` 下 npm install --omit=dev 之后 | 再加约 20 MB（better-sqlite3 原生 addon） |

**结论：编译包上传大小是源码版的约 1/25，公网上传一般 30 秒即可完成。**

***

## 十一、紧急故障处理：`Failed to fetch dynamically imported module`

生产环境出现这个报错的本质：**浏览器手上持有的是旧版本的 entry.js，加载时尝试 fetch 旧 hash 的子 chunk（比如** **`CVMBqxUx.js`），但服务器升级后这个 chunk 文件已经不存在了** → 404 → 浏览器控制台红字报错 + 页面白屏。

代码侧我们已经做了 4 层自愈（见 `nuxt.config.ts` + `app.vue`）：

1. 每次构建写入 `build-version` meta 标签，客户端 hydration 一发现客户端/服务端版本不一致就**立刻硬刷新**；
2. 路由跳转后偷偷 re-fetch 当前 HTML 做版本比对，不匹配自动弹底部升级横幅 + 2 秒后刷新；
3. `onErrorCaptured` + `vue:error` + `app:error` + `unhandledrejection` 四种错误全局捕获，命中 chunk 的关键词一律走刷新流程；
4. sessionStorage 每 45 秒锁一次，避免极端情况下刷新死循环。

如果线上**仍然出现**（大多数场景是 Nginx/CDN 缓存不规范或第一次升级旧包 -> 新包未做 Nginx `_nuxt` 目录直出），在宝塔终端**按顺序执行这 11 条命令**，1 分钟内恢复：

```bash
# ========= 0. 进入目录 & 先备份 ==========
cd /www/wwwroot/im-project/im-site
mkdir -p /root/chatpulse-backups
tar -czf /root/chatpulse-backups/emergency-$(date +%Y%m%d%H%M%S).tar.gz data/

# ========= 1. 确认 _nuxt/ 目录在磁盘上真的有文件 ==========
ls -la .output/public/_nuxt | head -n 20
# 正常应该看到一大堆 [name]-[hash].js / .css / .svg 文件
# 如果目录为空或几乎没文件 = 解压没解干净，重新上传 tar.gz 再 tar -xzf

# ========= 2. 清空 Nginx / CDN 的静态缓存 ==========
# 宝塔面板操作：缓存 -> 站点缓存 -> 清除全部
# 如果开了阿里 CDN / 腾讯 CDN，控制台点"刷新缓存 -> 刷新所有 / 全站"
# CLI 清 Nginx proxy_cache（如果你配置过缓存路径）：
rm -rf /www/server/nginx/proxy_cache_dir/* 2>/dev/null

# ========= 3. 重载 Nginx（加载新的 _nuxt location 规则）==========
nginx -t && nginx -s reload

# ========= 4. 检查 _nuxt/xxx.js 实际是否能从磁盘命中 ==========
# （把下面的 XXX 替换成报错里的文件名，例如 CVMBqxUx.js）
# 文件名有两种写法：vite 会把 hash 放在 - 后，但老版本是纯 hash
find .output/public/_nuxt -type f -name '*CVMBqxUx*'
# 如果返回空 -> 该 hash 属于"旧构建"，请让客户端刷新一次就能自愈。

# ========= 5. 用 curl 直接查 Nginx 返回的响应头（看是不是 immutable 1y）==========
curl -I https://你的官网域名.com/_nuxt/随便一个真实存在的js文件.js
# 期望看到:  Cache-Control: public, max-age=31536000, immutable
# 如果没看到 = Nginx 规则没生效（检查是否加了 location ^~ /_nuxt/ 块）

# ========= 6. PM2 重启一次 ==========
pm2 reload chatpulse-site
sleep 2
pm2 status

# ========= 7. 校验 Node 本身对构建产物的响应 ==========
curl -I http://127.0.0.1:3000/_nuxt/    # 404/403 都正常（列表页我们不需要）

# ========= 8. 可选：如果上面都做完还有客户投诉白屏 ==========
# 你可以临时关闭 long-term immutable：把 _nuxt location 改成 expires 10m; 等 24h 再改回去。
# 不推荐长期这么做。

# ========= 9. 让客户端立刻清缓存最狠一招 ==========
# 给所有响应加一个 Set-Cookie 携带 __v=<build> 也行，但最直接的是：
# 改完 Nginx 之后，"宝塔设置 → 反向代理 → 清除缓存"按钮点一次，再给"CDN 全站刷新"
```

### 永久避免这个故障的检查清单

部署完成后执行，全部满足就再也不会遇到 chunk 动态导入失败：

- [ ] `curl -I https://你的域名/_nuxt/xxx.js` → 响应头有 `Cache-Control: public, max-age=31536000, immutable`

- [ ] `curl -I https://你的域名/_nuxt/xxx.js` → `Server: nginx`（不是 Node），即 Nginx 从 `.output/public/_nuxt` 直出

- [ ] `location ^~ /_nuxt/ { root /www/wwwroot/im-project/im-site/.output/public; ... }` 已写入配置

- [ ] npm run deploy-pack 的 `buildVersion` 注入成功（HTML head 里有 `<meta name="build-version" content="...">`）

- [ ] 升级过程中 tar 解压时不做中间删除（别 `rm -rf *` 再解压，否则窗口期 2\~5 秒内会产生 404），应当直接解压覆盖；必要时把 pm2 reload 放到 tar 解压完之后再执行

- [ ] 有 CDN 时一定给 `/_nuxt/*` 开"强制缓存 + 最长 1 年"，而不是"跟随源站 304"，否则 CDN 会对 chunk 做 Range 请求产生不可预期 416

