class_name PassiveRuleHandler
extends RefCounted

## 被动行为的最小稳定协议。具体内容 ID、库存扫描和战斗会话均不进入 Handler。

func behavior_id() -> String:
    return ""

func supported_hooks() -> Array[String]:
    return []

func validate_configuration(_configuration: Dictionary) -> Array[String]:
    return []

func handle(_hook: String, _context, _configuration: Dictionary) -> Dictionary:
    return {"success": false, "reason": "被动行为尚未实现"}
