#!/bin/bash

# ClickHouse 系统级优化脚本
# 适用于服务器直接部署方案

set -e

echo "=== ClickHouse 系统级优化脚本 ==="
echo "警告: 此脚本需要 root 权限，请在服务器上运行"
echo

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请以 root 用户运行此脚本"
    exit 1
fi

# 检测操作系统
detect_os() {
    if [ -f /etc/redhat-release ]; then
        echo "RHEL兼容系统"
        OS_TYPE="rhel"
    elif [ -f /etc/debian_version ]; then
        echo "Debian/Ubuntu系统"
        OS_TYPE="debian"
    else
        echo "未知操作系统"
        exit 1
    fi
}

echo "检测操作系统..."
detect_os
echo

# 1. 优化时钟源
echo "1. 优化时钟源..."
CURRENT_CLOCKSOURCE=$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null || echo "unknown")
echo "当前时钟源: $CURRENT_CLOCKSOURCE"

if [ "$CURRENT_CLOCKSOURCE" = "jiffies" ]; then
    echo "检测到使用 jiffies 时钟源，建议切换到 tsc"
    if [ "$OS_TYPE" = "rhel" ]; then
        echo "请在 /etc/default/grub 中添加: GRUB_CMDLINE_LINUX_DEFAULT=\"clocksource=tsc\""
        echo "然后运行: grub2-mkconfig -o /boot/grub2/grub.cfg && reboot"
    else
        echo "请在 /etc/default/grub 中添加: GRUB_CMDLINE_LINUX_DEFAULT=\"clocksource=tsc\""
        echo "然后运行: update-grub && reboot"
    fi
else
    echo "时钟源配置正常"
fi
echo

# 2. 启用延迟统计
echo "2. 启用延迟统计..."
echo "1" > /proc/sys/kernel/task_delayacct
echo "已临时启用延迟统计"

# 永久启用
if ! grep -q "kernel.task_delayacct = 1" /etc/sysctl.conf; then
    echo "kernel.task_delayacct = 1" >> /etc/sysctl.conf
    echo "已永久启用延迟统计"
fi
echo

# 3. 优化文件描述符限制
echo "3. 优化文件描述符限制..."
if ! grep -q "nofile 65536" /etc/security/limits.conf; then
    echo "* soft nofile 65536" >> /etc/security/limits.conf
    echo "* hard nofile 65536" >> /etc/security/limits.conf
    echo "已设置文件描述符限制为 65536"
else
    echo "文件描述符限制已配置"
fi
echo

# 4. 优化内核参数
echo "4. 优化内核参数..."
if ! grep -q "# ClickHouse 优化参数" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << 'SYSCTL_EOF'

# ClickHouse 优化参数
# 增加文件描述符限制
fs.file-max = 65536

# 优化网络参数
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000

# 优化内存参数
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# 优化 I/O 参数
vm.dirty_writeback_centisecs = 100
vm.dirty_expire_centisecs = 3000
SYSCTL_EOF

    echo "已添加内核优化参数"
else
    echo "内核优化参数已存在"
fi
echo

# 5. 优化磁盘I/O调度器
echo "5. 优化磁盘I/O调度器..."
for disk in /sys/block/sd*; do
    if [ -d "$disk" ]; then
        disk_name=$(basename "$disk")
        current_scheduler=$(cat "$disk/queue/scheduler" 2>/dev/null | grep -o '\[.*\]' | tr -d '[]' || echo "unknown")
        echo "磁盘 $disk_name 当前调度器: $current_scheduler"
        
        # 尝试设置为 deadline 或 mq-deadline
        if [ -w "$disk/queue/scheduler" ]; then
            if echo "deadline" > "$disk/queue/scheduler" 2>/dev/null; then
                echo "已设置 $disk_name 为 deadline 调度器"
            elif echo "mq-deadline" > "$disk/queue/scheduler" 2>/dev/null; then
                echo "已设置 $disk_name 为 mq-deadline 调度器"
            else
                echo "无法修改 $disk_name 的调度器"
            fi
        fi
    fi
done
echo

# 6. 优化ClickHouse专用目录
echo "6. 优化ClickHouse目录权限..."
CLICKHOUSE_USER="clickhouse"
CLICKHOUSE_GROUP="clickhouse"

# 创建ClickHouse用户（如果不存在）
if ! id "$CLICKHOUSE_USER" &>/dev/null; then
    useradd -r -s /bin/false -d /var/lib/clickhouse "$CLICKHOUSE_USER"
    echo "已创建ClickHouse用户"
fi

# 设置目录权限
CLICKHOUSE_DIRS=(
    "/var/lib/clickhouse"
    "/var/log/clickhouse-server"
    "/etc/clickhouse-server"
)

for dir in "${CLICKHOUSE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        chown -R "$CLICKHOUSE_USER:$CLICKHOUSE_GROUP" "$dir"
        chmod 755 "$dir"
        echo "已设置 $dir 权限"
    fi
done
echo

# 7. 配置透明大页
echo "7. 配置透明大页..."
if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
    echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
    echo "已临时禁用透明大页"
    
    # 永久禁用
    if [ "$OS_TYPE" = "rhel" ]; then
        if ! grep -q "transparent_hugepage=never" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=never /' /etc/default/grub
            echo "已永久禁用透明大页"
        fi
    else
        if ! grep -q "transparent_hugepage=never" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=never /' /etc/default/grub
            echo "已永久禁用透明大页"
        fi
    fi
else
    echo "透明大页配置不可用"
fi
echo

# 8. 应用配置
echo "8. 应用配置..."
sysctl -p
echo "配置已应用"
echo

# 9. 显示优化结果
echo "9. 优化结果检查..."
echo "文件描述符限制:"
ulimit -n
echo ""

echo "当前内核参数:"
sysctl fs.file-max net.core.somaxconn vm.swappiness
echo ""

echo "ClickHouse用户信息:"
id clickhouse 2>/dev/null || echo "ClickHouse用户不存在"
echo ""

echo "=== 优化完成 ==="
echo ""
echo "建议操作:"
echo "1. 重启系统以确保所有配置生效"
echo "2. 重启后运行: sudo systemctl restart clickhouse-server"
echo "3. 检查ClickHouse服务状态: sudo systemctl status clickhouse-server"
echo "4. 运行性能测试: ./scripts/health-check.sh"
echo ""
echo "注意: 某些配置需要重启系统才能完全生效" 