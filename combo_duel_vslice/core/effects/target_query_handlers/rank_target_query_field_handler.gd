class_name RankTargetQueryFieldHandler
extends RefCounted

const FIELD_DEFINITIONS := {
    "rank_names": {"validation": "array_string"},
    "rank_orders": {"validation": "array_integer"},
    "exclude_rank_orders": {"validation": "array_integer"},
    "duplicate_rank": {"validation": "bool"},
    "effective_above_base": {"validation": "bool"},
    "effective_qi_at_most": {"validation": "integer_or_value_spec"},
    "effective_qi_at_least": {"validation": "integer_or_value_spec"},
}

func field_definitions() -> Dictionary:
    return FIELD_DEFINITIONS.duplicate(true)

func validate(
        _field: String, value, definition: Dictionary, registry,
        report_error: Callable, scope: String) -> bool:
    return registry.validate_value(value, definition, report_error, scope)

func matches(
        field: String, value, card, facts, match_context: Dictionary,
        registry) -> bool:
    var rank_name: String = str(facts.rank_name) if facts != null \
        else card.current_rank_name() if card.has_method("current_rank_name") \
        else str(card.rank_name)
    var rank_order: int = int(facts.rank_order) if facts != null \
        else card.current_rank_order() if card.has_method("current_rank_order") \
        else int(card.rank_order)
    match field:
        "rank_names": return value.has(rank_name)
        "rank_orders": return value.has(rank_order)
        "exclude_rank_orders": return not value.has(rank_order)
        "duplicate_rank": return true
        "effective_above_base":
            var effective: int = registry.current_effective_qi(card, match_context)
            var base: int = int(card.current_base_qi_value()) \
                if card.has_method("current_base_qi_value") else int(card.qi_value)
            return (effective > base) == bool(value)
        "effective_qi_at_most":
            return registry.current_effective_qi(card, match_context) <= int(value) \
                if not value is Dictionary else false
        "effective_qi_at_least":
            return registry.current_effective_qi(card, match_context) >= int(value) \
                if not value is Dictionary else false
    return false

func apply_post_filter(
        field: String, value, cards: Array, _match_context: Dictionary,
        _registry) -> Array:
    if field != "duplicate_rank" or not bool(value):
        return cards
    var rank_counts: Dictionary = {}
    for card in cards:
        var rank_order := int(card.current_rank_order()) \
            if card.has_method("current_rank_order") else int(card.rank_order)
        rank_counts[rank_order] = int(rank_counts.get(rank_order, 0)) + 1
    return cards.filter(func(card):
        var rank_order := int(card.current_rank_order()) \
            if card.has_method("current_rank_order") else int(card.rank_order)
        return int(rank_counts.get(rank_order, 0)) > 1)
