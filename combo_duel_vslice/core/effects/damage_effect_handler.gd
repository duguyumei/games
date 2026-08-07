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
            var result: Dictionary = runtime.ports.deal_damage(
                runtime.actor, runtime.target, amount, "technique")
            if not result.get("success", false):
                return EffectResultScript.failed(str(result.get("reason", "伤害结算失败")))
            return EffectResultScript.succeeded(
                "伤害 %d（防御-%d / 生命-%d）" % [
                    amount, result["defense_lost"], result["life_lost"]])
        "multi_damage":
            return _execute_multi_damage(effect, runtime)
    return _unsupported(effect)

func summarize(effect: Dictionary, context, intent: Dictionary, state: Dictionary) -> void:
    match str(effect.get("op", "")):
        "damage":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
            intent["damage"] = int(intent.get("damage", 0)) + int(floor(
                amount * (1.0 + int(state.get("momentum", 0)) / 100.0)))
            intent["segments"] = int(intent.get("segments", 0)) + 1
        "multi_damage":
            var count := maxi(0, int(effect.get("segments", 1)))
            for _index in range(count):
                var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
                intent["damage"] = int(intent.get("damage", 0)) + int(floor(
                    amount * (1.0 + int(state.get("momentum", 0)) / 100.0)))
                intent["segments"] = int(intent.get("segments", 0)) + 1
                var after_stack: Dictionary = effect.get("after_each_stack", {})
                if after_stack.get("stack", "") == "momentum":
                    state["momentum"] = (
                        int(state.get("momentum", 0))
                        + maxi(0, int(after_stack.get("amount", 0))))

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
        var after_stack: Dictionary = effect.get("after_each_stack", {})
        if not after_stack.is_empty():
            ports.add_actor_status(
                actor,
                str(after_stack["stack"]),
                int(after_stack.get("amount", 0)),
                runtime.technique_name if runtime.technique_name != "" else "功法")
        if previous_life_hit and current_life_hit \
                and int(effect.get("chase_on_consecutive_life_hits_percent", 0)) > 0:
            var chase_amount := int(floor(
                amount * int(effect["chase_on_consecutive_life_hits_percent"]) / 100.0))
            ports.deal_damage(actor, target, chase_amount, "chase")
            ports.add_actor_status(
                actor,
                "momentum",
                int(effect.get("chase_stack", 0)),
                runtime.technique_name if runtime.technique_name != "" else "功法")
            chase_count += 1
        previous_life_hit = current_life_hit
    return EffectResultScript.succeeded(
        "多段 %d，伤及生命 %d 段，追击 %d 段" % [segments, life_hits, chase_count])

func _unsupported(effect: Dictionary):
    return EffectResultScript.failed(
        "伤害处理器不支持：%s" % str(effect.get("op", "")))
