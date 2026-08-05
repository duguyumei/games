class_name BattleActionProposal
extends RefCounted

var accepted: bool = false
var controller_id: String = ""
var card_ids: Array[String] = []
var preview: Dictionary = {}
var score: float = 0.0
var diagnostics: Dictionary = {}
var rejection_reason: String = ""

func configure_accept(
        source_controller_id: String,
        selected_card_ids: Array,
        action_preview: Dictionary,
        action_score: float = 0.0,
        action_diagnostics: Dictionary = {}):
    accepted = true
    controller_id = source_controller_id
    for card_id in selected_card_ids:
        card_ids.append(str(card_id))
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
        "accepted": accepted,
        "controller_id": controller_id,
        "card_ids": card_ids.duplicate(),
        "score": score,
        "diagnostics": diagnostics.duplicate(true),
        "rejection_reason": rejection_reason,
    }
