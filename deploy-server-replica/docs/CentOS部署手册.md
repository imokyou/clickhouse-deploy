# ClickHouse 单片多副本集群 CentOS 部署手册

## 目录
1. [环境准备](#1-环境准备)
2. [ClickHouse Keeper部署](#2-clickhouse-keeper部署)
3. [ClickHouse集群部署](#3-clickhouse集群部署)
4. [集群配置和初始化](#4-集群配置和初始化)
5. [负载均衡配置](#5-负载均衡配置)
6. [监控系统部署](#6-监控系统部署)
7. [安全配置](#7-安全配置)
8. [验证和测试](#8-验证和测试)

---

## 1. 环境准备

### 1.1 服务器配置要求

**硬件配置（每台服务器）：**
- CPU: 4核
- 内存: 16GB
- 存储: 150GB NVMe SSD
- 网络: 1Gbps带宽

**网络配置：**
- 节点间延迟 < 2ms
- 开放端口: 9000, 8123, 9181, 2181, 2888, 3888

### 1.2 系统环境准备

#### 1.2.1 更新系统包

```bash
# 在所有节点执行
sudo yum update -y
sudo yum install -y epel-release
sudo yum groupinstall -y "Development Tools"
```

#### 1.2.2 安装必要依赖

```bash
# 在所有节点执行
sudo yum install -y wget curl vim net-tools ntp ntpdate
sudo yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
```

#### 1.2.3 配置NTP时间同步

```bash
# 在所有节点执行
sudo systemctl enable ntpd
sudo systemctl start ntpd
sudo ntpdate -s time.nist.gov
```

#### 1.2.4 系统参数优化

```bash
# 在所有节点执行
sudo tee -a /etc/sysctl.conf << EOF
# 网络参数优化
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1

# 文件系统参数
fs.file-max = 1000000
fs.nr_open = 1000000

# 内存参数
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF

sudo sysctl -p
```

#### 1.2.5 用户和目录创建

```bash
# 在所有节点执行
sudo useradd -r -s /bin/false clickhouse
sudo mkdir -p /var/lib/clickhouse
sudo mkdir -p /var/log/clickhouse-server
sudo mkdir -p /etc/clickhouse-server
sudo mkdir -p /etc/clickhouse-keeper
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse
sudo chown -R clickhouse:clickhouse /var/log/clickhouse-server
```

#### 1.2.6 防火墙配置

> **兼容性说明**: 以下配置脚本会自动检测系统防火墙状态，支持以下情况：
> - 使用firewalld的系统（CentOS 7+默认）
> - 使用iptables的系统（较老版本）
> - 未启用防火墙的系统

```bash
# 在所有节点执行
# 检查防火墙状态并配置端口
if systemctl is-active --quiet firewalld; then
    echo "防火墙已启用，配置端口开放..."
    sudo firewall-cmd --permanent --add-port=9000/tcp
    sudo firewall-cmd --permanent --add-port=8123/tcp
    sudo firewall-cmd --permanent --add-port=9181/tcp
    sudo firewall-cmd --permanent --add-port=2181/tcp
    sudo firewall-cmd --permanent --add-port=2888/tcp
    sudo firewall-cmd --permanent --add-port=3888/tcp
    sudo firewall-cmd --reload
    echo "防火墙端口配置完成"
elif systemctl is-active --quiet iptables; then
    echo "使用iptables防火墙，配置端口开放..."
    sudo iptables -A INPUT -p tcp --dport 9000 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 8123 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 9181 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 2181 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 2888 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 3888 -j ACCEPT
    sudo service iptables save
    echo "iptables端口配置完成"
else
    echo "防火墙未启用，跳过端口配置"
    echo "注意：如果后续需要启用防火墙，请手动配置端口开放"
fi
```

### 1.3 网络配置

#### 1.3.1 配置静态IP

```bash
# 在每台服务器上配置静态IP
# 示例：Node 1
sudo tee /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=static
ONBOOT=yes
IPADDR=192.168.1.10
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=8.8.8.8
DNS2=8.8.4.4
EOF

# Node 2: IPADDR=192.168.1.11
# Node 3: IPADDR=192.168.1.12
```

#### 1.3.2 配置hosts文件

```bash
# 在所有节点执行
sudo tee -a /etc/hosts << EOF
192.168.1.10 node1
192.168.1.11 node2
192.168.1.12 node3
EOF
```

#### 1.3.3 测试网络连通性

```bash
# 在所有节点执行
ping -c 3 node1
ping -c 3 node2
ping -c 3 node3
```

---

## 2. ClickHouse Keeper部署

### 2.1 安装ClickHouse Keeper

```bash
# 在所有节点执行
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
sudo yum install -y clickhouse-keeper
```

### 2.2 配置Keeper集群

#### 2.2.1 创建Keeper配置文件

```bash
# 在所有节点执行
sudo tee /etc/clickhouse-keeper/keeper.xml << EOF
<?xml version="1.0"?>
<clickhouse>
    <logger>
        <level>trace</level>
        <log>/var/log/clickhouse-server/clickhouse-keeper.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-keeper.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <http_port>9181</http_port>
    <tcp_port>9181</tcp_port>

    <keeper_server>
        <port>2181</port>
        <tcp_port>2181</tcp_port>
        <server_id>1</server_id>
        <log_storage_path>/var/lib/clickhouse/coordination/logs</log_storage_path>
        <snapshot_storage_path>/var/lib/clickhouse/coordination/snapshots</snapshot_storage_path>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <election_timeout_lower_bound_ms>1000</election_timeout_lower_bound_ms>
            <election_timeout_upper_bound_ms>10000</election_timeout_upper_bound_ms>
            <rotate_log_storage_interval>100000</rotate_log_storage_interval>
            <reserved_log_items>100000</reserved_log_items>
            <snapshot_distance>10000</snapshot_distance>
            <max_stored_snapshots>3</max_stored_snapshots>
            <max_concurrent_requests>100</max_concurrent_requests>
            <dead_session_check_period_ms>500</dead_session_check_period_ms>
            <heart_beat_interval_ms>500</heart_beat_interval_ms>
            <quorum_reads>false</quorum_reads>
            <raft_logs_level>trace</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server>
                <id>1</id>
                <hostname>node1</hostname>
                <port>9181</port>
            </server>
            <server>
                <id>2</id>
                <hostname>node2</hostname>
                <port>9181</port>
            </server>
            <server>
                <id>3</id>
                <hostname>node3</hostname>
                <port>9181</port>
            </server>
        </raft_configuration>
    </keeper_server>
</clickhouse>
EOF
```

**注意：** 需要根据实际节点修改server_id和hostname：
- Node 1: server_id=1, hostname=node1
- Node 2: server_id=2, hostname=node2  
- Node 3: server_id=3, hostname=node3

#### 2.2.2 创建Keeper数据目录

```bash
# 在所有节点执行
sudo mkdir -p /var/lib/clickhouse/coordination/logs
sudo mkdir -p /var/lib/clickhouse/coordination/snapshots
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse/coordination
```

#### 2.2.3 配置systemd服务

```bash
# 在所有节点执行
sudo tee /etc/systemd/system/clickhouse-keeper.service << EOF
[Unit]
Description=ClickHouse Keeper
After=network.target

[Service]
Type=simple
User=clickhouse
Group=clickhouse
ExecStart=/usr/bin/clickhouse-keeper --config=/etc/clickhouse-keeper/keeper.xml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable clickhouse-keeper
```

### 2.3 启动Keeper集群

```bash
# 在所有节点执行
sudo systemctl start clickhouse-keeper
sudo systemctl status clickhouse-keeper
```

### 2.4 验证Keeper集群状态

```bash
# 检查Keeper状态
echo stat | nc localhost 2181

# 检查Keeper日志
sudo tail -f /var/log/clickhouse-server/clickhouse-keeper.log
```

---

## 3. ClickHouse集群部署

### 3.1 安装ClickHouse Server

```bash
# 在所有节点执行
sudo yum install -y clickhouse-server clickhouse-client
```

### 3.2 配置ClickHouse集群

#### 3.2.1 创建主配置文件

```bash
# 在所有节点执行
sudo tee /etc/clickhouse-server/config.xml << EOF
<?xml version="1.0"?>
<clickhouse>
    <logger>
        <level>trace</level>
        <log>/var/log/clickhouse-server/clickhouse-server.log</log>
        <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
        <size>1000M</size>
        <count>10</count>
    </logger>

    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>

    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>

    <users_config>users.xml</users_config>
    <default_profile>default</default_profile>
    <default_database>default</default_database>

    <timezone>Asia/Shanghai</timezone>

    <remote_servers>
        <cluster_3shards_3replicas>
            <shard>
                <replica>
                    <host>node1</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>node2</host>
                    <port>9000</port>
                </replica>
                <replica>
                    <host>node3</host>
                    <port>9000</port>
                </replica>
            </shard>
        </cluster_3shards_3replicas>
    </remote_servers>

    <zookeeper>
        <node>
            <host>node1</host>
            <port>2181</port>
        </node>
        <node>
            <host>node2</host>
            <port>2181</port>
        </node>
        <node>
            <host>node3</host>
            <port>2181</port>
        </node>
    </zookeeper>

    <macros>
        <replica>node1</replica>
        <shard>1</shard>
    </macros>

    <merge_tree>
        <parts_to_delay_insert>150</parts_to_delay_insert>
        <parts_to_throw_insert>300</parts_to_throw_insert>
        <max_bytes_to_merge_at_max_space_in_pool>1000000000000</max_bytes_to_merge_at_max_space_in_pool>
    </merge_tree>

    <max_server_memory_usage>14000000000</max_server_memory_usage>
    <max_memory_usage>12000000000</max_memory_usage>
    <max_memory_usage_for_user>10000000000</max_memory_usage_for_user>

    <background_pool_size>16</background_pool_size>
    <background_schedule_pool_size>16</background_schedule_pool_size>
</clickhouse>
EOF
```

**注意：** 需要根据实际节点修改macros部分：
- Node 1: `<replica>node1</replica>`, `<shard>1</shard>`
- Node 2: `<replica>node2</replica>`, `<shard>1</shard>`
- Node 3: `<replica>node3</replica>`, `<shard>1</shard>`

#### 3.2.2 创建用户配置文件

```bash
# 在所有节点执行
sudo tee /etc/clickhouse-server/users.xml << EOF
<?xml version="1.0"?>
<clickhouse>
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
    </profiles>

    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
        
        <clickhouse_user>
            <password>your_secure_password</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </clickhouse_user>
    </users>

    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</clickhouse>
EOF
```

#### 3.2.3 创建数据目录

```bash
# 在所有节点执行
sudo mkdir -p /var/lib/clickhouse/tmp
sudo mkdir -p /var/lib/clickhouse/user_files
sudo mkdir -p /var/lib/clickhouse/format_schemas
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse
```

### 3.3 启动ClickHouse服务

```bash
# 在所有节点执行
sudo systemctl enable clickhouse-server
sudo systemctl start clickhouse-server
sudo systemctl status clickhouse-server
```

### 3.4 验证ClickHouse安装

```bash
# 测试连接
clickhouse-client --host=localhost --port=9000 --user=default --password=

# 执行测试查询
clickhouse-client --query="SELECT version()"
```

---

## 4. 集群配置和初始化

### 4.1 创建分布式数据库

```bash
# 在任意节点执行
clickhouse-client --query="CREATE DATABASE IF NOT EXISTS analytics"

# 创建分布式表
clickhouse-client --query="
CREATE TABLE analytics.events_local (
    id UUID,
    timestamp DateTime,
    user_id String,
    event_type String,
    properties JSON,
    created_at DateTime DEFAULT now()
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events_local', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, user_id)
SETTINGS index_granularity = 8192;
"

# 创建分布式表
clickhouse-client --query="
CREATE TABLE analytics.events AS analytics.events_local
ENGINE = Distributed(cluster_3shards_3replicas, analytics, events_local, rand());
"
```

### 4.2 配置副本同步

```bash
# 检查副本状态
clickhouse-client --query="SELECT * FROM system.replicas"

# 检查集群状态
clickhouse-client --query="SELECT * FROM system.clusters"
```

### 4.3 创建应用用户和权限

```bash
# 创建应用用户
clickhouse-client --query="
CREATE USER IF NOT EXISTS app_user IDENTIFIED WITH plaintext_password BY 'app_password';
GRANT ALL ON analytics.* TO app_user;
"
```

---

## 5. 负载均衡配置

### 5.1 安装Nginx

```bash
# 在负载均衡器节点执行
sudo yum install -y nginx
```

### 5.2 配置Nginx负载均衡

```bash
# 配置Nginx
sudo tee /etc/nginx/conf.d/clickhouse.conf << EOF
upstream clickhouse_backend {
    server node1:8123 max_fails=3 fail_timeout=30s;
    server node2:8123 max_fails=3 fail_timeout=30s;
    server node3:8123 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name clickhouse-cluster;

    location / {
        proxy_pass http://clickhouse_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }
}
EOF

sudo systemctl enable nginx
sudo systemctl start nginx
```

---

## 6. 监控系统部署

### 6.1 安装Prometheus

```bash
# 在监控节点执行
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvf prometheus-*.tar.gz
sudo mv prometheus-* /opt/prometheus
sudo useradd -r -s /bin/false prometheus
sudo chown -R prometheus:prometheus /opt/prometheus
```

### 6.2 配置Prometheus

```bash
sudo tee /opt/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'clickhouse'
    static_configs:
      - targets: ['node1:9181', 'node2:9181', 'node3:9181']
    metrics_path: '/metrics'
EOF

sudo systemctl enable prometheus
sudo systemctl start prometheus
```

### 6.3 安装Grafana

```bash
# 安装Grafana
sudo tee /etc/yum.repos.d/grafana.repo << EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=0
sslverify=0
EOF

sudo yum install -y grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

---

## 7. 安全配置

### 7.1 SSL/TLS配置

```bash
# 生成SSL证书
sudo mkdir -p /etc/clickhouse-server/ssl
cd /etc/clickhouse-server/ssl
sudo openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server/ssl
```

### 7.2 配置SSL

```bash
# 在config.xml中添加SSL配置
sudo tee -a /etc/clickhouse-server/config.xml << EOF
    <https_port>8443</https_port>
    <tcp_port_secure>9440</tcp_port_secure>
    
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/ssl/cert.pem</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/ssl/key.pem</privateKeyFile>
        </server>
    </openSSL>
EOF
```

---

## 8. 验证和测试

### 8.1 基础功能测试

```bash
# 测试连接
clickhouse-client --host=node1 --port=9000 --user=app_user --password=app_password

# 测试写入
clickhouse-client --query="
INSERT INTO analytics.events (id, timestamp, user_id, event_type, properties)
VALUES 
(generateUUIDv4(), now(), 'user1', 'page_view', '{\"page\": \"/home\"}'),
(generateUUIDv4(), now(), 'user2', 'click', '{\"button\": \"submit\"}');
"

# 测试查询
clickhouse-client --query="SELECT COUNT(*) FROM analytics.events"
```

### 8.2 高可用性测试

```bash
# 模拟节点故障
sudo systemctl stop clickhouse-server  # 在node2上执行

# 验证查询仍然可用
clickhouse-client --host=node1 --query="SELECT COUNT(*) FROM analytics.events"

# 恢复节点
sudo systemctl start clickhouse-server  # 在node2上执行
```

### 8.3 性能测试

```bash
# 批量插入测试
clickhouse-client --query="
INSERT INTO analytics.events (id, timestamp, user_id, event_type, properties)
SELECT 
    generateUUIDv4(),
    now() - INTERVAL rand() % 86400 SECOND,
    concat('user', toString(rand() % 1000)),
    'test_event',
    '{\"test\": true}'
FROM numbers(10000);
"

# 查询性能测试
time clickhouse-client --query="
SELECT 
    toDate(timestamp) as date,
    event_type,
    COUNT(*) as count
FROM analytics.events 
WHERE timestamp >= now() - INTERVAL 7 DAY
GROUP BY date, event_type
ORDER BY date DESC, count DESC;
"
```

---

## 故障排查

### 常见问题解决

#### 1. Keeper连接问题
```bash
# 检查Keeper状态
echo stat | nc localhost 2181

# 检查Keeper日志
sudo tail -f /var/log/clickhouse-server/clickhouse-keeper.log
```

#### 2. 副本同步问题
```bash
# 检查副本状态
clickhouse-client --query="SELECT * FROM system.replicas"

# 检查集群状态
clickhouse-client --query="SELECT * FROM system.clusters"
```

#### 3. 内存不足问题
```bash
# 检查内存使用
free -h

# 调整内存配置
sudo vim /etc/clickhouse-server/config.xml
# 修改 max_server_memory_usage 和 max_memory_usage
```

#### 4. 磁盘空间问题
```bash
# 检查磁盘使用
df -h

# 清理临时文件
sudo rm -rf /var/lib/clickhouse/tmp/*
```

---

## 维护命令

### 日常维护

```bash
# 检查服务状态
sudo systemctl status clickhouse-server
sudo systemctl status clickhouse-keeper

# 查看日志
sudo tail -f /var/log/clickhouse-server/clickhouse-server.log
sudo tail -f /var/log/clickhouse-server/clickhouse-keeper.log

# 备份数据
sudo clickhouse-backup create

# 清理日志
sudo find /var/log/clickhouse-server -name "*.log" -mtime +7 -delete
```

### 扩容操作

```bash
# 添加新节点到集群
# 1. 在新节点上重复安装步骤
# 2. 修改配置文件中的集群定义
# 3. 重新启动所有节点服务
```

---

## 总结

本手册提供了完整的ClickHouse单片多副本集群部署流程，包括：

1. **环境准备**：系统配置、网络设置
2. **Keeper部署**：集群协调服务
3. **ClickHouse部署**：主服务安装配置
4. **集群配置**：分布式表和副本设置
5. **负载均衡**：高可用访问
6. **监控系统**：运维监控
7. **安全配置**：SSL/TLS加密
8. **验证测试**：功能和高可用测试

部署完成后，您将拥有一个高可用的ClickHouse集群，支持：
- 自动故障转移
- 数据自动同步
- 读写分离
- 完整的监控体系
- 安全的数据访问

建议在生产环境中定期进行备份、监控和性能优化。 