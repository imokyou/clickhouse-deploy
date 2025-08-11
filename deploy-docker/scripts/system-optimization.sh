#!/bin/bash

# 系统级优化脚本
# 需要在宿主机上以 root 权限运行

set -e

echo "=== ClickHouse 系统级优化脚本 ==="
echo "警告: 此脚本需要 root 权限，请在宿主机上运行"
echo

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请以 root 用户运行此脚本"
    exit 1
fi

# 1. 优化时钟源
echo "1. 优化时钟源..."
CURRENT_CLOCKSOURCE=$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource)
echo "当前时钟源: $CURRENT_CLOCKSOURCE"

if [ "$CURRENT_CLOCKSOURCE" = "jiffies" ]; then
    echo "检测到使用 jiffies 时钟源，建议切换到 tsc"
    echo "请在 /etc/default/grub 中添加: GRUB_CMDLINE_LINUX_DEFAULT=\"clocksource=tsc\""
    echo "然后运行: update-grub && reboot"
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
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "已设置文件描述符限制为 65536"
echo

# 4. 优化内核参数
echo "4. 优化内核参数..."
cat >> /etc/sysctl.conf << 'SYSCTL_EOF'

# ClickHouse 优化参数
# 增加文件描述符限制
fs.file-max = 65536

# 优化网络参数
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 65535

# 优化内存参数
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# 优化 I/O 参数
vm.dirty_writeback_centisecs = 100
vm.dirty_expire_centisecs = 3000
SYSCTL_EOF

echo "已添加内核优化参数"
echo

# 5. 应用配置
echo "5. 应用配置..."
sysctl -p
echo "配置已应用"
echo

echo "=== 优化完成 ==="
echo "建议重启系统以确保所有配置生效"
echo "重启后运行: docker-compose restart clickhouse"
