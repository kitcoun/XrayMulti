#!/bin/bash
# XrayMulti 主控制脚本
# 功能：统一管理订阅更新和配置重载

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="/opt/xraymulti/config/app.conf"

# 显示帮助信息
show_help() {
    cat << EOF
XrayMulti - Xray 多节点管理工具

用法: xraymulti <命令> [选项]

命令:
    update [URL]    更新订阅并重新加载配置
                    URL: 订阅地址（可选，默认使用配置文件中的地址）
    
    reload          重新加载配置（不更新订阅）
    
    status          查看服务状态
    
    logs            查看日志
    
    help            显示此帮助信息

示例:
    # 使用配置文件中的URL更新订阅
    xraymulti update
    
    # 使用指定URL更新订阅
    xraymulti update "https://example.com/sub"
    
    # 仅重新加载配置
    xraymulti reload
    
    # 查看服务状态
    xraymulti status

EOF
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        # 导出必要的变量
        export SUBSCRIPTION_FILE="${SUBSCRIPTION_FILE:-/opt/xraymulti/config/subscription.json}"
        export XRAY_CONFIG_FILE="${XRAY_CONFIG_FILE:-/etc/xray/config.json}"
    else
        echo "警告: 配置文件不存在 $CONFIG_FILE"
        # 使用默认值
        export SUBSCRIPTION_FILE="/opt/xraymulti/config/subscription.json"
        export XRAY_CONFIG_FILE="/etc/xray/config.json"
    fi
}

# 更新订阅
cmd_update() {
    local url="$1"
    
    echo "========================================"
    echo "XrayMulti - 更新订阅"
    echo "========================================"
    
    # 执行订阅更新
    if [ -n "$url" ]; then
        bash "$SCRIPT_DIR/sub.sh" "$url"
    else
        bash "$SCRIPT_DIR/sub.sh"
    fi
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "订阅更新成功，开始转换配置..."
        cmd_reload
    else
        echo "错误: 订阅更新失败"
        exit 1
    fi
}

# 重新加载配置
cmd_reload() {
    echo "========================================"
    echo "XrayMulti - 重新加载配置"
    echo "========================================"
    
    # 执行配置转换
    bash "$SCRIPT_DIR/convert.sh"

    killall -HUP xray
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "✓ 配置已成功加载并生效"
    else
        echo "✗ 配置加载失败"
        exit 1
    fi
}

# 查看状态
cmd_status() {
    echo "========================================"
    echo "XrayMulti - 服务状态"
    echo "========================================"
    
    load_config
    
    # 检查订阅文件
    if [ -f "$SUBSCRIPTION_FILE" ]; then
        local node_count=$(cat "$SUBSCRIPTION_FILE" | jq 'length' 2>/dev/null || echo "0")
        local sub_mtime=$(stat -c %y "$SUBSCRIPTION_FILE" 2>/dev/null | cut -d'.' -f1)
        echo "订阅状态: ✓ 已加载"
        echo "配置数量: $node_count"
        echo "更新时间: $sub_mtime"
    else
        echo "订阅状态: ✗ 未加载"
    fi
    
    echo ""
    
    # 检查Xray配置
    if [ -f "$XRAY_CONFIG_FILE" ]; then
        local cfg_mtime=$(stat -c %y "$XRAY_CONFIG_FILE" 2>/dev/null | cut -d'.' -f1)
        echo "配置状态: ✓ 已生成"
        echo "配置时间: $cfg_mtime"
    else
        echo "配置状态: ✗ 未生成"
    fi
    
    echo ""
    
    # 检查Xray进程
    if pgrep xray > /dev/null 2>&1; then
        echo "Xray服务: ✓ 运行中"
        echo "进程PID: $(pgrep xray)"
    else
        echo "Xray服务: ✗ 未运行"
    fi
    
    echo ""
}

# 查看日志
cmd_logs() {
    echo "========================================"
    echo "XrayMulti - 日志查看"
    echo "========================================"
    echo ""
    echo "1. 初始化日志"
    echo "2. 订阅更新日志"
    echo "3. 配置转换日志"
    echo "4. Xray运行日志"
    echo "0. 返回"
    echo ""
    read -p "请选择 [0-4]: " choice
    
    case $choice in
        1)
            tail -f /var/log/xraymulti/init.log
            ;;
        2)
            tail -f /var/log/xraymulti/sub.log
            ;;
        3)
            tail -f /var/log/xraymulti/convert.log
            ;;
        4)
            if command -v xlogs &> /dev/null; then
                xlogs
            else
                tail -f /var/log/supervisor/xray.out.log
            fi
            ;;
        0|*)
            return
            ;;
    esac
}

# 主函数
main() {
    local command="$1"
    shift || true
    
    case "$command" in
        update)
            cmd_update "$@"
            ;;
        reload)
            cmd_reload
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs
            ;;
        help|--help|-h|"")
            show_help
            ;;
        *)
            echo "错误: 未知命令 '$command'"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
