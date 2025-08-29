#!/bin/bash

# MiniPanel 一键安装脚本
# 支持 Ubuntu/Debian 和 CentOS/RHEL 系统

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
INSTALL_DIR="/opt/miniPanel"
SERVICE_USER="minipanel"
BACKEND_PORT="8080"
GO_VERSION="1.21.0"
NODE_VERSION="18"

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

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
    
    log_info "检测到操作系统: $OS $OS_VERSION"
}

# 安装依赖包
install_dependencies() {
    log_info "安装系统依赖..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y curl wget git build-essential sqlite3 nginx supervisor
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf install -y curl wget git gcc gcc-c++ make sqlite nginx supervisor
            else
                yum install -y curl wget git gcc gcc-c++ make sqlite nginx supervisor
            fi
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
    
    log_success "系统依赖安装完成"
}

# 安装 Go
install_go() {
    if command -v go &> /dev/null; then
        local current_version=$(go version | awk '{print $3}' | sed 's/go//')
        log_info "Go 已安装，版本: $current_version"
        return
    fi
    
    log_info "安装 Go $GO_VERSION..."
    
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv6l" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac
    
    cd /tmp
    wget -q "https://golang.org/dl/go${GO_VERSION}.linux-${arch}.tar.gz"
    tar -C /usr/local -xzf "go${GO_VERSION}.linux-${arch}.tar.gz"
    
    # 添加到PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    log_success "Go 安装完成"
}

# 安装 Node.js
install_nodejs() {
    if command -v node &> /dev/null; then
        local current_version=$(node --version | sed 's/v//')
        log_info "Node.js 已安装，版本: $current_version"
        return
    fi
    
    log_info "安装 Node.js $NODE_VERSION..."
    
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
    
    case $OS in
        ubuntu|debian)
            apt-get install -y nodejs
            ;;
        centos|rhel|rocky|almalinux)
            if command -v dnf &> /dev/null; then
                dnf install -y nodejs npm
            else
                yum install -y nodejs npm
            fi
            ;;
    esac
    
    log_success "Node.js 安装完成"
}

# 创建系统用户
create_user() {
    if id "$SERVICE_USER" &>/dev/null; then
        log_info "用户 $SERVICE_USER 已存在"
    else
        log_info "创建系统用户 $SERVICE_USER..."
        useradd -r -s /bin/false -d "$INSTALL_DIR" "$SERVICE_USER"
        log_success "用户创建完成"
    fi
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    mkdir -p "$INSTALL_DIR"/{backend,agent,frontend,logs,data,config}
    mkdir -p /var/log/miniPanel
    mkdir -p /etc/miniPanel
    
    # 设置权限
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" /var/log/miniPanel
    
    log_success "目录结构创建完成"
}

# 编译后端
build_backend() {
    log_info "编译后端程序..."
    
    cd backend
    export GOPROXY=https://goproxy.cn,direct
    go mod tidy
    go build -o "$INSTALL_DIR/backend/miniPanel-backend" cmd/main.go
    
    log_success "后端编译完成"
}

# 编译Agent
build_agent() {
    log_info "编译Agent程序..."
    
    cd ../agent
    go mod tidy
    go build -o "$INSTALL_DIR/agent/miniPanel-agent" cmd/main.go
    
    log_success "Agent编译完成"
}

# 构建前端
build_frontend() {
    log_info "构建前端应用..."
    
    cd ../frontend
    npm install
    npm run build
    
    # 复制静态文件
    cp -r dist/* "$INSTALL_DIR/backend/static/"
    
    log_success "前端构建完成"
}

# 安装配置文件
install_configs() {
    log_info "安装配置文件..."
    
    # 后端配置
    cp backend/config.yaml /etc/miniPanel/backend.yaml
    
    # Agent配置
    cp agent/config.yaml /etc/miniPanel/agent.yaml
    
    # 修改配置文件权限
    chown "$SERVICE_USER:$SERVICE_USER" /etc/miniPanel/*.yaml
    chmod 640 /etc/miniPanel/*.yaml
    
    log_success "配置文件安装完成"
}

# 创建systemd服务
create_systemd_services() {
    log_info "创建systemd服务..."
    
    # 后端服务
    cat > /etc/systemd/system/miniPanel-backend.service << EOF
[Unit]
Description=MiniPanel Backend Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/backend
ExecStart=$INSTALL_DIR/backend/miniPanel-backend -config /etc/miniPanel/backend.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=miniPanel-backend

[Install]
WantedBy=multi-user.target
EOF

    # Agent服务
    cat > /etc/systemd/system/miniPanel-agent.service << EOF
[Unit]
Description=MiniPanel Agent Service
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR/agent
ExecStart=$INSTALL_DIR/agent/miniPanel-agent -config /etc/miniPanel/agent.yaml
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=miniPanel-agent

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd
    systemctl daemon-reload
    
    log_success "systemd服务创建完成"
}

# 配置Nginx
configure_nginx() {
    log_info "配置Nginx反向代理..."
    
    cat > /etc/nginx/sites-available/miniPanel << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /api/ {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    # 启用站点
    if [[ -d /etc/nginx/sites-enabled ]]; then
        ln -sf /etc/nginx/sites-available/miniPanel /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
    else
        # CentOS/RHEL 风格
        cp /etc/nginx/sites-available/miniPanel /etc/nginx/conf.d/miniPanel.conf
    fi
    
    # 测试Nginx配置
    nginx -t
    
    log_success "Nginx配置完成"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    cd "$INSTALL_DIR"
    ./scripts/init_database.sh -d "$INSTALL_DIR/data/miniPanel.db"
    
    # 设置数据库权限
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/data/miniPanel.db"
    
    log_success "数据库初始化完成"
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    # 启用并启动服务
    systemctl enable miniPanel-backend
    systemctl enable miniPanel-agent
    systemctl enable nginx
    
    systemctl start miniPanel-backend
    systemctl start miniPanel-agent
    systemctl start nginx
    
    # 检查服务状态
    sleep 3
    
    if systemctl is-active --quiet miniPanel-backend; then
        log_success "后端服务启动成功"
    else
        log_error "后端服务启动失败"
        systemctl status miniPanel-backend
    fi
    
    if systemctl is-active --quiet miniPanel-agent; then
        log_success "Agent服务启动成功"
    else
        log_warning "Agent服务启动失败（这是正常的，需要配置后重启）"
    fi
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx服务启动成功"
    else
        log_error "Nginx服务启动失败"
        systemctl status nginx
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo ""
    log_success "MiniPanel 安装完成！"
    echo ""
    echo "安装信息:"
    echo "  安装目录: $INSTALL_DIR"
    echo "  配置目录: /etc/miniPanel"
    echo "  日志目录: /var/log/miniPanel"
    echo "  服务用户: $SERVICE_USER"
    echo ""
    echo "访问信息:"
    echo "  Web界面: http://$(hostname -I | awk '{print $1}')"
    echo "  默认用户名: admin"
    echo "  默认密码: admin123"
    echo ""
    echo "服务管理:"
    echo "  启动后端: systemctl start miniPanel-backend"
    echo "  停止后端: systemctl stop miniPanel-backend"
    echo "  启动Agent: systemctl start miniPanel-agent"
    echo "  停止Agent: systemctl stop miniPanel-agent"
    echo "  查看日志: journalctl -u miniPanel-backend -f"
    echo ""
    echo "配置文件:"
    echo "  后端配置: /etc/miniPanel/backend.yaml"
    echo "  Agent配置: /etc/miniPanel/agent.yaml"
    echo ""
    log_warning "请修改配置文件中的JWT密钥等安全设置！"
}

# 显示帮助信息
show_help() {
    echo "MiniPanel 一键安装脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  --install-dir DIR       指定安装目录 (默认: /opt/miniPanel)"
    echo "  --user USER             指定服务用户 (默认: minipanel)"
    echo "  --port PORT             指定后端端口 (默认: 8080)"
    echo "  --skip-deps             跳过依赖安装"
    echo "  --skip-build            跳过编译构建"
    echo "  --skip-nginx            跳过Nginx配置"
    echo ""
}

# 主函数
main() {
    local skip_deps=false
    local skip_build=false
    local skip_nginx=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --user)
                SERVICE_USER="$2"
                shift 2
                ;;
            --port)
                BACKEND_PORT="$2"
                shift 2
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --skip-nginx)
                skip_nginx=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "======================================"
    echo "       MiniPanel 一键安装脚本"
    echo "======================================"
    echo ""
    
    # 检查root权限
    check_root
    
    # 检测操作系统
    detect_os
    
    # 安装依赖
    if [ "$skip_deps" = false ]; then
        install_dependencies
        install_go
        install_nodejs
    fi
    
    # 创建用户和目录
    create_user
    create_directories
    
    # 编译和构建
    if [ "$skip_build" = false ]; then
        build_backend
        build_agent
        build_frontend
    fi
    
    # 安装配置
    install_configs
    
    # 创建服务
    create_systemd_services
    
    # 配置Nginx
    if [ "$skip_nginx" = false ]; then
        configure_nginx
    fi
    
    # 初始化数据库
    init_database
    
    # 启动服务
    start_services
    
    # 显示完成信息
    show_completion_info
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi