#!/bin/bash

# ClickHouse Server 系统环境准备脚本
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

echo "=== 系统环境准备 ==="

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

# 更新系统包
update_system() {
    echo "更新系统包..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v dnf &> /dev/null; then
                dnf update -y
                dnf install -y wget curl git vim net-tools
            else
                yum update -y
                yum install -y wget curl git vim net-tools
            fi
            ;;
        "ubuntu"|"debian")
            apt update -y
            apt install -y wget curl git vim net-tools
            ;;
        *)
            echo "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
}

# 创建ClickHouse用户
create_clickhouse_user() {
    echo "创建ClickHouse用户..."
    if ! id "clickhouse" &>/dev/null; then
        useradd -r -s /bin/false -d /var/lib/clickhouse clickhouse
    fi
}

# 创建必要目录
create_directories() {
    echo "创建必要目录..."
    mkdir -p /var/lib/clickhouse
    mkdir -p /var/log/clickhouse-server
    mkdir -p /etc/clickhouse-server
    mkdir -p /etc/clickhouse-server/config.d
    mkdir -p /opt/clickhouse/backups
    mkdir -p /opt/clickhouse/logs

    # 设置目录权限
    chown -R clickhouse:clickhouse /var/lib/clickhouse
    chown -R clickhouse:clickhouse /var/log/clickhouse-server
    chown -R clickhouse:clickhouse /etc/clickhouse-server
    chown -R clickhouse:clickhouse /opt/clickhouse
}

# 配置系统参数
configure_system_params() {
    echo "配置系统参数..."
    cat >> /etc/sysctl.conf << EOF
# ClickHouse优化参数
fs.file-max = 65536
fs.nr_open = 65536
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

    # 应用系统参数
    sysctl -p
}

# 配置用户限制
configure_user_limits() {
    echo "配置用户限制..."
    cat >> /etc/security/limits.conf << EOF
# ClickHouse用户限制
clickhouse soft nofile 65536
clickhouse hard nofile 65536
clickhouse soft nproc 32768
clickhouse hard nproc 32768
EOF
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
                echo "防火墙端口已开放"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                ufw allow 8123/tcp
                ufw allow 9000/tcp
                echo "UFW防火墙端口已开放"
            elif command -v iptables &> /dev/null; then
                iptables -A INPUT -p tcp --dport 8123 -j ACCEPT
                iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
                echo "iptables端口已开放"
            fi
            ;;
    esac
}

# 配置SELinux（如果启用）
configure_selinux() {
    if command -v sestatus &> /dev/null && sestatus | grep -q "enabled"; then
        echo "配置SELinux..."
        setsebool -P clickhouse_can_network_connect 1
        setsebool -P clickhouse_can_network_connect_db 1
    fi
}

# 配置AppArmor（Ubuntu/Debian）
configure_apparmor() {
    case "$OS_NAME" in
        "ubuntu"|"debian")
            if command -v apparmor_status &> /dev/null; then
                echo "配置AppArmor..."
                # 如果ClickHouse有AppArmor配置文件，需要配置
                if [ -f /etc/apparmor.d/usr.bin.clickhouse-server ]; then
                    apparmor_parser -r /etc/apparmor.d/usr.bin.clickhouse-server
                fi
            fi
            ;;
    esac
}

# 主函数
main() {
    detect_os
    update_system
    create_clickhouse_user
    create_directories
    configure_system_params
    configure_user_limits
    configure_firewall
    configure_selinux
    configure_apparmor
    
    echo "=== 系统环境准备完成 ==="
}

# 执行主函数
main "$@" 