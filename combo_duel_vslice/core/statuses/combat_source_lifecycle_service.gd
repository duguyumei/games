class_name CombatSourceLifecycleService
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")

var _record_id_allocator
var _effect_ports_ref: WeakRef
var _effect_executor = null


func _init(record_id_allocator) -> void:
    assert(record_id_allocator != null,
        "CombatSourceLifecycleService requires StatusRecordIdAllocator")
    _record_id_allocator = record_id_allocator


func register_reflection_expiry(runtime, percent: int) -> Dictionary:
    var context = EffectContextScript.coerce(runtime)
    var token: String = _record_id_allocator.next_id("reflection")
    return _effect_ports().grant_reflection_source(
        context.actor, percent, 1, "round_end",
        context.source_name if context.source_name != "" else "反震",
        token, context.target)


func resolve_action_window(sides: Array, window_id: String) -> Dictionary:
    var resolved_challenges := 0
    var expired_reflection := 0
    var expired_blocks := 0
    var expired_deflections := 0
    for side in sides:
        resolved_challenges += _resolve_challenges_for_side(side, window_id)
    for side in sides:
        var expired: Dictionary = _expire_action_window_sources(
            side, window_id)
        expired_reflection += int(expired.get(
            "reflection_expired_count", 0))
        expired_blocks += int(expired.get("block_expired_count", 0))
        expired_deflections += int(expired.get(
            "deflection_expired_count", 0))
    return {
        "success": true,
        "resolved_challenge_count": resolved_challenges,
        "reflection_expired_count": expired_reflection,
        "block_expired_count": expired_blocks,
        "deflection_expired_count": expired_deflections,
    }


func expire_round_sources(side) -> Dictionary:
    var expired: Dictionary = side.tick_round_limited_sources()
    for record in expired.get("reflection_records", []):
        _effect_ports().notify_source_changed(
            "reflection_source_changed", side, record, "expired")
    for record in expired.get("true_damage_records", []):
        _effect_ports().notify_source_changed(
            "reflection_source_changed", side, record,
            "true_damage_expired")
    var reflection_count: int = expired.get("reflection", []).size()
    var true_damage_count: int = expired.get("true_damage", []).size()
    return {
        "success": true,
        "reflection_expired_count": reflection_count,
        "true_damage_expired_count": true_damage_count,
        "detail": "反震来源到期%d／真伤修改到期%d" % [
            reflection_count, true_damage_count],
    }


func clear_battle_sources(side) -> Dictionary:
    if side == null:
        return {"success": false, "detail": "战斗结束来源清理缺少参与方"}
    var momentum_receipt: Dictionary = side.write_momentum(
        "clear", 0, "battle_cleanup", "battle-end", "battle_end")
    if not momentum_receipt.get("success", false):
        return {
            "success": false,
            "detail": "战斗结束连势清理失败",
            "momentum_receipt": momentum_receipt,
        }
    side.direct_power_fixed = 0
    side.direct_power_percent = 0
    side.last_successful_technique_hand_id = ""
    side.clear_combat_sources()
    side.source_marker_store.clear_scope("battle")
    return {"success": true, "momentum_receipt": momentum_receipt}


func use_effect_ports(effect_ports) -> void:
    _effect_ports_ref = weakref(effect_ports) if effect_ports != null else null


func use_effect_executor(executor) -> void:
    _effect_executor = executor


func _resolve_challenges_for_side(side, window_id: String) -> int:
    if _effect_executor == null or side == null:
        return 0
    var due: Array = side.challenge_records.filter(func(record):
        return not bool(record.get("waiting_for_action", false)) \
            and str(record.get("window_id", "")) == window_id)
    for record in due:
        var threshold := int(record.get("threshold", 0))
        var current := int(record.get("current", 0))
        var difference := maxi(0, threshold - current)
        var met := current >= threshold
        var challenge_result := {
            "source_token": str(record.get("source_token", "")),
            "threshold": threshold,
            "current": current,
            "difference": difference,
            "met": met,
            "branch": "met" if met else "unmet",
        }
        record["resolution"] = challenge_result.duplicate(true)
        var branch_effects: Array = record.get(
            "met_effects", []) if met else record.get("effects", [])
        if not branch_effects.is_empty():
            var captures: Dictionary = record.get(
                "captures", {}).duplicate(true)
            captures["challenge_result"] = [challenge_result.duplicate(true)]
            captures["challenge_difference"] = [{"amount": difference}]
            var context = EffectContextScript.new().configure({
                "ports": _effect_ports(),
                "actor": record["challenger"],
                "target": record["target"],
                "power": int(record.get("power", 0)),
                "initial_power": int(record.get("initial_power", 0)),
                "hand_result": record.get("hand_result", {}),
                "played_cards": record.get("played_cards", []),
                "group_snapshot": record.get("group_snapshot", {}),
                "captures": captures,
                "technique_id": str(record.get("technique_id", "")),
                "technique_name": str(record.get("technique_name", "")),
                "actual_hand_id": str(record.get("actual_hand_id", "")),
                "branch_hand_id": str(record.get("branch_hand_id", "")),
                "technique_pool": str(record.get("technique_pool", "")),
                "action_token": str(record.get("action_token", "")),
                "source_kind": record.get("source_kind", "rule"),
                "source_id": record.get("source_id", ""),
                "source_name": record.get("source_name", ""),
                "source_instance_key": record.get(
                    "source_instance_key", ""),
                "trigger_mode": "delayed",
            })
            _effect_executor.execute_all(branch_effects, context)
        _effect_ports().add_history(
            "challenge_resolved", str(record.get("label", "邀战")),
            side.name, "达标" if met else "未达标", "%d/%d，差额%d" % [
                current, threshold, difference])
        _effect_ports().notify_source_changed(
            "challenge_resolved", side, record, "resolved",
            challenge_result)
        side.challenge_records.erase(record)
    return due.size()


func _expire_action_window_sources(side, window_id: String) -> Dictionary:
    if side == null:
        return {
            "reflection_expired_count": 0,
            "block_expired_count": 0,
            "deflection_expired_count": 0,
        }
    var expired: Dictionary = side.expire_action_window_sources(window_id)
    for record in expired.get("reflection_records", []):
        _effect_ports().notify_source_changed(
            "reflection_source_changed", side, record, "expired")
    for record in expired.get("block_records", []):
        _effect_ports().notify_source_changed(
            "block_source_changed", side, record, "expired")
    for record in expired.get("deflection_records", []):
        _effect_ports().notify_source_changed(
            "block_source_changed", side, record, "expired")
    var reflection_count: int = expired.get("reflection", []).size()
    var block_count: int = expired.get("blocks", []).size()
    var deflection_count: int = expired.get("deflections", []).size()
    if reflection_count > 0 or block_count > 0 or deflection_count > 0:
        _effect_ports().add_history(
            "source_expiry", "%s行动窗来源到期" % side.name,
            "战斗来源", "成功", "反震%d／格挡%d／卸力%d" % [
                reflection_count, block_count, deflection_count])
    return {
        "reflection_expired_count": reflection_count,
        "block_expired_count": block_count,
        "deflection_expired_count": deflection_count,
    }


func _effect_ports():
    return _effect_ports_ref.get_ref() if _effect_ports_ref != null else null
