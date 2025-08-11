#!/bin/bash

# ClickHouse Server 健康检查脚本
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

# 配置参数
CONFIG_FILE="health-check.conf"
LOG_FILE="/opt/clickhouse/logs/health-check.log"
ALERT_EMAIL=""
ALERT_THRESHOLD_MEMORY=80  # 内存使用率阈值(%)
ALERT_THRESHOLD_CONNECTIONS=100  # 连接数阈值
ALERT_THRESHOLD_DISK=80  # 磁盘使用率阈值(%)
ALERT_THRESHOLD_SLOW_QUERIES=10  # 慢查询阈值

# 默认配置
DEFAULT_USER="admin"
DEFAULT_PASSWORD="Admin_2024_Secure!"
MAX_RETRIES=3
HEALTH_CHECK_TIMEOUT=30

echo "=== ClickHouse Server 健康检查 ==="
echo "检查时间: $(date)"
echo ""

# 加载配置文件
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        echo "使用默认配置"
    fi
}

# 日志函数
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# 检测操作系统类型
detect_os() {
    log_message "INFO" "检测操作系统类型..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="rhel"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    elif [ -f /etc/debian_version ]; then
        OS_NAME="debian"
        OS_VERSION=$(cat /etc/debian_version)
    else
        log_message "ERROR" "无法检测操作系统类型"
        return 1
    fi
    
    log_message "INFO" "检测到操作系统: $OS_NAME $OS_VERSION"
    return 0
}

# 检查服务状态
check_service_status() {
    log_message "INFO" "检查服务状态..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if systemctl is-active --quiet clickhouse-server; then
            log_message "SUCCESS" "服务运行正常"
            return 0
        else
            retries=$((retries + 1))
            log_message "WARNING" "服务未运行，尝试启动 (第$retries次)"
            
            if [ $retries -eq 1 ]; then
                systemctl start clickhouse-server
                sleep $HEALTH_CHECK_TIMEOUT
            else
                sleep 5
            fi
        fi
    done
    
    log_message "ERROR" "服务启动失败，已尝试$MAX_RETRIES次"
    return 1
}

# 检查端口监听
check_ports() {
    log_message "INFO" "检查端口监听..."
    
    # 检查HTTP端口
    local http_port=$(netstat -tlnp | grep -c ":8123 " || echo "0")
    if [ "$http_port" -gt 0 ]; then
        log_message "SUCCESS" "HTTP端口(8123)监听正常"
    else
        log_message "ERROR" "HTTP端口(8123)未监听"
        return 1
    fi
    
    # 检查Native端口
    local native_port=$(netstat -tlnp | grep -c ":9000 " || echo "0")
    if [ "$native_port" -gt 0 ]; then
        log_message "SUCCESS" "Native端口(9000)监听正常"
    else
        log_message "ERROR" "Native端口(9000)未监听"
        return 1
    fi
    
    return 0
}

# 检查数据库连接
check_database_connection() {
    log_message "INFO" "检查数据库连接..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
            --query "SELECT 1" > /dev/null 2>&1; then
            log_message "SUCCESS" "数据库连接正常"
            return 0
        else
            retries=$((retries + 1))
            log_message "WARNING" "数据库连接失败，重试中 (第$retries次)"
            sleep 5
        fi
    done
    
    log_message "ERROR" "数据库连接失败，已尝试$MAX_RETRIES次"
    return 1
}

# 检查系统表
check_system_tables() {
    log_message "INFO" "检查系统表..."
    
    local table_count=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.tables" 2>/dev/null || echo "0")
    
    if [ "$table_count" -gt 0 ]; then
        log_message "SUCCESS" "系统表访问正常，表数量: $table_count"
        return 0
    else
        log_message "ERROR" "系统表访问失败"
        return 1
    fi
}

# 检查内存使用
check_memory_usage() {
    log_message "INFO" "检查内存使用..."
    
    local memory_usage=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT value FROM system.metrics WHERE metric = 'MemoryUsage'" 2>/dev/null || echo "0")
    
    local memory_tracking=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT value FROM system.metrics WHERE metric = 'MemoryTracking'" 2>/dev/null || echo "0")
    
    if [ "$memory_tracking" -gt 0 ]; then
        local memory_percent=0
        if [ "$memory_tracking" -gt 0 ]; then
            memory_percent=$(echo "scale=2; $memory_usage * 100 / $memory_tracking" | bc 2>/dev/null || echo "0")
        fi
        
        log_message "INFO" "服务器分配的总内存量: $memory_usage bytes"
        log_message "INFO" "内存使用率: ${memory_percent}%"
        
        # 检查内存告警阈值
        if [ "$(echo "$memory_percent > $ALERT_THRESHOLD_MEMORY" | bc 2>/dev/null || echo "0")" -eq 1 ]; then
            log_message "WARNING" "内存使用率过高: ${memory_percent}%"
            return 1
        fi
        
        return 0
    else
        log_message "ERROR" "无法获取服务器分配的总内存量"
        return 1
    fi
}

# 检查连接数
check_connections() {
    log_message "INFO" "检查连接数..."
    
    local connections=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.processes" 2>/dev/null || echo "0")
    
    log_message "INFO" "当前连接数: $connections"
    
    # 检查连接数告警阈值
    if [ "$connections" -gt "$ALERT_THRESHOLD_CONNECTIONS" ]; then
        log_message "WARNING" "连接数过多: $connections"
        return 1
    fi
    
    return 0
}

# 检查磁盘使用
check_disk_usage() {
    log_message "INFO" "检查磁盘使用..."
    
    # 检查数据目录
    if [ -d "/var/lib/clickhouse/" ]; then
        local disk_usage=$(du -sh /var/lib/clickhouse/ 2>/dev/null | awk '{print $1}' || echo "未知")
        log_message "INFO" "数据目录大小: $disk_usage"
    else
        log_message "ERROR" "数据目录不存在"
        return 1
    fi
    
    # 检查磁盘空间
    local disk_percent=$(df /var/lib/clickhouse/ | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_free=$(df -h /var/lib/clickhouse/ | tail -1 | awk '{print $4}')
    
    log_message "INFO" "可用磁盘空间: $disk_free"
    log_message "INFO" "磁盘使用率: ${disk_percent}%"
    
    # 检查磁盘告警阈值
    if [ "$disk_percent" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log_message "WARNING" "磁盘使用率过高: ${disk_percent}%"
        return 1
    fi
    
    return 0
}

# 检查慢查询
check_slow_queries() {
    log_message "INFO" "检查慢查询..."
    
    local slow_queries=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE query_duration_ms > 5000 AND event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    
    log_message "INFO" "过去1小时慢查询数量 (>5s): $slow_queries"
    
    # 检查慢查询告警阈值
    if [ "$slow_queries" -gt "$ALERT_THRESHOLD_SLOW_QUERIES" ]; then
        log_message "WARNING" "慢查询过多: $slow_queries 条"
        return 1
    fi
    
    return 0
}

# 检查错误日志
check_error_logs() {
    log_message "INFO" "检查错误日志..."
    
    local error_count=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.text_log WHERE level >= 'Error' AND event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    
    if [ "$error_count" -eq 0 ]; then
        log_message "SUCCESS" "无错误日志"
        return 0
    else
        log_message "WARNING" "发现 $error_count 条错误日志"
        
        # 显示最近的错误日志
        log_message "INFO" "最近错误日志:"
        clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
            --query "SELECT event_time, message FROM system.text_log WHERE level >= 'Error' ORDER BY event_time DESC LIMIT 5" \
            2>/dev/null || log_message "WARNING" "无法获取错误日志详情"
        
        return 1
    fi
}

# 检查防火墙状态
check_firewall() {
    log_message "INFO" "检查防火墙状态..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v firewall-cmd &> /dev/null; then
                if firewall-cmd --list-ports | grep -q "8123/tcp"; then
                    log_message "SUCCESS" "防火墙端口8123已开放"
                else
                    log_message "WARNING" "防火墙端口8123未开放"
                fi
                if firewall-cmd --list-ports | grep -q "9000/tcp"; then
                    log_message "SUCCESS" "防火墙端口9000已开放"
                else
                    log_message "WARNING" "防火墙端口9000未开放"
                fi
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                if ufw status | grep -q "8123"; then
                    log_message "SUCCESS" "UFW端口8123已开放"
                else
                    log_message "WARNING" "UFW端口8123未开放"
                fi
                if ufw status | grep -q "9000"; then
                    log_message "SUCCESS" "UFW端口9000已开放"
                else
                    log_message "WARNING" "UFW端口9000未开放"
                fi
            fi
            ;;
    esac
    
    return 0
}

# 检查系统资源
check_system_resources() {
    log_message "INFO" "检查系统资源..."
    
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    log_message "INFO" "CPU使用率: ${cpu_usage}%"
    
    # 系统内存
    local mem_info=$(free -m | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    local mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc 2>/dev/null || echo "0")
    log_message "INFO" "系统内存使用率: ${mem_percent}%"
    
    # 系统负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    log_message "INFO" "系统负载: $load_avg"
    
    return 0
}

# 检查配置文件
check_configuration() {
    log_message "INFO" "检查配置文件..."
    
    local config_files=("/etc/clickhouse-server/config.xml" "/etc/clickhouse-server/users.xml")
    
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            if [ -r "$config_file" ]; then
                log_message "SUCCESS" "配置文件存在且可读: $config_file"
            else
                log_message "ERROR" "配置文件存在但不可读: $config_file"
                return 1
            fi
        else
            log_message "ERROR" "配置文件不存在: $config_file"
            return 1
        fi
    done
    
    return 0
}

# 生成健康报告
generate_health_report() {
    log_message "INFO" "生成健康检查报告..."
    
    echo ""
    echo "=== ClickHouse 健康检查报告 ==="
    echo "检查时间: $(date)"
    echo "操作系统: $OS_NAME $OS_VERSION"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo ""
    
    # 服务状态摘要
    echo "服务状态摘要:"
    echo "- 服务状态: $(systemctl is-active clickhouse-server)"
    echo "- HTTP端口: $(netstat -tlnp | grep ':8123' | wc -l) 个监听"
    echo "- Native端口: $(netstat -tlnp | grep ':9000' | wc -l) 个监听"
    echo ""
    
    # 性能指标摘要
    echo "性能指标摘要:"
    echo "- 连接数: $connections"
    echo "- 内存使用率: ${memory_percent}%"
    echo "- 磁盘使用率: ${disk_percent}%"
    echo "- 慢查询数量: $slow_queries"
    echo "- 错误数量: $error_count"
    echo ""
    
    echo "=== 健康检查完成 ==="
}

# 发送告警
send_alert() {
    local message="$1"
    if [ -n "$ALERT_EMAIL" ]; then
        log_message "ALERT" "发送告警邮件到: $ALERT_EMAIL"
        echo "$message" | mail -s "ClickHouse健康检查告警" "$ALERT_EMAIL" 2>/dev/null || \
            log_message "WARNING" "无法发送告警邮件"
    fi
}

# 主函数
main() {
    local exit_code=0
    
    # 初始化
    load_config
    
    # 创建日志目录
    mkdir -p /opt/clickhouse/logs
    
    # 执行各项检查
    detect_os || exit_code=1
    check_service_status || exit_code=1
    check_ports || exit_code=1
    check_database_connection || exit_code=1
    check_system_tables || exit_code=1
    check_memory_usage || exit_code=1
    check_connections || exit_code=1
    check_disk_usage || exit_code=1
    check_slow_queries || exit_code=1
    check_error_logs || exit_code=1
    check_firewall || exit_code=1
    check_system_resources || exit_code=1
    check_configuration || exit_code=1
    
    # 生成报告
    generate_health_report
    
    # 如果有错误，发送告警
    if [ $exit_code -ne 0 ]; then
        send_alert "ClickHouse健康检查发现问题，请查看日志: $LOG_FILE"
    fi
    
    return $exit_code
}

# 清理函数
cleanup() {
    # 清理临时文件
    rm -f /tmp/clickhouse-health-check.tmp 2>/dev/null || true
}

# 设置信号处理
trap cleanup EXIT

# 执行主函数
main "$@" 