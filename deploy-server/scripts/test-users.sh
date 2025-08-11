#!/bin/bash

# ClickHouse 用户配置测试脚本
# 用于测试新创建的用户是否能正常连接（服务器直接部署版本）

echo "ClickHouse 用户配置测试"
echo "========================"
echo ""

# 检查ClickHouse服务是否运行
if ! systemctl is-active --quiet clickhouse-server; then
    echo "错误: ClickHouse服务未运行"
    echo "请先启动ClickHouse服务: sudo systemctl start clickhouse-server"
    exit 1
fi

echo "ClickHouse服务正在运行..."
echo ""

# 检查ClickHouse客户端是否可用
if ! command -v clickhouse-client &> /dev/null; then
    echo "错误: ClickHouse客户端未安装"
    echo "请安装ClickHouse客户端: sudo yum install clickhouse-client 或 sudo apt install clickhouse-client"
    exit 1
fi

# 测试管理员用户连接
echo "测试管理员用户 (admin)..."
if clickhouse-client --user=admin --password=Admin_2024_Secure! --query="SELECT 1 as test" 2>/dev/null; then
    echo "✓ 管理员用户连接成功"
else
    echo "✗ 管理员用户连接失败"
    echo "请检查密码和配置"
    echo "检查配置文件: /etc/clickhouse-server/users.xml"
fi
echo ""

# 测试Web用户连接
echo "测试Web用户 (webuser)..."
if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="SELECT 1 as test" 2>/dev/null; then
    echo "✓ Web用户连接成功"
else
    echo "✗ Web用户连接失败"
    echo "请检查密码和配置"
    echo "检查配置文件: /etc/clickhouse-server/users.xml"
fi
echo ""

# 测试默认用户连接
echo "测试默认用户 (default)..."
if clickhouse-client --user=default --password=clickhouse123 --query="SELECT 1 as test" 2>/dev/null; then
    echo "✓ 默认用户连接成功"
else
    echo "✗ 默认用户连接失败"
    echo "请检查默认用户配置"
fi
echo ""

# 测试权限
echo "测试用户权限..."
echo ""

echo "管理员用户权限测试:"
clickhouse-client --user=admin --password=Admin_2024_Secure! --query="SHOW GRANTS" 2>/dev/null || echo "无法获取权限信息"

echo ""
echo "Web用户权限测试:"
clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="SHOW GRANTS" 2>/dev/null || echo "无法获取权限信息"

echo ""
echo "默认用户权限测试:"
clickhouse-client --user=default --password=clickhouse123 --query="SHOW GRANTS" 2>/dev/null || echo "无法获取权限信息"

# 测试数据库操作权限
echo ""
echo "测试数据库操作权限..."

echo "管理员用户 - 创建测试数据库:"
if clickhouse-client --user=admin --password=Admin_2024_Secure! --query="CREATE DATABASE IF NOT EXISTS test_users_db" 2>/dev/null; then
    echo "✓ 管理员用户创建数据库成功"
else
    echo "✗ 管理员用户创建数据库失败"
fi

echo "Web用户 - 创建测试表:"
if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="CREATE TABLE IF NOT EXISTS test_users_db.test_table (id UInt32, name String) ENGINE = Memory" 2>/dev/null; then
    echo "✓ Web用户创建表成功"
else
    echo "✗ Web用户创建表失败"
fi

echo "Web用户 - 插入测试数据:"
if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="INSERT INTO test_users_db.test_table VALUES (1, 'test')" 2>/dev/null; then
    echo "✓ Web用户插入数据成功"
else
    echo "✗ Web用户插入数据失败"
fi

echo "Web用户 - 查询测试数据:"
if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query="SELECT * FROM test_users_db.test_table" 2>/dev/null; then
    echo "✓ Web用户查询数据成功"
else
    echo "✗ Web用户查询数据失败"
fi

# 清理测试数据
echo ""
echo "清理测试数据..."
clickhouse-client --user=admin --password=Admin_2024_Secure! --query="DROP DATABASE IF EXISTS test_users_db" 2>/dev/null

# 测试网络连接
echo ""
echo "测试网络连接..."
echo "HTTP接口测试:"
if curl -s http://localhost:8123/ping > /dev/null; then
    echo "✓ HTTP接口 (8123) 可访问"
else
    echo "✗ HTTP接口 (8123) 不可访问"
fi

echo "Native接口测试:"
if clickhouse-client --user=default --password=clickhouse123 --query="SELECT 1" > /dev/null 2>&1; then
    echo "✓ Native接口 (9000) 可访问"
else
    echo "✗ Native接口 (9000) 不可访问"
fi

echo ""
echo "测试完成！"

# 显示连接信息
echo ""
echo "连接信息:"
echo "HTTP接口: http://localhost:8123"
echo "Native接口: localhost:9000"
echo "管理员用户: admin / Admin_2024_Secure!"
echo "Web用户: webuser / WebUser_2024_Secure!"
echo "默认用户: default / clickhouse123" 