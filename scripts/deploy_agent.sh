#!/bin/bash

# MiniPanel Agent 分发部署脚本
# 用于在多台服务器上批量部署Agent

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
AGENT_DIR="/opt/miniPanel/agent"
CONFIG_DIR="/etc/miniPanel"
SERVICE_USER="minipanel"
SERVER_URL="http://localhost:8080"
AGENT_BINARY="miniPanel-agent"
HOSTS_FILE="hosts.txt"
SSH_KEY=""
SSH_USER="root"
SSH_PORT="22"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    log_info "检查依赖..."
    
    if ! command -v ssh &> /dev/null; then
        log_error "ssh 命令未找到"
        exit 1
    fi
    
    if ! command -v scp &> /dev/null; then
        log_error "scp 命令未找到"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 编译Agent
build_agent() {
    log_info "编译Agent程序..."
    
    if [ ! -f "agent/cmd/main.go" ]; then
        log_error "Agent源码不存在，请确保在项目根目录运行此脚本"
        exit 1
    fi
    
    cd agent
    
    # 编译不同架构的Agent
    local platforms=("linux/amd64" "linux/arm64" "linux/arm")
    
    for platform in "${platforms[@]}"; do
        local os=$(echo $platform | cut -d'/' -f1)
        local arch=$(echo $platform | cut -d'/' -f2)
        local output="../dist/${AGENT_BINARY}-${os}-${arch}"
        
        log_info "编译 $platform..."
        GOOS=$os GOARCH=$arch go build -o "$output" cmd/main.go
        
        if [ $? -eq 0 ]; then
            log_success "$platform 编译完成"
        else
            log_error "$platform 编译失败"
            exit 1
        fi
    done
    
    cd ..
    log_success "Agent编译完成"
}

# 检测远程主机架构
detect_remote_arch() {
    local host=$1
    local ssh_opts="$2"
    
    local arch=$(ssh $ssh_opts "$host" "uname -m" 2>/dev/null)
    
    case $arch in
        x86_64) echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l|armv6l) echo "arm" ;;
        *) echo "amd64" ;; # 默认
    esac
}

# 在远程主机上安装Agent
install_agent_on_host() {
    local host=$1
    local ssh_opts="$2"
    local arch=$3
    
    log_info "在 $host 上安装Agent..."
    
    # 检查远程主机连接
    if ! ssh $ssh_opts "$host" "echo 'Connection test'" &>/dev/null; then
        log_error "无法连接到 $host"
        return 1
    fi
    
    # 创建目录结构
    ssh $ssh_opts "$host" "mkdir -p $AGENT_DIR $CONFIG_DIR /var/log/miniPanel"
    
    # 创建用户（如果不存在）
    ssh $ssh_opts "$host" "id $SERVICE_USER &>/dev/null || useradd -r -s /bin/false -d $AGENT_DIR $SERVICE_USER"
    
    # 复制Agent二进制文件
    local agent_binary="dist/${AGENT_BINARY}-linux-${arch}"
    if [ ! -f "$agent_binary" ]; then
        log_error "Agent二进制文件不存在: $agent_binary"
        return 1
    fi
    
    scp $ssh_opts "$agent_binary" "$host:$AGENT_DIR/$AGENT_BINARY"
    ssh $ssh_opts "$host" "chmod +x $AGENT_DIR/$AGENT_BINARY"
    
    # 生成配置文件
    local node_name=$(ssh $ssh_opts "$host" "hostname")
    local node_id="node-$(ssh $ssh_opts "$host" "hostname | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g'")"
    
    cat > "/tmp/agent-config-$host.yaml" << EOF
# MiniPanel Agent 配置文件
server:
  url: "$SERVER_URL"
  timeout: 30
  retry_count: 3
  retry_interval: 5

agent:
  node_id: "$node_id"
  node_name: "$node_name"
  
collector:
  interval: 30
  enable_cpu: true
  enable_memory: true
  enable_temperature: true
  
log:
  level: "info"
  file: "/var/log/miniPanel/agent.log"
  max_size: 50
  max_backups: 3
  max_age: 7
EOF
    
    # 复制配置文件
    scp $ssh_opts "/tmp/agent-config-$host.yaml" "$host:$CONFIG_DIR/agent.yaml"
    rm -f "/tmp/agent-config-$host.yaml"
    
    # 创建systemd服务
    cat > "/tmp/miniPanel-agent-$host.service" << EOF
[Unit]
Description=MiniPanel Agent Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$AGENT_DIR
ExecStart=$AGENT_DIR/$AGENT_BINARY -config $CONFIG_DIR/agent.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=miniPanel-agent

[Install]
WantedBy=multi-user.target
EOF
    
    scp $ssh_opts "/tmp/miniPanel-agent-$host.service" "$host:/etc/systemd/system/miniPanel-agent.service"
    rm -f "/tmp/miniPanel-agent-$host.service"
    
    # 设置权限
    ssh $ssh_opts "$host" "chown -R $SERVICE_USER:$SERVICE_USER $AGENT_DIR $CONFIG_DIR/agent.yaml /var/log/miniPanel"
    ssh $ssh_opts "$host" "chmod 640 $CONFIG_DIR/agent.yaml"
    
    # 启用并启动服务
    ssh $ssh_opts "$host" "systemctl daemon-reload"
    ssh $ssh_opts "$host" "systemctl enable miniPanel-agent"
    ssh $ssh_opts "$host" "systemctl start miniPanel-agent"
    
    # 检查服务状态
    sleep 2
    if ssh $ssh_opts "$host" "systemctl is-active --quiet miniPanel-agent"; then
        log_success "$host Agent安装并启动成功"
    else
        log_warning "$host Agent安装完成但启动失败，请检查配置"
        ssh $ssh_opts "$host" "systemctl status miniPanel-agent --no-pager -l"
    fi
}

# 从主机列表文件部署
deploy_from_hosts_file() {
    local hosts_file=$1
    
    if [ ! -f "$hosts_file" ]; then
        log_error "主机列表文件不存在: $hosts_file"
        exit 1
    fi
    
    log_info "从文件读取主机列表: $hosts_file"
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r line; do
        # 跳过空行和注释
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        total_count=$((total_count + 1))
        
        # 解析主机信息 (格式: host[:port] [user] [key_file])
        local host_info=($line)
        local host=${host_info[0]}
        local user=${host_info[1]:-$SSH_USER}
        local key=${host_info[2]:-$SSH_KEY}
        
        # 构建SSH选项
        local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
        if [ -n "$key" ]; then
            ssh_opts="$ssh_opts -i $key"
        fi
        if [[ "$host" == *":"* ]]; then
            local port=$(echo $host | cut -d':' -f2)
            host=$(echo $host | cut -d':' -f1)
            ssh_opts="$ssh_opts -p $port"
        else
            ssh_opts="$ssh_opts -p $SSH_PORT"
        fi
        
        # 添加用户
        ssh_opts="$user@$host $ssh_opts"
        
        # 检测架构
        local arch=$(detect_remote_arch "$user@$host" "$ssh_opts")
        log_info "$host 架构: $arch"
        
        # 安装Agent
        if install_agent_on_host "$user@$host" "$ssh_opts" "$arch"; then
            success_count=$((success_count + 1))
        fi
        
    done < "$hosts_file"
    
    log_info "部署完成: $success_count/$total_count 成功"
}

# 部署到单个主机
deploy_to_single_host() {
    local host=$1
    local user=${2:-$SSH_USER}
    local key=${3:-$SSH_KEY}
    
    # 构建SSH选项
    local ssh_opts="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [ -n "$key" ]; then
        ssh_opts="$ssh_opts -i $key"
    fi
    if [[ "$host" == *":"* ]]; then
        local port=$(echo $host | cut -d':' -f2)
        host=$(echo $host | cut -d':' -f1)
        ssh_opts="$ssh_opts -p $port"
    else
        ssh_opts="$ssh_opts -p $SSH_PORT"
    fi
    
    ssh_opts="$user@$host $ssh_opts"
    
    # 检测架构
    local arch=$(detect_remote_arch "$user@$host" "$ssh_opts")
    log_info "$host 架构: $arch"
    
    # 安装Agent
    install_agent_on_host "$user@$host" "$ssh_opts" "$arch"
}

# 生成示例主机列表文件
generate_hosts_example() {
    cat > hosts.txt.example << EOF
# MiniPanel Agent 主机列表文件
# 格式: host[:port] [user] [ssh_key_file]
# 示例:

# 使用默认端口和用户
192.168.1.100
192.168.1.101

# 指定端口
192.168.1.102:2222

# 指定用户
192.168.1.103 ubuntu

# 指定用户和SSH密钥
192.168.1.104 centos /path/to/private/key

# 完整格式
192.168.1.105:2222 admin /home/user/.ssh/id_rsa
EOF
    
    log_success "示例主机列表文件已生成: hosts.txt.example"
}

# 显示帮助信息
show_help() {
    echo "MiniPanel Agent 分发部署脚本"
    echo ""
    echo "用法: $0 [选项] [主机地址]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -f, --hosts-file FILE   从文件读取主机列表 (默认: hosts.txt)"
    echo "  -u, --user USER         SSH用户名 (默认: root)"
    echo "  -p, --port PORT         SSH端口 (默认: 22)"
    echo "  -k, --key FILE          SSH私钥文件"
    echo "  -s, --server URL        服务器地址 (默认: http://localhost:8080)"
    echo "  --skip-build            跳过编译，使用现有二进制文件"
    echo "  --generate-example      生成示例主机列表文件"
    echo ""
    echo "示例:"
    echo "  $0                      从 hosts.txt 批量部署"
    echo "  $0 192.168.1.100        部署到单个主机"
    echo "  $0 -f servers.txt       从指定文件批量部署"
    echo "  $0 -u ubuntu -k ~/.ssh/id_rsa 192.168.1.100"
    echo ""
}

# 主函数
main() {
    local hosts_file="$HOSTS_FILE"
    local single_host=""
    local skip_build=false
    local generate_example=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--hosts-file)
                hosts_file="$2"
                shift 2
                ;;
            -u|--user)
                SSH_USER="$2"
                shift 2
                ;;
            -p|--port)
                SSH_PORT="$2"
                shift 2
                ;;
            -k|--key)
                SSH_KEY="$2"
                shift 2
                ;;
            -s|--server)
                SERVER_URL="$2"
                shift 2
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --generate-example)
                generate_example=true
                shift
                ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                single_host="$1"
                shift
                ;;
        esac
    done
    
    echo "======================================"
    echo "     MiniPanel Agent 分发部署脚本"
    echo "======================================"
    echo ""
    
    # 生成示例文件
    if [ "$generate_example" = true ]; then
        generate_hosts_example
        exit 0
    fi
    
    # 检查依赖
    check_dependencies
    
    # 创建dist目录
    mkdir -p dist
    
    # 编译Agent
    if [ "$skip_build" = false ]; then
        build_agent
    fi
    
    # 部署
    if [ -n "$single_host" ]; then
        # 单个主机部署
        deploy_to_single_host "$single_host"
    else
        # 批量部署
        if [ ! -f "$hosts_file" ]; then
            log_warning "主机列表文件不存在: $hosts_file"
            log_info "生成示例文件..."
            generate_hosts_example
            log_info "请编辑 hosts.txt.example 并重命名为 hosts.txt，然后重新运行脚本"
            exit 1
        fi
        
        deploy_from_hosts_file "$hosts_file"
    fi
    
    log_success "Agent部署完成！"
    echo ""
    echo "管理命令:"
    echo "  启动Agent: systemctl start miniPanel-agent"
    echo "  停止Agent: systemctl stop miniPanel-agent"
    echo "  查看状态: systemctl status miniPanel-agent"
    echo "  查看日志: journalctl -u miniPanel-agent -f"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi