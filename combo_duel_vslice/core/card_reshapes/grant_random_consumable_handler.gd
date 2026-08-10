class_name CardReshapeGrantRandomConsumableHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

func behavior_id() -> String:
    return "grant_random_consumable"

func triggers() -> Array[String]:
    return ["card_explicitly_discarded"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    var kind := str(behavior.get("kind", ""))
    if kind == "":
        validator.report_error(scope + ".kind", "必须是非空字符串")
    elif validator.content_ids_by_kind("consumable", kind).is_empty():
        validator.report_error(scope + ".kind", "统一内容中没有 kind=%s 的消耗品" % kind)

func execute(behavior: Dictionary, context) -> Dictionary:
    if not context.effect_ports.can_grant_battle_consumable(context.holder):
        return {"success": true, "applied": false, "reason": "消耗品栏已满"}
    var candidates: Array[String] = context.effect_ports.consumable_ids_by_kind(
        str(behavior["kind"]))
    if candidates.is_empty():
        return {"success": true, "applied": false, "reason": "候选池为空"}
    var consumable_id := candidates[context.rng.randi_range(0, candidates.size() - 1)]
    var granted: bool = context.effect_ports.grant_battle_consumable(
        context.holder, consumable_id)
    return {
        "success": true,
        "applied": granted,
        "consumable_id": consumable_id if granted else "",
    }
