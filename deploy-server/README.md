# ClickHouse Server 部署方案

## 概述

本项目提供了ClickHouse传统服务器部署的完整解决方案，包括自动化部署脚本、配置文件、监控工具和详细文档。支持 RHEL 兼容发行版和 Ubuntu LTS / Debian 两个主要平台。

## 🏗️ 部署架构

### 单片单节点架构

```json
┌─────────────────┐
│   Application   │
│   (应用层)      │
└─────────┬───────┘
          │
┌─────────▼───────┐
│  Load Balancer  │
│   (负载均衡)    │
└─────────┬───────┘
          │
┌─────────▼───────┐
│  ClickHouse     │
│  (单节点)       │
└─────────────────┘
```

## 📋 系统要求

### 硬件要求

- **CPU**: 4核 (推荐8核)
- **内存**: 16GB (推荐32GB)
- **存储**: 150GB NVMe SSD (推荐300GB)
- **网络**: 1Gbps带宽

### 软件要求

#### 支持的操作系统

**RHEL 兼容发行版:**
- RHEL 7.x/8.x/9.x
- CentOS 7.x/8.x
- Rocky Linux 8.x/9.x
- AlmaLinux 8.x/9.x
- Fedora 35+

**Ubuntu/Debian:**
- Ubuntu 20.04 LTS+
- Ubuntu 22.04 LTS+
- Debian 11+
- Debian 12+

#### ClickHouse版本
- ClickHouse 23.8 或更高版本

## 🚀 快速部署

### 一键部署（推荐）

```bash
# 1. 下载项目文件
git clone <repository-url>
cd clickhouse/deploy-server

# 2. 给脚本添加执行权限（Linux环境）
chmod +x scripts/*.sh

# 3. 执行一键部署
sudo ./scripts/auto-deploy.sh
```

### 分步部署

```bash
# 1. 系统环境准备
sudo ./scripts/setup-system.sh

# 2. 安装ClickHouse
sudo ./scripts/install-clickhouse.sh

# 3. 配置ClickHouse
sudo ./scripts/setup-config.sh

# 4. 启动服务
sudo ./scripts/start-service.sh

# 5. 健康检查
./scripts/health-check.sh
```

## 📁 项目结构

```
deploy-server/
├── README.md                    # 项目说明
├── 部署大纲.md                  # 部署方案大纲
├── clickhouse/                  # ClickHouse配置
│   ├── config/                  # 配置文件
│   │   ├── config.yml          # 主配置文件
│   │   ├── users.yml           # 用户配置
│   │   ├── performance.yml     # 性能优化配置
│   │   ├── security.yml        # 安全配置
│   │   ├── macros.yml          # 宏定义
│   │   └── json-optimization.yml # JSON优化配置
│   ├── data/                   # 数据目录
│   └── logs/                   # 日志目录
├── scripts/                     # 部署脚本
│   ├── auto-deploy.sh          # 一键部署脚本
│   ├── setup-system.sh         # 系统环境准备
│   ├── install-clickhouse.sh   # ClickHouse安装
│   ├── setup-config.sh         # 配置脚本
│   ├── start-service.sh        # 服务启动
│   ├── health-check.sh         # 健康检查
│   ├── backup.sh               # 备份脚本
│   └── monitor.sh              # 监控脚本
└── docs/                       # 文档目录
    ├── CentOS部署手册.md       # CentOS部署手册
    ├── 运维手册.md             # 运维手册
    └── 配置说明.md             # 配置说明
```

## 🔧 平台特性

### RHEL 兼容发行版特性
- 支持 `yum` 和 `dnf` 包管理器
- 自动配置 `firewall-cmd` 防火墙
- 支持 SELinux 安全策略
- 兼容 systemd 服务管理

### Ubuntu/Debian 特性
- 支持 `apt` 包管理器
- 自动配置 `ufw` 或 `iptables` 防火墙
- 支持 AppArmor 安全策略
- 兼容 systemd 服务管理

## 📊 部署脚本说明

| 脚本名称 | 功能 | 执行时间 | 平台支持 |
|---------|------|----------|----------|
| `auto-deploy.sh` | 一键完成所有部署步骤 | 10-15分钟 | 全平台 |
| `setup-system.sh` | 系统环境准备和优化 | 3-5分钟 | 全平台 |
| `install-clickhouse.sh` | 安装ClickHouse服务 | 2-3分钟 | 全平台 |
| `setup-config.sh` | 配置优化和安全设置 | 2-3分钟 | 全平台 |
| `start-service.sh` | 启动ClickHouse服务 | 30秒 | 全平台 |
| `health-check.sh` | 健康检查和验证 | 30秒 | 全平台 |
| `backup.sh` | 数据备份脚本 | 根据数据量 | 全平台 |
| `monitor.sh` | 监控服务脚本 | 持续运行 | 全平台 |

## 🔍 操作系统检测

脚本会自动检测以下操作系统：

### RHEL 兼容发行版
- 通过 `/etc/redhat-release` 或 `/etc/os-release` 检测
- 支持 RHEL、CentOS、Rocky Linux、AlmaLinux、Fedora

### Ubuntu/Debian
- 通过 `/etc/os-release` 或 `/etc/debian_version` 检测
- 支持 Ubuntu LTS、Debian 稳定版

## 🛠️ 故障排查

### 常见问题

1. **操作系统不支持**
   ```bash
   # 检查操作系统版本
   cat /etc/os-release
   ```

2. **包管理器错误**
   ```bash
   # RHEL 兼容发行版
   sudo yum clean all && sudo yum update
   
   # Ubuntu/Debian
   sudo apt update && sudo apt upgrade
   ```

3. **防火墙配置**
   ```bash
   # 检查防火墙状态
   sudo firewall-cmd --list-all  # RHEL
   sudo ufw status               # Ubuntu
   ```

4. **服务启动失败**
   ```bash
   # 查看服务状态
   sudo systemctl status clickhouse-server
   
   # 查看详细日志
   sudo journalctl -u clickhouse-server -f
   ```

## 📞 技术支持

- **文档**: 查看 `docs/` 目录下的详细文档
- **日志**: 检查 `/var/log/clickhouse-server/` 目录
- **配置**: 查看 `/etc/clickhouse-server/` 目录
- **数据**: 查看 `/var/lib/clickhouse/` 目录

## 📄 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。 