class_name AiPromptEncoder
extends RefCounted

const VERSION := 2
const SYSTEM_INSTRUCTION := "你是共享战斗规则核下的敌方玩家决策器。目标是提高整场战斗最终胜率，不是每次追求即时最大伤害。只能使用请求中的公开信息与自身信息，只能从 candidates 选择一个 candidate_id；要考虑必杀与存活、后续手牌、功法序列、连击与协同、状态、历史行为和不确定性。不得猜测或输出玩家隐藏手牌、抽牌顺序、隐藏随机结果，不得请求候选之外的动作。只返回 JSON：{\"schema_version\":1,\"decision_id\":\"...\",\"state_hash\":\"...\",\"candidate_id\":\"...\",\"reason_code\":\"...\",\"confidence\":0.0}。不要 Markdown、解释文本、额外字段或思维过程。"

func system_message() -> Dictionary:
    return {
        "role": "system",
        "content": SYSTEM_INSTRUCTION,
    }

func decision_message(payload: Dictionary) -> Dictionary:
    return {
        "role": "user",
        "content": JSON.stringify(payload),
    }

func build_chat_body(messages: Array, model: String, thinking_enabled: bool, reasoning_effort: String, max_tokens: int, extra_body: Dictionary = {}) -> Dictionary:
    var body: Dictionary = extra_body.duplicate(true)
    body.merge({
        "model": model,
        "messages": messages.duplicate(true),
        "stream": false,
        "max_tokens": maxi(32, max_tokens),
    }, true)
    if thinking_enabled:
        body["thinking"] = {"type": "enabled"}
    if reasoning_effort != "":
        body["reasoning_effort"] = reasoning_effort
    return body

func correction_message(error: Dictionary) -> Dictionary:
    return {
        "role": "user",
        "content": JSON.stringify({
            "type": "correction",
            "error_code": error.get("error_code", "INVALID_RESPONSE"),
            "message": error.get("message", "回答无效"),
            "context": error.get("context", {}).duplicate(true),
        }),
    }
