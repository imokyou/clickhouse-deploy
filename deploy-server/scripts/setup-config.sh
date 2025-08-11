#!/bin/bash

# ClickHouse Server 配置脚本

set -e

echo "=== 配置ClickHouse ==="

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 备份原始配置
echo "备份原始配置..."
if [ -f /etc/clickhouse-server/config.xml ]; then
    cp /etc/clickhouse-server/config.xml /etc/clickhouse-server/config.xml.backup.$(date +%Y%m%d%H%M)
fi      

if [ -f /etc/clickhouse-server/users.xml ]; then
    cp /etc/clickhouse-server/users.xml /etc/clickhouse-server/users.xml.backup.$(date +%Y%m%d%H%M)
fi

# 创建配置目录结构
echo "创建配置目录结构..."
mkdir -p /etc/clickhouse-server/config.d
mkdir -p /etc/clickhouse-server/users.d


# 复制配置文件
echo "复制配置文件..."
cp -r $PROJECT_ROOT/clickhouse/config/config.d/* /etc/clickhouse-server/config.d/
cp -r $PROJECT_ROOT/clickhouse/config/users.d/* /etc/clickhouse-server/users.d/

# 清理旧的default-user.xml文件（如果存在）
echo "清理旧的default-user.xml文件..."
if [ -f /etc/clickhouse-server/users.d/default-user.xml ]; then
    rm -f /etc/clickhouse-server/users.d/default-user.xml
    echo "已删除 /etc/clickhouse-server/users.d/default-user.xml"
fi

# 设置配置文件权限
echo "设置配置文件权限..."
chown -R clickhouse:clickhouse /etc/clickhouse-server/
chmod 755 /etc/clickhouse-server/*
chmod 755 /etc/clickhouse-server/config.d/*.xml
chmod 755 /etc/clickhouse-server/users.d/*.xml

# 启用服务
systemctl enable clickhouse-server

echo "=== ClickHouse配置完成 ==="
echo "配置说明："
echo "- 配置文件目录：/etc/clickhouse-server/config.d/"
echo "- 用户配置文件：/etc/clickhouse-server/users.d/users.xml"
echo "- 默认用户已重新定义：profile=default, networks=::/0, password=clickhouse123, quota=default, access_management=1"
echo "- 已清理旧的default-user.xml文件"
echo ""
echo "⚠️  配置文件优先级说明："
echo "- ClickHouse会按字母顺序加载 config.d/ 目录中的所有 .xml 文件"
echo "- 同名配置项会被后面的文件覆盖"
echo "- 建议使用 config.d/ 目录管理所有配置文件，避免与主配置文件冲突" 