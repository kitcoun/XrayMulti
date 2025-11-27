#!/bin/bash
# XrayMulti 配置转换脚本
# 功能：将订阅配置转换为Xray配置并应用
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/xraymulti/convert.log"
CONFIG_FILE="/opt/xraymulti/config/app.conf"

# 记录日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 如果环境变量不存在，尝试加载配置文件
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    export SUBSCRIPTION_FILE="${SUBSCRIPTION_FILE:-/opt/xraymulti/config/subscription.json}"
    export XRAY_CONFIG_FILE="${XRAY_CONFIG_FILE:-/etc/xray/config.json}"
fi

log "========================================="
log "开始转换配置"
log "========================================="

# 检查订阅文件
if [ ! -f "$SUBSCRIPTION_FILE" ]; then
    log "错误: 订阅文件不存在: $SUBSCRIPTION_FILE"
    log "请先运行订阅更新: xraymulti update"
    exit 1
fi

# 解析订阅文件中的代理节点
log "正在解析订阅文件..."

# 使用 Dockerfile 中编译好的 Go 程序
CONVERT_BIN="${SCRIPT_DIR}/subconverter"

# 检查 Go 程序是否存在
if [ ! -f "$CONVERT_BIN" ]; then
    log "错误: subconverter 程序不存在"
    log "请确保 Docker 镜像构建正确"
    exit 1
fi

# 运行 Go 程序
"$CONVERT_BIN" \
    -subscription "$SUBSCRIPTION_FILE" \
    -config "$XRAY_CONFIG_FILE" \
    -loglevel "${XRAY_LOG_LEVEL:-warning}" \
    -inbounds "${INBOUNDS_JSON:-[]}" \
    -api-listen "${API_LISTEN:-127.0.0.1}" \
    -api-port "${API_PORT:-8080}" 2>&1 | tee -a "$LOG_FILE"

if [ $? -ne 0 ]; then
    log "错误: Go程序执行失败"
    exit 1
fi

log "========================================="
log "配置转换完成"
log "========================================="
log "配置文件已更新: ${XRAY_CONFIG_FILE:-/etc/xray/config.json}"

exit 0
