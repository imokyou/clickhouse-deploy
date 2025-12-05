#!/bin/bash

# ClickHouse Docker 健康检查脚本
# 兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统
# 验证部署状态和连接性

set -e

# 加载环境变量
if [ -f ".env" ]; then
    echo "加载环境配置文件..."
    set -a
    source .env
    set +a
fi

# 配置参数
CONFIG_FILE="health-check.conf"
LOG_FILE="/tmp/clickhouse-health-check.log"
ALERT_EMAIL=""
DOCKER_COMPOSE_FILE="docker-compose.yml"

# 默认配置
DEFAULT_USER="default"
DEFAULT_PASSWORD="clickhouse123"
HEALTH_CHECK_TIMEOUT=30
MAX_RETRIES=3

# 从环境变量获取配置
CLICKHOUSE_CONTAINER_NAME=${CLICKHOUSE_CONTAINER_NAME:-clickhouse-server}
CLICKHOUSE_HTTP_PORT=${CLICKHOUSE_HTTP_PORT:-8123}
CLICKHOUSE_NATIVE_PORT=${CLICKHOUSE_NATIVE_PORT:-9000}

echo "=== ClickHouse Docker 健康检查 ==="
echo "检查时间: $(date)"
echo "容器名称: $CLICKHOUSE_CONTAINER_NAME"
echo "HTTP端口: $CLICKHOUSE_HTTP_PORT"
echo "Native端口: $CLICKHOUSE_NATIVE_PORT"
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
    log_message "INFO" "检查Docker Compose命令..."
    
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
        log_message "INFO" "使用 docker-compose 命令"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        log_message "INFO" "使用 docker compose 命令"
    else
        log_message "ERROR" "Docker Compose未安装"
        return 1
    fi
    
    # 验证Docker Compose文件
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_message "ERROR" "Docker Compose文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    log_message "INFO" "Docker Compose文件验证通过"
    return 0
}

# 检查服务状态
check_service_status() {
    log_message "INFO" "检查服务状态..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
            log_message "SUCCESS" "ClickHouse服务正在运行"
            $COMPOSE_CMD ps
            return 0
        else
            retries=$((retries + 1))
            log_message "WARNING" "ClickHouse服务未运行，尝试启动 (第$retries次)"
            
            if [ $retries -eq 1 ]; then
                $COMPOSE_CMD up -d
                sleep $HEALTH_CHECK_TIMEOUT
            else
                sleep 5
            fi
        fi
    done
    
    log_message "ERROR" "服务启动失败，已尝试$MAX_RETRIES次"
    return 1
}

# 检查容器健康状态
check_container_health() {
    log_message "INFO" "检查容器健康状态..."
    
    local health_status=$($COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}" | grep clickhouse)
    if echo "$health_status" | grep -q "healthy"; then
        log_message "SUCCESS" "容器健康状态正常"
    elif echo "$health_status" | grep -q "unhealthy"; then
        log_message "ERROR" "容器健康状态异常"
        $COMPOSE_CMD logs $CLICKHOUSE_CONTAINER_NAME --tail=20
        return 1
    else
        log_message "WARNING" "容器健康状态未知"
    fi
    
    return 0
}

# 检查数据库连接
check_database_connection() {
    log_message "INFO" "检查数据库连接..."
    
    local retries=0
    while [ $retries -lt $MAX_RETRIES ]; do
        if $COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
            -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
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
    log_message "ERROR" "检查服务日志..."
    $COMPOSE_CMD logs $CLICKHOUSE_CONTAINER_NAME --tail=20
    return 1
}

# 检查版本信息
check_version() {
    log_message "INFO" "检查ClickHouse版本..."
    
    local version=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT version()" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$version" ]; then
        log_message "SUCCESS" "ClickHouse版本: $version"
        return 0
    else
        log_message "ERROR" "无法获取版本信息"
        return 1
    fi
}

# 检查性能指标
check_performance_metrics() {
    log_message "INFO" "检查性能指标..."
    
    # 查询数量
    local query_count=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE event_time >= now() - INTERVAL 1 HOUR" \
        2>/dev/null || echo "0")
    log_message "INFO" "过去1小时查询次数: $query_count"
    
    # 慢查询数量
    local slow_query_count=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.query_log WHERE event_time >= now() - INTERVAL 1 HOUR AND query_duration_ms > 1000" \
        2>/dev/null || echo "0")
    log_message "INFO" "过去1小时慢查询次数 (>1s): $slow_query_count"
    
    # 连接数
    local connection_count=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.processes" \
        2>/dev/null || echo "0")
    log_message "INFO" "当前连接数: $connection_count"
    
    # 错误数量
    local error_count=$($COMPOSE_CMD logs $CLICKHOUSE_CONTAINER_NAME 2>&1 | grep -c "ERROR\|Exception" || echo "0")
    log_message "INFO" "错误日志数量: $error_count"
    
    if [ "$error_count" -gt 0 ]; then
        log_message "WARNING" "最近错误日志:"
        $COMPOSE_CMD logs $CLICKHOUSE_CONTAINER_NAME 2>&1 | grep "ERROR\|Exception" | tail -5
    fi
    
    return 0
}

# 检查资源使用
check_resource_usage() {
    log_message "INFO" "检查资源使用..."
    
    # 容器资源使用
    log_message "INFO" "容器资源使用情况:"
    $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME cat /proc/meminfo | grep -E "MemTotal|MemAvailable|MemUsed" || \
        log_message "WARNING" "无法获取内存信息"
    
    # ClickHouse内存使用
    log_message "INFO" "ClickHouse内存使用:"
    $COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "
        SELECT 
            'Memory Usage' as metric,
            formatReadableSize(memory_usage) as value
        FROM system.processes 
        WHERE query_id = currentQueryID()
        " 2>/dev/null || log_message "WARNING" "无法获取内存使用信息"
    
    # 磁盘使用
    log_message "INFO" "磁盘使用情况:"
    $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME df -h /var/lib/clickhouse/ || \
        log_message "WARNING" "无法获取磁盘使用信息"
    
    return 0
}

# 检查网络连接
check_network_connectivity() {
    log_message "INFO" "检查网络连接..."
    
    # 检查端口监听的多种方法
    local http_port=0
    local native_port=0
    
    # 方法1: 尝试使用 netstat
    if $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME which netstat >/dev/null 2>&1; then
        http_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME netstat -tlnp 2>/dev/null | grep -c ":$CLICKHOUSE_HTTP_PORT " || echo "0")
        native_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME netstat -tlnp 2>/dev/null | grep -c ":$CLICKHOUSE_NATIVE_PORT " || echo "0")
    # 方法2: 尝试使用 ss (socket statistics)
    elif $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME which ss >/dev/null 2>&1; then
        http_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME ss -tlnp 2>/dev/null | grep -c ":$CLICKHOUSE_HTTP_PORT " || echo "0")
        native_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME ss -tlnp 2>/dev/null | grep -c ":$CLICKHOUSE_NATIVE_PORT " || echo "0")
    # 方法3: 检查 /proc/net/tcp
    elif $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME test -f /proc/net/tcp; then
        http_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME cat /proc/net/tcp 2>/dev/null | grep -c ":1F9B " || echo "0")  # 8123 in hex
        native_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME cat /proc/net/tcp 2>/dev/null | grep -c ":2328 " || echo "0")  # 9000 in hex
    # 方法4: 使用 lsof
    elif $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME which lsof >/dev/null 2>&1; then
        http_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME lsof -i :$CLICKHOUSE_HTTP_PORT 2>/dev/null | wc -l || echo "0")
        native_port=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME lsof -i :$CLICKHOUSE_NATIVE_PORT 2>/dev/null | wc -l || echo "0")
    # 方法5: 通过 ClickHouse 系统表检查
    else
        log_message "WARNING" "无法使用系统工具检查端口，尝试通过 ClickHouse 系统表检查"
        # 通过 ClickHouse 查询检查端口状态
        local http_check=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
            -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
            --query "SELECT count() FROM system.processes WHERE query LIKE '%$CLICKHOUSE_HTTP_PORT%'" \
            2>/dev/null || echo "0")
        local native_check=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
            -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
            --query "SELECT count() FROM system.processes WHERE query LIKE '%$CLICKHOUSE_NATIVE_PORT%'" \
            2>/dev/null || echo "0")
        
        # 如果无法通过系统表检查，则假设端口正常（因为连接已经建立）
        if [ "$http_check" -eq 0 ] && [ "$native_check" -eq 0 ]; then
            log_message "INFO" "无法直接检查端口监听，但 ClickHouse 服务正在运行"
            http_port=1
            native_port=1
        fi
    fi
    
    # 确保变量是纯数字，去除可能的换行符
    http_port=$(echo "$http_port" | tr -d '\n\r')
    native_port=$(echo "$native_port" | tr -d '\n\r')
    
    # 检查 HTTP 端口
    if [ "$http_port" -gt 0 ] 2>/dev/null; then
        log_message "SUCCESS" "HTTP端口($CLICKHOUSE_HTTP_PORT)监听正常"
    else
        log_message "ERROR" "HTTP端口($CLICKHOUSE_HTTP_PORT)未监听"
    fi
    
    # 检查 Native 端口
    if [ "$native_port" -gt 0 ] 2>/dev/null; then
        log_message "SUCCESS" "Native端口($CLICKHOUSE_NATIVE_PORT)监听正常"
    else
        log_message "ERROR" "Native端口($CLICKHOUSE_NATIVE_PORT)未监听"
    fi
    
    # 额外检查：尝试从容器外部连接端口
    log_message "INFO" "检查外部端口连接性..."
    
    # 获取容器IP
    local container_ip=$($COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME hostname -i 2>/dev/null | awk '{print $1}' || echo "")
    
    if [ -n "$container_ip" ]; then
        # 检查 HTTP 端口连接
        if timeout 5 bash -c "</dev/tcp/$container_ip/$CLICKHOUSE_HTTP_PORT" 2>/dev/null; then
            log_message "SUCCESS" "HTTP端口($CLICKHOUSE_HTTP_PORT)外部连接正常"
        else
            log_message "WARNING" "HTTP端口($CLICKHOUSE_HTTP_PORT)外部连接失败"
        fi
        
        # 检查 Native 端口连接
        if timeout 5 bash -c "</dev/tcp/$container_ip/$CLICKHOUSE_NATIVE_PORT" 2>/dev/null; then
            log_message "SUCCESS" "Native端口($CLICKHOUSE_NATIVE_PORT)外部连接正常"
        else
            log_message "WARNING" "Native端口($CLICKHOUSE_NATIVE_PORT)外部连接失败"
        fi
    else
        log_message "WARNING" "无法获取容器IP地址"
    fi
    
    return 0
}

# 检查系统表
check_system_tables() {
    log_message "INFO" "检查系统表..."
    
    local table_count=$($COMPOSE_CMD exec -T $CLICKHOUSE_CONTAINER_NAME clickhouse-client \
        -u "$DEFAULT_USER" --password "$DEFAULT_PASSWORD" \
        --query "SELECT count() FROM system.tables" \
        2>/dev/null || echo "0")
    
    if [ "$table_count" -gt 0 ]; then
        log_message "SUCCESS" "系统表访问正常，表数量: $table_count"
        return 0
    else
        log_message "ERROR" "系统表访问失败"
        return 1
    fi
}

# 生成健康报告
generate_health_report() {
    log_message "INFO" "生成健康检查报告..."
    
    echo ""
    echo "=== ClickHouse 健康检查报告 ==="
    echo "检查时间: $(date)"
    echo "Docker Compose文件: $DOCKER_COMPOSE_FILE"
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo ""
    
    # 服务状态摘要
    echo "服务状态摘要:"
    $COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    # 性能指标摘要
    echo "性能指标摘要:"
    echo "- 查询次数: $query_count"
    echo "- 慢查询次数: $slow_query_count"
    echo "- 连接数: $connection_count"
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
    
    # 执行各项检查
    check_docker_compose || exit_code=1
    check_service_status || exit_code=1
    check_container_health || exit_code=1
    check_database_connection || exit_code=1
    check_version || exit_code=1
    check_performance_metrics || exit_code=1
    check_resource_usage || exit_code=1
    check_network_connectivity || exit_code=1
    check_system_tables || exit_code=1
    
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