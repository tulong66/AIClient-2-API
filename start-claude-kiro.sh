#!/bin/bash

# AIClient-2-API Claude Kiro OAuth 启动脚本
# 作者: AIClient-2-API
# 版本: 1.0
# 描述: 启动 claude-kiro-oauth 服务的便捷脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_API_KEY="123456"
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="3000"
DEFAULT_KIRO_CREDS_FILE="$HOME/.aws/sso/cache/kiro-auth-token.json"
DEFAULT_LOG_MODE="console"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "AIClient-2-API Claude Kiro OAuth 启动脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -k, --api-key KEY        API密钥 (默认: $DEFAULT_API_KEY)"
    echo "  --host HOST              监听地址 (默认: $DEFAULT_HOST)"
    echo "  -p, --port PORT          监听端口 (默认: $DEFAULT_PORT)"
    echo "  -f, --kiro-file FILE     Kiro认证文件路径 (默认: $DEFAULT_KIRO_CREDS_FILE)"
    echo "  -l, --log-mode MODE      日志模式: console/file/none (默认: $DEFAULT_LOG_MODE)"
    echo "  -d, --daemon             后台运行模式"
    echo "  -s, --status             检查服务状态"
    echo "  -t, --test               测试API功能"
    echo "  --stop                   停止后台服务"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                       # 使用默认配置启动"
    echo "  $0 -k mykey -p 8080      # 自定义API密钥和端口"
    echo "  $0 -d                    # 后台运行"
    echo "  $0 -s                    # 检查服务状态"
    echo "  $0 -t                    # 测试API功能"
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    
    # 检查 Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js 未安装，请先安装 Node.js (>=20.0.0)"
        exit 1
    fi
    
    local node_version=$(node -v | sed 's/v//')
    print_info "Node.js 版本: $node_version"
    
    # 检查项目文件
    if [ ! -f "$PROJECT_DIR/src/api-server.js" ]; then
        print_error "未找到 api-server.js 文件，请确认在正确的项目目录中运行"
        exit 1
    fi
    
    # 检查 package.json
    if [ ! -f "$PROJECT_DIR/package.json" ]; then
        print_error "未找到 package.json 文件"
        exit 1
    fi
    
    # 检查 node_modules
    if [ ! -d "$PROJECT_DIR/node_modules" ]; then
        print_warning "未找到 node_modules，正在安装依赖..."
        cd "$PROJECT_DIR"
        npm install
        if [ $? -ne 0 ]; then
            print_error "依赖安装失败"
            exit 1
        fi
    fi
    
    print_success "依赖检查完成"
}

# 检查 Kiro 认证文件
check_kiro_auth() {
    local kiro_file="$1"
    
    print_info "检查 Kiro 认证文件: $kiro_file"
    
    if [ ! -f "$kiro_file" ]; then
        print_error "Kiro 认证文件不存在: $kiro_file"
        print_info "请确保已完成 Kiro 客户端授权登录并生成认证文件"
        exit 1
    fi
    
    # 检查文件格式
    if ! jq empty "$kiro_file" 2>/dev/null; then
        print_error "Kiro 认证文件格式无效 (不是有效的JSON)"
        exit 1
    fi
    
    # 检查必要字段
    local required_fields=("accessToken" "refreshToken")
    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$kiro_file" >/dev/null 2>&1; then
            print_error "Kiro 认证文件缺少必要字段: $field"
            exit 1
        fi
    done
    
    # 检查token是否过期
    local expires_at=$(jq -r '.expiresAt // empty' "$kiro_file")
    if [ -n "$expires_at" ]; then
        local current_time=$(date -u +%s)
        local expire_time=$(date -d "$expires_at" +%s 2>/dev/null || echo "0")
        
        if [ "$expire_time" -lt "$current_time" ]; then
            print_warning "访问令牌已过期，服务将尝试自动刷新"
        else
            print_success "访问令牌有效"
        fi
    fi
    
    print_success "Kiro 认证文件检查完成"
}

# 检查端口是否被占用
check_port() {
    local port="$1"
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "端口 $port 已被占用"
        print_info "请使用其他端口或停止占用该端口的进程"
        exit 1
    fi
}

# 启动服务
start_service() {
    local api_key="$1"
    local host="$2"
    local port="$3"
    local kiro_file="$4"
    local log_mode="$5"
    local daemon_mode="$6"
    
    print_info "启动 Claude Kiro OAuth 服务..."
    print_info "配置信息:"
    print_info "  API密钥: $api_key"
    print_info "  监听地址: $host:$port"
    print_info "  Kiro认证文件: $kiro_file"
    print_info "  日志模式: $log_mode"
    
    # 构建启动命令
    local cmd="node src/api-server.js"
    cmd="$cmd --model-provider claude-kiro-oauth"
    cmd="$cmd --kiro-oauth-creds-file $kiro_file"
    cmd="$cmd --api-key $api_key"
    cmd="$cmd --host $host"
    cmd="$cmd --port $port"
    cmd="$cmd --log-prompts $log_mode"
    
    cd "$PROJECT_DIR"
    
    if [ "$daemon_mode" = "true" ]; then
        # 后台运行
        print_info "以后台模式启动服务..."
        nohup $cmd > "claude-kiro-service.log" 2>&1 &
        local pid=$!
        echo $pid > "claude-kiro-service.pid"
        
        # 等待服务启动
        sleep 3
        
        if kill -0 $pid 2>/dev/null; then
            print_success "服务已在后台启动 (PID: $pid)"
            print_info "日志文件: $PROJECT_DIR/claude-kiro-service.log"
            print_info "PID文件: $PROJECT_DIR/claude-kiro-service.pid"
            print_info "服务地址: http://$host:$port"
        else
            print_error "服务启动失败"
            exit 1
        fi
    else
        # 前台运行
        print_info "启动服务 (按 Ctrl+C 停止)..."
        exec $cmd
    fi
}

# 检查服务状态
check_status() {
    local pid_file="$PROJECT_DIR/claude-kiro-service.pid"
    
    if [ ! -f "$pid_file" ]; then
        print_info "未找到PID文件，服务可能未在后台运行"
        return 1
    fi
    
    local pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        print_success "服务正在运行 (PID: $pid)"
        
        # 尝试健康检查
        local health_url="http://localhost:$DEFAULT_PORT/health"
        if command -v curl &> /dev/null; then
            print_info "执行健康检查..."
            local response=$(curl -s "$health_url" 2>/dev/null)
            if [ $? -eq 0 ]; then
                print_success "健康检查通过: $response"
            else
                print_warning "健康检查失败，服务可能未完全启动"
            fi
        fi
        return 0
    else
        print_warning "PID文件存在但进程不存在，清理PID文件"
        rm -f "$pid_file"
        return 1
    fi
}

# 停止服务
stop_service() {
    local pid_file="$PROJECT_DIR/claude-kiro-service.pid"
    
    if [ ! -f "$pid_file" ]; then
        print_info "未找到PID文件，服务可能未在后台运行"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    if kill -0 "$pid" 2>/dev/null; then
        print_info "停止服务 (PID: $pid)..."
        kill "$pid"
        
        # 等待进程结束
        local count=0
        while kill -0 "$pid" 2>/dev/null && [ $count -lt 10 ]; do
            sleep 1
            count=$((count + 1))
        done
        
        if kill -0 "$pid" 2>/dev/null; then
            print_warning "进程未正常结束，强制终止..."
            kill -9 "$pid"
        fi
        
        print_success "服务已停止"
    else
        print_info "进程不存在"
    fi
    
    rm -f "$pid_file"
}

# 测试API功能
test_api() {
    local host="${1:-localhost}"
    local port="${2:-$DEFAULT_PORT}"
    local api_key="${3:-$DEFAULT_API_KEY}"
    
    print_info "测试API功能..."
    
    if ! command -v curl &> /dev/null; then
        print_error "curl 未安装，无法执行API测试"
        return 1
    fi
    
    local base_url="http://$host:$port"
    
    # 测试健康检查
    print_info "1. 测试健康检查..."
    local health_response=$(curl -s "$base_url/health")
    if [ $? -eq 0 ]; then
        print_success "健康检查通过: $health_response"
    else
        print_error "健康检查失败"
        return 1
    fi
    
    # 测试模型列表
    print_info "2. 测试模型列表..."
    local models_response=$(curl -s -H "Authorization: Bearer $api_key" "$base_url/v1/models")
    if [ $? -eq 0 ]; then
        print_success "模型列表获取成功"
        echo "$models_response" | jq '.data[].id' 2>/dev/null || echo "$models_response"
    else
        print_error "模型列表获取失败"
        return 1
    fi
    
    # 测试聊天功能
    print_info "3. 测试聊天功能..."
    local chat_data='{
        "model": "claude-sonnet-4-20250514",
        "messages": [{"role": "user", "content": "Hello, please respond with just \"API Test OK\""}],
        "stream": false
    }'
    
    local chat_response=$(curl -s -X POST "$base_url/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$chat_data")
    
    if [ $? -eq 0 ]; then
        print_success "聊天功能测试成功"
        echo "$chat_response" | jq '.choices[0].message.content' 2>/dev/null || echo "$chat_response"
    else
        print_error "聊天功能测试失败"
        return 1
    fi
    
    print_success "所有API测试通过！"
}

# 主函数
main() {
    # 解析命令行参数
    local api_key="$DEFAULT_API_KEY"
    local host="$DEFAULT_HOST"
    local port="$DEFAULT_PORT"
    local kiro_file="$DEFAULT_KIRO_CREDS_FILE"
    local log_mode="$DEFAULT_LOG_MODE"
    local daemon_mode="false"
    local show_status="false"
    local run_test="false"
    local stop_service_flag="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--api-key)
                api_key="$2"
                shift 2
                ;;
            --host)
                host="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -f|--kiro-file)
                kiro_file="$2"
                shift 2
                ;;
            -l|--log-mode)
                log_mode="$2"
                shift 2
                ;;
            -d|--daemon)
                daemon_mode="true"
                shift
                ;;
            -s|--status)
                show_status="true"
                shift
                ;;
            -t|--test)
                run_test="true"
                shift
                ;;
            --stop)
                stop_service_flag="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 执行相应操作
    if [ "$stop_service_flag" = "true" ]; then
        stop_service
        exit 0
    fi
    
    if [ "$show_status" = "true" ]; then
        check_status
        exit $?
    fi
    
    if [ "$run_test" = "true" ]; then
        test_api "$host" "$port" "$api_key"
        exit $?
    fi
    
    # 启动服务
    check_dependencies
    check_kiro_auth "$kiro_file"
    
    if [ "$daemon_mode" = "false" ]; then
        check_port "$port"
    fi
    
    start_service "$api_key" "$host" "$port" "$kiro_file" "$log_mode" "$daemon_mode"
}

# 运行主函数
main "$@"
