#!/bin/bash

# MiniPanel 数据库初始化脚本
# 用于自动创建数据库和初始化数据

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    
    if ! command -v sqlite3 &> /dev/null; then
        log_error "sqlite3 未安装，请先安装 SQLite3"
        exit 1
    fi
    
    log_success "依赖检查完成"
}

# 创建目录结构
create_directories() {
    log_info "创建目录结构..."
    
    # 后端目录
    mkdir -p backend/data
    mkdir -p backend/logs
    mkdir -p backend/static
    
    # Agent目录
    mkdir -p agent/logs
    
    log_success "目录结构创建完成"
}

# 初始化数据库
init_database() {
    local db_path="${1:-backend/data/miniPanel.db}"
    local sql_file="${2:-scripts/init_db.sql}"
    
    log_info "初始化数据库: $db_path"
    
    if [ ! -f "$sql_file" ]; then
        log_error "SQL文件不存在: $sql_file"
        exit 1
    fi
    
    # 创建数据库目录
    mkdir -p "$(dirname "$db_path")"
    
    # 执行SQL脚本
    if sqlite3 "$db_path" < "$sql_file"; then
        log_success "数据库初始化完成: $db_path"
    else
        log_error "数据库初始化失败"
        exit 1
    fi
    
    # 设置数据库文件权限
    chmod 644 "$db_path"
    
    # 显示数据库信息
    log_info "数据库表列表:"
    sqlite3 "$db_path" ".tables"
    
    log_info "用户表记录数:"
    sqlite3 "$db_path" "SELECT COUNT(*) FROM users;"
    
    log_info "节点表记录数:"
    sqlite3 "$db_path" "SELECT COUNT(*) FROM nodes;"
}

# 生成配置文件
generate_configs() {
    log_info "检查配置文件..."
    
    # 后端配置
    if [ ! -f "backend/config.yaml" ]; then
        log_warning "后端配置文件不存在，请手动创建 backend/config.yaml"
    else
        log_success "后端配置文件已存在"
    fi
    
    # Agent配置
    if [ ! -f "agent/config.yaml" ]; then
        log_warning "Agent配置文件不存在，请手动创建 agent/config.yaml"
    else
        log_success "Agent配置文件已存在"
    fi
}

# 验证数据库
verify_database() {
    local db_path="${1:-backend/data/miniPanel.db}"
    
    log_info "验证数据库..."
    
    if [ ! -f "$db_path" ]; then
        log_error "数据库文件不存在: $db_path"
        exit 1
    fi
    
    # 检查表是否存在
    local tables=("users" "nodes" "system_metrics")
    for table in "${tables[@]}"; do
        if sqlite3 "$db_path" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table';" | grep -q "$table"; then
            log_success "表 $table 存在"
        else
            log_error "表 $table 不存在"
            exit 1
        fi
    done
    
    # 检查默认管理员用户
    local admin_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM users WHERE username='admin';")
    if [ "$admin_count" -gt 0 ]; then
        log_success "默认管理员用户已创建"
    else
        log_warning "默认管理员用户不存在"
    fi
}

# 显示帮助信息
show_help() {
    echo "MiniPanel 数据库初始化脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示帮助信息"
    echo "  -d, --database PATH     指定数据库文件路径 (默认: backend/data/miniPanel.db)"
    echo "  -s, --sql PATH          指定SQL文件路径 (默认: scripts/init_db.sql)"
    echo "  --skip-deps             跳过依赖检查"
    echo "  --verify-only           仅验证数据库，不进行初始化"
    echo ""
    echo "示例:"
    echo "  $0                      使用默认设置初始化数据库"
    echo "  $0 -d /path/to/db.db    指定数据库文件路径"
    echo "  $0 --verify-only        仅验证现有数据库"
}

# 主函数
main() {
    local db_path="backend/data/miniPanel.db"
    local sql_file="scripts/init_db.sql"
    local skip_deps=false
    local verify_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--database)
                db_path="$2"
                shift 2
                ;;
            -s|--sql)
                sql_file="$2"
                shift 2
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --verify-only)
                verify_only=true
                shift
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_info "开始 MiniPanel 数据库初始化..."
    
    # 检查依赖
    if [ "$skip_deps" = false ]; then
        check_dependencies
    fi
    
    if [ "$verify_only" = true ]; then
        verify_database "$db_path"
        log_success "数据库验证完成"
        exit 0
    fi
    
    # 创建目录
    create_directories
    
    # 初始化数据库
    init_database "$db_path" "$sql_file"
    
    # 生成配置文件
    generate_configs
    
    # 验证数据库
    verify_database "$db_path"
    
    log_success "MiniPanel 数据库初始化完成！"
    echo ""
    log_info "下一步:"
    echo "1. 检查并修改配置文件 backend/config.yaml"
    echo "2. 检查并修改配置文件 agent/config.yaml"
    echo "3. 启动后端服务: cd backend && go run cmd/main.go"
    echo "4. 启动Agent: cd agent && go run cmd/main.go"
    echo "5. 访问 http://localhost:8080 (默认用户名: admin, 密码: admin123)"
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi