# ClickHouse Docker 部署脚本集

本目录包含了用于 ClickHouse Docker 环境部署、管理和监控的完整脚本集合。所有脚本都兼容 RHEL 兼容发行版和 Ubuntu LTS / Debian 系统。

## 📋 脚本概览

### 🚀 部署相关脚本

| 脚本名称 | 功能描述 | 权限要求 | 依赖 |
|---------|---------|---------|------|
| `auto-deploy.sh` | 一键自动部署脚本 | root | 无 |
| `install-docker.sh` | Docker 环境安装脚本 | root | 无 |
| `setup-project.sh` | 项目目录和配置文件设置 | root | Docker |
| `deploy.sh` | ClickHouse 服务部署脚本 | 普通用户 | Docker, Docker Compose |

### 🔧 管理和维护脚本

| 脚本名称 | 功能描述 | 权限要求 | 依赖 |
|---------|---------|---------|------|
| `health-check.sh` | 服务健康检查脚本 | 普通用户 | Docker Compose |
| `monitor.sh` | 实时监控脚本 | 普通用户 | Docker Compose |
| `backup.sh` | 数据备份脚本 | 普通用户 | Docker Compose |
| `system-optimization.sh` | 系统级优化脚本 | root | 无 |

### 🧪 测试和验证脚本

| 脚本名称 | 功能描述 | 权限要求 | 依赖 |
|---------|---------|---------|------|
| `platform-test.sh` | 平台兼容性测试 | 普通用户 | Docker |
| `test-users.sh` | 用户配置测试 | 普通用户 | Docker Compose |
| `test-docker-compose.sh` | Docker Compose 命令测试 | 普通用户 | Docker |

### 🔐 安全相关脚本

| 脚本名称 | 功能描述 | 权限要求 | 依赖 |
|---------|---------|---------|------|
| `generate-password-hash.sh` | 密码哈希生成工具 | 普通用户 | 无 |

## 🚀 快速开始

### 一键部署（推荐）

```bash
# 以 root 权限运行一键部署脚本
sudo ./scripts/auto-deploy.sh
```

此脚本将自动完成：
1. Docker 环境安装
2. 项目目录设置
3. ClickHouse 服务部署
4. 健康检查

### 分步部署

如果您希望分步执行，可以按以下顺序运行：

```bash
# 1. 安装 Docker 环境
sudo ./scripts/install-docker.sh

# 2. 设置项目目录
sudo ./scripts/setup-project.sh

# 3. 部署服务
./scripts/deploy.sh

# 4. 健康检查
./scripts/health-check.sh
```

## 📖 详细使用说明

### 1. 环境安装脚本

#### `install-docker.sh`
安装 Docker 和 Docker Compose 环境。

**功能特性：**
- 自动检测操作系统类型
- 安装基础网络工具（netstat, ip, ping, telnet）
- 配置 Docker 镜像加速
- 验证安装结果

**使用方法：**
```bash
sudo ./scripts/install-docker.sh
```

### 2. 项目设置脚本

#### `setup-project.sh`
创建项目目录结构和配置文件。

**功能特性：**
- 创建标准目录结构
- 配置防火墙规则
- 安装 XML 工具用于配置验证
- 验证配置文件语法

**使用方法：**
```bash
sudo ./scripts/setup-project.sh
```

### 3. 服务部署脚本

#### `deploy.sh`
部署和启动 ClickHouse 服务。

**功能特性：**
- 检查 Docker 环境
- 拉取最新镜像
- 启动服务
- 创建测试数据
- 验证部署结果

**使用方法：**
```bash
./scripts/deploy.sh
```

### 4. 健康检查脚本

#### `health-check.sh`
全面的服务健康检查。

**功能特性：**
- 检查服务状态
- 验证数据库连接
- 测试用户权限
- 生成健康报告

**使用方法：**
```bash
./scripts/health-check.sh
```

**配置文件：**
可以创建 `health-check.conf` 文件来自定义检查参数。

### 5. 监控脚本

#### `monitor.sh`
实时监控 ClickHouse 服务状态和性能。

**功能特性：**
- 实时性能指标监控
- 内存和连接数监控
- 慢查询检测
- 告警功能

**使用方法：**
```bash
./scripts/monitor.sh
```

**配置文件：**
复制 `monitor.conf.example` 为 `monitor.conf` 并修改配置：

```bash
cp monitor.conf.example monitor.conf
# 编辑 monitor.conf 文件
```

### 6. 备份脚本

#### `backup.sh`
数据备份和恢复管理。

**功能特性：**
- 全量数据库备份
- 配置文件备份
- 备份信息记录
- 自动清理旧备份

**使用方法：**
```bash
./scripts/backup.sh
```

### 7. 系统优化脚本

#### `system-optimization.sh`
系统级性能优化配置。

**功能特性：**
- 时钟源优化
- 文件描述符限制优化
- 内核参数优化
- 网络参数优化

**使用方法：**
```bash
sudo ./scripts/system-optimization.sh
```

**注意：** 此脚本需要重启系统才能完全生效。

### 8. 测试脚本

#### `platform-test.sh`
平台兼容性和环境测试。

**功能特性：**
- 系统环境检测
- Docker 环境测试
- ClickHouse 功能测试
- 性能基准测试

**使用方法：**
```bash
./scripts/platform-test.sh
```

#### `test-users.sh`
用户配置和权限测试。

**功能特性：**
- 测试用户连接
- 验证用户权限
- 显示权限信息

**使用方法：**
```bash
./scripts/test-users.sh
```

#### `test-docker-compose.sh`
Docker Compose 命令检测测试。

**功能特性：**
- 检测 Docker Compose 版本
- 验证命令可用性
- 显示版本信息

**使用方法：**
```bash
./scripts/test-docker-compose.sh
```

### 9. 安全工具

#### `generate-password-hash.sh`
生成 ClickHouse 用户密码的 SHA256 哈希。

**功能特性：**
- 生成安全的密码哈希
- 支持命令行参数和交互式输入
- 提供配置示例

**使用方法：**
```bash
# 命令行参数方式
./scripts/generate-password-hash.sh "your_password"

# 交互式输入方式
./scripts/generate-password-hash.sh
```

## ⚙️ 配置文件

### monitor.conf
监控脚本的配置文件，包含以下参数：

```bash
# 日志配置
LOG_FILE="/tmp/clickhouse-monitor.log"

# 告警配置
ALERT_EMAIL="admin@example.com"

# Docker Compose配置
DOCKER_COMPOSE_FILE="docker-compose.yml"

# 监控间隔（秒）
MONITOR_INTERVAL=30

# 数据库连接配置
DEFAULT_USER="default"
DEFAULT_PASSWORD="clickhouse123"

# 告警阈值
ALERT_THRESHOLD_MEMORY=80      # 内存使用率阈值(%)
ALERT_THRESHOLD_CONNECTIONS=100 # 连接数阈值
ALERT_THRESHOLD_DISK=80        # 磁盘使用率阈值(%)
ALERT_THRESHOLD_SLOW_QUERIES=10 # 慢查询阈值
```

## 🔧 故障排除

### 常见问题

1. **Docker 未安装**
   ```bash
   sudo ./scripts/install-docker.sh
   ```

2. **权限问题**
   ```bash
   # 确保用户有 Docker 权限
   sudo usermod -aG docker $USER
   # 重新登录或运行
   newgrp docker
   ```

3. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :8123
   netstat -tlnp | grep :9000
   ```

4. **服务启动失败**
   ```bash
   # 查看服务日志
   docker-compose logs clickhouse
   
   # 重新部署
   ./scripts/deploy.sh
   ```

### 日志文件

- 健康检查日志：`/tmp/clickhouse-health-check.log`
- 监控日志：`/tmp/clickhouse-monitor.log`
- Docker 日志：`docker-compose logs clickhouse`

## 📊 性能监控

### 关键指标

- **内存使用率**：监控 ClickHouse 内存使用情况
- **连接数**：跟踪活跃连接数量
- **查询性能**：监控慢查询和查询统计
- **磁盘使用率**：监控数据目录空间使用

### 监控命令

```bash
# 启动监控
./scripts/monitor.sh

# 查看实时状态
docker-compose exec clickhouse clickhouse-client --query "
SELECT 
    metric,
    value
FROM system.metrics
WHERE metric IN ('MemoryUsage', 'TCPConnection', 'Query')
"
```

## 🔒 安全建议

1. **修改默认密码**
   ```bash
   # 生成新密码哈希
   ./scripts/generate-password-hash.sh "new_secure_password"
   ```

2. **配置防火墙**
   ```bash
   # 只开放必要端口
   sudo ufw allow 8123/tcp
   sudo ufw allow 9000/tcp
   ```

3. **定期备份**
   ```bash
   # 设置定时备份
   crontab -e
   # 添加：0 2 * * * /path/to/scripts/backup.sh
   ```

## 📞 支持

如果您在使用过程中遇到问题，请：

1. 查看相关日志文件
2. 运行 `./scripts/platform-test.sh` 进行环境检查
3. 运行 `./scripts/health-check.sh` 进行健康检查
4. 检查 Docker 和 ClickHouse 官方文档

## 📝 更新日志

- **v1.0**：初始版本，包含基础部署和管理脚本
- **v1.1**：添加监控和备份功能
- **v1.2**：增强错误处理和日志记录
- **v1.3**：添加系统优化和性能测试功能

---

**注意：** 所有脚本都经过测试，支持主流 Linux 发行版。在生产环境使用前，建议在测试环境中充分验证。 