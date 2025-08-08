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
    cp /etc/clickhouse-server/config.xml /etc/clickhouse-server/config.xml.backup.$(date +%Y%m%d)
fi

if [ -f /etc/clickhouse-server/users.xml ]; then
    cp /etc/clickhouse-server/users.xml /etc/clickhouse-server/users.xml.backup.$(date +%Y%m%d)
fi

# 复制配置文件
echo "复制配置文件..."
cp -r $PROJECT_ROOT/clickhouse/config/* /etc/clickhouse-server/

# 设置配置文件权限
chown -R clickhouse:clickhouse /etc/clickhouse-server/
chmod 644 /etc/clickhouse-server/*.yml

# 创建systemd服务文件
echo "创建systemd服务文件..."
cat > /etc/systemd/system/clickhouse-server.service << EOF
[Unit]
Description=ClickHouse Server (analytic DBMS)
After=network.target

[Service]
Type=simple
RuntimeDirectory=clickhouse-server
User=clickhouse
Group=clickhouse
ExecStart=/usr/bin/clickhouse-server --config=/etc/clickhouse-server/config.yml
Restart=always
RestartSec=10
LimitNOFILE=65536
LimitNPROC=32768

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd
systemctl daemon-reload

# 启用服务
systemctl enable clickhouse-server

echo "=== ClickHouse配置完成 ===" 