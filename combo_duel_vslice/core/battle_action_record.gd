class_name BattleActionRecord
extends RefCounted

const SCHEMA_VERSION := 1

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
        "hand_id": str(preview.get("hand", {}).get("id", "")),
        "technique_id": str(preview.get("technique_id", "")),
        "reshape_action_confirmed": bool(preview.get("reshape_action_confirmed", false)),
        "reshape_action_results": preview.get(
            "reshape_action_results", {}).duplicate(true),
        "cooperation_group_count": cooperation_groups.size(),
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
    }
