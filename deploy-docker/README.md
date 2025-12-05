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

---

## 快速开始

### 一键部署（推荐）

```bash
# 部署到开发环境
sudo ./scripts/auto-deploy.sh -env dev

# 部署到测试环境
sudo ./scripts/auto-deploy.sh -env test

# 部署到生产环境
sudo ./scripts/auto-deploy.sh -env prod
```

### 交互式配置流程

运行部署脚本后，会依次询问：

#### 1. 端口配置
```
配置端口映射 (留空使用默认值):
HTTP端口 (默认: 8123): [输入或回车]
Native端口 (默认: 9000): [输入或回车]
```

#### 2. 密码配置
```
配置用户密码 (留空使用默认值):
注意: 密码应包含大小写字母、数字和特殊字符，建议长度至少12位

admin 用户密码 (默认: xnJ8_M2zd7R!uQXaVgQDbTYn): [输入或回车]
webuser 用户密码 (默认: w2E8_B43wzP!gS53c56Lz0g6): [输入或回车]
demouser 用户密码 (默认: l0K3_L12g5F!pX83c45Jz1h7): [输入或回车]
```

**注意**：密码输入时不会显示，这是安全特性。

### 部署结果

部署成功后，会自动：

1. 创建部署目录：`/opt/clickhouse-deploy-{env}`
2. 生成配置文件：`/opt/clickhouse-deploy-{env}/.env`
3. 启动 Docker 容器：`clickhouse-server-{env}`
4. 执行健康检查

### 查看配置

```bash
# 查看 .env 配置
cd /opt/clickhouse-deploy-dev
cat .env

# 查看服务状态
docker compose ps

# 查看容器日志
docker compose logs -f clickhouse-server-dev
```

### 连接数据库

```bash
# 使用 default 用户
docker exec clickhouse-server-dev clickhouse-client -u default --password clickhouse123

# 使用 admin 用户（需要使用你设置的密码）
docker exec clickhouse-server-dev clickhouse-client -u admin --password YOUR_ADMIN_PASSWORD

# 使用 webuser 用户
docker exec clickhouse-server-dev clickhouse-client -u webuser --password YOUR_WEBUSER_PASSWORD
```

### 常用命令

```bash
# 进入部署目录
cd /opt/clickhouse-deploy-dev

# 健康检查
./scripts/health-check.sh

# 用户测试
./scripts/test-users.sh

# 监控服务
./scripts/monitor.sh --once

# 同步密码（修改 .env 后）
./scripts/sync-passwords.sh

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 备份数据
./scripts/backup.sh
```

### 访问不同环境

```bash
# 开发环境
curl http://localhost:8123/ping
docker exec clickhouse-server-dev clickhouse-client --query "SELECT 1"

# 测试环境
curl http://localhost:8223/ping
docker exec clickhouse-server-test clickhouse-client --query "SELECT 1"

# 生产环境
curl http://localhost:8323/ping
docker exec clickhouse-server-prod clickhouse-client --query "SELECT 1"
```

---

## 环境变量配置

### 概述

部署脚本支持通过 `.env` 文件配置服务名称、容器名称、端口和用户密码，实现多环境隔离部署。

### 支持的配置项

#### 服务配置
- `CLICKHOUSE_SERVICE_NAME`: Docker Compose 服务名称
- `CLICKHOUSE_CONTAINER_NAME`: Docker 容器名称

#### 端口配置
- `CLICKHOUSE_HTTP_PORT`: HTTP 接口端口（默认：8123）
- `CLICKHOUSE_NATIVE_PORT`: Native 接口端口（默认：9000）

#### 用户密码配置
- `ADMIN_PASSWORD`: admin 用户密码
- `WEBUSER_PASSWORD`: webuser 用户密码
- `DEMOUSER_PASSWORD`: demouser 用户密码（只读用户）

### 配置文件位置

**每个环境独立的 `.env` 文件**：
```
/opt/clickhouse-deploy-dev/.env      # 开发环境配置
/opt/clickhouse-deploy-test/.env     # 测试环境配置
/opt/clickhouse-deploy-prod/.env     # 生产环境配置
```

### .env 文件示例

```bash
# ClickHouse 部署配置 - 开发环境
CLICKHOUSE_SERVICE_NAME=clickhouse-server-dev
CLICKHOUSE_CONTAINER_NAME=clickhouse-server-dev

# 端口配置
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_NATIVE_PORT=9000

# 用户密码配置
ADMIN_PASSWORD=Dev_Admin_2024!
WEBUSER_PASSWORD=Dev_Web_2024!
DEMOUSER_PASSWORD=Dev_Demo_2024!
```

### docker-compose.yml 环境变量支持

```yaml
services:
  clickhouse-server:
    image: clickhouse/clickhouse-server:25.6-alpine
    container_name: ${CLICKHOUSE_CONTAINER_NAME:-clickhouse-server}
    ports:
      - "${CLICKHOUSE_HTTP_PORT:-8123}:8123"
      - "${CLICKHOUSE_NATIVE_PORT:-9000}:9000"
```

Docker Compose 会自动读取当前目录的 `.env` 文件。

---

## 密码管理

### 设计理念

1. **配置集中管理**：密码配置在 `.env` 文件中
2. **自动同步机制**：通过脚本自动同步到 `users.xml`
3. **多环境隔离**：每个环境独立的密码配置

### 密码工作流程

```
.env 文件           →    auto-deploy.sh/sync-passwords.sh    →    users.xml
配置密码                  读取并同步                              ClickHouse 使用

ADMIN_PASSWORD           sed 替换                              <password><![CDATA[...]]></password>
WEBUSER_PASSWORD         使用 CDATA 包裹            
DEMOUSER_PASSWORD        防止特殊字符问题
```

### 方式 1：自动部署（推荐）

```bash
sudo ./scripts/auto-deploy.sh -env dev
# 交互式输入密码，自动同步到 users.xml
```

### 方式 2：手动配置

```bash
# 1. 编辑 .env 文件
cd /opt/clickhouse-deploy-dev
vim .env

# 2. 修改密码配置
ADMIN_PASSWORD=New_Secure_Password!
WEBUSER_PASSWORD=New_Web_Password!
DEMOUSER_PASSWORD=New_Demo_Password!

# 3. 同步到 users.xml
./scripts/sync-passwords.sh

# 4. 重启服务（脚本会询问）
docker compose restart
```

### 多环境密码示例

```bash
# 开发环境 (dev)
ADMIN_PASSWORD=Dev_Admin_2024!
WEBUSER_PASSWORD=Dev_Web_2024!
DEMOUSER_PASSWORD=Dev_Demo_2024!

# 测试环境 (test)
ADMIN_PASSWORD=Test_Admin_2024!
WEBUSER_PASSWORD=Test_Web_2024!
DEMOUSER_PASSWORD=Test_Demo_2024!

# 生产环境 (prod)
ADMIN_PASSWORD=Prod_SecureAdmin_2024!@#
WEBUSER_PASSWORD=Prod_SecureWeb_2024!@#
DEMOUSER_PASSWORD=Prod_SecureDemo_2024!@#
```

### 密码安全建议

1. **使用强密码**
   - 至少 12 位字符
   - 包含大小写字母、数字和特殊字符
   - 示例：`Secure_Pass_2024!@#`

2. **不同环境使用不同密码**
   - 开发环境可以使用相对简单的密码
   - 生产环境必须使用强密码

3. **保护 .env 文件**
   ```bash
   chmod 600 .env
   ```

4. **定期更换密码**
   - 生产环境建议每 3-6 个月更换一次
   - 修改后运行 `sync-passwords.sh` 同步

5. **备份配置**
   ```bash
   cp .env .env.backup
   ```

### sync-passwords.sh 脚本

用于在修改 `.env` 文件后同步密码到 `users.xml`：

```bash
cd /opt/clickhouse-deploy-dev
./scripts/sync-passwords.sh
```

功能：
- 读取 `.env` 中的密码配置
- 自动备份 `users.xml`
- 使用 CDATA 包裹密码更新到 `users.xml`
- 询问是否重启服务

### 为什么使用 CDATA？

```xml
<!-- 不使用 CDATA：特殊字符可能导致 XML 解析错误 -->
<password>Pass<word&!@#</password>  ❌

<!-- 使用 CDATA：安全处理所有特殊字符 -->
<password><![CDATA[Pass<word&!@#]]></password>  ✅
```

---

## 故障排查

### 端口已被占用

```bash
# 检查端口占用
netstat -tuln | grep 8123

# 解决方案：使用不同端口
sudo ./scripts/auto-deploy.sh -env dev
# 输入: 8223
```

### 容器名冲突

```bash
# 检查现有容器
docker ps -a | grep clickhouse

# 清理旧容器
docker stop clickhouse-server-dev
docker rm clickhouse-server-dev

# 重新部署
sudo ./scripts/auto-deploy.sh -env dev
```

### 密码问题

```bash
# 检查 .env 文件中的密码
cat .env | grep PASSWORD

# 检查 users.xml 中的密码格式
cat clickhouse/config/users.d/users.xml | grep -A 2 "admin"

# 重新同步密码
./scripts/sync-passwords.sh

# 重启服务
docker compose restart
```

### 多环境密码混乱

```bash
# 每个环境独立查看
cd /opt/clickhouse-deploy-dev && cat .env | grep PASSWORD
cd /opt/clickhouse-deploy-test && cat .env | grep PASSWORD
cd /opt/clickhouse-deploy-prod && cat .env | grep PASSWORD
```

---

## 工具脚本

### auto-deploy.sh
一键部署脚本，支持多环境部署和交互式配置。

```bash
# 查看帮助
./scripts/auto-deploy.sh -h

# 部署到指定环境
sudo ./scripts/auto-deploy.sh -env prod
```

### sync-passwords.sh ⭐ 新增
从 `.env` 文件同步密码到 `users.xml`。

```bash
./scripts/sync-passwords.sh
```

### health-check.sh
全面的健康检查脚本。

```bash
./scripts/health-check.sh
```

### monitor.sh
实时监控服务状态和性能指标。

```bash
# 单次检查
./scripts/monitor.sh --once

# 持续监控
./scripts/monitor.sh
```

### test-users.sh
测试用户连接（交互式输入密码）。

```bash
./scripts/test-users.sh
```

### backup.sh
数据备份脚本。

```bash
./scripts/backup.sh
```

---

## 最佳实践

### 初次部署

1. 使用 `auto-deploy.sh` 进行一键部署
2. 根据提示配置端口和密码
3. 运行健康检查验证部署

### 密码管理

1. 在 `.env` 文件中配置密码
2. 使用 `sync-passwords.sh` 同步到 `users.xml`
3. 定期更换生产环境密码
4. 保护 `.env` 文件权限

### 多环境部署

1. 为每个环境分配不同的端口
2. 使用不同的密码
3. 独立管理各环境配置
4. 定期审计各环境安全性

### 运维操作

1. 定期运行健康检查
2. 监控系统资源使用
3. 定期备份数据和配置
4. 记录重要操作和变更

