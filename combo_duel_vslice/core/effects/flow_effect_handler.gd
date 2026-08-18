class_name FlowEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "gain_extra_action", "write_momentum", "add_direct_power_fixed",
        "add_direct_power_percent",
        "register_delayed_effects",
        "register_response",
        "register_next_round_hand_limit",
        "register_defense_decay_return",
        "register_no_life_loss_disruption",
        "steal_random_card_if_power_target_and_same_qi",
        "recover_forest_priority",
        "burn_deck_then_heat_hand",
        "retrigger_current_hand_technique",
        "grant_reflection_source", "grant_reflection_true_damage",
        "grant_block", "grant_deflection", "register_challenge",
        "grant_defense_retention", "add_pending_power_fixed",
        "write_same_qi", "grant_momentum_preservation",
    ]

func group_name() -> String:
    return "flow_delay"

func default_phase(operation_id: String) -> String:
    if operation_id in [
            "write_momentum",
            "grant_reflection_source", "grant_reflection_true_damage",
            "grant_block", "grant_deflection", "register_challenge",
            "grant_defense_retention",
            "add_pending_power_fixed", "add_direct_power_fixed",
            "add_direct_power_percent",
            "steal_random_card_if_power_target_and_same_qi"]:
        return "prepare"
    return "zones"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("流程处理器缺少战斗端口")
    match str(effect.get("op", "")):
        "gain_extra_action":
            var amount: int = value_resolver.resolve(effect.get("amount", {}), runtime)
            var side = runtime.resolve_side(str(effect.get("side", "actor")))
            if side == null:
                return EffectResultScript.failed("额外行动目标作用域不存在")
            runtime.ports.gain_extra_actions(
                side, amount,
                runtime.source_name if runtime.source_name != "" else "效果",
                str(effect.get("source_category", runtime.source_kind)),
                runtime.action_token)
            return EffectResultScript.succeeded("连击机会 +%d" % amount)
        "write_momentum":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            var operation := str(effect.get("operation", "add"))
            var momentum_action_token: String = runtime.action_token
            if bool(effect.get("action_token_from_event", false)):
                var events: Array = runtime.captures.get("event", [])
                if not events.is_empty():
                    momentum_action_token = str(events[0].get(
                        "action_token", momentum_action_token))
            var side = runtime.resolve_side(str(effect.get("side", "actor")))
            if side == null:
                return EffectResultScript.failed("连势目标作用域不存在")
            var receipt: Dictionary = runtime.ports.write_momentum(
                side, operation, amount, runtime.source_kind,
                momentum_action_token, runtime.source_id)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = \
                    [receipt] if bool(receipt.get("success", false)) else []
            return EffectResultScript.succeeded("连势写入完成")
        "grant_momentum_preservation":
            var settlement_token: String = runtime.invocation_token \
                if runtime.invocation_token != "" \
                else runtime.root_action_token
            if settlement_token == "":
                settlement_token = runtime.action_token
            var record: Dictionary = runtime.actor.grant_momentum_preservation(
                settlement_token, runtime.source_id)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [record]
            return EffectResultScript.succeeded("建立一次连势保留保护")
        "grant_reflection_source":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            if bool(effect.get("add_to_current", false)):
                amount += int(runtime.actor.current_reflection_percent)
            var result: Dictionary = runtime.ports.grant_reflection_source(
                runtime.actor, amount, int(effect.get("rounds", 1)),
                str(effect.get("expiry", "round_end")),
                runtime.source_name if runtime.source_name != "" else "反震",
                "", runtime.target)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result.get("record", {})]
            return EffectResultScript.succeeded("建立%d%%反震来源" % amount) \
                if result.get("success", false) else EffectResultScript.failed("反震来源建立失败")
        "grant_reflection_true_damage":
            var result: Dictionary = runtime.ports.grant_reflection_true_damage_source(
                runtime.actor, int(effect.get("rounds", 1)),
                runtime.source_name if runtime.source_name != "" else "反震真伤")
            return EffectResultScript.succeeded("反震伤害改为真伤") \
                if result.get("success", false) else EffectResultScript.failed("反震真伤来源建立失败")
        "grant_block":
            var result: Dictionary = runtime.ports.grant_block_source(
                runtime.actor, runtime.target,
                effect.get("condition_spec", {}),
                runtime.source_name if runtime.source_name != "" else "格挡",
                "", runtime.source_metadata())
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result.get("record", {})]
            return EffectResultScript.succeeded("获得1次格挡") \
                if result.get("success", false) else EffectResultScript.failed("格挡来源建立失败")
        "grant_deflection":
            var threshold: int = value_resolver.resolve(
                effect.get("threshold", effect.get("amount", 0)), runtime)
            var result: Dictionary = runtime.ports.grant_deflection_source(
                runtime.actor, runtime.target, threshold,
                runtime.source_name if runtime.source_name != "" else "卸力",
                "", runtime.source_metadata())
            if effect.has("capture") and result.get("success", false):
                runtime.captures[str(effect["capture"])] = [result.get(
                    "record", {})]
            return EffectResultScript.succeeded("获得1次卸力%d" % threshold) \
                if result.get("success", false) else EffectResultScript.failed(
                    str(result.get("reason", "卸力来源建立失败")))
        "register_challenge":
            var threshold: int = value_resolver.resolve(effect.get("threshold", 0), runtime)
            var result: Dictionary = runtime.ports.register_challenge(
                runtime, threshold, effect.get("effects", []),
                runtime.source_name if runtime.source_name != "" else "邀战",
                effect.get("met_effects", []))
            if effect.has("capture") and result.get("success", false):
                runtime.captures[str(effect["capture"])] = [result.get("record", {})]
            return EffectResultScript.succeeded("邀战%d" % threshold) \
                if result.get("success", false) else EffectResultScript.failed("邀战建立失败")
        "grant_defense_retention":
            var record: Dictionary = runtime.actor.add_defense_retention_source(
                int(effect.get("additional_percent", 0)),
                bool(effect.get("prevent_decay", false)), "",
                int(effect.get("rounds", 1)), runtime.source_name)
            return EffectResultScript.succeeded("建立防御保留来源") \
                if not record.is_empty() else EffectResultScript.failed("防御保留来源建立失败")
        "add_pending_power_fixed":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            if amount > 0:
                runtime.actor.add_pending_power_fixed_source(
                    amount,
                    "%s:%s:pending_power_fixed" % [
                        runtime.action_token, runtime.slot_instance_id],
                    runtime.source_name, true, {
                        "source_instance_key": runtime.source_instance_key,
                        "content_id": runtime.source_id,
                        "source_kind": runtime.source_kind,
                    })
            return EffectResultScript.succeeded("下一门成功功法值+%d" % amount)
        "write_same_qi":
            var amount: int = value_resolver.resolve(effect.get("amount", 0), runtime)
            var receipt_key := str(effect.get("receipt_key", "default"))
            if bool(effect.get("receipt_key_from_event", false)):
                var events: Array = runtime.captures.get("event", [])
                if not events.is_empty():
                    receipt_key += ":" + str(events[0].get(
                        "event_token", events[0].get("event_serial", "event")))
            var side = runtime.resolve_side(str(effect.get("side", "actor")))
            if side == null:
                return EffectResultScript.failed("同气目标作用域不存在")
            var result: Dictionary = runtime.ports.write_same_qi(
                side, str(effect.get("operation", "add")), amount,
                runtime.source_name,
                "%s:%s:write_same_qi:%s" % [
                    runtime.action_token, runtime.source_id,
                    receipt_key],
                runtime.source_kind, runtime.action_token)
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = [result] \
                    if result.get("success", false) else []
            return EffectResultScript.succeeded("同气写入完成") \
                if result.get("success", false) else EffectResultScript.failed(
                    str(result.get("reason", "同气写入失败")))
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
                runtime.actor, runtime.target, runtime.source_metadata())
            return EffectResultScript.succeeded(
                "夺取敌方真气" if result.get("success", false) else "")
        "recover_forest_priority":
            var result: Dictionary = runtime.ports.recover_forest_priority(
                runtime.actor, runtime.power,
                value_resolver.condition_met({"same_qi": "forest"}, runtime),
                runtime.source_metadata())
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
                runtime.source_name if runtime.source_name != "" else "延迟效果",
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
                effect.get("effects", []), runtime, effect.get("filters", {}),
                effect.get("expiry_effects", []))
            return EffectResultScript.succeeded("建立战斗响应") \
                if result.get("success", false) \
                else EffectResultScript.failed(str(result.get("reason", "响应建立失败")))
        "register_next_round_hand_limit":
            var affected_side = runtime.resolve_side(str(
                effect.get("side", "actor")))
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
                effect.get("excluded_technique_ids", []),
                runtime)
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
        "write_momentum":
            if str(effect.get("operation", "add")) not in [
                    "add", "set", "clear", "consume"]:
                validator.report_error(scope + ".operation", "引用未知连势写入操作")
            if str(effect.get("operation", "add")) != "clear" \
                    and not effect.has("amount"):
                validator.report_error(scope + ".amount", "连势写入缺少 amount")
            if effect.has("action_token_from_event") \
                    and not effect["action_token_from_event"] is bool:
                validator.report_error(
                    scope + ".action_token_from_event", "必须是布尔值")
        "register_delayed_effects":
            if str(effect.get("timing", "")) not in ["turn_end", "after_normal_draw"]:
                validator.report_error(scope + ".timing", "未知延迟事件时点 %s" % str(effect.get("timing", "")))
            validator.validate_positive_integer(
                effect.get("occurrences"), scope + ".occurrences", "occurrences")
            validator.validate_nested_battle_effects(
                effect.get("effects"), scope + ".effects")
        "register_response":
            validator.validate_response_event(
                str(effect.get("event", "")), scope + ".event")
            validator.validate_event_filters(
                effect.get("filters", {}), scope + ".filters")
            validator.validate_nested_battle_effects(
                effect.get("effects", []), scope + ".effects")
            if effect.has("expiry_effects"):
                validator.validate_nested_battle_effects(
                    effect.get("expiry_effects", []), scope + ".expiry_effects")
        "register_no_life_loss_disruption":
            validator.validate_nested_battle_effects(
                [effect.get("effect", {})], scope + ".effect")
        "register_challenge":
            validator.validate_nested_battle_effects(
                effect.get("effects", []), scope + ".effects")
            if effect.has("met_effects"):
                validator.validate_nested_battle_effects(
                    effect.get("met_effects", []), scope + ".met_effects")
        "grant_block":
            validator.validate_event_filters(
                effect.get("condition_spec", {}), scope + ".condition_spec")
            if effect.has("condition"):
                validator.report_error(
                    scope + ".condition", "旧字符串格挡条件已废弃，请使用 condition_spec")
        "grant_deflection":
            if effect.get("threshold", effect.get("amount", 0)) is Dictionary:
                validator.validate_amount_spec(
                    effect.get("threshold", effect.get("amount", 0)),
                    scope + ".threshold")
            else:
                validator.validate_non_negative_integer(
                    effect.get("threshold", effect.get("amount", 0)),
                    scope + ".threshold", "threshold")
