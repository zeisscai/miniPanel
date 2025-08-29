package client

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"miniPanel-agent/internal/collector"
)

// Client HTTP客户端
type Client struct {
	serverURL string
	nodeName  string
	httpClient *http.Client
}

// NewClient 创建新的HTTP客户端
func NewClient(serverURL, nodeName string) *Client {
	return &Client{
		serverURL: serverURL,
		nodeName:  nodeName,
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// SendMetrics 发送监控数据到服务器
func (c *Client) SendMetrics(metrics *collector.MetricsData) error {
	// 将数据转换为JSON
	jsonData, err := json.Marshal(metrics)
	if err != nil {
		return fmt.Errorf("failed to marshal metrics: %v", err)
	}

	// 创建HTTP请求
	req, err := http.NewRequest("POST", c.serverURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}

	// 设置请求头
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Node-Name", c.nodeName)
	req.Header.Set("User-Agent", "MiniPanel-Agent/1.0")

	// 发送请求
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	// 检查响应状态
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("server returned status: %d", resp.StatusCode)
	}

	return nil
}

// TestConnection 测试与服务器的连接
func (c *Client) TestConnection() error {
	// 创建一个简单的GET请求来测试连接
	req, err := http.NewRequest("GET", c.serverURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create test request: %v", err)
	}

	req.Header.Set("User-Agent", "MiniPanel-Agent/1.0")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to connect to server: %v", err)
	}
	defer resp.Body.Close()

	return nil
}