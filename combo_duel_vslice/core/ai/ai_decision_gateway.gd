class_name AiDecisionGateway
extends RefCounted

signal decision_ready(decision_id, proposal, metadata)
signal decision_retry(decision_id, retry_index, error)
signal decision_failed(decision_id, error)

const ValidatorScript = preload("res://core/ai/ai_response_validator.gd")

var provider = null
var validator := ValidatorScript.new()
var _pending: Dictionary = {}

func _init(provider_value = null) -> void:
    use_provider(provider_value)

func use_provider(provider_value) -> void:
    if provider != null and provider.request_completed.is_connected(_on_request_completed):
        provider.request_completed.disconnect(_on_request_completed)
    provider = provider_value
    if provider != null:
        provider.request_completed.connect(_on_request_completed)

func begin_decision(conversation, observation, candidates: Array) -> Dictionary:
    if provider == null:
        return {"success": false, "reason": "没有配置 AI Provider"}
    var observation_snapshot: Dictionary = observation.snapshot()
    if not observation.is_valid():
        return {"success": false, "reason": "AI 决策观察无效"}
    var candidates_by_id: Dictionary = {}
    for candidate in candidates:
        if candidate == null or not candidate.has_method("is_valid") or not candidate.is_valid():
            continue
        candidates_by_id[candidate.candidate_id] = candidate
    if candidates_by_id.is_empty():
        return {"success": false, "reason": "没有合法 AI 候选"}
    var state := {
        "conversation": conversation,
        "observation": observation_snapshot,
        "candidates": candidates,
        "candidates_by_id": candidates_by_id,
        "retry_index": 0,
        "max_retries": int(conversation.settings.get("max_retries", 1)),
        "last_error": {},
    }
    return _submit_state(state)

func _submit_state(state: Dictionary) -> Dictionary:
    var decision_id := str(state["observation"].get("decision_id", ""))
    var request_id := "%s:%d" % [decision_id, int(state["retry_index"])]
    var correction: Dictionary = state.get("last_error", {})
    var request: Dictionary = state["conversation"].build_decision_request(
        state["observation"],
        state["candidates"],
        correction)
    state["request"] = request
    _pending[request_id] = state
    state["conversation"].record_request(request_id, request)
    if not provider.submit(request_id, request):
        _pending.erase(request_id)
        var error := {
            "error_code": "PROVIDER_REJECTED",
            "message": "Provider 拒绝接收请求",
        }
        decision_failed.emit(decision_id, error)
        return {"success": false, "reason": error["message"]}
    return {
        "success": true,
        "request_id": request_id,
        "decision_id": decision_id,
    }

func _on_request_completed(request_id: String, provider_result: Dictionary) -> void:
    if not _pending.has(request_id):
        return
    var state: Dictionary = _pending[request_id]
    _pending.erase(request_id)
    state["conversation"].record_response(request_id, provider_result)
    var validation: Dictionary
    if not provider_result.get("success", false):
        validation = {
            "valid": false,
            "error_code": str(provider_result.get("error_code", "TRANSPORT_ERROR")),
            "message": str(provider_result.get("message", "Provider 请求失败")),
            "context": {},
        }
    else:
        validation = validator.validate(
            provider_result.get("body"),
            state["observation"],
            state["candidates_by_id"].keys())
    var decision_id := str(state["observation"].get("decision_id", ""))
    if validation.get("valid", false):
        var candidate = state["candidates_by_id"][validation["candidate_id"]]
        if candidate.action_proposal == null:
            validation = {
                "valid": false,
                "error_code": "MISSING_LOCAL_PROPOSAL",
                "message": "候选没有绑定本地行动提案",
                "context": {},
            }
        else:
            state["conversation"].accept_decision(state["request"], validation)
            decision_ready.emit(decision_id, candidate.action_proposal, {
                "candidate_id": validation["candidate_id"],
                "reason_code": validation.get("reason_code", ""),
                "confidence": validation.get("confidence", 0.0),
                "request_id": request_id,
            })
            return
    if int(state["retry_index"]) < int(state["max_retries"]):
        state["retry_index"] = int(state["retry_index"]) + 1
        state["last_error"] = validation.duplicate(true)
        decision_retry.emit(decision_id, state["retry_index"], validation.duplicate(true))
        _submit_state(state)
        return
    decision_failed.emit(decision_id, validation.duplicate(true))

func pending_request_ids() -> Array:
    return _pending.keys()
