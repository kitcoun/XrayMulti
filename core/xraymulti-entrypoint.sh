#!/bin/sh
# XrayMulti 入口点脚本
# 执行初始化，然后启动 Xray

set -e

echo "[XrayMulti] 正在初始化..."
/opt/xraymulti/core/init.sh

echo "[XrayMulti] 初始化完成，启动 Xray 服务..."
# 使用 exec 执行 CMD
exec "$@"