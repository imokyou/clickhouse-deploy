# ClickHouse 单片多副本 CentOS Docker 部署手册

## 目录
- [1. 环境准备](#1-环境准备)
- [2. Docker环境配置](#2-docker环境配置)
- [3. 集群架构设计](#3-集群架构设计)
- [4. Docker Compose配置](#4-docker-compose配置)
- [5. 集群部署](#5-集群部署)
- [6. 监控部署](#6-监控部署)
- [7. 负载均衡配置](#7-负载均衡配置)
- [8. 安全配置](#8-安全配置)
- [9. 备份策略](#9-备份策略)
- [10. 验证测试](#10-验证测试)
- [11. 故障排查](#11-故障排查)

---

## 1. 环境准备

### 1.1 系统要求检查

**硬件要求**：
- 3台服务器，每台配置：
  - CPU: 4核以上
  - 内存: 16GB以上
  - 存储: 150GB NVMe SSD
  - 网络: 1Gbps带宽

**软件要求**：
- CentOS 7.6+ 或 CentOS 8.x
- Docker 20.10+
- Docker Compose 2.0+

```bash
# 检查系统版本
cat /etc/redhat-release

# 检查硬件配置
nproc
free -h
df -h

# 检查网络配置
ip addr show
ping -c 3 <其他节点IP>
```

### 1.2 网络配置

**节点信息**：
- 节点1: 192.168.1.10 (clickhouse-node1)
- 节点2: 192.168.1.11 (clickhouse-node2)  
- 节点3: 192.168.1.12 (clickhouse-node3)

```bash
# 配置hosts文件
sudo vim /etc/hosts
```

添加以下内容：

```bash
192.168.1.10 clickhouse-node1
192.168.1.11 clickhouse-node2
192.168.1.12 clickhouse-node3
```

```bash
# 测试节点间连通性
for node in clickhouse-node1 clickhouse-node2 clickhouse-node3; do
    echo "Testing connection to $node..."
    ping -c 3 $node
done
```

### 1.3 系统优化

```bash
# 更新系统
sudo yum update -y

# 安装基础工具
sudo yum install -y wget curl vim net-tools htop iotop

# 安装EPEL仓库
sudo yum install -y epel-release
```

**系统参数优化**：

```bash
# 编辑系统参数
sudo vim /etc/sysctl.conf
```

添加以下配置：

```bash
# 网络参数优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr

# 文件系统参数
fs.file-max = 1000000
fs.nr_open = 1000000

# 内存参数
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# 应用参数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
```

```bash
# 应用配置
sudo sysctl -p
```

---

## 2. Docker环境配置

### 2.1 安装Docker

```bash
# 卸载旧版本Docker
sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine

# 安装Docker依赖
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# 添加Docker官方仓库
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 安装Docker
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 启动Docker服务
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
sudo docker --version
sudo docker-compose --version
```

### 2.2 配置Docker

```bash
# 创建docker用户组
sudo groupadd docker

# 添加当前用户到docker组
sudo usermod -aG docker $USER

# 配置Docker守护进程
sudo vim /etc/docker/daemon.json
```

Docker配置内容：

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Hard": 65536,
      "Name": "nofile",
      "Soft": 65536
    }
  }
}
```

```bash
# 重启Docker服务
sudo systemctl restart docker

# 验证配置
sudo docker info
```

### 2.3 创建项目目录

```bash
# 创建项目目录结构
sudo mkdir -p /opt/clickhouse-cluster/{config,data,logs,backup}
sudo mkdir -p /opt/clickhouse-cluster/config/{clickhouse,keeper,nginx}
sudo mkdir -p /opt/clickhouse-cluster/data/{clickhouse,keeper}
sudo mkdir -p /opt/clickhouse-cluster/logs/{clickhouse,keeper,nginx}

# 设置权限
sudo chown -R $USER:$USER /opt/clickhouse-cluster
```

---

## 3. 集群架构设计

### 3.1 节点角色分配

| 节点 | ClickHouse | Keeper | 负载均衡 |
|------|------------|--------|----------|
| 节点1 | Replica 1 | Keeper 1 | Nginx |
| 节点2 | Replica 2 | Keeper 2 | - |
| 节点3 | Replica 3 | Keeper 3 | - |

### 3.2 端口规划

| 服务 | 内部端口 | 外部端口 | 说明 |
|------|----------|----------|------|
| ClickHouse HTTP | 8123 | 8123 | HTTP接口 |
| ClickHouse TCP | 9000 | 9000 | TCP接口 |
| ClickHouse Keeper | 9181 | 9181 | Keeper接口 |
| Nginx | 80 | 80 | 负载均衡 |
| Prometheus | 9090 | 9090 | 监控 |
| Grafana | 3000 | 3000 | 可视化 |

### 3.3 网络设计

```bash
# 创建Docker网络
sudo docker network create clickhouse-network --subnet=172.20.0.0/16
```

---

## 4. Docker Compose配置

### 4.1 创建Docker Compose文件

```bash
# 创建docker-compose.yml
vim /opt/clickhouse-cluster/docker-compose.yml
```

Docker Compose配置：

```yaml
version: '3.8'

services:
  # ClickHouse Keeper 1
  clickhouse-keeper-1:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-keeper-1
    hostname: clickhouse-keeper-1
    restart: unless-stopped
    ports:
      - "9181:9181"
    volumes:
      - ./config/keeper/keeper1.xml:/etc/clickhouse-server/config.d/keeper.xml
      - ./data/keeper/keeper1:/var/lib/clickhouse/
      - ./logs/keeper:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.d/keeper.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.10
    command: clickhouse-keeper --config=/etc/clickhouse-server/config.d/keeper.xml

  # ClickHouse Keeper 2
  clickhouse-keeper-2:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-keeper-2
    hostname: clickhouse-keeper-2
    restart: unless-stopped
    ports:
      - "9182:9181"
    volumes:
      - ./config/keeper/keeper2.xml:/etc/clickhouse-server/config.d/keeper.xml
      - ./data/keeper/keeper2:/var/lib/clickhouse/
      - ./logs/keeper:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.d/keeper.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.11
    command: clickhouse-keeper --config=/etc/clickhouse-server/config.d/keeper.xml

  # ClickHouse Keeper 3
  clickhouse-keeper-3:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-keeper-3
    hostname: clickhouse-keeper-3
    restart: unless-stopped
    ports:
      - "9183:9181"
    volumes:
      - ./config/keeper/keeper3.xml:/etc/clickhouse-server/config.d/keeper.xml
      - ./data/keeper/keeper3:/var/lib/clickhouse/
      - ./logs/keeper:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.d/keeper.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.12
    command: clickhouse-keeper --config=/etc/clickhouse-server/config.d/keeper.xml

  # ClickHouse Server 1
  clickhouse-server-1:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-server-1
    hostname: clickhouse-server-1
    restart: unless-stopped
    ports:
      - "8123:8123"
      - "9000:9000"
    volumes:
      - ./config/clickhouse/config1.xml:/etc/clickhouse-server/config.xml
      - ./config/clickhouse/users1.xml:/etc/clickhouse-server/users.xml
      - ./data/clickhouse/server1:/var/lib/clickhouse/
      - ./logs/clickhouse:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.20
    depends_on:
      - clickhouse-keeper-1
      - clickhouse-keeper-2
      - clickhouse-keeper-3

  # ClickHouse Server 2
  clickhouse-server-2:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-server-2
    hostname: clickhouse-server-2
    restart: unless-stopped
    ports:
      - "8124:8123"
      - "9001:9000"
    volumes:
      - ./config/clickhouse/config2.xml:/etc/clickhouse-server/config.xml
      - ./config/clickhouse/users2.xml:/etc/clickhouse-server/users.xml
      - ./data/clickhouse/server2:/var/lib/clickhouse/
      - ./logs/clickhouse:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.21
    depends_on:
      - clickhouse-keeper-1
      - clickhouse-keeper-2
      - clickhouse-keeper-3

  # ClickHouse Server 3
  clickhouse-server-3:
    image: clickhouse/clickhouse-server:23.8
    container_name: clickhouse-server-3
    hostname: clickhouse-server-3
    restart: unless-stopped
    ports:
      - "8125:8123"
      - "9002:9000"
    volumes:
      - ./config/clickhouse/config3.xml:/etc/clickhouse-server/config.xml
      - ./config/clickhouse/users3.xml:/etc/clickhouse-server/users.xml
      - ./data/clickhouse/server3:/var/lib/clickhouse/
      - ./logs/clickhouse:/var/log/clickhouse-server/
    environment:
      - CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.22
    depends_on:
      - clickhouse-keeper-1
      - clickhouse-keeper-2
      - clickhouse-keeper-3

  # Nginx负载均衡器
  nginx:
    image: nginx:alpine
    container_name: clickhouse-nginx
    hostname: clickhouse-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./config/nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./logs/nginx:/var/log/nginx/
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.30
    depends_on:
      - clickhouse-server-1
      - clickhouse-server-2
      - clickhouse-server-3

  # Prometheus监控
  prometheus:
    image: prom/prometheus:latest
    container_name: clickhouse-prometheus
    hostname: clickhouse-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./data/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.40

  # Grafana可视化
  grafana:
    image: grafana/grafana:latest
    container_name: clickhouse-grafana
    hostname: clickhouse-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - ./data/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    networks:
      clickhouse-network:
        ipv4_address: 172.20.0.41
    depends_on:
      - prometheus

networks:
  clickhouse-network:
    external: true
```

---

## 5. 集群部署

### 5.1 启动Keeper集群

```bash
# 进入项目目录
cd /opt/clickhouse-cluster

# 启动Keeper集群
docker-compose up -d clickhouse-keeper-1 clickhouse-keeper-2 clickhouse-keeper-3

# 检查Keeper状态
docker-compose logs clickhouse-keeper-1
docker-compose logs clickhouse-keeper-2
docker-compose logs clickhouse-keeper-3

# 验证Keeper集群
docker exec -it clickhouse-keeper-1 clickhouse-keeper-cli --host=clickhouse-keeper-1 --port=9181
```

### 5.2 启动ClickHouse集群

```bash
# 启动ClickHouse节点
docker-compose up -d clickhouse-server-1 clickhouse-server-2 clickhouse-server-3

# 检查服务状态
docker-compose ps

# 查看日志
docker-compose logs clickhouse-server-1
```

### 5.3 验证集群状态

```bash
# 连接到任意节点验证
docker exec -it clickhouse-server-1 clickhouse-client --host=clickhouse-server-1 --port=9000

# 检查集群状态
SELECT * FROM system.clusters;

# 检查副本状态
SELECT * FROM system.replicas;
```

---

## 6. 监控部署

### 6.1 启动监控服务

```bash
# 启动Prometheus和Grafana
docker-compose up -d prometheus grafana

# 检查监控服务状态
docker-compose ps prometheus grafana

# 访问Grafana
# 浏览器访问: http://localhost:3000
# 用户名: admin
# 密码: admin123
```

### 6.2 配置Grafana数据源

1. 登录Grafana
2. 添加Prometheus数据源：
   - URL: `http://prometheus:9090`
   - Access: Server (default)

---

## 7. 负载均衡配置

### 7.1 启动负载均衡器

```bash
# 启动Nginx
docker-compose up -d nginx

# 检查Nginx状态
docker-compose ps nginx

# 测试负载均衡
curl http://localhost/ping
```

---

## 8. 安全配置

### 8.1 配置SSL/TLS

```bash
# 生成SSL证书
mkdir -p /opt/clickhouse-cluster/ssl
cd /opt/clickhouse-cluster/ssl

# 生成私钥
openssl genrsa -out clickhouse.key 2048

# 生成证书签名请求
openssl req -new -key clickhouse.key -out clickhouse.csr -subj "/C=CN/ST=Beijing/L=Beijing/O=Company/CN=clickhouse.local"

# 生成自签名证书
openssl x509 -req -days 365 -in clickhouse.csr -signkey clickhouse.key -out clickhouse.crt
```

### 8.2 配置防火墙

> **兼容性说明**: 以下配置脚本会自动检测系统防火墙状态，支持以下情况：
> - 使用firewalld的系统（CentOS 7+默认）
> - 使用iptables的系统（较老版本）
> - 未启用防火墙的系统

```bash
# 检查防火墙状态并配置端口
if systemctl is-active --quiet firewalld; then
    echo "防火墙已启用，配置端口开放..."
    # 配置防火墙规则
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=8123/tcp
    sudo firewall-cmd --permanent --add-port=9000/tcp
    sudo firewall-cmd --permanent --add-port=9181/tcp
    sudo firewall-cmd --permanent --add-port=9090/tcp
    sudo firewall-cmd --permanent --add-port=3000/tcp
    sudo firewall-cmd --reload
    
    # 验证端口开放
    sudo firewall-cmd --list-ports
    echo "防火墙端口配置完成"
elif systemctl is-active --quiet iptables; then
    echo "使用iptables防火墙，配置端口开放..."
    # 配置防火墙规则
    sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 8123 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9181 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
    sudo service iptables save
    echo "iptables端口配置完成"
else
    echo "防火墙未启用，跳过端口配置"
    echo "注意：如果后续需要启用防火墙，请手动配置端口开放"
fi
```

---

## 9. 备份策略

### 9.1 创建备份脚本

```bash
# 创建备份脚本
vim /opt/clickhouse-cluster/backup.sh
```

备份脚本内容：

```bash
#!/bin/bash

BACKUP_DIR="/opt/clickhouse-cluster/backup"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="clickhouse_backup_$DATE"

# 创建备份目录
mkdir -p $BACKUP_DIR

# 备份ClickHouse数据
docker exec clickhouse-server-1 clickhouse-client --query="BACKUP TABLE analytics.events_local TO '$BACKUP_DIR/$BACKUP_NAME'"

# 压缩备份
cd $BACKUP_DIR
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# 删除7天前的备份
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_NAME.tar.gz"
```

```bash
# 设置执行权限
chmod +x /opt/clickhouse-cluster/backup.sh

# 添加到crontab
crontab -e
```

添加定时任务：

```bash
# 每天凌晨2点执行备份
0 2 * * * /opt/clickhouse-cluster/backup.sh
```

---

## 10. 验证测试

### 10.1 基础连接测试

```bash
# 测试HTTP接口
curl "http://localhost/?query=SELECT%201"

# 测试TCP连接
docker exec -it clickhouse-server-1 clickhouse-client --host=clickhouse-server-1 --port=9000 --query="SELECT 1"

# 测试负载均衡
for i in {1..10}; do
    echo "Request $i:"
    curl -s "http://localhost/?query=SELECT%20hostName()" | grep -o "clickhouse-server-[1-3]"
done
```

### 10.2 数据写入测试

```bash
# 插入测试数据
docker exec -it clickhouse-server-1 clickhouse-client --host=clickhouse-server-1 --port=9000 --query="
INSERT INTO analytics.events (id, timestamp, event_type, user_id, data)
SELECT 
    number as id,
    now() - INTERVAL number SECOND as timestamp,
    'test_event' as event_type,
    concat('user_', toString(number % 1000)) as user_id,
    '{\"test\": \"data\", \"value\": ' || toString(number) || '}' as data
FROM numbers(1000000)
"
```

### 10.3 查询性能测试

```bash
# 执行查询性能测试
time docker exec -it clickhouse-server-1 clickhouse-client --host=clickhouse-server-1 --port=9000 --query="
SELECT 
    toDate(timestamp) as date,
    event_type,
    count() as count,
    uniq(user_id) as unique_users
FROM analytics.events 
WHERE timestamp >= now() - INTERVAL 1 DAY
GROUP BY date, event_type
"
```

---

## 11. 故障排查

### 11.1 常见问题解决

#### 容器无法启动

```bash
# 检查容器状态
docker-compose ps

# 查看容器日志
docker-compose logs <service_name>

# 检查配置文件
docker exec -it <container_name> cat /etc/clickhouse-server/config.xml
```

#### 集群连接问题

```bash
# 检查网络连接
docker network ls
docker network inspect clickhouse-network

# 测试容器间连通性
docker exec -it clickhouse-server-1 ping clickhouse-server-2
```

#### 数据复制问题

```bash
# 检查副本状态
docker exec -it clickhouse-server-1 clickhouse-client --query="SELECT * FROM system.replicas"

# 检查集群状态
docker exec -it clickhouse-server-1 clickhouse-client --query="SELECT * FROM system.clusters"
```

### 11.2 性能优化

```bash
# 检查内存使用
docker stats

# 查看慢查询
docker exec -it clickhouse-server-1 clickhouse-client --query="
SELECT 
    query,
    query_duration_ms,
    memory_usage,
    read_rows,
    read_bytes
FROM system.query_log 
WHERE type = 'QueryFinish'
ORDER BY query_duration_ms DESC 
LIMIT 10
"
```

### 11.3 监控检查

```bash
# 检查Prometheus状态
curl http://localhost:9090/-/healthy

# 检查Grafana状态
curl http://localhost:3000/api/health

# 检查ClickHouse指标
curl http://clickhouse-server-1:8123/metrics | grep clickhouse
```

---

## 附录

### A. 常用命令

```bash
# 启动所有服务
docker-compose up -d

# 停止所有服务
docker-compose down

# 重启服务
docker-compose restart <service_name>

# 查看日志
docker-compose logs -f <service_name>

# 进入容器
docker exec -it <container_name> bash

# 查看服务状态
docker-compose ps
```

### B. 配置文件位置

- Docker Compose: `/opt/clickhouse-cluster/docker-compose.yml`
- ClickHouse配置: `/opt/clickhouse-cluster/config/clickhouse/`
- Keeper配置: `/opt/clickhouse-cluster/config/keeper/`
- Nginx配置: `/opt/clickhouse-cluster/config/nginx/`
- Prometheus配置: `/opt/clickhouse-cluster/config/prometheus/`

### C. 端口说明

- 8123: ClickHouse HTTP接口
- 9000: ClickHouse TCP接口
- 9181: ClickHouse Keeper接口
- 80: Nginx负载均衡
- 9090: Prometheus监控
- 3000: Grafana可视化

### D. 性能基准

- 查询响应时间: < 1秒
- 并发查询数: 10个
- 数据复制延迟: < 5秒
- 故障转移时间: < 30秒
- 系统可用性: > 99.9%

---

**部署完成！**

现在您的ClickHouse Docker多副本集群已经部署完成。建议按照以下顺序进行验证：

1. 基础连接测试
2. 数据写入测试
3. 查询性能测试
4. 故障转移测试
5. 监控系统验证

如有问题，请参考故障排查章节或查看容器日志。 