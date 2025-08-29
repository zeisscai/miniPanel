package collector

import (
	"fmt"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
)

// MetricsData 监控数据结构
type MetricsData struct {
	CPUPercent    float64   `json:"cpu_percent"`
	MemoryTotal   uint64    `json:"memory_total"`
	MemoryUsed    uint64    `json:"memory_used"`
	MemoryPercent float64   `json:"memory_percent"`
	CPUTemp       float64   `json:"cpu_temp"`
	Timestamp     time.Time `json:"timestamp"`
}

// Collector 数据采集器
type Collector struct {
	enableCPU    bool
	enableMemory bool
	enableTemp   bool
}

// NewCollector 创建新的采集器
func NewCollector(enableCPU, enableMemory, enableTemp bool) *Collector {
	return &Collector{
		enableCPU:    enableCPU,
		enableMemory: enableMemory,
		enableTemp:   enableTemp,
	}
}

// CollectMetrics 采集系统监控数据
func (c *Collector) CollectMetrics() (*MetricsData, error) {
	metrics := &MetricsData{
		Timestamp: time.Now(),
	}

	// 采集CPU使用率
	if c.enableCPU {
		cpuPercents, err := cpu.Percent(time.Second, false)
		if err != nil {
			return nil, fmt.Errorf("failed to get CPU usage: %v", err)
		}
		if len(cpuPercents) > 0 {
			metrics.CPUPercent = cpuPercents[0]
		}
	}

	// 采集内存使用情况
	if c.enableMemory {
		memInfo, err := mem.VirtualMemory()
		if err != nil {
			return nil, fmt.Errorf("failed to get memory info: %v", err)
		}
		metrics.MemoryTotal = memInfo.Total
		metrics.MemoryUsed = memInfo.Used
		metrics.MemoryPercent = memInfo.UsedPercent
	}

	// 采集CPU温度
	if c.enableTemp {
		temp, err := c.getCPUTemperature()
		if err != nil {
			// 温度采集失败不影响其他数据，设置为0
			metrics.CPUTemp = 0
		} else {
			metrics.CPUTemp = temp
		}
	}

	return metrics, nil
}

// getCPUTemperature 获取CPU温度
func (c *Collector) getCPUTemperature() (float64, error) {
	// 尝试从host.SensorsTemperatures获取温度信息
	temps, err := host.SensorsTemperatures()
	if err != nil {
		return 0, err
	}

	// 查找CPU相关的温度传感器
	for _, temp := range temps {
		// 常见的CPU温度传感器名称
		if temp.SensorKey == "coretemp_core0_input" ||
			temp.SensorKey == "cpu_thermal_thermal_zone0" ||
			temp.SensorKey == "k10temp_tctl" ||
			temp.SensorKey == "cpu_thermal" {
			return temp.Temperature, nil
		}
	}

	// 如果没有找到特定的CPU温度传感器，返回第一个温度值
	if len(temps) > 0 {
		return temps[0].Temperature, nil
	}

	return 0, fmt.Errorf("no temperature sensors found")
}