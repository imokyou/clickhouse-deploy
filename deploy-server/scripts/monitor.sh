#!/bin/bash

# ClickHouse Server 监控脚本

set -e

echo "=== ClickHouse 监控脚本 ==="

# 配置变量
LOG_FILE="/opt/clickhouse/logs/monitor_$(date +%Y%m%d).log"
ALERT_THRESHOLD_MEMORY=12884901888  # 12GB
ALERT_THRESHOLD_CONNECTIONS=100
ALERT_THRESHOLD_DISK=80  # 80%

# 创建日志目录
mkdir -p /opt/clickhouse/logs

# 记录监控时间
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] 开始监控检查..." >> $LOG_FILE

# 检查服务状态
check_service_status() {
    if systemctl is-active --quiet clickhouse-server; then
        echo "[$TIMESTAMP] ✓ 服务运行正常" >> $LOG_FILE
        return 0
    else
        echo "[$TIMESTAMP] ✗ 服务未运行" >> $LOG_FILE
        return 1
    fi
}

# 检查内存使用
check_memory_usage() {
    MEMORY_USAGE=$(clickhouse-client --query "
    SELECT value 
    FROM system.metrics 
    WHERE metric = 'MemoryUsage'
    " 2>/dev/null || echo "0")
    
    if [ "$MEMORY_USAGE" -gt "$ALERT_THRESHOLD_MEMORY" ]; then
        echo "[$TIMESTAMP] ⚠ 内存使用过高: $MEMORY_USAGE bytes" >> $LOG_FILE
        return 1
    else
        echo "[$TIMESTAMP] ✓ 内存使用正常: $MEMORY_USAGE bytes" >> $LOG_FILE
        return 0
    fi
}

# 检查连接数
check_connections() {
    CONNECTIONS=$(clickhouse-client --query "
    SELECT count() 
    FROM system.processes
    " 2>/dev/null || echo "0")
    
    if [ "$CONNECTIONS" -gt "$ALERT_THRESHOLD_CONNECTIONS" ]; then
        echo "[$TIMESTAMP] ⚠ 连接数过多: $CONNECTIONS" >> $LOG_FILE
        return 1
    else
        echo "[$TIMESTAMP] ✓ 连接数正常: $CONNECTIONS" >> $LOG_FILE
        return 0
    fi
}

# 检查磁盘使用
check_disk_usage() {
    DISK_USAGE=$(df /var/lib/clickhouse | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [ "$DISK_USAGE" -gt "$ALERT_THRESHOLD_DISK" ]; then
        echo "[$TIMESTAMP] ⚠ 磁盘使用率过高: ${DISK_USAGE}%" >> $LOG_FILE
        return 1
    else
        echo "[$TIMESTAMP] ✓ 磁盘使用率正常: ${DISK_USAGE}%" >> $LOG_FILE
        return 0
    fi
}

# 检查慢查询
check_slow_queries() {
    SLOW_QUERIES=$(clickhouse-client --query "
    SELECT count() 
    FROM system.query_log 
    WHERE query_duration_ms > 5000 
    AND event_time >= now() - INTERVAL 1 HOUR
    " 2>/dev/null || echo "0")
    
    if [ "$SLOW_QUERIES" -gt 10 ]; then
        echo "[$TIMESTAMP] ⚠ 慢查询过多: $SLOW_QUERIES 条" >> $LOG_FILE
        return 1
    else
        echo "[$TIMESTAMP] ✓ 慢查询正常: $SLOW_QUERIES 条" >> $LOG_FILE
        return 0
    fi
}

# 检查错误日志
check_error_logs() {
    ERROR_COUNT=$(clickhouse-client --query "
    SELECT count() 
    FROM system.text_log 
    WHERE level >= 'Error' 
    AND event_time >= now() - INTERVAL 1 HOUR
    " 2>/dev/null || echo "0")
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "[$TIMESTAMP] ⚠ 发现错误日志: $ERROR_COUNT 条" >> $LOG_FILE
        return 1
    else
        echo "[$TIMESTAMP] ✓ 无错误日志" >> $LOG_FILE
        return 0
    fi
}

# 检查端口监听
check_ports() {
    HTTP_PORT=$(netstat -tlnp | grep -c ":8123 " || echo "0")
    NATIVE_PORT=$(netstat -tlnp | grep -c ":9000 " || echo "0")
    
    if [ "$HTTP_PORT" -eq 0 ]; then
        echo "[$TIMESTAMP] ✗ HTTP端口未监听" >> $LOG_FILE
        return 1
    fi
    
    if [ "$NATIVE_PORT" -eq 0 ]; then
        echo "[$TIMESTAMP] ✗ Native端口未监听" >> $LOG_FILE
        return 1
    fi
    
    echo "[$TIMESTAMP] ✓ 端口监听正常" >> $LOG_FILE
    return 0
}

# 生成性能报告
generate_performance_report() {
    echo "[$TIMESTAMP] 生成性能报告..." >> $LOG_FILE
    
    # 查询统计
    QUERY_STATS=$(clickhouse-client --query "
    SELECT 
        count() as total_queries,
        avg(query_duration_ms) as avg_duration,
        max(query_duration_ms) as max_duration,
        sum(read_bytes) as total_read,
        sum(written_bytes) as total_written
    FROM system.query_log 
    WHERE event_date >= today()
    " 2>/dev/null || echo "0,0,0,0,0")
    
    echo "[$TIMESTAMP] 查询统计: $QUERY_STATS" >> $LOG_FILE
    
    # 表大小统计
    TABLE_STATS=$(clickhouse-client --query "
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
    
    echo "[$TIMESTAMP] 表大小统计: $TABLE_STATS" >> $LOG_FILE
}

# 发送告警
send_alert() {
    local message="$1"
    echo "[$TIMESTAMP] 告警: $message" >> $LOG_FILE
    
    # 这里可以添加告警通知逻辑
    # 例如：发送邮件、短信、钉钉等
    # echo "$message" | mail -s "ClickHouse告警" admin@example.com
}

# 主监控逻辑
main() {
    local alerts=0
    
    echo "=== ClickHouse 监控检查 ==="
    
    # 检查各项指标
    check_service_status || ((alerts++))
    check_memory_usage || ((alerts++))
    check_connections || ((alerts++))
    check_disk_usage || ((alerts++))
    check_slow_queries || ((alerts++))
    check_error_logs || ((alerts++))
    check_ports || ((alerts++))
    
    # 生成性能报告
    generate_performance_report
    
    # 如果有告警，发送通知
    if [ $alerts -gt 0 ]; then
        send_alert "ClickHouse监控发现 $alerts 个问题"
        echo "[$TIMESTAMP] 监控完成，发现 $alerts 个问题" >> $LOG_FILE
    else
        echo "[$TIMESTAMP] 监控完成，系统运行正常" >> $LOG_FILE
    fi
    
    echo "=== 监控检查完成 ==="
}

# 执行监控
main

# 清理旧日志
cleanup_old_logs() {
    # 保留最近7天的日志
    find /opt/clickhouse/logs -name "monitor_*.log" -mtime +7 -delete 2>/dev/null || true
}

cleanup_old_logs 