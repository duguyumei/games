class_name CardReshapeBlockExplicitDiscardHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "block_explicit_discard"

func triggers() -> Array[String]:
    return ["explicit_discard_attempt"]

func execute(behavior: Dictionary, _context) -> Dictionary:
    return {
        "success": true,
        "blocked": true,
        "reason": str(behavior.get("reason", "此真气不能被明确弃掉")),
    }
