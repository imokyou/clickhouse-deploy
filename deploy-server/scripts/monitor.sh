#!/bin/bash

# ClickHouse Server 监控脚本
# 实时监控ClickHouse服务状态和性能指标

set -e

# 配置参数
CONFIG_FILE="monitor.conf"
LOG_FILE="/opt/clickhouse/logs/monitor_$(date +%Y%m%d).log"
ALERT_EMAIL=""
MONITOR_INTERVAL=30
ALERT_THRESHOLD_MEMORY=80  # 内存使用率阈值(%)
ALERT_THRESHOLD_CONNECTIONS=100  # 连接数阈值
ALERT_THRESHOLD_DISK=80  # 磁盘使用率阈值(%)
ALERT_THRESHOLD_SLOW_QUERIES=10  # 慢查询阈值
ALERT_THRESHOLD_CPU=90  # CPU使用率阈值(%)

# 默认配置
DEFAULT_USER="webuser"
DEFAULT_PASSWORD="WebUser_2024_Secure!"
MAX_RETRIES=3

echo "=== ClickHouse Server 监控脚本 ==="
echo "监控时间: $(date)"
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

# 创建日志目录
create_log_directory() {
    mkdir -p /opt/clickhouse/logs
}

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet clickhouse-server; then
        log_message "SUCCESS" "服务运行正常"
        return 0
    else
        log_message "ERROR" "服务未运行"
        return 1
    fi
}

# 检查内存使用
check_memory_usage() {
    local memory_usage=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT value FROM system.metrics WHERE metric = 'MemoryUsage'" 2>/dev/null || echo "0")
    
    local memory_tracking=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT value FROM system.metrics WHERE metric = 'MemoryTracking'" 2>/dev/null || echo "0")
    
    # 确保变量不为空且为数字
    memory_usage=${memory_usage:-0}
    memory_tracking=${memory_tracking:-0}
    
    if [ "$memory_tracking" -gt 0 ] && [ "$memory_usage" -ge 0 ]; then
        local memory_percent=$(echo "scale=2; $memory_usage * 100 / $memory_tracking" | bc 2>/dev/null || echo "0")
        # 确保百分比不为空
        memory_percent=${memory_percent:-0}
        log_message "INFO" "内存使用: $memory_usage bytes (${memory_percent}%)"
        
        # 安全的数值比较
        if [ -n "$memory_percent" ] && [ "$(echo "$memory_percent > $ALERT_THRESHOLD_MEMORY" | bc 2>/dev/null || echo "0")" -eq 1 ]; then
            log_message "WARNING" "内存使用过高: ${memory_percent}%"
            return 1
        fi
        return 0
    else
        log_message "ERROR" "无法获取内存使用信息"
        return 1
    fi
}

# 检查连接数
check_connections() {
    local connections=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.processes" 2>/dev/null || echo "0")
    
    # 确保连接数不为空且为数字
    connections=${connections:-0}
    
    log_message "INFO" "连接数: $connections"
    
    # 安全的数值比较
    if [ -n "$connections" ] && [ "$connections" -gt "$ALERT_THRESHOLD_CONNECTIONS" ]; then
        log_message "WARNING" "连接数过多: $connections"
        return 1
    fi
    return 0
}

# 检查磁盘使用
check_disk_usage() {
    local disk_percent=$(df /var/lib/clickhouse | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_free=$(df -h /var/lib/clickhouse | tail -1 | awk '{print $4}')
    
    # 确保磁盘使用率不为空且为数字
    disk_percent=${disk_percent:-0}
    disk_free=${disk_free:-未知}
    
    log_message "INFO" "磁盘使用率: ${disk_percent}% (可用: $disk_free)"
    
    # 安全的数值比较
    if [ -n "$disk_percent" ] && [ "$disk_percent" -gt "$ALERT_THRESHOLD_DISK" ]; then
        log_message "WARNING" "磁盘使用率过高: ${disk_percent}%"
        return 1
    fi
    return 0
}

# 检查慢查询
check_slow_queries() {
    local slow_queries=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE query_duration_ms > 5000 AND event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    
    # 确保慢查询数不为空且为数字
    slow_queries=${slow_queries:-0}
    
    log_message "INFO" "慢查询数量 (>5s): $slow_queries"
    
    # 安全的数值比较
    if [ -n "$slow_queries" ] && [ "$slow_queries" -gt "$ALERT_THRESHOLD_SLOW_QUERIES" ]; then
        log_message "WARNING" "慢查询过多: $slow_queries 条"
        return 1
    fi
    return 0
}

# 检查错误日志
check_error_logs() {
    local error_count=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.text_log WHERE level >= 'Error' AND event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    
    # 确保错误数不为空且为数字
    error_count=${error_count:-0}
    
    if [ -n "$error_count" ] && [ "$error_count" -gt 0 ]; then
        log_message "WARNING" "发现错误日志: $error_count 条"
        return 1
    else
        log_message "SUCCESS" "无错误日志"
        return 0
    fi
}

# 检查端口监听
check_ports() {
    local http_port=$(netstat -tlnp | grep -c ":8123 " || echo "0")
    local native_port=$(netstat -tlnp | grep -c ":9000 " || echo "0")
    
    # 确保端口数不为空且为数字
    http_port=${http_port:-0}
    native_port=${native_port:-0}
    
    if [ -n "$http_port" ] && [ "$http_port" -eq 0 ]; then
        log_message "ERROR" "HTTP端口未监听"
        return 1
    fi
    
    if [ -n "$native_port" ] && [ "$native_port" -eq 0 ]; then
        log_message "ERROR" "Native端口未监听"
        return 1
    fi
    
    log_message "SUCCESS" "端口监听正常"
    return 0
}

# 检查系统资源
check_system_resources() {
    # CPU使用率
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    # 确保CPU使用率不为空且为数字
    cpu_usage=${cpu_usage:-0}
    log_message "INFO" "CPU使用率: ${cpu_usage}%"
    
    # 安全的数值比较
    if [ -n "$cpu_usage" ] && [ "$(echo "$cpu_usage > $ALERT_THRESHOLD_CPU" | bc 2>/dev/null || echo "0")" -eq 1 ]; then
        log_message "WARNING" "CPU使用率过高: ${cpu_usage}%"
        return 1
    fi
    
    # 系统内存
    local mem_info=$(free -m | grep Mem)
    local mem_total=$(echo $mem_info | awk '{print $2}')
    local mem_used=$(echo $mem_info | awk '{print $3}')
    # 确保内存值不为空且为数字
    mem_total=${mem_total:-1}
    mem_used=${mem_used:-0}
    local mem_percent=$(echo "scale=2; $mem_used * 100 / $mem_total" | bc 2>/dev/null || echo "0")
    mem_percent=${mem_percent:-0}
    log_message "INFO" "系统内存使用率: ${mem_percent}%"
    
    # 系统负载
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    load_avg=${load_avg:-0}
    log_message "INFO" "系统负载: $load_avg"
    
    return 0
}

# 生成性能报告
generate_performance_report() {
    log_message "INFO" "生成性能报告..."
    
    # 查询统计
    local query_stats=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            count() as total_queries,
            avg(query_duration_ms) as avg_duration,
            max(query_duration_ms) as max_duration,
            sum(read_bytes) as total_read,
            sum(written_bytes) as total_written
        FROM system.query_log 
        WHERE event_date >= today()
        " 2>/dev/null || echo "0,0,0,0,0")
    
    log_message "INFO" "查询统计: $query_stats"
    
    # 表大小统计
    local table_stats=$(clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            database,
            table,
            formatReadableSize(total_bytes) as size,
            total_rows
        FROM system.tables
        WHERE database NOT IN ('system', 'information_schema')
        ORDER BY total_bytes DESC
        LIMIT 5
        " 2>/dev/null || echo "无数据")
    
    log_message "INFO" "表大小统计: $table_stats"
    
    return 0
}

# 获取详细性能指标
get_detailed_metrics() {
    echo ""
    echo "=== 详细性能指标 ==="
    
    # 查询性能统计
    clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            'Total Queries Today' as metric,
            toString(count()) as value
        FROM system.query_log 
        WHERE event_date >= today()
        
        UNION ALL
        
        SELECT 
            'Avg Query Duration' as metric,
            concat(toString(round(avg(query_duration_ms), 2)), ' ms') as value
        FROM system.query_log 
        WHERE event_date >= today()
        
        UNION ALL
        
        SELECT 
            'Max Query Duration' as metric,
            concat(toString(max(query_duration_ms)), ' ms') as value
        FROM system.query_log 
        WHERE event_date >= today()
        
        UNION ALL
        
        SELECT 
            'Total Read Bytes' as metric,
            formatReadableSize(sum(read_bytes)) as value
        FROM system.query_log 
        WHERE event_date >= today()
        
        UNION ALL
        
        SELECT 
            'Total Written Bytes' as metric,
            formatReadableSize(sum(written_bytes)) as value
        FROM system.query_log 
        WHERE event_date >= today()
        
        UNION ALL
        
        SELECT 
            'Active Queries' as metric,
            toString(count()) as value
        FROM system.processes
        WHERE query_id != currentQueryID()
        " 2>/dev/null || log_message "WARNING" "无法获取详细性能指标"
}

# 获取表信息
get_table_information() {
    echo ""
    echo "=== 表信息 ==="
    
    clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            database,
            table,
            formatReadableSize(total_bytes) as size,
            toString(total_rows) as rows,
            engine
        FROM system.tables
        WHERE database NOT IN ('system', 'information_schema')
        ORDER BY total_bytes DESC
        LIMIT 10
        " 2>/dev/null || log_message "WARNING" "无法获取表信息"
}

# 获取系统指标
get_system_metrics() {
    echo ""
    echo "=== 系统指标 ==="
    
    clickhouse-client --user="$DEFAULT_USER" --password="$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            metric,
            toString(value) as value
        FROM system.metrics
        WHERE metric IN (
            'MemoryTracking',
            'MemoryUsage',
            'TCPConnections',
            'HTTPConnections',
            'Query',
            'SelectQuery',
            'InsertQuery',
            'FailedQuery',
            'FailedSelectQuery',
            'FailedInsertQuery'
        )
        ORDER BY metric
        " 2>/dev/null || log_message "WARNING" "无法获取系统指标"
}

# 发送告警
send_alert() {
    local message="$1"
    if [ -n "$ALERT_EMAIL" ]; then
        log_message "ALERT" "发送告警邮件到: $ALERT_EMAIL"
        echo "$message" | mail -s "ClickHouse监控告警" "$ALERT_EMAIL" 2>/dev/null || \
            log_message "WARNING" "无法发送告警邮件"
    fi
}

# 生成监控报告
generate_monitor_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "=== 监控报告 ==="
    echo "监控时间: $timestamp"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo "监控间隔: ${MONITOR_INTERVAL}秒"
    echo ""
}

# 单次检查模式
single_check() {
    log_message "INFO" "执行单次监控检查"
    
    check_service_status
    check_memory_usage
    check_connections
    check_disk_usage
    check_slow_queries
    check_error_logs
    check_ports
    check_system_resources
    generate_performance_report
    get_detailed_metrics
    get_table_information
    get_system_metrics
    generate_monitor_report
    
    log_message "INFO" "单次检查完成"
}

# 持续监控模式
continuous_monitor() {
    log_message "INFO" "启动持续监控模式，间隔: ${MONITOR_INTERVAL}秒"
    
    while true; do
        clear
        echo "=== ClickHouse 实时监控 ==="
        echo "按 Ctrl+C 退出监控"
        echo ""
        
        # 执行各项检查
        check_service_status
        check_memory_usage
        check_connections
        check_disk_usage
        check_slow_queries
        check_error_logs
        check_ports
        check_system_resources
        generate_performance_report
        get_detailed_metrics
        get_table_information
        get_system_metrics
        generate_monitor_report
        
        echo ""
        echo "=== 监控信息 ==="
        echo "监控时间: $(date)"
        echo "下次更新: ${MONITOR_INTERVAL}秒后"
        echo ""
        
        # 等待指定时间后更新
        sleep $MONITOR_INTERVAL
    done
}

# 主监控逻辑
main_monitor() {
    local alerts=0
    
    log_message "INFO" "开始监控检查..."
    
    # 检查各项指标
    check_service_status || ((alerts++))
    check_memory_usage || ((alerts++))
    check_connections || ((alerts++))
    check_disk_usage || ((alerts++))
    check_slow_queries || ((alerts++))
    check_error_logs || ((alerts++))
    check_ports || ((alerts++))
    check_system_resources || ((alerts++))
    
    # 生成性能报告
    generate_performance_report
    
    # 如果有告警，发送通知
    if [ $alerts -gt 0 ]; then
        send_alert "ClickHouse监控发现 $alerts 个问题"
        log_message "WARNING" "监控完成，发现 $alerts 个问题"
    else
        log_message "SUCCESS" "监控完成，系统运行正常"
    fi
    
    return 0
}

# 清理旧日志
cleanup_old_logs() {
    # 保留最近7天的日志
    find /opt/clickhouse/logs -name "monitor_*.log" -mtime +7 -delete 2>/dev/null || true
}

# 清理函数
cleanup() {
    log_message "INFO" "监控脚本退出，清理资源"
    # 清理临时文件
    rm -f /tmp/clickhouse-monitor.tmp 2>/dev/null || true
}

# 设置信号处理
trap cleanup EXIT INT TERM

# 主函数
main() {
    # 初始化
    load_config
    create_log_directory
    
    # 检查参数
    if [ "$1" = "--once" ]; then
        # 单次检查模式
        single_check
    elif [ "$1" = "--daemon" ]; then
        # 后台监控模式
        log_message "INFO" "启动后台监控模式"
        while true; do
            main_monitor
            sleep $MONITOR_INTERVAL
        done
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --once    执行单次检查"
        echo "  --daemon  启动后台监控模式"
        echo "  --help    显示帮助信息"
        echo "  无参数    启动持续监控模式"
        exit 0
    else
        # 持续监控模式
        continuous_monitor
    fi
    
    # 清理旧日志
    cleanup_old_logs
}

# 执行主函数
main "$@" 