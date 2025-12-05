# ClickHouse Docker 部署方案大纲

使用docker的部署，支持多平台部署

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

## 部署架构

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

## 部署步骤大纲

### 1. 环境准备

- [ ] 系统要求检查
- [ ] 操作系统兼容性验证
- [ ] Docker环境安装（多平台支持）
- [ ] Docker Compose安装
- [ ] 网络配置检查
- [ ] 存储空间检查

### 2. 目录结构创建

```json
deploy-docker/
├── docker-compose.yml          # Docker Compose配置
├── clickhouse/                 # ClickHouse配置目录
│   ├── config/                 # 配置文件
│   │   ├── config.d/          # 主配置文件目录
│   │   │   └── config.xml     # 主配置文件（基础配置、日志、网络、存储、系统级优化、TTL等）
│   │   └── users.d/           # 用户配置文件目录
│   │       ├── users.xml      # 用户性能配置文件（profiles、线程数、内存限制、超时设置、异步插入配置）
│   │       └── default-user.xml # 默认用户配置（用户认证、网络访问、权限配置）
│   ├── logs/                  # 日志目录
│   └── data/                  # 数据目录
├── scripts/                    # 部署脚本
│   ├── auto-deploy.sh         # 一键部署脚本
│   ├── install-docker.sh      # Docker安装脚本（多平台）
│   ├── setup-project.sh       # 项目设置脚本
│   ├── deploy.sh              # 部署脚本
│   ├── health-check.sh        # 健康检查脚本
│   ├── backup.sh              # 备份脚本
│   ├── monitor.sh             # 监控脚本
│   ├── system-optimization.sh # 系统优化脚本
│   ├── platform-test.sh       # 平台测试脚本
│   ├── test-docker-compose.sh # Docker Compose测试脚本
│   ├── test-users.sh          # 用户测试脚本
│   └── generate-password-hash.sh # 密码哈希生成脚本
└── docs/                      # 文档
    ├── 部署指南.md            # 多平台部署指南
    ├── 配置说明.md            # 配置详细说明
    └── 运维手册.md            # 运维操作指南
```

### 3. Docker Compose配置

- [ ] 基础服务配置
- [ ] 网络配置
- [ ] 存储卷配置
- [ ] 环境变量配置
- [ ] 健康检查配置

### 4. ClickHouse配置

- [ ] 主配置文件 (config.d/config.xml)
  - [ ] 内存配置 (16GB优化)
  - [ ] CPU配置 (4核优化)
  - [ ] 存储配置 (150GB NVMe SSD优化)
  - [ ] 网络配置
  - [ ] 系统日志配置
  - [ ] TTL配置
- [ ] 用户配置文件 (users.d/users.xml)
  - [ ] 默认用户性能配置
  - [ ] 线程数配置
  - [ ] 内存限制配置
  - [ ] 超时设置
  - [ ] 异步插入配置
- [ ] 默认用户配置 (users.d/default-user.xml)
  - [ ] 用户认证配置
  - [ ] 网络访问控制
  - [ ] 权限配置

### 5. 数据初始化

- [ ] 数据库创建
- [ ] 表结构创建
- [ ] 索引配置
- [ ] 分区策略配置
- [ ] 压缩策略配置

### 6. 安全配置

- [ ] 用户认证配置
- [ ] 网络访问控制
- [ ] SSL/TLS配置
- [ ] 防火墙规则（多平台支持）

### 7. 监控配置

- [ ] 系统监控
- [ ] ClickHouse监控
- [ ] 日志收集
- [ ] 告警配置

### 8. 备份策略

- [ ] 自动备份脚本
- [ ] 备份存储配置
- [ ] 恢复测试
- [ ] 备份验证

### 9. 性能优化

- [ ] 内存配置优化
- [ ] 存储配置优化
- [ ] 网络配置优化
- [ ] 查询优化

### 10. 部署验证

- [ ] 服务启动验证
- [ ] 连接测试
- [ ] 性能测试
- [ ] 功能测试

## 部署文件清单

### 核心配置文件

- [ ] `docker-compose.yml` - Docker Compose主配置
- [ ] `clickhouse/config/config.d/config.xml` - ClickHouse主配置
- [ ] `clickhouse/config/users.d/users.xml` - 用户性能配置
- [ ] `clickhouse/config/users.d/default-user.xml` - 默认用户配置

### 脚本文件

- [ ] `scripts/auto-deploy.sh` - 一键部署脚本（支持 -env 参数）
- [ ] `scripts/install-docker.sh` - Docker安装脚本（多平台）
- [ ] `scripts/setup-project.sh` - 项目设置脚本（支持 -env 参数）
- [ ] `scripts/deploy.sh` - 部署脚本
- [ ] `scripts/health-check.sh` - 健康检查脚本
- [ ] `scripts/backup.sh` - 备份脚本
- [ ] `scripts/monitor.sh` - 监控脚本
- [ ] `scripts/system-optimization.sh` - 系统优化脚本
- [ ] `scripts/platform-test.sh` - 平台测试脚本
- [ ] `scripts/test-docker-compose.sh` - Docker Compose测试脚本
- [ ] `scripts/test-users.sh` - 用户测试脚本
- [ ] `scripts/generate-password-hash.sh` - 密码哈希生成脚本

### 文档文件

- [ ] `docs/部署指南.md` - 多平台部署指南
- [ ] `docs/配置说明.md` - 配置详细说明
- [ ] `docs/运维手册.md` - 运维操作指南

## 平台特定配置

### RHEL 兼容发行版

- **包管理器**: yum (CentOS 7/RHEL 7) 或 dnf (CentOS 8+/RHEL 8+)
- **防火墙**: firewalld
- **服务管理**: systemd
- **Docker安装**: 使用官方仓库

### Ubuntu LTS / Debian

- **包管理器**: apt
- **防火墙**: ufw (Ubuntu) 或 iptables (Debian)
- **服务管理**: systemd
- **Docker安装**: 使用官方仓库

## 部署检查清单

### 部署前检查

- [ ] 硬件资源满足要求
- [ ] 操作系统版本兼容
- [ ] 网络连接正常
- [ ] 存储空间充足
- [ ] 防火墙配置正确

### 部署中检查

- [ ] Docker容器启动成功
- [ ] ClickHouse服务正常
- [ ] 配置文件加载正确
- [ ] 数据目录权限正确
- [ ] 防火墙端口开放

### 部署后检查

- [ ] 服务可访问
- [ ] 查询性能正常
- [ ] 监控指标正常
- [ ] 备份功能正常

## 自动化脚本功能

### 多平台支持

| 脚本名称 | RHEL兼容 | Ubuntu/Debian | 功能描述 |
|---------|----------|---------------|----------|
| `auto-deploy.sh` | ✅ | ✅ | 一键完成所有部署步骤（支持 -env 参数） |
| `install-docker.sh` | ✅ | ✅ | 自动检测平台并安装Docker |
| `setup-project.sh` | ✅ | ✅ | 设置项目目录和配置文件（支持 -env 参数） |
| `deploy.sh` | ✅ | ✅ | 部署ClickHouse服务 |
| `health-check.sh` | ✅ | ✅ | 健康检查和验证 |
| `backup.sh` | ✅ | ✅ | 数据备份和恢复 |
| `monitor.sh` | ✅ | ✅ | 系统监控和告警 |
| `system-optimization.sh` | ✅ | ✅ | 系统性能优化 |
| `platform-test.sh` | ✅ | ✅ | 平台兼容性测试 |

### 平台检测功能

- 自动检测操作系统类型
- 自动选择对应的包管理器
- 自动配置防火墙规则
- 自动安装依赖包

## 配置优化重点

### 硬件配置基准

| 组件 | 规格 | 优化重点 |
|------|------|----------|
| **CPU** | 4核 | 线程池优化、并发控制 |
| **内存** | 16GB | 缓存分配、内存限制 |
| **存储** | 150GB NVMe SSD | 合并策略、IO优化 |
| **网络** | 1Gbps | 连接池、超时设置 |

### 内存分配优化 (16GB总内存)

```json
总内存使用限制: 12GB (75%)
├── 查询内存限制: 12GB (75%)
├── 用户内存限制: 12GB (75%)
└── 缓存分配:
    ├── 未压缩缓存: 6GB (37.5%)
    └── 标记缓存: 3GB (18.75%)
```

### CPU线程优化 (4核CPU)

```json
最大线程数: 4 (1:1对应CPU核心)
插入线程数: 4
异步插入线程: 4（用户级）；服务器级别：8
并发查询数: 10 (CPU核心数 × 2 + 2)
```

### 存储优化 (150GB NVMe SSD)

```json
最大合并空间: 100GB (67%)
最小合并空间: 50GB (33%)
索引粒度: 8192
```

## 运维功能

### 监控告警机制

- **系统监控**: CPU、内存、磁盘使用率监控
- **ClickHouse监控**: 查询性能、连接数、存储使用情况
- **日志监控**: 查询日志、错误日志、慢查询日志
- **告警机制**: 邮件告警、阈值告警

### 备份策略

- **全量备份**: 每周一凌晨执行，保留4周
- **实时备份**: 重要数据变更时立即备份
- **备份验证**: 定期测试备份恢复流程
- **备份监控**: 监控备份状态和完整性

### 故障排查

- **常见问题**: 容器启动失败、内存不足、磁盘空间不足
- **性能问题**: 慢查询分析、资源使用分析
- **日志分析**: 系统日志、查询日志、错误日志
- **性能优化**: 配置优化、表结构优化、查询优化

### 安全运维

- **用户管理**: 创建用户、权限管理
- **网络安全**: 防火墙配置、SSL配置
- **访问控制**: RBAC权限控制、行级访问控制
- **安全加固**: 密码策略、网络访问限制

## 下一步计划

1. **详细配置文件编写**
   - Docker Compose配置 ✅
   - ClickHouse配置文件 ✅
   - 初始化脚本 ✅

2. **部署脚本编写**
   - 自动化部署脚本 ✅
   - 配置验证脚本 ✅
   - 性能测试脚本 ✅

3. **监控方案实现**
   - 系统监控配置 ✅
   - ClickHouse监控配置 ✅
   - 告警规则配置 ✅

4. **文档完善**
   - 多平台部署操作指南 ✅
   - 运维手册 ✅
   - 故障排查指南 ✅

5. **测试验证**
   - 多平台兼容性测试 ✅
   - 自动化脚本测试 ✅
   - 性能基准测试 ✅

## 部署方式选择

### 方式一：自动化部署（推荐）

**执行时间**: 5-10分钟
**适用场景**: 生产环境、快速部署

#### 基础用法

```bash
# 部署到开发环境（默认）
sudo ./scripts/auto-deploy.sh

# 部署到测试环境
sudo ./scripts/auto-deploy.sh -env test

# 部署到生产环境
sudo ./scripts/auto-deploy.sh -env prod
```

#### 环境参数说明

| 参数 | 环境 | 部署目录 | 适用场景 |
|------|------|----------|----------|
| `-env dev` | 开发环境 | `/opt/clickhouse-deploy-dev` | 开发测试、功能验证 |
| `-env test` | 测试环境 | `/opt/clickhouse-deploy-test` | 集成测试、性能测试 |
| `-env prod` | 生产环境 | `/opt/clickhouse-deploy-prod` | 生产部署、正式环境 |

**注意**: 如果不指定 `-env` 参数，默认部署到开发环境 (dev)

### 方式二：手动部署

**执行时间**: 30-60分钟
**适用场景**: 学习、定制化部署

## 自动化部署

### 一键部署（最简单）

```bash
# 1. 下载项目文件
git clone <repository-url>
cd clickhouse/deploy-docker

# 2. 给脚本添加执行权限
chmod +x scripts/*.sh

# 3. 执行一键部署（根据目标环境选择）

# 部署到开发环境（默认）
sudo ./scripts/auto-deploy.sh

# 部署到测试环境
sudo ./scripts/auto-deploy.sh -env test

# 部署到生产环境
sudo ./scripts/auto-deploy.sh -env prod

# 查看帮助信息
./scripts/auto-deploy.sh -h
```

### 环境隔离说明

通过 `-env` 参数，可以在同一台服务器上部署多个独立的 ClickHouse 实例：

- **开发环境**: `/opt/clickhouse-deploy-dev` - 用于开发和功能测试
- **测试环境**: `/opt/clickhouse-deploy-test` - 用于集成测试和性能测试
- **生产环境**: `/opt/clickhouse-deploy-prod` - 用于生产部署

每个环境拥有独立的：
- 配置文件目录
- 数据存储目录
- 日志目录
- Docker 容器实例（需要修改端口避免冲突）

### 分步自动化部署

如果需要更细粒度的控制，可以分步执行：

```bash
# 1. 安装Docker环境（如果未安装）
sudo ./scripts/install-docker.sh

# 2. 设置项目目录和配置文件（指定环境）
sudo ./scripts/setup-project.sh -env prod

# 3. 切换到部署目录
cd /opt/clickhouse-deploy-prod

# 4. 部署ClickHouse服务
./scripts/deploy.sh

# 5. 健康检查
./scripts/health-check.sh
```

## 生产环境部署建议

### 环境规划

在部署前，建议根据实际需求规划环境：

1. **单环境部署**
   - 适合：仅需生产环境
   - 部署命令：`sudo ./scripts/auto-deploy.sh -env prod`
   - 部署目录：`/opt/clickhouse-deploy-prod`

2. **多环境部署**
   - 适合：需要开发、测试、生产环境隔离
   - 注意事项：
     - 各环境使用独立的部署目录
     - 需要修改 docker-compose.yml 中的端口避免冲突
     - 合理分配系统资源（CPU、内存、磁盘）

### 安全配置

1. **网络访问控制**
   - 限制为内网IP段
   - 配置防火墙规则
   - 启用SSL/TLS

2. **强密码策略**
   - 修改默认密码为强密码
   - 定期更换密码
   - 实施密码复杂度要求

3. **用户权限管理**
   - 实施RBAC权限控制
   - 最小权限原则
   - 定期权限审计

### 性能优化

1. **内存配置**
   - 根据系统内存调整配置
   - 优化缓存分配
   - 监控内存使用情况

2. **CPU配置**
   - 根据CPU核心数调整线程数
   - 优化并发查询数
   - 启用异步插入

3. **存储配置**
   - 根据存储类型优化参数
   - 配置合适的分区策略
   - 优化合并策略

### 监控配置

1. **日志监控**
   - 启用查询日志用于性能分析
   - 启用错误日志用于故障排查
   - 启用慢查询日志用于优化

2. **系统监控**
   - 监控内存使用情况
   - 监控CPU使用情况
   - 监控磁盘IO情况
   - 监控网络连接情况

### 备份策略

1. **配置文件备份**
   - 定期备份config.d和users.d目录
   - 版本控制配置文件变更
   - 测试配置恢复流程

2. **数据备份**
   - 定期备份data目录
   - 测试数据恢复流程
   - 验证备份完整性

## 多环境部署实践

### 端口规划

在同一台服务器部署多个环境时，需要为每个环境分配不同的端口：

| 环境 | HTTP端口 | Native端口 | 部署目录 |
|------|----------|------------|----------|
| 开发环境 (dev) | 8123 | 9000 | `/opt/clickhouse-deploy-dev` |
| 测试环境 (test) | 8124 | 9001 | `/opt/clickhouse-deploy-test` |
| 生产环境 (prod) | 8125 | 9002 | `/opt/clickhouse-deploy-prod` |

### 多环境部署步骤

```bash
# 1. 部署开发环境
sudo ./scripts/auto-deploy.sh -env dev

# 2. 修改测试环境端口配置
# 编辑 /opt/clickhouse-deploy-test/docker-compose.yml
# 将端口从 8123:8123 改为 8124:8123
# 将端口从 9000:9000 改为 9001:9000

# 3. 部署测试环境
sudo ./scripts/auto-deploy.sh -env test

# 4. 修改生产环境端口配置
# 编辑 /opt/clickhouse-deploy-prod/docker-compose.yml
# 将端口从 8123:8123 改为 8125:8123
# 将端口从 9000:9000 改为 9002:9000

# 5. 部署生产环境
sudo ./scripts/auto-deploy.sh -env prod
```

### 环境管理

```bash
# 查看各环境服务状态
cd /opt/clickhouse-deploy-dev && docker-compose ps
cd /opt/clickhouse-deploy-test && docker-compose ps
cd /opt/clickhouse-deploy-prod && docker-compose ps

# 停止特定环境
cd /opt/clickhouse-deploy-dev && docker-compose stop

# 启动特定环境
cd /opt/clickhouse-deploy-prod && docker-compose start

# 重启特定环境
cd /opt/clickhouse-deploy-test && docker-compose restart
```

### 资源隔离建议

对于多环境部署，建议：

1. **CPU资源隔离**
   - 使用 Docker CPU 限制参数
   - 为生产环境分配更多 CPU 资源

2. **内存资源隔离**
   - 修改各环境的内存配置
   - 确保总内存分配不超过系统可用内存

3. **磁盘空间规划**
   - 为各环境预留足够的磁盘空间
   - 监控各环境的磁盘使用情况

## 总结

本部署方案提供了完整的ClickHouse Docker部署解决方案，包括：

### 📁 配置文件清单

- **docker-compose.yml**: Docker Compose主配置
- **config.d/config.xml**: 主配置文件，包含基础配置、日志配置、网络配置、内存配置、存储配置和系统日志配置
- **users.d/users.xml**: 用户性能配置文件，包含线程数、内存限制、超时设置和异步插入配置
- **users.d/default-user.xml**: 默认用户配置，包含用户认证、网络访问和权限配置

### 📊 配置优化重点

#### 主配置文件 (config.xml)

- 网络配置（端口、连接数、并发查询数）
- 内存配置（服务器内存、缓存分配）
- 存储配置（合并树引擎参数）
- 系统日志配置（查询日志、错误日志、慢查询日志）

#### 用户配置文件 (users.xml)

- 线程配置（最大线程数、插入线程数）
- 内存限制（查询内存、用户内存）
- 超时设置（连接、接收、发送超时）
- 异步插入配置

#### 用户定义文件 (default-user.xml)

- 用户认证（密码、网络访问）
- 权限配置（配置文件、配额、访问管理）

### 🚀 自动化脚本

| 脚本名称 | 环境参数支持 | 功能描述 |
|---------|-------------|----------|
| **auto-deploy.sh** | ✅ 支持 `-env` | 一键完成所有部署步骤，支持多环境部署 |
| **setup-project.sh** | ✅ 支持 `-env` | 项目目录和配置文件设置，支持多环境 |
| **install-docker.sh** | - | 多平台Docker安装 |
| **deploy.sh** | - | ClickHouse服务部署 |
| **health-check.sh** | - | 健康检查和验证 |
| **backup.sh** | - | 数据备份和恢复 |
| **monitor.sh** | - | 系统监控和告警 |

#### 环境参数使用示例

```bash
# 部署到不同环境
sudo ./scripts/auto-deploy.sh -env dev     # 开发环境
sudo ./scripts/auto-deploy.sh -env test    # 测试环境
sudo ./scripts/auto-deploy.sh -env prod    # 生产环境

# 单独设置项目目录（指定环境）
sudo ./scripts/setup-project.sh -env prod

# 查看帮助
./scripts/auto-deploy.sh -h
```

### 📚 文档体系

- **部署指南.md**: 多平台部署操作指南
- **配置说明.md**: 配置详细说明和优化建议
- **运维手册.md**: 运维操作指南和故障排查

