class_name MockAiProvider
extends "res://core/ai/providers/ai_provider.gd"

var auto_complete: bool = true
var queued_results: Array = []
var pending: Dictionary = {}
var submitted_requests: Array = []

func _init(complete_automatically: bool = true) -> void:
    auto_complete = complete_automatically

func provider_id() -> String:
    return "mock"

func queue_result(result: Dictionary) -> void:
    queued_results.append(result.duplicate(true))

func submit(request_id: String, payload: Dictionary) -> bool:
    if request_id == "" or pending.has(request_id):
        return false
    pending[request_id] = payload.duplicate(true)
    submitted_requests.append({
        "request_id": request_id,
        "payload": payload.duplicate(true),
    })
    if auto_complete:
        complete(request_id)
    return true

func complete(request_id: String) -> bool:
    if not pending.has(request_id):
        return false
    pending.erase(request_id)
    var result: Dictionary = (
        queued_results.pop_front()
        if not queued_results.is_empty()
        else {
            "success": false,
            "error_code": "NO_MOCK_RESPONSE",
            "message": "Mock Provider 没有排队回答",
        })
    request_completed.emit(request_id, result.duplicate(true))
    return true

func cancel(request_id: String) -> bool:
    return pending.erase(request_id)
