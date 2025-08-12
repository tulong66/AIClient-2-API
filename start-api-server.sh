#!/bin/bash

# AIClient-2-API 统一启动脚本
# 作者: AIClient-2-API
# 版本: 2.0
# 描述: 基于配置文件的统一AI服务启动脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
CONFIG_FILE="$PROJECT_DIR/providers-config.json"
PID_FILE="$PROJECT_DIR/api-server.pid"
LOG_FILE="$PROJECT_DIR/api-server.log"

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

print_provider() {
    echo -e "${CYAN}[PROVIDER]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo "AIClient-2-API 统一启动脚本 v2.0"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --provider PROVIDER      指定单个服务提供商"
    echo "  --all                    启动所有可用的服务提供商 (默认)"
    echo "  -k, --api-key KEY        API密钥 (覆盖配置文件)"
    echo "  --host HOST              监听地址 (覆盖配置文件)"
    echo "  -p, --port PORT          监听端口 (仅单个服务时有效)"
    echo "  -l, --log-mode MODE      日志模式: console/file/none (覆盖配置文件)"
    echo "  -d, --daemon             后台运行模式"
    echo "  -s, --status             检查服务状态"
    echo "  -t, --test               测试API功能"
    echo "  --list-providers         列出所有可用的服务提供商"
    echo "  --stop                   停止所有后台服务"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                                    # 启动所有服务 (默认)"
    echo "  $0 --all                             # 启动所有服务"
    echo "  $0 --provider gemini-claude          # 仅启动Gemini Claude服务"
    echo "  $0 --provider claude-kiro            # 仅启动Claude Kiro服务"
    echo "  $0 --list-providers                  # 查看所有可用提供商"
    echo "  $0 -d                                # 后台运行所有服务"
    echo "  $0 -s                                # 检查所有服务状态"
    echo "  $0 -t                                # 测试所有服务功能"
}

# 检查配置文件
check_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        print_info "请确保 providers-config.json 文件存在"
        exit 1
    fi
    
    # 检查JSON格式
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        print_error "配置文件格式无效 (不是有效的JSON)"
        exit 1
    fi
    
    print_success "配置文件检查通过"
}

# 列出所有可用的服务提供商
list_providers() {
    print_info "可用的服务提供商:"
    echo ""
    
    local providers=$(jq -r '.providers | keys[]' "$CONFIG_FILE")
    local default_provider=$(jq -r '.default_provider' "$CONFIG_FILE")
    
    for provider in $providers; do
        local name=$(jq -r ".providers.\"$provider\".name" "$CONFIG_FILE")
        local description=$(jq -r ".providers.\"$provider\".description" "$CONFIG_FILE")
        local model_provider=$(jq -r ".providers.\"$provider\".model_provider" "$CONFIG_FILE")
        
        if [ "$provider" = "$default_provider" ]; then
            print_provider "🌟 $provider (默认)"
        else
            print_provider "   $provider"
        fi
        
        echo "     名称: $name"
        echo "     描述: $description"
        echo "     后端: $model_provider"
        
        # 显示功能特点
        local features=$(jq -r ".providers.\"$provider\".features[]?" "$CONFIG_FILE" 2>/dev/null)
        if [ -n "$features" ]; then
            echo "     特点:"
            while IFS= read -r feature; do
                echo "       • $feature"
            done <<< "$features"
        fi
        echo ""
    done
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖..."
    
    # 检查 jq
    if ! command -v jq &> /dev/null; then
        print_error "jq 未安装，请先安装 jq 用于JSON处理"
        print_info "Ubuntu/Debian: sudo apt-get install jq"
        print_info "CentOS/RHEL: sudo yum install jq"
        print_info "macOS: brew install jq"
        exit 1
    fi
    
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

# 检查端口是否被占用
check_port() {
    local port="$1"
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_error "端口 $port 已被占用"
        print_info "请使用其他端口或停止占用该端口的进程"
        exit 1
    fi
}

# 检查服务状态
check_status() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            print_success "服务正在运行 (PID: $pid)"
            
            # 尝试获取服务信息
            local config_provider=$(jq -r '.default_provider' "$CONFIG_FILE" 2>/dev/null || echo "unknown")
            local config_port=$(jq -r '.server.port' "$CONFIG_FILE" 2>/dev/null || echo "3000")
            
            print_info "服务信息:"
            print_info "  提供商: $config_provider"
            print_info "  端口: $config_port"
            print_info "  PID文件: $PID_FILE"
            print_info "  日志文件: $LOG_FILE"
            
            return 0
        else
            print_warning "PID文件存在但进程未运行，清理PID文件"
            rm -f "$PID_FILE"
        fi
    fi
    
    print_info "服务未运行"
    return 1
}

# 停止服务
stop_service() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            print_info "停止服务 (PID: $pid)..."
            kill $pid

            # 等待进程结束
            local count=0
            while ps -p $pid > /dev/null 2>&1 && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done

            if ps -p $pid > /dev/null 2>&1; then
                print_warning "进程未正常结束，强制终止..."
                kill -9 $pid
            fi

            rm -f "$PID_FILE"
            print_success "服务已停止"
        else
            print_warning "PID文件存在但进程未运行，清理PID文件"
            rm -f "$PID_FILE"
        fi
    else
        print_info "服务未运行"
    fi
}

# 启动所有服务
start_all_services() {
    local api_key="$1"
    local host="$2"
    local log_mode="$3"
    local daemon_mode="$4"

    print_info "启动所有可用的 AIClient-2-API 服务..."
    print_feature "🚀 多服务模式"

    local providers=$(jq -r '.providers | keys[]' "$CONFIG_FILE")
    local started_services=()
    local failed_services=()

    for provider in $providers; do
        local provider_name=$(jq -r ".providers.\"$provider\".name" "$CONFIG_FILE")
        local provider_port=$(jq -r ".providers.\"$provider\".port" "$CONFIG_FILE")
        local api_key_required=$(jq -r ".providers.\"$provider\".api_key_required?" "$CONFIG_FILE")

        print_provider "启动 $provider_name (端口: $provider_port)"

        # 检查是否需要API密钥但未提供
        if [ "$api_key_required" = "true" ]; then
            local provider_api_key=""
            case "$provider" in
                "openai-custom")
                    provider_api_key=$(jq -r ".providers.\"$provider\".openai_api_key?" "$CONFIG_FILE")
                    ;;
                "claude-custom")
                    provider_api_key=$(jq -r ".providers.\"$provider\".claude_api_key?" "$CONFIG_FILE")
                    ;;
            esac

            if [ "$provider_api_key" = "null" ] || [ -z "$provider_api_key" ]; then
                print_warning "跳过 $provider_name - 需要API密钥但未配置"
                failed_services+=("$provider (需要API密钥)")
                continue
            fi
        fi

        # 检查端口是否被占用
        if lsof -Pi :$provider_port -sTCP:LISTEN -t >/dev/null 2>&1; then
            print_warning "跳过 $provider_name - 端口 $provider_port 已被占用"
            failed_services+=("$provider (端口占用)")
            continue
        fi

        # 启动服务
        if start_single_service "$provider" "$api_key" "$host" "$provider_port" "$log_mode" "$daemon_mode"; then
            started_services+=("$provider_name:$provider_port")
            sleep 1  # 避免同时启动太多服务
        else
            failed_services+=("$provider (启动失败)")
        fi
    done

    # 显示启动结果
    echo ""
    print_success "服务启动完成！"

    if [ ${#started_services[@]} -gt 0 ]; then
        print_feature "✅ 已启动的服务:"
        for service in "${started_services[@]}"; do
            local name=$(echo "$service" | cut -d':' -f1)
            local port=$(echo "$service" | cut -d':' -f2)
            print_feature "  • $name - http://$host:$port"
        done
    fi

    if [ ${#failed_services[@]} -gt 0 ]; then
        print_warning "⚠️  跳过的服务:"
        for service in "${failed_services[@]}"; do
            print_warning "  • $service"
        done
    fi

    echo ""
    print_info "使用 $0 -s 检查所有服务状态"
    print_info "使用 $0 --stop 停止所有服务"
}

# 启动单个服务
start_single_service() {
    local provider="$1"
    local api_key="$2"
    local host="$3"
    local port="$4"
    local log_mode="$5"
    local daemon_mode="$6"

    # 构建PID和日志文件名
    local pid_file="$PROJECT_DIR/api-server-$provider.pid"
    local log_file="$PROJECT_DIR/api-server-$provider.log"

    # 从配置文件获取提供商信息
    local model_provider=$(jq -r ".providers.\"$provider\".model_provider" "$CONFIG_FILE")

    # 构建启动命令
    local cmd="node src/api-server.js"
    cmd="$cmd --model-provider $model_provider"

    # 根据提供商类型添加特定参数
    case "$model_provider" in
        "gemini-cli-oauth")
            local oauth_file=$(jq -r ".providers.\"$provider\".oauth_file" "$CONFIG_FILE")
            oauth_file="${oauth_file/#\~/$HOME}"  # 展开 ~ 为 $HOME
            cmd="$cmd --gemini-oauth-creds-file $oauth_file"
            ;;
        "claude-kiro-oauth")
            local oauth_file=$(jq -r ".providers.\"$provider\".oauth_file" "$CONFIG_FILE")
            oauth_file="${oauth_file/#\~/$HOME}"  # 展开 ~ 为 $HOME
            cmd="$cmd --kiro-oauth-creds-file $oauth_file"
            ;;
        "openai-custom")
            local openai_key=$(jq -r ".providers.\"$provider\".openai_api_key?" "$CONFIG_FILE")
            if [ "$openai_key" != "null" ] && [ -n "$openai_key" ]; then
                cmd="$cmd --openai-api-key $openai_key"
            fi
            ;;
        "claude-custom")
            local claude_key=$(jq -r ".providers.\"$provider\".claude_api_key?" "$CONFIG_FILE")
            if [ "$claude_key" != "null" ] && [ -n "$claude_key" ]; then
                cmd="$cmd --claude-api-key $claude_key"
            fi
            ;;
    esac

    cmd="$cmd --api-key $api_key"
    cmd="$cmd --host $host"
    cmd="$cmd --port $port"
    cmd="$cmd --log-prompts $log_mode"

    if [ "$daemon_mode" = "true" ]; then
        cd "$PROJECT_DIR"
        nohup $cmd > "$log_file" 2>&1 &
        local pid=$!
        echo $pid > "$pid_file"

        # 等待服务启动
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    else
        cd "$PROJECT_DIR"
        exec $cmd
    fi
}

# 启动服务
start_service() {
    local provider="$1"
    local api_key="$2"
    local host="$3"
    local port="$4"
    local log_mode="$5"
    local daemon_mode="$6"

    # 从配置文件获取提供商信息
    local provider_name=$(jq -r ".providers.\"$provider\".name" "$CONFIG_FILE")
    local model_provider=$(jq -r ".providers.\"$provider\".model_provider" "$CONFIG_FILE")
    local description=$(jq -r ".providers.\"$provider\".description" "$CONFIG_FILE")

    print_info "启动 AIClient-2-API 服务..."
    print_provider "🚀 $provider_name"
    print_info "描述: $description"

    # 显示功能特点
    local features=$(jq -r ".providers.\"$provider\".features[]?" "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$features" ]; then
        print_feature "🎯 功能特点:"
        while IFS= read -r feature; do
            print_feature "  • $feature"
        done <<< "$features"
    fi

    print_info "配置信息:"
    print_info "  提供商: $provider"
    print_info "  后端: $model_provider"
    print_info "  API密钥: $api_key"
    print_info "  监听地址: $host:$port"
    print_info "  日志模式: $log_mode"

    # 构建启动命令
    local cmd="node src/api-server.js"
    cmd="$cmd --model-provider $model_provider"

    # 根据提供商类型添加特定参数
    case "$model_provider" in
        "gemini-cli-oauth")
            local oauth_file=$(jq -r ".providers.\"$provider\".oauth_file" "$CONFIG_FILE")
            oauth_file="${oauth_file/#\~/$HOME}"  # 展开 ~ 为 $HOME
            cmd="$cmd --gemini-oauth-creds-file $oauth_file"
            print_info "  认证文件: $oauth_file"
            ;;
        "claude-kiro-oauth")
            local oauth_file=$(jq -r ".providers.\"$provider\".oauth_file" "$CONFIG_FILE")
            oauth_file="${oauth_file/#\~/$HOME}"  # 展开 ~ 为 $HOME
            cmd="$cmd --kiro-oauth-creds-file $oauth_file"
            print_info "  认证文件: $oauth_file"
            ;;
        "openai-custom")
            local openai_key=$(jq -r ".providers.\"$provider\".openai_api_key?" "$CONFIG_FILE")
            if [ "$openai_key" != "null" ] && [ -n "$openai_key" ]; then
                cmd="$cmd --openai-api-key $openai_key"
            fi
            ;;
        "claude-custom")
            local claude_key=$(jq -r ".providers.\"$provider\".claude_api_key?" "$CONFIG_FILE")
            if [ "$claude_key" != "null" ] && [ -n "$claude_key" ]; then
                cmd="$cmd --claude-api-key $claude_key"
            fi
            ;;
    esac

    cmd="$cmd --api-key $api_key"
    cmd="$cmd --host $host"
    cmd="$cmd --port $port"
    cmd="$cmd --log-prompts $log_mode"

    print_info "启动命令: $cmd"

    if [ "$daemon_mode" = "true" ]; then
        print_info "以后台模式启动服务..."
        cd "$PROJECT_DIR"
        nohup $cmd > "$LOG_FILE" 2>&1 &
        local pid=$!
        echo $pid > "$PID_FILE"

        # 等待服务启动
        sleep 2
        if ps -p $pid > /dev/null 2>&1; then
            print_success "服务已在后台启动 (PID: $pid)"
            print_info "日志文件: $LOG_FILE"
            print_info "PID文件: $PID_FILE"
        else
            print_error "服务启动失败"
            rm -f "$PID_FILE"
            exit 1
        fi
    else
        print_info "以前台模式启动服务..."
        cd "$PROJECT_DIR"
        exec $cmd
    fi

    print_info "服务地址: http://$host:$port"

    # 显示支持的端点
    local endpoints=$(jq -r ".providers.\"$provider\".supported_endpoints[]?" "$CONFIG_FILE" 2>/dev/null)
    if [ -n "$endpoints" ]; then
        print_feature "支持的API端点:"
        while IFS= read -r endpoint; do
            print_feature "  • http://$host:$port$endpoint"
        done <<< "$endpoints"
    fi
}

# 测试API功能
test_api() {
    local provider="$1"
    local host="$2"
    local port="$3"
    local api_key="$4"

    print_info "测试 API 功能..."

    local base_url="http://$host:$port"
    local model_provider=$(jq -r ".providers.\"$provider\".model_provider" "$CONFIG_FILE")

    # 测试健康检查
    print_info "1. 测试健康检查..."
    local health_response=$(curl -s "$base_url/health" 2>/dev/null)
    if [ $? -eq 0 ] && [[ "$health_response" == *"OK"* ]]; then
        print_success "健康检查通过"
    else
        print_error "健康检查失败"
        return 1
    fi

    # 测试模型列表
    print_info "2. 测试模型列表..."
    local models_response=$(curl -s -H "x-api-key: $api_key" "$base_url/v1/models" 2>/dev/null)
    if [ $? -eq 0 ] && [[ "$models_response" == *"data"* ]]; then
        print_success "模型列表获取成功"
        local model_count=$(echo "$models_response" | jq '.data | length' 2>/dev/null || echo "0")
        print_info "可用模型数量: $model_count"
    else
        print_error "模型列表获取失败"
        return 1
    fi

    # 根据提供商类型测试聊天功能
    print_info "3. 测试聊天功能..."
    case "$model_provider" in
        "gemini-cli-oauth")
            test_claude_format_chat "$base_url" "$api_key" "gemini-2.5-pro"
            ;;
        "claude-kiro-oauth")
            test_openai_format_chat "$base_url" "$api_key" "claude-3-5-sonnet-20241022"
            ;;
        "openai-custom")
            test_openai_format_chat "$base_url" "$api_key" "gpt-3.5-turbo"
            ;;
        "claude-custom")
            test_claude_format_chat "$base_url" "$api_key" "claude-3-5-sonnet-20241022"
            ;;
        *)
            print_warning "未知的提供商类型，跳过聊天测试"
            ;;
    esac

    print_success "API功能测试完成"
}

# 测试Claude格式聊天
test_claude_format_chat() {
    local base_url="$1"
    local api_key="$2"
    local model="$3"

    local response=$(curl -s -X POST "$base_url/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [
                {
                    \"role\": \"user\",
                    \"content\": \"Hello! Please respond with just: API TEST OK\"
                }
            ],
            \"max_tokens\": 50
        }" 2>/dev/null)

    if [ $? -eq 0 ] && [[ "$response" == *"message"* ]]; then
        print_success "Claude格式聊天功能测试成功"
        local content=$(echo "$response" | jq -r '.content[0].text' 2>/dev/null || echo "响应内容解析失败")
        print_info "响应内容: $content"
    else
        print_error "Claude格式聊天功能测试失败"
        print_info "响应: $response"
    fi
}

# 测试OpenAI格式聊天
test_openai_format_chat() {
    local base_url="$1"
    local api_key="$2"
    local model="$3"

    local response=$(curl -s -X POST "$base_url/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $api_key" \
        -d "{
            \"model\": \"$model\",
            \"messages\": [
                {
                    \"role\": \"user\",
                    \"content\": \"Hello! Please respond with just: API TEST OK\"
                }
            ],
            \"max_tokens\": 50
        }" 2>/dev/null)

    if [ $? -eq 0 ] && [[ "$response" == *"choices"* ]]; then
        print_success "OpenAI格式聊天功能测试成功"
        local content=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null || echo "响应内容解析失败")
        print_info "响应内容: $content"
    else
        print_error "OpenAI格式聊天功能测试失败"
        print_info "响应: $response"
    fi
}

# 主函数
main() {
    # 默认配置
    local provider=""
    local all_providers="false"
    local api_key=""
    local host=""
    local port=""
    local log_mode=""
    local daemon_mode="false"
    local show_status="false"
    local run_test="false"
    local stop_service_flag="false"
    local list_providers_flag="false"

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --provider)
                provider="$2"
                shift 2
                ;;
            --all)
                all_providers="true"
                shift
                ;;
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
            --list-providers)
                list_providers_flag="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查配置文件
    check_config_file

    # 处理特殊命令
    if [ "$list_providers_flag" = "true" ]; then
        list_providers
        exit 0
    fi

    if [ "$show_status" = "true" ]; then
        check_status
        exit $?
    fi

    if [ "$stop_service_flag" = "true" ]; then
        stop_service
        exit 0
    fi

    # 从配置文件读取默认值
    if [ -z "$api_key" ]; then
        api_key=$(jq -r '.server.api_key' "$CONFIG_FILE")
    fi

    if [ -z "$host" ]; then
        host=$(jq -r '.server.host' "$CONFIG_FILE")
    fi

    if [ -z "$log_mode" ]; then
        log_mode=$(jq -r '.server.log_mode' "$CONFIG_FILE")
    fi

    # 确定启动模式：单个服务还是所有服务
    local default_mode=$(jq -r '.default_mode' "$CONFIG_FILE")

    if [ -n "$provider" ]; then
        # 指定了单个提供商
        all_providers="false"
    elif [ "$all_providers" = "true" ]; then
        # 明确指定启动所有服务
        all_providers="true"
    elif [ "$default_mode" = "all" ]; then
        # 配置文件默认启动所有服务
        all_providers="true"
    else
        # 使用默认提供商
        all_providers="false"
        provider=$(jq -r '.default_provider' "$CONFIG_FILE")
    fi

    if [ "$run_test" = "true" ]; then
        if [ "$all_providers" = "true" ]; then
            print_info "测试所有服务..."
            local providers=$(jq -r '.providers | keys[]' "$CONFIG_FILE")
            for test_provider in $providers; do
                local test_port=$(jq -r ".providers.\"$test_provider\".port" "$CONFIG_FILE")
                print_info "测试 $test_provider (端口: $test_port)"
                test_api "$test_provider" "$host" "$test_port" "$api_key"
            done
        else
            test_api "$provider" "$host" "$port" "$api_key"
        fi
        exit $?
    fi

    # 启动服务
    check_dependencies

    if [ "$all_providers" = "true" ]; then
        # 启动所有服务
        start_all_services "$api_key" "$host" "$log_mode" "$daemon_mode"
    else
        # 启动单个服务
        if [ -z "$port" ]; then
            port=$(jq -r ".providers.\"$provider\".port" "$CONFIG_FILE")
        fi

        # 验证提供商是否存在
        local provider_exists=$(jq -r ".providers.\"$provider\"" "$CONFIG_FILE")
        if [ "$provider_exists" = "null" ]; then
            print_error "未知的服务提供商: $provider"
            print_info "使用 --list-providers 查看所有可用的提供商"
            exit 1
        fi

        if [ "$daemon_mode" = "false" ]; then
            check_port "$port"
        fi

        start_service "$provider" "$api_key" "$host" "$port" "$log_mode" "$daemon_mode"
    fi
}

# 设置脚本可执行权限提醒
if [ ! -x "$0" ]; then
    print_warning "脚本没有执行权限，请运行: chmod +x $0"
fi

# 运行主函数
main "$@"
