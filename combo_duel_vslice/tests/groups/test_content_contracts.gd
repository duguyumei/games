extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("content-contracts", [
        "_test_card_reshape_behavior_registry",
        "_test_content_catalog_and_validator",
        "_test_passive_rule_registry_and_content_contract",
        "_test_enemy_pool_content_and_repository",
        "_test_starter_build_assembly_and_composition_root",
        "_test_node_reward_service_contract",
        "_test_run_effect_platform_contract",
        "_test_run_card_workshop_effects",
        "_test_awakening_origin_persistence_contract",
        "_test_effect_handler_registry_contract",
        "_test_effect_extension_entry_contract",
        "_test_consumable_effect_registry_contract",
        "_test_consumable_effect_validation_scope",
        "_test_run_consumable_zengyuan_pill",
        "_test_run_consumable_origin_and_save",
        "_test_run_consumable_invalid_targets",
        "_test_run_consumable_transaction_rollback",
        "_test_run_consumable_failed_use_keeps_randomness",
        "_test_run_consumable_slot_release_order",
        "_test_run_consumable_phase_gate",
        "_test_run_consumable_save_round_trip",
        "_test_consumable_no_central_op_branches",
    ])
