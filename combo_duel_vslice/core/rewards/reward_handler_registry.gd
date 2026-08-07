class_name RewardHandlerRegistry
extends RefCounted

const ExperienceHandlerScript = preload(
    "res://core/rewards/experience_reward_handler.gd")

var _handlers_by_kind: Dictionary = {}

func _init() -> void:
    register_handler(ExperienceHandlerScript.new())

func register_handler(handler, replace_existing: bool = false) -> bool:
    if handler == null or not handler.has_method("kind_ids") \
            or not handler.has_method("apply"):
        return false
    var kind_ids: Array = handler.kind_ids()
    if kind_ids.is_empty():
        return false
    for kind_id_value in kind_ids:
        var kind_id := str(kind_id_value)
        if kind_id == "" or (_handlers_by_kind.has(kind_id) and not replace_existing):
            return false
    for kind_id_value in kind_ids:
        _handlers_by_kind[str(kind_id_value)] = handler
    return true

func has_handler(kind_id: String) -> bool:
    return _handlers_by_kind.has(kind_id)

func kind_ids() -> Array[String]:
    var result: Array[String] = []
    for kind_id in _handlers_by_kind:
        result.append(str(kind_id))
    result.sort()
    return result

func apply(entry: Dictionary, growth) -> Dictionary:
    var kind_id := str(entry.get("kind", ""))
    var handler = _handlers_by_kind.get(kind_id)
    if handler == null:
        return {"success": false, "reason": "奖励类型尚未接入：%s" % kind_id}
    return handler.apply(entry, growth)
