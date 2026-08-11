class_name StatusBehaviorRegistry
extends RefCounted

const CardHandlerScript = preload("res://core/statuses/card_status_behavior_handler.gd")

var _handlers_by_behavior: Dictionary = {}

func _init() -> void:
    register_handler(CardHandlerScript.new())

func register_handler(handler, replace_existing: bool = false) -> bool:
    if handler == null or not handler.has_method("behavior_ids") \
            or not handler.has_method("execute"):
        return false
    var behavior_ids: Array = handler.behavior_ids()
    if behavior_ids.is_empty():
        return false
    var seen_ids: Dictionary = {}
    for behavior_id_value in behavior_ids:
        var behavior_id := str(behavior_id_value)
        if behavior_id == "" or seen_ids.has(behavior_id) \
                or (_handlers_by_behavior.has(behavior_id) and not replace_existing):
            return false
        seen_ids[behavior_id] = true
    for behavior_id_value in behavior_ids:
        _handlers_by_behavior[str(behavior_id_value)] = handler
    return true

func has_handler(behavior_id: String) -> bool:
    return _handlers_by_behavior.has(behavior_id)

func behavior_ids() -> Array[String]:
    var result: Array[String] = []
    for behavior_id in _handlers_by_behavior:
        result.append(str(behavior_id))
    result.sort()
    return result

func execute(behavior: Dictionary, context) -> Dictionary:
    var behavior_id := str(behavior.get("handler", ""))
    var handler = _handlers_by_behavior.get(behavior_id)
    if handler == null:
        return {"success": false, "detail": "未注册的状态处理器：%s" % behavior_id}
    return handler.execute(context)
