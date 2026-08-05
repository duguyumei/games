class_name FlowEffectHandler
extends RefCounted

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["gain_extra_action", "register_attack_counter_delay"]

func group_name() -> String:
    return "flow_delay"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    match str(effect.get("op", "")):
        "gain_extra_action":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
            context["engine"].gain_extra_actions_for(context["actor"], amount, "功法")
            return {"success": true, "detail": "连击机会 +%d" % amount}
        "register_attack_counter_delay":
            var damage: int = value_resolver.resolve(effect.get("damage", {}), context)
            context["engine"].register_attack_counter_delay(
                context.get("technique_name", "延迟功法"),
                int(effect.get("turn_ends", 1)),
                int(context["power"]),
                damage,
                context["actor"],
                context["target"])
            return {
                "success": true,
                "detail": "记录 P=%d，延迟伤害/段=%d" % [context["power"], damage],
            }
    return {"success": false, "detail": "流程处理器不支持：%s" % str(effect.get("op", ""))}

func summarize(effect: Dictionary, context: Dictionary, intent: Dictionary, _state: Dictionary) -> void:
    if effect.get("op", "") == "gain_extra_action":
        intent["technique_combo"] = (
            bool(intent.get("technique_combo", false))
            or value_resolver.resolve(effect.get("amount", {}), context) > 0)
