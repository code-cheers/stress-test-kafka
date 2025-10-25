.PHONY: run build clean test create-topic

# 配置 Go 代理（加速依赖下载）
GOPROXY ?= https://goproxy.cn,direct
export GOPROXY

# 安装依赖
deps:
	@echo "📦 Installing dependencies..."
	@echo "Using GOPROXY=$(GOPROXY)"
	go mod download
	go mod tidy

# 构建完整版本
build: deps
	@echo "🔨 Building full version..."
	go build -o bin/stress-test main.go

# 构建快速测试版本
build-quick:
	@echo "🔨 Building quick test version..."
	go build -o bin/quick-test main-quick-test.go

# 快速测试（1 万条）
quick-test: build-quick
	@echo "🚀 Running quick test (10K messages)..."
	./bin/quick-test

# 运行完整测试（1 亿条 - 约 8 分钟）
run: build
	@echo "🚀 Running full stress test (100 million messages)..."
	@echo "⚠️  This will take approximately 8-10 minutes!"
	@echo "Press Ctrl+C to cancel or wait 3 seconds to continue..."
	@sleep 3
	./bin/stress-test

# 创建测试 topic
create-topic:
	@echo "📝 Creating topic..."
	docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh \
		--create \
		--bootstrap-server kafka-controller-1:9092 \
		--topic stress-test-topic \
		--partitions 3 \
		--replication-factor 3 \
		--if-not-exists

# 查看 topic 信息
describe-topic:
	@echo "📊 Topic information:"
	docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh \
		--describe \
		--bootstrap-server kafka-controller-1:9092 \
		--topic stress-test-topic

# 消费消息
consume:
	@echo "📥 Consuming messages from stress-test-topic:"
	docker exec kafka-controller-1 /opt/kafka/bin/kafka-console-consumer.sh \
		--bootstrap-server kafka-controller-1:9092 \
		--topic stress-test-topic \
		--from-beginning

# 查看所有 topics
list-topics:
	docker exec kafka-controller-1 /opt/kafka/bin/kafka-topics.sh \
		--list \
		--bootstrap-server kafka-controller-1:9092

# 清理
clean:
	@echo "🧹 Cleaning up..."
	rm -rf bin/
	go clean

# 快速测试流程
test: create-topic quick-test
	@echo "✅ Quick test completed!"

# 完整压力测试流程（10 亿条消息）
test-full: create-topic run
	@echo "✅ Full stress test completed!"
