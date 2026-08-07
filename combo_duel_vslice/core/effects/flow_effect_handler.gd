class_name FlowEffectHandler
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "gain_extra_action", "register_attack_counter_delay", "register_turn_end_stack",
        "register_played_return",
        "register_delayed_effects",
        "retrigger_current_hand_technique",
    ]

func group_name() -> String:
    return "flow_delay"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("流程处理器缺少战斗端口")
    match str(effect.get("op", "")):
        "gain_extra_action":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            runtime.ports.gain_extra_actions(runtime.actor, amount, "功法")
            return EffectResultScript.succeeded("连击机会 +%d" % amount)
        "register_attack_counter_delay":
            var damage: int = value_resolver.resolve(effect.get("damage", {}), runtime)
            var result: Dictionary = runtime.ports.register_attack_counter_delay(
                runtime.technique_name if runtime.technique_name != "" else "延迟功法",
                int(effect.get("turn_ends", 1)),
                runtime.power,
                damage,
                runtime.actor,
                runtime.target)
            if not result.get("success", true):
                return EffectResultScript.failed(str(result.get("reason", "延迟记录失败")))
            return EffectResultScript.succeeded(
                "记录 P=%d，延迟伤害/段=%d" % [runtime.power, damage])
        "register_turn_end_stack":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var result: Dictionary = runtime.ports.register_turn_end_stack(
                runtime.technique_name if runtime.technique_name != "" else "延迟层数",
                int(effect.get("turn_ends", 1)),
                str(effect.get("stack", "")),
                amount,
                runtime.actor)
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("reason", "延迟层数建立失败")))
            return EffectResultScript.succeeded("回合结束时%s +%d" % [effect.get("stack", ""), amount])
        "register_played_return":
            var count: int = value_resolver.resolve(effect.get("count", {}), runtime)
            var result: Dictionary = runtime.ports.register_played_return(
                runtime.actor,
                runtime.played_cards,
                runtime.hand_result.get("contributing", []),
                count,
                str(effect.get("destination", "hand")),
                str(effect.get("anomaly", "")),
                bool(effect.get("enter_discard_first", true)),
                bool(effect.get("shuffle", false)))
            return EffectResultScript.succeeded("登记打出牌回收 %d 张" % int(result.get("registered", 0)))
        "register_delayed_effects":
            var result: Dictionary = runtime.ports.register_delayed_effects(
                runtime.technique_name if runtime.technique_name != "" else "延迟功法",
                str(effect.get("timing", "turn_end")),
                int(effect.get("occurrences", 1)),
                effect.get("effects", []),
                runtime)
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("reason", "延迟效果建立失败")))
            return EffectResultScript.succeeded("建立%s延迟效果" % str(effect.get("timing", "turn_end")))
        "retrigger_current_hand_technique":
            var result: Dictionary = runtime.ports.retrigger_current_hand_technique(
                runtime.actor,
                runtime.target,
                runtime.sequence_book,
                runtime.power,
                int(effect.get("maximum_discard", 6)),
                effect.get("excluded_technique_ids", []))
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("detail", "功法重触失败")))
            return EffectResultScript.succeeded(str(result.get("detail", "功法重触完成")))
    return EffectResultScript.failed("流程处理器不支持：%s" % str(effect.get("op", "")))

func summarize(effect: Dictionary, context, intent: Dictionary, _state: Dictionary) -> void:
    if effect.get("op", "") == "gain_extra_action":
        intent["technique_combo"] = (
            bool(intent.get("technique_combo", false))
            or value_resolver.resolve(effect.get("amount", {}), context) > 0)
