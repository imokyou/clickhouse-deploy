#!/bin/bash

# ClickHouse Server 服务启动脚本
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

echo "=== 启动ClickHouse服务 ==="

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

# 检查配置文件
check_config() {
    echo "检查配置文件..."
    
    # 检查主配置文件
    if [ ! -f /etc/clickhouse-server/config.d/config.xml ]; then
        echo "✗ 配置文件不存在: /etc/clickhouse-server/config.d/config.xml"
        exit 1
    fi
    
    # 测试配置文件
    # echo "测试配置文件..."
    # if clickhouse-server --config-file=/etc/clickhouse-server/config.d/config.xml --test-config; then
    #     echo "✓ 配置文件语法正确"
    # else
    #     echo "✗ 配置文件语法错误"
    #     exit 1
    # fi

    # 检查用户配置文件
    if [ ! -f /etc/clickhouse-server/users.d/users.xml ]; then
        echo "✗ 用户配置文件不存在: /etc/clickhouse-server/users.d/users.xml"
        exit 1
    fi
    
    # 测试用户配置文件
    # echo "测试用户配置文件..."
    # if clickhouse-server --config-file=/etc/clickhouse-server/users.d/users.xml --test-config; then
    #     echo "✓ 用户配置文件语法正确"
    # else
    #     echo "✗ 用户配置文件语法错误"
    #     exit 1
    # fi
}

# 启动服务
start_service() {
    echo "启动ClickHouse服务..."
    
    # 启用服务
    systemctl enable clickhouse-server
    
    # 启动服务
    systemctl start clickhouse-server
    
    # 等待服务启动
    echo "等待服务启动..."
    sleep 10
    
    # 检查服务状态
    if systemctl is-active --quiet clickhouse-server; then
        echo "✓ ClickHouse服务启动成功"
    else
        echo "✗ ClickHouse服务启动失败"
        echo "查看日志: journalctl -u clickhouse-server -n 50"
        exit 1
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
        return 1
    fi
    
    # 检查Native端口
    if netstat -tlnp | grep -q ":9000 "; then
        echo "✓ Native端口(9000)监听正常"
    else
        echo "✗ Native端口(9000)未监听"
        return 1
    fi
}

# 测试连接
test_connection() {
    echo "测试数据库连接..."
    
    # 测试基础连接
    if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query "SELECT 1" > /dev/null 2>&1; then
        echo "✓ 数据库连接正常"
    else
        echo "✗ 数据库连接失败"
        return 1
    fi
    
    # 测试版本查询
    if clickhouse-client --user=webuser --password=WebUser_2024_Secure! --query "SELECT version()" > /dev/null 2>&1; then
        echo "✓ 版本查询正常"
    else
        echo "✗ 版本查询失败"
        return 1
    fi
}

# 配置防火墙
configure_firewall() {
    echo "配置防火墙..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v firewall-cmd &> /dev/null; then
                firewall-cmd --permanent --add-port=8123/tcp
                firewall-cmd --permanent --add-port=9000/tcp
                firewall-cmd --reload
                echo "✓ 防火墙端口已开放"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                ufw allow 8123/tcp
                ufw allow 9000/tcp
                echo "✓ UFW防火墙端口已开放"
            elif command -v iptables &> /dev/null; then
                iptables -A INPUT -p tcp --dport 8123 -j ACCEPT
                iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
                echo "✓ iptables端口已开放"
            fi
            ;;
    esac
}

# 主函数
main() {
    detect_os
    check_config
    start_service
    check_ports
    test_connection
    configure_firewall
    
    echo ""
    echo "=== ClickHouse服务启动完成 ==="
    echo "访问信息:"
    echo "  HTTP接口: http://localhost:8123"
    echo "  Native接口: localhost:9000"
    echo "  默认用户: default"
    echo "  默认密码: clickhouse123"
    echo ""
    echo "常用命令:"
    echo "  查看服务状态: systemctl status clickhouse-server"
    echo "  查看日志: journalctl -u clickhouse-server -f"
    echo "  连接数据库: clickhouse-client"
}

# 执行主函数
main "$@" 