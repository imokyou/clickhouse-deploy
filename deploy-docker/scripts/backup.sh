#!/bin/bash

# ClickHouse 数据备份脚本
# 支持全量备份和增量备份

set -e

echo "=== ClickHouse 数据备份 ==="

# 检查Docker Compose命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    echo "错误: Docker Compose未安装"
    exit 1
fi

# 配置变量
BACKUP_DIR="/opt/clickhouse-deploy/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="clickhouse_backup_$DATE"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 检查服务状态
echo "1. 检查服务状态..."
if ! $COMPOSE_CMD ps | grep -q "clickhouse.*Up"; then
    echo "错误: ClickHouse服务未运行"
    exit 1
fi

# 检查数据库连接
echo "2. 检查数据库连接..."
if ! $COMPOSE_CMD exec clickhouse clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
    echo "错误: 无法连接到ClickHouse数据库"
    exit 1
fi

# 获取数据库列表
echo "3. 获取数据库列表..."
DATABASES=$($COMPOSE_CMD exec clickhouse clickhouse-client --query "
SELECT name FROM system.databases 
WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
" 2>/dev/null || echo "")

if [ -z "$DATABASES" ]; then
    echo "警告: 没有找到用户数据库"
    DATABASES="default"
fi

echo "将备份以下数据库: $DATABASES"

# 创建备份
echo "4. 开始创建备份..."
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# 备份每个数据库
for db in $DATABASES; do
    echo "备份数据库: $db"
    
    # 获取表列表
    TABLES=$($COMPOSE_CMD exec clickhouse clickhouse-client --query "
    SELECT name FROM system.tables 
    WHERE database = '$db' AND engine NOT LIKE '%View'
    " 2>/dev/null || echo "")
    
    if [ -n "$TABLES" ]; then
        # 创建数据库备份目录
        mkdir -p "$BACKUP_DIR/$BACKUP_NAME/$db"
        
        # 备份每个表
        for table in $TABLES; do
            echo "  备份表: $table"
            $COMPOSE_CMD exec clickhouse clickhouse-client --query "
            BACKUP TABLE $db.$table TO 'File(\"$BACKUP_DIR/$BACKUP_NAME/$db/$table.sql\")'
            " 2>/dev/null || echo "警告: 无法备份表 $table"
        done
    else
        echo "  数据库 $db 没有可备份的表"
        rm -rf "$BACKUP_DIR/$BACKUP_NAME"
        exit 1
    fi
done

# 备份配置文件
echo "5. 备份配置文件..."
cp -r clickhouse/config "$BACKUP_DIR/$BACKUP_NAME/"

# 备份docker-compose文件
cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/"

# 创建备份信息文件
echo "6. 创建备份信息..."
cat > "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt" << EOF
备份时间: $(date)
备份名称: $BACKUP_NAME
备份数据库: $DATABASES
ClickHouse版本: $($COMPOSE_CMD exec clickhouse clickhouse-client --query "SELECT version()" 2>/dev/null || echo "未知")
备份大小: $(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
EOF

# 压缩备份
echo "7. 压缩备份文件..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# 清理旧备份（保留最近5个）
echo "8. 清理旧备份..."
ls -t *.tar.gz | tail -n +6 | xargs -r rm -f

# 显示备份结果
echo ""
echo "=== 备份完成 ==="
echo "备份文件: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "备份大小: $(du -sh "$BACKUP_DIR/${BACKUP_NAME}.tar.gz" | cut -f1)"
echo ""
echo "备份信息:"
cat "$BACKUP_DIR/$BACKUP_NAME/backup_info.txt"

echo ""
echo "恢复命令示例:"
echo "  tar -xzf $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "  cd ${BACKUP_NAME}"
echo "  docker-compose down"
echo "  cp -r config clickhouse/"
echo "  docker-compose up -d" 