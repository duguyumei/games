class_name PowerCalculator
extends RefCounted

static func calculate(
        hand_result: Dictionary,
        modifiers: Dictionary = {},
        contribution_modifier: Callable = Callable()) -> Dictionary:
    if hand_result.is_empty():
        return {}
    var card_total := 0
    var card_multiplier_bonus := 0
    var card_amp_percent := 0
    var card_trigger_bundles: Dictionary = {}
    for card in hand_result["contributing"]:
        var bundle := _qualified_card_numeric_bundle(
            card, contribution_modifier)
        card_total += int(bundle["contribution"])
        card_multiplier_bonus += int(bundle["technique_multiplier_bonus"])
        card_amp_percent += int(bundle["power_amp_percent"])
        card_trigger_bundles[str(card.id)] = bundle
    var base_value: int = card_total + int(modifiers.get("base_fixed", 0))
    var fixed_multiplier: int = int(hand_result["multiplier"])
    var technique_multiplier: int = (
        fixed_multiplier
        + int(modifiers.get("multiplier_bonus", 0))
        + card_multiplier_bonus)
    var baseline_value: int = base_value * fixed_multiplier
    var initial_power: int = int(floor(base_value * technique_multiplier))
    var direct_power_fixed := int(modifiers.get("power_fixed", 0))
    var direct_power_percent := (
        int(modifiers.get("power_amp_percent", 0)) + card_amp_percent)
    var pre_momentum_power := int(floor(
        (initial_power + direct_power_fixed)
        * (1.0 + direct_power_percent / 100.0)))
    return {
        "card_total": card_total,
        "base_value": base_value,
        "fixed_multiplier": fixed_multiplier,
        "technique_multiplier": technique_multiplier,
        "baseline_value": baseline_value,
        "initial_power": initial_power,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "pre_momentum_power": pre_momentum_power,
        "momentum_used": 0,
        "card_multiplier_bonus": card_multiplier_bonus,
        "card_amp_percent": card_amp_percent,
        "card_trigger_bundles": card_trigger_bundles,
        "technique_value": maxi(0, pre_momentum_power),
    }

static func apply_momentum(values: Dictionary, momentum: int) -> Dictionary:
    var result := values.duplicate(true)
    result["momentum_used"] = maxi(0, momentum)
    result["technique_value"] = maxi(
        0,
        int(result.get("pre_momentum_power", 0))
        + int(result["momentum_used"]))
    return result

static func _qualified_card_numeric_bundle(
        card,
        contribution_modifier: Callable) -> Dictionary:
    if card.has_method("effective_qi_value") \
            and card.has_method("reshape_card_contribution"):
        # 读取一次会确保旧卡牌夹具也完成 fallback rules 绑定；该调用纯计算且结果
        # 不参与累加，真正数值统一由单牌触发包从相同原始输入分别计算。
        card.effective_qi_value(false, {"participating": true})
        var rules = card.reshape_rule_service
        if rules != null and rules.has_method(
                "calculate_qualified_numeric_bundle"):
            return rules.calculate_qualified_numeric_bundle(
                card,
                {"participating": true},
                contribution_modifier)
    var contribution := int(card.qi_value)
    if contribution_modifier.is_valid():
        contribution = int(contribution_modifier.call(card, contribution))
    return {
        "source_card_instance_id": str(card.id),
        "source_trigger": "numeric_bundle",
        "replay_count": 0,
        "trigger_count": 1,
        "effective_qi": int(card.qi_value),
        "contribution": contribution,
        "technique_multiplier_bonus": 0,
        "power_amp_percent": 0,
        "passes": [],
    }

static func apply_frozen_card_multiplier_bonus(
        values: Dictionary,
        bonus: int) -> Dictionary:
    var result := values.duplicate(true)
    var applied_bonus := maxi(0, bonus)
    if applied_bonus == 0:
        return result
    var previous_multiplier := int(result.get("technique_multiplier", 0))
    result["card_multiplier_bonus"] = (
        int(result.get("card_multiplier_bonus", 0)) + applied_bonus)
    result["technique_multiplier"] = previous_multiplier + applied_bonus
    result["initial_power"] = int(floor(
        int(result.get("base_value", 0))
        * int(result["technique_multiplier"])))
    result["pre_momentum_power"] = int(floor(
        (int(result["initial_power"])
        + int(result.get("direct_power_fixed", 0)))
        * (1.0 + int(result.get("direct_power_percent", 0)) / 100.0)))
    return apply_momentum(result, int(result.get("momentum_used", 0)))
