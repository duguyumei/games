class_name PowerCalculator
extends RefCounted

const ATTRIBUTES := ["wind", "forest", "fire", "mountain"]

static func calculate(
        hand_result: Dictionary,
        modifiers: Dictionary = {},
        contribution_modifier: Callable = Callable(),
        identity_policy = null,
        identity_context: Dictionary = {},
        effective_qi_provider: Callable = Callable()) -> Dictionary:
    if hand_result.is_empty():
        return {}
    var card_total := 0
    var card_multiplier_bonus := 0
    var card_amp_percent := 0
    var card_trigger_bundles: Dictionary = {}
    var numeric_cards: Array = hand_result.get(
        "numeric_contributing", hand_result.get("contributing", [])).duplicate()
    var counted_card_ids: Dictionary = {}
    var attribute_counts := {
        "wind": 0, "forest": 0, "fire": 0, "mountain": 0,
    }
    for card in numeric_cards:
        var bundle := _qualified_card_numeric_bundle(
            card, contribution_modifier, identity_policy, identity_context,
            effective_qi_provider)
        card_total += int(bundle["contribution"])
        card_multiplier_bonus += int(bundle["technique_multiplier_bonus"])
        card_amp_percent += int(bundle["power_amp_percent"])
        card_trigger_bundles[str(card.id)] = bundle
        var card_id := str(card.id)
        if counted_card_ids.has(card_id):
            continue
        counted_card_ids[card_id] = true
        var identity: Dictionary = bundle.get("identity", {})
        for attribute in ATTRIBUTES:
            if identity.get("effective_attributes", []).has(attribute):
                attribute_counts[attribute] = int(attribute_counts[attribute]) + 1
    var base_value: int = card_total + int(modifiers.get("base_fixed", 0))
    var attribute_concentration := 0
    for count in attribute_counts.values():
        attribute_concentration = maxi(attribute_concentration, int(count))
    var concentrated_attributes: Array[String] = []
    for attribute in ATTRIBUTES:
        if attribute_concentration > 0 \
                and int(attribute_counts[attribute]) == attribute_concentration:
            concentrated_attributes.append(attribute)
    var technique_multiplier: int = (
        attribute_concentration
        + int(modifiers.get("multiplier_bonus", 0))
        + card_multiplier_bonus)
    var baseline_value: int = base_value
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
        "contribution_total": base_value,
        "attribute_counts": attribute_counts,
        "attribute_concentration": attribute_concentration,
        "concentrated_attributes": concentrated_attributes,
        "technique_multiplier": technique_multiplier,
        "baseline_value": baseline_value,
        "initial_power": initial_power,
        "p0": initial_power,
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

static func calculate_from_initial_power(
        initial_power: int,
        direct_power_fixed: int = 0,
        direct_power_percent: int = 0,
        momentum: int = 0) -> Dictionary:
    var pre_momentum_power := int(floor(
        (initial_power + direct_power_fixed)
        * (1.0 + direct_power_percent / 100.0)))
    return apply_momentum({
        "initial_power": initial_power,
        "p0": initial_power,
        "direct_power_fixed": direct_power_fixed,
        "direct_power_percent": direct_power_percent,
        "pre_momentum_power": pre_momentum_power,
        "momentum_used": 0,
        "technique_value": maxi(0, pre_momentum_power),
    }, momentum)

static func apply_direct_power_fixed(values: Dictionary, amount: int) -> Dictionary:
    var result := values.duplicate(true)
    result["direct_power_fixed"] = int(result.get("direct_power_fixed", 0)) + amount
    result["pre_momentum_power"] = int(floor(
        (int(result.get("initial_power", 0))
        + int(result["direct_power_fixed"]))
        * (1.0 + int(result.get("direct_power_percent", 0)) / 100.0)))
    return apply_momentum(result, int(result.get("momentum_used", 0)))

static func _qualified_card_numeric_bundle(
        card,
        contribution_modifier: Callable,
        identity_policy = null,
        identity_context: Dictionary = {},
        effective_qi_provider: Callable = Callable()) -> Dictionary:
    var identity: Dictionary = {}
    if identity_policy != null and identity_policy.has_method("resolve"):
        var identity_result: Dictionary = identity_policy.resolve(
            card, identity_context)
        if identity_result.get("success", false):
            identity = identity_result["facts"].to_dict()
    elif card != null:
        var attributes: Array[String] = []
        for attribute in ATTRIBUTES:
            if card.has_method("is_attribute") and card.is_attribute(attribute):
                attributes.append(attribute)
        identity = {
            "is_true_qi": true,
            "effective_attributes": attributes,
            "card_kinds": ["normal"] if not card.has_method("is_card_kind") \
                or card.is_card_kind("normal") else [],
        }
    if card.has_method("effective_qi_value") \
            and card.has_method("reshape_card_contribution"):
        # 读取一次会确保旧卡牌夹具也完成 fallback rules 绑定；该调用纯计算且结果
        # 不参与累加，真正数值统一由单牌触发包从相同原始输入分别计算。
        var calculation_context := {"participating": true}
        if effective_qi_provider.is_valid():
            calculation_context["effective_qi_override"] = int(
                effective_qi_provider.call(card))
        else:
            card.effective_qi_value(false, calculation_context)
        var rules = card.reshape_rule_service
        if rules != null and rules.has_method(
                "calculate_qualified_numeric_bundle"):
            var bundle: Dictionary = rules.calculate_qualified_numeric_bundle(
                card,
                calculation_context,
                contribution_modifier)
            bundle["identity"] = identity
            return bundle
    var effective_qi := int(effective_qi_provider.call(card)) \
        if effective_qi_provider.is_valid() else int(card.qi_value)
    var contribution := effective_qi
    if contribution_modifier.is_valid():
        contribution = int(contribution_modifier.call(card, contribution))
    return {
        "source_card_instance_id": str(card.id),
        "source_trigger": "numeric_bundle",
        "replay_count": 0,
        "trigger_count": 1,
        "effective_qi": effective_qi,
        "contribution": contribution,
        "technique_multiplier_bonus": 0,
        "power_amp_percent": 0,
        "passes": [],
        "identity": identity,
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
