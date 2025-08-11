#!/bin/bash

# AIClient-2-API Gemini to Claude Proxy 启动脚本
# 作者: AIClient-2-API
# 版本: 1.0
# 描述: 启动 gemini-claude-proxy 服务的便捷脚本
# 功能: 通过Claude API格式访问Gemini模型，利用Gemini CLI OAuth的免费额度

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_API_KEY="123456"
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT="3001"
DEFAULT_GEMINI_CREDS_FILE="$HOME/.config/gcloud/application_default_credentials.json"
DEFAULT_PROJECT_ID=""
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

print_feature() {
    echo -e "${PURPLE}[FEATURE]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "AIClient-2-API Gemini to Claude Proxy 启动脚本"
    echo ""
    echo "🎯 功能特点:"
    echo "  • 通过Claude API格式访问Gemini模型"
    echo "  • 利用Gemini CLI OAuth的免费额度和高频率访问"
    echo "  • 兼容所有Claude API客户端"
    echo "  • 支持流式和非流式响应"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -k, --api-key KEY        API密钥 (默认: $DEFAULT_API_KEY)"
    echo "  --host HOST              监听地址 (默认: $DEFAULT_HOST)"
    echo "  -p, --port PORT          监听端口 (默认: $DEFAULT_PORT)"
    echo "  -f, --gemini-file FILE   Gemini认证文件路径 (默认: $DEFAULT_GEMINI_CREDS_FILE)"
    echo "  --project-id ID          Google Cloud项目ID (必需)"
    echo "  -l, --log-mode MODE      日志模式: console/file/none (默认: $DEFAULT_LOG_MODE)"
    echo "  --demo                   演示模式 (无需Google Cloud认证)"
    echo "  -d, --daemon             后台运行模式"
    echo "  -s, --status             检查服务状态"
    echo "  -t, --test               测试API功能"
    echo "  --stop                   停止后台服务"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --demo                                     # 演示模式启动 (推荐)"
    echo "  $0 --project-id my-project                    # 使用默认配置启动"
    echo "  $0 --project-id my-project -k mykey -p 8080   # 自定义API密钥和端口"
    echo "  $0 --project-id my-project -d                 # 后台运行"
    echo "  $0 -s                                         # 检查服务状态"
    echo "  $0 -t --demo                                  # 测试API功能 (演示模式)"
    echo ""
    echo "🔧 设置说明:"
    echo "  1. 确保已安装并配置Google Cloud CLI"
    echo "  2. 运行 'gcloud auth application-default login' 进行认证"
    echo "  3. 设置正确的Google Cloud项目ID"
    echo ""
    echo "📡 API端点:"
    echo "  • Claude兼容: POST /v1/messages"
    echo "  • 模型列表: GET /v1/models"
    echo "  • 健康检查: GET /health"
    echo ""
    echo "🎯 支持的Gemini模型:"
    echo "  • gemini-2.0-flash-exp"
    echo "  • gemini-1.5-pro"
    echo "  • gemini-1.5-flash"
    echo "  • gemini-1.0-pro"
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
    
    # 检查 Google Cloud CLI
    if ! command -v gcloud &> /dev/null; then
        print_warning "Google Cloud CLI 未安装，但可能不是必需的"
        print_info "如果遇到认证问题，请安装 gcloud CLI 并运行 'gcloud auth application-default login'"
    else
        local gcloud_version=$(gcloud version --format="value(Google Cloud SDK)" 2>/dev/null)
        print_info "Google Cloud CLI 版本: $gcloud_version"
    fi
    
    # 检查项目文件
    if [ ! -f "$PROJECT_DIR/src/api-server.js" ]; then
        print_error "未找到 api-server.js 文件，请确认在正确的项目目录中运行"
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

# 检查 Gemini 认证文件
check_gemini_auth() {
    local gemini_file="$1"
    local project_id="$2"
    
    print_info "检查 Gemini 认证配置..."
    
    if [ -z "$project_id" ]; then
        print_error "Google Cloud 项目ID未指定"
        print_info "请使用 --project-id 参数指定项目ID"
        exit 1
    fi
    
    print_info "Google Cloud 项目ID: $project_id"
    
    if [ ! -f "$gemini_file" ]; then
        print_warning "Gemini 认证文件不存在: $gemini_file"
        print_info "尝试使用默认认证方式..."
        print_info "如果遇到认证问题，请运行: gcloud auth application-default login"
    else
        print_success "找到 Gemini 认证文件: $gemini_file"
        
        # 检查文件格式
        if ! jq empty "$gemini_file" 2>/dev/null; then
            print_error "Gemini 认证文件格式无效 (不是有效的JSON)"
            exit 1
        fi
        
        print_success "Gemini 认证文件格式有效"
    fi
    
    print_success "Gemini 认证配置检查完成"
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
    local gemini_file="$4"
    local project_id="$5"
    local log_mode="$6"
    local demo_mode="$7"
    local daemon_mode="$8"
    
    print_info "启动 Gemini to Claude Proxy 服务..."

    if [ "$demo_mode" = "true" ]; then
        print_feature "🎯 演示模式特点:"
        print_feature "  • 无需Google Cloud认证"
        print_feature "  • 模拟Gemini API响应"
        print_feature "  • 完整的Claude API格式支持"
        print_feature "  • 适合测试和演示"
    else
        print_feature "🎯 服务特点:"
        print_feature "  • 通过Claude API格式访问Gemini模型"
        print_feature "  • 利用Gemini CLI OAuth免费额度"
        print_feature "  • 支持所有Claude API客户端"
    fi

    print_info "配置信息:"
    print_info "  API密钥: $api_key"
    print_info "  监听地址: $host:$port"
    if [ "$demo_mode" = "true" ]; then
        print_info "  运行模式: 演示模式 (无需认证)"
    else
        print_info "  项目ID: $project_id"
        print_info "  认证文件: $gemini_file"
    fi
    print_info "  日志模式: $log_mode"
    
    # 构建启动命令
    local cmd="node src/api-server.js"
    cmd="$cmd --model-provider gemini-claude-proxy"

    if [ "$demo_mode" = "true" ]; then
        cmd="$cmd --demo-mode true"
    else
        cmd="$cmd --gemini-oauth-creds-file $gemini_file"
        cmd="$cmd --project-id $project_id"
    fi

    cmd="$cmd --api-key $api_key"
    cmd="$cmd --host $host"
    cmd="$cmd --port $port"
    cmd="$cmd --log-prompts $log_mode"
    
    cd "$PROJECT_DIR"
    
    if [ "$daemon_mode" = "true" ]; then
        # 后台运行
        print_info "以后台模式启动服务..."
        nohup $cmd > "gemini-claude-proxy.log" 2>&1 &
        local pid=$!
        echo $pid > "gemini-claude-proxy.pid"
        
        # 等待服务启动
        sleep 3
        
        if kill -0 $pid 2>/dev/null; then
            print_success "服务已在后台启动 (PID: $pid)"
            print_info "日志文件: $PROJECT_DIR/gemini-claude-proxy.log"
            print_info "PID文件: $PROJECT_DIR/gemini-claude-proxy.pid"
            print_info "服务地址: http://$host:$port"
            print_feature "Claude API端点: http://$host:$port/v1/messages"
        else
            print_error "服务启动失败"
            exit 1
        fi
    else
        # 前台运行
        print_info "启动服务 (按 Ctrl+C 停止)..."
        print_feature "Claude API端点: http://$host:$port/v1/messages"
        exec $cmd
    fi
}

# 检查服务状态
check_status() {
    local pid_file="$PROJECT_DIR/gemini-claude-proxy.pid"
    
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
    local pid_file="$PROJECT_DIR/gemini-claude-proxy.pid"
    
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
    
    print_info "测试 Gemini to Claude Proxy API 功能..."
    
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
    local models_response=$(curl -s -H "x-api-key: $api_key" "$base_url/v1/models")
    if [ $? -eq 0 ]; then
        print_success "模型列表获取成功"
        echo "$models_response" | jq '.data[].id' 2>/dev/null || echo "$models_response"
    else
        print_error "模型列表获取失败"
        return 1
    fi
    
    # 测试Claude格式聊天功能
    print_info "3. 测试Claude格式聊天功能..."
    local chat_data='{
        "model": "gemini-1.5-flash",
        "messages": [{"role": "user", "content": "Hello, please respond with just \"Gemini-Claude Proxy Test OK\""}],
        "max_tokens": 100
    }'
    
    local chat_response=$(curl -s -X POST "$base_url/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -d "$chat_data")
    
    if [ $? -eq 0 ]; then
        print_success "Claude格式聊天功能测试成功"
        echo "$chat_response" | jq '.content[0].text' 2>/dev/null || echo "$chat_response"
    else
        print_error "Claude格式聊天功能测试失败"
        return 1
    fi
    
    print_success "所有API测试通过！"
    print_feature "🎉 Gemini to Claude Proxy 服务运行正常！"
}

# 主函数
main() {
    # 解析命令行参数
    local api_key="$DEFAULT_API_KEY"
    local host="$DEFAULT_HOST"
    local port="$DEFAULT_PORT"
    local gemini_file="$DEFAULT_GEMINI_CREDS_FILE"
    local project_id="$DEFAULT_PROJECT_ID"
    local log_mode="$DEFAULT_LOG_MODE"
    local demo_mode="false"
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
            -f|--gemini-file)
                gemini_file="$2"
                shift 2
                ;;
            --project-id)
                project_id="$2"
                shift 2
                ;;
            -l|--log-mode)
                log_mode="$2"
                shift 2
                ;;
            --demo)
                demo_mode="true"
                shift
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
        if [ "$demo_mode" = "false" ] && [ -z "$project_id" ]; then
            print_error "测试需要指定项目ID或使用演示模式，请使用 --project-id 参数或 --demo"
            exit 1
        fi
        test_api "$host" "$port" "$api_key"
        exit $?
    fi

    # 启动服务
    check_dependencies

    if [ "$demo_mode" = "false" ]; then
        check_gemini_auth "$gemini_file" "$project_id"
    else
        print_info "演示模式：跳过Google Cloud认证检查"
    fi

    if [ "$daemon_mode" = "false" ]; then
        check_port "$port"
    fi

    start_service "$api_key" "$host" "$port" "$gemini_file" "$project_id" "$log_mode" "$demo_mode" "$daemon_mode"
}

# 运行主函数
main "$@"
