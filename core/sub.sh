#!/bin/bash
# XrayMulti 订阅更新脚本
# 功能：从订阅URL获取配置并保存

# 代理
# set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/xraymulti/sub.log"
CONFIG_FILE="/opt/xraymulti/config/app.conf"

# 记录日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 如果环境变量不存在，尝试加载配置文件
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    export SUBSCRIPTION_FILE="${SUBSCRIPTION_FILE:-/opt/xraymulti/config/subscription.json}"
fi

# 检查参数
SUBSCRIPTION_URL="${1:-$SUBSCRIPTION_URL}"

if [ -z "$SUBSCRIPTION_URL" ]; then
    log "错误: 未提供订阅URL"
    echo "用法: $0 <订阅URL>"
    exit 1
fi

log "========================================="
log "开始更新订阅"
log "========================================="
log "订阅URL: ${SUBSCRIPTION_URL:0:50}..."

# 创建临时文件
TEMP_FILE="/tmp/subscription_$(date +%s).tmp"

# 下载订阅
log "正在下载订阅..."
if curl -s --max-time 60 "$SUBSCRIPTION_URL" -o "$TEMP_FILE"; then
    log "订阅下载成功"
else
    log "错误: 订阅下载失败"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 检测内容类型并处理
FIRST_LINE=$(head -n 1 "$TEMP_FILE")

# 判断是否为base64编码
if echo "$FIRST_LINE" | grep -qE '^[A-Za-z0-9+/=]+$' && [ ${#FIRST_LINE} -gt 100 ]; then
    log "检测到base64编码，正在解码..."
    base64 -d "$TEMP_FILE" > "${TEMP_FILE}.decoded"
    mv "${TEMP_FILE}.decoded" "$TEMP_FILE"
fi

# 验证JSON格式
if jq empty "$TEMP_FILE" > /dev/null 2>&1; then
    log "订阅格式验证通过 (JSON)"
    
    # 确保订阅目录存在
    mkdir -p "$(dirname "$SUBSCRIPTION_FILE")"
    
    # 保存新订阅
    mv "$TEMP_FILE" "$SUBSCRIPTION_FILE"
    log "订阅已保存到: $SUBSCRIPTION_FILE"
    
    # 统计配置数量
    NODE_COUNT=$(jq 'length' "$SUBSCRIPTION_FILE" 2>/dev/null || echo "0")
    log "订阅包含 $NODE_COUNT 个配置"
    
    log "========================================="
    log "订阅更新完成"
    log "========================================="
else
    log "错误: 不支持的订阅格式，需要 JSON 数组"
    log "内容预览: $(head -n 3 "$TEMP_FILE")"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 清理临时文件
rm -f "$TEMP_FILE"

exit 0
