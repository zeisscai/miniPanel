# 项目名称：MiniPanel
## 项目架构
后端：go 1.25
前端：vue3 + vite6 node.js 22.14.0
数据库：sqlite3

## 项目核心需求
用户环境：REHL系 Linux系统，用户有root权限，在集群中节点之间采用munge认证。集群没有上级路由器做DHCP。通过hosts文件中的信息连接。
minipanel功能：
简单的用户认证：
1.实时监控：CPU占用率，内存占用率，CPU温度情况。
2.历史查询：CPU占用率，内存占用率，温度情况。
数据库采用sqlite3存储。
计算节点采用agent程序进行监控并上报数据。

--- 下面是技术细节 ---

## go模块
shirou/gopsutil 系统监控模块
github.com/mattn/go-sqlite3 sqlite3驱动
github.com/gin-gonic/gin Web框架
github.com/golang-jwt/jwt/v5 JWT认证
github.com/BurntSushi/toml 配置文件解析
golang.org/x/crypto/bcrypt 密码加密

## 安装
给出一个sh脚本，引导用户首次使用的设置。
包括，设置网页管理帐号密码（默认帐号miniadmin，密码随机生成8位）
获取节点信息：通过读取hosts文件，获取节点信息。根据读到的信息（ip地址+主机名），用户选择直接使用，或者添加节点（用户输入ip地址+主机名），或者删除节点。
用户设置数据库位置，默认存储在/var/lib/minipanel/data.db
创建一个配置文件，文件格式用toml，用于存储用户名和密码，密码加密；数据库位置；节点信息。
创建一个数据库文件。数据库文件格式用sqlite3。
创建systemctl服务。

### 配置文件结构 (config.toml)
```toml
[server]
port = 8080
host = "0.0.0.0"
jwt_secret = "随机生成的密钥"

[admin]
username = "miniadmin"
password_hash = "bcrypt加密后的密码"

[database]
path = "/var/lib/minipanel/data.db"

[[nodes]]
name = "本地节点"
ip = "127.0.0.1"
hostname = "localhost"
enabled = true
```

## 网页页面
1. 登录页面
2. 实时信息页面
实时信息：CPU整体占用率，内存占用情况（GB），CPU温度。实时信息刷新率为5秒。
3. 历史信息页面
和实时信息一样的数据，但每5分钟记录一次。提供1天，7天，1个月的选项。

记录的时间根据系统时间计算。5秒刷新按系统时间的秒钟5的倍数计算，5分钟记录按系统时间的分钟5的倍数计算。

## 数据库设计

### 用户表 (users)
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 节点表 (nodes)
```sql
CREATE TABLE nodes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL,
    ip VARCHAR(45) NOT NULL,
    hostname VARCHAR(255),
    enabled BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### 系统监控数据表 (system_metrics)
```sql
CREATE TABLE system_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    node_id INTEGER NOT NULL,
    timestamp DATETIME NOT NULL,
    cpu_percent REAL,
    memory_total BIGINT,
    memory_used BIGINT,
    memory_percent REAL,
    cpu_temp REAL,
    FOREIGN KEY (node_id) REFERENCES nodes(id)
);

CREATE INDEX idx_system_metrics_timestamp ON system_metrics(timestamp);
CREATE INDEX idx_system_metrics_node_timestamp ON system_metrics(node_id, timestamp);
```

## API接口设计

### 认证接口
- POST /api/auth/login - 用户登录

### 系统监控接口
- GET /api/metrics/realtime/:nodeId - 获取实时系统信息
- GET /api/metrics/history/:nodeId - 获取历史系统信息
  - 查询参数: period (1d/7d/1m)

### 节点管理接口
- GET /api/nodes - 获取所有节点

## 系统架构

### 后端架构
```
├── main.go                 # 程序入口
├── config/                 # 配置管理
│   └── config.go
├── models/                 # 数据模型
│   ├── node.go
│   └── metrics.go
├── handlers/               # HTTP处理器
│   ├── auth.go
│   ├── metrics.go
│   └── nodes.go
├── services/               # 业务逻辑
│   └── metrics_service.go
└── database/               # 数据库操作
    ├── connection.go
    └── queries.go
```

### 前端架构
```
src/
├── main.js                 # 入口文件
├── App.vue                 # 根组件
├── router/                 # 路由配置
│   └── index.js
├── views/                  # 页面组件
│   ├── Login.vue
│   ├── Realtime.vue
│   └── History.vue
├── components/             # 通用组件
│   └── MetricsChart.vue
├── api/                    # API调用
│   └── api.js
└── assets/                 # 静态资源
    └── styles/
```

## 安全机制
- 使用JWT Token进行身份认证
- 密码使用bcrypt加密存储

## Agent架构设计

### Agent核心模块

#### 1. 数据采集模块
```go
type MetricsCollector struct {
    interval    time.Duration
}

// 采集CPU、内存、温度信息
func (m *MetricsCollector) Collect() (*SystemMetrics, error) {
    // 使用gopsutil采集系统信息
}
```

#### 2. 通信模块
```go
type AgentClient struct {
    serverURL   string
    nodeID      string
    httpClient  *http.Client
}

type MetricsData struct {
    NodeID    string  `json:"node_id"`
    Timestamp int64   `json:"timestamp"`
    CPUPercent float64 `json:"cpu_percent"`
    MemoryTotal uint64 `json:"memory_total"`
    MemoryUsed  uint64 `json:"memory_used"`
    CPUTemp     float64 `json:"cpu_temp"`
}
```

#### 3. 配置管理模块
```go
type AgentConfig struct {
    ServerURL string `toml:"server_url"`
    NodeID    string `toml:"node_id"`
    Interval  int    `toml:"interval"`
}
```

### 通信协议设计

#### 数据上报协议
```json
// 指标数据上报
{
    "node_id": "node_001",
    "timestamp": 1640995200,
    "cpu_percent": 45.2,
    "memory_total": 16777216000,
    "memory_used": 8388608000,
    "cpu_temp": 65.5
}
```



### Agent部署方案

#### 管理节点Agent分发脚本
```bash
#!/bin/bash
# distribute-agents.sh - 在管理节点运行，用于分发Agent到所有节点

MANAGEMENT_NODE_IP="$(hostname -I | awk '{print $1}')"
SERVER_URL="http://${MANAGEMENT_NODE_IP}:8080"
AGENT_BINARY="/opt/minipanel/minipanel-agent"
INSTALL_SCRIPT="/tmp/install-agent.sh"

# 检查Agent二进制文件是否存在
check_agent_binary() {
    if [ ! -f "$AGENT_BINARY" ]; then
        echo "错误: Agent二进制文件不存在: $AGENT_BINARY"
        exit 1
    fi
}

# 生成Agent安装脚本
generate_install_script() {
    cat > $INSTALL_SCRIPT << 'EOF'
#!/bin/bash
# install-agent.sh - Agent安装脚本

SERVER_URL="__SERVER_URL__"
INSTALL_DIR="/opt/minipanel-agent"
AGENT_BINARY="/tmp/minipanel-agent"

# 安装Agent
install_agent() {
    echo "正在安装MiniPanel Agent..."
    
    # 创建安装目录
    mkdir -p $INSTALL_DIR
    
    # 复制Agent程序
    if [ -f "$AGENT_BINARY" ]; then
        cp $AGENT_BINARY $INSTALL_DIR/minipanel-agent
        chmod +x $INSTALL_DIR/minipanel-agent
        echo "Agent程序安装完成"
    else
        echo "错误: Agent二进制文件不存在"
        exit 1
    fi
}

# 生成配置文件
generate_config() {
    echo "正在生成配置文件..."
    cat > $INSTALL_DIR/config.toml << EOC
server_url = "$SERVER_URL"
node_id = "$(hostname)"
interval = 5
EOC
    echo "配置文件生成完成"
}

# 创建systemd服务
create_service() {
    echo "正在创建systemd服务..."
    cat > /etc/systemd/system/minipanel-agent.service << EOS
[Unit]
Description=MiniPanel Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/minipanel-agent
Restart=always
RestartSec=5
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
EOS

    # 重新加载systemd并启动服务
    systemctl daemon-reload
    systemctl enable minipanel-agent
    systemctl start minipanel-agent
    
    if systemctl is-active --quiet minipanel-agent; then
        echo "MiniPanel Agent服务启动成功"
    else
        echo "警告: MiniPanel Agent服务启动失败"
        systemctl status minipanel-agent
    fi
}

# 清理临时文件
cleanup() {
    rm -f $AGENT_BINARY
    rm -f /tmp/install-agent.sh
    echo "临时文件清理完成"
}

main() {
    echo "开始安装MiniPanel Agent到节点: $(hostname)"
    install_agent
    generate_config
    create_service
    cleanup
    echo "MiniPanel Agent安装完成！"
}

main "$@"
EOF

    # 替换SERVER_URL占位符
    sed -i "s|__SERVER_URL__|$SERVER_URL|g" $INSTALL_SCRIPT
}

# 获取所有节点信息
get_nodes() {
    echo "正在从/etc/hosts获取节点信息..."
    # 从hosts文件中提取节点信息，排除注释行和localhost
    grep -v '^#' /etc/hosts | grep -v '127.0.0.1' | grep -v '::1' | awk '{if($2 != "") print $1 " " $2}' | sort -u
}

# 分发Agent到远程节点
distribute_to_remote_node() {
    local node_ip="$1"
    local node_hostname="$2"
    
    echo "正在分发Agent到节点: $node_hostname ($node_ip)"
    
    # 检查节点连通性
    if ! ping -c 1 -W 3 "$node_ip" > /dev/null 2>&1; then
        echo "警告: 节点 $node_hostname ($node_ip) 无法连通，跳过"
        return 1
    fi
    
    # 复制Agent二进制文件
    if ! scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$AGENT_BINARY" "root@$node_ip:/tmp/minipanel-agent"; then
        echo "错误: 无法复制Agent到节点 $node_hostname ($node_ip)"
        return 1
    fi
    
    # 复制安装脚本
    if ! scp -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$INSTALL_SCRIPT" "root@$node_ip:/tmp/install-agent.sh"; then
        echo "错误: 无法复制安装脚本到节点 $node_hostname ($node_ip)"
        return 1
    fi
    
    # 执行安装脚本
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "root@$node_ip" "chmod +x /tmp/install-agent.sh && /tmp/install-agent.sh"; then
        echo "成功: 节点 $node_hostname ($node_ip) Agent安装完成"
        return 0
    else
        echo "错误: 节点 $node_hostname ($node_ip) Agent安装失败"
        return 1
    fi
}

# 安装Agent到本地节点
install_local_agent() {
    echo "正在安装Agent到本地节点: $(hostname)"
    
    # 直接在本地执行安装
    INSTALL_DIR="/opt/minipanel-agent"
    
    # 创建安装目录
    mkdir -p $INSTALL_DIR
    
    # 复制Agent程序
    cp "$AGENT_BINARY" "$INSTALL_DIR/minipanel-agent"
    chmod +x "$INSTALL_DIR/minipanel-agent"
    
    # 生成配置文件
    cat > $INSTALL_DIR/config.toml << EOF
server_url = "$SERVER_URL"
node_id = "$(hostname)"
interval = 5
EOF
    
    # 创建systemd服务
    cat > /etc/systemd/system/minipanel-agent.service << EOF
[Unit]
Description=MiniPanel Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/minipanel-agent
Restart=always
RestartSec=5
Environment=HOME=/root

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd并启动服务
    systemctl daemon-reload
    systemctl enable minipanel-agent
    systemctl start minipanel-agent
    
    if systemctl is-active --quiet minipanel-agent; then
        echo "成功: 本地节点Agent安装完成"
        return 0
    else
        echo "错误: 本地节点Agent安装失败"
        systemctl status minipanel-agent
        return 1
    fi
}

# 主函数
main() {
    echo "=== MiniPanel Agent分发工具 ==="
    echo "管理节点IP: $MANAGEMENT_NODE_IP"
    echo "服务器URL: $SERVER_URL"
    echo ""
    
    # 检查必要条件
    check_agent_binary
    
    # 生成安装脚本
    generate_install_script
    
    # 统计变量
    local total_nodes=0
    local success_nodes=0
    local failed_nodes=0
    
    # 安装到本地节点
    echo "1. 安装Agent到本地节点"
    total_nodes=$((total_nodes + 1))
    if install_local_agent; then
        success_nodes=$((success_nodes + 1))
    else
        failed_nodes=$((failed_nodes + 1))
    fi
    echo ""
    
    # 获取远程节点列表
    echo "2. 获取远程节点列表"
    local nodes
    nodes=$(get_nodes)
    
    if [ -z "$nodes" ]; then
        echo "警告: 未在/etc/hosts中找到其他节点"
    else
        echo "找到以下节点:"
        echo "$nodes"
        echo ""
        
        # 分发到远程节点
        echo "3. 分发Agent到远程节点"
        while IFS=' ' read -r node_ip node_hostname; do
            if [ -n "$node_ip" ] && [ -n "$node_hostname" ]; then
                total_nodes=$((total_nodes + 1))
                if distribute_to_remote_node "$node_ip" "$node_hostname"; then
                    success_nodes=$((success_nodes + 1))
                else
                    failed_nodes=$((failed_nodes + 1))
                fi
                echo ""
            fi
        done <<< "$nodes"
    fi
    
    # 清理临时文件
    rm -f $INSTALL_SCRIPT
    
    # 输出统计结果
    echo "=== 分发完成 ==="
    echo "总节点数: $total_nodes"
    echo "成功安装: $success_nodes"
    echo "安装失败: $failed_nodes"
    
    if [ $failed_nodes -eq 0 ]; then
        echo "所有节点Agent安装成功！"
        exit 0
    else
        echo "部分节点安装失败，请检查网络连接和SSH配置"
        exit 1
    fi
}

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用root权限运行此脚本"
    exit 1
fi

main "$@"
```

### 管理节点扩展

#### Agent管理API
```go
// 接收指标数据
func ReceiveMetrics(c *gin.Context) {
    var metrics MetricsData
    if err := c.ShouldBindJSON(&metrics); err != nil {
        c.JSON(400, gin.H{"error": err.Error()})
        return
    }
    
    // 存储数据到数据库
    err := StoreMetrics(&metrics)
    if err != nil {
        c.JSON(500, gin.H{"error": err.Error()})
        return
    }
    
    c.JSON(200, gin.H{"status": "ok"})
}
```

## 部署方案

### 系统要求

#### 管理节点
- RHEL系 Linux系统
- 最小内存: 512MB
- 最小磁盘: 1GB
- 网络端口: 8080

#### 计算节点
- RHEL系 Linux系统
- 最小内存: 64MB
- 最小磁盘: 50MB

### 安装脚本功能

#### 管理节点安装
1. 读取hosts文件获取节点信息
2. 设置管理员账号密码
3. 创建配置文件和数据库
4. 安装systemd服务
5. 启动服务
6. 运行Agent分发脚本，自动分发到所有节点（包括本机）

#### Agent分发流程
1. **自动检测节点**：从/etc/hosts文件读取所有节点信息
2. **本地安装**：首先在管理节点本机安装Agent
3. **远程分发**：通过SSH自动分发Agent到所有远程节点
4. **连通性检查**：分发前检查节点网络连通性
5. **安装验证**：验证每个节点的Agent服务启动状态
6. **统计报告**：显示安装成功和失败的节点统计

#### 使用方法
```bash
# 在管理节点运行
sudo ./distribute-agents.sh
```

#### 分发特性
- **包含本机**：自动在管理节点安装Agent，实现自监控
- **批量分发**：一键分发到所有hosts文件中的节点
- **错误处理**：网络超时、SSH失败等异常情况的处理
- **进度显示**：实时显示分发进度和结果
- **自动清理**：分发完成后自动清理临时文件

### Systemd服务配置

#### 管理节点服务
```ini
[Unit]
Description=MiniPanel System Monitor Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/minipanel
ExecStart=/opt/minipanel/minipanel
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

#### Agent服务
```ini
[Unit]
Description=MiniPanel Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/minipanel-agent
ExecStart=/opt/minipanel-agent/minipanel-agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```















