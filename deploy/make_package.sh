#!/usr/bin/env bash
# 一键组装宝塔部署包（在本地 Git Bash 运行）：
#   deploy/package/im-project/  →  deploy/im-project-server-<日期>.zip
# 前置条件：
#   1. 已完成 Go 交叉编译：im-server/bin/api、im-server/bin/gateway（Linux amd64）
#   2. 已完成前端构建：im-web/dist/index.html
set -e

# pwd -W 输出 Windows 原生路径（如 D:/im-project），避免 POSIX 路径被 MSYS 转错
ROOT="$(cd "$(dirname "$0")/.." && pwd -W)"
SRC="$ROOT/deploy/package/im-project"

# 0) 前置检查
MISS=0
for f in api gateway; do
  if [ ! -f "$ROOT/im-server/bin/$f" ]; then
    echo "[缺失] im-server/bin/$f —— 请先执行 Go 交叉编译命令"
    MISS=1
  fi
done
if [ ! -f "$ROOT/im-web/dist/index.html" ]; then
  echo "[缺失] im-web/dist/index.html —— 请先在 im-web 目录执行 npm run build"
  MISS=1
fi
[ "$MISS" = "0" ] || exit 1

# 1) 组装目录（镜像服务器 /www/wwwroot/im-project 结构）
rm -rf "$SRC"
mkdir -p "$SRC/im-server/bin" "$SRC/deploy" "$SRC/im-web"

# 2) Go 二进制
cp "$ROOT/im-server/bin/api" "$ROOT/im-server/bin/gateway" "$SRC/im-server/bin/"

# 3) 服务端源码 + 迁移 SQL + env 模板（不打包本地 .env，里面有密码）
cp "$ROOT/im-server/go.mod" "$ROOT/im-server/go.sum" "$SRC/im-server/"
cp -r "$ROOT/im-server/cmd" "$ROOT/im-server/internal" "$ROOT/im-server/migrations" "$SRC/im-server/"
cp "$ROOT/im-server/.env.example" "$SRC/im-server/"

# 4) 前端构建产物
cp -r "$ROOT/im-web/dist" "$SRC/im-web/dist"

# 5) 部署脚本与配置（用通配符避免中文文件名转码问题）
for f in "$ROOT/deploy/"*.sh "$ROOT/deploy/"*.conf "$ROOT/deploy/"*.md; do
  [ -f "$f" ] && cp "$f" "$SRC/deploy/"
done

# 6) 压缩（优先 Python zipfile：正斜杠 + UTF-8 文件名，Linux unzip 才不出乱码）
cd "$ROOT/deploy/package"
ZIP="im-project-server-$(date +%Y%m%d).zip"
rm -f "$ROOT/deploy/$ZIP"
if command -v python >/dev/null 2>&1; then
  python "$ROOT/deploy/zipdir.py" "$ROOT/deploy/package" "$ROOT/deploy/$ZIP"
elif command -v python3 >/dev/null 2>&1; then
  python3 "$ROOT/deploy/zipdir.py" "$ROOT/deploy/package" "$ROOT/deploy/$ZIP"
elif command -v py >/dev/null 2>&1; then
  py -3 "$ROOT/deploy/zipdir.py" "$ROOT/deploy/package" "$ROOT/deploy/$ZIP"
else
  echo "[错误] 未找到 python/python3/py，无法生成 Linux 兼容 zip"
  exit 1
fi

echo "--------------------------------------------------"
echo "打包完成: deploy/$ZIP"
echo "上传到服务器 /www/wwwroot/ 解压，然后执行:"
echo "  cd /www/wwwroot/im-project/deploy && bash bt_deploy.sh"
