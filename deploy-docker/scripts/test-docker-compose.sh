#!/bin/bash

# 测试Docker Compose命令检测脚本

echo "=== Docker Compose 命令检测测试 ==="

# 检查Docker Compose命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo "✓ 检测到Docker Compose独立版本"
    echo "  命令: $COMPOSE_CMD"
    echo "  版本: $($COMPOSE_CMD --version)"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    echo "✓ 检测到Docker Compose插件版本"
    echo "  命令: $COMPOSE_CMD"
    echo "  版本: $(docker compose version)"
else
    echo "✗ 未检测到Docker Compose"
    echo "  请运行 ./scripts/install-docker.sh 安装Docker Compose"
    exit 1
fi

echo ""
echo "测试Docker Compose命令..."
echo "使用命令: $COMPOSE_CMD"

# 测试基本命令
if $COMPOSE_CMD version &> /dev/null; then
    echo "✓ Docker Compose命令测试通过"
else
    echo "✗ Docker Compose命令测试失败"
    exit 1
fi

echo ""
echo "=== 测试完成 ==="
echo "Docker Compose已正确配置，可以使用以下命令:"
echo "  $COMPOSE_CMD ps"
echo "  $COMPOSE_CMD up -d"
echo "  $COMPOSE_CMD down"
echo "  $COMPOSE_CMD logs" 