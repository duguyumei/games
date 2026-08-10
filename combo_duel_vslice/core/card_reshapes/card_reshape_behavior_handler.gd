class_name CardReshapeBehaviorHandler
extends RefCounted

## 单个重塑行为的协议基类。

func behavior_id() -> String:
    return ""

func triggers() -> Array[String]:
    return [] as Array[String]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    pass

func execute(behavior: Dictionary, context) -> Dictionary:
    return {"success": false, "reason": "重塑行为尚未实现：%s" % behavior_id()}
