#!/bin/bash

# ClickHouse 用户配置测试脚本
# 用于测试新创建的用户是否能正常连接

echo "ClickHouse 用户配置测试"
echo "========================"
echo ""

# 检查ClickHouse是否运行
if ! docker ps | grep -q clickhouse-server; then
    echo "错误: ClickHouse容器未运行"
    echo "请先启动ClickHouse服务: docker-compose up -d"
    exit 1
fi

echo "ClickHouse服务正在运行..."
echo ""

# 测试管理员用户连接
echo "测试管理员用户 (admin)..."
if docker exec clickhouse-server clickhouse-client --user=admin --password=Admin_2024_Secure! --query="SELECT 1 as test" 2>/dev/null; then
    echo "✓ 管理员用户连接成功"
else
    echo "✗ 管理员用户连接失败"
    echo "请检查密码和配置"
fi
echo ""

# 测试Web用户连接
echo "测试Web用户 (webuser)..."
if docker exec clickhouse-server clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="SELECT 1 as test" 2>/dev/null; then
    echo "✓ Web用户连接成功"
else
    echo "✗ Web用户连接失败"
    echo "请检查密码和配置"
fi
echo ""

# 测试权限
echo "测试用户权限..."
echo ""

echo "管理员用户权限测试:"
docker exec clickhouse-server clickhouse-client --user=admin --password=Admin_2024_Secure! --query="SHOW GRANTS" 2>/dev/null || echo "无法获取权限信息"

echo ""
echo "Web用户权限测试:"
docker exec clickhouse-server clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="SHOW GRANTS" 2>/dev/null || echo "无法获取权限信息"

echo ""
echo "测试完成！" 