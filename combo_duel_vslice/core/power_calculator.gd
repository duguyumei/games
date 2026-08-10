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
    for card in hand_result["contributing"]:
        var contribution: int = (
            card.effective_qi_value() if card.has_method("effective_qi_value") else card.qi_value)
        if card.has_method("reshape_card_contribution"):
            contribution = card.reshape_card_contribution(contribution)
        if card.has_method("reshape_multiplier_bonus"):
            card_multiplier_bonus += card.reshape_multiplier_bonus()
        if card.has_method("reshape_power_amp_percent"):
            card_amp_percent += card.reshape_power_amp_percent()
        if contribution_modifier.is_valid():
            contribution = int(contribution_modifier.call(card, contribution))
        card_total += contribution
    var base_value: int = card_total + int(modifiers.get("base_fixed", 0))
    var fixed_multiplier: int = int(hand_result["multiplier"])
    var technique_multiplier: int = (
        fixed_multiplier
        + int(modifiers.get("insight_multiplier", 0))
        + int(modifiers.get("multiplier_bonus", 0))
        + card_multiplier_bonus)
    var baseline_value: int = base_value * fixed_multiplier
    var unamplified: int = (
        base_value * technique_multiplier
        + int(modifiers.get("power_fixed", 0)))
    var amp_percent: int = int(modifiers.get("power_amp_percent", 0)) + card_amp_percent
    var technique_value := maxi(0, int(floor(unamplified * (1.0 + amp_percent / 100.0))))
    return {
        "card_total": card_total,
        "base_value": base_value,
        "fixed_multiplier": fixed_multiplier,
        "technique_multiplier": technique_multiplier,
        "baseline_value": baseline_value,
        "unamplified_technique_value": unamplified,
        "power_amp_percent": amp_percent,
        "card_multiplier_bonus": card_multiplier_bonus,
        "card_amp_percent": card_amp_percent,
        "technique_value": technique_value,
    }
