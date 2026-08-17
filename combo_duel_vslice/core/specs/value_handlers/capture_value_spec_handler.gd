class_name CaptureValueSpecHandler
extends RefCounted

const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

const REGISTERED_KINDS := [
    "capture_count", "capture_qi_sum", "capture_attribute_qi_sum",
    "capture_attribute_count", "capture_non_attribute_count",
    "capture_base_qi_sum", "capture_card_base_qi_sum",
    "capture_current_effective_qi", "capture_effective_qi_sum",
    "capture_effective_qi_max", "capture_r_sum", "capture_r_max",
    "capture_anomaly_layers_sum", "capture_anomaly_layers_max",
    "capture_result_count", "capture_actual_life_loss",
    "capture_field_sum", "capture_field_max", "capture_field_first",
    "capture_field_distinct_count", "event_field",
]

func kind_ids() -> Array[String]:
    return REGISTERED_KINDS.duplicate()

func validate(kind: String, spec: Dictionary, registry, report_error: Callable, scope: String) -> bool:
    if kind == "event_field":
        var event_valid := true
        for field in ["capture", "field"]:
            if spec.has(field) and not spec[field] is String:
                report_error.call(scope + "." + field, "必须是字符串")
                event_valid = false
        return event_valid
    var valid: bool = registry.validate_capture(
        spec, report_error, scope,
        kind in ["capture_attribute_qi_sum", "capture_attribute_count", "capture_non_attribute_count"])
    if spec.has("side") and str(spec["side"]) not in [
            "actor", "target", "owner", "opponent"]:
        report_error.call(scope + ".side", "必须为 actor、target、owner 或 opponent")
        valid = false
    if kind in ["capture_anomaly_layers_sum", "capture_anomaly_layers_max"] \
            and spec.has("category") \
            and str(spec["category"]) not in registry.anomaly_category_ids():
        report_error.call(scope + ".category", "引用未知异状类别")
        valid = false
    if kind in ["capture_field_sum", "capture_field_max", "capture_field_first",
            "capture_field_distinct_count"] \
            and spec.has("field") and not spec["field"] is String:
        report_error.call(scope + ".field", "必须是字符串")
        valid = false
    return valid

func resolve(kind: String, spec: Dictionary, runtime, resolver, _registry) -> int:
    match kind:
        "capture_count":
            return resolver.capture_cards(runtime, spec).size()
        "capture_qi_sum":
            var total := 0
            for card in resolver.capture_cards(runtime, spec):
                total += int(card.get("qi_value", 0) if card is Dictionary else card.qi_value)
            return total
        "capture_base_qi_sum":
            return HandGroupSnapshotScript.base_qi_sum(
                runtime.group_snapshot, resolver.capture_cards(runtime, spec))
        "capture_card_base_qi_sum":
            var total := 0
            for card in resolver.capture_cards(runtime, spec):
                if card is Dictionary:
                    total += int(card.get("card_base_qi", card.get("qi_value", 0)))
                    continue
                total += int(runtime.group_snapshot.get("facts_by_id", {}).get(
                    str(card.id), {}).get("card_base_qi_at_freeze", card.qi_value))
            return total
        "capture_current_effective_qi":
            var cards: Array = resolver.capture_cards(runtime, spec)
            if cards.is_empty():
                return 0
            return HandGroupSnapshotScript.current_effective_qi(
                runtime.group_snapshot, cards[0], runtime.actor)
        "capture_effective_qi_sum", "capture_effective_qi_max":
            var values: Array[int] = []
            var owner = resolver.side(runtime, str(spec.get("side", "actor")))
            for card in resolver.capture_cards(runtime, spec):
                values.append(
                    HandGroupSnapshotScript.confirmed_or_current_effective_qi(
                        runtime.group_snapshot, card, owner))
            if kind == "capture_effective_qi_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "capture_r_sum", "capture_r_max":
            var values: Array[int] = []
            var owner = resolver.side(runtime, str(spec.get("side", "actor")))
            for card in resolver.capture_cards(runtime, spec):
                values.append(maxi(0,
                    HandGroupSnapshotScript.confirmed_or_current_effective_qi(
                        runtime.group_snapshot, card, owner) \
                    - HandGroupSnapshotScript.frozen_base_qi(
                        runtime.group_snapshot, card)))
            if kind == "capture_r_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "capture_anomaly_layers_sum", "capture_anomaly_layers_max":
            var values: Array[int] = []
            for card in resolver.capture_cards(runtime, spec):
                values.append(card.anomaly_layers(
                    str(spec.get("category", "buff")), str(spec.get("anomaly", ""))))
            if kind == "capture_anomaly_layers_max":
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
        "event_field":
            var events: Array = runtime.captures.get(
                str(spec.get("capture", "event")), [])
            return int(events[0].get(str(spec.get("field", "amount")), 0)) \
                if not events.is_empty() and events[0] is Dictionary else 0
        "capture_field_distinct_count":
            var distinct: Dictionary = {}
            var field := str(spec.get("field", "amount"))
            for entry in runtime.captures.get(str(spec.get("capture", "")), []):
                if entry is Dictionary:
                    distinct[str(entry.get(field, ""))] = true
            return distinct.size()
        "capture_field_sum", "capture_field_max", "capture_field_first":
            var values: Array[int] = []
            var field := str(spec.get("field", "amount"))
            for entry in runtime.captures.get(str(spec.get("capture", "")), []):
                if entry is Dictionary:
                    values.append(int(entry.get(field, 0)))
            if kind == "capture_field_first":
                return values[0] if not values.is_empty() else 0
            if kind == "capture_field_max":
                return values.max() if not values.is_empty() else 0
            var total := 0
            for value in values:
                total += value
            return total
        "capture_attribute_qi_sum":
            var total := 0
            for card in resolver.capture_cards(runtime, spec):
                if resolver.card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    total += int(card.get("qi_value", 0) if card is Dictionary else card.qi_value)
            return total
        "capture_attribute_count", "capture_non_attribute_count":
            var count := 0
            for card in resolver.capture_cards(runtime, spec):
                var is_attribute: bool = resolver.card_is_attribute(
                    card, str(spec.get("attribute", "")), runtime)
                if (kind == "capture_attribute_count" and is_attribute) \
                        or (kind == "capture_non_attribute_count" and not is_attribute):
                    count += 1
            return count
    return 0
