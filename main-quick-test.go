package main

import (
	"fmt"
	"log"
	"sync/atomic"
	"time"

	"github.com/IBM/sarama"
)

const (
	broker         = "localhost:19092"
	topic          = "stress-test-topic"
	numGoroutines  = 10
	msgsPerWorker  = 1_000 // 快速测试：1 万条
	totalMessages  = numGoroutines * msgsPerWorker
)

func main() {
	fmt.Println("🚀 Quick Test - 10,000 messages")
	
	config := sarama.NewConfig()
	config.Producer.Return.Successes = false
	config.Producer.Return.Errors = true
	config.Producer.Retry.Max = 5
	config.Producer.RequiredAcks = 1
	config.Producer.Compression = sarama.CompressionSnappy
	config.Producer.Flush.Messages = 1000
	config.Producer.Flush.Frequency = 100 * time.Millisecond

	producer, err := sarama.NewAsyncProducer([]string{broker}, config)
	if err != nil {
		log.Fatalf("❌ Failed: %v", err)
	}
	defer producer.Close()

	fmt.Println("✅ Producer ready, sending...")
	
	var successCount int64
	var errorCount int64
	startTime := time.Now()

	go func() {
		for err := range producer.Errors() {
			atomic.AddInt64(&errorCount, 1)
			if atomic.LoadInt64(&errorCount) <= 3 {
				fmt.Printf("❌ Error: %v\n", err)
			}
		}
	}()

	for i := 0; i < numGoroutines; i++ {
		go func(workerID int) {
			for j := 0; j < msgsPerWorker; j++ {
				msg := &sarama.ProducerMessage{
					Topic: topic,
					Key:   sarama.StringEncoder(fmt.Sprintf("key-%d-%d", workerID, j)),
					Value: sarama.StringEncoder(fmt.Sprintf("Worker-%d-Message-%d", workerID, j)),
				}
				producer.Input() <- msg
				atomic.AddInt64(&successCount, 1)
			}
		}(i)
	}

	expectedTotal := int64(totalMessages)
	for atomic.LoadInt64(&successCount)+atomic.LoadInt64(&errorCount) < expectedTotal {
		time.Sleep(50 * time.Millisecond)
	}

	duration := time.Since(startTime)
	fmt.Printf("\n✅ Completed: %d messages in %v (%.0f msg/s)\n", 
		atomic.LoadInt64(&successCount), duration, float64(atomic.LoadInt64(&successCount))/duration.Seconds())
}
