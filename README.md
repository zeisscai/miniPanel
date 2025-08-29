# MiniPanel

一个轻量级的服务器监控面板，基于 Go + Vue3 + SQLite 构建。

## 🚀 特性

- **轻量级**: 基于 SQLite 数据库，无需复杂的数据库配置
- **实时监控**: 实时显示 CPU、内存使用率和温度信息
- **历史数据**: 支持历史数据查询和图表展示
- **多节点**: 支持多台服务器的集中监控
- **易部署**: 提供一键安装脚本和 Agent 分发工具
- **现代化UI**: 基于 Vue3 + Element Plus 的响应式界面

## 📋 系统要求

### 服务端
- Linux 系统 (Ubuntu 18.04+, CentOS 7+)
- Go 1.19+ (自动安装)
- Node.js 18+ (自动安装)
- SQLite3
- Nginx (可选，用于反向代理)

### Agent端
- Linux 系统
- 网络连接到服务端

## 🛠️ 快速开始

### 方式一：一键安装（推荐）

```bash
# 下载项目
git clone https://github.com/your-org/miniPanel.git
cd miniPanel

# 运行一键安装脚本
sudo ./scripts/install.sh
```

安装完成后访问 `http://your-server-ip`，默认用户名 `admin`，密码 `admin123`。

### 方式二：手动安装

#### 1. 初始化数据库

```bash
# 创建数据库和目录
./scripts/init_database.sh
```

#### 2. 编译后端

```bash
cd backend
go mod tidy
go build -o miniPanel-backend cmd/main.go
```

#### 3. 构建前端

```bash
cd ../frontend
npm install
npm run build
```

#### 4. 编译Agent

```bash
cd ../agent
go mod tidy
go build -o miniPanel-agent cmd/main.go
```

#### 5. 配置和启动

```bash
# 复制配置文件
cp backend/config.yaml /etc/miniPanel/backend.yaml
cp agent/config.yaml /etc/miniPanel/agent.yaml

# 启动后端
./backend/miniPanel-backend -config /etc/miniPanel/backend.yaml

# 启动Agent
./agent/miniPanel-agent -config /etc/miniPanel/agent.yaml
```

## 📦 Agent 部署

### 批量部署

1. 创建主机列表文件：

```bash
# 生成示例文件
./scripts/deploy_agent.sh --generate-example

# 编辑主机列表
cp hosts.txt.example hosts.txt
vim hosts.txt
```

2. 批量部署：

```bash
# 部署到所有主机
./scripts/deploy_agent.sh

# 指定服务器地址
./scripts/deploy_agent.sh -s http://your-server:8080
```

### 单个部署

```bash
# 部署到单个主机
./scripts/deploy_agent.sh 192.168.1.100

# 指定用户和密钥
./scripts/deploy_agent.sh -u ubuntu -k ~/.ssh/id_rsa 192.168.1.100
```

## ⚙️ 配置说明

### 后端配置 (`backend.yaml`)

```yaml
server:
  host: "0.0.0.0"          # 监听地址
  port: 8080               # 监听端口
  mode: "release"          # 运行模式

database:
  path: "./data/miniPanel.db"  # 数据库路径
  
auth:
  jwt_secret: "your-secret-key"  # JWT密钥（生产环境请修改）
  token_expire_hours: 24         # Token过期时间
```

### Agent配置 (`agent.yaml`)

```yaml
server:
  url: "http://localhost:8080"  # 服务器地址
  timeout: 30                   # 请求超时

agent:
  node_id: ""                   # 节点ID（留空自动生成）
  node_name: ""                 # 节点名称（留空使用主机名）
  
collector:
  interval: 30                  # 采集间隔（秒）
  enable_cpu: true              # 启用CPU监控
  enable_memory: true           # 启用内存监控
  enable_temperature: true      # 启用温度监控
```

## 🔧 服务管理

### Systemd 服务

```bash
# 后端服务
sudo systemctl start miniPanel-backend
sudo systemctl stop miniPanel-backend
sudo systemctl restart miniPanel-backend
sudo systemctl status miniPanel-backend

# Agent服务
sudo systemctl start miniPanel-agent
sudo systemctl stop miniPanel-agent
sudo systemctl restart miniPanel-agent
sudo systemctl status miniPanel-agent

# 查看日志
sudo journalctl -u miniPanel-backend -f
sudo journalctl -u miniPanel-agent -f
```

### 手动启动

```bash
# 后端
./miniPanel-backend -config /etc/miniPanel/backend.yaml

# Agent
./miniPanel-agent -config /etc/miniPanel/agent.yaml
```

## 📊 API 文档

### 认证

```bash
# 登录
curl -X POST http://localhost:8080/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

### 获取节点列表

```bash
curl -X GET http://localhost:8080/api/nodes \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 获取实时数据

```bash
curl -X GET "http://localhost:8080/api/metrics/realtime?node_id=node-001" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 获取历史数据

```bash
curl -X GET "http://localhost:8080/api/metrics/history?node_id=node-001&start_time=2024-01-01 00:00:00&end_time=2024-01-02 00:00:00" \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## 🏗️ 项目结构

```
miniPanel/
├── backend/                 # 后端Go程序
│   ├── cmd/
│   │   └── main.go         # 主程序入口
│   ├── internal/
│   │   ├── config/         # 配置管理
│   │   ├── handler/        # HTTP处理器
│   │   ├── middleware/     # 中间件
│   │   ├── model/          # 数据模型
│   │   ├── service/        # 业务逻辑
│   │   └── utils/          # 工具函数
│   ├── static/             # 前端构建文件
│   ├── config.yaml         # 配置文件
│   ├── go.mod
│   └── go.sum
├── frontend/               # 前端Vue3应用
│   ├── public/
│   ├── src/
│   │   ├── api/           # API接口
│   │   ├── components/    # 组件
│   │   ├── router/        # 路由
│   │   ├── stores/        # 状态管理
│   │   ├── views/         # 页面
│   │   ├── App.vue
│   │   └── main.js
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   └── ...
├── agent/                  # Agent程序
│   ├── cmd/
│   │   └── main.go        # Agent主程序
│   ├── internal/
│   │   ├── collector/     # 数据采集器
│   │   ├── config/        # 配置管理
│   │   └── client/        # HTTP客户端
│   ├── config.yaml        # Agent配置
│   ├── go.mod
│   └── go.sum
├── scripts/               # 部署和管理脚本
│   ├── install.sh         # 一键安装脚本
│   ├── deploy_agent.sh    # Agent部署脚本
│   ├── init_database.sh   # 数据库初始化
│   └── init_db.sql        # SQL初始化脚本
├── deploy/                # 部署配置
│   ├── miniPanel-backend.service  # 后端systemd服务
│   ├── miniPanel-agent.service    # Agent systemd服务
│   └── nginx.conf         # Nginx配置模板
├── data/                  # 数据目录（运行时创建）
│   └── miniPanel.db       # SQLite数据库
├── logs/                  # 日志目录（运行时创建）
└── README.md
```

## 🔒 安全建议

1. **修改默认密码**: 首次登录后立即修改默认管理员密码
2. **JWT密钥**: 生产环境中修改 `jwt_secret` 为强密码
3. **HTTPS**: 生产环境建议配置HTTPS
4. **防火墙**: 配置防火墙规则，仅开放必要端口
5. **定期备份**: 定期备份SQLite数据库文件

## 🔍 故障排除

### 常见问题

**Q: Agent无法连接到服务器**
```bash
# 检查网络连通性
telnet server-ip 8080

# 检查Agent配置
cat /etc/miniPanel/agent.yaml

# 查看Agent日志
sudo journalctl -u miniPanel-agent -f
```

**Q: 前端页面无法访问**
```bash
# 检查后端服务状态
sudo systemctl status miniPanel-backend

# 检查端口占用
sudo netstat -tlnp | grep 8080

# 查看后端日志
sudo journalctl -u miniPanel-backend -f
```

**Q: 数据库权限问题**
```bash
# 检查数据库文件权限
ls -la /opt/miniPanel/data/

# 修复权限
sudo chown -R miniPanel:miniPanel /opt/miniPanel/data/
sudo chmod 644 /opt/miniPanel/data/miniPanel.db
```

### 日志位置

- 后端日志: `/var/log/miniPanel/backend.log`
- Agent日志: `/var/log/miniPanel/agent.log`
- Systemd日志: `journalctl -u miniPanel-backend` / `journalctl -u miniPanel-agent`

## 🤝 贡献指南

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [Gin](https://github.com/gin-gonic/gin) - Go Web框架
- [Vue.js](https://vuejs.org/) - 前端框架
- [Element Plus](https://element-plus.org/) - Vue3 UI组件库
- [gopsutil](https://github.com/shirou/gopsutil) - 系统信息采集库
- [Chart.js](https://www.chartjs.org/) - 图表库

## 📞 支持

如果您遇到问题或有建议，请：

- 提交 [Issue](https://github.com/your-org/miniPanel/issues)
- 发送邮件到: support@example.com
- 查看 [Wiki](https://github.com/your-org/miniPanel/wiki) 文档

---

**MiniPanel** - 让服务器监控变得简单 🚀