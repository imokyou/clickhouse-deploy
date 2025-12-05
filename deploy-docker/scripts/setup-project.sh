#!/bin/bash

# ClickHouse 项目设置脚本
# 兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统
# 自动创建目录结构和配置文件

set -e

# 默认环境
ENV="dev"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -env|--environment)
            ENV="$2"
            shift 2
            ;;
        *)
            echo "未知参数: $1"
            echo "使用方法: $0 [-env ENV]"
            exit 1
            ;;
    esac
done

# 验证环境参数
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
    echo "错误: 环境参数必须是 dev, test 或 prod"
    exit 1
fi

echo "=== 开始设置 ClickHouse 项目 ==="
echo "部署环境: $ENV"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 根据环境设置部署目录
DEPLOY_DIR="/opt/clickhouse-deploy-${ENV}"

# 检测操作系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        OS=SuSE
    elif [ -f /etc/redhat-release ]; then
        OS=RedHat
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    echo "检测到操作系统: $OS $VER"
}

# 配置防火墙（通用函数）
configure_firewall() {
    echo "4. 配置防火墙规则..."
    
    # 检测防火墙类型
    if systemctl is-active --quiet firewalld; then
        echo "检测到 firewalld，配置端口开放..."
        # 开放ClickHouse端口
        firewall-cmd --permanent --add-port=8123/tcp
        firewall-cmd --permanent --add-port=9000/tcp
        firewall-cmd --reload
        echo "firewalld端口配置完成"
    elif systemctl is-active --quiet ufw; then
        echo "检测到 ufw，配置端口开放..."
        # 开放ClickHouse端口
        ufw allow 8123/tcp
        ufw allow 9000/tcp
        echo "ufw端口配置完成"
    elif systemctl is-active --quiet iptables; then
        echo "检测到 iptables，配置端口开放..."
        # 开放ClickHouse端口
        iptables -A INPUT -p tcp --dport 8123 -j ACCEPT
        iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
        # 保存iptables规则
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
        fi
        echo "iptables端口配置完成"
    else
        echo "防火墙未启用，跳过端口配置"
        echo "注意：如果后续需要启用防火墙，请手动配置端口开放"
        echo "需要开放的端口："
        echo "  - 8123/tcp (HTTP接口)"
        echo "  - 9000/tcp (Native接口)"
    fi
}

# 安装XML工具（用于XML验证）
install_xml_tools() {
    if ! command -v xmllint &> /dev/null; then
        echo "安装XML工具用于配置文件验证..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y libxml2-utils
        elif command -v yum &> /dev/null; then
            yum install -y libxml2
        elif command -v dnf &> /dev/null; then
            dnf install -y libxml2
        fi
    fi
}

# 验证配置文件（XML语法基本检查）
validate_configs() {
    echo "5. 验证配置文件..."
    if command -v xmllint &> /dev/null; then
        echo "验证主配置文件..."
        if [ -f "clickhouse/config/config.d/config.xml" ]; then
            if xmllint --noout clickhouse/config/config.d/config.xml 2>/dev/null; then
                echo "✓ config.xml 语法基本正确"
            else
                echo "✗ config.xml 存在语法问题"
            fi
        else
            echo "⚠ config.xml 文件不存在"
        fi

         echo "验证用户配置文件..."
        if [ -f "clickhouse/config/users.d/users.xml" ]; then
            if xmllint --noout clickhouse/config/users.d/users.xml 2>/dev/null; then
                echo "✓ users.xml 语法基本正确"
            else
                echo "✗ config.xml 存在语法问题"
            fi
        else
            echo "⚠ config.xml 文件不存在"
        fi
    else
        echo "未检测到 xmllint，跳过XML验证"
    fi
}

echo "1. 创建项目目录结构..."
sudo mkdir -p $DEPLOY_DIR
sudo chown -R $USER:$USER $DEPLOY_DIR

cd $DEPLOY_DIR

# 创建目录结构
mkdir -p clickhouse/{config,logs,data}
mkdir -p scripts
mkdir -p docs

echo "2. 复制配置文件..."
# 复制Docker Compose配置
cp $PROJECT_ROOT/docker-compose.yml ./

# 复制配置文件
cp -r $PROJECT_ROOT/clickhouse/config/* clickhouse/config/

# 复制脚本文件
cp $PROJECT_ROOT/scripts/*.sh scripts/
chmod +x scripts/*.sh

# 复制文档
cp $PROJECT_ROOT/docs/*.md docs/

echo "3. 设置目录权限..."
chmod -R 755 $DEPLOY_DIR
chmod -R 777 clickhouse/logs
chmod -R 777 clickhouse/data

# 检测操作系统并配置防火墙
detect_os
configure_firewall

# 安装验证工具并验证配置
install_xml_tools
validate_configs

echo "=== 项目设置完成 ==="
echo "项目目录: $DEPLOY_DIR"
echo "配置文件已复制到相应位置"
echo "可以运行 './scripts/deploy.sh' 开始部署" 