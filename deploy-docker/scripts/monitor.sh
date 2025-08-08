#!/bin/bash

# ClickHouse 监控脚本
# 实时监控ClickHouse服务状态和性能指标

set -e

echo "=== ClickHouse 服务监控 ==="

# 检查Docker Compose命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "错误: Docker Compose未安装"
    exit 1
fi

# 检查服务状态
check_service_status() {
    echo "=== 服务状态检查 ==="
    if $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
        echo "✓ ClickHouse服务正在运行"
        $COMPOSE_CMD ps
    else
        echo "✗ ClickHouse服务未运行"
        return 1
    fi
}

# 检查连接状态
check_connection() {
    echo ""
    echo "=== 连接状态检查 ==="
    if $COMPOSE_CMD exec clickhouse-server clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
        echo "✓ 数据库连接正常"
    else
        echo "✗ 数据库连接失败"
        return 1
    fi
}

# 获取性能指标
get_performance_metrics() {
    echo ""
    echo "=== 性能指标 ==="
    
    # 查询数量
    QUERY_COUNT=$($COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
    SELECT count() FROM system.query_log 
    WHERE event_time >= now() - INTERVAL 1 HOUR
    " 2>/dev/null || echo "0")
    echo "过去1小时查询次数: $QUERY_COUNT"
    
    # 慢查询数量
    SLOW_QUERY_COUNT=$($COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
    SELECT count() FROM system.query_log 
    WHERE event_time >= now() - INTERVAL 1 HOUR 
    AND query_duration_ms > 1000
    " 2>/dev/null || echo "0")
    echo "过去1小时慢查询次数 (>1s): $SLOW_QUERY_COUNT"
    
    # 连接数
    CONNECTION_COUNT=$($COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
    SELECT count() FROM system.processes
    " 2>/dev/null || echo "0")
    echo "当前连接数: $CONNECTION_COUNT"
    
    # 错误数量
    ERROR_COUNT=$($COMPOSE_CMD logs clickhouse-server 2>&1 | grep -c "ERROR\|Exception" || echo "0")
    echo "错误日志数量: $ERROR_COUNT"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo ""
        echo "⚠ 最近错误日志:"
        $COMPOSE_CMD logs clickhouse-server 2>&1 | grep "ERROR\|Exception" | tail -5
    fi
}

# 获取资源使用情况
get_resource_usage() {
    echo ""
    echo "=== 资源使用情况 ==="
    
    # 容器资源使用
    echo "容器资源使用:"
    $COMPOSE_CMD exec clickhouse-server cat /proc/meminfo | grep -E "MemTotal|MemAvailable" || echo "无法获取内存信息"
    
    # ClickHouse内存使用
    echo ""
    echo "ClickHouse内存使用:"
    $COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
    SELECT 
        'Memory Usage' as metric,
        formatReadableSize(memory_usage) as value
    FROM system.processes 
    WHERE query_id = currentQueryID()
    " 2>/dev/null || echo "无法获取内存使用信息"
}

# 主监控循环
main_monitor() {
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
        
        echo ""
        echo "=== 监控信息 ==="
        echo "监控时间: $(date)"
        echo "下次更新: 30秒后"
        echo ""
        
        # 等待30秒后更新
        sleep 30
    done
}

# 检查参数
if [ "$1" = "--once" ]; then
    # 单次检查模式
    check_service_status
    check_connection
    get_performance_metrics
    get_resource_usage
    echo ""
    echo "=== 单次检查完成 ==="
else
    # 持续监控模式
    main_monitor
fi 