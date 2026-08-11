class_name PassiveRuleHandler
extends RefCounted

## 被动行为的最小稳定协议。具体内容 ID、库存扫描和战斗会话均不进入 Handler。

func behavior_id() -> String:
    return ""

func supported_hooks() -> Array[String]:
    return []

func validate_configuration(_configuration: Dictionary) -> Array[String]:
    return []

## 声明该 behavior 在当前配置下可访问的全部本局整数计数器。
## 无状态 Handler 保持空数组；返回值由 Registry 统一校验和类型化。
func counter_definitions(_configuration: Dictionary) -> Array:
    return []

## 声明 behavior 对十个 BattleTimingSystem 生命周期时点的全局 order 绑定。
func battle_timing_bindings(_configuration: Dictionary) -> Array:
    return []

## 声明只存在于当前战斗的整数计数器。
func battle_counter_definitions(_configuration: Dictionary) -> Array:
    return []

func handle(_hook: String, _context, _configuration: Dictionary) -> Dictionary:
    return {"success": false, "reason": "被动行为尚未实现"}
