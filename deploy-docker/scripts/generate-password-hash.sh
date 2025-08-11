#!/bin/bash

# ClickHouse 密码哈希生成脚本
# 用于生成SHA256哈希密码，提高安全性

echo "ClickHouse 密码哈希生成工具"
echo "================================"
echo ""

# 检查是否提供了密码参数
if [ $# -eq 0 ]; then
    echo "用法: $0 <密码>"
    echo "示例: $0 'Admin_2024_Secure!'"
    echo ""
    echo "或者交互式输入密码:"
    echo -n "请输入密码: "
    read -s PASSWORD
    echo ""
else
    PASSWORD="$1"
fi

if [ -z "$PASSWORD" ]; then
    echo "错误: 密码不能为空"
    exit 1
fi

echo "正在生成密码哈希..."
echo "密码: $PASSWORD"
echo ""

# 生成SHA256哈希
SHA256_HASH=$(echo -n "$PASSWORD" | sha256sum | cut -d' ' -f1)

echo "SHA256哈希:"
echo "$SHA256_HASH"
echo ""

echo "在users.xml中的配置示例:"
echo "<password_sha256_hex>$SHA256_HASH</password_sha256_hex>"
echo ""

echo "完成！请将上述哈希值复制到配置文件中。" 