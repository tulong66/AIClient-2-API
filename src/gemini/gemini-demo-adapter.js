import { v4 as uuidv4 } from 'uuid';

/**
 * Gemini Demo Adapter - 演示模式
 * 
 * 这个适配器模拟Gemini API响应，用于演示Gemini to Claude Proxy的功能
 * 无需真实的Google Cloud认证，适合测试和演示
 */
export class GeminiDemoAdapter {
    constructor(config) {
        this.config = config;
        this.isInitialized = true;
        
        // 模拟的Gemini模型列表
        this.demoModels = [
            {
                name: 'models/gemini-2.0-flash-exp',
                displayName: 'Gemini 2.0 Flash Experimental',
                description: 'Latest experimental version with enhanced capabilities'
            },
            {
                name: 'models/gemini-1.5-pro',
                displayName: 'Gemini 1.5 Pro',
                description: 'High-performance model for complex tasks'
            },
            {
                name: 'models/gemini-1.5-flash',
                displayName: 'Gemini 1.5 Flash',
                description: 'Fast and efficient model for everyday use'
            },
            {
                name: 'models/gemini-1.0-pro',
                displayName: 'Gemini 1.0 Pro',
                description: 'Stable and reliable model'
            }
        ];
        
        console.log('[Gemini Demo] Demo adapter initialized with mock models');
    }

    /**
     * 模拟生成内容
     */
    async generateContent(model, claudeRequestBody) {
        console.log(`[Gemini Demo] Processing Claude format request for model: ${model}`);
        
        // 模拟处理延迟
        await this.delay(500);
        
        // 提取用户消息
        const userMessage = this.extractUserMessage(claudeRequestBody);
        
        // 生成模拟响应
        const mockResponse = this.generateMockResponse(userMessage, model);
        
        // 转换为Claude格式
        const claudeResponse = this.convertToClaudeFormat(mockResponse, model);
        
        console.log(`[Gemini Demo] Generated mock response in Claude format`);
        return claudeResponse;
    }

    /**
     * 模拟流式生成内容
     */
    async *generateContentStream(model, claudeRequestBody) {
        console.log(`[Gemini Demo] Processing streaming Claude format request for model: ${model}`);
        
        const userMessage = this.extractUserMessage(claudeRequestBody);
        const messageId = `msg_${uuidv4()}`;
        
        // 发送消息开始事件
        yield {
            type: "message_start",
            message: {
                id: messageId,
                type: "message",
                role: "assistant",
                content: [],
                model: model,
                stop_reason: null,
                stop_sequence: null,
                usage: {
                    input_tokens: 0,
                    output_tokens: 0
                }
            }
        };

        // 生成模拟响应文本
        const responseText = this.generateMockResponse(userMessage, model);
        const words = responseText.split(' ');
        
        // 逐词发送流式响应
        for (let i = 0; i < words.length; i++) {
            await this.delay(50); // 模拟流式延迟
            
            const word = words[i] + (i < words.length - 1 ? ' ' : '');
            
            yield {
                type: "content_block_delta",
                index: 0,
                delta: {
                    type: "text_delta",
                    text: word
                }
            };
        }

        // 发送消息结束事件
        yield {
            type: "message_delta",
            delta: {
                stop_reason: "end_turn",
                stop_sequence: null
            },
            usage: {
                output_tokens: words.length
            }
        };

        yield {
            type: "message_stop"
        };
    }

    /**
     * 返回模拟的模型列表
     */
    async listModels() {
        console.log(`[Gemini Demo] Returning mock model list`);
        
        return {
            models: this.demoModels
        };
    }

    /**
     * 模拟token刷新
     */
    async refreshToken() {
        console.log(`[Gemini Demo] Mock token refresh completed`);
        return Promise.resolve();
    }

    /**
     * 提取用户消息内容
     */
    extractUserMessage(claudeRequestBody) {
        if (!claudeRequestBody.messages || claudeRequestBody.messages.length === 0) {
            return "Hello";
        }
        
        const lastMessage = claudeRequestBody.messages[claudeRequestBody.messages.length - 1];
        return lastMessage.content || "Hello";
    }

    /**
     * 生成模拟响应
     */
    generateMockResponse(userMessage, model) {
        const responses = {
            greeting: [
                `Hello! I'm ${model}, a demo version of Gemini running through the Claude API proxy. How can I help you today?`,
                `Hi there! This is ${model} responding through the Gemini-Claude proxy in demo mode. What would you like to know?`,
                `Greetings! I'm ${model} (demo mode) accessible via Claude API format. How may I assist you?`
            ],
            test: [
                `Gemini-Claude Proxy Test OK! This response is from ${model} in demo mode.`,
                `Test successful! ${model} is working correctly through the Claude API proxy.`,
                `Demo test passed! ${model} responding via Gemini-Claude proxy.`
            ],
            story: [
                `Once upon a time, in a digital realm where APIs spoke different languages, there was a clever proxy that could translate between Gemini and Claude formats. This proxy, powered by ${model}, made it possible for applications to use Gemini's capabilities through Claude's familiar interface. And they all lived efficiently ever after!`,
                `Here's a short story: A developer wanted to use Gemini models in their Claude-compatible application. Thanks to the Gemini-Claude proxy running ${model}, they could seamlessly access Gemini's power without changing their existing code. The end!`
            ],
            default: [
                `This is ${model} responding in demo mode through the Gemini-Claude proxy. Your message was: "${userMessage}". This demonstrates how Gemini models can be accessed using Claude API format!`,
                `Hello from ${model}! I'm running in demo mode to showcase the Gemini-Claude proxy functionality. You said: "${userMessage}". Pretty cool how this works, right?`,
                `${model} here (demo version)! I received your message: "${userMessage}". This proxy allows you to use Gemini models through Claude's API format - no authentication needed in demo mode!`
            ]
        };

        const lowerMessage = userMessage.toLowerCase();
        
        if (lowerMessage.includes('hello') || lowerMessage.includes('hi') || lowerMessage.includes('greet')) {
            return this.randomChoice(responses.greeting);
        } else if (lowerMessage.includes('test')) {
            return this.randomChoice(responses.test);
        } else if (lowerMessage.includes('story') || lowerMessage.includes('tale')) {
            return this.randomChoice(responses.story);
        } else {
            return this.randomChoice(responses.default);
        }
    }

    /**
     * 转换为Claude格式响应
     */
    convertToClaudeFormat(responseText, model) {
        return {
            id: `msg_${uuidv4()}`,
            type: "message",
            role: "assistant",
            content: [
                {
                    type: "text",
                    text: responseText
                }
            ],
            model: model,
            stop_reason: "end_turn",
            stop_sequence: null,
            usage: {
                input_tokens: 10,
                output_tokens: responseText.split(' ').length
            }
        };
    }

    /**
     * 随机选择响应
     */
    randomChoice(array) {
        return array[Math.floor(Math.random() * array.length)];
    }

    /**
     * 延迟函数
     */
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * 转换错误为Claude格式
     */
    convertErrorToClaudeFormat(error) {
        const claudeError = new Error();
        claudeError.status = 500;
        claudeError.type = 'api_error';
        claudeError.message = `Demo mode error: ${error.message}`;
        return claudeError;
    }
}
