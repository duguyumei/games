class_name DefenseEffectHandler
extends RefCounted

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["defense", "defense_from_noncontributing_qi"]

func group_name() -> String:
    return "defense"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    match str(effect.get("op", "")):
        "defense":
            var amount: int = context["actor"].add_defense(
                value_resolver.resolve(effect.get("amount", {}), context))
            return {"success": true, "detail": "获得 %d 防御" % amount}
        "defense_from_noncontributing_qi":
            var amount: int = context["actor"].add_defense(
                value_resolver.noncontributing_qi_total(context))
            return {"success": true, "detail": "额外真气转化 %d 防御" % amount}
    return {"success": false, "detail": "防御处理器不支持：%s" % str(effect.get("op", ""))}

func summarize(effect: Dictionary, context: Dictionary, intent: Dictionary, _state: Dictionary) -> void:
    match str(effect.get("op", "")):
        "defense":
            intent["defense"] = int(intent.get("defense", 0)) + maxi(
                0, value_resolver.resolve(effect.get("amount", {}), context))
        "defense_from_noncontributing_qi":
            intent["defense"] = int(intent.get("defense", 0)) + value_resolver.noncontributing_qi_total(context)
