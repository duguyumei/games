extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-contracts", [
        "_test_technique_entities_are_individual_resources",
        "_test_structured_context_and_ports",
        "_test_action_preview_dto_contract",
        "_test_action_and_dispatch_dto_contracts",
        "_test_legacy_dictionary_compatibility",
        "_test_typed_context_random_is_deterministic",
        "_test_target_query_filters_and_order",
        "_test_choice_request_shortage_policies",
    ])
