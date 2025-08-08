#!/bin/bash

# ClickHouse Server 一键部署脚本
# 自动完成从环境安装到服务部署的全过程
# 支持 RHEL 兼容发行版和 Ubuntu LTS / Debian

set -e

echo "=== ClickHouse Server 一键部署脚本 ==="
echo "此脚本将自动完成以下步骤："
echo "1. 平台兼容性测试"
echo "2. 系统环境准备"
echo "3. 安装ClickHouse"
echo "4. 配置ClickHouse服务"
echo "5. 启动和验证服务"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

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
    
    # 检查操作系统兼容性
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora"|"ubuntu"|"debian")
            echo "✓ 操作系统兼容性检查通过"
            ;;
        *)
            echo "✗ 不支持的操作系统: $OS_NAME"
            echo "支持的操作系统: RHEL/CentOS/Rocky/Alma/Fedora, Ubuntu/Debian"
            exit 1
            ;;
    esac
}

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 错误处理函数
handle_error() {
    echo "错误: 部署过程中出现错误"
    echo "请检查日志并手动修复问题"
    exit 1
}

# 设置错误处理
trap handle_error ERR

# 平台兼容性测试
run_platform_test() {
    echo ""
    echo "=== 步骤0: 平台兼容性测试 ==="
    if [ -f "$SCRIPT_DIR/platform-test.sh" ]; then
        if $SCRIPT_DIR/platform-test.sh; then
            echo "✓ 平台兼容性测试通过"
        else
            echo "✗ 平台兼容性测试失败"
            echo "请解决兼容性问题后重新运行部署脚本"
            exit 1
        fi
    else
        echo "⚠ 平台测试脚本不存在，跳过兼容性测试"
    fi
}

# 主部署流程
main() {
    # 检测操作系统
    detect_os
    
    # 平台兼容性测试
    run_platform_test
    
    # 步骤1: 系统环境准备
    echo ""
    echo "=== 步骤1: 系统环境准备 ==="
    if ! $SCRIPT_DIR/setup-system.sh; then
        echo "系统环境准备失败"
        exit 1
    fi

    # 步骤2: 安装ClickHouse
    echo ""
    echo "=== 步骤2: 安装ClickHouse ==="
    if ! $SCRIPT_DIR/install-clickhouse.sh; then
        echo "ClickHouse安装失败"
        exit 1
    fi

    # 步骤3: 配置ClickHouse
    echo ""
    echo "=== 步骤3: 配置ClickHouse ==="
    if ! $SCRIPT_DIR/setup-config.sh; then
        echo "ClickHouse配置失败"
        exit 1
    fi

    # 步骤4: 启动服务
    echo ""
    echo "=== 步骤4: 启动ClickHouse服务 ==="
    if ! $SCRIPT_DIR/start-service.sh; then
        echo "ClickHouse服务启动失败"
        exit 1
    fi

    # 步骤5: 健康检查
    echo ""
    echo "=== 步骤5: 健康检查 ==="
    if ! $SCRIPT_DIR/health-check.sh; then
        echo "健康检查失败"
        exit 1
    fi

    echo ""
    echo "=== 一键部署完成 ==="
    echo "ClickHouse服务已成功部署并运行"
    echo ""
    echo "访问信息:"
    echo "  HTTP接口: http://localhost:8123"
    echo "  Native接口: localhost:9000"
    echo "  默认用户: default"
    echo "  默认密码: StrongPassword123!"
    echo ""
    echo "常用命令:"
    echo "  查看服务状态: systemctl status clickhouse-server"
    echo "  查看日志: journalctl -u clickhouse-server -f"
    echo "  连接数据库: clickhouse-client"
    echo "  健康检查: $SCRIPT_DIR/health-check.sh"
    echo "  备份数据: $SCRIPT_DIR/backup.sh"
    echo "  监控服务: $SCRIPT_DIR/monitor.sh"
    echo "  平台测试: $SCRIPT_DIR/platform-test.sh"
    echo ""
    echo "系统信息:"
    echo "  操作系统: $OS_NAME $OS_VERSION"
    echo "  部署时间: $(date)"
    echo "  部署路径: $PROJECT_ROOT"
}

# 执行主函数
main "$@" 