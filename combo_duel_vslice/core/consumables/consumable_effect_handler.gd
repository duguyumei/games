class_name ConsumableEffectHandler
extends RefCounted

## 一次性消耗品效果的最小扩展协议。
##
## Handler 只校验自己的专属参数，并在事务工作副本上执行一个小能力；效果执行
## 结果通过结构化 `applied` 返回，由调用方决定如何记录与展示。Handler 不负责
## UI、地图推进、存档和日志，也不直接访问 CombatEngine、ActionResolver、
## StatusSystem。新增消耗品操作时只新增并注册小型 Handler，不修改中央 match。

func operation_ids() -> Array[String]:
	return []

func validate_effect(_effect: Dictionary, _context, _scope: String) -> void:
	pass

func apply(_effect: Dictionary, _context) -> Dictionary:
	return {"success": false, "reason": "消耗品效果处理器尚未实现 apply()"}
