#!/bin/bash

# ClickHouse Docker 监控脚本
# 实时监控ClickHouse服务状态和性能指标

set -e

# 配置参数
CONFIG_FILE="monitor.conf"
LOG_FILE="/tmp/clickhouse-monitor.log"
ALERT_EMAIL=""
DOCKER_COMPOSE_FILE="docker-compose.yml"
MONITOR_INTERVAL=30
ALERT_THRESHOLD_MEMORY=80  # 内存使用率阈值(%)
ALERT_THRESHOLD_CONNECTIONS=100  # 连接数阈值
ALERT_THRESHOLD_SLOW_QUERIES=10  # 慢查询阈值

# 默认配置
DEFAULT_USER="default"
DEFAULT_PASSWORD="clickhouse123"
MAX_RETRIES=3

echo "=== ClickHouse Docker 服务监控 ==="
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

# 检查Docker Compose命令
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        log_message "ERROR" "Docker Compose未安装"
        return 1
    fi
    
    # 验证Docker Compose文件
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_message "ERROR" "Docker Compose文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    return 0
}

# 检查服务状态
check_service_status() {
    if $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
        log_message "SUCCESS" "ClickHouse服务正在运行"
        return 0
    else
        log_message "ERROR" "ClickHouse服务未运行"
        return 1
    fi
}

# 检查连接状态
check_connection() {
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if $COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
            -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
            --query "SELECT 1" > /dev/null 2>&1; then
            log_message "SUCCESS" "数据库连接正常"
            return 0
        else
            retries=$((retries + 1))
            log_message "WARNING" "数据库连接失败，重试中 (第$retries次)"
            sleep 2
        fi
    done
    
    log_message "ERROR" "数据库连接失败，已尝试$MAX_RETRIES次"
    return 1
}

# 获取性能指标
get_performance_metrics() {
    # 查询数量
    local query_count=$($COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    
    # 慢查询数量
    local slow_query_count=$($COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE event_time >= now() - INTERVAL 1 HOUR AND query_duration_ms > 1000" \
        2>/dev/null || echo "0")
    
    # 连接数
    local connection_count=$($COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.processes" \
        2>/dev/null || echo "0")
    
    # 错误数量
    local error_count=$($COMPOSE_CMD logs clickhouse-server 2>&1 | grep -c "ERROR\|Exception" || echo "0")
    
    # 内存使用率
    local memory_usage=$($COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            round(
                100.0 * memory_usage / (
                    SELECT value FROM system.metrics WHERE metric = 'MemoryTracking'
                ), 2
            ) as memory_percent
        FROM system.processes 
        WHERE query_id = currentQueryID()
        " 2>/dev/null || echo "0")
    
    # 检查告警条件
    local alerts=()
    
    if [ "$connection_count" -gt "$ALERT_THRESHOLD_CONNECTIONS" ]; then
        alerts+=("连接数过多: $connection_count")
    fi
    
    if [ "$slow_query_count" -gt "$ALERT_THRESHOLD_SLOW_QUERIES" ]; then
        alerts+=("慢查询过多: $slow_query_count")
    fi
    
    if [ "$error_count" -gt 0 ]; then
        alerts+=("发现错误: $error_count")
    fi
    
    # 输出指标
    echo "=== 性能指标 ==="
    echo "过去1小时查询次数: $query_count"
    echo "过去1小时慢查询次数 (>1s): $slow_query_count"
    echo "当前连接数: $connection_count"
    echo "错误日志数量: $error_count"
    echo "内存使用率: ${memory_usage}%"
    
    # 输出告警
    if [ ${#alerts[@]} -gt 0 ]; then
        echo ""
        echo "⚠ 告警信息:"
        for alert in "${alerts[@]}"; do
            echo "- $alert"
        done
        
        # 发送告警
        send_alert "ClickHouse监控告警: ${alerts[*]}"
    fi
    
    # 显示最近错误日志
    if [ "$error_count" -gt 0 ]; then
        echo ""
        echo "⚠ 最近错误日志:"
        $COMPOSE_CMD logs clickhouse-server 2>&1 | grep "ERROR\|Exception" | tail -5
    fi
    
    return 0
}

# 获取资源使用情况
get_resource_usage() {
    echo ""
    echo "=== 资源使用情况 ==="
    
    # 容器资源使用
    echo "容器资源使用:"
    $COMPOSE_CMD exec clickhouse-server cat /proc/meminfo | grep -E "MemTotal|MemAvailable|MemUsed" || \
        log_message "WARNING" "无法获取内存信息"
    
    # ClickHouse内存使用详情
    echo ""
    echo "ClickHouse内存使用详情:"
    $COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            'Memory Usage' as metric,
            formatReadableSize(memory_usage) as value
        FROM system.processes 
        WHERE query_id = currentQueryID()
        
        UNION ALL
        
        SELECT 
            'Total Memory' as metric,
            formatReadableSize(value) as value
        FROM system.metrics 
        WHERE metric = 'MemoryTracking'
        
        UNION ALL
        
        SELECT 
            'MarkCache Hit Ratio' as metric,
            concat(
                toString(
                    100.0 * ProfileEvents['MarkCacheHits'] / 
                    greatest(ProfileEvents['MarkCacheHits'] + ProfileEvents['MarkCacheMisses'], 1)
                ),
                '%'
            ) as value
        FROM system.processes 
        WHERE query_id = currentQueryID()
        " 2>/dev/null || log_message "WARNING" "无法获取内存使用信息"
    
    # 磁盘使用
    echo ""
    echo "磁盘使用情况:"
    $COMPOSE_CMD exec clickhouse-server df -h /var/lib/clickhouse/ || \
        log_message "WARNING" "无法获取磁盘使用信息"
    
    return 0
}

# 获取查询统计
get_query_statistics() {
    echo ""
    echo "=== 查询统计 ==="
    
    $COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            'Total Queries' as metric,
            toString(count()) as value
        FROM system.query_log 
        WHERE event_time >= now() - INTERVAL 1 HOUR
        
        UNION ALL
        
        SELECT 
            'Avg Query Duration' as metric,
            concat(toString(round(avg(query_duration_ms), 2)), ' ms') as value
        FROM system.query_log 
        WHERE event_time >= now() - INTERVAL 1 HOUR
        
        UNION ALL
        
        SELECT 
            'Max Query Duration' as metric,
            concat(toString(max(query_duration_ms)), ' ms') as value
        FROM system.query_log 
        WHERE event_time >= now() - INTERVAL 1 HOUR
        
        UNION ALL
        
        SELECT 
            'Total Read Bytes' as metric,
            formatReadableSize(sum(read_bytes)) as value
        FROM system.query_log 
        WHERE event_time >= now() - INTERVAL 1 HOUR
        
        UNION ALL
        
        SELECT 
            'Total Written Bytes' as metric,
            formatReadableSize(sum(written_bytes)) as value
        FROM system.query_log 
        WHERE event_time >= now() - INTERVAL 1 HOUR
        " 2>/dev/null || log_message "WARNING" "无法获取查询统计信息"
}

# 获取表信息
get_table_information() {
    echo ""
    echo "=== 表信息 ==="
    
    $COMPOSE_CMD exec -T clickhouse-server clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            database,
            table,
            formatReadableSize(total_bytes) as size,
            toString(total_rows) as rows
        FROM system.tables
        WHERE database NOT IN ('system', 'information_schema')
        ORDER BY total_bytes DESC
        LIMIT 5
        " 2>/dev/null || log_message "WARNING" "无法获取表信息"
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
    echo "Docker Compose文件: $DOCKER_COMPOSE_FILE"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo "监控间隔: ${MONITOR_INTERVAL}秒"
    echo ""
}

# 单次检查模式
single_check() {
    log_message "INFO" "执行单次监控检查"
    
    check_service_status
    check_connection
    get_performance_metrics
    get_resource_usage
    get_query_statistics
    get_table_information
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
        check_connection
        get_performance_metrics
        get_resource_usage
        get_query_statistics
        get_table_information
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
    
    # 检查Docker Compose
    if ! check_docker_compose; then
        exit 1
    fi
    
    # 检查参数
    if [ "$1" = "--once" ]; then
        # 单次检查模式
        single_check
    elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "用法: $0 [选项]"
        echo "选项:"
        echo "  --once    执行单次检查"
        echo "  --help    显示帮助信息"
        echo "  无参数    启动持续监控模式"
        exit 0
    else
        # 持续监控模式
        continuous_monitor
    fi
}

# 执行主函数
main "$@" 