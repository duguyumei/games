class_name EffectValueResolver
extends RefCounted

func resolve(spec, context: Dictionary) -> int:
    if spec is int or spec is float:
        return int(spec)
    if not spec is Dictionary:
        return 0
    match spec.get("kind", "constant"):
        "constant":
            return int(spec.get("value", 0))
        "power":
            return int(context.get("power", 0))
        "power_fraction":
            var value := int(floor(
                int(context.get("power", 0))
                * int(spec.get("numerator", 1))
                / float(maxi(1, int(spec.get("denominator", 1))))))
            return maxi(int(spec.get("minimum", 0)), value)
        "n60":
            return maxi(1, int(floor(int(context.get("power", 0)) / 60.0)))
        "hand_map":
            var hand_id := str(context.get("hand_result", {}).get("id", ""))
            return int(spec.get("values", {}).get(hand_id, 0))
        "max":
            var maximum := 0
            for child in spec.get("values", []):
                maximum = maxi(maximum, resolve(child, context))
            return maximum
    return 0

func condition_met(condition: Dictionary, context: Dictionary) -> bool:
    if condition.is_empty():
        return true
    if condition.has("pure_attribute"):
        var attribute: String = condition["pure_attribute"]
        var contributing: Array = context.get("hand_result", {}).get("contributing", [])
        if contributing.is_empty():
            return false
        for card in contributing:
            if card.attribute != attribute:
                return false
    if condition.has("capture_nonempty"):
        var captured: Array = context.get("captures", {}).get(condition["capture_nonempty"], [])
        if captured.is_empty():
            return false
    return true

func noncontributing_qi_total(context: Dictionary) -> int:
    var contributing: Array = context.get("hand_result", {}).get("contributing", [])
    var total := 0
    for card in context.get("played_cards", []):
        if not contributing.has(card):
            total += int(card.qi_value)
    return maxi(0, total)
