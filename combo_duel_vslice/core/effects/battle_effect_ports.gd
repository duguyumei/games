class_name BattleEffectPorts
extends RefCounted

const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")
const BattleSurvivalEffectServiceScript = preload(
    "res://core/effects/battle_survival_effect_service.gd")
const BattleCardEffectServiceScript = preload(
    "res://core/effects/battle_card_effect_service.gd")
const BattleSourceResourceEffectServiceScript = preload(
    "res://core/effects/battle_source_resource_effect_service.gd")
const BattleInvocationEffectServiceScript = preload(
    "res://core/effects/battle_invocation_effect_service.gd")
const BattleResponseEffectServiceScript = preload(
    "res://core/effects/battle_response_effect_service.gd")

## 效果处理器修改战斗状态的唯一窄端口。
##
## 四个依赖是必需的，不接受 null：端口一旦允许缺依赖，每个方法都要带一条兜底分支，
## 而兜底分支会在依赖真的缺失时静默改用另一套判定，把装配错误伪装成正常结果。
## 装配失败应当在构造点暴露，不应推迟到某个效果结算时。

var _battle_flow: BattleFlowCoordinator
var _trigger_queue: VisibleTriggerQueue
var _sides: Array[BattleSide] = []
var _consumable_repository
var _battle_rule_query_service
var _battle_rng: RandomNumberGenerator
var _survival_effect_service
var _card_effect_service
var _source_resource_effect_service
var _invocation_effect_service
var _response_effect_service

func _init(
        damage_resolver: ComboDamageResolver,
        status_system: StatusSystem,
        battle_flow: BattleFlowCoordinator,
        trigger_queue: VisibleTriggerQueue) -> void:
    _battle_flow = battle_flow
    _trigger_queue = trigger_queue
    _survival_effect_service = BattleSurvivalEffectServiceScript.new(
        damage_resolver, status_system, trigger_queue)
    _card_effect_service = BattleCardEffectServiceScript.new(status_system)
    _source_resource_effect_service = BattleSourceResourceEffectServiceScript.new(
        status_system,
        trigger_queue,
        Callable(_survival_effect_service, "current_action_window_id"),
        Callable(_survival_effect_service, "can_bind_current_source"),
        Callable(_survival_effect_service, "close_current_source_binding_window"))
    _invocation_effect_service = BattleInvocationEffectServiceScript.new()
    _response_effect_service = BattleResponseEffectServiceScript.new(status_system)

func use_trigger_queue(trigger_queue: VisibleTriggerQueue) -> void:
    _trigger_queue = trigger_queue
    _survival_effect_service.use_trigger_queue(trigger_queue)
    _source_resource_effect_service.use_trigger_queue(trigger_queue)

func use_sides(first: BattleSide, second: BattleSide) -> void:
    _sides = [first, second]
    _survival_effect_service.use_sides(first, second)
    _card_effect_service.use_sides(first, second)

func use_hand_retrigger_callback(callback: Callable) -> void:
    _invocation_effect_service.use_hand_retrigger_callback(callback)

func use_card_reshape_runtime(runtime) -> void:
    _card_effect_service.use_card_reshape_runtime(runtime)
    _response_effect_service.use_card_reshape_runtime(runtime)

func use_battle_permission_service(service) -> void:
    _card_effect_service.use_battle_permission_service(service)

func use_consumable_repository(repository) -> void:
    _consumable_repository = repository

func use_passive_battle_services(
        query_service,
        event_service,
        round_reader: Callable = Callable()) -> void:
    _battle_rule_query_service = query_service
    _survival_effect_service.use_passive_battle_services(
        query_service, event_service, round_reader)
    _source_resource_effect_service.use_passive_battle_services(
        event_service, round_reader)
    _invocation_effect_service.use_passive_battle_services(
        event_service, round_reader)

func use_battle_rng(rng: RandomNumberGenerator) -> void:
    _battle_rng = rng
    _card_effect_service.use_battle_rng(rng)

func battle_rng() -> RandomNumberGenerator:
    return _battle_rng

func use_battle_instance_id(value: String) -> void:
    _source_resource_effect_service.use_battle_instance_id(value)

func use_effect_executor(executor) -> void:
    _invocation_effect_service.use_effect_executor(executor)

func use_same_qi_gauge_service(service) -> void:
    _source_resource_effect_service.use_same_qi_gauge_service(service)

func use_technique_invocation_service(service) -> void:
    _invocation_effect_service.use_technique_invocation_service(service)

func push_effect_context(context) -> void:
    _invocation_effect_service.push_effect_context(context)

func pop_effect_context(context) -> void:
    _invocation_effect_service.pop_effect_context(context)

func current_effect_context():
    return _invocation_effect_service.current_effect_context()

func schedule_immediate_effect(context, effect: Dictionary) -> bool:
    return _invocation_effect_service.schedule_immediate_effect(context, effect)

func take_immediate_effects(context) -> Array:
    return _invocation_effect_service.take_immediate_effects(context)

func same_qi_projection(side: BattleSide, amount: int, context: Dictionary = {}) -> Dictionary:
    return _source_resource_effect_service.same_qi_projection(side, amount, context)

func gain_same_qi(
        side: BattleSide,
        amount: int,
        source: String,
        token: String) -> Dictionary:
    return _source_resource_effect_service.gain_same_qi(
        side, amount, source, token)

func write_same_qi(
        side: BattleSide,
        operation: String,
        amount: int,
        source: String,
        token: String,
        source_category: String = "effect",
        action_token: String = "") -> Dictionary:
    return _source_resource_effect_service.write_same_qi(
        side, operation, amount, source, token, source_category, action_token)

func same_qi_receipts_for_action(side: BattleSide, action_token: String) -> Array:
    return _source_resource_effect_service.same_qi_receipts_for_action(
        side, action_token)

func execute_effect_chain(effects: Array, context) -> Dictionary:
    return _invocation_effect_service.execute_effect_chain(effects, context)

func battle_instance_id() -> String:
    return _source_resource_effect_service.battle_instance_id()

func is_current_side(side) -> bool:
    return side != null and _sides.has(side)

func locate_active_card(card_instance_id: String) -> Dictionary:
    return _card_effect_service.locate_active_card(card_instance_id)

func opponent_of(side: BattleSide) -> BattleSide:
    for candidate in _sides:
        if candidate != side:
            return candidate
    return null

func side_holding_card(card, zone: String) -> BattleSide:
    return _card_effect_service.side_holding_card(card, zone)

func deal_damage(
        actor: BattleSide,
        target: BattleSide,
        amount: int,
        source_kind,
        true_damage: bool = false,
        action_token: String = "",
        damage_type: String = "",
        resolution_metadata: Dictionary = {}) -> Dictionary:
    var effect_source := _effect_source_metadata(source_kind)
    var resolved_metadata := resolution_metadata.duplicate(true)
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode"]:
        resolved_metadata[field] = effect_source[field]
    return _survival_effect_service.deal_damage(
        actor, target, amount, str(effect_source["source_kind"]), true_damage,
        action_token, damage_type, resolved_metadata, effect_source)

func actor_can_continue(side: BattleSide) -> bool:
    return _survival_effect_service.actor_can_continue(side)

func target_can_receive(side: BattleSide) -> bool:
    return _survival_effect_service.target_can_receive(side)

func resolve_poison_segment_amount(
        affected_side: BattleSide,
        base_amount: int,
        receipt_token: String = "") -> Dictionary:
    return _survival_effect_service.resolve_poison_segment_amount(
        affected_side, base_amount, receipt_token)

func begin_synchronized_damage(records: Array) -> void:
    _survival_effect_service.begin_synchronized_damage(records)

func begin_action_resolution(actors: Array, metadata: Dictionary = {}) -> void:
    _survival_effect_service.begin_action_resolution(actors, metadata)

func close_current_source_binding_window() -> void:
    _source_resource_effect_service.close_current_source_binding_window()

func finish_action_resolution() -> Dictionary:
    return _survival_effect_service.finish_action_resolution()

func abort_action_resolution() -> void:
    _survival_effect_service.abort_action_resolution()
    _invocation_effect_service.abort_action_resolution()

func flush_synchronized_damage() -> Array:
    return _survival_effect_service.flush_synchronized_damage()

func trigger_poison_card(
        holder: BattleSide,
        card,
        action_token: String = "",
        replayed: bool = false,
        frozen_amount_override = null) -> Dictionary:
    if holder == null or card == null or not card.has_anomaly("state", "poison"):
        return {"success": false, "reason": "毒触发目标无效"}
    var frozen_amount: int = (
        current_effective_qi(holder, card)
        if frozen_amount_override == null else maxi(0, int(frozen_amount_override)))
    var damage: Dictionary = deal_damage(
        holder, holder, frozen_amount, {
            "source_kind": "card_status",
            "source_id": "poison",
            "source_name": "毒",
            "source_instance_key": "card_status:%s:poison" % str(card.id),
            "trigger_mode": "direct",
        }, false, action_token, "poison", {
            "kind": "poison_card_trigger",
            "holder": holder,
            "card": card,
            "frozen_amount": frozen_amount,
            "action_token": action_token,
            "poison_modifier_receipt_token": "%s:poison:%s" % [
                action_token, str(card.id)],
            "replayed": replayed,
        })
    if not damage.get("success", false):
        return damage
    var removed: Dictionary = remove_card_anomaly(
        card, "state", "poison", "毒触发", {
            "source_kind": "card_status",
            "source_id": "poison",
            "source_name": "毒",
            "source_instance_key": "card_status:%s:poison" % str(card.id),
            "trigger_mode": "direct",
        })
    if not removed.get("changed", false):
        return {"success": false, "reason": "毒伤完成后清除毒失败", "damage_result": damage}
    if not bool(damage.get("buffered", false)):
        notify_poison_triggered(
            holder, card, frozen_amount, damage, action_token, replayed)
    return {
        "success": true,
        "card": card,
        "frozen_amount": frozen_amount,
        "life_lost": int(damage.get("life_lost", 0)),
        "actual_life_loss": int(damage.get("life_lost", 0)),
        "damage_result": damage,
        "buffered": bool(damage.get("buffered", false)),
    }

func add_defense(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "") -> int:
    return _survival_effect_service.add_defense(
        side, amount, source_kind, action_token)

func add_defense_result(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "") -> Dictionary:
    return _survival_effect_service.add_defense_result(
        side, amount, source_kind, action_token)

func recover_life(
        side: BattleSide,
        amount: int,
        source_kind: String = "effect",
        action_token: String = "",
        source_actor = null) -> Dictionary:
    return _survival_effect_service.recover_life(
        side, amount, source_kind, action_token, source_actor)

func remove_defense(
        side: BattleSide,
        amount: int,
        remove_all: bool,
        source_actor = null,
        source_kind: String = "effect",
        action_token: String = "",
        cause: String = "direct_effect",
        require_full: bool = false) -> Dictionary:
    return _survival_effect_service.remove_defense(
        side, amount, remove_all, source_actor, source_kind,
        action_token, cause, require_full)

func write_source_marker(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        amount: int,
        action_token: String = "") -> Dictionary:
    return _source_resource_effect_service.write_source_marker(
        side, source, operation, amount, action_token)

func transfer_source_marker(
        side: BattleSide,
        source: Dictionary,
        target: Dictionary,
        amount: int,
        action_token: String = "") -> Dictionary:
    return _source_resource_effect_service.transfer_source_marker(
        side, source, target, amount, action_token)

func append_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        records: Array,
        action_token: String = "") -> Dictionary:
    return _source_resource_effect_service.append_source_marker_records(
        side, source, records, action_token)

func consume_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        count: int,
        action_token: String = "") -> Dictionary:
    return _source_resource_effect_service.consume_source_marker_records(
        side, source, count, action_token)

func invoke_sequence_technique(effect: Dictionary, context) -> Dictionary:
    return _invocation_effect_service.invoke_sequence_technique(effect, context)

func resolve_after_caller_advance(root_action_token: String) -> Dictionary:
    return _invocation_effect_service.resolve_after_caller_advance(root_action_token)

func resolve_technique_invocations_at_timing(
        timing: String,
        root_action_token: String = "") -> Dictionary:
    return _invocation_effect_service.resolve_technique_invocations_at_timing(
        timing, root_action_token)

func emit_technique_sequence_changed(
        side: BattleSide,
        action_token: String,
        reason: String,
        changed_slots: Array) -> void:
    _invocation_effect_service.emit_technique_sequence_changed(
        side, action_token, reason, changed_slots)

func add_momentum(side: BattleSide, amount: int) -> int:
    return _source_resource_effect_service.add_momentum(side, amount)

func set_momentum(side: BattleSide, value: int) -> int:
    return _source_resource_effect_service.set_momentum(side, value)

func write_momentum(
        side: BattleSide,
        operation: String,
        amount: int,
        source_category: String,
        action_token: String,
        source_id: String = "") -> Dictionary:
    return _source_resource_effect_service.write_momentum(
        side, operation, amount, source_category, action_token, source_id)

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _card_effect_service.transfer_card_anomaly(
        source_card, target_card, category, anomaly_id, source, event_metadata)

func set_reflection_percent(
        side: BattleSide, value: int, source_token: String = "") -> int:
    return _source_resource_effect_service.set_reflection_percent(
        side, value, source_token)

func grant_reflection_source(
        side: BattleSide,
        percent: int,
        remaining_rounds: int,
        expiry_kind: String,
        label: String,
        source_token: String = "",
        target_side: BattleSide = null) -> Dictionary:
    return _source_resource_effect_service.grant_reflection_source(
        side, percent, remaining_rounds, expiry_kind, label,
        source_token, target_side)

func grant_reflection_true_damage_source(
        side: BattleSide,
        remaining_rounds: int,
        label: String,
        source_token: String = "") -> Dictionary:
    return _source_resource_effect_service.grant_reflection_true_damage_source(
        side, remaining_rounds, label, source_token)

func grant_block_source(
        side: BattleSide,
        target_side: BattleSide,
        condition,
        label: String,
        source_token: String = "",
        metadata: Dictionary = {}) -> Dictionary:
    return _source_resource_effect_service.grant_block_source(
        side, target_side, condition, label, source_token, metadata)

func register_challenge(
        context,
        threshold: int,
        effects: Array,
        label: String = "邀战",
        met_effects: Array = []) -> Dictionary:
    return _source_resource_effect_service.register_challenge(
        context, threshold, effects, label, met_effects)

func notify_source_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> void:
    _source_resource_effect_service.notify_source_changed(
        event_kind, side, record, change, payload)

func add_direct_power_fixed(side: BattleSide, amount: int) -> int:
    return _source_resource_effect_service.add_direct_power_fixed(side, amount)

func add_direct_power_percent(side: BattleSide, amount: int) -> int:
    return _source_resource_effect_service.add_direct_power_percent(side, amount)

func gain_battle_experience(side: BattleSide, amount: int) -> int:
    var gained := maxi(0, amount)
    side.experience += gained
    return gained

func generate_temporary_normal_card(
        side: BattleSide,
        source,
        options: Dictionary = {}):
    return _card_effect_service.generate_temporary_normal_card(
        side, source, options)

func steal_random_normal_card(
        actor: BattleSide, target: BattleSide, source_value = "") -> Dictionary:
    return _card_effect_service.steal_random_normal_card(
        actor, target, _effect_source_metadata(source_value))

func recover_forest_priority(
        actor: BattleSide,
        maximum_qi: int,
        prefer_permanent: bool,
        source_value = "") -> Dictionary:
    return _card_effect_service.recover_forest_priority(
        actor, maximum_qi, prefer_permanent,
        _effect_source_metadata(source_value))

func burn_deck_then_heat_hand(
        actor: BattleSide, bottom_first: bool, choice_capture: String, context) -> Dictionary:
    return _card_effect_service.burn_deck_then_heat_hand(
        actor, bottom_first, choice_capture, context)

func can_grant_battle_consumable(side: BattleSide) -> bool:
    return side.consumable_ids.size() < side.consumable_limit

func grant_battle_consumable(side: BattleSide, consumable_id: String) -> bool:
    return side.grant_consumable(consumable_id)

func consumable_ids_by_kind(kind: String) -> Array[String]:
    return _consumable_repository.ids_by_kind(kind)

func place_on_draw_pile_top(side: BattleSide, card) -> Dictionary:
    return _card_effect_service.place_on_draw_pile_top(side, card)

func temporarily_remove_card(
        side: BattleSide,
        instance_id: String,
        reason: String,
        source_value = "") -> Dictionary:
    return _card_effect_service.temporarily_remove_card(
        side, instance_id, reason, _effect_source_metadata(source_value))

func can_explicit_discard(side: BattleSide, card) -> Dictionary:
    return _card_effect_service.can_explicit_discard(side, card)

func notify_cards_played(
        side: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array[Dictionary]:
    var runtime = _card_effect_service.card_reshape_runtime()
    return runtime.on_card_played(
        side, cards, source_values) if runtime != null else []

func notify_poison_triggered(
        holder: BattleSide,
        card,
        frozen_amount: int,
        damage_result: Dictionary,
        action_token: String = "",
        replayed: bool = false) -> void:
    _survival_effect_service.notify_poison_triggered(
        holder, card, frozen_amount, damage_result, action_token, replayed)

func notify_response_event(event_kind: String, values: Dictionary) -> void:
    _response_effect_service.notify_response_event(event_kind, values)

func successful_on_play_ids(action_token: String) -> Array:
    return _response_effect_service.successful_on_play_ids(action_token)

func register_direct_card_trigger_listener(
        listener_id: String,
        listener) -> bool:
    return _response_effect_service.register_direct_card_trigger_listener(
        listener_id, listener)

func unregister_direct_card_trigger_listener(listener_id: String) -> bool:
    return _response_effect_service.unregister_direct_card_trigger_listener(
        listener_id)

func finalize_reshape_action(side: BattleSide, preview: Dictionary) -> Dictionary:
    return _card_effect_service.finalize_reshape_action(side, preview)

func draw(side: BattleSide, count: int, source_value = "") -> Array:
    return _card_effect_service.draw(
        side, count, _draw_source_metadata(source_value))

func _draw_source_metadata(source_value) -> Dictionary:
    if source_value is Dictionary:
        var result := EffectSourceProtocolScript.from_values(source_value)
        result["draw_reason"] = str(source_value.get("draw_reason", "effect_draw"))
        return result
    var legacy := str(source_value)
    if legacy in EffectSourceProtocolScript.SOURCE_KINDS \
            or EffectSourceProtocolScript.LEGACY_SOURCE_MODES.has(legacy):
        var result := EffectSourceProtocolScript.from_values({
            "source_kind": legacy,
        })
        result["draw_reason"] = "effect_draw"
        return result
    var reason := legacy if legacy != "" else "effect_draw"
    return {
        "source_kind": "rule",
        "source_id": reason,
        "source_name": reason,
        "source_instance_key": "rule:%s" % reason,
        "trigger_mode": "direct",
        "draw_reason": reason,
    }

func _effect_source_metadata(source_value) -> Dictionary:
    if source_value is Dictionary:
        return EffectSourceProtocolScript.from_values(source_value)
    if source_value is Object:
        return EffectSourceProtocolScript.from_context(source_value)
    var legacy := str(source_value)
    if legacy in EffectSourceProtocolScript.SOURCE_KINDS \
            or EffectSourceProtocolScript.LEGACY_SOURCE_MODES.has(legacy):
        return EffectSourceProtocolScript.from_values({
            "source_kind": legacy,
            "source_id": legacy,
            "source_name": legacy,
            "source_instance_key": "%s:%s" % [legacy, legacy],
            "trigger_mode": "direct",
        })
    var rule_id := legacy if legacy != "" else "effect"
    return EffectSourceProtocolScript.from_values({
        "source_kind": "rule",
        "source_id": rule_id,
        "source_name": rule_id,
        "source_instance_key": "rule:%s" % rule_id,
        "trigger_mode": "direct",
    })

func shuffle_zone(
        side: BattleSide,
        zone: String,
        rng: RandomNumberGenerator) -> void:
    _card_effect_service.shuffle_zone(side, zone, rng)

func current_effective_qi(side: BattleSide, card) -> int:
    return _card_effect_service.current_effective_qi(side, card)

func discard_random(
        side: BattleSide,
        count: int,
        rng: RandomNumberGenerator,
        source_value = "") -> Array:
    return _card_effect_service.discard_random(
        side, count, rng, _effect_source_metadata(source_value))

func discard_all(side: BattleSide, source_value = "") -> Array:
    return _card_effect_service.discard_all(
        side, _effect_source_metadata(source_value))

func move_card(
        source_side: BattleSide,
        source_zone: String,
        target_side: BattleSide,
        destination_zone: String,
        card,
        reason: String = "effect",
        placement: String = "top",
        source_kind = "") -> Dictionary:
    return _card_effect_service.move_card(
        source_side, source_zone, target_side, destination_zone, card,
        reason, placement, _effect_source_metadata(source_kind))

func move_cards_synchronously(records: Array, source_value = "") -> Array:
    return _card_effect_service.move_cards_synchronously(
        records, _effect_source_metadata(source_value))

func transfer_cards_atomically(records: Array, source_value = "") -> Array:
    return _card_effect_service.transfer_cards_atomically(
        records, _effect_source_metadata(source_value))

func atomic_exchange_cards(
        actor_side: BattleSide, actor_zone: String, actor_card,
        target_side: BattleSide, target_zone: String, target_card,
        source_value = "") -> Dictionary:
    return _card_effect_service.atomic_exchange_cards(
        actor_side, actor_zone, actor_card, target_side, target_zone, target_card,
        _effect_source_metadata(source_value))

func zone_cards(side: BattleSide, zone: String) -> Array:
    return _card_effect_service.zone_cards(side, zone)

func query_effect_targets(context, query_spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    return _card_effect_service.query_effect_targets(context, query_spec, rng)

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String,
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _card_effect_service.apply_card_anomaly(
        card, category, anomaly_id, payload, source, layers, replace_state,
        event_metadata)

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return _card_effect_service.can_apply_card_anomaly(
        card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _card_effect_service.remove_card_anomaly(
        card, category, anomaly_id, source, event_metadata)

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    return _card_effect_service.set_card_anomaly_layers(
        card, category, anomaly_id, layers, source)

func apply_temporary_enhancement(card, enhancement_id: String) -> Dictionary:
    return _card_effect_service.apply_temporary_enhancement(
        card, enhancement_id)

func apply_temporary_attribute(card, attribute_id: String) -> Dictionary:
    return _card_effect_service.apply_temporary_attribute(card, attribute_id)

func apply_temporary_rank(
        card,
        rank_name: String,
        rank_order: int,
        base_qi: int) -> Dictionary:
    return _card_effect_service.apply_temporary_rank(
        card, rank_name, rank_order, base_qi)

func clear_temporary_reshape(card, subslot: String) -> Dictionary:
    return _card_effect_service.clear_temporary_reshape(card, subslot)

func clear_all_temporary_reshapes(card) -> Dictionary:
    return _card_effect_service.clear_all_temporary_reshapes(card)

func resolve_played_card_anomalies(
        holder: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array:
    var results: Array = _card_effect_service.resolve_played_card_anomalies(
        holder, cards, source_values)
    notify_cards_played(holder, cards, source_values)
    return results

func gain_extra_actions(
        side: BattleSide,
        amount: int,
        source: String,
        source_category: String = "rule",
        action_token: String = "") -> int:
    var gained: int = _battle_flow.grant_actions(side, amount, {
        "category": source_category,
        "source": source,
        "action_token": action_token,
        "from_same_qi": source_category == "same_qi",
    })
    add_history(
        "action_end",
        "%s额外出牌机会" % side.name,
        source,
        "成功",
        "+%d（连击不自动补牌）" % gained)
    return gained

func register_delayed_effects(
        label: String,
        timing: String,
        occurrences: int,
        effects: Array,
        context) -> Dictionary:
    return _response_effect_service.register_delayed_effects(
        label, timing, occurrences, effects, context)

func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = []) -> Dictionary:
    return _response_effect_service.register_response(
        event_kind, expiry, effects, context, filters, expiry_effects)

func register_next_round_hand_limit(
        context, amount: int, affected_side = null) -> Dictionary:
    return _response_effect_service.register_next_round_hand_limit(
        context, amount, affected_side)

func register_defense_decay_return(context) -> Dictionary:
    return _response_effect_service.register_defense_decay_return(context)

func register_reflection_expiry(context, percent: int) -> Dictionary:
    return _response_effect_service.register_reflection_expiry(context, percent)

func register_no_life_loss_disruption(context, effect: Dictionary) -> Dictionary:
    return _response_effect_service.register_no_life_loss_disruption(
        context, effect)

func technique_draw_count(side: BattleSide) -> int:
    return _response_effect_service.technique_draw_count(side)

func retrigger_current_hand_technique(
        actor: BattleSide,
        target: BattleSide,
        sequence_book,
        power_snapshot: Dictionary,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    return _invocation_effect_service.retrigger_current_hand_technique(
        actor,
        target,
        sequence_book,
        power_snapshot,
        maximum_discard,
        excluded_technique_ids)

func add_history(
        timing: String,
        label: String,
        source: String,
        result: String,
        detail: String = "") -> void:
    _trigger_queue.add_history(timing, label, source, result, detail)
