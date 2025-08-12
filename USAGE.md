# AIClient-2-API 统一启动脚本使用指南

## 🚀 快速开始

### 1. 统一启动脚本功能

`start-api-server.sh` 是基于配置文件的统一启动脚本，支持多种AI服务提供商：

- ✅ **配置文件驱动**：通过 `providers-config.json` 管理所有服务提供商
- ✅ **多提供商支持**：Gemini Claude、Claude Kiro、OpenAI、Claude Custom
- ✅ **自动依赖检查**：检查 Node.js、jq 和项目依赖
- ✅ **认证文件验证**：自动验证各种认证文件格式
- ✅ **后台运行**：支持后台守护进程模式
- ✅ **服务管理**：启动、停止、状态检查
- ✅ **API测试**：内置多格式API功能测试
- ✅ **彩色输出**：友好的命令行界面

### 2. 查看可用服务提供商

```bash
# 列出所有可用的服务提供商
./start-api-server.sh --list-providers
```

输出示例：
```
[PROVIDER] 🌟 gemini-claude (默认)
     名称: Gemini via Claude API
     描述: 通过Claude API格式访问Gemini模型
     后端: gemini-cli-oauth
     特点:
       • Claude API兼容格式
       • Gemini CLI OAuth免费额度
       • 支持gemini-2.5-pro和gemini-2.5-flash模型

[PROVIDER]    claude-kiro
     名称: Claude via Kiro OAuth
     描述: 通过Kiro OAuth访问Claude模型
     后端: claude-kiro-oauth
     特点:
       • 免费使用Claude Sonnet 4模型
       • OpenAI API兼容格式
       • Kiro OAuth认证
```

### 3. 基本用法

```bash
# 显示帮助信息
./start-api-server.sh -h

# 启动所有服务（默认）
./start-api-server.sh

# 明确启动所有服务
./start-api-server.sh --all

# 指定单个提供商启动
./start-api-server.sh --provider gemini-claude
./start-api-server.sh --provider claude-kiro

# 后台运行所有服务
./start-api-server.sh -d

# 后台运行单个服务
./start-api-server.sh --provider gemini-claude -d

# 检查所有服务状态
./start-api-server.sh -s

# 测试所有服务功能
./start-api-server.sh -t

# 测试单个服务功能
./start-api-server.sh -t --provider gemini-claude

# 停止所有后台服务
./start-api-server.sh --stop
```

### 4. 高级用法

```bash
# 自定义配置启动
./start-api-server.sh --provider gemini-claude -k myapikey -p 8080 --host 127.0.0.1

# 启用文件日志
./start-api-server.sh --provider claude-kiro -l file -d

# 覆盖配置文件中的设置
./start-api-server.sh --provider gemini-claude --port 8080 --log-mode file
```

## 📋 配置文件说明

### providers-config.json 结构

```json
{
  "providers": {
    "gemini-claude": {
      "name": "Gemini via Claude API",
      "model_provider": "gemini-cli-oauth",
      "oauth_file": "~/.gemini/oauth_creds.json",
      "description": "通过Claude API格式访问Gemini模型"
    },
    "claude-kiro": {
      "name": "Claude via Kiro OAuth",
      "model_provider": "claude-kiro-oauth",
      "oauth_file": "~/.aws/sso/cache/kiro-auth-token.json",
      "description": "通过Kiro OAuth访问Claude模型"
    }
  },
  "default_provider": "gemini-claude",
  "server": {
    "host": "0.0.0.0",
    "port": 3000,
    "api_key": "123456",
    "log_mode": "console"
  }
}
```

## 🛠️ 命令行选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--all` | 启动所有可用的服务提供商 | 默认行为 |
| `--provider PROVIDER` | 指定单个服务提供商 | - |
| `-k, --api-key KEY` | API密钥 | 从配置文件读取 |
| `--host HOST` | 监听地址 | 从配置文件读取 |
| `-p, --port PORT` | 监听端口 (仅单个服务时有效) | 从配置文件读取 |
| `-l, --log-mode MODE` | 日志模式 (console/file/none) | 从配置文件读取 |
| `-d, --daemon` | 后台运行模式 | - |
| `-s, --status` | 检查服务状态 | - |
| `-t, --test` | 测试API功能 | - |
| `--list-providers` | 列出所有可用提供商 | - |
| `--stop` | 停止所有后台服务 | - |
| `-h, --help` | 显示帮助信息 | - |

## 🌐 服务端口分配

| 服务提供商 | 端口 | API格式 | 描述 |
|------------|------|---------|------|
| gemini-claude | 3000 | Claude API | 通过Claude API格式访问Gemini模型 |
| claude-kiro | 3001 | OpenAI API | 通过Kiro OAuth访问Claude模型 |
| openai-custom | 3002 | OpenAI API | 使用自定义OpenAI API密钥 |
| claude-custom | 3003 | Claude API | 使用自定义Claude API密钥 |

## 🌐 API 使用指南

### 1. 健康检查

```bash
curl http://localhost:3000/health
```

### 2. 获取模型列表

```bash
curl -H "x-api-key: 123456" http://localhost:3000/v1/models
```

## 🎯 各服务提供商API示例

### Gemini Claude (gemini-claude)

**支持的端点**: `/v1/messages`, `/v1/models`
**API格式**: Claude API 兼容

#### 获取模型列表
```bash
curl -H "x-api-key: 123456" http://localhost:3000/v1/models
```

#### 聊天对话（Claude格式）
```bash
curl -X POST http://localhost:3000/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: 123456" \
  -d '{
    "model": "gemini-2.5-pro",
    "messages": [
      {
        "role": "user",
        "content": "Hello! How are you?"
      }
    ],
    "max_tokens": 100
  }'
```

#### 流式聊天
```bash
curl -X POST http://localhost:3000/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: 123456" \
  -d '{
    "model": "gemini-2.5-pro",
    "messages": [
      {
        "role": "user",
        "content": "Tell me a story"
      }
    ],
    "max_tokens": 200,
    "stream": true
  }'
```

### Claude Kiro (claude-kiro)

**支持的端点**: `/v1/chat/completions`, `/v1/models`
**API格式**: OpenAI API 兼容

#### 聊天对话（OpenAI格式）
```bash
curl -X POST http://localhost:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-api-key: 123456" \
  -d '{
    "model": "claude-3-5-sonnet-20241022",
    "messages": [
      {
        "role": "user",
        "content": "Hello! How are you?"
      }
    ],
    "max_tokens": 100
  }'
```

## 📊 支持的模型

### Gemini Claude 提供商
- `gemini-2.5-pro` - Gemini 2.5 Pro (推荐)
- `gemini-2.5-flash` - Gemini 2.5 Flash (快速)

### Claude Kiro 提供商
- `claude-3-5-sonnet-20241022` - Claude 3.5 Sonnet (推荐)
- `claude-3-5-haiku-20241022` - Claude 3.5 Haiku (快速)

## 🔧 认证配置

### Gemini Claude 认证

1. **安装 Gemini CLI**:
   ```bash
   npm install -g @google/generative-ai-cli
   ```

2. **完成OAuth认证**:
   ```bash
   gemini auth
   ```

3. **验证认证文件**:
   ```bash
   ls -la ~/.gemini/oauth_creds.json
   ```

### Claude Kiro 认证

1. **获取Kiro认证令牌** (具体步骤请参考Kiro文档)

2. **验证认证文件**:
   ```bash
   ls -la ~/.aws/sso/cache/kiro-auth-token.json
   ```

## 💻 客户端配置

### Claude API 兼容客户端 (Gemini Claude)
- **API Base URL**: `http://localhost:3000/v1`
- **API Key**: `123456` (或您设置的密钥)
- **Model**: `gemini-2.5-pro`
- **API格式**: Claude Messages API

### OpenAI API 兼容客户端 (Claude Kiro)
- **API Base URL**: `http://localhost:3000/v1`
- **API Key**: `123456` (或您设置的密钥)
- **Model**: `claude-3-5-sonnet-20241022`
- **API格式**: OpenAI Chat Completions API

### 支持的客户端
- **Claude格式**: Claude官方客户端、支持Claude API的应用
- **OpenAI格式**: LobeChat、NextChat、ChatGPT-Next-Web、OpenAI官方客户端

## 🔍 故障排除

### 1. 认证问题

#### Gemini Claude 认证
```bash
# 检查Gemini认证文件
ls -la ~/.gemini/oauth_creds.json

# 检查文件格式
jq . ~/.gemini/oauth_creds.json

# 重新认证
gemini auth
```

#### Claude Kiro 认证
```bash
# 检查Kiro认证文件
ls -la ~/.aws/sso/cache/kiro-auth-token.json

# 检查文件格式
jq . ~/.aws/sso/cache/kiro-auth-token.json
```

### 2. 端口占用
```bash
# 检查端口占用
lsof -i :3000

# 使用其他端口
./start-api-server.sh --provider gemini-claude -p 8080
```

### 3. 服务日志
```bash
# 查看后台服务日志
tail -f api-server.log

# 实时查看日志
./start-api-server.sh --provider gemini-claude -l console
```

### 4. 服务管理
```bash
# 检查服务状态
./start-api-server.sh -s

# 停止服务
./start-api-server.sh --stop

# 重启服务
./start-api-server.sh --stop && ./start-api-server.sh --provider gemini-claude -d
```

## 📁 文件说明

- `start-api-server.sh` - 统一启动脚本
- `providers-config.json` - 服务提供商配置文件
- `api-server.log` - 后台服务日志文件
- `api-server.pid` - 后台服务PID文件
- `~/.gemini/oauth_creds.json` - Gemini认证文件
- `~/.aws/sso/cache/kiro-auth-token.json` - Kiro认证文件

## 🎯 常见使用场景

### 1. 开发测试
```bash
# 前台运行，便于调试
./start-api-server.sh --provider gemini-claude -l console
```

### 2. 生产部署
```bash
# 后台运行，启用文件日志
./start-api-server.sh --provider gemini-claude -d -l file
```

### 3. 多服务部署
```bash
# 启动Gemini Claude服务
./start-api-server.sh --provider gemini-claude -p 3001 -d

# 启动Claude Kiro服务
./start-api-server.sh --provider claude-kiro -p 3002 -d
```

### 4. 定期健康检查
```bash
# 添加到 crontab
*/5 * * * * /path/to/start-api-server.sh -s > /dev/null 2>&1
```

## ⚠️ 注意事项

### Gemini Claude
1. **认证文件**：确保 `~/.gemini/oauth_creds.json` 文件存在且有效
2. **网络访问**：服务需要访问 Google AI 服务
3. **Token刷新**：服务会自动刷新过期的访问令牌
4. **免费额度**：使用个人Google账户免费额度

### Claude Kiro
1. **认证文件**：确保 `kiro-auth-token.json` 文件存在且有效
2. **网络访问**：服务需要访问 AWS CodeWhisperer 服务
3. **新用户限制**：新注册的 Kiro 用户可能遇到 429 错误

## 🔄 更新和维护

```bash
# 更新项目代码
git pull origin main

# 重新安装依赖
npm install

# 重启服务
./start-api-server.sh --stop
./start-api-server.sh --provider gemini-claude -d
```

## 🚀 快速切换提供商

```bash
# 停止当前服务
./start-api-server.sh --stop

# 切换到Gemini Claude
./start-api-server.sh --provider gemini-claude -d

# 切换到Claude Kiro
./start-api-server.sh --provider claude-kiro -d
```

---

**享受使用多种AI模型的强大功能！** 🎉
