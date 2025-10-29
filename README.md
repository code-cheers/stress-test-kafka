# stress-test-kafka

Kafka 集群压力测试项目

## 集群配置

本项目使用 KRaft 模式的 Kafka 集群

- **Kafka Brokers**: 3个节点
  - kafka-controller-1: 端口 19092
  - kafka-controller-2: 端口 19094
  - kafka-controller-3: 端口 19096
- **Kafka UI**: 可视化管理界面，端口 8080

## 重要配置说明

### KAFKA_CLUSTER_ID
- **作用**: KRaft 模式下集群的唯一标识符（类似于 Zookeeper 的集群 ID）
- **要求**: 集群内所有节点必须使用**相同的 CLUSTER_ID**
- **格式**: UUID（例如：`M8dH9ZLUTLi8K3bH5kPnYg`）
- **注意**: 首次启动后会写入元数据，之后**不能更改**，否则会导致集群无法启动

### KRaft 模式优势

- ✅ **无需 Zookeeper**：减少外部依赖
- ✅ **启动更快**：集群启动速度提升
- ✅ **延迟更低**：减少网络往返
- ✅ **可扩展性更强**：支持百万级分区
- ✅ **运维简单**：只需维护 Kafka 一个系统

## 快速开始

### 查看所有命令

```bash
make help
```

### Docker 集群管理

```bash
# 启动 Kafka 集群
make up

# 查看集群状态
make status

# 查看日志
make logs

# 停止集群
make down

# 停止并删除数据
make down-clean

# 重启集群
make restart
```

### 压力测试

#### 完整工作流程（推荐）

```bash
# 一键完成：启动集群 -> 创建 topic -> 快速测试
make all
```

#### 分步执行

```bash
# 1. 启动集群
make up

# 2. 创建测试 topic
make create-topic

# 3. 快速测试（1 万条）
make quick-test

# 4. 完整测试（10 亿条，约 1.5 小时）
make run

# 5. 查看 topic 信息
make describe-topic

# 6. 消费消息验证
make consume

# ⚠️  注意：完整测试配置
# - 消息总数：10 亿条
# - 并发数：5000 个 goroutine
# - 每个 goroutine：20 万条消息
# - 预计存储空间需求：约 417 GB（含 3 个副本）
# - 预计发送时间：约 80-90 分钟
# - 预计吞吐量：约 20 万 msg/s
```

## 常用操作

### 查看日志

```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f kafka-controller-1
```

### 清理数据

```bash
docker-compose down -v
```

## 访问 Kafka UI

启动集群后，访问 http://localhost:8080 可以查看 Kafka 集群的详细信息。

## 连接到 Kafka

### 生产者示例

**在容器内使用服务名（推荐）：**
```bash
docker exec -it kafka-controller-1 /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka-controller-1:9092 --topic test-topic
```

**从宿主机连接：**
```bash
docker exec -i kafka-controller-1 /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:19092 --topic test-topic
```

### 消费者示例

**在容器内使用服务名（推荐）：**
```bash
docker exec -it kafka-controller-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka-controller-1:9092 --topic test-topic --from-beginning
```

**从宿主机连接：**
```bash
docker exec kafka-controller-1 /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:19092 --topic test-topic --from-beginning
```

## 创建 Topic

```bash
docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server kafka-controller-1:9092 --replication-factor 3 --partitions 3 --topic test-topic
```

## 列出所有 Topic

```bash
docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka-controller-1:9092
```

## 查看 Topic 详情

```bash
docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh --describe --bootstrap-server kafka-controller-1:9092 --topic test-topic
```

## 压力测试工具

本项目包含一个 Go 语言编写的 Kafka 压力测试工具。

### 环境配置

**本地电脑永久配置（推荐）：**

**项目级别配置：**

- Makefile 中已自动配置 GOPROXY
- 如果使用 direnv：`direnv allow` 自动加载 `.envrc` 配置

### 快速开始

#### 快速测试（推荐先运行）

```bash
# 1. 创建测试 topic
make create-topic

# 2. 快速测试（1 万条消息，约 1 秒）
make quick-test

# 3. 查看 topic 信息
make describe-topic

# 4. 消费消息验证
make consume
```

#### 完整压力测试（1 亿条消息）

```bash
# 1. 创建测试 topic
make create-topic

# 2. 运行完整压力测试（1 亿条消息，约 8 分钟）
make run

# ⚠️  注意：完整测试会发送 1 亿条消息
# 预计存储空间需求：约 42 GB（含 3 个副本）
# 预计发送时间：约 8-10 分钟
# 预计吞吐量：约 20 万 msg/s
```

### 测试配置

在 `main.go` 中可以调整以下参数：
- `numGoroutines`: 并发 goroutine 数量
- `msgsPerWorker`: 每个 goroutine 发送的消息数
- `broker`: Kafka broker 地址
- `topic`: 测试 topic 名称

### 功能特性

- ✅ 并发消息发送（多个 goroutine）
- ✅ 消息压缩（Snappy）
- ✅ 完整的 ACK 确认（WaitForAll）
- ✅ 错误重试机制
- ✅ 详细的性能统计
- ✅ 消息包含 key、value 和 headers

## 磁盘性能测试

本项目包含磁盘性能测试功能，使用 fio 测试磁盘的顺序写入和随机写入性能。

### 安装 fio

**macOS:**
```bash
brew install fio
```

**Ubuntu/Debian:**
```bash
apt-get install fio
```

**CentOS/RHEL:**
```bash
yum install fio
```

### 运行磁盘测试

```bash
# 完整磁盘性能测试（顺序+随机写入）
make disk-test

# 对比分析测试结果
make disk-compare
```

### 测试配置

**顺序写入测试:**
- 数据大小: 1GB
- 块大小: 1MB
- 测试时长: 30秒
- 并发数: 1个线程

**随机写入测试:**
- 数据大小: 1GB
- 块大小: 4KB
- 测试时长: 30秒
- 并发数: 4个线程

### 测试结果

测试结果会保存到以下文件：
- `fio-write.txt` - 顺序写入测试结果
- `fio-randwrite.txt` - 随机写入测试结果

**实际测试结果对比：**

| 指标 | 顺序写入 | 随机写入 | 对比 |
|------|----------|----------|------|
| 带宽 | 3234 MiB/s | 68.0 MiB/s | 47.5倍 |
| IOPS | 3234 | ~4350 | 1.3倍 |
| 延迟 | 294.72 μs | ~230 μs | 1.2倍 |
| 块大小 | 1MB | 4KB | - |
| 并发数 | 1 | 4 | - |

**分析结论：**
- ✅ **顺序写入**: 高带宽，适合大文件传输和流式处理
- ✅ **随机写入**: 高IOPS，适合数据库等随机访问场景
- 📝 这是典型的磁盘特性：顺序访问性能远高于随机访问

### 手动执行 fio 命令

```bash
# 顺序写入测试
fio --name=write-test --size=1G --bs=1M --rw=write --direct=1 --numjobs=1 --runtime=30 --time_based --output=fio-write.txt

# 随机写入测试
fio --name=random-write --size=1G --bs=4k --rw=randwrite --direct=1 --numjobs=4 --runtime=30 --output=fio-randwrite.txt
```

