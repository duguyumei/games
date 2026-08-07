extends RefCounted

var _behavior_ids: Array[String] = []
var calls: Array[String] = []

func _init(ids: Array = ["probe_status_behavior"]) -> void:
    for id_value in ids:
        _behavior_ids.append(str(id_value))

func behavior_ids() -> Array[String]:
    return _behavior_ids.duplicate()

func execute(context) -> Dictionary:
    calls.append(str(context.status_id) if context != null else "")
    return {"success": true}
