class_name EffectValueResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")
const ValueSpecRegistryScript = preload("res://core/specs/value_spec_registry.gd")
const ConditionSpecRegistryScript = preload("res://core/specs/condition_spec_registry.gd")

var spec_registry = ValueSpecRegistryScript.new()
var condition_registry = ConditionSpecRegistryScript.new()

func resolve(spec, context) -> int:
    return spec_registry.resolve(spec, context, Callable(self, "_resolve_known"))

func _resolve_known(spec, context) -> int:
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
        "card_contribution":
            return int(runtime.group_snapshot.get("card_contribution", 0))
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
        "capture_card_base_qi_sum":
            var total := 0
            for card in _capture_cards(runtime, spec):
                if card is Dictionary:
                    total += int(card.get("card_base_qi", card.get("qi_value", 0)))
                    continue
                total += int(runtime.group_snapshot.get("facts_by_id", {}).get(
                    str(card.id), {}).get("card_base_qi_at_freeze", card.qi_value))
            return total
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
        "source_marker_value":
            var side = _side(runtime, str(spec.get("side", "actor")))
            if side == null or side.source_marker_store == null:
                return 0
            return side.source_marker_store.value(
                str(spec.get("source_kind", "technique")),
                str(spec.get("source_instance_key", runtime.slot_instance_id)),
                str(spec.get("marker_id", "")), str(spec.get("scope", "")))
        "source_marker_sum":
            var side = _side(runtime, str(spec.get("side", "actor")))
            if side == null or side.source_marker_store == null:
                return 0
            var filters: Dictionary = spec.get("filters", {}).duplicate(true)
            if spec.has("marker_id"):
                filters["marker_id"] = str(spec["marker_id"])
            if spec.has("scope"):
                filters["scope"] = str(spec["scope"])
            return side.source_marker_store.sum(filters)
        "equipped_source_marker_sum":
            return _equipped_source_marker_sum(
                _side(runtime, str(spec.get("side", "actor"))), spec)
        "consumed_marker_value":
            return runtime.consumed_marker_value
        "missing_life":
            return maxi(0, int(runtime.actor.max_life) - int(runtime.actor.life)) \
                if runtime.actor != null else 0
        "target_missing_life":
            return maxi(0, int(runtime.target.max_life) - int(runtime.target.life)) \
                if runtime.target != null else 0
        "max_life":
            return int(runtime.actor.max_life) if runtime.actor != null else 0
        "target_max_life":
            return int(runtime.target.max_life) if runtime.target != null else 0
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
        "extra_effective_qi_sum":
            var total := 0
            for card in runtime.group_snapshot.get("extra_cards", []):
                total += runtime.ports.current_effective_qi(runtime.actor, card)
            return total
        "action_same_qi_gain":
            return int(runtime.group_snapshot.get("action_same_qi_gain", 0))
        "action_same_qi_trigger_count":
            return int(runtime.group_snapshot.get(
                "action_same_qi_trigger_count", 0))
        "momentum_value":
            return int(runtime.actor.momentum_value) if runtime.actor != null else 0
        "base_attribute_count":
            var attributes: Dictionary = {}
            for card in runtime.group_snapshot.get("played_cards", runtime.played_cards):
                var facts: Dictionary = runtime.group_snapshot.get(
                    "facts_by_id", {}).get(str(card.id), {})
                attributes[str(facts.get(
                    "base_attribute_at_freeze",
                    card.current_attribute() if card.has_method("current_attribute") else card.attribute))] = true
            attributes.erase("")
            return attributes.size()
        "event_field":
            var events: Array = runtime.captures.get(
                str(spec.get("capture", "event")), [])
            return int(events[0].get(str(spec.get("field", "amount")), 0)) \
                if not events.is_empty() and events[0] is Dictionary else 0
        "active_temporary_reshape_base_qi_sum":
            var total := 0
            for card in runtime.group_snapshot.get("played_cards", runtime.played_cards):
                if _has_active_temporary_reshape(card):
                    total += int(card.current_base_qi_value())
            return total
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
        "occupied_meridian_count":
            var side = _side(runtime, str(spec.get("side", "actor")))
            return side.occupied_meridian_count() if side != null else 0
        "deck_count":
            var side = _side(runtime, str(spec.get("side", "actor")))
            return side.draw_pile.size() if side != null else 0
        "bomb_constituent_count":
            if runtime.actual_hand_id == "four_kind":
                return 4
            if runtime.actual_hand_id == "five_kind":
                return 5
            return 0
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

func _equipped_source_marker_sum(side, spec: Dictionary) -> int:
    if side == null or side.source_marker_store == null:
        return 0
    var equipped: Dictionary = {}
    for progression_value in side.hand_technique_progression.values():
        var progression: Dictionary = progression_value
        for technique_id_value in progression.get("sequence", []):
            equipped[str(technique_id_value)] = true
    for inner_skill_id in side.equipped_inner_skill_ids:
        equipped[str(inner_skill_id)] = true
    var total := 0
    var filters: Dictionary = spec.get("filters", {}).duplicate(true)
    if spec.has("marker_id"):
        filters["marker_id"] = str(spec["marker_id"])
    if spec.has("scope"):
        filters["scope"] = str(spec["scope"])
    for entry_value in side.source_marker_store.entries(filters):
        if equipped.has(str(entry_value.get("content_id", ""))):
            total += int(entry_value.get("value", 0))
    return total

func _side(runtime, side_id: String):
    return runtime.target if side_id == "target" else runtime.actor

func condition_met(condition: Dictionary, context) -> bool:
    return condition_registry.evaluate(
        condition, context, Callable(self, "resolve"))

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

func _has_active_temporary_reshape(card) -> bool:
    if card == null or card.return_to_origin_active():
        return false
    return str(card.temporary_reshapes.get("enhancement", "")) != "" \
        or str(card.temporary_reshapes.get("attribute", "")) != "" \
        or not card.temporary_reshapes.get("rank", {}).is_empty()

func noncontributing_qi_total(context) -> int:
    var runtime = EffectContextScript.coerce(context)
    var contributing: Array = runtime.hand_result.get("contributing", [])
    var total := 0
    for card in runtime.played_cards:
        if not contributing.has(card):
            total += int(card.qi_value)
    return maxi(0, total)
