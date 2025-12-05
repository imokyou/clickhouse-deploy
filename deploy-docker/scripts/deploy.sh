#!/bin/bash

# ClickHouse Docker 完整部署脚本
# 兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统

set -e

echo "=== ClickHouse Docker 完整部署 ==="

# 加载环境变量
if [ -f ".env" ]; then
    echo "加载环境配置文件..."
    set -a
    source .env
    set +a
fi

# 从环境变量获取配置
CLICKHOUSE_CONTAINER_NAME=${CLICKHOUSE_CONTAINER_NAME:-clickhouse-server}
CLICKHOUSE_HTTP_PORT=${CLICKHOUSE_HTTP_PORT:-8123}
CLICKHOUSE_NATIVE_PORT=${CLICKHOUSE_NATIVE_PORT:-9000}

echo "容器名称: $CLICKHOUSE_CONTAINER_NAME"
echo "HTTP端口: $CLICKHOUSE_HTTP_PORT"
echo "Native端口: $CLICKHOUSE_NATIVE_PORT"
echo ""

# 检查Docker环境
echo "1. 检查Docker环境..."
if ! command -v docker &> /dev/null; then
    echo "错误: Docker未安装，请先运行 ./scripts/install-docker.sh"
    exit 1
fi

# 检查Docker Compose（支持插件版本和独立版本）
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "错误: Docker Compose未安装，请先运行 ./scripts/install-docker.sh"
    exit 1
fi

echo "使用Docker Compose命令: $COMPOSE_CMD"

# 检查配置文件
echo "2. 检查配置文件..."
if [ ! -f "docker-compose.yml" ]; then
    echo "错误: docker-compose.yml 文件不存在"
    exit 1
fi

# 检查主配置文件
if [ ! -f "clickhouse/config/config.d/config.xml" ]; then
    echo "错误: ClickHouse主配置文件 config.xml 不存在"
    exit 1
else
    echo "✓ 找到主配置文件: config.xml"
fi


# 停止现有容器
echo "3. 停止现有容器... $COMPOSE_CMD down"
$COMPOSE_CMD down 2>/dev/null || true

# 清理旧数据（可选）
read -p "是否清理旧数据? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "清理旧数据..."
    sudo rm -rf clickhouse/data/*
    sudo rm -rf clickhouse/logs/*
fi

# 拉取最新镜像
echo "4. 拉取ClickHouse镜像... $COMPOSE_CMD pull"
$COMPOSE_CMD pull

# 启动服务
echo "5. 启动 ClickHouse 服务... $COMPOSE_CMD up -d"
$COMPOSE_CMD up -d

# 等待服务启动
echo "6. 等待服务启动...sleep 60"
sleep 60

# 检查服务状态
echo "7. 检查服务状态... $COMPOSE_CMD ps"
$COMPOSE_CMD ps

# 等待服务完全启动
echo "8. 等待服务完全启动..."
for i in {1..12}; do
    if curl -s http://localhost:$CLICKHOUSE_HTTP_PORT/ping > /dev/null; then
        echo "✓ ClickHouse服务已启动"
        break
    else
        echo "等待服务启动... ($i/12), 已等待 $((i*10)) 秒"
        sleep 10
    fi
done

# 测试连接
echo "9. 测试 ClickHouse 连接... $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME clickhouse-client --query"
if $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME clickhouse-client -u default --password clickhouse123 --query "SELECT version()" > /dev/null 2>&1; then
    echo "✓ ClickHouse连接测试成功"
else
    echo "⚠ ClickHouse连接测试失败，请检查日志"
    $COMPOSE_CMD logs $CLICKHOUSE_CONTAINER_NAME
fi

# 创建测试数据库和表
echo "10. 创建测试数据... $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME clickhouse-client --query"
$COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME clickhouse-client -u default --password clickhouse123 --query "
CREATE DATABASE IF NOT EXISTS test_db;
CREATE TABLE IF NOT EXISTS test_db.test_table (
    id UInt32,
    name String,
    created_at DateTime
) ENGINE = MergeTree()
ORDER BY (id, created_at);
" > /dev/null 2>&1 || echo "测试数据创建失败或已存在"

# 显示部署信息
echo ""
echo "=== 部署完成 ==="
echo "ClickHouse 服务已启动"
echo "HTTP端口: http://localhost:$CLICKHOUSE_HTTP_PORT"
echo "Native端口: localhost:$CLICKHOUSE_NATIVE_PORT"
echo "默认用户: default"
echo "默认密码: clickhouse123"
echo ""
echo "常用命令:"
echo "  查看服务状态: $COMPOSE_CMD ps"
echo "  查看日志: $COMPOSE_CMD logs -f $CLICKHOUSE_CONTAINER_NAME"
echo "  连接数据库: $COMPOSE_CMD exec $CLICKHOUSE_CONTAINER_NAME clickhouse-client -u default --password clickhouse123"
echo "  健康检查: ./scripts/health-check.sh"
echo "  备份数据: ./scripts/backup.sh" 