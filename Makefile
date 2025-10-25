.PHONY: run build clean test create-topic up down restart status logs help

# 配置 Go 代理（加速依赖下载）
GOPROXY ?= https://goproxy.cn,direct
export GOPROXY

# 帮助信息
help:
	@echo "📚 Stress Test Kafka - Available Commands:"
	@echo ""
	@echo "🚀 Docker Compose 管理:"
	@echo "  make up           - 启动 Kafka 集群"
	@echo "  make down         - 停止 Kafka 集群"
	@echo "  make down-clean   - 停止并删除数据"
	@echo "  make restart      - 重启 Kafka 集群"
	@echo "  make status       - 查看集群状态"
	@echo "  make logs         - 查看所有日志"
	@echo "  make logs-kafka   - 查看 Kafka 日志"
	@echo "  make logs-ui      - 查看 UI 日志"
	@echo ""
	@echo "🧪 测试工具:"
	@echo "  make create-topic - 创建测试 topic"
	@echo "  make quick-test   - 快速测试 (1万条)"
	@echo "  make run          - 完整测试 (1亿条)"
	@echo "  make test         - 运行快速测试流程"
	@echo "  make test-full    - 运行完整压力测试"
	@echo "  make all          - 完整工作流程"
	@echo ""
	@echo "📦 其他命令:"
	@echo "  make deps         - 安装 Go 依赖"
	@echo "  make clean        - 清理编译产物"
	@echo "  make clean-all    - 完全清理(包括Docker)"
	@echo ""

# ==================== Docker Compose 管理 ====================

# 启动 Kafka 集群
up:
	@echo "🚀 Starting Kafka cluster..."
	docker-compose up -d
	@echo "✅ Kafka cluster started"
	@echo "📊 Kafka UI: http://localhost:8080"
	@echo ""
	@echo "Waiting for Kafka to be ready..."
	@sleep 3
	@docker-compose ps

# 停止 Kafka 集群
down:
	@echo "🛑 Stopping Kafka cluster..."
	docker-compose down

# 停止并删除数据卷
down-clean:
	@echo "🛑 Stopping Kafka cluster and removing data..."
	docker-compose down -v

# 重启 Kafka 集群
restart:
	@echo "🔄 Restarting Kafka cluster..."
	docker-compose restart

# 查看集群状态
status:
	@echo "📊 Kafka cluster status:"
	docker-compose ps

# 查看日志
logs:
	docker-compose logs -f

# 查看特定服务的日志
logs-kafka:
	@echo "📋 Kafka logs:"
	docker-compose logs -f kafka-controller-1

logs-ui:
	@echo "📋 Kafka UI logs:"
	docker-compose logs -f kafka-ui

# ==================== Go 测试工具 ====================

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

# 运行完整测试（1 亿条 - 目标 3 分钟）
run: build
	@echo "🚀 Running fast stress test (100 million messages)..."
	@echo "⚠️  1,000 goroutines, Target: 3 minutes!"
	@echo "Press Ctrl+C to cancel or wait 2 seconds to continue..."
	@sleep 2
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

# ==================== 清理命令 ====================

# 清理编译产物
clean:
	@echo "🧹 Cleaning up build artifacts..."
	rm -rf bin/
	go clean

# 完全清理（包括 Docker 和数据）
clean-all: down-clean
	@echo "🧹 Cleaning up build artifacts..."
	rm -rf bin/
	go clean
	@echo "✅ All cleaned!"

# ==================== 完整测试流程 ====================

# 快速测试流程
test: create-topic quick-test
	@echo "✅ Quick test completed!"

# 完整压力测试流程（1 亿条消息）
test-full: create-topic run
	@echo "✅ Full stress test completed!"

# 完整工作流程：启动集群 -> 测试 -> 清理
all: up create-topic quick-test
	@echo ""
	@echo "✅ Complete workflow done!"
	@echo "📊 Kafka UI: http://localhost:8080"
