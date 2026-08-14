class_name EffectValueResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

func resolve(spec, context) -> int:
    var runtime = EffectContextScript.coerce(context)
    if spec is int or spec is float:
        return int(spec)
    if not spec is Dictionary:
        return 0
    match spec.get("kind", "constant"):
        "constant":
            return int(spec.get("value", 0))
        "power":
            return runtime.power
        "initial_power":
            return runtime.initial_power
        "initial_power_fraction":
            var value := int(floor(
                runtime.initial_power
                * int(spec.get("numerator", 1))
                / float(maxi(1, int(spec.get("denominator", 1))))))
            return maxi(int(spec.get("minimum", 0)), value)
        "power_fraction":
            var value := int(floor(
                runtime.power
                * int(spec.get("numerator", 1))
                / float(maxi(1, int(spec.get("denominator", 1))))))
            return maxi(int(spec.get("minimum", 0)), value)
        "n60":
            return maxi(1, int(floor(runtime.power / 60.0)))
        "hand_map":
            var values: Dictionary = spec.get("values", {})
            if values.has(runtime.actual_hand_id):
                return int(values[runtime.actual_hand_id])
            if values.has(runtime.branch_hand_id):
                return int(values[runtime.branch_hand_id])
            return 0
        "max":
            var maximum := 0
            for child in spec.get("values", []):
                maximum = maxi(maximum, resolve(child, context))
            return maximum
        "add":
            var total := 0
            for child in spec.get("values", []):
                total += resolve(child, runtime)
            return total
        "subtract":
            return resolve(spec.get("left", 0), runtime) - resolve(spec.get("right", 0), runtime)
        "multiply":
            var product := 1
            for child in spec.get("values", []):
                product *= resolve(child, runtime)
            return product
        "divide_floor":
            return int(floor(
                resolve(spec.get("value", {}), runtime)
                / float(maxi(1, resolve(spec.get("divisor", 1), runtime)))))
        "divide_ceil":
            return int(ceil(
                resolve(spec.get("value", {}), runtime)
                / float(maxi(1, resolve(spec.get("divisor", 1), runtime)))))
        "modulo":
            return resolve(spec.get("value", 0), runtime) \
                % maxi(1, resolve(spec.get("divisor", 1), runtime))
        "capture_count":
            return _capture_cards(runtime, spec).size()
        "capture_qi_sum":
            var total := 0
            for card in _capture_cards(runtime, spec):
                total += int(card.get("qi_value", 0) if card is Dictionary else card.qi_value)
            return total
        "capture_base_qi_sum":
            return HandGroupSnapshotScript.base_qi_sum(
                runtime.group_snapshot, _capture_cards(runtime, spec))
        "capture_current_effective_qi":
            var cards := _capture_cards(runtime, spec)
            if cards.is_empty():
                return 0
            return HandGroupSnapshotScript.current_effective_qi(
                runtime.group_snapshot, cards[0], runtime.actor)
        "capture_effective_qi_sum":
            var total := 0
            for card in _capture_cards(runtime, spec):
                total += runtime.ports.current_effective_qi(
                    _side(runtime, str(spec.get("side", "actor"))), card)
            return total
        "capture_effective_qi_max":
            var maximum := 0
            for card in _capture_cards(runtime, spec):
                maximum = maxi(maximum, runtime.ports.current_effective_qi(
                    _side(runtime, str(spec.get("side", "actor"))), card))
            return maximum
        "capture_r_sum", "capture_r_max":
            var values: Array[int] = []
            var owner = _side(runtime, str(spec.get("side", "actor")))
            for card in _capture_cards(runtime, spec):
                values.append(maxi(0, runtime.ports.current_effective_qi(owner, card) \
                    - int(card.current_base_qi_value())))
            if str(spec.get("kind", "")) == "capture_r_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "capture_anomaly_layers_sum", "capture_anomaly_layers_max":
            var values: Array[int] = []
            for card in _capture_cards(runtime, spec):
                values.append(card.anomaly_layers(
                    str(spec.get("category", "buff")), str(spec.get("anomaly", ""))))
            if str(spec.get("kind", "")) == "capture_anomaly_layers_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "capture_result_count":
            return runtime.captures.get(str(spec.get("capture", "")), []).size()
        "capture_actual_life_loss":
            var total := 0
            for result in runtime.captures.get(str(spec.get("capture", "")), []):
                total += int(result.get("life_lost", result.get("actual_life_loss", 0)))
            return total
        "capture_field_sum", "capture_field_max", "capture_field_first":
            var values: Array[int] = []
            var field := str(spec.get("field", "amount"))
            for entry in runtime.captures.get(str(spec.get("capture", "")), []):
                if entry is Dictionary:
                    values.append(int(entry.get(field, 0)))
            if str(spec.get("kind", "")) == "capture_field_first":
                return values[0] if not values.is_empty() else 0
            if str(spec.get("kind", "")) == "capture_field_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "current_defense":
            var side = _side(runtime, str(spec.get("side", "actor")))
            return int(side.defense) if side != null else 0
        "played_poison_amount":
            return int(runtime.group_snapshot.get("played_poison_amount", 0))
        "played_poison_count":
            return int(runtime.group_snapshot.get("played_poison_count", 0))
        "zone_anomaly_count", "zone_anomaly_qi_sum":
            var side = _side(runtime, str(spec.get("side", "actor")))
            if side == null:
                return 0
            var cards: Array = []
            for zone in spec.get("zones", [spec.get("zone", "hand")]):
                cards.append_array(runtime.ports.zone_cards(side, str(zone)))
            cards = cards.filter(func(card): return card.is_card_kind("normal") \
                and card.has_anomaly(str(spec.get("category", "state")), \
                    str(spec.get("anomaly", "poison"))))
            if str(spec.get("kind", "")) == "zone_anomaly_count":
                return cards.size()
            var total := 0
            for card in cards:
                total += runtime.ports.current_effective_qi(side, card)
            return total
        "group_base_qi_sum":
            return HandGroupSnapshotScript.base_qi_sum(
                runtime.group_snapshot,
                runtime.group_snapshot.get("played_cards", runtime.played_cards))
        "extra_count":
            return runtime.group_snapshot.get("extra_cards", []).size()
        "extra_attribute_count":
            var count := 0
            for card in runtime.group_snapshot.get("extra_cards", []):
                if _card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    count += 1
            return count
        "capture_attribute_qi_sum":
            var total := 0
            for card in _capture_cards(runtime, spec):
                if _card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    total += int(card.get("qi_value", 0) if card is Dictionary else card.qi_value)
            return total
        "capture_attribute_count":
            var count := 0
            for card in _capture_cards(runtime, spec):
                if _card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    count += 1
            return count
        "capture_non_attribute_count":
            var count := 0
            for card in _capture_cards(runtime, spec):
                if not _card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    count += 1
            return count
        "hand_count":
            return runtime.actor.hand.size() if runtime.actor != null else 0
        "target_hand_count":
            return runtime.target.hand.size() if runtime.target != null else 0
        "hand_limit":
            return runtime.actor.current_hand_limit() if runtime.actor != null else 0
        "base_hand_limit":
            return runtime.actor.base_hand_limit() if runtime.actor != null else 0
        "conditional":
            return resolve(
                spec.get("then", {}) if condition_met(spec.get("when", {}), runtime) else spec.get("else", {}),
                runtime)
        "power_scaled_by_zone_anomaly":
            var side = runtime.actor if str(spec.get("side", "actor")) == "actor" else runtime.target
            if side == null:
                return 0
            var count: int = side.count_anomaly_in_zone(
                str(spec.get("zone", "draw_pile")),
                str(spec.get("category", "mark")),
                str(spec.get("anomaly", "")))
            var percent := int(spec.get("percent_per_card", 0))
            if spec.has("pure_attribute_percent") \
                    and condition_met({"pure_attribute": str(spec.get("attribute", "wind"))}, runtime):
                percent = int(spec["pure_attribute_percent"])
            return int(floor(runtime.power * (100 + count * percent) / 100.0))
    return 0

func _side(runtime, side_id: String):
    return runtime.target if side_id == "target" else runtime.actor

func condition_met(condition: Dictionary, context) -> bool:
    var runtime = EffectContextScript.coerce(context)
    if condition.is_empty():
        return true
    if condition.has("all"):
        for child in condition["all"]:
            if not condition_met(child, runtime):
                return false
    if condition.has("any"):
        var matched := false
        for child in condition["any"]:
            if condition_met(child, runtime):
                matched = true
                break
        if not matched:
            return false
    if condition.has("not") and condition_met(condition["not"], runtime):
        return false
    if condition.has("pure_attribute"):
        var attribute: String = condition["pure_attribute"]
        var contributing: Array = runtime.hand_result.get("contributing", [])
        if contributing.is_empty():
            return false
        for card in contributing:
            if not _card_is_attribute(card, attribute, runtime):
                return false
    if condition.has("capture_nonempty"):
        var captured: Array = runtime.captures.get(condition["capture_nonempty"], [])
        if captured.is_empty():
            return false
    if condition.has("capture_empty") \
            and not runtime.captures.get(condition["capture_empty"], []).is_empty():
        return false
    if condition.has("hand_id"):
        var wanted_hand_id := str(condition["hand_id"])
        if runtime.actual_hand_id != wanted_hand_id \
                and runtime.branch_hand_id != wanted_hand_id:
            return false
    if condition.has("capture_count_equals"):
        var spec: Dictionary = condition["capture_count_equals"]
        if runtime.captures.get(spec.get("capture", ""), []).size() != int(spec.get("value", 0)):
            return false
    if condition.has("capture_count_at_least"):
        var spec: Dictionary = condition["capture_count_at_least"]
        if runtime.captures.get(spec.get("capture", ""), []).size() < int(spec.get("value", 0)):
            return false
    if condition.has("capture_all_attribute"):
        var spec: Dictionary = condition["capture_all_attribute"]
        var cards: Array = runtime.captures.get(spec.get("capture", ""), [])
        if cards.is_empty():
            return false
        for card in cards:
            if not _card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                return false
    if condition.has("capture_any_anomaly"):
        var spec: Dictionary = condition["capture_any_anomaly"]
        var cards: Array = runtime.captures.get(str(spec.get("capture", "")), [])
        var has_anomaly := false
        for card in cards:
            if not card is Dictionary and card.has_anomaly(
                    str(spec.get("category", "")), str(spec.get("id", ""))):
                has_anomaly = true
                break
        if not has_anomaly:
            return false
    if condition.has("same_qi") and not HandGroupSnapshotScript.is_same_qi(
            runtime.group_snapshot, str(condition["same_qi"])):
        return false
    if condition.has("capture_result_life_lost"):
        var results: Array = runtime.captures.get(
            str(condition["capture_result_life_lost"]), [])
        if results.is_empty() or int(results[0].get("life_lost", 0)) <= 0:
            return false
    if condition.has("value_at_least"):
        var comparison: Dictionary = condition["value_at_least"]
        var minimum: int = resolve(comparison.get("minimum", 0), runtime) \
            if comparison.get("minimum", 0) is Dictionary else int(comparison.get("minimum", 0))
        if resolve(comparison.get("value", 0), runtime) < minimum:
            return false
    if condition.has("value_greater_than"):
        var comparison: Dictionary = condition["value_greater_than"]
        var threshold: int = resolve(comparison.get("threshold", 0), runtime) \
            if comparison.get("threshold", 0) is Dictionary else int(comparison.get("threshold", 0))
        if resolve(comparison.get("value", 0), runtime) <= threshold:
            return false
    if condition.has("actor_alive"):
        if runtime.actor == null or (int(runtime.actor.life) > 0) != bool(condition["actor_alive"]):
            return false
    if condition.has("capture_card_in_zone"):
        var zone_spec: Dictionary = condition["capture_card_in_zone"]
        var cards: Array = runtime.captures.get(str(zone_spec.get("capture", "")), [])
        var side = _side(runtime, str(zone_spec.get("side", "actor")))
        if cards.is_empty() or side == null \
                or not runtime.ports.zone_cards(side, str(zone_spec.get("zone", "hand"))).has(cards[0]):
            return false
    if condition.has("initial_power_greater_than_group_base_qi"):
        var total := HandGroupSnapshotScript.base_qi_sum(
            runtime.group_snapshot,
            runtime.group_snapshot.get("played_cards", runtime.played_cards))
        if runtime.initial_power <= total:
            return false
    if condition.has("capture_card_effective_above_base"):
        var cards: Array = runtime.captures.get(
            str(condition["capture_card_effective_above_base"]), [])
        if cards.is_empty():
            return false
        var card = cards[0]
        var base := int(runtime.group_snapshot.get("facts_by_id", {}).get(
            str(card.id), {}).get("base_qi_at_freeze", card.current_base_qi_value()))
        if HandGroupSnapshotScript.current_effective_qi(
                runtime.group_snapshot, card, runtime.actor) <= base:
            return false
    if condition.has("actor_hand_less_than_target"):
        if runtime.actor == null or runtime.target == null \
                or runtime.actor.hand.size() >= runtime.target.hand.size():
            return false
    if condition.has("actor_defense_equals"):
        if runtime.actor == null \
                or int(runtime.actor.defense) != int(condition["actor_defense_equals"]):
            return false
    return true

func _capture_cards(runtime, spec: Dictionary) -> Array:
    return runtime.captures.get(str(spec.get("capture", "")), [])

func _card_is_attribute(card, attribute: String, runtime = null) -> bool:
    if card is Dictionary:
        return card.get("attributes", []).has(attribute)
    if runtime != null and runtime.card_identity_policy != null \
            and runtime.card_identity_policy.has_method("resolve"):
        var result: Dictionary = runtime.card_identity_policy.resolve(card, {
            "owner": runtime.actor, "actor": runtime.actor, "target": runtime.target,
        })
        if result.get("success", false):
            return bool(result["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func noncontributing_qi_total(context) -> int:
    var runtime = EffectContextScript.coerce(context)
    var contributing: Array = runtime.hand_result.get("contributing", [])
    var total := 0
    for card in runtime.played_cards:
        if not contributing.has(card):
            total += int(card.qi_value)
    return maxi(0, total)
