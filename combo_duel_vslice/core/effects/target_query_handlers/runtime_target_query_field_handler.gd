class_name RuntimeTargetQueryFieldHandler
extends RefCounted

const FIELD_DEFINITIONS := {
    "explicit_discard_allowed": {"validation": "bool"},
    "exclude_base_attributes_from_capture": {"validation": "capture_id"},
    "exclude_rank_orders_from_capture": {"validation": "capture_id"},
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
        "explicit_discard_allowed":
            if not bool(value):
                return true
            var context = match_context.get("context")
            var side = match_context.get("side")
            return context != null and context.ports != null and side != null \
                and context.ports.can_explicit_discard(
                    side, card).get("allowed", false)
        "exclude_base_attributes_from_capture":
            var base_attribute := str(card.attribute)
            for entry in registry.capture_entries(str(value), match_context):
                var excluded := str(entry.get("base_attribute", "")) \
                    if entry is Dictionary else str(entry.attribute)
                if excluded != "" and excluded == base_attribute:
                    return false
            return true
        "exclude_rank_orders_from_capture":
            var rank_order := int(card.current_rank_order()) \
                if card.has_method("current_rank_order") else int(card.rank_order)
            for entry in registry.capture_entries(str(value), match_context):
                var excluded := int(entry.get("rank_order", 0)) \
                    if entry is Dictionary else int(entry.current_rank_order())
                if excluded == rank_order:
                    return false
            return true
    return false
