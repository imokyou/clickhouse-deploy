#!/bin/bash

# ClickHouse 一键部署脚本
# 自动完成从环境安装到服务部署的全过程

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
        -h|--help)
            echo "用法: $0 [-env ENV]"
            echo ""
            echo "参数:"
            echo "  -env, --environment ENV    指定部署环境 (dev|test|prod)，默认为 dev"
            echo "  -h, --help                显示帮助信息"
            echo ""
            echo "示例:"
            echo "  $0 -env dev     # 部署到开发环境"
            echo "  $0 -env test    # 部署到测试环境"
            echo "  $0 -env prod    # 部署到生产环境"
            exit 0
            ;;
        *)
            echo "未知参数: $1"
            echo "使用 -h 或 --help 查看帮助信息"
            exit 1
            ;;
    esac
done

# 验证环境参数
if [[ ! "$ENV" =~ ^(dev|test|prod)$ ]]; then
    echo "错误: 环境参数必须是 dev, test 或 prod"
    exit 1
fi

echo "=== ClickHouse 一键部署脚本 ==="
echo "部署环境: $ENV"
echo "此脚本将自动完成以下步骤："
echo "1. 安装Docker环境"
echo "2. 设置项目目录"
echo "3. 部署ClickHouse服务"
echo "4. 健康检查"
echo ""

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 根据环境设置部署目录
DEPLOY_DIR="/opt/clickhouse-deploy-${ENV}"

echo "部署目录: $DEPLOY_DIR"
echo ""

# 步骤1: 安装Docker环境
echo "=== 步骤1: 安装Docker环境 ==="
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，开始安装..."
    $SCRIPT_DIR/install-docker.sh
else
    echo "Docker已安装，跳过安装步骤"
fi

# 步骤2: 设置项目
echo ""
echo "=== 步骤2: 设置项目 ==="
# 将环境参数传递给 setup-project.sh
if [ -f "$SCRIPT_DIR/setup-project.sh" ]; then
    $SCRIPT_DIR/setup-project.sh -env $ENV
else
    # 如果 setup-project.sh 不支持 -env 参数，使用传统方式
    $SCRIPT_DIR/setup-project.sh
fi

# 切换到部署目录
cd $DEPLOY_DIR

# 步骤3: 部署服务
echo ""
echo "=== 步骤3: 部署ClickHouse服务 ==="
$SCRIPT_DIR/deploy.sh

# 步骤4: 健康检查
echo ""
echo "=== 步骤4: 健康检查 ==="
$SCRIPT_DIR/health-check.sh

# 确定Docker Compose命令
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    COMPOSE_CMD="docker compose"
else
    COMPOSE_CMD="docker-compose"
fi

echo ""
echo "=== 一键部署完成 ==="
echo "ClickHouse服务已成功部署并运行"
echo "部署环境: $ENV"
echo "部署目录: $DEPLOY_DIR"
echo ""
echo "访问信息:"
echo "  HTTP接口: http://localhost:8123"
echo "  Native接口: localhost:9000"
echo "  默认用户: default"
echo "  默认密码: clickhouse123"
echo ""
echo "常用命令:"
echo "  查看服务状态: $COMPOSE_CMD ps"
echo "  查看日志: $COMPOSE_CMD logs -f clickhouse"
echo "  连接数据库: $COMPOSE_CMD exec clickhouse clickhouse-client"
echo "  健康检查: cd $DEPLOY_DIR && ./scripts/health-check.sh"
echo "  备份数据: cd $DEPLOY_DIR && ./scripts/backup.sh"
echo "  监控服务: cd $DEPLOY_DIR && ./scripts/monitor.sh" 