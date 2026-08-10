class_name CardReshapeGrantMappedConsumableHandler
extends "res://core/card_reshapes/card_reshape_behavior_handler.gd"

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

func behavior_id() -> String:
    return "grant_mapped_consumable"

func triggers() -> Array[String]:
    return ["battle_victory"]

func validate_behavior(behavior: Dictionary, validator, scope: String) -> void:
    if str(behavior.get("required_zone", "")) != "hand":
        validator.report_error(scope + ".required_zone", "悟道印必须限定胜者手牌")
    var mapping = behavior.get("mapping")
    if not mapping is Dictionary:
        validator.report_error(scope + ".mapping", "必须是八种牌型到心得的映射")
        return
    for hand_id in HAND_IDS:
        if not mapping.has(hand_id):
            validator.report_error(scope + ".mapping", "缺少牌型 %s" % hand_id)
            continue
        var consumable_id := str(mapping[hand_id])
        var definition: Dictionary = validator.content_definition(
            "consumable", consumable_id)
        if definition.is_empty():
            validator.report_error(
                scope + ".mapping." + hand_id,
                "引用未知消耗品 %s" % consumable_id)
        elif str(definition.get("kind", "")) != "insight":
            validator.report_error(
                scope + ".mapping." + hand_id,
                "消耗品 %s 不是心得" % consumable_id)
    for hand_id in mapping:
        if str(hand_id) not in HAND_IDS:
            validator.report_error(
                scope + ".mapping." + str(hand_id),
                "未知牌型 %s" % str(hand_id))

func execute(behavior: Dictionary, context) -> Dictionary:
    if context.zone_name != str(behavior["required_zone"]):
        return {"success": true, "applied": false, "reason": "真气不在指定牌区"}
    var hand_id := str(context.payload.get("last_successful_hand_id", ""))
    if hand_id == "":
        return {"success": true, "applied": false, "reason": "没有成功出招记录"}
    var consumable_id := str(behavior["mapping"].get(hand_id, ""))
    if consumable_id == "" or not context.effect_ports.can_grant_battle_consumable(
            context.holder):
        return {"success": true, "applied": false, "reason": "消耗品栏已满或映射为空"}
    var granted: bool = context.effect_ports.grant_battle_consumable(
        context.holder, consumable_id)
    return {
        "success": true,
        "applied": granted,
        "consumable_id": consumable_id if granted else "",
    }
