class_name ActorStatusBehaviorHandler
extends RefCounted

var _handlers: Dictionary = {}

func _init() -> void:
    _handlers = {
        "consume_stack": Callable(self, "_consume_stack"),
        "transfer_opponent_drawn_attribute": Callable(
            self, "_transfer_opponent_drawn_attribute"),
        "technique_card_flow_rewards": Callable(self, "_technique_card_flow_rewards"),
        "recycle_triggered_card_anomaly": Callable(
            self, "_recycle_triggered_card_anomaly"),
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
        return {"success": false, "detail": "未知角色状态处理器：%s" % behavior_id}
    return handler.call(context)

func _consume_stack(context) -> Dictionary:
    var consumed := int(context.status_system.consume_actor_status(
        context.actor,
        context.status_id,
        maxi(0, int(context.behavior.get("amount", 1))),
        str(context.behavior.get("source", context.definition.get("name", context.status_id)))
    ).get("changed", 0))
    return {"success": true, "consumed": consumed}

func _transfer_opponent_drawn_attribute(context) -> Dictionary:
    if context.actor == null or context.holder == null \
            or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "抽牌转移状态缺少参战方、真气或战斗端口"}
    if not context.holder.hand.has(context.card):
        return {"success": true}
    var attribute_id := str(context.behavior.get("attribute", ""))
    if attribute_id != "" and not context.card.is_attribute(attribute_id):
        return {"success": true}
    var consumed := int(context.status_system.consume_actor_status(
        context.actor,
        context.status_id,
        1,
        str(context.definition.get("name", context.status_id))
    ).get("changed", 0))
    if consumed <= 0:
        return {"success": true}
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder,
        "hand",
        context.actor,
        "hand",
        context.card,
        str(context.behavior.get("reason", context.status_id)))
    return {
        "success": bool(moved.get("success", false)),
        "stop_card_behaviors": bool(moved.get("success", false)),
    }

func _technique_card_flow_rewards(context) -> Dictionary:
    if context.actor == null or context.count <= 0:
        return {"success": true}
    var flow_effects: Dictionary = context.behavior.get(
        "effects_by_flow", {}).get(context.flow_kind, {})
    if flow_effects.is_empty():
        return {"success": true}
    var stacks: int = context.status_system.actor_status_value(
        context.actor, context.status_id)
    if stacks <= 0:
        return {"success": true}
    var scale: int = stacks * context.count
    var defense_per_stack := int(flow_effects.get("defense_per_stack", 0))
    if defense_per_stack != 0:
        context.actor.add_defense(defense_per_stack * scale)
    var damage_per_stack := int(flow_effects.get("opponent_damage_per_stack", 0))
    if damage_per_stack != 0 and context.effect_ports != null:
        var opponent = context.effect_ports.opponent_of(context.actor)
        if opponent != null:
            context.effect_ports.deal_damage(
                context.actor,
                opponent,
                damage_per_stack * scale,
                str(context.behavior.get("source_kind", "status")))
    return {"success": true}

func _recycle_triggered_card_anomaly(context) -> Dictionary:
    if context.resolution.is_empty() or bool(context.resolution.get("recycle", false)):
        return {"success": true}
    var category := str(context.behavior.get("category", ""))
    if category != "" and str(context.resolution.get("category", "")) != category:
        return {"success": true}
    var consumed := int(context.status_system.consume_actor_status(
        context.actor,
        context.status_id,
        maxi(1, int(context.behavior.get("amount", 1))),
        str(context.definition.get("name", context.status_id))
    ).get("changed", 0))
    if consumed <= 0:
        return {"success": true}
    context.resolution["recycle"] = true
    context.resolution["recycle_category"] = str(context.resolution.get("category", ""))
    context.resolution["recycle_anomaly_id"] = str(context.resolution.get("anomaly_id", ""))
    context.resolution["recycle_status_name"] = str(
        context.definition.get("name", context.status_id))
    return {"success": true}
