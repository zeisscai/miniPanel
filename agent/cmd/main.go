package main

import (
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"miniPanel-agent/internal/client"
	"miniPanel-agent/internal/collector"
	"miniPanel-agent/internal/config"
)

func main() {
	// 命令行参数
	configPath := flag.String("config", "/etc/miniPanel/agent.json", "配置文件路径")
	flag.Parse()

	// 加载配置
	var cfg *config.Config

	if _, err := os.Stat(*configPath); os.IsNotExist(err) {
		// 配置文件不存在，使用默认配置
		log.Printf("配置文件 %s 不存在，使用默认配置", *configPath)
		cfg = config.DefaultConfig()
	} else {
		// 加载配置文件
		cfg, err = config.LoadConfig(*configPath)
		if err != nil {
			log.Fatalf("加载配置文件失败: %v", err)
		}
	}

	log.Printf("MiniPanel Agent 启动")
	log.Printf("节点名称: %s", cfg.Agent.NodeName)
	log.Printf("服务器地址: %s", cfg.Server.URL)
	log.Printf("采集间隔: %d秒", cfg.Agent.Interval)

	// 创建数据采集器
	collectorInstance := collector.NewCollector(
		cfg.Collector.CPU,
		cfg.Collector.Memory,
		cfg.Collector.Temp,
	)

	// 创建HTTP客户端
	clientInstance := client.NewClient(cfg.Server.URL, cfg.Agent.NodeName)

	// 测试连接
	log.Printf("测试服务器连接...")
	if err := clientInstance.TestConnection(); err != nil {
		log.Printf("警告: 无法连接到服务器: %v", err)
		log.Printf("Agent将继续运行，稍后重试连接")
	} else {
		log.Printf("服务器连接正常")
	}

	// 创建定时器
	ticker := time.NewTicker(time.Duration(cfg.Agent.Interval) * time.Second)
	defer ticker.Stop()

	// 监听系统信号
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// 立即执行一次数据采集
	collectAndSend(collectorInstance, clientInstance)

	// 主循环
	for {
		select {
		case <-ticker.C:
			// 定时采集和发送数据
			collectAndSend(collectorInstance, clientInstance)

		case sig := <-sigChan:
			log.Printf("收到信号 %v，正在关闭Agent...", sig)
			return
		}
	}
}

// collectAndSend 采集数据并发送到服务器
func collectAndSend(collector *collector.Collector, client *client.Client) {
	// 采集监控数据
	metrics, err := collector.CollectMetrics()
	if err != nil {
		log.Printf("数据采集失败: %v", err)
		return
	}

	log.Printf("采集数据 - CPU: %.2f%%, 内存: %.2f%% (%.2fGB/%.2fGB), CPU温度: %.1f°C",
		metrics.CPUPercent,
		metrics.MemoryPercent,
		float64(metrics.MemoryUsed)/1024/1024/1024,
		float64(metrics.MemoryTotal)/1024/1024/1024,
		metrics.CPUTemp)

	// 发送数据到服务器
	err = client.SendMetrics(metrics)
	if err != nil {
		log.Printf("数据发送失败: %v", err)
		return
	}

	log.Printf("数据发送成功")
}