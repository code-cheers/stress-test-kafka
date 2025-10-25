package main

import (
	"fmt"
	"log"
	"sync/atomic"
	"time"

	"github.com/IBM/sarama"
)

const (
	// Kafka broker 地址
	broker = "localhost:19092"
	topic  = "stress-test-topic"

	// 测试参数 - 1 亿条消息
	numGoroutines = 100   // 并发 goroutine 数量（增加并发）
	msgsPerWorker = 1_000_000 // 每个 goroutine 发送 100 万条消息
	totalMessages = numGoroutines * msgsPerWorker // 1 亿条消息
)

func main() {
	fmt.Println("🚀 Kafka 100 Million Messages Stress Test Started")
	fmt.Printf("Configuration:\n")
	fmt.Printf("  - Broker: %s\n", broker)
	fmt.Printf("  - Topic: %s\n", topic)
	fmt.Printf("  - Goroutines: %d\n", numGoroutines)
	fmt.Printf("  - Messages per goroutine: %d\n", msgsPerWorker)
	fmt.Printf("  - Total messages: %d (%.2f million)\n", totalMessages, float64(totalMessages)/1e6)
	fmt.Println()

	// 配置 Kafka producer - 使用异步 producer 提高性能
	config := sarama.NewConfig()
	config.Producer.Return.Successes = false // 关闭 success channel 提高性能
	config.Producer.Return.Errors = true
	config.Producer.Retry.Max = 5
	config.Producer.RequiredAcks = 1 // 使用 1 提高吞吐量（leader 确认即可）
	config.Producer.Compression = sarama.CompressionSnappy
	
	// 批量发送配置
	config.Producer.Flush.Messages = 1000      // 每批 1000 条
	config.Producer.Flush.Frequency = 100 * time.Millisecond // 每 100ms 刷新一次
	config.Producer.MaxMessageBytes = 1000000  // 1MB

	// 创建 producer
	producer, err := sarama.NewAsyncProducer([]string{broker}, config)
	if err != nil {
		log.Fatalf("❌ Failed to create producer: %v", err)
	}
	defer producer.Close()

	fmt.Println("✅ Async Producer created successfully")
	fmt.Println("📊 Starting to send messages...")
	
	var successCount int64
	var errorCount int64
	startTime := time.Now()
	lastReportTime := startTime

	// 错误处理 goroutine
	go func() {
		for err := range producer.Errors() {
			atomic.AddInt64(&errorCount, 1)
			if atomic.LoadInt64(&errorCount) <= 5 { // 只打印前 5 个错误
				fmt.Printf("❌ Error: %v\n", err)
			}
		}
	}()

	// 启动多个 goroutine 并发发送消息
	for i := 0; i < numGoroutines; i++ {
		go func(workerID int) {
			for j := 0; j < msgsPerWorker; j++ {
				message := fmt.Sprintf("Worker-%d-Message-%d-Timestamp-%d", 
					workerID, j, time.Now().UnixNano())

				msg := &sarama.ProducerMessage{
					Topic: topic,
					Key:   sarama.StringEncoder(fmt.Sprintf("key-%d-%d", workerID, j)),
					Value: sarama.StringEncoder(message),
					Headers: []sarama.RecordHeader{
						{
							Key:   []byte("worker-id"),
							Value: []byte(fmt.Sprintf("%d", workerID)),
						},
					},
				}

				// 异步发送消息
				producer.Input() <- msg
				atomic.AddInt64(&successCount, 1)

				// 每 50 万条消息报告一次进度
				total := atomic.LoadInt64(&successCount) + atomic.LoadInt64(&errorCount)
				if total%500_000 == 0 {
					now := time.Now()
					elapsed := now.Sub(startTime)
					duration := now.Sub(lastReportTime)
					rate := float64(500_000) / duration.Seconds()
					
					fmt.Printf("📊 Progress: %d/%d messages (%.2f%%) | Rate: %.0f msg/s | Elapsed: %v\n",
						total, totalMessages, float64(total)/float64(totalMessages)*100, rate, elapsed)
					lastReportTime = now
				}
			}
		}(i)
	}

	// 等待所有消息发送完成
	expectedTotal := int64(totalMessages)
	for atomic.LoadInt64(&successCount)+atomic.LoadInt64(&errorCount) < expectedTotal {
		time.Sleep(100 * time.Millisecond)
	}

	duration := time.Since(startTime)

	// 输出统计信息
	fmt.Println()
	fmt.Println("============================================================")
	fmt.Println("📊 Stress Test Results")
	fmt.Println("============================================================")
	fmt.Printf("Total messages sent: %d\n", atomic.LoadInt64(&successCount)+atomic.LoadInt64(&errorCount))
	fmt.Printf("Success: %d\n", atomic.LoadInt64(&successCount))
	fmt.Printf("Errors: %d\n", atomic.LoadInt64(&errorCount))
	fmt.Printf("Success rate: %.2f%%\n", 
		float64(atomic.LoadInt64(&successCount))/float64(totalMessages)*100)
	fmt.Printf("Duration: %v\n", duration)
	fmt.Printf("Throughput: %.0f messages/second\n", 
		float64(atomic.LoadInt64(&successCount))/duration.Seconds())
	fmt.Printf("Average latency: %.2f ms/message\n",
		duration.Seconds()*1000/float64(atomic.LoadInt64(&successCount)))
	fmt.Println("============================================================")

	if atomic.LoadInt64(&errorCount) > 0 {
		fmt.Println("⚠️  Some messages failed to send")
	} else {
		fmt.Println("🎉 All messages sent successfully!")
	}
}
