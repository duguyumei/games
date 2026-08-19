class_name CardStatusBehaviorHandler
extends RefCounted

var _handlers: Dictionary = {}

func _init() -> void:
    _handlers = {
        "damage_holder_by_current_qi": Callable(self, "_damage_holder_by_current_qi"),
        "grow_anomaly_layers": Callable(self, "_grow_anomaly_layers"),
        "decrement_state_layer": Callable(self, "_decrement_state_layer"),
        "remove_self_and_draw_filtered": Callable(self, "_remove_self_and_draw_filtered"),
        "remove_self_and_discard_non_attribute": Callable(
            self, "_remove_self_and_discard_non_attribute"),
        "remove_self_and_shuffle_into_draw_pile": Callable(
            self, "_remove_self_and_shuffle_into_draw_pile"),
        "temporarily_remove_if_in_hand": Callable(self, "_temporarily_remove_if_in_hand"),
        "block_play": Callable(self, "_block_play"),
        "remove_self": Callable(self, "_remove_self_behavior"),
        "remove_self_with_resolution": Callable(self, "_remove_self_with_resolution"),
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
    var amount: int = int(context.behavior.get(
        "frozen_amount",
        context.effect_ports.current_effective_qi(context.holder, context.card, {
            "actor": context.holder,
            "purpose": "effect_value",
            "evaluation_mode": "runtime",
            "action_token": context.action_token,
            "source_kind": "status",
            "boundary": "card_status_behavior",
        })))
    var triggered: Dictionary = context.effect_ports.trigger_poison_card(
        context.holder, context.card, context.action_token,
        context.replay_depth > 0, amount)
    if not triggered.get("success", false):
        return triggered
    return {
        "success": true,
        "resolution": {
            "card": context.card,
            "category": context.category,
            "anomaly_id": context.status_id,
            "anomaly_name": str(context.definition.get("name", context.status_id)),
            "damage": amount,
            "life_lost": int(triggered.get("life_lost", 0)),
            "damage_type": "poison",
        },
    }

func _grow_anomaly_layers(context) -> Dictionary:
    if context.holder == null or context.card == null \
            or not context.holder.hand.has(context.card):
        return {"success": true, "applied": false}
    var layers: int = context.card.anomaly_layers(context.category, context.status_id)
    if layers <= 0:
        return {"success": true, "applied": false}
    return context.card_anomaly_service.trigger_growth(
        context.card,
        context.holder,
        layers,
        str(context.behavior.get("category", "")),
        str(context.behavior.get("anomaly", "")),
        context.extra_trigger,
        context.trigger_sequence,
        context.growth_source_metadata)

func _decrement_state_layer(context) -> Dictionary:
    var layers: int = context.card.anomaly_layers("state", context.status_id)
    if layers <= 1:
        _remove_self(context)
    else:
        context.card_anomaly_service.set_card_anomaly_layers(
            context.card, "state", context.status_id, layers - 1,
            "%s触发" % str(context.definition.get("name", context.status_id)),
            _source_metadata(context))
    return {"success": true, "applied": true}

func _remove_self_and_draw_filtered(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "定向抽牌状态缺少运行依赖"}
    _remove_self(context)
    var candidates: Array = context.holder.draw_pile.filter(
        func(card): return card.is_attribute(str(context.behavior.get("attribute", ""))))
    if candidates.is_empty():
        return {"success": true, "applied": false}
    var index: int = context.rng.randi_range(0, candidates.size() - 1) \
        if context.rng != null else 0
    var chosen = candidates[index]
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder, "draw_pile", context.holder, "hand", chosen, "draw",
        "top", _source_metadata(context))
    return {"success": bool(moved.get("success", false)), "card": chosen}

func _remove_self_and_discard_non_attribute(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "乱流缺少运行依赖"}
    _remove_self(context)
    var attribute_id := str(context.behavior.get("attribute", ""))
    var candidates: Array = context.holder.hand.filter(func(card):
        return not card.is_attribute(attribute_id) \
            and bool(context.effect_ports.can_explicit_discard(
                context.holder, card).get("allowed", true)))
    if candidates.is_empty():
        return {"success": true, "applied": false}
    var index: int = context.rng.randi_range(0, candidates.size() - 1) \
        if context.rng != null else 0
    var chosen = candidates[index]
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder, "hand", context.holder, "discard_pile",
        chosen, "explicit_discard", "top", _source_metadata(context))
    return {
        "success": bool(moved.get("success", false)),
        "stop_card_behaviors": chosen == context.card and bool(moved.get("success", false)),
        "card": chosen,
    }

func _remove_self_and_shuffle_into_draw_pile(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "重聚缺少运行依赖"}
    if not context.holder.discard_pile.has(context.card):
        return {"success": true, "applied": false}
    _remove_self(context)
    var moved: Dictionary = context.effect_ports.move_card(
        context.holder, "discard_pile", context.holder, "draw_pile",
        context.card, "regroup", "top", _source_metadata(context))
    if moved.get("success", false) and context.rng != null:
        context.effect_ports.shuffle_zone(context.holder, "draw_pile", context.rng)
    return {"success": bool(moved.get("success", false))}

func _temporarily_remove_if_in_hand(context) -> Dictionary:
    if context.holder == null or context.card == null or context.effect_ports == null:
        return {"success": false, "detail": "虚无缺少运行依赖"}
    if not context.holder.hand.has(context.card):
        return {"success": true, "applied": false}
    return context.effect_ports.temporarily_remove_card(
        context.holder,
        str(context.card.id),
        str(context.behavior.get("reason", context.status_id)))

func _block_play(context) -> Dictionary:
    return {
        "success": true,
        "blocked": true,
        "reason": str(context.behavior.get(
            "reason", "%s令此真气本回合不能打出" % str(
                context.definition.get("name", context.status_id)))),
    }

func _remove_self_behavior(context) -> Dictionary:
    _remove_self(context)
    return {"success": true}

func _remove_self_with_resolution(context) -> Dictionary:
    _remove_self(context)
    return {
        "success": true,
        "resolution": {
            "card": context.card,
            "category": context.category,
            "anomaly_id": context.status_id,
            "anomaly_name": str(context.definition.get("name", context.status_id)),
            "effect_kind": str(context.behavior.get("effect_kind", "status")),
            "detail": str(context.behavior.get("detail", "状态已结算")),
        },
    }

func _source_metadata(context) -> Dictionary:
    return {
        "holder": context.holder,
        "source_actor": context.holder,
        "action_token": context.action_token,
        "source_kind": "card_status",
        "source_id": context.status_id,
        "source_name": str(context.definition.get("name", context.status_id)),
        "source_instance_key": "card_status:%s:%s" % [
            str(context.card.id), context.status_id],
        "trigger_mode": "direct",
    }

func _remove_self(context) -> void:
    context.card_anomaly_service.remove_card_anomaly(
        context.card,
        context.category,
        context.status_id,
        "%s触发" % str(context.definition.get("name", context.status_id)),
        _source_metadata(context))
