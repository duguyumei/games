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

func default_phase(_operation_id: String) -> String:
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
            var damage_type := str(effect.get(
                "damage_type", "true" if is_true else "normal"))
            if effect.has("damage_type_when"):
                var typed: Dictionary = effect["damage_type_when"]
                damage_type = str(typed.get("then", "normal")) \
                    if value_resolver.condition_met(typed.get("when", {}), runtime) \
                    else str(typed.get("else", "normal"))
            is_true = damage_type == "true"
            var damage_actor = runtime.target \
                if str(effect.get("from_side", "actor")) == "target" else runtime.actor
            var damage_target = runtime.actor \
                if str(effect.get("to_side", "target")) == "actor" else runtime.target
            var result: Dictionary = runtime.ports.deal_damage(
                damage_actor, damage_target, amount,
                str(effect.get("source_kind", "technique")), is_true,
                runtime.action_token, damage_type, {
                    "direct_attack": bool(effect.get(
                        "direct_attack",
                        runtime.source_kind in [
                            "technique", "technique_retrigger", "technique_echo"])),
                    "blockable": bool(effect.get("blockable", true)),
                })
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
                    "damage_type": damage_type,
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
            var damage_type := str(effect.get(
                "damage_type", "true" if is_true else "normal"))
            if effect.has("damage_type_when"):
                var typed: Dictionary = effect["damage_type_when"]
                damage_type = str(typed.get("then", "normal")) \
                    if value_resolver.condition_met(
                        typed.get("when", {}), context) \
                    else str(typed.get("else", "normal"))
            var projected := amount if damage_type != "normal" else int(floor(
                amount * (1.0 + int(state.get("damage_percent", 0)) / 100.0)))
            intent["damage"] = int(intent.get("damage", 0)) + projected
            if damage_type == "true":
                intent["true_damage"] = int(intent.get("true_damage", 0)) + projected
            if damage_type == "normal":
                intent["normal_damage"] = int(intent.get("normal_damage", 0)) + projected
            if damage_type == "poison":
                intent["poison_damage"] = int(intent.get("poison_damage", 0)) + projected
            intent["segments"] = int(intent.get("segments", 0)) + 1
        "multi_damage":
            var count := maxi(0, value_resolver.resolve(
                effect.get("segments", 1), context))
            for _index in range(count):
                var amount: int = value_resolver.resolve(effect.get("amount", {}), context)
                var projected: int = int(floor(
                    amount * (1.0 + int(state.get("damage_percent", 0)) / 100.0)))
                intent["damage"] = int(intent.get("damage", 0)) + projected
                intent["normal_damage"] = int(
                    intent.get("normal_damage", 0)) + projected
                intent["segments"] = int(intent.get("segments", 0)) + 1

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) != "multi_damage":
        return
    if effect.get("segments") is Dictionary:
        validator.validate_amount_spec(effect["segments"], scope + ".segments")
    else:
        validator.validate_positive_integer(effect.get("segments"), scope + ".segments", "segments")
    if not effect.get("on_life_loss_effects", []).is_empty():
        validator.validate_nested_battle_effects(
            effect.get("on_life_loss_effects", []),
            scope + ".on_life_loss_effects")
    for retired_field in ["after_each_stack", "chase_stack"]:
        if effect.has(retired_field):
            validator.report_error(
                scope + "." + retired_field,
                "依赖旧命名角色层数的字段已废弃")

func _execute_multi_damage(effect: Dictionary, runtime):
    var actor = runtime.actor
    var target = runtime.target
    var ports = runtime.ports
    var segments := maxi(0, value_resolver.resolve(effect.get("segments", 1), runtime))
    var life_hits := 0
    var previous_life_hit := false
    var chase_count := 0
    var results: Array = []
    for segment_index in range(segments):
        if not ports.actor_can_continue(actor) or not ports.target_can_receive(target):
            break
        var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
        var damage_type := "normal"
        if bool(effect.get("true_when_previous_no_life_loss", false)) \
                and segment_index > 0 and not previous_life_hit:
            damage_type = "true"
        var hit: Dictionary = ports.deal_damage(
            actor, target, amount, "technique", damage_type == "true",
            runtime.action_token, damage_type, {
                "direct_attack": true,
                "blockable": bool(effect.get("blockable", true)),
            })
        if not hit.get("success", false):
            return EffectResultScript.failed(str(hit.get("reason", "多段伤害结算失败")))
        var current_life_hit: bool = int(hit["life_lost"]) > 0
        results.append(hit)
        if current_life_hit:
            life_hits += 1
            if not effect.get("on_life_loss_effects", []).is_empty():
                var child_captures: Dictionary = runtime.captures.duplicate(true)
                child_captures["segment_result"] = [hit]
                child_captures["segment_index"] = [{"amount": segment_index}]
                var child = EffectContextScript.new().configure({
                    "ports": runtime.ports, "actor": runtime.actor,
                    "target": runtime.target, "hand_result": runtime.hand_result,
                    "played_cards": runtime.played_cards, "power": runtime.power,
                    "initial_power": runtime.initial_power,
                    "direct_power_fixed": runtime.direct_power_fixed,
                    "direct_power_percent": runtime.direct_power_percent,
                    "pre_momentum_power": runtime.pre_momentum_power,
                    "momentum_used": runtime.momentum_used,
                    "technique_id": runtime.technique_id,
                    "technique_name": runtime.technique_name,
                    "actual_hand_id": runtime.actual_hand_id,
                    "branch_hand_id": runtime.branch_hand_id,
                    "technique_pool": runtime.technique_pool,
                    "action_token": runtime.action_token,
                    "source_kind": runtime.source_kind,
                    "captures": child_captures,
                    "sequence_book": runtime.sequence_book,
                    "card_identity_policy": runtime.card_identity_policy,
                    "group_snapshot": runtime.group_snapshot,
                })
                var followup: Dictionary = ports.execute_effect_chain(
                    effect.get("on_life_loss_effects", []), child)
                if not followup.get("success", false):
                    return EffectResultScript.failed(str(followup.get(
                        "reason", "多段伤害后续效果失败")))
        if previous_life_hit and current_life_hit \
                and int(effect.get("chase_on_consecutive_life_hits_percent", 0)) > 0:
            var chase_amount := int(floor(
                amount * int(effect["chase_on_consecutive_life_hits_percent"]) / 100.0))
            ports.deal_damage(
                actor, target, chase_amount, "chase", false,
                runtime.action_token, "normal", {"direct_attack": true})
            chase_count += 1
        previous_life_hit = current_life_hit
    if effect.has("capture"):
        runtime.captures[str(effect["capture"])] = results
    return EffectResultScript.succeeded(
        "多段 %d，伤及生命 %d 段，追击 %d 段" % [segments, life_hits, chase_count])

func _unsupported(effect: Dictionary):
    return EffectResultScript.failed(
        "伤害处理器不支持：%s" % str(effect.get("op", "")))
