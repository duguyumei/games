class_name AiResponseValidator
extends RefCounted

const PROTOCOL_VERSION := 3
const REASON_CODES := [
    "lethal", "survival", "assault", "prepare", "cycle", "control",
    "passive_trigger", "sequence_progress", "resource_preservation",
    "uncertainty_management",
]
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
    var reason_provided: bool = parsed.has("reason_code") \
        and str(parsed.get("reason_code", "")) != ""
    var reason_code: String = str(parsed.get("reason_code", "unspecified")) \
        if reason_provided else "unspecified"
    if reason_provided and not REASON_CODES.has(reason_code):
        return _failure("INVALID_REASON_CODE", "reason_code 不在固定枚举中", {
            "allowed_reason_codes": REASON_CODES.duplicate(),
        })
    return {
        "valid": true,
        "candidate_id": candidate_id,
        "reason_code": reason_code,
        "protocol_quality_issue": not reason_provided,
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
