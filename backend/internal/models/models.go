package models

import (
	"time"
)

// User 用户表
type User struct {
	ID       int    `json:"id" db:"id"`
	Username string `json:"username" db:"username"`
	Password string `json:"-" db:"password"` // 不在JSON中显示密码
}

// Node 节点表
type Node struct {
	ID       int    `json:"id" db:"id"`
	Name     string `json:"name" db:"name"`
	IP       string `json:"ip" db:"ip"`
	Status   string `json:"status" db:"status"`
	LastSeen string `json:"last_seen" db:"last_seen"`
}

// SystemMetrics 系统监控数据表
type SystemMetrics struct {
	ID          int     `json:"id" db:"id"`
	NodeID      int     `json:"node_id" db:"node_id"`
	CPUPercent  float64 `json:"cpu_percent" db:"cpu_percent"`
	MemoryTotal uint64  `json:"memory_total" db:"memory_total"`
	MemoryUsed  uint64  `json:"memory_used" db:"memory_used"`
	MemoryPercent float64 `json:"memory_percent" db:"memory_percent"`
	CPUTemp     float64 `json:"cpu_temp" db:"cpu_temp"`
	Timestamp   string  `json:"timestamp" db:"timestamp"`
}

// LoginRequest 登录请求
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// LoginResponse 登录响应
type LoginResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}

// MetricsResponse 监控数据响应
type MetricsResponse struct {
	Success bool           `json:"success"`
	Data    SystemMetrics  `json:"data,omitempty"`
	List    []SystemMetrics `json:"list,omitempty"`
	Message string         `json:"message,omitempty"`
}

// NodesResponse 节点列表响应
type NodesResponse struct {
	Success bool   `json:"success"`
	Data    []Node `json:"data,omitempty"`
	Message string `json:"message,omitempty"`
}

// APIResponse 通用API响应
type APIResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
}

// AgentMetrics Agent上报的监控数据
type AgentMetrics struct {
	NodeID        int     `json:"node_id"`
	CPUPercent    float64 `json:"cpu_percent"`
	MemoryTotal   uint64  `json:"memory_total"`
	MemoryUsed    uint64  `json:"memory_used"`
	MemoryPercent float64 `json:"memory_percent"`
	CPUTemp       float64 `json:"cpu_temp"`
	Timestamp     time.Time `json:"timestamp"`
}