# ClickHouse 部署和运维脚本

本目录包含了 ClickHouse Server 的完整部署和运维脚本集合，支持 RHEL 兼容发行版和 Ubuntu/Debian 系统。

## 📋 脚本概览

### 🚀 部署脚本

| 脚本名称 | 功能描述 | 执行时间 | 权限要求 |
|---------|----------|----------|----------|
| `auto-deploy.sh` | 一键完成所有部署步骤 | 10-15分钟 | sudo |
| `setup-system.sh` | 系统环境准备和优化 | 3-5分钟 | sudo |
| `install-clickhouse.sh` | 安装 ClickHouse 服务 | 2-3分钟 | sudo |
| `setup-config.sh` | 配置优化和安全设置 | 2-3分钟 | sudo |
| `start-service.sh` | 启动 ClickHouse 服务 | 30秒 | sudo |
| `platform-test.sh` | 平台兼容性测试 | 1-2分钟 | sudo |

### 🔧 运维脚本

| 脚本名称 | 功能描述 | 执行频率 | 权限要求 |
|---------|----------|----------|----------|
| `health-check.sh` | 健康检查和验证 | 按需/定时 | 普通用户 |
| `monitor.sh` | 实时监控服务状态 | 持续运行 | 普通用户 |
| `backup.sh` | 数据备份脚本 | 每日/每周 | sudo |
| `test-users.sh` | 用户配置测试 | 按需 | 普通用户 |
| `system-optimization.sh` | 系统性能优化 | 一次性 | sudo |
| `generate-password-hash.sh` | 密码哈希生成 | 按需 | 普通用户 |

## 🚀 快速开始

### 一键部署

```bash
# 克隆项目并进入目录
cd deploy-server/scripts

# 一键部署（需要 sudo 权限）
sudo ./auto-deploy.sh
```

### 分步部署

```bash
# 1. 平台兼容性测试
sudo ./platform-test.sh

# 2. 系统环境准备
sudo ./setup-system.sh

# 3. 安装 ClickHouse
sudo ./install-clickhouse.sh

# 4. 配置 ClickHouse
sudo ./setup-config.sh

# 5. 启动服务
sudo ./start-service.sh

# 6. 健康检查
./health-check.sh
```

## 📖 脚本详细说明

### 部署脚本

#### `auto-deploy.sh` - 一键部署脚本
自动完成从环境检测到服务部署的全过程。

**功能特性：**
- 自动检测操作系统类型
- 平台兼容性验证
- 系统环境准备
- ClickHouse 安装和配置
- 服务启动和验证

**使用方法：**
```bash
sudo ./auto-deploy.sh
```

#### `setup-system.sh` - 系统环境准备
准备 ClickHouse 运行所需的系统环境。

**功能特性：**
- 更新系统包
- 安装必要依赖
- 配置防火墙规则
- 系统参数优化
- 创建专用用户和目录

**使用方法：**
```bash
sudo ./setup-system.sh
```

#### `install-clickhouse.sh` - ClickHouse 安装
安装 ClickHouse Server 和 Client。

**功能特性：**
- 添加官方仓库
- 安装服务包
- 验证安装完整性
- 配置 systemd 服务

**使用方法：**
```bash
sudo ./install-clickhouse.sh
```

#### `setup-config.sh` - 配置设置
配置 ClickHouse 服务参数和安全设置。

**功能特性：**
- 配置主配置文件
- 设置用户和权限
- 配置日志路径
- 设置数据目录
- 安全策略配置

**使用方法：**
```bash
sudo ./setup-config.sh
```

#### `start-service.sh` - 服务启动
启动 ClickHouse 服务并进行基础验证。

**功能特性：**
- 启动 ClickHouse 服务
- 检查服务状态
- 验证端口监听
- 基础连接测试

**使用方法：**
```bash
sudo ./start-service.sh
```

#### `platform-test.sh` - 平台兼容性测试
测试当前平台是否支持 ClickHouse 部署。

**功能特性：**
- 操作系统兼容性检查
- 硬件配置验证
- 网络连通性测试
- 依赖包检查

**使用方法：**
```bash
sudo ./platform-test.sh
```

### 运维脚本

#### `health-check.sh` - 健康检查
全面的 ClickHouse 服务健康状态检查。

**功能特性：**
- 服务状态检查
- 端口监听验证
- 内存使用监控
- 连接数检查
- 查询性能测试
- 磁盘空间检查

**使用方法：**
```bash
# 使用默认配置
./health-check.sh

# 使用自定义配置文件
./health-check.sh -c health-check.conf
```

**配置文件示例：**
```bash
# health-check.conf
ALERT_EMAIL="admin@example.com"
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_CONNECTIONS=100
ALERT_THRESHOLD_DISK=80
ALERT_THRESHOLD_SLOW_QUERIES=10
```

#### `monitor.sh` - 监控脚本
实时监控 ClickHouse 服务状态和性能指标。

**功能特性：**
- 持续监控服务状态
- 性能指标收集
- 告警阈值检测
- 日志记录
- 邮件告警（可选）

**使用方法：**
```bash
# 启动监控（前台运行）
./monitor.sh

# 后台运行监控
nohup ./monitor.sh > /dev/null 2>&1 &

# 使用自定义配置
./monitor.sh -c monitor.conf
```

**配置文件示例：**
```bash
# monitor.conf
MONITOR_INTERVAL=30
ALERT_EMAIL="admin@example.com"
ALERT_THRESHOLD_MEMORY=80
ALERT_THRESHOLD_CONNECTIONS=100
ALERT_THRESHOLD_DISK=80
ALERT_THRESHOLD_SLOW_QUERIES=10
ALERT_THRESHOLD_CPU=90
```

#### `backup.sh` - 备份脚本
ClickHouse 数据备份和恢复。

**功能特性：**
- 完整备份
- 增量备份
- 配置备份
- 自动清理旧备份
- 备份验证

**使用方法：**
```bash
# 完整备份
sudo ./backup.sh full

# 增量备份
sudo ./backup.sh incremental

# 配置备份
sudo ./backup.sh config

# 查看备份日志
tail -f /opt/clickhouse/logs/backup_$(date +%Y%m%d_%H%M%S).log
```

#### `test-users.sh` - 用户配置测试
测试 ClickHouse 用户配置和权限。

**功能特性：**
- 用户连接测试
- 权限验证
- 数据库操作测试
- 网络访问测试

**使用方法：**
```bash
./test-users.sh
```

#### `system-optimization.sh` - 系统优化
系统级性能优化配置。

**功能特性：**
- 内核参数调优
- 文件系统优化
- 网络参数优化
- 内存管理优化

**使用方法：**
```bash
sudo ./system-optimization.sh
```

#### `generate-password-hash.sh` - 密码哈希生成
生成安全的密码哈希值。

**功能特性：**
- SHA256 哈希生成
- 多种配置格式输出
- 交互式密码输入
- 安全建议

**使用方法：**
```bash
# 命令行参数
./generate-password-hash.sh "your_password"

# 交互式输入
./generate-password-hash.sh
```

## 🔧 配置说明

### 配置文件位置

| 配置文件 | 路径 | 说明 |
|---------|------|------|
| `health-check.conf` | `./health-check.conf` | 健康检查配置 |
| `monitor.conf` | `./monitor.conf` | 监控脚本配置 |

### 默认用户配置

| 用户名 | 密码 | 权限 | 用途 |
|--------|------|------|------|
| `admin` | `Admin_2024_Secure!` | 管理员 | 系统管理 |
| `webuser` | `WebUser_2024_Secure!` | 读写 | Web 应用 |
| `default` | `clickhouse123` | 基础 | 默认用户 |

## 📊 监控指标

### 系统指标
- CPU 使用率
- 内存使用率
- 磁盘使用率
- 网络连接数

### ClickHouse 指标
- 查询执行时间
- 内存使用情况
- 连接数统计
- 慢查询数量

### 告警阈值
- 内存使用率 > 80%
- 连接数 > 100
- 磁盘使用率 > 80%
- 慢查询 > 10 个/分钟
- CPU 使用率 > 90%

## 🛠️ 故障排查

### 常见问题

#### 服务启动失败
```bash
# 检查服务状态
systemctl status clickhouse-server

# 查看错误日志
journalctl -u clickhouse-server -f

# 检查配置文件
sudo clickhouse-server --config-file=/etc/clickhouse-server/config.xml --test-config
```

#### 连接失败
```bash
# 检查端口监听
netstat -tlnp | grep clickhouse

# 测试连接
curl -s http://localhost:8123/ping

# 检查防火墙
sudo firewall-cmd --list-all  # RHEL
sudo ufw status               # Ubuntu
```

#### 性能问题
```sql
-- 查看系统指标
SELECT metric, value FROM system.metrics ORDER BY value DESC;

-- 查看慢查询
SELECT query, query_duration_ms FROM system.query_log 
WHERE query_duration_ms > 1000 ORDER BY query_duration_ms DESC;

-- 查看内存使用
SELECT metric, value FROM system.metrics 
WHERE metric LIKE '%memory%' ORDER BY value DESC;
```

### 日志文件

| 日志类型 | 路径 | 说明 |
|---------|------|------|
| 服务日志 | `/var/log/clickhouse-server/` | ClickHouse 服务日志 |
| 健康检查 | `/opt/clickhouse/logs/health-check.log` | 健康检查日志 |
| 监控日志 | `/opt/clickhouse/logs/monitor_*.log` | 监控脚本日志 |
| 备份日志 | `/opt/clickhouse/logs/backup_*.log` | 备份操作日志 |

## 🔒 安全建议

### 密码安全
- 使用强密码（大小写字母、数字、特殊字符）
- 定期更换密码
- 不同用户使用不同密码
- 使用密码哈希而非明文

### 网络安全
- 配置防火墙规则
- 限制网络访问范围
- 使用 SSL/TLS 加密
- 定期更新系统

### 权限管理
- 最小权限原则
- 定期审查用户权限
- 禁用不必要的用户
- 启用审计日志

## 📞 支持

### 系统要求
- **操作系统**: RHEL 7+/CentOS 7+/Rocky Linux 8+/Ubuntu 20.04+/Debian 11+
- **内存**: 最少 4GB，推荐 16GB+
- **磁盘**: 最少 50GB，推荐 150GB+ NVMe SSD
- **网络**: 1Gbps 带宽

### 获取帮助
1. 查看脚本帮助信息：`./script_name.sh --help`
2. 检查日志文件获取详细错误信息
3. 运行健康检查脚本诊断问题
4. 参考主 README.md 文档

### 贡献
欢迎提交 Issue 和 Pull Request 来改进这些脚本。

---

**注意**: 所有脚本都经过测试，但在生产环境使用前请先在测试环境验证。 