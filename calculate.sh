#!/bin/bash
# 计算 1 亿条消息的存储和网络需求

messages=100000000
avg_msg_size=150  # 平均每条消息 150 字节

# 总数据量
total_bytes=$((messages * avg_msg_size))
total_mb=$((total_bytes / 1024 / 1024))
total_gb=$((total_mb / 1024))

echo "📊 1 亿条消息资源需求估算："
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "总消息数: $messages"
echo "平均消息大小: ${avg_msg_size} 字节"
echo "总数据量: ${total_mb} MB (${total_gb} GB)"
echo ""
echo "考虑 Kafka 副本因子=3："
echo "实际存储: $((total_gb * 3)) GB"
echo ""
echo "预计发送时间（按 20 万 msg/s）："
minutes=$(echo "scale=1; $messages / 200000 / 60" | bc)
echo "$minutes 分钟"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
