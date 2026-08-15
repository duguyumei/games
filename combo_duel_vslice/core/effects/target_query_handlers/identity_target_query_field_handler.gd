class_name IdentityTargetQueryFieldHandler
extends RefCounted

const FIELD_DEFINITIONS := {
    "card_kind": {"validation": "enum", "values": ["any", "normal"]},
    "attributes": {"validation": "array_attribute"},
    "exclude_attributes": {"validation": "array_attribute"},
    "base_attributes": {"validation": "array_attribute"},
    "exclude_base_attributes": {"validation": "array_attribute"},
    "definition_ids": {"validation": "array_string"},
    "has_non_attribute_identity": {"validation": "attribute"},
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
    match field:
        "card_kind":
            return str(value) == "any" or (
                facts.is_card_kind("normal") if facts != null \
                else card.is_card_kind("normal"))
        "attributes":
            for attribute in value:
                if registry.card_has_attribute(
                        card, str(attribute), facts, match_context):
                    return true
            return false
        "exclude_attributes":
            for attribute in value:
                if registry.card_has_attribute(
                        card, str(attribute), facts, match_context):
                    return false
            return true
        "base_attributes":
            return value.has(str(card.attribute))
        "exclude_base_attributes":
            return not value.has(str(card.attribute))
        "definition_ids":
            var definition_id: String = card.current_definition_id() \
                if card.has_method("current_definition_id") \
                else str(card.definition_id)
            return value.has(definition_id)
        "has_non_attribute_identity":
            for attribute in ["wind", "forest", "fire", "mountain"]:
                if attribute != str(value) and registry.card_has_attribute(
                        card, attribute, facts, match_context):
                    return true
            return false
    return false
