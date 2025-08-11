# AIClient-2-API Claude Kiro OAuth 使用指南

## 快速开始

### 1. 启动脚本功能

`start-claude-kiro.sh` 是一个便捷的启动脚本，提供以下功能：

- ✅ **自动依赖检查**：检查 Node.js 版本和项目依赖
- ✅ **认证文件验证**：验证 Kiro 认证文件格式和有效性
- ✅ **后台运行**：支持后台守护进程模式
- ✅ **服务管理**：启动、停止、状态检查
- ✅ **API测试**：内置API功能测试
- ✅ **彩色输出**：友好的命令行界面

### 2. 基本用法

```bash
# 显示帮助信息
./start-claude-kiro.sh -h

# 使用默认配置启动（前台运行）
./start-claude-kiro.sh

# 后台运行
./start-claude-kiro.sh -d

# 检查服务状态
./start-claude-kiro.sh -s

# 测试API功能
./start-claude-kiro.sh -t

# 停止后台服务
./start-claude-kiro.sh --stop
```

### 3. 高级用法

```bash
# 自定义配置启动
./start-claude-kiro.sh -k myapikey -p 8080 --host 127.0.0.1

# 指定认证文件路径
./start-claude-kiro.sh -f /path/to/kiro-auth-token.json

# 启用文件日志
./start-claude-kiro.sh -l file -d
```

## 配置选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-k, --api-key` | API密钥 | `123456` |
| `--host` | 监听地址 | `0.0.0.0` |
| `-p, --port` | 监听端口 | `3000` |
| `-f, --kiro-file` | Kiro认证文件路径 | `~/.aws/sso/cache/kiro-auth-token.json` |
| `-l, --log-mode` | 日志模式 | `console` |
| `-d, --daemon` | 后台运行模式 | - |
| `-s, --status` | 检查服务状态 | - |
| `-t, --test` | 测试API功能 | - |
| `--stop` | 停止后台服务 | - |
| `-h, --help` | 显示帮助信息 | - |

## API 使用

### 1. 健康检查
```bash
curl http://localhost:3000/health
```

### 2. 获取模型列表
```bash
curl -H "Authorization: Bearer 123456" \
     http://localhost:3000/v1/models
```

### 3. 聊天对话（非流式）
```bash
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 123456" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ],
    "stream": false
  }'
```

### 4. 聊天对话（流式）
```bash
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 123456" \
  -d '{
    "model": "claude-sonnet-4-20250514",
    "messages": [
      {"role": "user", "content": "Tell me a story"}
    ],
    "stream": true
  }'
```

## 支持的模型

- `claude-sonnet-4-20250514` - Claude Sonnet 4 (推荐)
- `claude-3-7-sonnet-20250219` - Claude 3.7 Sonnet
- `amazonq-claude-sonnet-4-20250514` - Amazon Q Claude Sonnet 4
- `amazonq-claude-3-7-sonnet-20250219` - Amazon Q Claude 3.7 Sonnet

## 客户端配置

### OpenAI 兼容客户端设置
- **API Base URL**: `http://localhost:3000/v1`
- **API Key**: `123456` (或您设置的密钥)
- **Model**: `claude-sonnet-4-20250514`

### 支持的客户端
- LobeChat
- NextChat
- ChatGPT-Next-Web
- OpenAI官方客户端
- 任何支持OpenAI API的应用

## 故障排除

### 1. 认证问题
```bash
# 检查认证文件是否存在
ls -la ~/.aws/sso/cache/kiro-auth-token.json

# 检查文件格式
jq . ~/.aws/sso/cache/kiro-auth-token.json
```

### 2. 端口占用
```bash
# 检查端口占用
lsof -i :3000

# 使用其他端口
./start-claude-kiro.sh -p 8080
```

### 3. 服务日志
```bash
# 查看后台服务日志
tail -f claude-kiro-service.log

# 实时查看日志
./start-claude-kiro.sh -l console
```

### 4. 网络代理
如果需要代理访问：
```bash
export HTTP_PROXY="http://your_proxy:port"
./start-claude-kiro.sh
```

## 文件说明

- `start-claude-kiro.sh` - 主启动脚本
- `claude-kiro-service.log` - 后台服务日志文件
- `claude-kiro-service.pid` - 后台服务PID文件
- `~/.aws/sso/cache/kiro-auth-token.json` - Kiro认证文件

## 常见使用场景

### 1. 开发测试
```bash
# 前台运行，便于调试
./start-claude-kiro.sh -l console
```

### 2. 生产部署
```bash
# 后台运行，启用文件日志
./start-claude-kiro.sh -d -l file
```

### 3. 多端口部署
```bash
# 启动多个实例
./start-claude-kiro.sh -p 3001 -d
./start-claude-kiro.sh -p 3002 -d
```

### 4. 定期健康检查
```bash
# 添加到 crontab
*/5 * * * * /path/to/start-claude-kiro.sh -s > /dev/null 2>&1
```

## 注意事项

1. **认证文件**：确保 `kiro-auth-token.json` 文件存在且有效
2. **网络访问**：服务需要访问 AWS CodeWhisperer 服务
3. **Token刷新**：服务会自动刷新过期的访问令牌
4. **资源使用**：Claude Sonnet 4 通过 Kiro API 免费使用，但可能有使用限制
5. **新用户限制**：新注册的 Kiro 用户可能遇到 429 错误

## 更新和维护

```bash
# 更新项目代码
git pull origin main

# 重新安装依赖
npm install

# 重启服务
./start-claude-kiro.sh --stop
./start-claude-kiro.sh -d
```

---

**享受使用 Claude Sonnet 4 的强大功能！** 🚀
