class_name BattleActionProposal
extends RefCounted

const SCHEMA_VERSION := 1

var accepted: bool = false
var controller_id: String = ""
var card_ids: Array[String] = []
var groups: Array = []
var preview: Dictionary = {}
var score: float = 0.0
var diagnostics: Dictionary = {}
var rejection_reason: String = ""

func configure_accept(
        source_controller_id: String,
        selected_card_ids: Array,
        action_preview: Dictionary,
        action_score: float = 0.0,
        action_diagnostics: Dictionary = {},
        action_groups: Array = []):
    accepted = true
    controller_id = source_controller_id
    card_ids.clear()
    for card_id in selected_card_ids:
        card_ids.append(str(card_id))
    groups = action_groups.duplicate(true)
    if groups.is_empty() and not card_ids.is_empty():
        groups.append({
            "group_index": 0,
            "kind": "main",
            "card_ids": card_ids.duplicate(),
        })
    preview = action_preview.duplicate(true)
    score = action_score
    diagnostics = action_diagnostics.duplicate(true)
    return self

func configure_reject(
        source_controller_id: String,
        reason: String,
        action_diagnostics: Dictionary = {}):
    controller_id = source_controller_id
    rejection_reason = reason
    diagnostics = action_diagnostics.duplicate(true)
    return self

func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "accepted": accepted,
        "controller_id": controller_id,
        "card_ids": card_ids.duplicate(),
        "groups": groups.duplicate(true),
        "score": score,
        "diagnostics": diagnostics.duplicate(true),
        "rejection_reason": rejection_reason,
    }

func to_dict() -> Dictionary:
    return snapshot()
