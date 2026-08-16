class_name BattleEffectPorts
extends RefCounted

const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")
const BattleSurvivalEffectServiceScript = preload(
    "res://core/effects/battle_survival_effect_service.gd")

## 效果处理器修改战斗状态的唯一窄端口。
##
## 四个依赖是必需的，不接受 null：端口一旦允许缺依赖，每个方法都要带一条兜底分支，
## 而兜底分支会在依赖真的缺失时静默改用另一套判定，把装配错误伪装成正常结果。
## 装配失败应当在构造点暴露，不应推迟到某个效果结算时。

var _status_system: StatusSystem
var _battle_flow: BattleFlowCoordinator
var _trigger_queue: VisibleTriggerQueue
var _sides: Array[BattleSide] = []
var _hand_retrigger_callback: Callable
var _card_reshape_runtime_ref: WeakRef
var _consumable_repository
var _battle_rule_query_service
var _committed_event_service
var _round_number_reader: Callable
var _battle_rng: RandomNumberGenerator
var _battle_instance_id: String = "battle-0"
var _effect_executor_ref: WeakRef
var _same_qi_gauge_service
var _technique_invocation_service_ref: WeakRef
var _effect_context_stack: Array = []
var _effect_context_slot_entries: Dictionary = {}
var _immediate_effects_by_context: Dictionary = {}
var _survival_effect_service

func _init(
        damage_resolver: ComboDamageResolver,
        status_system: StatusSystem,
        battle_flow: BattleFlowCoordinator,
        trigger_queue: VisibleTriggerQueue) -> void:
    _status_system = status_system
    _battle_flow = battle_flow
    _trigger_queue = trigger_queue
    _survival_effect_service = BattleSurvivalEffectServiceScript.new(
        damage_resolver, status_system, trigger_queue)

func use_trigger_queue(trigger_queue: VisibleTriggerQueue) -> void:
    _trigger_queue = trigger_queue
    _survival_effect_service.use_trigger_queue(trigger_queue)

func use_sides(first: BattleSide, second: BattleSide) -> void:
    _sides = [first, second]
    _survival_effect_service.use_sides(first, second)

func use_hand_retrigger_callback(callback: Callable) -> void:
    _hand_retrigger_callback = callback

func use_card_reshape_runtime(runtime) -> void:
    _card_reshape_runtime_ref = weakref(runtime)

func use_consumable_repository(repository) -> void:
    _consumable_repository = repository

func use_passive_battle_services(
        query_service,
        event_service,
        round_reader: Callable = Callable()) -> void:
    _battle_rule_query_service = query_service
    _committed_event_service = event_service
    _round_number_reader = round_reader
    _survival_effect_service.use_passive_battle_services(
        query_service, event_service, round_reader)

func use_battle_rng(rng: RandomNumberGenerator) -> void:
    _battle_rng = rng

func battle_rng() -> RandomNumberGenerator:
    return _battle_rng

func use_battle_instance_id(value: String) -> void:
    _battle_instance_id = value if value != "" else "battle-0"

func use_effect_executor(executor) -> void:
    _effect_executor_ref = weakref(executor)

func use_same_qi_gauge_service(service) -> void:
    _same_qi_gauge_service = service

func use_technique_invocation_service(service) -> void:
    _technique_invocation_service_ref = weakref(service) if service != null else null

func push_effect_context(context) -> void:
    _effect_context_stack.append(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null:
        var slot_id := str(context.get("slot_instance_id") \
            if context is Dictionary else context.slot_instance_id)
        _effect_context_slot_entries[context] = {
            "slot_instance_id": slot_id,
            "entered": invocation_service.enter_resolution_slot(slot_id),
        }

func pop_effect_context(context) -> void:
    if not _effect_context_stack.is_empty() and _effect_context_stack.back() == context:
        _effect_context_stack.pop_back()
    else:
        _effect_context_stack.erase(context)
    var invocation_service = _technique_invocation_service()
    if invocation_service != null and _effect_context_slot_entries.has(context):
        var entry: Dictionary = _effect_context_slot_entries[context]
        invocation_service.exit_resolution_slot(
            str(entry.get("slot_instance_id", "")), bool(entry.get("entered", false)))
        _effect_context_slot_entries.erase(context)

func current_effect_context():
    return _effect_context_stack.back() if not _effect_context_stack.is_empty() else null

func schedule_immediate_effect(context, effect: Dictionary) -> bool:
    if context == null or effect.is_empty():
        return false
    if not _immediate_effects_by_context.has(context):
        _immediate_effects_by_context[context] = []
    _immediate_effects_by_context[context].append(effect.duplicate(true))
    return true

func take_immediate_effects(context) -> Array:
    var result: Array = _immediate_effects_by_context.get(context, [])
    _immediate_effects_by_context.erase(context)
    return result

func same_qi_projection(side: BattleSide, amount: int, context: Dictionary = {}) -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    return _same_qi_gauge_service.project_gain(side, amount, context)

func gain_same_qi(
        side: BattleSide,
        amount: int,
        source: String,
        token: String) -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    var result: Dictionary = _same_qi_gauge_service.apply_gain(
        side, amount, source, token)
    if result.get("success", false) and not result.get("reused", false):
        add_history(
            "same_qi_changed",
            "%s同气变化" % side.name,
            source,
            "成功",
            "%d +%d -%d = %d / %d；额外行动 +%d" % [
                int(result["same_qi_before"]), int(result["gained"]),
                int(result["spent"]), int(result["same_qi_after"]),
                int(result["same_qi_capacity"]),
                int(result["granted_actions"]),
            ])
        var response := result.duplicate(true)
        response["actor"] = side
        response["owner"] = side
        response["holder"] = side
        response["action_token"] = token.trim_suffix(":same_qi")
        if _committed_event_service != null:
            var serial := int(_committed_event_service.next_serial())
            response["event_serial"] = serial
            response["event_token"] = _committed_event_service.make_token(
                "same_qi_gain_resolved", side, serial, response["action_token"])
            _committed_event_service.commit("same_qi_gain_resolved", response)
        else:
            _status_system.handle_response_event("same_qi_gain_resolved", response)
    return result

func write_same_qi(
        side: BattleSide,
        operation: String,
        amount: int,
        source: String,
        token: String,
        source_category: String = "effect",
        action_token: String = "") -> Dictionary:
    if _same_qi_gauge_service == null:
        return {"success": false, "reason": "同气槽服务尚未装配"}
    var resolved_action_token := action_token if action_token != "" \
        else token.split(":same_qi")[0]
    var result: Dictionary = _same_qi_gauge_service.apply_write(
        side, operation, amount, source, token, {
            "source_category": source_category,
            "action_token": resolved_action_token,
        })
    if result.get("success", false) and not result.get("reused", false):
        add_history(
            "same_qi_changed", "%s同气变化" % side.name, source, "成功",
            "%d → %d / %d；转换%d次" % [
                int(result.get("same_qi_before", 0)),
                int(result.get("same_qi_after", 0)),
                int(result.get("same_qi_capacity", 5)),
                int(result.get("conversion_count", 0)),
            ])
        var response := result.duplicate(true)
        response["actor"] = side
        response["owner"] = side
        response["holder"] = side
        response["action_token"] = resolved_action_token
        if _committed_event_service != null:
            var serial := int(_committed_event_service.next_serial())
            response["event_serial"] = serial
            response["event_token"] = _committed_event_service.make_token(
                "same_qi_gain_resolved", side, serial, resolved_action_token)
            _committed_event_service.commit("same_qi_gain_resolved", response)
        else:
            _status_system.handle_response_event("same_qi_gain_resolved", response)
    return result

func same_qi_receipts_for_action(side: BattleSide, action_token: String) -> Array:
    if _same_qi_gauge_service == null:
        return []
    return _same_qi_gauge_service.receipts_for_action(side, action_token)

func execute_effect_chain(effects: Array, context) -> Dictionary:
    var executor = _effect_executor_ref.get_ref() if _effect_executor_ref != null else null
    var parent = current_effect_context()
    if executor != null and parent != null \
            and not context is Dictionary \
            and not parent is Dictionary \
            and int(parent.effect_command_limit) > 0:
        context.effect_command_limit = int(parent.effect_command_limit)
        context.effect_chain_state = parent.effect_chain_state
    return executor.execute_all(effects, context) if executor != null else {
        "success": false, "detail": "战斗端口缺少效果执行器"}

func battle_instance_id() -> String:
    return _battle_instance_id

func is_current_side(side) -> bool:
    return side != null and _sides.has(side)

func locate_active_card(card_instance_id: String) -> Dictionary:
    if card_instance_id == "":
        return {"success": false, "reason": "卡牌实例 ID 不能为空"}
    var matches: Array[Dictionary] = []
    for side in _sides:
        var location: Dictionary = side.card_zone_service.find_active_location(
            side, card_instance_id)
        if not location.is_empty():
            matches.append({
                "side": side,
                "zone": str(location["zone"]),
                "card": location["card"],
            })
    if matches.is_empty():
        return {"success": false, "reason": "当前战斗不存在目标卡牌"}
    if matches.size() > 1:
        return {"success": false, "reason": "当前战斗存在重复卡牌实例 ID"}
    var result: Dictionary = matches[0]
    result["success"] = true
    return result

func opponent_of(side: BattleSide) -> BattleSide:
    for candidate in _sides:
        if candidate != side:
            return candidate
    return null

func side_holding_card(card, zone: String) -> BattleSide:
    for side in _sides:
        if zone_cards(side, zone).has(card):
            return side
    return null

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
    _survival_effect_service.close_current_source_binding_window()

func finish_action_resolution() -> Dictionary:
    return _survival_effect_service.finish_action_resolution()

func abort_action_resolution() -> void:
    _survival_effect_service.abort_action_resolution()
    _immediate_effects_by_context.clear()

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
    var result: Dictionary = side.source_marker_store.write(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("content_id", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")), operation, amount, source)
    if result.get("success", false) and result.get("changed", false):
        _emit_source_marker_changed(side, source, operation, result, action_token)
        if str(source.get("scope", "battle")) == "run" \
                and str(source.get("contributes_to", "")) != "":
            side.recalculate_effective_max_life()
    return result

func transfer_source_marker(
        side: BattleSide,
        source: Dictionary,
        target: Dictionary,
        amount: int,
        action_token: String = "") -> Dictionary:
    var result: Dictionary = side.source_marker_store.transfer(source, target, amount)
    if result.get("success", false) and int(result.get("transferred", 0)) > 0:
        _emit_source_marker_changed(
            side, source, "transfer_out", result.get("source", {}), action_token)
        _emit_source_marker_changed(
            side, target, "transfer_in", result.get("target", {}), action_token)
        if str(source.get("scope", "battle")) == "run" \
                or str(target.get("scope", "battle")) == "run":
            side.recalculate_effective_max_life()
    return result

func append_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        records: Array,
        action_token: String = "") -> Dictionary:
    var result: Dictionary = side.source_marker_store.append_records(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("content_id", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")),
        records,
        source)
    if result.get("success", false):
        _emit_source_marker_changed(
            side, source, "append_records", result, action_token)
    return result

func consume_source_marker_records(
        side: BattleSide,
        source: Dictionary,
        count: int,
        action_token: String = "") -> Dictionary:
    var result: Dictionary = side.source_marker_store.consume_records(
        str(source.get("source_kind", "")),
        str(source.get("source_instance_key", "")),
        str(source.get("marker_id", "")),
        str(source.get("scope", "battle")),
        count)
    if result.get("success", false):
        _emit_source_marker_changed(
            side, source, "consume_records", result, action_token)
    return result

func invoke_sequence_technique(effect: Dictionary, context) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": false, "reason": "功法调用服务尚未装配"}
    return invocation_service.invoke(effect, context)

func resolve_after_caller_advance(root_action_token: String) -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_after_caller_advance(root_action_token)

func resolve_technique_invocations_at_timing(
        timing: String,
        root_action_token: String = "") -> Dictionary:
    var invocation_service = _technique_invocation_service()
    if invocation_service == null:
        return {"success": true, "results": []}
    return invocation_service.resolve_timing(timing, root_action_token)

func _technique_invocation_service():
    return _technique_invocation_service_ref.get_ref() \
        if _technique_invocation_service_ref != null else null

func emit_technique_sequence_changed(
        side: BattleSide,
        action_token: String,
        reason: String,
        changed_slots: Array) -> void:
    if _committed_event_service == null:
        return
    var serial := int(_committed_event_service.next_serial())
    _committed_event_service.commit("technique_sequence_changed", {
        "event_token": _committed_event_service.make_token(
            "technique_sequence_changed", side, serial, action_token),
        "event_serial": serial, "actor": side, "owner": side,
        "action_token": action_token, "reason": reason,
        "changed_slots": changed_slots.duplicate(true),
        "round_number": _round_number(),
    })

func _emit_source_marker_changed(
        side: BattleSide,
        source: Dictionary,
        operation: String,
        result: Dictionary,
        action_token: String) -> void:
    var values := source.duplicate(true)
    values.merge({
        "actor": side, "owner": side, "holder": side,
        "operation": operation, "before": int(result.get("before", 0)),
        "after": int(result.get("after", 0)),
        "delta": int(result.get("delta", 0)),
        "consumed": int(result.get("consumed", 0)),
        "action_token": action_token, "round_number": _round_number(),
    }, true)
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        values["event_serial"] = serial
        values["event_token"] = _committed_event_service.make_token(
            "source_marker_changed", side, serial, action_token)
        _committed_event_service.commit("source_marker_changed", values)
    if _committed_event_service == null:
        _status_system.handle_response_event("source_marker_changed", values)

func add_momentum(side: BattleSide, amount: int) -> int:
    return side.add_momentum(amount)

func set_momentum(side: BattleSide, value: int) -> int:
    return side.set_momentum(value)

func write_momentum(
        side: BattleSide,
        operation: String,
        amount: int,
        source_category: String,
        action_token: String,
        source_id: String = "") -> Dictionary:
    return side.write_momentum(
        operation, amount, source_category, action_token, source_id)

func transfer_card_anomaly(
        source_card,
        target_card,
        category: String,
        anomaly_id: String,
        source: String,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.transfer_card_anomaly(
        source_card, target_card, category, anomaly_id, source, event_metadata)

func set_reflection_percent(
        side: BattleSide, value: int, source_token: String = "") -> int:
    return side.set_reflection_percent(value, source_token)

func grant_reflection_source(
        side: BattleSide,
        percent: int,
        remaining_rounds: int,
        expiry_kind: String,
        label: String,
        source_token: String = "",
        target_side: BattleSide = null) -> Dictionary:
    var window_id := ""
    if expiry_kind == "action_window_end":
        var target_owner_id := str(target_side.owner_id) if target_side != null else ""
        if _can_bind_current_source(target_owner_id):
            window_id = _current_action_window_id()
    var record := side.add_reflection_source(
        percent, source_token, remaining_rounds, expiry_kind,
        window_id, label, true)
    _emit_source_state_changed(
        "reflection_source_changed", side, record, "established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func grant_reflection_true_damage_source(
        side: BattleSide,
        remaining_rounds: int,
        label: String,
        source_token: String = "") -> Dictionary:
    var record := side.add_reflection_true_damage_source(
        source_token, remaining_rounds, label, true)
    _emit_source_state_changed(
        "reflection_source_changed", side, record, "true_damage_established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func grant_block_source(
        side: BattleSide,
        target_side: BattleSide,
        condition,
        label: String,
        source_token: String = "",
        metadata: Dictionary = {}) -> Dictionary:
    var target_owner_id := str(target_side.owner_id) if target_side != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := side.add_block_source(
        condition, source_token, target_owner_id, window_id,
        label, true, metadata)
    _emit_source_state_changed("block_source_changed", side, record, "established")
    return {"success": true, "record": record, "source_token": record["source_token"]}

func register_challenge(
        context,
        threshold: int,
        effects: Array,
        label: String = "邀战",
        met_effects: Array = []) -> Dictionary:
    var runtime = context
    var token: String = str(runtime.actor.next_combat_source_token("challenge"))
    var target_owner_id := str(runtime.target.owner_id) if runtime.target != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := {
        "source_token": token,
        "threshold": maxi(0, threshold), "current": 0,
        "challenger": runtime.actor, "target": runtime.target,
        "target_owner_id": target_owner_id,
        "window_id": window_id, "waiting_for_action": window_id == "",
        "effects": effects.duplicate(true),
        "met_effects": met_effects.duplicate(true),
        "power": runtime.power, "initial_power": runtime.initial_power,
        "hand_result": runtime.hand_result.duplicate(true),
        "played_cards": runtime.played_cards.duplicate(),
        "group_snapshot": runtime.group_snapshot.duplicate(true),
        "captures": runtime.captures.duplicate(true),
        "technique_id": runtime.technique_id,
        "technique_name": runtime.technique_name,
        "actual_hand_id": runtime.actual_hand_id,
        "branch_hand_id": runtime.branch_hand_id,
        "technique_pool": runtime.technique_pool,
        "action_token": runtime.action_token,
        "source_kind": runtime.source_kind,
        "source_id": runtime.source_id,
        "source_name": runtime.source_name,
        "source_instance_key": runtime.source_instance_key,
        "trigger_mode": runtime.trigger_mode,
        "label": label, "public": true,
    }
    runtime.actor.challenge_records.append(record)
    _emit_source_state_changed(
        "challenge_established", runtime.actor, record, "established")
    return {"success": true, "record": record, "source_token": token}

func notify_source_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> void:
    _emit_source_state_changed(event_kind, side, record, change, payload)

func add_direct_power_fixed(side: BattleSide, amount: int) -> int:
    side.direct_power_fixed += amount
    return side.direct_power_fixed

func add_direct_power_percent(side: BattleSide, amount: int) -> int:
    side.direct_power_percent += amount
    return side.direct_power_percent

func gain_battle_experience(side: BattleSide, amount: int) -> int:
    var gained := maxi(0, amount)
    side.experience += gained
    return gained

func generate_temporary_normal_card(
        side: BattleSide,
        source,
        options: Dictionary = {}):
    if _battle_rng == null:
        return null
    var base_deck = JSON.parse_string(FileAccess.get_file_as_string(
        "res://data/base_deck.json"))
    if not base_deck is Dictionary or not base_deck.get("ranks") is Array:
        return null
    var ranks: Array = base_deck["ranks"]
    var attributes: Array = base_deck.get("attributes", [])
    var base_attribute: String = str(source.get("attribute")) \
        if source is Object else str(source)
    if base_attribute not in ["wind", "forest", "fire", "mountain"]:
        return null
    var attribute := base_attribute
    if str(options.get("attribute_mode", "same_base")) == "random_other_base":
        var attribute_ids: Array[String] = []
        for value in attributes:
            var attribute_id := str(value.get("id", ""))
            if attribute_id != base_attribute:
                attribute_ids.append(attribute_id)
        if attribute_ids.is_empty():
            return null
        attribute = attribute_ids[_battle_rng.randi_range(0, attribute_ids.size() - 1)]
    var rank: Dictionary = ranks[_battle_rng.randi_range(0, ranks.size() - 1)]
    if source is Object and source.has_method("current_rank_order"):
        var source_order := int(source.current_rank_order())
        var wanted_order := source_order
        match str(options.get("rank_mode", "same_current")):
            "random_adjacent":
                wanted_order = source_order + (1 if source_order <= 2 else -1 \
                    if source_order >= 14 else [-1, 1][
                        _battle_rng.randi_range(0, 1)])
            "random":
                wanted_order = int(rank.get("order", 0))
        for value in ranks:
            if int(value.get("order", 0)) == wanted_order:
                rank = value
                break
    var card = QiCard.new(
        "%s-temp-%d" % [attribute, _battle_rng.randi()],
        str(rank.get("id", "")), int(rank.get("order", 0)),
        int(rank.get("qi", 0)), attribute, attribute,
        "%s_%s" % [attribute, str(rank.get("id", "")).to_lower()])
    card.temporary_card = true
    if bool(options.get("add_void", true)):
        var applied: Dictionary = apply_card_anomaly(
            card, "mark", "void", {}, "临时真气", 1, false)
        if not applied.get("success", false):
            return null
    var added: Dictionary = side.card_zone_service.add_generated(side, card, "hand", true)
    return card if added.get("success", false) else null

func steal_random_normal_card(
        actor: BattleSide, target: BattleSide, source_value = "") -> Dictionary:
    if actor == null or target == null or _battle_rng == null:
        return {"success": false}
    var candidates: Array = target.draw_pile.filter(
        func(card): return card.is_card_kind("normal"))
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(
        target, "draw_pile", actor, "hand", card, "steal", "top",
        source_value)

func recover_forest_priority(
        actor: BattleSide,
        maximum_qi: int,
        prefer_permanent: bool,
        source_value = "") -> Dictionary:
    if actor == null or _battle_rng == null:
        return {"success": false}
    var plain: Array = []
    var reshaped: Array = []
    for card in actor.discard_pile:
        if not card.is_card_kind("normal") or current_effective_qi(actor, card) > maximum_qi:
            continue
        var permanent: bool = not card.reshape_origin.is_empty() \
            or card.reshape_enhancement != "" or card.reshape_imprint != "" \
            or not card.reshape_others.is_empty()
        (reshaped if permanent else plain).append(card)
    var candidates: Array = reshaped if prefer_permanent and not reshaped.is_empty() else plain
    if candidates.is_empty():
        return {"success": false}
    var card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    return move_card(
        actor, "discard_pile", actor, "hand", card, "recover", "top",
        source_value)

func burn_deck_then_heat_hand(
        actor: BattleSide, bottom_first: bool, choice_capture: String, context) -> Dictionary:
    var candidates: Array = actor.draw_pile.filter(func(card):
        return card.is_card_kind("normal") and not card.is_attribute("fire") \
            and can_apply_card_anomaly(card, "mark", "burned_out").get("allowed", false))
    if candidates.is_empty():
        return {"success": true, "detail": ""}
    var card = null
    if bottom_first:
        card = candidates[0]
    else:
        card = candidates[_battle_rng.randi_range(0, candidates.size() - 1)]
    var applied := apply_card_anomaly(card, "mark", "burned_out", {}, "引火式")
    if not applied.get("success", false):
        return {"success": true, "detail": ""}
    var heat_targets: Array = context.captures.get(choice_capture, [])
    if not heat_targets.is_empty():
        var layers := int(floor(card.current_base_qi_value() / 2.0))
        if layers > 0:
            apply_card_anomaly(heat_targets[0], "buff", "qi_heat", {}, "引火式", layers)
    return {"success": true, "detail": "燃尽并施加炽气"}

func can_grant_battle_consumable(side: BattleSide) -> bool:
    return side.consumable_ids.size() < side.consumable_limit

func grant_battle_consumable(side: BattleSide, consumable_id: String) -> bool:
    return side.grant_consumable(consumable_id)

func consumable_ids_by_kind(kind: String) -> Array[String]:
    return _consumable_repository.ids_by_kind(kind)

func place_on_draw_pile_top(side: BattleSide, card) -> Dictionary:
    return side.card_zone_service.place_on_draw_pile_top(side, card)

func temporarily_remove_card(
        side: BattleSide,
        instance_id: String,
        reason: String,
        source_value = "") -> Dictionary:
    return side.temporarily_remove_card(
        instance_id, reason, _effect_source_metadata(source_value))

func can_explicit_discard(side: BattleSide, card) -> Dictionary:
    var runtime = _card_reshape_runtime()
    if runtime == null:
        return {"allowed": true}
    return runtime.can_explicit_discard(side, card)

func notify_cards_played(
        side: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array[Dictionary]:
    var runtime = _card_reshape_runtime()
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
    if _status_system != null:
        _status_system.handle_response_event(event_kind, values)

func successful_on_play_ids(action_token: String) -> Array:
    var runtime = _card_reshape_runtime()
    return runtime.successful_on_play_ids(action_token) if runtime != null else []

func register_direct_card_trigger_listener(
        listener_id: String,
        listener) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .register_direct_listener(listener_id, listener)

func unregister_direct_card_trigger_listener(listener_id: String) -> bool:
    var runtime = _card_reshape_runtime()
    return runtime != null and runtime.trigger_replay_service \
        .unregister_direct_listener(listener_id)

func finalize_reshape_action(side: BattleSide, preview: Dictionary) -> Dictionary:
    var runtime = _card_reshape_runtime()
    if runtime == null:
        return {"success": true, "reused": false}
    return runtime.finalize_action_preview(side, preview)

func draw(side: BattleSide, count: int, source_value = "") -> Array:
    var source := _draw_source_metadata(source_value)
    var draw_reason := str(source.get("draw_reason", "effect_draw"))
    source.erase("draw_reason")
    var drawn: Array = side.draw(count, draw_reason, source)
    if str(source["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(side, "draw", drawn.size())
    return drawn

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
    side.card_zone_service.shuffle(side.card_zone_service.zone(side, zone), rng)

func current_effective_qi(side: BattleSide, card) -> int:
    var reshape_value: int = (
        card.effective_qi_value()
        if card.has_method("effective_qi_value") else int(card.qi_value))
    return maxi(0, _status_system.modify_card_contribution(
        card, reshape_value, side))

func discard_random(
        side: BattleSide,
        count: int,
        rng: RandomNumberGenerator,
        source_value = "") -> Array:
    var discarded: Array = side.random_discard(count, rng)
    if str(_effect_source_metadata(source_value)["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func discard_all(side: BattleSide, source_value = "") -> Array:
    var discarded: Array = side.discard_all()
    if str(_effect_source_metadata(source_value)["source_kind"]) == "technique":
        _status_system.record_technique_card_flow(side, "discard", discarded.size())
    return discarded

func move_card(
        source_side: BattleSide,
        source_zone: String,
        target_side: BattleSide,
        destination_zone: String,
        card,
        reason: String = "effect",
        placement: String = "top",
        source_kind = "") -> Dictionary:
    var effect_source := _effect_source_metadata(source_kind)
    var result: Dictionary
    if source_side == target_side:
        result = source_side.card_zone_service.move_card(
            source_side, source_zone, destination_zone, card, reason,
            effect_source)
    else:
        result = source_side.temporarily_transfer_card_to(
            target_side, str(card.id), destination_zone, reason,
            effect_source)
    if result.get("success", false) and placement == "bottom":
        var destination: Array = target_side.card_zone_service.zone(
            target_side, destination_zone)
        destination.erase(card)
        destination.push_front(card)
    if result.get("success", false) \
            and str(effect_source["source_kind"]) == "technique":
        if destination_zone == "hand" and reason == "draw":
            _status_system.record_technique_card_flow(target_side, "draw", 1)
        elif destination_zone == "discard_pile" and reason == "explicit_discard":
            _status_system.record_technique_card_flow(source_side, "discard", 1)
    return result

func move_cards_synchronously(records: Array, source_value = "") -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("side")
    if first_side == null:
        return []
    var effect_source := _effect_source_metadata(source_value)
    var sourced_records: Array = []
    for record_value in records:
        var sourced_record: Dictionary = record_value.duplicate(true)
        sourced_record["source_metadata"] = effect_source.duplicate(true)
        sourced_records.append(sourced_record)
    var moved: Array = first_side.card_zone_service.move_cards_synchronously(
        sourced_records)
    for record in records:
        if str(effect_source["source_kind"]) == "technique" \
                and moved.has(record.get("card")) \
                and str(record.get("reason", "")) == "explicit_discard":
            _status_system.record_technique_card_flow(record.get("side"), "discard", 1)
    return moved

func transfer_cards_atomically(records: Array, source_value = "") -> Array:
    if records.is_empty():
        return []
    var first_side = records[0].get("source_side")
    if first_side == null:
        return []
    var effect_source := _effect_source_metadata(source_value)
    var sourced_records: Array = []
    for record_value in records:
        var sourced_record: Dictionary = record_value.duplicate(true)
        sourced_record["source_metadata"] = effect_source.duplicate(true)
        sourced_records.append(sourced_record)
    return first_side.card_zone_service.temporarily_transfer_many(sourced_records)

func atomic_exchange_cards(
        actor_side: BattleSide, actor_zone: String, actor_card,
        target_side: BattleSide, target_zone: String, target_card,
        source_value = "") -> Dictionary:
    return actor_side.card_zone_service.atomic_exchange(
        actor_side, actor_zone, actor_card, target_side, target_zone, target_card,
        _effect_source_metadata(source_value))

func zone_cards(side: BattleSide, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func query_effect_targets(context, query_spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
    var QueryScript = load("res://core/effects/effect_target_query.gd")
    var values := query_spec.duplicate(true)
    values["card_identity_policy"] = context.card_identity_policy
    return QueryScript.new().configure(values).resolve(context, rng)

func apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        payload: Dictionary,
        source: String,
        layers: int = 1,
        replace_state: bool = false,
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.apply_card_anomaly(
        card, category, anomaly_id, payload, source, layers, replace_state,
        event_metadata)

func can_apply_card_anomaly(
        card,
        category: String,
        anomaly_id: String,
        replace_state: bool = false) -> Dictionary:
    return _status_system.can_apply_card_anomaly(
        card, category, anomaly_id, replace_state)

func remove_card_anomaly(
        card,
        category: String,
        anomaly_id: String = "",
        source: String = "效果",
        event_metadata: Dictionary = {}) -> Dictionary:
    return _status_system.remove_card_anomaly(
        card, category, anomaly_id, source, event_metadata)

func set_card_anomaly_layers(
        card,
        category: String,
        anomaly_id: String,
        layers: int,
        source: String = "效果") -> Dictionary:
    return _status_system.set_card_anomaly_layers(
        card, category, anomaly_id, layers, source)

func apply_temporary_enhancement(card, enhancement_id: String) -> Dictionary:
    if card == null or enhancement_id == "":
        return {"success": false, "reason": "临时强化参数无效"}
    return {
        "success": card.set_temporary_enhancement(enhancement_id),
        "enhancement": enhancement_id,
    }

func apply_temporary_attribute(card, attribute_id: String) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时属性目标为空"}
    return {
        "success": card.set_temporary_attribute(attribute_id),
        "attribute": attribute_id,
    }

func apply_temporary_rank(
        card,
        rank_name: String,
        rank_order: int,
        base_qi: int) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时牌阶参数无效"}
    return {
        "success": card.set_temporary_rank(rank_name, rank_order, base_qi),
        "rank_name": rank_name,
        "rank_order": rank_order,
        "base_qi": base_qi,
    }

func clear_temporary_reshape(card, subslot: String) -> Dictionary:
    if card == null or subslot not in ["enhancement", "attribute", "rank"]:
        return {"success": false, "reason": "临时重塑子槽无效"}
    return {"success": true, "removed": card.clear_temporary_reshape(subslot)}

func clear_all_temporary_reshapes(card) -> Dictionary:
    if card == null:
        return {"success": false, "reason": "临时重塑目标为空"}
    return {"success": true, "removed": card.clear_all_temporary_reshapes()}

func _card_reshape_runtime():
    return (
        _card_reshape_runtime_ref.get_ref()
        if _card_reshape_runtime_ref != null else null)

func resolve_played_card_anomalies(
        holder: BattleSide,
        cards: Array,
        source_values: Dictionary = {}) -> Array:
    var results: Array = _status_system.resolve_played_card_anomalies(
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
    return _status_system.register_delayed_effects(
        label, timing, occurrences, effects, context)

func register_response(
        event_kind: String,
        expiry: String,
        effects: Array,
        context,
        filters: Dictionary = {},
        expiry_effects: Array = []) -> Dictionary:
    return _status_system.register_response(
        event_kind, expiry, effects, context, filters, expiry_effects)

func register_next_round_hand_limit(
        context, amount: int, affected_side = null) -> Dictionary:
    return _status_system.register_next_round_hand_limit(
        context, amount, affected_side)

func register_defense_decay_return(context) -> Dictionary:
    return _status_system.register_defense_decay_return(context)

func register_reflection_expiry(context, percent: int) -> Dictionary:
    return _status_system.register_reflection_expiry(context, percent)

func register_no_life_loss_disruption(context, effect: Dictionary) -> Dictionary:
    return _status_system.register_no_life_loss_disruption(context, effect)

func technique_draw_count(side: BattleSide) -> int:
    return _status_system.technique_draw_count(side)

func retrigger_current_hand_technique(
        actor: BattleSide,
        target: BattleSide,
        sequence_book,
        power_snapshot: Dictionary,
        maximum_discard: int,
        excluded_technique_ids: Array) -> Dictionary:
    if not _hand_retrigger_callback.is_valid():
        return {"success": false, "detail": "当前未连接功法重触端口"}
    return _hand_retrigger_callback.call(
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

func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0

func _emit_source_state_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> void:
    if _committed_event_service == null:
        return
    var serial: int = int(_committed_event_service.next_serial())
    _committed_event_service.commit(event_kind, {
        "event_token": _committed_event_service.make_token(
            event_kind, side, serial, str(record.get("source_token", ""))),
        "event_serial": serial,
        "actor": side, "owner": side,
        "target": record.get("target"),
        "round_number": _round_number(),
        "action_token": str(record.get("action_token", "")),
        "source_kind": str(record.get("source_kind", event_kind)),
        "source_token": str(record.get("source_token", "")),
        "change": change,
        "payload": payload.duplicate(true),
        "public_state": record.duplicate(true),
    })

func _current_action_window_id() -> String:
    return _survival_effect_service.current_action_window_id()

func _can_bind_current_source(target_owner_id: String) -> bool:
    return _survival_effect_service.can_bind_current_source(target_owner_id)
