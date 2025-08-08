#!/bin/bash

# ClickHouse 健康检查脚本
# 兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统
# 验证部署状态和连接性

set -e

echo "=== ClickHouse 健康检查 ==="

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
echo "1. 检查服务状态..."
if $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
    echo "✓ ClickHouse服务正在运行"
    $COMPOSE_CMD ps
else
    echo "✗ ClickHouse服务未运行"
    echo "尝试启动服务..."
    $COMPOSE_CMD up -d
    sleep 10
    if $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
        echo "✓ 服务已启动"
    else
        echo "✗ 服务启动失败"
        exit 1
    fi
fi

# 检查连接
echo ""
echo "2. 检查数据库连接..."
if $COMPOSE_CMD exec clickhouse-server clickhouse-client --query "SELECT 1" 2> /dev/null; then
    echo "✓ 数据库连接正常"
else
    echo "✗ 数据库连接失败"
    echo "检查服务日志..."
    $COMPOSE_CMD logs clickhouse --tail=20
    exit 1
fi

# 检查版本
echo ""
echo "3. 检查ClickHouse版本..."
VERSION=$($COMPOSE_CMD exec clickhouse-server clickhouse-client --query "SELECT version()" 2>/dev/null)
if [ $? -eq 0 ]; then
    echo "✓ ClickHouse版本: $VERSION"
else
    echo "✗ 无法获取版本信息"
fi

# 检查性能指标
echo ""
echo "4. 检查性能指标..."
QUERY_COUNT=$($COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
SELECT count() FROM system.query_log 
WHERE event_time >= now() - INTERVAL 1 HOUR
" 2>/dev/null || echo "0")

echo "过去1小时查询次数: $QUERY_COUNT"

ERROR_COUNT=$($COMPOSE_CMD logs clickhouse-server 2>&1 | grep -c "ERROR\|Exception" || echo "0")
echo "错误日志数量: $ERROR_COUNT"

# 检查资源使用
echo ""
echo "5. 检查资源使用..."
$COMPOSE_CMD exec clickhouse-server clickhouse-client --query "
SELECT
    'Memory' AS metric,
    formatReadableSize(memory_usage) AS value
FROM system.processes
WHERE query_id = currentQueryID()

UNION ALL

SELECT
    'CPU' AS metric,
    concat(
        toString(
            100.0
            * (
                ProfileEvents['UserTimeMicroseconds'] 
              + ProfileEvents['SystemTimeMicroseconds']
            )
            / (elapsed * 1000000)
        ),
        '%'
    ) AS value
FROM system.processes
WHERE query_id = currentQueryID()

UNION ALL

SELECT
    'MarkCacheHitRatio' AS metric,
    concat(
        toString(
            100.0
            * ProfileEvents['MarkCacheHits']
            / greatest(ProfileEvents['MarkCacheHits'] + ProfileEvents['MarkCacheMisses'], 1)
        ),
        '%'
    ) AS value
FROM system.processes
WHERE query_id = currentQueryID();" 2>/dev/null || echo "无法获取资源使用信息"

echo ""
echo "=== 健康检查完成 ===" 