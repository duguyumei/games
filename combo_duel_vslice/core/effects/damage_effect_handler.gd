class_name DamageEffectHandler
extends RefCounted

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["damage", "multi_damage"]

func group_name() -> String:
    return "damage"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    match str(effect.get("op", "")):
        "damage":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
            var result: Dictionary = context["engine"].deal_damage(
                context["actor"], context["target"], amount, "technique")
            return {
                "success": true,
                "detail": "伤害 %d（防御-%d / 生命-%d）" % [
                    amount, result["defense_lost"], result["life_lost"]],
            }
        "multi_damage":
            return _execute_multi_damage(effect, context)
    return _unsupported(effect)

func summarize(effect: Dictionary, context: Dictionary, intent: Dictionary, state: Dictionary) -> void:
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

func _execute_multi_damage(effect: Dictionary, context: Dictionary) -> Dictionary:
    var actor = context["actor"]
    var target = context["target"]
    var engine = context["engine"]
    var segments := int(effect.get("segments", 1))
    var life_hits := 0
    var previous_life_hit := false
    var chase_count := 0
    for _index in range(segments):
        if not engine.damage_actor_can_continue(actor) or not engine.damage_target_can_receive(target):
            break
        var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
        var hit: Dictionary = engine.deal_damage(actor, target, amount, "technique")
        var current_life_hit: bool = int(hit["life_lost"]) > 0
        if current_life_hit:
            life_hits += 1
        var after_stack: Dictionary = effect.get("after_each_stack", {})
        if not after_stack.is_empty():
            actor.add_stack(after_stack["stack"], int(after_stack.get("amount", 0)))
        if previous_life_hit and current_life_hit \
                and int(effect.get("chase_on_consecutive_life_hits_percent", 0)) > 0:
            var chase_amount := int(floor(
                amount * int(effect["chase_on_consecutive_life_hits_percent"]) / 100.0))
            engine.deal_damage(actor, target, chase_amount, "chase")
            actor.add_stack("momentum", int(effect.get("chase_stack", 0)))
            chase_count += 1
        previous_life_hit = current_life_hit
    return {
        "success": true,
        "detail": "多段 %d，伤及生命 %d 段，追击 %d 段" % [segments, life_hits, chase_count],
    }

func _unsupported(effect: Dictionary) -> Dictionary:
    return {"success": false, "detail": "伤害处理器不支持：%s" % str(effect.get("op", ""))}
