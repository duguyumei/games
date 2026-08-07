class_name AiResponseValidator
extends RefCounted

const PROTOCOL_VERSION := 1
const ALLOWED_KEYS := [
    "schema_version",
    "decision_id",
    "state_hash",
    "candidate_id",
    "reason_code",
    "confidence",
]

func validate(raw_response, observation: Dictionary, valid_candidate_ids: Array) -> Dictionary:
    var parsed = raw_response
    if raw_response is String:
        parsed = JSON.parse_string(raw_response)
    if not parsed is Dictionary:
        return _failure("INVALID_JSON", "回答必须是 JSON 对象")
    for key in parsed:
        if not ALLOWED_KEYS.has(str(key)):
            return _failure(
                "UNEXPECTED_FIELD",
                "回答包含协议外字段：%s" % str(key))
    if int(parsed.get("schema_version", -1)) != PROTOCOL_VERSION:
        return _failure("INVALID_SCHEMA_VERSION", "schema_version 必须为 %d" % PROTOCOL_VERSION)
    if str(parsed.get("decision_id", "")) != str(observation.get("decision_id", "")):
        return _failure("DECISION_MISMATCH", "decision_id 与当前请求不一致")
    if str(parsed.get("state_hash", "")) != str(observation.get("state_hash", "")):
        return _failure("STATE_MISMATCH", "state_hash 与当前行动窗口不一致")
    var candidate_id := str(parsed.get("candidate_id", ""))
    if not valid_candidate_ids.has(candidate_id):
        return _failure(
            "INVALID_CANDIDATE",
            "candidate_id 不在合法候选中",
            {"valid_candidate_ids": valid_candidate_ids.duplicate()})
    return {
        "valid": true,
        "candidate_id": candidate_id,
        "reason_code": str(parsed.get("reason_code", "")),
        "confidence": clampf(float(parsed.get("confidence", 0.0)), 0.0, 1.0),
        "parsed": parsed.duplicate(true),
    }

func _failure(code: String, message: String, context: Dictionary = {}) -> Dictionary:
    return {
        "valid": false,
        "error_code": code,
        "message": message,
        "context": context.duplicate(true),
    }
