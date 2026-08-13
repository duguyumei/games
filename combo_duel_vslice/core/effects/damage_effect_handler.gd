class_name DamageEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["damage", "multi_damage"]

func group_name() -> String:
    return "damage"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("伤害处理器缺少战斗端口")
    match str(effect.get("op", "")):
        "damage":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var is_true := bool(effect.get("true_damage", false))
            if effect.has("true_damage_when"):
                is_true = value_resolver.condition_met(
                    effect["true_damage_when"], runtime)
            var result: Dictionary = runtime.ports.deal_damage(
                runtime.actor, runtime.target, amount, "technique", is_true,
                runtime.action_token)
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("reason", "伤害结算失败")))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result]
            return EffectResultScript.succeeded(
                "伤害 %d（防御-%d / 生命-%d）" % [
                    amount, result["defense_lost"], result["life_lost"]], {
                    "life_lost": int(result["life_lost"]),
                    "defense_lost": int(result["defense_lost"]),
                    "true_damage": is_true,
                })
        "multi_damage":
            return _execute_multi_damage(effect, runtime)
    return _unsupported(effect)

func summarize(effect: Dictionary, context, intent: Dictionary, state: Dictionary) -> void:
    match str(effect.get("op", "")):
        "damage":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
            var is_true := bool(effect.get("true_damage", false))
            if effect.has("true_damage_when"):
                is_true = value_resolver.condition_met(effect["true_damage_when"], context)
            var projected := amount if is_true else int(floor(
                amount * (1.0 + int(state.get("damage_percent", 0)) / 100.0)))
            intent["damage"] = int(intent.get("damage", 0)) + projected
            if is_true:
                intent["true_damage"] = int(intent.get("true_damage", 0)) + projected
            intent["segments"] = int(intent.get("segments", 0)) + 1
        "multi_damage":
            var count := maxi(0, int(effect.get("segments", 1)))
            for _index in range(count):
                var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
                intent["damage"] = int(intent.get("damage", 0)) + int(floor(
                    amount * (1.0 + int(state.get("damage_percent", 0)) / 100.0)))
                intent["segments"] = int(intent.get("segments", 0)) + 1

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) != "multi_damage":
        return
    validator.validate_positive_integer(effect.get("segments"), scope + ".segments", "segments")
    for retired_field in ["after_each_stack", "chase_stack"]:
        if effect.has(retired_field):
            validator.report_error(
                scope + "." + retired_field,
                "依赖旧命名角色层数的字段已废弃")

func _execute_multi_damage(effect: Dictionary, runtime):
    var actor = runtime.actor
    var target = runtime.target
    var ports = runtime.ports
    var segments := int(effect.get("segments", 1))
    var life_hits := 0
    var previous_life_hit := false
    var chase_count := 0
    for _index in range(segments):
        if not ports.actor_can_continue(actor) or not ports.target_can_receive(target):
            break
        var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
        var hit: Dictionary = ports.deal_damage(actor, target, amount, "technique")
        if not hit.get("success", false):
            return EffectResultScript.failed(str(hit.get("reason", "多段伤害结算失败")))
        var current_life_hit: bool = int(hit["life_lost"]) > 0
        if current_life_hit:
            life_hits += 1
        if previous_life_hit and current_life_hit \
                and int(effect.get("chase_on_consecutive_life_hits_percent", 0)) > 0:
            var chase_amount := int(floor(
                amount * int(effect["chase_on_consecutive_life_hits_percent"]) / 100.0))
            ports.deal_damage(actor, target, chase_amount, "chase")
            chase_count += 1
        previous_life_hit = current_life_hit
    return EffectResultScript.succeeded(
        "多段 %d，伤及生命 %d 段，追击 %d 段" % [segments, life_hits, chase_count])

func _unsupported(effect: Dictionary):
    return EffectResultScript.failed(
        "伤害处理器不支持：%s" % str(effect.get("op", "")))
