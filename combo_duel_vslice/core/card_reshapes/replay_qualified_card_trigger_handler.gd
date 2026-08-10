class_name ReplayQualifiedCardTriggerHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "replay_qualified_card_trigger"

func triggers() -> Array[String]:
    return ["qualified_trigger_replay"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    var additional = behavior.get("additional_replays")
    if not _is_integer(additional) or int(additional) != 1:
        validator.report_error(
            scope + ".additional_replays",
            "回响当前必须固定额外重演 1 次")

func execute(behavior: Dictionary, _context) -> Dictionary:
    return {
        "success": true,
        "additional_replays": int(behavior.get("additional_replays", 0)),
    }

func _is_integer(value) -> bool:
    return value is int or value is float and float(value) == floor(float(value))
