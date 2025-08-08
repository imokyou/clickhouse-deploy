#!/bin/bash

# ClickHouse Server 健康检查脚本
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

echo "=== ClickHouse 健康检查 ==="

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$ID"
        OS_VERSION="$VERSION_ID"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="rhel"
        OS_VERSION=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
    elif [ -f /etc/debian_version ]; then
        OS_NAME="debian"
        OS_VERSION=$(cat /etc/debian_version)
    else
        echo "无法检测操作系统类型"
        exit 1
    fi
    
    echo "检测到操作系统: $OS_NAME $OS_VERSION"
}

# 检查服务状态
check_service_status() {
    echo "检查服务状态..."
    if systemctl is-active --quiet clickhouse-server; then
        echo "✓ 服务运行正常"
        return 0
    else
        echo "✗ 服务未运行"
        return 1
    fi
}

# 检查端口监听
check_ports() {
    echo "检查端口监听..."
    
    # 检查HTTP端口
    if netstat -tlnp | grep -q ":8123 "; then
        echo "✓ HTTP端口(8123)监听正常"
    else
        echo "✗ HTTP端口(8123)未监听"
    fi
    
    # 检查Native端口
    if netstat -tlnp | grep -q ":9000 "; then
        echo "✓ Native端口(9000)监听正常"
    else
        echo "✗ Native端口(9000)未监听"
    fi
}

# 检查数据库连接
check_database_connection() {
    echo "检查数据库连接..."
    
    # 测试基础连接
    if clickhouse-client --query "SELECT 1" > /dev/null 2>&1; then
        echo "✓ 数据库连接正常"
        return 0
    else
        echo "✗ 数据库连接失败"
        return 1
    fi
}

# 检查系统表
check_system_tables() {
    echo "检查系统表..."
    if clickhouse-client --query "SELECT count() FROM system.tables" > /dev/null 2>&1; then
        echo "✓ 系统表访问正常"
        return 0
    else
        echo "✗ 系统表访问失败"
        return 1
    fi
}

# 检查内存使用
check_memory_usage() {
    echo "检查内存使用..."
    MEMORY_USAGE=$(clickhouse-client --query "
    SELECT value 
    FROM system.metrics 
    WHERE metric = 'MemoryUsage'
    " 2>/dev/null || echo "0")

    if [ "$MEMORY_USAGE" -gt 0 ]; then
        echo "✓ 内存使用正常: $MEMORY_USAGE bytes"
        return 0
    else
        echo "✗ 无法获取内存使用信息"
        return 1
    fi
}

# 检查连接数
check_connections() {
    echo "检查连接数..."
    CONNECTIONS=$(clickhouse-client --query "
    SELECT count() 
    FROM system.processes
    " 2>/dev/null || echo "0")

    echo "当前连接数: $CONNECTIONS"
    return 0
}

# 检查查询性能
check_query_performance() {
    echo "检查查询性能..."
    QUERY_TIME=$(clickhouse-client --query "
    SELECT query_duration_ms
    FROM system.query_log 
    WHERE query LIKE 'SELECT 1'
    ORDER BY event_time DESC 
    LIMIT 1
    " 2>/dev/null || echo "0")

    if [ "$QUERY_TIME" -gt 0 ] && [ "$QUERY_TIME" -lt 1000 ]; then
        echo "✓ 查询性能正常: ${QUERY_TIME}ms"
        return 0
    else
        echo "⚠ 查询性能异常: ${QUERY_TIME}ms"
        return 1
    fi
}

# 检查磁盘使用
check_disk_usage() {
    echo "检查磁盘使用..."
    
    # 检查数据目录
    if [ -d "/var/lib/clickhouse/" ]; then
        DISK_USAGE=$(du -sh /var/lib/clickhouse/ 2>/dev/null | awk '{print $1}' || echo "未知")
        echo "数据目录大小: $DISK_USAGE"
    else
        echo "✗ 数据目录不存在"
        return 1
    fi
    
    # 检查磁盘空间
    DISK_FREE=$(df -h /var/lib/clickhouse/ | tail -1 | awk '{print $4}')
    echo "可用磁盘空间: $DISK_FREE"
    
    return 0
}

# 检查错误日志
check_error_logs() {
    echo "检查错误日志..."
    ERROR_COUNT=$(clickhouse-client --query "
    SELECT count() 
    FROM system.text_log 
    WHERE level >= 'Error' 
    AND event_time >= now() - INTERVAL 1 HOUR
    " 2>/dev/null || echo "0")

    if [ "$ERROR_COUNT" -eq 0 ]; then
        echo "✓ 无错误日志"
        return 0
    else
        echo "⚠ 发现 $ERROR_COUNT 条错误日志"
        return 1
    fi
}

# 检查防火墙状态
check_firewall() {
    echo "检查防火墙状态..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v firewall-cmd &> /dev/null; then
                if firewall-cmd --list-ports | grep -q "8123/tcp"; then
                    echo "✓ 防火墙端口8123已开放"
                else
                    echo "⚠ 防火墙端口8123未开放"
                fi
                if firewall-cmd --list-ports | grep -q "9000/tcp"; then
                    echo "✓ 防火墙端口9000已开放"
                else
                    echo "⚠ 防火墙端口9000未开放"
                fi
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                if ufw status | grep -q "8123"; then
                    echo "✓ UFW端口8123已开放"
                else
                    echo "⚠ UFW端口8123未开放"
                fi
                if ufw status | grep -q "9000"; then
                    echo "✓ UFW端口9000已开放"
                else
                    echo "⚠ UFW端口9000未开放"
                fi
            fi
            ;;
    esac
}

# 生成健康报告
generate_report() {
    echo ""
    echo "=== 健康检查报告 ==="
    echo "操作系统: $OS_NAME $OS_VERSION"
    echo "检查时间: $(date)"
    echo "服务状态: $(systemctl is-active clickhouse-server)"
    echo "HTTP端口: $(netstat -tlnp | grep ':8123' | wc -l) 个监听"
    echo "Native端口: $(netstat -tlnp | grep ':9000' | wc -l) 个监听"
    echo "连接数: $CONNECTIONS"
    echo "内存使用: $MEMORY_USAGE bytes"
    echo "查询响应: ${QUERY_TIME}ms"
    echo "数据大小: $DISK_USAGE"
    echo "错误数量: $ERROR_COUNT"
}

# 主函数
main() {
    detect_os
    
    # 执行各项检查
    check_service_status
    check_ports
    check_database_connection
    check_system_tables
    check_memory_usage
    check_connections
    check_query_performance
    check_disk_usage
    check_error_logs
    check_firewall
    
    # 生成报告
    generate_report
    
    echo ""
    echo "=== 健康检查完成 ==="
}

# 执行主函数
main "$@" 