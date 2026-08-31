#!/usr/bin/env bash
# =============================================================
# 企业 IM 宝塔面板一键部署脚本
#
# 用法：
#   1. 把整个项目上传到 /www/wwwroot/im-project（含 im-server、im-web、deploy）
#   2. 宝塔面板装好 Nginx、MySQL、Redis（MongoDB 需另行安装或用 Docker）
#   3. cd /www/wwwroot/im-project/deploy && bash bt_deploy.sh
#
# 说明：
#   - 脚本幂等，重复执行不会破坏已有配置（关键文件先备份为 .bak 再写）
#   - 不在脚本中硬编码任何密码，密码通过 deploy/.env 或交互输入
#   - 端口/目录与 deploy/docker-compose.yml、deploy/nginx-*.conf 保持一致：
#       api  :8080   gateway :9090   web :8081   admin :8082   h5 :8090   pc :8091
# =============================================================
set -e

# =============================================================
# 一、变量区（集中配置，按需修改）
# =============================================================
INSTALL_DIR="/www/wwwroot/im-project"      # 安装根目录（宝塔习惯 /www/wwwroot）
HTTP_PORT="8080"                           # api 端口，对应 im-server/.env 的 HTTP_PORT
WS_PORT="9090"                             # gateway 长连接端口，对应 WS_PORT
WEB_PORT="8081"                            # 工作台 Web 站点端口（对应 deploy/nginx-web.conf 的映射端口）
ADMIN_PORT="8082"                          # 管理后台站点端口（对应 deploy/nginx-admin.conf）
H5_PORT="8090"                             # Flutter H5 站点端口（对应 deploy/nginx-h5.conf）
PC_PORT="8091"                             # PC 网页版站点端口（对应 deploy/nginx-pc.conf）
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_DB="im"                              # 数据库名，与 compose/.env 的 MYSQL_DB 一致
BT_VHOST_DIR="/www/server/panel/vhost/nginx"   # 宝塔 Nginx 站点配置目录
SYSTEMD_DIR="/etc/systemd/system"

# 源目录 = 脚本所在 deploy/ 的上一级（即项目根）
SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# =============================================================
# 二、辅助函数
# =============================================================
info()  { echo -e "\033[32m[信息]\033[0m $*"; }
warn()  { echo -e "\033[33m[警告]\033[0m $*"; }
error() { echo -e "\033[31m[错误]\033[0m $*"; }

# 关键文件备份：已存在则备份为 .bak（.bak 已存在则跳过备份，保留最早的原始备份）
bak() {
    if [ -f "$1" ] && [ ! -f "$1.bak" ]; then
        cp -a "$1" "$1.bak"
        info "已备份: $1 -> $1.bak"
    fi
}

# =============================================================
# 三、前置检查
# =============================================================
if [ "$(id -u)" -ne 0 ]; then
    error "请用 root 执行：sudo bash $0"
    exit 1
fi

for cmd in mysql systemctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "缺少命令 $cmd，请先在宝塔面板安装 MySQL，并确认系统可用 systemctl"
        exit 1
    fi
done

if [ ! -d "$SOURCE_DIR/im-server" ]; then
    error "源目录异常：$SOURCE_DIR 下没有 im-server/，请确认脚本位于项目 deploy/ 目录内"
    exit 1
fi

info "源项目目录: $SOURCE_DIR"
info "安装根目录: $INSTALL_DIR"

# =============================================================
# 四、同步项目文件到安装目录（源目录与安装目录不同时才拷贝）
# =============================================================
mkdir -p "$INSTALL_DIR"
if [ "$SOURCE_DIR" != "$INSTALL_DIR" ]; then
    info "同步项目文件到 $INSTALL_DIR ..."
    for item in im-server im-web im-pc im-app migrations deploy; do
        if [ -e "$SOURCE_DIR/$item" ]; then
            cp -a "$SOURCE_DIR/$item" "$INSTALL_DIR/"
        fi
    done
fi

SRV_DIR="$INSTALL_DIR/im-server"
mkdir -p "$SRV_DIR/bin"

# =============================================================
# 五、编译 Go 后端（有 go 环境则尝试；失败不阻断，可上传已编译二进制）
# =============================================================
API_BIN="$SRV_DIR/bin/api"
GW_BIN="$SRV_DIR/bin/gateway"

if command -v go >/dev/null 2>&1; then
    info "检测到 Go 环境，尝试编译 im-server（api + gateway）..."
    if (cd "$SRV_DIR" && GO111MODULE=on CGO_ENABLED=0 go build -o bin/api ./cmd/api \
        && GO111MODULE=on CGO_ENABLED=0 go build -o bin/gateway ./cmd/gateway); then
        info "编译成功: $API_BIN / $GW_BIN"
    else
        warn "编译失败。请本地交叉编译后上传二进制："
        warn "  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/api ./cmd/api"
        warn "  GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bin/gateway ./cmd/gateway"
        warn "上传到 $SRV_DIR/bin/ 下即可，脚本继续。"
    fi
else
    warn "未检测到 Go 环境，跳过编译。请确认已上传二进制到："
    warn "  $API_BIN 与 $GW_BIN"
    warn "（本地编译命令见 宝塔部署说明.md）"
fi
[ -x "$API_BIN" ] || warn "注意：$API_BIN 尚不存在，后续 systemd 启动会失败，请上传二进制后重跑本脚本或手动 systemctl start"

# =============================================================
# 六、前端 dist 检测（由 npm run build 产物提供，不存在则给出指引后跳过）
# =============================================================
WEB_DIST="$INSTALL_DIR/im-web/dist"
if [ ! -f "$WEB_DIST/index.html" ]; then
    warn "未找到前端构建产物 $WEB_DIST/index.html，跳过前端部署。请在本地或服务器上构建："
    warn "  cd im-web && npm install && npm run build"
    warn "构建完成后把 im-web/dist 上传到 $WEB_DIST，再在宝塔里发布站点即可。"
else
    info "前端产物检测通过: $WEB_DIST"
fi
# Flutter H5 与 PC 网页版（可选，存在才部署对应站点）
H5_DIST="$INSTALL_DIR/im-app/build/web"
PC_DIST="$INSTALL_DIR/im-pc/dist"
[ -f "$H5_DIST/index.html" ] && info "H5 产物检测通过: $H5_DIST"
[ -f "$PC_DIST/index.html" ] && info "PC 产物检测通过: $PC_DIST"

# =============================================================
# 七、写后端配置 .env（从 .env.example 生成；已存在则不覆盖）
# =============================================================
ENV_FILE="$SRV_DIR/.env"
ENV_EXAMPLE="$SRV_DIR/.env.example"
if [ -f "$ENV_FILE" ]; then
    info "配置文件 $ENV_FILE 已存在，不覆盖。如需重置请手动删除后重跑。"
else
    if [ ! -f "$ENV_EXAMPLE" ]; then
        error "缺少 $ENV_EXAMPLE，无法生成配置"
        exit 1
    fi
    echo "=============================================="
    echo "首次部署，请设置以下密码（输入不回显）"
    echo "=============================================="
    read -r -s -p "MySQL root 密码（宝塔-数据库页可查）: " MYSQL_ROOT_PW; echo
    while [ -z "$MYSQL_ROOT_PW" ]; do
        read -r -s -p "MySQL root 密码不能为空，请重新输入: " MYSQL_ROOT_PW; echo
    done
    read -r -s -p "Redis 密码（宝塔 Redis 默认可能为空，直接回车跳过）: " REDIS_PW; echo
    read -r -s -p "第一个管理员 admin 的密码（直接回车用样例默认值，建议自定义）: " ADMIN_PW; echo

    # JWT 密钥：优先用 openssl 生成随机串，失败则交互输入
    JWT_SECRET="$(openssl rand -hex 32 2>/dev/null || true)"
    if [ -z "$JWT_SECRET" ]; then
        read -r -s -p "openssl 不可用，请手动输入 JWT_SECRET（长随机串）: " JWT_SECRET; echo
    fi

    info "从 .env.example 生成 $ENV_FILE ..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    # 统一替换为生产环境值（用 | 作分隔符，避免密码中 / 干扰）
    sed -i "s|^APP_ENV=.*|APP_ENV=prod|" "$ENV_FILE"
    sed -i "s|^MYSQL_HOST=.*|MYSQL_HOST=$MYSQL_HOST|" "$ENV_FILE"
    sed -i "s|^MYSQL_PORT=.*|MYSQL_PORT=$MYSQL_PORT|" "$ENV_FILE"
    sed -i "s|^MYSQL_USER=.*|MYSQL_USER=$MYSQL_USER|" "$ENV_FILE"
    sed -i "s|^MYSQL_PASSWORD=.*|MYSQL_PASSWORD=$MYSQL_ROOT_PW|" "$ENV_FILE"
    sed -i "s|^MYSQL_DB=.*|MYSQL_DB=$MYSQL_DB|" "$ENV_FILE"
    sed -i "s|^MYSQL_DSN=.*|MYSQL_DSN=$MYSQL_USER:$MYSQL_ROOT_PW@tcp($MYSQL_HOST:$MYSQL_PORT)/$MYSQL_DB?charset=utf8mb4\&parseTime=True\&loc=UTC|" "$ENV_FILE"
    sed -i "s|^REDIS_ADDR=.*|REDIS_ADDR=127.0.0.1:6379|" "$ENV_FILE"
    if [ -n "$REDIS_PW" ]; then
        sed -i "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$REDIS_PW|" "$ENV_FILE"
    fi
    sed -i "s|^MONGO_URI=.*|MONGO_URI=mongodb://127.0.0.1:27017|" "$ENV_FILE"
    sed -i "s|^MINIO_ENDPOINT=.*|MINIO_ENDPOINT=127.0.0.1:9000|" "$ENV_FILE"
    sed -i "s|^MINIO_PUBLIC_URL=.*|MINIO_PUBLIC_URL=http://127.0.0.1:9000|" "$ENV_FILE"
    sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$JWT_SECRET|" "$ENV_FILE"
    if [ -n "$ADMIN_PW" ]; then
        sed -i "s|^ADMIN_INIT_PASSWORD=.*|ADMIN_INIT_PASSWORD=$ADMIN_PW|" "$ENV_FILE"
    fi
    chmod 600 "$ENV_FILE"
    info ".env 生成完成（权限 600，含 DSN 与密钥，请勿外泄）"
fi
chmod 600 "$ENV_FILE" 2>/dev/null || true

# 从 .env 读取 MySQL root 密码用于导入 SQL（不在脚本内硬编码）
if [ -z "${MYSQL_ROOT_PW:-}" ]; then
    MYSQL_ROOT_PW="$(grep -E '^MYSQL_PASSWORD=' "$ENV_FILE" | head -1 | cut -d= -f2-)"
    if [ -z "$MYSQL_ROOT_PW" ] || [ "$MYSQL_ROOT_PW" = "change_me" ]; then
        read -r -s -p "请输入 MySQL root 密码（用于导入初始化 SQL）: " MYSQL_ROOT_PW; echo
    fi
fi

# =============================================================
# 八、导入数据库初始化 SQL（幂等：绝大多数迁移自带 IF NOT EXISTS）
# =============================================================
MIGRATIONS_DIR="$SRV_DIR/migrations"
if [ -d "$MIGRATIONS_DIR" ]; then
    info "创建数据库 $MYSQL_DB（不存在时）并按序导入 migrations/*.sql ..."
    export MYSQL_PWD="$MYSQL_ROOT_PW"   # 走环境变量，避免命令行暴露密码
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" \
        -e "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    for f in "$MIGRATIONS_DIR"/*.sql; do
        # --force：单条迁移重复执行报错时继续跑下一条（003 等含 ALTER 的迁移重跑会报重复列，属预期）
        if mysql --force -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" "$MYSQL_DB" < "$f"; then
            info "SQL 导入完成: $(basename "$f")"
        else
            warn "SQL 导入有告警（已跳过重复项）: $(basename "$f")"
        fi
    done
    unset MYSQL_PWD
    info "数据库初始化完成（api 启动时还会自动做一次幂等迁移，双保险）"
else
    warn "未找到 $MIGRATIONS_DIR，跳过 SQL 导入（api 启动时也会自动迁移）"
fi

# =============================================================
# 九、写 systemd 服务单元（api + gateway 两个进程）并启动
# =============================================================
write_unit() { # $1=服务名 $2=描述 $3=二进制
    local unit="$SYSTEMD_DIR/$1.service"
    bak "$unit"
    cat > "$unit" <<EOF
# 由 deploy/bt_deploy.sh 生成
[Unit]
Description=$2
After=network.target mysqld.service redis.service

[Service]
Type=simple
WorkingDirectory=$SRV_DIR
ExecStart=$3
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable "$1" >/dev/null 2>&1
    systemctl restart "$1"
    info "服务已部署并启动: $1（ WorkingDirectory=$SRV_DIR，Go 程序会从工作目录向上加载 .env ）"
}

if [ -x "$API_BIN" ]; then
    write_unit "im-server"  "IM API 服务 (gin, :$HTTP_PORT)"   "$API_BIN"
else
    warn "跳过 im-server 服务：二进制不存在"
fi
if [ -x "$GW_BIN" ]; then
    write_unit "im-gateway" "IM WebSocket 网关 (:${WS_PORT})" "$GW_BIN"
else
    warn "跳过 im-gateway 服务：二进制不存在"
fi

# =============================================================
# 十、生成宝塔 Nginx 站点配置（基于 deploy/nginx-*.conf，改本机上游）
# =============================================================
mkdir -p "$BT_VHOST_DIR"

gen_vhost() { # $1=站点名 $2=端口 $3=heredoc内容文件
    local dest="$BT_VHOST_DIR/$1.conf"
    bak "$dest"
    cp "$3" "$dest"
    info "已生成站点配置: $dest"
}

TMP_CONF="$(mktemp)"

# ---- 工作台 Web（对应 deploy/nginx-web.conf，端口 8081）----
if [ -f "$WEB_DIST/index.html" ]; then
    cat > "$TMP_CONF" <<EOF
# 工作台 Web：静态资源 + API 反代 + WS 反代（由 bt_deploy.sh 生成，源自 deploy/nginx-web.conf）
server {
    listen $WEB_PORT;
    root $WEB_DIST;
    index index.html;

    # SPA 路由
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # REST API 反代到本机 api
    location /api/ {
        proxy_pass http://127.0.0.1:$HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # WebSocket 反代到本机 gateway
    location /ws {
        proxy_pass http://127.0.0.1:$WS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
    }
}
EOF
    gen_vhost "im-web" "$WEB_PORT" "$TMP_CONF"
fi

# ---- 管理后台（对应 deploy/nginx-admin.conf，端口 8082；入口 admin.html）----
cat > "$TMP_CONF" <<EOF
# 管理后台（独立站点）：入口为 admin.html（由 bt_deploy.sh 生成，源自 deploy/nginx-admin.conf）
server {
    listen $ADMIN_PORT;
    root $WEB_DIST;
    index admin.html;

    location = / {
        try_files /admin.html =404;
    }

    location / {
        try_files \$uri \$uri/ /admin.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:$HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
gen_vhost "im-admin" "$ADMIN_PORT" "$TMP_CONF"
if [ ! -f "$WEB_DIST/admin.html" ]; then
    warn "im-web/dist 中暂无 admin.html（后台前端产物），im-admin 站点就绪后访问会 404，构建/上传 admin 产物后即可用"
fi

# ---- Flutter H5（对应 deploy/nginx-h5.conf，端口 8090，可选）----
if [ -f "$H5_DIST/index.html" ]; then
    cat > "$TMP_CONF" <<EOF
# Flutter H5 静态托管 + 同源 API/WS 反代（由 bt_deploy.sh 生成，源自 deploy/nginx-h5.conf）
server {
    listen $H5_PORT;
    root $H5_DIST;
    index index.html;

    location /api {
        proxy_pass http://127.0.0.1:$HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 60s;
    }

    location /ws {
        proxy_pass http://127.0.0.1:$WS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
    gen_vhost "im-h5" "$H5_PORT" "$TMP_CONF"
fi

# ---- PC 网页版（对应 deploy/nginx-pc.conf，端口 8091，可选）----
if [ -f "$PC_DIST/index.html" ]; then
    cat > "$TMP_CONF" <<EOF
# PC 网页版（im-pc）：静态资源 + API/WS 同源反代（由 bt_deploy.sh 生成，源自 deploy/nginx-pc.conf）
server {
    listen $PC_PORT;
    server_name _;
    root $PC_DIST;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /assets/ {
        expires 7d;
        add_header Cache-Control "public";
    }

    location /api {
        proxy_pass http://127.0.0.1:$HTTP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /ws {
        proxy_pass http://127.0.0.1:$WS_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
EOF
    gen_vhost "im-pc" "$PC_PORT" "$TMP_CONF"
fi

rm -f "$TMP_CONF"

# ---- 重载 Nginx（宝塔的 nginx 在 PATH 时自动检测；否则提示手动重载）----
NGINX_BIN="$(command -v nginx 2>/dev/null || echo /www/server/nginx/sbin/nginx)"
if [ -x "$NGINX_BIN" ]; then
    if "$NGINX_BIN" -t; then
        "$NGINX_BIN" -s reload && info "Nginx 配置检测通过并已重载"
    else
        warn "Nginx 配置检测失败，请检查 $BT_VHOST_DIR 下新生成的 conf 后在宝塔面板重载 Nginx"
    fi
else
    warn "未找到 nginx 可执行文件，请在宝塔面板：软件商店 -> Nginx -> 重载配置"
fi

# =============================================================
# 十一、结果汇总
# =============================================================
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ -z "$SERVER_IP" ] && SERVER_IP="服务器IP"

echo
echo "=============================================================="
echo " 部署完成（或部分完成，请核对上方警告项）"
echo "=============================================================="
echo " 访问地址："
echo "   工作台 Web : http://$SERVER_IP:$WEB_PORT"
echo "   管理后台   : http://$SERVER_IP:$ADMIN_PORT  (入口 admin.html)"
[ -f "$H5_DIST/index.html" ] && echo "   移动端 H5  : http://$SERVER_IP:$H5_PORT"
[ -f "$PC_DIST/index.html" ] && echo "   PC 网页版  : http://$SERVER_IP:$PC_PORT"
echo
echo " 默认管理员账号: admin（密码为部署时输入值，或 .env 中 ADMIN_INIT_PASSWORD）"
echo
echo " 后续运维命令："
echo "   systemctl status im-server im-gateway   # 查看服务状态"
echo "   journalctl -u im-server -f              # 跟踪 api 日志"
echo "   journalctl -u im-gateway -f             # 跟踪 gateway 日志"
echo "   systemctl restart im-server im-gateway  # 重启"
echo "   systemctl stop im-server im-gateway     # 停止"
echo
echo " 安全提示："
echo "   1. 宝塔面板 -> 安全：放行 $HTTP_PORT $WS_PORT $WEB_PORT $ADMIN_PORT$([ -f "$H5_DIST/index.html" ] && echo " $H5_PORT")$([ -f "$PC_DIST/index.html" ] && echo " $PC_PORT") 端口"
echo "   2. 生产环境请把 ACCESS_NODES 里的 127.0.0.1 改成公网域名/IP（$ENV_FILE）"
echo "   3. MinIO/MongoDB 目前仅监听本机即可，如需对外请自行加防护"
echo "=============================================================="
