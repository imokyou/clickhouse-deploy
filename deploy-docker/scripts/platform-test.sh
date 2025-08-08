#!/bin/bash

# ClickHouse 平台兼容性测试脚本
# 测试系统环境、Docker环境和ClickHouse部署

set -e

echo "=== ClickHouse 平台兼容性测试 ==="

# 检查Docker Compose命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    COMPOSE_VERSION=$($COMPOSE_CMD --version)
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
    COMPOSE_VERSION=$(docker compose version)
else
    echo "错误: Docker Compose未安装"
    exit 1
fi

# 测试系统环境
test_system_environment() {
    echo ""
    echo "=== 系统环境测试 ==="
    
    # 检测操作系统
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
    echo "操作系统: $OS $VER"
    
    # 检查内核版本
    KERNEL=$(uname -r)
    echo "内核版本: $KERNEL"
    
    # 检查系统架构
    ARCH=$(uname -m)
    echo "系统架构: $ARCH"
    
    # 检查内存
    if command -v free &> /dev/null; then
        TOTAL_MEM=$(free -h | grep Mem | awk '{print $2}')
        echo "总内存: $TOTAL_MEM"
    fi
    
    # 检查磁盘空间
    if command -v df &> /dev/null; then
        DISK_SPACE=$(df -h / | tail -1 | awk '{print $4}')
        echo "可用磁盘空间: $DISK_SPACE"
    fi
}

# 测试Docker环境
test_docker_environment() {
    echo ""
    echo "=== Docker环境测试 ==="
    
    # 检查Docker版本
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version)
        echo "Docker版本: $DOCKER_VERSION"
    else
        echo "✗ Docker未安装"
        return 1
    fi
    
    # 检查Docker Compose版本
    echo "Docker Compose版本: $COMPOSE_VERSION"
    
    # 检查Docker服务状态
    if systemctl is-active --quiet docker; then
        echo "✓ Docker服务正在运行"
    else
        echo "✗ Docker服务未运行"
        return 1
    fi
    
    # 测试Docker权限
    if docker info &> /dev/null; then
        echo "✓ Docker权限正常"
    else
        echo "✗ Docker权限异常"
        return 1
    fi
    
    # 测试Docker网络
    if docker network ls &> /dev/null; then
        echo "✓ Docker网络正常"
    else
        echo "✗ Docker网络异常"
        return 1
    fi
}

# 测试网络连接
test_network_connectivity() {
    echo ""
    echo "=== 网络连接测试 ==="
    
    # 测试DNS解析
    if nslookup google.com &> /dev/null; then
        echo "✓ DNS解析正常"
    else
        echo "✗ DNS解析异常"
    fi
    
    # 测试Docker Hub连接
    if curl -s https://registry-1.docker.io/v2/ &> /dev/null; then
        echo "✓ Docker Hub连接正常"
    else
        echo "✗ Docker Hub连接异常"
    fi
    
    # 测试ClickHouse镜像拉取
    echo "测试ClickHouse镜像拉取..."
    if docker pull clickhouse/clickhouse-server:latest &> /dev/null; then
        echo "✓ ClickHouse镜像拉取成功"
    else
        echo "✗ ClickHouse镜像拉取失败"
    fi
}

# 测试端口可用性
test_port_availability() {
    echo ""
    echo "=== 端口可用性测试 ==="
    
    # 检查8123端口
    if netstat -tuln 2>/dev/null | grep -q ":8123 "; then
        echo "⚠ 端口8123已被占用"
    else
        echo "✓ 端口8123可用"
    fi
    
    # 检查9000端口
    if netstat -tuln 2>/dev/null | grep -q ":9000 "; then
        echo "⚠ 端口9000已被占用"
    else
        echo "✓ 端口9000可用"
    fi
}

# 测试ClickHouse部署
test_clickhouse_deployment() {
    echo ""
    echo "=== ClickHouse部署测试 ==="
    
    # 检查docker-compose.yml文件
    if [ -f "docker-compose.yml" ]; then
        echo "✓ docker-compose.yml文件存在"
    else
        echo "✗ docker-compose.yml文件不存在"
        return 1
    fi
    
    # 检查主配置文件
    if [ -f "clickhouse/config/config.xml" ]; then
        echo "✓ 主配置文件 config.xml 存在"
    else
        echo "✗ 主配置文件 config.xml 不存在"
    fi
    
    # 使用xmllint验证XML
    if command -v xmllint &> /dev/null; then
        if [ -f "clickhouse/config/config.xml" ]; then
            if xmllint --noout clickhouse/config/config.xml 2>/dev/null; then
                echo "✓ config.xml 语法正确"
            else
                echo "✗ config.xml 语法错误"
            fi
        fi
    else
        echo "未检测到 xmllint，跳过XML语法验证"
    fi
}

# 测试性能基准
test_performance_benchmark() {
    echo ""
    echo "=== 性能基准测试 ==="
    
    # 测试磁盘I/O
    if command -v dd &> /dev/null; then
        echo "测试磁盘写入性能..."
        DD_RESULT=$(dd if=/dev/zero of=/tmp/test_file bs=1M count=100 2>&1 | tail -1)
        echo "磁盘写入测试: $DD_RESULT"
        rm -f /tmp/test_file
    fi
    
    # 测试内存性能
    if command -v sysbench &> /dev/null; then
        echo "测试内存性能..."
        sysbench memory --memory-block-size=1K --memory-total-size=100M run 2>/dev/null | grep "transferred" || echo "内存测试完成"
    fi
}

# 生成测试报告
generate_test_report() {
    echo ""
    echo "=== 测试报告 ==="
    echo "测试时间: $(date)"
    echo "测试系统: $OS $VER"
    echo "Docker版本: $(docker --version 2>/dev/null || echo "未安装")"
    echo "Docker Compose: $(command -v docker-compose >/dev/null && echo "已安装" || echo "未安装")"
    echo "Docker Compose插件: $(docker compose version >/dev/null 2>&1 && echo "已安装" || echo "未安装")"
    
    echo ""
    echo "建议:"
    if ! command -v docker &> /dev/null; then
        echo "- 需要安装Docker"
    fi
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo "- 需要安装Docker Compose"
    fi
    if ! systemctl is-active --quiet docker; then
        echo "- 需要启动Docker服务"
    fi
}

# 主函数
main() {
    test_system_environment
    test_docker_environment
    test_network_connectivity
    test_port_availability
    test_clickhouse_deployment
    test_performance_benchmark
    generate_test_report
    
    echo ""
    echo "=== 平台测试完成 ==="
}

# 执行主函数
main 