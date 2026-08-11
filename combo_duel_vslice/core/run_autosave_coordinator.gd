class_name RunAutosaveCoordinator
extends RefCounted

## 将 RunSession 的稳定命令边界转换为一次原子本局存档。

signal save_succeeded(reason: String)
signal save_failed(reason: String, detail: String)

var save_application_service
var bound_session = null
var last_save_reason: String = ""
var last_error: String = ""

func _init(service_override = null) -> void:
    save_application_service = service_override

func bind_session(run_session) -> Dictionary:
    unbind_session()
    if run_session == null:
        return {"success": false, "reason": "自动存档缺少 RunSession"}
    if save_application_service == null:
        return {"success": false, "reason": "自动存档缺少存档应用服务"}
    bound_session = run_session
    bound_session.persistence_boundary_reached.connect(
        _on_persistence_boundary_reached)
    return {"success": true}

func unbind_session() -> void:
    if bound_session != null \
            and bound_session.persistence_boundary_reached.is_connected(
                _on_persistence_boundary_reached):
        bound_session.persistence_boundary_reached.disconnect(
            _on_persistence_boundary_reached)
    bound_session = null

func save_now(reason: String) -> Dictionary:
    last_save_reason = reason
    if bound_session == null:
        return _report_failure(reason, "自动存档尚未绑定本局会话")
    var result: Dictionary = save_application_service.execute({
        "type": "save_run",
        "run_session": bound_session,
    })
    if not result.get("success", false):
        return _report_failure(
            reason, str(result.get("reason", "自动存档写入失败")))
    last_error = ""
    save_succeeded.emit(reason)
    return result

func retry_last_save() -> Dictionary:
    return save_now(last_save_reason if last_save_reason != "" else "manual_retry")

func _on_persistence_boundary_reached(command_type: String) -> void:
    save_now(command_type)

func _report_failure(reason: String, detail: String) -> Dictionary:
    last_error = detail
    if bound_session != null and bound_session.game_log != null:
        bound_session.game_log.record_system(
            "error",
            "autosave_failed",
            "自动存档失败",
            detail,
            {"reason": reason})
    save_failed.emit(reason, detail)
    return {"success": false, "reason": detail}
