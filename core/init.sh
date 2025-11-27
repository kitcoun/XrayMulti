#!/bin/bash
# XrayMulti 初始化脚本
# 在容器启动时执行，加载配置但不阻塞主进程

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/opt/xraymulti/config/app.conf"
LOG_FILE="/var/log/xraymulti/init.log"

# 记录日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================="
log "XrayMulti 初始化开始"
log "========================================="

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log "配置已加载"
else
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 计算 cron 时间间隔（默认24小时 = 86400秒 = 1440分钟）
if [ -n "$SUBSCRIPTION_UPDATE_INTERVAL" ] && [ "$SUBSCRIPTION_UPDATE_INTERVAL" -gt 0 ]; then
    UPDATE_CRON_MINUTES=$((SUBSCRIPTION_UPDATE_INTERVAL / 60))
    # 如果间隔小于1小时，按分钟设置
    if [ "$UPDATE_CRON_MINUTES" -lt 60 ]; then
        CRON_SCHEDULE="*/${UPDATE_CRON_MINUTES} * * * *"
    # 如果是整小时，按小时设置
    elif [ $((UPDATE_CRON_MINUTES % 60)) -eq 0 ]; then
        UPDATE_CRON_HOURS=$((UPDATE_CRON_MINUTES / 60))
        CRON_SCHEDULE="0 */${UPDATE_CRON_HOURS} * * *"
    else
        # 其他情况按分钟设置
        CRON_SCHEDULE="*/${UPDATE_CRON_MINUTES} * * * *"
    fi
    
    log "配置订阅自动更新: 每 ${UPDATE_CRON_MINUTES} 分钟 (${SUBSCRIPTION_UPDATE_INTERVAL}秒)"
    
    # 创建 crontab 文件
    cat > /etc/crontabs/root << EOF
# XrayMulti 自动更新订阅并重启 Xray
${CRON_SCHEDULE} /opt/xraymulti/core/sub.sh >> /var/log/xraymulti/cron.log 2>&1 && /opt/xraymulti/core/convert.sh >> /var/log/xraymulti/cron.log 2>&1 && killall -HUP xray >> /var/log/xraymulti/cron.log 2>&1

EOF
    
    # 启动 crond
    if command -v crond &> /dev/null; then
        crond -b -l 2
        log "cron 守护进程已启动"
    fi
else
    log "警告: 未配置订阅更新间隔，跳过自动更新设置"
fi

# 首次启动时自动更新订阅和配置
if [ -n "$SUBSCRIPTION_URL" ]; then
    log "首次启动，开始更新订阅..."
    "$SCRIPT_DIR/sub.sh" "$SUBSCRIPTION_URL" && \
    log "订阅更新成功，转换配置..." && \
    "$SCRIPT_DIR/convert.sh" && \
    log "配置转换完成" || \
    log "警告: 初始化订阅失败，请手动运行 xraymulti update"
else
    log "警告: 未配置订阅URL，跳过初始更新"
fi

log "初始化完成"
log "========================================="

exit 0
