package config

import (
	"encoding/json"
	"os"
)

type Config struct {
	Server   ServerConfig   `json:"server"`
	Database DatabaseConfig `json:"database"`
	Auth     AuthConfig     `json:"auth"`
}

type ServerConfig struct {
	Port string `json:"port"`
	Host string `json:"host"`
}

type DatabaseConfig struct {
	Path string `json:"path"`
}

type AuthConfig struct {
	JWTSecret string `json:"jwt_secret"`
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
			Port: "8080",
			Host: "0.0.0.0",
		},
		Database: DatabaseConfig{
			Path: "./miniPanel.db",
		},
		Auth: AuthConfig{
			JWTSecret: "miniPanel_secret_key_change_in_production",
		},
	}
}