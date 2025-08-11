# Gemini to Claude Proxy 使用指南

## 🎯 项目概述

Gemini to Claude Proxy 是一个创新的API代理服务，允许用户通过熟悉的Claude API格式来访问Google Gemini模型。这个解决方案结合了两个世界的优势：

- **Gemini CLI OAuth的优势**: 免费额度、高频率访问、无需付费API密钥
- **Claude API的便利性**: 标准化接口、广泛的客户端支持、简洁的请求格式

## 🚀 核心功能

### **认证转换**
- **输入**: Claude API的x-api-key认证格式
- **内部**: 使用Gemini CLI OAuth进行实际API调用
- **优势**: 用户无需管理Google Cloud认证复杂性

### **请求格式转换**
- **输入**: Claude API格式 (`/v1/messages`)
- **处理**: 自动转换为Gemini API格式
- **输出**: Claude API兼容的响应格式

### **支持的功能**
- ✅ 非流式聊天对话
- ✅ 流式聊天对话
- ✅ 模型列表获取
- ✅ 错误处理和格式转换
- ✅ 完整的日志记录

## 📋 前置要求

### 1. 系统要求
- Node.js >= 20.0.0
- Google Cloud CLI (推荐)
- jq (JSON处理工具)

### 2. Google Cloud 设置
```bash
# 安装 Google Cloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 认证
gcloud auth application-default login

# 设置项目
gcloud config set project YOUR_PROJECT_ID
```

### 3. 项目依赖
```bash
# 安装项目依赖
npm install
```

## 🛠️ 快速开始

### 1. 基本启动
```bash
# 使用默认配置启动
./start-gemini-claude-proxy.sh --project-id your-project-id

# 后台运行
./start-gemini-claude-proxy.sh --project-id your-project-id -d

# 自定义端口和API密钥
./start-gemini-claude-proxy.sh --project-id your-project-id -p 8080 -k myapikey
```

### 2. 服务管理
```bash
# 检查服务状态
./start-gemini-claude-proxy.sh -s

# 测试API功能
./start-gemini-claude-proxy.sh -t --project-id your-project-id

# 停止后台服务
./start-gemini-claude-proxy.sh --stop
```

## 📡 API 使用示例

### 1. 健康检查
```bash
curl http://localhost:3001/health
```

**响应示例:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "provider": "gemini-claude-proxy"
}
```

### 2. 获取模型列表
```bash
curl -H "x-api-key: 123456" \
     http://localhost:3001/v1/models
```

**响应示例:**
```json
{
  "data": [
    {
      "id": "gemini-2.0-flash-exp",
      "object": "model",
      "created": 1704067200,
      "owned_by": "google",
      "type": "text",
      "display_name": "Gemini 2.0 Flash Experimental"
    },
    {
      "id": "gemini-1.5-pro",
      "object": "model",
      "created": 1704067200,
      "owned_by": "google",
      "type": "text",
      "display_name": "Gemini 1.5 Pro"
    }
  ]
}
```

### 3. Claude格式聊天对话（非流式）
```bash
curl -X POST http://localhost:3001/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: 123456" \
  -d '{
    "model": "gemini-1.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "Hello! Please introduce yourself."
      }
    ],
    "max_tokens": 100
  }'
```

**响应示例:**
```json
{
  "id": "msg_12345",
  "type": "message",
  "role": "assistant",
  "content": [
    {
      "type": "text",
      "text": "Hello! I'm Gemini, a large language model developed by Google..."
    }
  ],
  "model": "gemini-1.5-flash",
  "stop_reason": "end_turn",
  "stop_sequence": null,
  "usage": {
    "input_tokens": 10,
    "output_tokens": 25
  }
}
```

### 4. Claude格式流式对话
```bash
curl -X POST http://localhost:3001/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: 123456" \
  -d '{
    "model": "gemini-1.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "Tell me a short story"
      }
    ],
    "stream": true,
    "max_tokens": 200
  }'
```

**流式响应示例:**
```
data: {"type":"message_start","message":{"id":"msg_67890","type":"message","role":"assistant","content":[],"model":"gemini-1.5-flash"}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Once upon a time"}}

data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":", in a small village..."}}

data: {"type":"message_stop"}
```

## 🎯 支持的Gemini模型

| 模型名称 | 描述 | 特点 |
|---------|------|------|
| `gemini-2.0-flash-exp` | Gemini 2.0 Flash 实验版 | 最新功能，实验性 |
| `gemini-1.5-pro` | Gemini 1.5 Pro | 高性能，复杂任务 |
| `gemini-1.5-flash` | Gemini 1.5 Flash | 快速响应，日常使用 |
| `gemini-1.0-pro` | Gemini 1.0 Pro | 稳定版本 |

## 🔧 客户端配置

### OpenAI兼容客户端设置
由于使用Claude API格式，需要配置为Claude兼容客户端：

- **API Base URL**: `http://localhost:3001/v1`
- **API Key**: `123456` (或您设置的密钥)
- **API格式**: Claude API
- **端点**: `/v1/messages`

### 支持的客户端
- **Claude官方客户端** (如果支持自定义端点)
- **支持Claude API的第三方客户端**
- **自定义应用** (使用Claude API格式)

## 🔍 技术实现细节

### 架构设计
```
Client (Claude API) → Proxy Server → Gemini API
     ↓                    ↓              ↓
Claude格式请求 → 格式转换 → Gemini格式请求
Claude格式响应 ← 格式转换 ← Gemini格式响应
```

### 关键组件
1. **GeminiToClaudeAdapter**: 主要适配器类
2. **格式转换函数**: 重用现有的转换逻辑
3. **认证代理**: 处理认证格式转换
4. **流式处理**: 支持实时响应流

### 错误处理
- Gemini API错误自动转换为Claude格式
- 网络错误和超时处理
- 认证失败的友好提示

## 🚨 故障排除

### 1. 认证问题
```bash
# 检查Google Cloud认证
gcloud auth application-default print-access-token

# 重新认证
gcloud auth application-default login

# 检查项目ID
gcloud config get-value project
```

### 2. 端口占用
```bash
# 检查端口占用
lsof -i :3001

# 使用其他端口
./start-gemini-claude-proxy.sh --project-id your-project -p 8080
```

### 3. 服务日志
```bash
# 查看后台服务日志
tail -f gemini-claude-proxy.log

# 实时查看日志
./start-gemini-claude-proxy.sh --project-id your-project -l console
```

### 4. 常见错误

**错误**: `Project ID not specified`
**解决**: 使用 `--project-id` 参数指定Google Cloud项目ID

**错误**: `Authentication failed`
**解决**: 运行 `gcloud auth application-default login` 重新认证

**错误**: `Model not found`
**解决**: 检查模型名称是否正确，使用 `/v1/models` 端点查看可用模型

## 📊 性能优化

### 1. 连接池配置
服务自动管理HTTP连接池，优化并发请求性能。

### 2. 缓存策略
- 模型列表缓存
- 认证token缓存
- 减少不必要的API调用

### 3. 监控建议
```bash
# 定期健康检查
*/5 * * * * curl -s http://localhost:3001/health > /dev/null

# 日志轮转
logrotate /path/to/gemini-claude-proxy.log
```

## 🔒 安全考虑

### 1. API密钥管理
- 使用强密码作为API密钥
- 定期轮换API密钥
- 不要在日志中记录敏感信息

### 2. 网络安全
- 使用HTTPS（生产环境）
- 配置防火墙规则
- 限制访问IP范围

### 3. 认证文件保护
```bash
# 设置适当的文件权限
chmod 600 ~/.config/gcloud/application_default_credentials.json
```

## 🎉 使用场景

### 1. 开发测试
- 在Claude API客户端中测试Gemini模型
- 比较不同模型的响应质量
- 原型开发和概念验证

### 2. 成本优化
- 利用Gemini CLI OAuth的免费额度
- 减少API调用成本
- 高频率访问场景

### 3. 客户端兼容性
- 让只支持Claude API的应用使用Gemini
- 统一API接口管理
- 简化多模型集成

---

**🚀 享受通过Claude API格式使用Gemini模型的便利！**
