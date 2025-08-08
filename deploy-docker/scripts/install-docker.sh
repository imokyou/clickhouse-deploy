#!/bin/bash

# ClickHouse Docker 环境安装脚本
# 兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统

set -e

echo "=== 开始安装 Docker 环境 ==="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

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

# 安装基础工具（通用）
install_basic_tools() {
    echo "1. 安装基础工具..."
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu 系统
        apt-get update
        apt-get install -y wget curl git vim net-tools ca-certificates gnupg lsb-release
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 系统
        yum update -y
        yum install -y wget curl git vim net-tools
    elif command -v dnf &> /dev/null; then
        # Fedora/RHEL 8+ 系统
        dnf update -y
        dnf install -y wget curl git vim net-tools
    else
        echo "不支持的操作系统包管理器"
        exit 1
    fi
}

# 安装Docker（Ubuntu/Debian）
install_docker_ubuntu() {
    echo "2. 安装Docker (Ubuntu/Debian)..."
    
    # 卸载旧版本
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # 安装依赖
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # 添加Docker官方GPG密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加Docker仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新包索引
    apt-get update
    
    # 安装Docker
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# 安装Docker（RHEL/CentOS）
install_docker_rhel() {
    echo "2. 安装Docker (RHEL/CentOS)..."
    
    # 卸载旧版本
    yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # 安装依赖
    yum install -y yum-utils device-mapper-persistent-data lvm2
    
    # 添加Docker仓库
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # 安装Docker
    yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# 安装Docker（Fedora/RHEL 8+）
install_docker_fedora() {
    echo "2. 安装Docker (Fedora/RHEL 8+)..."
    
    # 卸载旧版本
    dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
    
    # 安装依赖
    dnf install -y dnf-plugins-core
    
    # 添加Docker仓库
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    
    # 安装Docker
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# 安装Docker Compose（如果未通过插件安装）
install_docker_compose() {
    echo "3. 安装Docker Compose..."
    
    # 检查是否已安装独立版本
    if command -v docker-compose &> /dev/null; then
        echo "✓ Docker Compose独立版本已安装"
        COMPOSE_VERSION=$(docker-compose --version)
        echo "  Docker Compose版本: $COMPOSE_VERSION"
        return 0
    fi

    # 检查是否已安装插件版本
    if docker compose version &> /dev/null; then
        echo "✓ Docker Compose插件已安装"
        COMPOSE_VERSION=$(docker compose version)
        echo "  Docker Compose版本: $COMPOSE_VERSION"
        return 0
    fi  
    
    # 安装独立版本作为备用
    echo "安装Docker Compose独立版本..."
    curl -L "https://github.com/docker/compose/releases/download/v2.39.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    if command -v docker-compose &> /dev/null; then
        echo "✓ Docker Compose独立版本安装成功"
        COMPOSE_VERSION=$(docker-compose --version)
        echo "  Docker Compose版本: $COMPOSE_VERSION"
    else
        echo "✗ Docker Compose安装失败"
        return 1
    fi
}

# 配置Docker服务
setup_docker_service() {
    echo "4. 配置Docker服务..."
    
    # 启动Docker服务
    systemctl start docker
    systemctl enable docker
    
    # 验证Docker安装
    echo "5. 验证Docker安装..."
    docker --version
    
    # 验证Docker Compose安装
    echo "6. 验证Docker Compose安装..."
    if command -v docker-compose &> /dev/null; then
        echo "✓ 使用Docker Compose独立版本"
        docker-compose --version
    elif docker compose version &> /dev/null; then
        echo "✓ 使用Docker Compose插件版本"
        docker compose version
    else
        echo "✗ Docker Compose未正确安装"
        return 1
    fi
    
    # 配置Docker用户组
    echo "7. 配置Docker用户组..."
    groupadd docker 2>/dev/null || true
    usermod -aG docker $SUDO_USER
    
    echo "=== Docker 环境安装完成 ==="
    echo "请重新登录或执行 'newgrp docker' 使组权限生效"
    echo ""
    echo "Docker Compose使用说明:"
    if command -v docker-compose &> /dev/null; then
        echo "  使用独立版本: docker-compose <command>"
    elif docker compose version &> /dev/null; then
        echo "  使用插件版本: docker compose <command>"
    fi
}

# 主函数
main() {
    detect_os
    install_basic_tools
    
    # 根据包管理器选择安装方式
    if command -v apt-get &> /dev/null; then
        install_docker_ubuntu
    elif command -v yum &> /dev/null; then
        install_docker_rhel
    elif command -v dnf &> /dev/null; then
        install_docker_fedora
    else
        echo "不支持的操作系统包管理器"
        exit 1
    fi
    
    install_docker_compose
    setup_docker_service
}

# 执行主函数
main 