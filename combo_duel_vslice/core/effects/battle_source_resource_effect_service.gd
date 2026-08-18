class_name BattleSourceResourceEffectService
extends RefCounted

## BattleEffectPorts 内部的来源标识与来源化战斗资源写入服务。
##
## 本服务集中维护来源 marker、连势、同气槽、直接功法值修正，以及反震／格挡／
## 邀战来源的建立和公开变化事件。伤害如何读取、消费这些来源仍由
## BattleSurvivalEffectService 负责；行动窗口只通过三个窄 Callable 接入。

var _status_system
var _trigger_queue
var _same_qi_gauge_service
var _committed_event_service
var _round_number_reader: Callable
var _current_action_window_id_reader: Callable
var _can_bind_current_source_reader: Callable
var _close_source_binding_window: Callable
var _battle_instance_id: String = "battle-0"


func _init(
        status_system,
        trigger_queue,
        current_action_window_id_reader: Callable,
        can_bind_current_source_reader: Callable,
        close_source_binding_window: Callable) -> void:
    assert(status_system != null,
        "BattleSourceResourceEffectService requires StatusSystem")
    assert(trigger_queue != null,
        "BattleSourceResourceEffectService requires VisibleTriggerQueue")
    assert(current_action_window_id_reader.is_valid(),
        "BattleSourceResourceEffectService requires action-window reader")
    assert(can_bind_current_source_reader.is_valid(),
        "BattleSourceResourceEffectService requires source-binding reader")
    assert(close_source_binding_window.is_valid(),
        "BattleSourceResourceEffectService requires source-binding closer")
    _status_system = status_system
    _trigger_queue = trigger_queue
    _current_action_window_id_reader = current_action_window_id_reader
    _can_bind_current_source_reader = can_bind_current_source_reader
    _close_source_binding_window = close_source_binding_window


func use_trigger_queue(trigger_queue) -> void:
    assert(trigger_queue != null,
        "BattleSourceResourceEffectService requires VisibleTriggerQueue")
    _trigger_queue = trigger_queue


func use_passive_battle_services(
        event_service,
        round_reader: Callable = Callable()) -> void:
    _committed_event_service = event_service
    _round_number_reader = round_reader


func use_same_qi_gauge_service(service) -> void:
    assert(service != null,
        "BattleSourceResourceEffectService requires SameQiGaugeService")
    _same_qi_gauge_service = service


func use_battle_instance_id(value: String) -> void:
    _battle_instance_id = value if value != "" else "battle-0"


func battle_instance_id() -> String:
    return _battle_instance_id


func same_qi_projection(
        side: BattleSide,
        amount: int,
        context: Dictionary = {}) -> Dictionary:
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
        _add_history(
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
        _commit_same_qi_gain(side, response, str(response["action_token"]))
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
        _add_history(
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
        _commit_same_qi_gain(side, response, resolved_action_token)
    return result


func same_qi_receipts_for_action(
        side: BattleSide,
        action_token: String) -> Array:
    if _same_qi_gauge_service == null:
        return []
    return _same_qi_gauge_service.receipts_for_action(side, action_token)


func close_current_source_binding_window() -> void:
    _close_source_binding_window.call()


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


func set_reflection_percent(
        side: BattleSide,
        value: int,
        source_token: String = "") -> int:
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
        var target_owner_id := str(target_side.owner_id) \
            if target_side != null else ""
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
    var emitted := _emit_source_state_changed(
        "block_source_changed", side, record, "established")
    if not emitted.get("success", false):
        side.block_sources.erase(record)
        return {"success": false, "reason": emitted.get(
            "reason", "格挡来源建立事件失败")}
    return {"success": true, "record": record, "source_token": record["source_token"]}


func grant_deflection_source(
        side: BattleSide,
        target_side: BattleSide,
        threshold: int,
        label: String,
        source_token: String = "",
        metadata: Dictionary = {}) -> Dictionary:
    if side == null:
        return {"success": false, "reason": "卸力来源缺少持有者"}
    if threshold < 0:
        return {"success": false, "reason": "卸力阈值不得小于0"}
    var target_owner_id := str(target_side.owner_id) \
        if target_side != null else ""
    var window_id := _current_action_window_id() \
        if _can_bind_current_source(target_owner_id) else ""
    var record := side.add_deflection_source(
        threshold, source_token, target_owner_id, window_id,
        label, true, metadata)
    var emitted := _emit_source_state_changed(
        "block_source_changed", side, record, "established")
    if not emitted.get("success", false):
        side.block_sources.erase(record)
        return {"success": false, "reason": emitted.get(
            "reason", "卸力来源建立事件失败")}
    return {
        "success": true,
        "record": record,
        "source_token": str(record.get("source_token", "")),
    }


func register_challenge(
        context,
        threshold: int,
        effects: Array,
        label: String = "邀战",
        met_effects: Array = []) -> Dictionary:
    var runtime = context
    var token: String = str(runtime.actor.next_combat_source_token("challenge"))
    var target_owner_id := str(runtime.target.owner_id) \
        if runtime.target != null else ""
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


func _commit_same_qi_gain(
        side: BattleSide,
        response: Dictionary,
        action_token: String) -> void:
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        response["event_serial"] = serial
        response["event_token"] = _committed_event_service.make_token(
            "same_qi_gain_resolved", side, serial, action_token)
        _committed_event_service.commit("same_qi_gain_resolved", response)
    else:
        _status_system.handle_response_event("same_qi_gain_resolved", response)


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
    else:
        _status_system.handle_response_event("source_marker_changed", values)


func _emit_source_state_changed(
        event_kind: String,
        side: BattleSide,
        record: Dictionary,
        change: String,
        payload: Dictionary = {}) -> Dictionary:
    if _committed_event_service == null:
        return {"success": true, "receipt": {}}
    var serial: int = int(_committed_event_service.next_serial())
    return _committed_event_service.commit(event_kind, {
        "event_token": _committed_event_service.make_token(
            event_kind, side, serial, str(record.get("source_token", ""))),
        "event_serial": serial,
        "actor": side, "owner": side,
        "target": record.get("target"),
        "round_number": _round_number(),
        "action_token": str(record.get("action_token", "")),
        "source_kind": str(record.get("source_kind", event_kind)),
        "source_id": str(record.get("source_id", "")),
        "source_name": str(record.get("source_name", record.get(
            "label", ""))),
        "source_instance_key": str(record.get("source_instance_key", "")),
        "trigger_mode": str(record.get("trigger_mode", "direct")),
        "source_token": str(record.get("source_token", "")),
        "cancel_kind": str(record.get("cancel_kind", "block")),
        "threshold": int(record.get("threshold", 0)),
        "established_order": int(record.get("established_order", 0)),
        "window_id": str(record.get("window_id", "")),
        "waiting_for_action": bool(record.get("waiting_for_action", false)),
        "change": change,
        "payload": payload.duplicate(true),
        "public_state": record.duplicate(true),
    })


func _current_action_window_id() -> String:
    return str(_current_action_window_id_reader.call())


func _can_bind_current_source(target_owner_id: String) -> bool:
    return bool(_can_bind_current_source_reader.call(target_owner_id))


func _round_number() -> int:
    return int(_round_number_reader.call()) if _round_number_reader.is_valid() else 0


func _add_history(
        timing: String,
        label: String,
        source: String,
        result: String,
        detail: String = "") -> void:
    _trigger_queue.add_history(timing, label, source, result, detail)
