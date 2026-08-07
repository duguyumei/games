extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("content-contracts", [
        "_test_content_catalog_and_validator",
        "_test_starter_build_assembly_and_composition_root",
        "_test_node_reward_service_contract",
        "_test_effect_handler_registry_contract",
        "_test_effect_extension_entry_contract",
    ])
