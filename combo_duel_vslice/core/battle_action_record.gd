class_name BattleActionRecord
extends RefCounted

const SCHEMA_VERSION := 5

var actor
var target
var preview: Dictionary = {}
var book
var order: int = 0
var turn_number: int = 0
var triggered: bool = false
var failed: bool = false
var token: String = ""
var captures_by_source: Dictionary = {}
var cooperation_groups: Array = []
var momentum_prepared: bool = false
var technique_activation_checked: bool = false
var technique_activation_allowed: bool = false
var technique_activation_reason: String = ""
var technique_activation_breakdown: Array = []

func configure(
        action_actor,
        action_target,
        action_preview: Dictionary,
        sequence_book,
        action_order: int,
        action_turn_number: int):
    actor = action_actor
    target = action_target
    preview = action_preview
    book = sequence_book
    order = action_order
    turn_number = action_turn_number
    token = str(action_preview.get("reshape_action_token", ""))
    if token == "":
        token = "%s-%d-%d" % [actor.name, turn_number, order]
    captures_by_source.clear()
    cooperation_groups.clear()
    triggered = false
    failed = false
    momentum_prepared = false
    var activation: Dictionary = action_preview.get(
        "technique_activation", {})
    technique_activation_checked = bool(activation.get("checked", false))
    technique_activation_allowed = bool(activation.get("allowed", false))
    technique_activation_reason = str(activation.get("reason", ""))
    technique_activation_breakdown = activation.get(
        "source_breakdown", []).duplicate(true)
    return self

func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "actor_id": str(actor.owner_id),
        "target_id": str(target.owner_id),
        "order": order,
        "turn_number": turn_number,
        "token": token,
        "triggered": triggered,
        "failed": failed,
        "momentum_prepared": momentum_prepared,
        "technique_activation_checked": technique_activation_checked,
        "technique_activation_allowed": technique_activation_allowed,
        "technique_activation_reason": technique_activation_reason,
        "technique_activation_breakdown": technique_activation_breakdown.duplicate(true),
        "hand_id": str(preview.get("hand", {}).get("id", "")),
        "technique_id": str(preview.get("technique_id", "")),
        "reshape_action_confirmed": bool(preview.get("reshape_action_confirmed", false)),
        "reshape_action_results": preview.get(
            "reshape_action_results", {}).duplicate(true),
        "passive_action_confirmed": bool(preview.get(
            "passive_action_confirmed", false)),
        "passive_power_queries": preview.get("values", {}).get(
            "passive_power_queries", {}).duplicate(true),
        "same_qi": preview.get("same_qi", {}).duplicate(true),
        "same_qi_group": preview.get("same_qi_group", {}).duplicate(true),
        "same_qi_gain": int(preview.get("same_qi_gain", 0)),
        "same_qi_before": int(preview.get("same_qi_before", 0)),
        "same_qi_capacity": int(preview.get("same_qi_capacity", 5)),
        "same_qi_after": int(preview.get("same_qi_after", 0)),
        "same_qi_trigger_count": int(preview.get(
            "same_qi_trigger_count", 0)),
        "cooperation_group_count": cooperation_groups.size(),
        "cooperation_groups": cooperation_groups.map(func(group): return {
            "group_index": int(group.get("group_index", 0)),
            "same_qi_group": group.get("preview", {}).get(
                "same_qi_group", {}).duplicate(true),
        }),
    }

func to_dict() -> Dictionary:
    return {
        "actor": actor,
        "target": target,
        "preview": preview,
        "book": book,
        "order": order,
        "triggered": triggered,
        "failed": failed,
        "turn_number": turn_number,
        "token": token,
        "captures_by_source": captures_by_source,
        "cooperation_groups": cooperation_groups,
        "momentum_prepared": momentum_prepared,
        "technique_activation_checked": technique_activation_checked,
        "technique_activation_allowed": technique_activation_allowed,
        "technique_activation_reason": technique_activation_reason,
        "technique_activation_breakdown": technique_activation_breakdown,
    }
