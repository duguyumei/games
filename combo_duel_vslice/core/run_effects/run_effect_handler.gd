class_name RunEffectHandler
extends RefCounted

## 战斗外本局效果的最小扩展协议。
##
## Handler 只校验并修改 RunMutationService 提供的工作副本；地图推进、UI、
## 功行结算与战斗系统都不属于这个协议。

func operation_ids() -> Array[String]:
    return []

func validate_effect(_effect: Dictionary, _validator, _scope: String) -> void:
    pass

func apply(_effect: Dictionary, _context) -> Dictionary:
    return {"success": false, "reason": "本局效果处理器尚未实现 apply()"}
