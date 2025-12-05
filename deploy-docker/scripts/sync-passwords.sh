#!/bin/bash

# ClickHouse 密码同步脚本
# 从 .env 文件读取密码并同步到 users.xml

set -e

echo "=== ClickHouse 密码同步脚本 ==="
echo ""

# 检查 .env 文件是否存在
if [ ! -f ".env" ]; then
    echo "错误: .env 文件不存在"
    echo "请先创建 .env 文件或运行 auto-deploy.sh"
    exit 1
fi

# 加载 .env 文件
echo "加载 .env 配置..."
set -a
source .env
set +a

# 检查密码变量是否存在
if [ -z "$ADMIN_PASSWORD" ] || [ -z "$WEBUSER_PASSWORD" ] || [ -z "$DEMOUSER_PASSWORD" ]; then
    echo "错误: .env 文件中缺少密码配置"
    echo "请确保 .env 文件包含以下变量:"
    echo "  - ADMIN_PASSWORD"
    echo "  - WEBUSER_PASSWORD"
    echo "  - DEMOUSER_PASSWORD"
    exit 1
fi

# 检查 users.xml 文件是否存在
if [ ! -f "clickhouse/config/users.d/users.xml" ]; then
    echo "错误: users.xml 文件不存在"
    echo "路径: clickhouse/config/users.d/users.xml"
    exit 1
fi

# 备份 users.xml
echo "备份 users.xml..."
cp clickhouse/config/users.d/users.xml clickhouse/config/users.d/users.xml.backup

# 同步密码到 users.xml
echo "同步密码到 users.xml..."
sed -i.tmp "s|<password>xnJ8_M2zd7R!uQXaVgQDbTYn</password>|<password><![CDATA[$ADMIN_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml
sed -i.tmp "s|<password>w2E8_B43wzP!gS53c56Lz0g6</password>|<password><![CDATA[$WEBUSER_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml
sed -i.tmp "s|<password>l0K3_L12g5F!pX83c45Jz1h7</password>|<password><![CDATA[$DEMOUSER_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml

# 如果有其他密码格式，也尝试替换
sed -i.tmp "s|<password><!\[CDATA\[.*\]\]></password>|<password><![CDATA[$ADMIN_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml

rm -f clickhouse/config/users.d/users.xml.tmp

echo ""
echo "✓ 密码同步完成"
echo ""
echo "同步的密码:"
echo "  - admin: ****"
echo "  - webuser: ****"
echo "  - demouser: ****"
echo ""
echo "备份文件: clickhouse/config/users.d/users.xml.backup"
echo ""

# 询问是否重启服务
read -p "是否重启 ClickHouse 服务使密码生效? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 确定 Docker Compose 命令
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    elif docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    else
        echo "错误: Docker Compose 未安装"
        exit 1
    fi
    
    echo "重启 ClickHouse 服务..."
    $COMPOSE_CMD restart
    echo "✓ 服务已重启"
else
    echo "跳过重启，请手动重启服务使密码生效:"
    echo "  docker compose restart"
fi

echo ""
echo "=== 密码同步完成 ==="

