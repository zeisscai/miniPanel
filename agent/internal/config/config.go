package config

import (
	"encoding/json"
	"os"
)

type Config struct {
	Server   ServerConfig   `json:"server"`
	Agent    AgentConfig    `json:"agent"`
	Collector CollectorConfig `json:"collector"`
}

type ServerConfig struct {
	URL string `json:"url"`
}

type AgentConfig struct {
	NodeName string `json:"node_name"`
	Interval int    `json:"interval"` // 数据采集间隔（秒）
}

type CollectorConfig struct {
	CPU    bool `json:"cpu"`
	Memory bool `json:"memory"`
	Temp   bool `json:"temp"`
}

func LoadConfig(configPath string) (*Config, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, err
	}

	var config Config
	err = json.Unmarshal(data, &config)
	if err != nil {
		return nil, err
	}

	return &config, nil
}

func DefaultConfig() *Config {
	return &Config{
		Server: ServerConfig{
			URL: "http://localhost:8080/api/metrics",
		},
		Agent: AgentConfig{
			NodeName: "default-node",
			Interval: 30,
		},
		Collector: CollectorConfig{
			CPU:    true,
			Memory: true,
			Temp:   true,
		},
	}
}