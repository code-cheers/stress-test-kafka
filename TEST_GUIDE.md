# 1 亿条消息压力测试指南

## 📋 测试配置

- **并发数**: 100 个 goroutine
- **消息总数**: 1 亿条
- **每个 goroutine**: 100 万条消息
- **压缩**: Snappy
- **ACK 级别**: 1（leader 确认即可）

## 🚀 快速开始

### 1️⃣ 快速测试（推荐先运行）
```bash
make quick-test  # 1 万条消息，约 1 秒
```

### 2️⃣ 完整压力测试
```bash
make run  # 1 亿条消息，约 8 分钟
```

## 📊 资源需求

- **存储空间**: 约 42 GB（3 个副本）
- **预计时间**: 约 8-10 分钟
- **吞吐量**: 约 20 万 msg/s
- **内存**: 建议至少 8 GB

## ⚙️ 优化选项

如需调整配置，编辑 `main.go`：

```go
const (
    numGoroutines = 100       // 调整并发数
    msgsPerWorker = 1_000_000 // 调整每 worker 消息数
)
```

## 📈 监控建议

在另一个终端监控 Kafka：

```bash
# 查看 topic 详情
make describe-topic

# 查看集群状态
docker-compose logs -f kafka-controller-1

# 查看 Kafka UI
open http://localhost:8080
```

## 🎯 预期结果

- **吞吐量**: 15-25 万 msg/s
- **成功率**: >99.9%
- **平均延迟**: <5ms
- **总耗时**: 约 8-10 分钟
