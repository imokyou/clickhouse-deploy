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
echo "1. 收集配置信息"
echo "2. 安装Docker环境"
echo "3. 设置项目目录"
echo "4. 部署ClickHouse服务"
echo "5. 健康检查"
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

# 步骤1: 收集配置信息
echo "=== 步骤1: 收集配置信息 ==="
echo ""

# 设置服务名称和容器名称（仅用于生成配置，不导出到环境变量）
CLICKHOUSE_SERVICE_NAME="clickhouse-server-${ENV}"
CLICKHOUSE_CONTAINER_NAME="clickhouse-server-${ENV}"
echo "服务名称: $CLICKHOUSE_SERVICE_NAME"
echo "容器名称: $CLICKHOUSE_CONTAINER_NAME"
echo ""

# 交互式输入端口配置
echo "配置端口映射 (留空使用默认值):"
read -p "HTTP端口 (默认: 8123): " HTTP_PORT
HTTP_PORT=${HTTP_PORT:-8123}
CLICKHOUSE_HTTP_PORT=$HTTP_PORT

read -p "Native端口 (默认: 9000): " NATIVE_PORT
NATIVE_PORT=${NATIVE_PORT:-9000}
CLICKHOUSE_NATIVE_PORT=$NATIVE_PORT

echo ""
echo "端口配置:"
echo "  HTTP端口: $CLICKHOUSE_HTTP_PORT"
echo "  Native端口: $CLICKHOUSE_NATIVE_PORT"
echo ""

# 交互式输入密码配置
echo "配置用户密码 (留空使用默认值):"
echo "注意: 密码应包含大小写字母、数字和特殊字符，建议长度至少12位"
echo ""

read -p "admin 用户密码 (默认: xnJ8_M2zd7R!uQXaVgQDbTYn): " -s ADMIN_PASSWORD
echo ""
ADMIN_PASSWORD=${ADMIN_PASSWORD:-xnJ8_M2zd7R!uQXaVgQDbTYn}

read -p "webuser 用户密码 (默认: w2E8_B43wzP!gS53c56Lz0g6): " -s WEBUSER_PASSWORD
echo ""
WEBUSER_PASSWORD=${WEBUSER_PASSWORD:-w2E8_B43wzP!gS53c56Lz0g6}

read -p "demouser 用户密码 (默认: l0K3_L12g5F!pX83c45Jz1h7): " -s DEMOUSER_PASSWORD
echo ""
DEMOUSER_PASSWORD=${DEMOUSER_PASSWORD:-l0K3_L12g5F!pX83c45Jz1h7}

echo ""
echo "密码配置已完成"
echo ""

# 保存配置到环境文件（包含密码）
ENV_FILE="$DEPLOY_DIR/.env"
cat > /tmp/clickhouse-deploy.env << EOF
# ClickHouse 部署配置 - 环境: $ENV
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# 服务配置
CLICKHOUSE_SERVICE_NAME=$CLICKHOUSE_SERVICE_NAME
CLICKHOUSE_CONTAINER_NAME=$CLICKHOUSE_CONTAINER_NAME

# 端口配置
CLICKHOUSE_HTTP_PORT=$CLICKHOUSE_HTTP_PORT
CLICKHOUSE_NATIVE_PORT=$CLICKHOUSE_NATIVE_PORT

# 用户密码配置
ADMIN_PASSWORD=$ADMIN_PASSWORD
WEBUSER_PASSWORD=$WEBUSER_PASSWORD
DEMOUSER_PASSWORD=$DEMOUSER_PASSWORD
EOF

echo "配置信息已准备"
echo "配置已保存到 .env 文件，密码将同步到 users.xml"
echo ""

# 步骤2: 安装Docker环境
echo "=== 步骤2: 安装Docker环境 ==="
if ! command -v docker &> /dev/null; then
    echo "Docker未安装，开始安装..."
    $SCRIPT_DIR/install-docker.sh
else
    echo "Docker已安装，跳过安装步骤"
fi

# 步骤3: 设置项目
echo ""
echo "=== 步骤3: 设置项目 ==="
# 将环境参数传递给 setup-project.sh
if [ -f "$SCRIPT_DIR/setup-project.sh" ]; then
    $SCRIPT_DIR/setup-project.sh -env $ENV
else
    # 如果 setup-project.sh 不支持 -env 参数，使用传统方式
    $SCRIPT_DIR/setup-project.sh
fi

# 切换到部署目录
cd $DEPLOY_DIR

# 移动环境配置文件到部署目录
mv /tmp/clickhouse-deploy.env .env

# 更新 users.xml 配置文件中的密码
echo "从 .env 文件同步密码到 users.xml..."
sed -i.bak "s|<password>xnJ8_M2zd7R!uQXaVgQDbTYn</password>|<password><![CDATA[$ADMIN_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml
sed -i.bak "s|<password>w2E8_B43wzP!gS53c56Lz0g6</password>|<password><![CDATA[$WEBUSER_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml
sed -i.bak "s|<password>l0K3_L12g5F!pX83c45Jz1h7</password>|<password><![CDATA[$DEMOUSER_PASSWORD]]></password>|g" clickhouse/config/users.d/users.xml
rm -f clickhouse/config/users.d/users.xml.bak
echo "密码已从 .env 同步到 users.xml 文件"

# 步骤4: 部署服务
echo ""
echo "=== 步骤4: 部署ClickHouse服务 ==="
# docker-compose 会自动读取当前目录的 .env 文件，不需要手动加载
$SCRIPT_DIR/deploy.sh

# 步骤5: 健康检查
echo ""
echo "=== 步骤5: 健康检查 ==="
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
echo "  HTTP接口: http://localhost:$CLICKHOUSE_HTTP_PORT"
echo "  Native接口: localhost:$CLICKHOUSE_NATIVE_PORT"
echo "  默认用户: default"
echo "  默认密码: clickhouse123"
echo "  管理员用户: admin"
echo "  Web用户: webuser"
echo ""
echo "常用命令:"
echo "  查看服务状态: $COMPOSE_CMD ps"
echo "  查看日志: $COMPOSE_CMD logs -f $CLICKHOUSE_SERVICE_NAME"
echo "  连接数据库: $COMPOSE_CMD exec $CLICKHOUSE_SERVICE_NAME clickhouse-client"
echo "  健康检查: cd $DEPLOY_DIR && ./scripts/health-check.sh"
echo "  备份数据: cd $DEPLOY_DIR && ./scripts/backup.sh"
echo "  监控服务: cd $DEPLOY_DIR && ./scripts/monitor.sh"
echo ""
echo "配置文件已保存到: $DEPLOY_DIR/.env" 