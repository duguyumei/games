class_name TechniqueEffectResult
extends RefCounted

const SUCCEEDED := "succeeded"
const FAILED := "failed"
const PENDING_CHOICE := "pending_choice"
const SCRIPT_PATH := "res://core/effects/technique_effect_result.gd"

var status: String = SUCCEEDED
var detail: String = ""
var payload: Dictionary = {}

static func succeeded(message: String = "", values: Dictionary = {}):
    return load(SCRIPT_PATH).new().configure(SUCCEEDED, message, values)

static func failed(message: String, values: Dictionary = {}):
    return load(SCRIPT_PATH).new().configure(FAILED, message, values)

static func pending_choice(message: String, request):
    var request_snapshot: Dictionary = (
        request.snapshot()
        if request is Object and request.has_method("snapshot")
        else request.duplicate(true))
    return load(SCRIPT_PATH).new().configure(
        PENDING_CHOICE,
        message,
        {
            "choice_request": request_snapshot,
            "_choice_request_object": request if request is Object else null,
        })

func configure(result_status: String, message: String, values: Dictionary = {}):
    status = result_status
    detail = message
    payload = values.duplicate(true)
    return self

func is_success() -> bool:
    return status == SUCCEEDED

func is_pending_choice() -> bool:
    return status == PENDING_CHOICE

func snapshot() -> Dictionary:
    var result := {
        "status": status,
        "success": is_success(),
        "pending_choice": is_pending_choice(),
        "detail": detail,
    }
    result.merge(payload.duplicate(true), true)
    return result

static func normalize(value) -> Dictionary:
    if value is Object and value.get_script() == load(SCRIPT_PATH):
        return value.snapshot()
    if value is Dictionary:
        var result: Dictionary = value.duplicate(true)
        if not result.has("success"):
            result["success"] = true
        if not result.has("pending_choice"):
            result["pending_choice"] = false
        if not result.has("status"):
            result["status"] = SUCCEEDED if result["success"] else FAILED
        if not result.has("detail"):
            result["detail"] = ""
        return result
    return failed("效果处理器返回了无效结果类型").snapshot()
