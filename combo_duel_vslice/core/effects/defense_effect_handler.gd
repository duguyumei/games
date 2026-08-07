class_name DefenseEffectHandler
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["defense", "defense_from_noncontributing_qi"]

func group_name() -> String:
    return "defense"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.actor == null:
        return EffectResultScript.failed("防御处理器缺少行动方")
    match str(effect.get("op", "")):
        "defense":
            var resolved: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var amount: int = (
                runtime.ports.add_defense(runtime.actor, resolved)
                if runtime.ports != null else runtime.actor.add_defense(resolved))
            return EffectResultScript.succeeded("获得 %d 防御" % amount)
        "defense_from_noncontributing_qi":
            var resolved: int = value_resolver.noncontributing_qi_total(runtime)
            var amount: int = (
                runtime.ports.add_defense(runtime.actor, resolved)
                if runtime.ports != null else runtime.actor.add_defense(resolved))
            return EffectResultScript.succeeded("额外真气转化 %d 防御" % amount)
    return EffectResultScript.failed("防御处理器不支持：%s" % str(effect.get("op", "")))

func summarize(effect: Dictionary, context, intent: Dictionary, _state: Dictionary) -> void:
    match str(effect.get("op", "")):
        "defense":
            intent["defense"] = int(intent.get("defense", 0)) + maxi(
                0, value_resolver.resolve(effect.get("amount", {}), context))
        "defense_from_noncontributing_qi":
            intent["defense"] = int(intent.get("defense", 0)) + value_resolver.noncontributing_qi_total(context)
