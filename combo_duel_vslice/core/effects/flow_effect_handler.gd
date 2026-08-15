class_name FlowEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "gain_extra_action", "add_momentum", "set_momentum",
        "set_reflection_percent", "add_direct_power_fixed",
        "add_direct_power_percent",
        "register_delayed_effects",
        "register_response",
        "register_next_round_hand_limit",
        "register_defense_decay_return", "set_reflection_until_turn_end",
        "register_no_life_loss_disruption",
        "steal_random_card_if_power_target_and_same_qi",
        "recover_forest_priority",
        "burn_deck_then_heat_hand",
        "retrigger_current_hand_technique",
        "grant_reflection_source", "grant_reflection_true_damage",
        "grant_block", "register_challenge",
        "grant_defense_retention", "add_pending_power_fixed",
        "clear_same_qi_for_defense", "add_same_qi",
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
        "add_momentum":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var changed: int = runtime.ports.add_momentum(runtime.actor, amount)
            return EffectResultScript.succeeded("连势 %+d" % changed)
        "set_momentum":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            runtime.ports.set_momentum(runtime.actor, amount)
            return EffectResultScript.succeeded("连势设为 %d" % runtime.actor.momentum_value)
        "set_reflection_percent":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            runtime.ports.set_reflection_percent(runtime.actor, amount)
            return EffectResultScript.succeeded("反震设为 %d%%" % runtime.actor.current_reflection_percent)
        "set_reflection_until_turn_end":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            var result: Dictionary = runtime.ports.register_reflection_expiry(runtime, amount)
            return EffectResultScript.succeeded("反震设为 %d%%" % amount) \
                if result.get("success", false) else EffectResultScript.failed("反震到期记录失败")
        "grant_reflection_source":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            if bool(effect.get("add_to_current", false)):
                amount += int(runtime.actor.current_reflection_percent)
            var result: Dictionary = runtime.ports.grant_reflection_source(
                runtime.actor, amount, int(effect.get("rounds", 1)),
                str(effect.get("expiry", "round_end")),
                runtime.technique_name if runtime.technique_name != "" else "反震",
                "", runtime.target)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result.get("record", {})]
            return EffectResultScript.succeeded("建立%d%%反震来源" % amount) \
                if result.get("success", false) else EffectResultScript.failed("反震来源建立失败")
        "grant_reflection_true_damage":
            var result: Dictionary = runtime.ports.grant_reflection_true_damage_source(
                runtime.actor, int(effect.get("rounds", 1)),
                runtime.technique_name if runtime.technique_name != "" else "反震真伤")
            return EffectResultScript.succeeded("反震伤害改为真伤") \
                if result.get("success", false) else EffectResultScript.failed("反震真伤来源建立失败")
        "grant_block":
            var result: Dictionary = runtime.ports.grant_block_source(
                runtime.actor, runtime.target,
                str(effect.get("condition", "unconditional")),
                runtime.technique_name if runtime.technique_name != "" else "格挡")
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result.get("record", {})]
            return EffectResultScript.succeeded("获得1次格挡") \
                if result.get("success", false) else EffectResultScript.failed("格挡来源建立失败")
        "register_challenge":
            var threshold: int = value_resolver.resolve(effect.get("threshold", 0), runtime)
            var result: Dictionary = runtime.ports.register_challenge(
                runtime, threshold, effect.get("effects", []),
                runtime.technique_name if runtime.technique_name != "" else "邀战")
            return EffectResultScript.succeeded("邀战%d" % threshold) \
                if result.get("success", false) else EffectResultScript.failed("邀战建立失败")
        "grant_defense_retention":
            var record: Dictionary = runtime.actor.add_defense_retention_source(
                int(effect.get("additional_percent", 0)),
                bool(effect.get("prevent_decay", false)), "",
                int(effect.get("rounds", 1)), runtime.technique_name)
            return EffectResultScript.succeeded("建立防御保留来源") \
                if not record.is_empty() else EffectResultScript.failed("防御保留来源建立失败")
        "add_pending_power_fixed":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            runtime.actor.add_pending_power_fixed_source(
                amount, "", runtime.technique_name)
            return EffectResultScript.succeeded("下一门成功功法值+%d" % amount)
        "clear_same_qi_for_defense":
            var cleared := maxi(0, int(runtime.actor.same_qi_value))
            runtime.actor.same_qi_value = 0
            var defense := cleared * int(effect.get("defense_per_point", 4))
            runtime.ports.add_defense(
                runtime.actor, defense, runtime.technique_name, runtime.action_token)
            return EffectResultScript.succeeded("清空%d同气并获得%d防御" % [cleared, defense])
        "add_same_qi":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            var result: Dictionary = runtime.ports.gain_same_qi(
                runtime.actor, amount, runtime.technique_name,
                "%s:%s:add_same_qi" % [runtime.action_token, runtime.technique_id])
            return EffectResultScript.succeeded("同气+%d" % amount) \
                if result.get("success", false) else EffectResultScript.failed(str(result.get("reason", "同气增加失败")))
        "register_defense_decay_return":
            runtime.ports.register_defense_decay_return(runtime)
            return EffectResultScript.succeeded("记录本回合自然防御衰减")
        "register_no_life_loss_disruption":
            runtime.ports.register_no_life_loss_disruption(runtime, effect.get("effect", {}))
            return EffectResultScript.succeeded("记录行动结束生命损失检查")
        "steal_random_card_if_power_target_and_same_qi":
            if runtime.group_snapshot.get("power_formation_target_cards", []).is_empty() \
                    or not value_resolver.condition_met({
                        "same_qi": str(effect.get("attribute", "wind"))}, runtime):
                return EffectResultScript.succeeded()
            var result: Dictionary = runtime.ports.steal_random_normal_card(
                runtime.actor, runtime.target)
            return EffectResultScript.succeeded(
                "夺取敌方真气" if result.get("success", false) else "")
        "recover_forest_priority":
            var result: Dictionary = runtime.ports.recover_forest_priority(
                runtime.actor, runtime.power,
                value_resolver.condition_met({"same_qi": "forest"}, runtime))
            return EffectResultScript.succeeded(
                "回收真气" if result.get("success", false) else "")
        "burn_deck_then_heat_hand":
            var result: Dictionary = runtime.ports.burn_deck_then_heat_hand(
                runtime.actor,
                value_resolver.condition_met({"same_qi": "fire"}, runtime),
                str(effect.get("choice_capture", "heat_target")), runtime)
            return EffectResultScript.succeeded(str(result.get("detail", ""))) \
                if result.get("success", true) else EffectResultScript.failed(str(result.get("reason", "引火失败")))
        "add_direct_power_fixed":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            runtime.ports.add_direct_power_fixed(runtime.actor, amount)
            return EffectResultScript.succeeded("直接功法值固定修正 %+d" % amount)
        "add_direct_power_percent":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            runtime.ports.add_direct_power_percent(runtime.actor, amount)
            return EffectResultScript.succeeded("直接功法值百分比修正 %+d%%" % amount)
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
        "register_response":
            var result: Dictionary = runtime.ports.register_response(
                str(effect.get("event", "")), str(effect.get("expiry", "turn_end")),
                effect.get("effects", []), runtime, effect.get("filters", {}))
            return EffectResultScript.succeeded("建立战斗响应") \
                if result.get("success", false) \
                else EffectResultScript.failed(str(result.get("reason", "响应建立失败")))
        "register_next_round_hand_limit":
            var affected_side = runtime.target \
                if str(effect.get("side", "actor")) == "target" else runtime.actor
            var result: Dictionary = runtime.ports.register_next_round_hand_limit(
                runtime,
                value_resolver.resolve(effect.get("amount", 0), runtime),
                affected_side)
            return EffectResultScript.succeeded("建立下一回合手牌上限修正") \
                if result.get("success", false) \
                else EffectResultScript.failed(str(result.get("reason", "手牌上限记录失败")))
        "retrigger_current_hand_technique":
            var result: Dictionary = runtime.ports.retrigger_current_hand_technique(
                runtime.actor,
                runtime.target,
                runtime.sequence_book,
                runtime.power_snapshot(),
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

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    match str(effect.get("op", "")):
        "register_delayed_effects":
            if str(effect.get("timing", "")) not in ["turn_end", "after_normal_draw"]:
                validator.report_error(scope + ".timing", "未知延迟事件时点 %s" % str(effect.get("timing", "")))
            validator.validate_positive_integer(
                effect.get("occurrences"), scope + ".occurrences", "occurrences")
            validator.validate_nested_battle_effects(
                effect.get("effects"), scope + ".effects")
        "register_response":
            validator.validate_nested_battle_effects(
                effect.get("effects", []), scope + ".effects")
        "register_no_life_loss_disruption":
            validator.validate_nested_battle_effects(
                [effect.get("effect", {})], scope + ".effect")
        "register_challenge":
            validator.validate_nested_battle_effects(
                effect.get("effects", []), scope + ".effects")
