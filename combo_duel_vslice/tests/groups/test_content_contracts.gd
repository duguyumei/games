extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("content-contracts", [
        "_test_content_catalog_and_validator",
        "_test_enemy_pool_content_and_repository",
        "_test_production_formal_sequences_and_damage",
        "_test_production_enemy_pool_remote_ai_battle",
        "_test_formal_production_technique_behaviors",
        "_test_starter_build_assembly_and_composition_root",
        "_test_node_reward_service_contract",
        "_test_effect_handler_registry_contract",
        "_test_effect_extension_entry_contract",
    ])
