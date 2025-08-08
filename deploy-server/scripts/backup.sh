#!/bin/bash

# ClickHouse Server 备份脚本

set -e

echo "=== ClickHouse 备份脚本 ==="

# 配置变量
BACKUP_DIR="/opt/clickhouse/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="clickhouse_backup_$DATE"
LOG_FILE="/opt/clickhouse/logs/backup_$DATE.log"

# 创建备份目录
mkdir -p $BACKUP_DIR
mkdir -p /opt/clickhouse/logs

# 记录开始时间
START_TIME=$(date)
echo "备份开始时间: $START_TIME" | tee -a $LOG_FILE

# 检查ClickHouse服务状态
echo "检查ClickHouse服务状态..." | tee -a $LOG_FILE
if ! systemctl is-active --quiet clickhouse-server; then
    echo "✗ ClickHouse服务未运行" | tee -a $LOG_FILE
    exit 1
fi

# 备份方式选择
BACKUP_TYPE=${1:-"full"}

case $BACKUP_TYPE in
    "full")
        echo "执行完整备份..." | tee -a $LOG_FILE
        perform_full_backup
        ;;
    "incremental")
        echo "执行增量备份..." | tee -a $LOG_FILE
        perform_incremental_backup
        ;;
    "config")
        echo "执行配置备份..." | tee -a $LOG_FILE
        perform_config_backup
        ;;
    *)
        echo "未知的备份类型: $BACKUP_TYPE" | tee -a $LOG_FILE
        echo "支持的备份类型: full, incremental, config" | tee -a $LOG_FILE
        exit 1
        ;;
esac

# 记录结束时间
END_TIME=$(date)
echo "备份结束时间: $END_TIME" | tee -a $LOG_FILE

echo "=== 备份完成 ===" | tee -a $LOG_FILE

# 清理旧备份
cleanup_old_backups

exit 0

# 完整备份函数
perform_full_backup() {
    echo "开始完整备份..." | tee -a $LOG_FILE
    
    # 停止服务（可选，用于一致性备份）
    echo "停止ClickHouse服务..." | tee -a $LOG_FILE
    systemctl stop clickhouse-server
    
    # 备份数据目录
    echo "备份数据目录..." | tee -a $LOG_FILE
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_data.tar.gz" \
        -C /var/lib/clickhouse/ . \
        --exclude='tmp' \
        --exclude='user_files' \
        --exclude='*.tmp' \
        2>> $LOG_FILE
    
    # 备份配置文件
    echo "备份配置文件..." | tee -a $LOG_FILE
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_config.tar.gz" \
        -C /etc/clickhouse-server/ . \
        2>> $LOG_FILE
    
    # 启动服务
    echo "启动ClickHouse服务..." | tee -a $LOG_FILE
    systemctl start clickhouse-server
    
    # 等待服务启动
    sleep 10
    
    # 验证服务状态
    if systemctl is-active --quiet clickhouse-server; then
        echo "✓ 服务启动成功" | tee -a $LOG_FILE
    else
        echo "✗ 服务启动失败" | tee -a $LOG_FILE
        exit 1
    fi
    
    echo "完整备份完成: ${BACKUP_NAME}" | tee -a $LOG_FILE
}

# 增量备份函数
perform_incremental_backup() {
    echo "开始增量备份..." | tee -a $LOG_FILE
    
    # 获取数据库列表
    DATABASES=$(clickhouse-client --query "
    SELECT name 
    FROM system.databases 
    WHERE name NOT IN ('system', 'information_schema', 'INFORMATION_SCHEMA')
    " 2>/dev/null || echo "")
    
    if [ -z "$DATABASES" ]; then
        echo "没有找到需要备份的数据库" | tee -a $LOG_FILE
        return
    fi
    
    # 为每个数据库创建备份
    for DB in $DATABASES; do
        echo "备份数据库: $DB" | tee -a $LOG_FILE
        
        # 获取表列表
        TABLES=$(clickhouse-client --query "
        SELECT name 
        FROM system.tables 
        WHERE database = '$DB'
        " 2>/dev/null || echo "")
        
        for TABLE in $TABLES; do
            echo "备份表: $DB.$TABLE" | tee -a $LOG_FILE
            
            # 创建表备份
            clickhouse-client --query "
            BACKUP TABLE $DB.$TABLE 
            TO '$BACKUP_DIR/${BACKUP_NAME}_${DB}_${TABLE}'
            " 2>> $LOG_FILE
            
            # 压缩备份
            if [ -d "$BACKUP_DIR/${BACKUP_NAME}_${DB}_${TABLE}" ]; then
                tar -czf "$BACKUP_DIR/${BACKUP_NAME}_${DB}_${TABLE}.tar.gz" \
                    -C "$BACKUP_DIR" "${BACKUP_NAME}_${DB}_${TABLE}" 2>> $LOG_FILE
                
                # 清理临时文件
                rm -rf "$BACKUP_DIR/${BACKUP_NAME}_${DB}_${TABLE}"
            fi
        done
    done
    
    echo "增量备份完成: ${BACKUP_NAME}" | tee -a $LOG_FILE
}

# 配置备份函数
perform_config_backup() {
    echo "开始配置备份..." | tee -a $LOG_FILE
    
    # 备份配置文件
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_config.tar.gz" \
        -C /etc/clickhouse-server/ . \
        2>> $LOG_FILE
    
    # 备份systemd服务文件
    if [ -f /etc/systemd/system/clickhouse-server.service ]; then
        cp /etc/systemd/system/clickhouse-server.service \
           "$BACKUP_DIR/${BACKUP_NAME}_systemd.service"
    fi
    
    # 备份系统配置
    tar -czf "$BACKUP_DIR/${BACKUP_NAME}_system.tar.gz" \
        /etc/sysctl.conf \
        /etc/security/limits.conf \
        2>> $LOG_FILE
    
    echo "配置备份完成: ${BACKUP_NAME}" | tee -a $LOG_FILE
}

# 清理旧备份函数
cleanup_old_backups() {
    echo "清理旧备份..." | tee -a $LOG_FILE
    
    # 保留最近7天的备份
    find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete 2>> $LOG_FILE
    
    # 保留最近30天的日志
    find /opt/clickhouse/logs -name "backup_*.log" -mtime +30 -delete 2>> $LOG_FILE
    
    echo "旧备份清理完成" | tee -a $LOG_FILE
} 