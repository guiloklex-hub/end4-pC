import QtQuick
import qs.modules.common
import qs.modules.common.functions as CF

ApiStrategy {
    property int inputTokens: 0
    property int outputTokens: 0
    property bool inThinking: false
    property bool receivedStop: false
    property string stopReason: ""
    property string errorBody: ""
    property var blocks: []
    property var inputJsonBuffers: ({})

    function reset() {
        inputTokens = 0;
        outputTokens = 0;
        inThinking = false;
        receivedStop = false;
        stopReason = "";
        errorBody = "";
        blocks = [];
        inputJsonBuffers = ({});
    }

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        // Search turns must preserve server tool results, citations and thinking signatures.
        const history = messages.filter(message => message.role === "user" || message.role === "assistant")
            .map(message => {
                if (message.role === "assistant" && message.anthropicContent?.length > 0)
                    return {role: "assistant", content: message.anthropicContent};
                const text = message.role === "assistant"
                    ? message.rawContent.replace(/<think>[\s\S]*?<\/think>/g, "").trim()
                    : message.rawContent;
                const path = message.role === "user" ? message.localFilePath : "";
                return { role: message.role, content: path
                    ? [{type: "local_file", path: path}, {type: "text", text: text || "Analise este arquivo."}]
                    : text };
            }).filter(message => message.content.length > 0);
        // The current attachment belongs to the most recent user turn.
        if (filePath && history.length > 0) {
            const last = history[history.length - 1];
            if (last.role === "user" && typeof last.content === "string")
                last.content = [{type: "local_file", path: filePath}, {type: "text", text: last.content || "Analise este arquivo."}];
        }
        const data = Object.assign({
            model: model.model,
            system: systemPrompt,
            messages: history,
            stream: true,
            max_tokens: 64000
        }, model.extraParams || {});
        if (tools?.length > 0) data.tools = tools;
        return data;
    }

    function buildRequestCommand(endpoint, headers, authHeader, data) {
        // stdin avoids argv limits for large histories; the key stays in the environment.
        const helper = CF.FileUtils.trimFileProtocol(Directories.scriptPath) + "/ai/anthropic-request.py";
        return `exec python3 '${CF.StringUtils.shellSingleQuoteEscape(helper)}' --endpoint '${CF.StringUtils.shellSingleQuoteEscape(endpoint)}' <<'ANTHROPIC_REQUEST_JSON'\n`
            + JSON.stringify(data) + "\nANTHROPIC_REQUEST_JSON\n";
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "x-api-key: \$\{${apiKeyEnvVarName}\}" -H 'anthropic-version: 2023-06-01'`;
    }

    function appendText(message, text) {
        message.content += text;
        message.rawContent += text;
    }

    function closeThinking(message) {
        if (inThinking) {
            appendText(message, "\n</think>\n\n");
            inThinking = false;
        }
    }

    function onRequestCancelled(message: AiMessageData) {
        closeThinking(message);
        // A cancelled block may not have its final signature or complete tool input.
        message.anthropicContent = [];
    }

    function addCitation(message, citation) {
        if (!citation?.url || !/^https?:\/\//i.test(citation.url)) return;
        const sources = message.annotationSources || [];
        let index = sources.findIndex(source => source.url === citation.url);
        if (index < 0) {
            index = sources.length;
            message.annotationSources = [...sources, {text: citation.title || citation.url, url: citation.url}];
        }
        appendText(message, ` [${index + 1}](<${citation.url.replace(/>/g, "%3E")}>)`);
    }

    function rememberBlock(message, index, block) {
        blocks[index] = block;
        message.anthropicContent = blocks.slice();
    }

    function finishBlock(message, index) {
        const block = blocks[index];
        if (!block) return;
        if (block.type === "server_tool_use" && block.name === "web_search") {
            if (inputJsonBuffers[index]) {
                try { block.input = JSON.parse(inputJsonBuffers[index]); } catch (e) { return; }
            }
            const query = block.input?.query;
            if (query && !(message.searchQueries || []).includes(query))
                message.searchQueries = [...(message.searchQueries || []), query];
        }
        rememberBlock(message, index, block);
    }

    function usageResult() {
        return { tokenUsage: { input: inputTokens, output: outputTokens, total: inputTokens + outputTokens } };
    }

    function parseResponseLine(line, message) {
        const clean = line.trim();
        if (!clean || clean.startsWith("event:") || clean.startsWith(":")) return {};
        // Non-streaming HTTP errors can arrive as a pretty-printed JSON body.
        if (!clean.startsWith("data:")) {
            errorBody += line + "\n";
            return {};
        }
        const data = JSON.parse(clean.slice(5).trim());
        if (data.type === "error" || data.error) {
            closeThinking(message);
            message.anthropicContent = [];
            appendText(message, "**Erro Anthropic:** " + (data.error?.message || "Erro na API"));
            receivedStop = true;
            return { finished: true };
        }
        if (data.type === "message_start") {
            const usage = data.message?.usage || {};
            inputTokens = (usage.input_tokens || 0) + (usage.cache_creation_input_tokens || 0) + (usage.cache_read_input_tokens || 0);
            outputTokens = usage.output_tokens || 0;
            return usageResult();
        }
        if (data.type === "content_block_start") {
            const block = JSON.parse(JSON.stringify(data.content_block));
            rememberBlock(message, data.index, block);
            if (block.type === "text") {
                closeThinking(message);
                appendText(message, block.text || "");
                (block.citations || []).forEach(citation => addCitation(message, citation));
            } else if (block.type === "web_search_tool_result" && block.content?.type === "web_search_tool_result_error") {
                closeThinking(message);
                appendText(message, "\n\n*Busca web indisponível: " + block.content.error_code + ".*\n\n");
            }
        }
        if (data.type === "content_block_delta") {
            const delta = data.delta || {};
            const block = blocks[data.index];
            if (block) {
                if (delta.type === "text_delta") block.text = (block.text || "") + (delta.text || "");
                else if (delta.type === "thinking_delta") block.thinking = (block.thinking || "") + (delta.thinking || "");
                else if (delta.type === "signature_delta") block.signature = (block.signature || "") + (delta.signature || "");
                else if (delta.type === "input_json_delta") inputJsonBuffers[data.index] = (inputJsonBuffers[data.index] || "") + delta.partial_json;
                else if (delta.type === "citations_delta" && delta.citation) block.citations = [...(block.citations || []), delta.citation];
                rememberBlock(message, data.index, block);
            }
            if (delta.type === "thinking_delta" && delta.thinking) {
                if (!inThinking) {
                    appendText(message, "<think>\n");
                    inThinking = true;
                }
                appendText(message, delta.thinking);
            } else if (delta.type === "text_delta") {
                closeThinking(message);
                appendText(message, delta.text || "");
            } else if (delta.type === "citations_delta") {
                addCitation(message, delta.citation);
            }
        }
        if (data.type === "content_block_stop") {
            finishBlock(message, data.index);
            closeThinking(message);
        }
        if (data.type === "message_delta") {
            outputTokens = data.usage?.output_tokens ?? outputTokens;
            stopReason = data.delta?.stop_reason || stopReason;
            return usageResult();
        }
        if (data.type === "message_stop") {
            closeThinking(message);
            if (stopReason === "max_tokens") appendText(message, "\n\n*Resposta interrompida pelo limite de tokens.*");
            receivedStop = true;
            return Object.assign({ finished: true, continueTurn: stopReason === "pause_turn" }, usageResult());
        }
        return {};
    }

    function onRequestFinished(message) {
        closeThinking(message);
        if (!receivedStop) {
            message.anthropicContent = [];
            let detail = "Conexão encerrada antes de concluir a resposta.";
            if (errorBody.trim()) {
                try {
                    const data = JSON.parse(errorBody);
                    detail = data.error?.message || detail;
                } catch (e) {
                    detail = "Resposta HTTP inesperada da API Anthropic.";
                }
            }
            appendText(message, "\n\n**Erro Anthropic:** " + detail);
        }
        return {};
    }
}
