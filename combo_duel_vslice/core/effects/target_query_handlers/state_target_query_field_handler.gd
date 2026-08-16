class_name StateTargetQueryFieldHandler
extends RefCounted

const FIELD_DEFINITIONS := {
    "temporary": {"validation": "bool"},
    "has_any_reshape": {"validation": "bool"},
    "has_permanent_reshape": {"validation": "bool"},
    "has_active_permanent_reshape": {"validation": "bool"},
    "has_active_any_reshape": {"validation": "bool"},
    "has_any_anomaly": {"validation": "bool"},
    "anomaly_layers_at_least": {"validation": "anomaly_layers"},
    "anomaly": {"validation": "anomaly"},
    "anomalies": {"validation": "anomalies"},
    "anomaly_any": {"validation": "anomalies"},
    "reshape": {"validation": "reshape"},
    "can_apply_anomaly": {"validation": "can_apply_anomaly"},
}

func field_definitions() -> Dictionary:
    return FIELD_DEFINITIONS.duplicate(true)

func validate(
        _field: String, value, definition: Dictionary, registry,
        report_error: Callable, scope: String) -> bool:
    return registry.validate_value(value, definition, report_error, scope)

func matches(
        field: String, value, card, _facts, match_context: Dictionary,
        registry) -> bool:
    match field:
        "temporary":
            return bool(value) == bool(card.temporary_card)
        "has_any_anomaly":
            var snapshot: Dictionary = card.anomaly_snapshot()
            var actual := false
            for entries in snapshot.values():
                actual = actual or not entries.is_empty()
            return actual == bool(value)
        "has_any_reshape":
            var actual: bool = card.has_any_reshape_storage() \
                if card.has_method("has_any_reshape_storage") else (
                    not card.reshape_origin.is_empty()
                    or card.reshape_enhancement != ""
                    or card.reshape_imprint != ""
                    or not card.reshape_others.is_empty())
            return actual == bool(value)
        "has_permanent_reshape":
            var actual: bool = (
                not card.reshape_origin.is_empty()
                or card.reshape_enhancement != ""
                or card.reshape_imprint != ""
                or not card.reshape_others.is_empty())
            return actual == bool(value)
        "has_active_permanent_reshape":
            var actual: bool = not card.return_to_origin_active() and (
                not card.reshape_origin.is_empty()
                or card.reshape_enhancement != ""
                or card.reshape_imprint != ""
                or not card.reshape_others.is_empty())
            return actual == bool(value)
        "has_active_any_reshape":
            var actual: bool = not card.return_to_origin_active() and (
                not card.reshape_origin.is_empty()
                or card.reshape_enhancement != ""
                or card.reshape_imprint != ""
                or not card.reshape_others.is_empty()
                or str(card.temporary_reshapes.get("enhancement", "")) != ""
                or str(card.temporary_reshapes.get("attribute", "")) != ""
                or not card.temporary_reshapes.get("rank", {}).is_empty())
            return actual == bool(value)
        "anomaly_layers_at_least":
            return card.anomaly_layers(
                str(value.get("category", "buff")), str(value.get("id", ""))) \
                >= int(value.get("value", 1))
        "anomaly":
            return registry.matches_anomaly(card, value)
        "anomalies":
            for spec in value:
                if not registry.matches_anomaly(card, spec):
                    return false
            return true
        "anomaly_any":
            for spec in value:
                if registry.matches_anomaly(card, spec):
                    return true
            return false
        "reshape":
            return registry.matches_reshape(card, value)
        "can_apply_anomaly":
            var context = match_context.get("context")
            return context != null and context.ports != null \
                and context.ports.can_apply_card_anomaly(
                    card, str(value.get("category", "")),
                    str(value.get("id", "")),
                    bool(value.get("replace_state", false))).get(
                        "allowed", false)
    return false
