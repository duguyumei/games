class_name AiPromptEncoder
extends RefCounted

const SYSTEM_INSTRUCTION := "你是敌方行动决策器。只能从 candidates 选择一个 candidate_id；不得猜测或输出玩家隐藏手牌、抽牌顺序或随机结果；只返回协议要求的 JSON。"

func system_message() -> Dictionary:
    return {"role": "system", "content": SYSTEM_INSTRUCTION}

func decision_message(payload: Dictionary) -> Dictionary:
    return {
        "role": "user",
        "content": JSON.stringify(payload),
    }

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
