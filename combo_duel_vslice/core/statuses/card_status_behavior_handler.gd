class_name CardStatusBehaviorHandler
extends RefCounted

var _handlers: Dictionary = {}

func _init() -> void:
    _handlers = {
        "damage_holder_by_current_qi": Callable(self, "_damage_holder_by_current_qi"),
        "remove_self_and_draw": Callable(self, "_remove_self_and_draw"),
        "remove_self_and_explicit_discard": Callable(self, "_remove_self_and_explicit_discard"),
        "remove_self_and_return_top": Callable(self, "_remove_self_and_return_top"),
        "remove_self_apply_anomaly_and_return_top": Callable(
            self, "_remove_self_apply_anomaly_and_return_top"),
    }

func behavior_ids() -> Array[String]:
    var result: Array[String] = []
    for behavior_id in _handlers:
        result.append(str(behavior_id))
    return result

func execute(context) -> Dictionary:
    var behavior_id := str(context.behavior.get("handler", ""))
    var handler: Callable = _handlers.get(behavior_id, Callable())
    if not handler.is_valid():
        return {"success": false, "detail": "未知真气状态处理器：%s" % behavior_id}
    return handler.call(context)

func _damage_holder_by_current_qi(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "真气伤害状态缺少持有者、真气或战斗端口"}
    _remove_self(context)
    var amount: int = context.status_system.effective_qi_value(context.card)
    context.effect_ports.deal_damage(
        context.holder,
        context.holder,
        amount,
        str(context.behavior.get("source_kind", context.definition.get("name", context.status_id))))
    return {
        "success": true,
        "resolution": {
            "card": context.card,
            "category": context.category,
            "anomaly_id": context.status_id,
            "anomaly_name": str(context.definition.get("name", context.status_id)),
            "damage": amount,
            "recycle": false,
        },
    }

func _remove_self_and_draw(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "抽牌状态缺少持有者、真气或战斗端口"}
    _remove_self(context)
    context.effect_ports.draw(
        context.holder,
        maxi(0, int(context.behavior.get("count", 1))),
        str(context.behavior.get("source_kind", "status")))
    return {"success": true}

func _remove_self_and_explicit_discard(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "弃牌状态缺少持有者、真气或战斗端口"}
    _remove_self(context)
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder,
        "hand",
        context.holder,
        "discard_pile",
        context.card,
        "explicit_discard")
    return {
        "success": bool(moved.get("success", false)),
        "stop_card_behaviors": bool(moved.get("success", false)),
    }

func _remove_self_and_return_top(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "回库状态缺少持有者、真气或战斗端口"}
    _remove_self(context)
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder,
        "discard_pile",
        context.holder,
        "draw_pile",
        context.card,
        str(context.behavior.get("reason", context.status_id)),
        "top")
    return {"success": bool(moved.get("success", false))}

func _remove_self_apply_anomaly_and_return_top(context) -> Dictionary:
    if context.card == null:
        return {"success": false, "detail": "改置状态缺少真气"}
    _remove_self(context)
    var applied: Dictionary = context.behavior.get("apply_anomaly", {})
    var apply_result: Dictionary = context.status_system.apply_card_anomaly(
        context.card,
        str(applied.get("category", "")),
        str(applied.get("id", "")),
        applied.get("payload", {}),
        str(context.definition.get("name", context.status_id)))
    if not apply_result.get("success", false):
        return apply_result
    if context.holder == null or context.effect_ports == null:
        return {"success": true}
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder,
        "discard_pile",
        context.holder,
        "draw_pile",
        context.card,
        str(context.behavior.get("reason", context.status_id)),
        "top")
    return {"success": bool(moved.get("success", false))}

func _remove_self(context) -> void:
    context.status_system.remove_card_anomaly(
        context.card,
        context.category,
        context.status_id,
        "%s触发" % str(context.definition.get("name", context.status_id)))
