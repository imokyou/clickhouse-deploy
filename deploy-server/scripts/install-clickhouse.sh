#!/bin/bash

# ClickHouse Server 安装脚本
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

echo "=== 安装ClickHouse ==="

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

# 安装依赖包
install_dependencies() {
    echo "安装系统依赖包..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            # RHEL 兼容发行版
            if command -v dnf &> /dev/null; then
                dnf install -y wget curl ca-certificates gnupg2
            else
                yum install -y wget curl ca-certificates gnupg2
            fi
            ;;
        "ubuntu"|"debian")
            # Ubuntu/Debian
            apt update -y
            apt install -y wget curl ca-certificates gnupg2
            ;;
        *)
            echo "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
}

# 添加ClickHouse官方仓库
add_clickhouse_repo() {
    echo "添加ClickHouse官方仓库..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            # RHEL 兼容发行版
            if command -v dnf &> /dev/null; then
                dnf install -y yum-utils
                dnf config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
            else
                yum install -y yum-utils
                yum-config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
            fi
            ;;
        "ubuntu"|"debian")
            # Ubuntu/Debian
            apt install -y apt-transport-https ca-certificates dirmngr
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754
            echo "deb https://packages.clickhouse.com/deb stable main" | tee /etc/apt/sources.list.d/clickhouse.list
            apt update
            ;;
        *)
            echo "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
}

# 安装ClickHouse
install_clickhouse() {
    echo "安装ClickHouse..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v dnf &> /dev/null; then
                dnf install -y clickhouse-server clickhouse-client
            else
                yum install -y clickhouse-server clickhouse-client
            fi
            ;;
        "ubuntu"|"debian")
            apt install -y clickhouse-server clickhouse-client
            ;;
        *)
            echo "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
}

# 验证安装
verify_installation() {
    echo "验证ClickHouse安装..."
    
    if command -v clickhouse-server &> /dev/null; then
        echo "✓ ClickHouse Server 安装成功"
    else
        echo "✗ ClickHouse Server 安装失败"
        exit 1
    fi

    if command -v clickhouse-client &> /dev/null; then
        echo "✓ ClickHouse Client 安装成功"
    else
        echo "✗ ClickHouse Client 安装失败"
        exit 1
    fi

    # 显示版本信息
    echo "ClickHouse版本信息:"
    clickhouse-server --version
    clickhouse-client --version
}

# 主函数
main() {
    detect_os
    install_dependencies
    add_clickhouse_repo
    install_clickhouse
    verify_installation
    
    echo "=== ClickHouse安装完成 ==="
}

# 执行主函数
main "$@" 