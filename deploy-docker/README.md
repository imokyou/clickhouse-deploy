# ClickHouse Docker 部署方案

## 概述

本项目提供了一套完整的ClickHouse Docker部署方案，支持多种Linux发行版，包括RHEL兼容发行版和Ubuntu LTS/Debian系统。

## 支持平台

### RHEL 兼容发行版

- CentOS 7.x, 8.x
- RHEL 7.x, 8.x, 9.x
- Rocky Linux 8.x, 9.x
- AlmaLinux 8.x, 9.x
- Fedora 35+

### Ubuntu LTS / Debian

- Ubuntu 20.04 LTS, 22.04 LTS
- Debian 10, 11

## 主要特性

### 多平台兼容性

- 自动检测操作系统类型
- 自动选择对应的包管理器
- 自动配置防火墙规则
- 支持多种防火墙类型（firewalld, ufw, iptables）

### 自动化部署

- 一键部署脚本
- 分步部署选项
- 自动环境检测
- 自动依赖安装

### 完整的运维工具

- 健康检查脚本
- 监控脚本
- 备份脚本
- 平台兼容性测试

## 快速开始

### 1. 下载项目

```bash
git clone <repository-url>
cd clickhouse/deploy-docker
```

### 2. 给脚本添加执行权限

```bash
chmod +x scripts/*.sh
```

### 3. 运行平台兼容性测试

```bash
./scripts/platform-test.sh
```

### 4. 一键部署

```bash
sudo ./scripts/auto-deploy.sh
```

## 部署方式

### 方式一：一键部署（推荐）

```bash
sudo ./scripts/auto-deploy.sh
```

### 方式二：分步部署

```bash
# 1. 安装Docker环境
sudo ./scripts/install-docker.sh

# 2. 设置项目目录
./scripts/setup-project.sh

# 3. 部署ClickHouse服务
./scripts/deploy.sh

# 4. 健康检查
./scripts/health-check.sh
```

## 脚本说明

| 脚本名称 | 功能 | 支持平台 |
|---------|------|----------|
| `auto-deploy.sh` | 一键完成所有部署步骤 | 全平台 |
| `install-docker.sh` | 自动检测平台并安装Docker | 全平台 |
| `setup-project.sh` | 设置项目目录和配置文件 | 全平台 |
| `deploy.sh` | 部署ClickHouse服务 | 全平台 |
| `health-check.sh` | 健康检查和验证 | 全平台 |
| `monitor.sh` | 监控服务状态和性能 | 全平台 |
| `backup.sh` | 数据备份和恢复 | 全平台 |
| `platform-test.sh` | 平台兼容性测试 | 全平台 |

## 平台特定功能

### 自动检测功能

- 操作系统类型检测
- 包管理器检测（apt, yum, dnf）
- 防火墙类型检测（firewalld, ufw, iptables）
- Docker环境检测

### 自动配置功能

- 根据平台自动安装Docker
- 根据防火墙类型配置端口开放
- 自动安装必要的依赖包
- 自动配置用户权限

## 配置文件

### Docker Compose配置

- `docker-compose.yml` - 主配置文件

### ClickHouse配置

- `clickhouse/config/config.d/config.xml` - 主配置文件
- `clickhouse/config/users.d/users.xml` - 用户配置文件

## 访问信息

部署完成后，可以通过以下方式访问ClickHouse：

- **HTTP接口**: http://localhost:8123
- **Native接口**: localhost:9000
- **默认用户**: default
- **默认密码**: clickhouse123

## 常用命令

```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f clickhouse

# 连接数据库
docker-compose exec clickhouse clickhouse-client

# 健康检查
./scripts/health-check.sh

# 监控服务
./scripts/monitor.sh

# 备份数据
./scripts/backup.sh
```

## 故障排查

### 常见问题

1. **Docker安装失败**
   - 检查网络连接
   - 确认系统版本支持
   - 查看错误日志

2. **端口被占用**
   - 检查端口占用: `netstat -tlnp | grep :8123`
   - 修改配置文件中的端口

3. **权限问题**
   - 确保用户已加入docker组
   - 重新登录或执行 `newgrp docker`

4. **防火墙问题**
   - 检查防火墙状态
   - 确认端口已开放

### 日志查看

```bash
# 查看ClickHouse日志
docker-compose logs -f clickhouse

# 查看系统日志
sudo journalctl -u docker

# 查看防火墙日志
sudo journalctl -u firewalld  # RHEL兼容系统
sudo journalctl -u ufw         # Ubuntu系统
```

## 性能优化

### 系统级优化

- 调整系统内存限制
- 配置交换分区
- 使用SSD存储
- 优化网络配置

### ClickHouse优化

- 根据系统内存调整配置
- 优化查询缓存
- 配置合适的分区策略
- 优化压缩设置

## 安全建议

1. **网络安全**
   - 配置防火墙规则
   - 使用VPN或专用网络

2. **访问控制**
   - 修改默认密码
   - 配置用户权限

3. **数据安全**
   - 定期备份数据
   - 加密敏感数据

## 监控和维护

### 监控指标

- CPU使用率
- 内存使用率
- 磁盘使用率
- 查询性能
- 连接数

### 维护任务

- 定期备份数据
- 日志轮转和清理
- 性能监控和调优

## 文档

- [部署指南](docs/部署指南.md) - 详细的部署说明
- [配置说明](docs/配置说明.md) - 配置文件详细说明
- [运维手册](docs/运维手册.md) - 运维操作指南

