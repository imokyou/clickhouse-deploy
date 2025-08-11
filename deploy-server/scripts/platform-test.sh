#!/bin/bash

# ClickHouse 平台兼容性测试脚本
# 测试系统是否支持 ClickHouse 部署

set -e

echo "=== ClickHouse 平台兼容性测试 ==="

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
        return 1
    fi
    
    echo "检测到操作系统: $OS_NAME $OS_VERSION"
    return 0
}

# 检查操作系统兼容性
check_os_compatibility() {
    echo "检查操作系统兼容性..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora"|"ubuntu"|"debian")
            echo "✓ 操作系统兼容: $OS_NAME $OS_VERSION"
            return 0
            ;;
        *)
            echo "✗ 不支持的操作系统: $OS_NAME"
            return 1
            ;;
    esac
}

# 检查系统架构
check_architecture() {
    echo "检查系统架构..."
    ARCH=$(uname -m)
    
    case "$ARCH" in
        "x86_64"|"amd64")
            echo "✓ 系统架构兼容: $ARCH"
            return 0
            ;;
        *)
            echo "✗ 不支持的系统架构: $ARCH"
            return 1
            ;;
    esac
}

# 检查硬件配置
check_hardware() {
    echo "检查硬件配置..."
    
    # 检查CPU核心数
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -ge 4 ]; then
        echo "✓ CPU核心数满足要求: $CPU_CORES 核"
    else
        echo "⚠ CPU核心数不足: $CPU_CORES 核 (推荐4核以上)"
    fi
    
    # 检查内存大小 - 使用KB为单位避免进制问题
    MEMORY_KB=$(free -k | awk 'NR==2{print $2}')
    MEMORY_GB_1024=$(echo "scale=1; $MEMORY_KB / 1024 / 1024" | bc -l)
    MEMORY_GB_1000=$(echo "scale=1; $MEMORY_KB / 1000 / 1000" | bc -l)
    
    echo "内存信息: ${MEMORY_KB}KB (约${MEMORY_GB_1024}GB 1024进制 / ${MEMORY_GB_1000}GB 1000进制)"
    
    # 使用bc进行浮点数比较
    if [ "$(echo "$MEMORY_GB_1024 >= 16" | bc -l)" -eq 1 ] || [ "$(echo "$MEMORY_GB_1000 >= 15" | bc -l)" -eq 1 ]; then
        echo "✓ 内存大小满足要求"
    else
        echo "⚠ 内存大小不足 (推荐16GB以上)"
    fi
    
    # 检查磁盘空间 - 使用字节为单位避免进制问题
    DISK_BYTES=$(df -B1 / | awk 'NR==2{print $4}')
    DISK_GB_1024=$((DISK_BYTES / 1024 / 1024 / 1024))
    DISK_GB_1000=$((DISK_BYTES / 1000 / 1000 / 1000))
    
    echo "磁盘空间: ${DISK_BYTES}字节 (约${DISK_GB_1024}GB 1024进制 / ${DISK_GB_1000}GB 1000进制)"
    
    if [ "$DISK_GB_1024" -ge 150 ] || [ "$DISK_GB_1000" -ge 145 ]; then
        echo "✓ 磁盘空间满足要求"
    else
        echo "⚠ 磁盘空间不足 (推荐150GB以上)"
    fi
}

# 检查网络连接
check_network() {
    echo "检查网络连接..."
    
    # 测试DNS解析
    if nslookup google.com > /dev/null 2>&1; then
        echo "✓ DNS解析正常"
    else
        echo "✗ DNS解析失败"
        return 1
    fi
    
    # 测试网络连通性
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo "✓ 网络连通性正常"
    else
        echo "✗ 网络连通性异常"
        return 1
    fi
}

# 检查包管理器
check_package_manager() {
    echo "检查包管理器..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v yum &> /dev/null; then
                echo "✓ 检测到 yum 包管理器"
            fi
            if command -v dnf &> /dev/null; then
                echo "✓ 检测到 dnf 包管理器"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v apt &> /dev/null; then
                echo "✓ 检测到 apt 包管理器"
            fi
            ;;
    esac
}

# 检查防火墙
check_firewall() {
    echo "检查防火墙..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v firewall-cmd &> /dev/null; then
                echo "✓ 检测到 firewall-cmd"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v ufw &> /dev/null; then
                echo "✓ 检测到 ufw"
            fi
            if command -v iptables &> /dev/null; then
                echo "✓ 检测到 iptables"
            fi
            ;;
    esac
}

# 检查安全策略
check_security_policy() {
    echo "检查安全策略..."
    
    case "$OS_NAME" in
        "rhel"|"centos"|"rocky"|"alma"|"fedora")
            if command -v sestatus &> /dev/null; then
                SELINUX_STATUS=$(sestatus | grep "SELinux status" | awk '{print $3}')
                echo "SELinux状态: $SELINUX_STATUS"
            fi
            ;;
        "ubuntu"|"debian")
            if command -v apparmor_status &> /dev/null; then
                echo "✓ 检测到 AppArmor"
            fi
            ;;
    esac
}

# 检查系统服务
check_systemd() {
    echo "检查系统服务..."
    
    if command -v systemctl &> /dev/null; then
        echo "✓ 检测到 systemd"
    else
        echo "✗ 未检测到 systemd"
        return 1
    fi
}

# 检查必要工具
check_required_tools() {
    echo "检查必要工具..."
    
    TOOLS=("wget" "curl" "git" "vim" "net-tools")
    MISSING_TOOLS=()
    
    for tool in "${TOOLS[@]}"; do
        if command -v "$tool" &> /dev/null; then
            echo "✓ $tool 已安装"
        else
            echo "⚠ $tool 未安装 (将在系统环境准备阶段安装)"
            MISSING_TOOLS+=("$tool")
        fi
    done
    
    if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
        echo "✓ 所有必要工具已安装"
    else
        echo "⚠ 缺少工具: ${MISSING_TOOLS[*]} (将在后续步骤中自动安装)"
    fi
    
    # 不将缺少工具作为错误，因为会在setup-system.sh中安装
    return 0
}

# 检查端口可用性
check_ports() {
    echo "检查端口可用性..."
    
    # 检查8123端口
    if netstat -tlnp | grep -q ":8123 "; then
        echo "⚠ 端口8123已被占用"
        return 1
    else
        echo "✓ 端口8123可用"
    fi
    
    # 检查9000端口
    if netstat -tlnp | grep -q ":9000 "; then
        echo "⚠ 端口9000已被占用"
        return 1
    else
        echo "✓ 端口9000可用"
    fi
}

# 生成测试报告
generate_report() {
    echo ""
    echo "=== 平台兼容性测试报告 ==="
    echo "操作系统: $OS_NAME $OS_VERSION"
    echo "系统架构: $(uname -m)"
    echo "CPU核心数: $(nproc)"
    
    # 重新计算内存和磁盘信息用于报告
    MEMORY_KB=$(free -k | awk 'NR==2{print $2}')
    MEMORY_GB_1024=$(echo "scale=1; $MEMORY_KB / 1024 / 1024" | bc -l)
    MEMORY_GB_1000=$(echo "scale=1; $MEMORY_KB / 1000 / 1000" | bc -l)
    echo "内存大小: ${MEMORY_KB}KB (约${MEMORY_GB_1000}GB 1000进制 / ${MEMORY_GB_1024}GB 1024进制)"
    
    DISK_BYTES=$(df -B1 / | awk 'NR==2{print $4}')
    DISK_GB_1024=$((DISK_BYTES / 1024 / 1024 / 1024))
    DISK_GB_1000=$((DISK_BYTES / 1000 / 1000 / 1000))
    echo "磁盘空间: ${DISK_BYTES}字节 (约${DISK_GB_1024}GB 1024进制 / ${DISK_GB_1000}GB 1000进制)"
    
    echo "测试时间: $(date)"
    echo ""
    
    if [ $TOTAL_ERRORS -eq 0 ]; then
        echo "✓ 平台兼容性测试通过"
        echo "✓ 系统支持 ClickHouse 部署"
    else
        echo "✗ 平台兼容性测试失败"
        echo "✗ 发现 $TOTAL_ERRORS 个问题"
        echo "请解决上述问题后重新测试"
    fi
}

# 主函数
main() {
    TOTAL_ERRORS=0
    
    # 执行各项检查
    if ! detect_os; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    if ! check_os_compatibility; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    if ! check_architecture; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    check_hardware
    
    if ! check_network; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    check_package_manager
    check_firewall
    check_security_policy
    
    if ! check_systemd; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    check_required_tools
    
    if ! check_ports; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    # 生成报告
    generate_report
    
    echo ""
    echo "=== 平台兼容性测试完成 ==="
    
    # 返回退出码
    if [ $TOTAL_ERRORS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# 执行主函数
main "$@" 