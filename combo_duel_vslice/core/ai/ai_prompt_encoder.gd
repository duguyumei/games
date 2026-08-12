class_name AiPromptEncoder
extends RefCounted

const VERSION := 3
const SYSTEM_INSTRUCTION := "你是共享战斗规则核下的敌方决策器，目标是提高本场战斗最终胜率，而非只追求即时伤害。candidates 已由本地规则核从完整合法行动中压缩而来，每项代表一个有意义的战略方案；其中数值、战略画像和状态语义是本次决策的权威输入。你只能从 candidates 选择一个 candidate_id，不得创造候选或要求执行候选外动作。需要考虑斩杀、生存、后续手牌、换气、功法序列、连击/协同、真气状态、内功运转、公开历史和风险。不得把玩家隐藏手牌、抽牌顺序或未冻结随机结果当作已知事实；允许仅依据公开构筑、公开历史和当前公开状态进行概率判断。不得根据 candidate_id、数组顺序或字段缺省猜测优先级。只返回协议 v3 JSON，不输出 Markdown、解释、思维过程或额外字段。"

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
