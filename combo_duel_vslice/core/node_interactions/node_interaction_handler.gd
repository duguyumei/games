class_name NodeInteractionHandler
extends RefCounted

## 非战斗节点交互的最小扩展协议。
##
## Handler 只准备冻结选项并把一次选择翻译为本局 effects；它不持有会话、
## 不推进地图，也不接触真实 GrowthInventory。

func interaction_kind() -> String:
    return ""

func validate_configuration(
        _configuration: Dictionary,
        _validation) -> void:
    pass

func prepare(_context) -> Dictionary:
    return {"success": false, "reason": "节点交互处理器尚未实现 prepare()"}

func commit(
        _context,
        _prepared_interaction: Dictionary,
        _choice_id: String,
        _choice_payload: Dictionary) -> Dictionary:
    return {"success": false, "reason": "节点交互处理器尚未实现 commit()"}
