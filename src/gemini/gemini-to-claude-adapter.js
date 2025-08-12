import { GeminiApiService } from './gemini-core.js';
import { toGeminiRequestFromClaude, toClaudeChatCompletionFromGemini } from '../convert.js';
import { v4 as uuidv4 } from 'uuid';

/**
 * Gemini to Claude Proxy Adapter
 * 
 * This adapter allows users to access Gemini models through Claude API format.
 * It leverages Gemini CLI OAuth authentication while providing Claude-compatible endpoints.
 * 
 * Benefits:
 * - Use Gemini CLI OAuth's free quota and high-frequency access
 * - Access through familiar Claude API format (/v1/messages)
 * - Compatible with Claude API clients
 */
export class GeminiToClaudeAdapter {
    constructor(config) {
        this.config = config;

        // 修改配置，使用正确的Gemini CLI OAuth文件路径
        const geminiOAuthPath = config.GEMINI_OAUTH_CREDS_FILE_PATH ||
            require('path').join(require('os').homedir(), '.gemini', 'oauth_creds.json');

        console.log(`[Gemini-Claude Proxy] Using OAuth credentials file: ${geminiOAuthPath}`);

        const geminiConfig = {
            ...config,
            GEMINI_OAUTH_CREDS_FILE_PATH: geminiOAuthPath
        };

        this.geminiApiService = new GeminiApiService(geminiConfig);
        this.isInitialized = false;
    }

    /**
     * Ensures the Gemini service is initialized
     */
    async ensureInitialized() {
        if (!this.geminiApiService.isInitialized) {
            console.warn("[Gemini-Claude Proxy] Gemini service not initialized, attempting to re-initialize...");
            await this.geminiApiService.initialize();
        }
    }

    /**
     * Generates content using Gemini API but with Claude request/response format
     * @param {string} model - Model name (Gemini model)
     * @param {Object} claudeRequestBody - Request body in Claude format
     * @returns {Promise<Object>} Response in Claude format
     */
    async generateContent(model, claudeRequestBody) {
        await this.ensureInitialized();
        
        try {
            console.log(`[Gemini-Claude Proxy] Processing Claude format request for model: ${model}`);
            console.log(`[Gemini-Claude Proxy] Original Claude request:`, JSON.stringify(claudeRequestBody, null, 2));

            // Convert Claude request to Gemini format
            const geminiRequest = toGeminiRequestFromClaude(claudeRequestBody);
            console.log(`[Gemini-Claude Proxy] Converted to Gemini format:`, JSON.stringify(geminiRequest, null, 2));

            // Call Gemini API
            const geminiResponse = await this.geminiApiService.generateContent(model, geminiRequest);
            console.log(`[Gemini-Claude Proxy] Received Gemini response`);

            // Convert Gemini response to Claude format
            const claudeResponse = toClaudeChatCompletionFromGemini(geminiResponse, model);
            console.log(`[Gemini-Claude Proxy] Converted to Claude format`);

            return claudeResponse;
        } catch (error) {
            console.error(`[Gemini-Claude Proxy] Error in generateContent:`, error);
            
            // Convert Gemini errors to Claude format
            throw this.convertErrorToClaudeFormat(error);
        }
    }

    /**
     * Generates streaming content using Gemini API but with Claude request/response format
     * @param {string} model - Model name (Gemini model)
     * @param {Object} claudeRequestBody - Request body in Claude format
     * @returns {AsyncGenerator<Object>} Stream of responses in Claude format
     */
    async *generateContentStream(model, claudeRequestBody) {
        await this.ensureInitialized();
        
        try {
            console.log(`[Gemini-Claude Proxy] Processing streaming Claude format request for model: ${model}`);

            // Convert Claude request to Gemini format
            const geminiRequest = toGeminiRequestFromClaude(claudeRequestBody);
            geminiRequest.stream = true; // Ensure streaming is enabled

            // Get Gemini stream
            const geminiStream = this.geminiApiService.generateContentStream(model, geminiRequest);
            
            let isFirstChunk = true;
            const messageId = `msg_${uuidv4()}`;
            
            for await (const geminiChunk of geminiStream) {
                try {
                    // Convert each Gemini chunk to Claude streaming format
                    const claudeChunk = this.convertGeminiStreamChunkToClaude(
                        geminiChunk, 
                        model, 
                        messageId, 
                        isFirstChunk
                    );
                    
                    if (claudeChunk) {
                        yield claudeChunk;
                        isFirstChunk = false;
                    }
                } catch (chunkError) {
                    console.error(`[Gemini-Claude Proxy] Error processing stream chunk:`, chunkError);
                    // Continue with next chunk instead of breaking the stream
                }
            }
            
            // Send final chunk to indicate stream end
            yield {
                type: "message_stop"
            };
            
        } catch (error) {
            console.error(`[Gemini-Claude Proxy] Error in generateContentStream:`, error);
            
            // Send error in Claude streaming format
            yield {
                type: "error",
                error: this.convertErrorToClaudeFormat(error)
            };
        }
    }

    /**
     * Lists available Gemini models in Claude format
     * @returns {Promise<Object>} Model list in Claude format
     */
    async listModels() {
        await this.ensureInitialized();

        try {
            // Get Gemini models
            const geminiModels = await this.geminiApiService.listModels();

            console.log(`[Gemini-Claude Proxy] Listed ${geminiModels.models.length} models in Gemini format`);
            return geminiModels;
        } catch (error) {
            console.error(`[Gemini-Claude Proxy] Error listing models:`, error);
            throw this.convertErrorToClaudeFormat(error);
        }
    }

    /**
     * Refreshes the underlying Gemini OAuth token
     * @returns {Promise<void>}
     */
    async refreshToken() {
        try {
            await this.geminiApiService.refreshToken();
            console.log(`[Gemini-Claude Proxy] Token refreshed successfully`);
        } catch (error) {
            console.error(`[Gemini-Claude Proxy] Token refresh failed:`, error);
            throw error;
        }
    }

    /**
     * Converts Gemini stream chunk to Claude streaming format
     * @param {Object} geminiChunk - Gemini stream chunk
     * @param {string} model - Model name
     * @param {string} messageId - Message ID
     * @param {boolean} isFirstChunk - Whether this is the first chunk
     * @returns {Object|null} Claude format stream chunk
     */
    convertGeminiStreamChunkToClaude(geminiChunk, model, messageId, isFirstChunk) {
        if (!geminiChunk || !geminiChunk.candidates || geminiChunk.candidates.length === 0) {
            return null;
        }

        const candidate = geminiChunk.candidates[0];
        
        if (isFirstChunk) {
            // First chunk - send message_start
            return {
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
        }

        // Extract text content from Gemini chunk
        let textContent = '';
        if (candidate.content && candidate.content.parts) {
            for (const part of candidate.content.parts) {
                if (part.text) {
                    textContent += part.text;
                }
            }
        }

        if (textContent) {
            // Content chunk
            return {
                type: "content_block_delta",
                index: 0,
                delta: {
                    type: "text_delta",
                    text: textContent
                }
            };
        }

        // Check for finish reason
        if (candidate.finishReason) {
            const stopReason = this.mapGeminiFinishReasonToClaudeStopReason(candidate.finishReason);
            return {
                type: "message_delta",
                delta: {
                    stop_reason: stopReason,
                    stop_sequence: null
                },
                usage: {
                    output_tokens: geminiChunk.usageMetadata?.candidatesTokenCount || 0
                }
            };
        }

        return null;
    }

    /**
     * Maps Gemini finish reasons to Claude stop reasons
     * @param {string} geminiFinishReason - Gemini finish reason
     * @returns {string} Claude stop reason
     */
    mapGeminiFinishReasonToClaudeStopReason(geminiFinishReason) {
        const mapping = {
            'STOP': 'end_turn',
            'MAX_TOKENS': 'max_tokens',
            'SAFETY': 'stop_sequence',
            'RECITATION': 'stop_sequence',
            'OTHER': 'end_turn'
        };
        return mapping[geminiFinishReason] || 'end_turn';
    }

    /**
     * Converts Gemini errors to Claude format
     * @param {Error} error - Original error
     * @returns {Error} Claude format error
     */
    convertErrorToClaudeFormat(error) {
        const claudeError = new Error();
        
        if (error.response) {
            // HTTP error from Gemini API
            claudeError.status = error.response.status;
            claudeError.message = error.response.data?.error?.message || error.message;
            
            // Map common HTTP status codes
            switch (error.response.status) {
                case 401:
                    claudeError.type = 'authentication_error';
                    break;
                case 403:
                    claudeError.type = 'permission_error';
                    break;
                case 429:
                    claudeError.type = 'rate_limit_error';
                    break;
                case 500:
                case 502:
                case 503:
                    claudeError.type = 'api_error';
                    break;
                default:
                    claudeError.type = 'invalid_request_error';
            }
        } else {
            // Other errors
            claudeError.status = 500;
            claudeError.type = 'api_error';
            claudeError.message = error.message || 'Internal server error';
        }
        
        return claudeError;
    }
}
