class_name DefenseEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["defense", "defense_from_noncontributing_qi", "remove_defense"]

func group_name() -> String:
    return "defense"

func default_phase(_operation_id: String) -> String:
    return "prepare"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.actor == null:
        return EffectResultScript.failed("防御处理器缺少行动方")
    match str(effect.get("op", "")):
        "defense":
            var resolved: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var side = runtime.resolve_side(str(effect.get("side", "actor")))
            if side == null:
                return EffectResultScript.failed("防御目标作用域不存在")
            var amount: int = (
                runtime.ports.add_defense(
                    side, resolved, runtime.source_kind,
                    runtime.action_token)
                if runtime.ports != null else side.add_defense(resolved))
            return EffectResultScript.succeeded("获得 %d 防御" % amount)
        "defense_from_noncontributing_qi":
            var resolved: int = value_resolver.noncontributing_qi_total(runtime)
            var amount: int = (
                runtime.ports.add_defense(
                    runtime.actor, resolved, runtime.source_kind,
                    runtime.action_token)
                if runtime.ports != null else runtime.actor.add_defense(resolved))
            return EffectResultScript.succeeded("额外真气转化 %d 防御" % amount)
        "remove_defense":
            var side = runtime.resolve_side(str(effect.get("side", "actor")))
            if side == null:
                return EffectResultScript.failed("防御移除目标作用域不存在")
            var remove_all := bool(effect.get("all", false))
            var requested: int = value_resolver.resolve(
                effect.get("amount", 0), runtime)
            var result: Dictionary = runtime.ports.remove_defense(
                side, requested, remove_all, runtime.actor, runtime.source_kind,
                runtime.action_token, str(effect.get("cause", "direct_effect")),
                bool(effect.get("require_full", false)))
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("reason", "移除防御失败")))
            var removed: int = int(result.get("removed", 0))
            if effect.has("capture"):
                var captured_result := result.duplicate(true)
                captured_result["amount"] = removed
                runtime.captures[str(effect["capture"])] = [captured_result]
            return EffectResultScript.succeeded("移除防御 %d" % removed)
    return EffectResultScript.failed("防御处理器不支持：%s" % str(effect.get("op", "")))

func summarize(effect: Dictionary, context, intent: Dictionary, _state: Dictionary) -> void:
    match str(effect.get("op", "")):
        "defense":
            intent["defense"] = int(intent.get("defense", 0)) + maxi(
                0, value_resolver.resolve(effect.get("amount", {}), context))
        "defense_from_noncontributing_qi":
            intent["defense"] = int(intent.get("defense", 0)) + value_resolver.noncontributing_qi_total(context)

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) != "remove_defense":
        return
    if str(effect.get("cause", "direct_effect")) not in [
            "damage_absorption", "direct_effect", "cost", "decay", "reset"]:
        validator.report_error(scope + ".cause", "引用未知防御减少 cause")
    if not bool(effect.get("all", false)) and not effect.has("amount"):
        validator.report_error(scope, "remove_defense 必须提供 amount 或 all=true")
    if effect.has("require_full") and not effect["require_full"] is bool:
        validator.report_error(scope + ".require_full", "必须是布尔值")
