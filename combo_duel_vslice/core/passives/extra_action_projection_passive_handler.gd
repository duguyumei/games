class_name ExtraActionProjectionPassiveHandler
extends "res://core/passives/passive_rule_handler.gd"

## Read-only declaration used only to decide whether a queued extra action can
## become an action window.  Actual draws/effects remain ordinary
## `battle_effects` on `extra_action_started`.

const HOOK := "extra_action_preflight_projection"

func behavior_id() -> String:
    return "extra_action_preflight_projection"

func supported_hooks() -> Array[String]:
    return [HOOK]

func validate_configuration(configuration: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in configuration:
        if str(field) != "projected_draw_count":
            errors.append("configuration 不支持字段 %s" % str(field))
    if not configuration.get("projected_draw_count") is int \
            or int(configuration.get("projected_draw_count", 0)) < 0:
        errors.append("projected_draw_count 必须是非负整数")
    return errors

func handle(hook: String, _context, configuration: Dictionary) -> Dictionary:
    if hook != HOOK:
        return {"success": true, "skipped": true, "projected_draw_count": 0}
    return {
        "success": true,
        "projected_draw_count": int(configuration.get(
            "projected_draw_count", 0)),
    }
