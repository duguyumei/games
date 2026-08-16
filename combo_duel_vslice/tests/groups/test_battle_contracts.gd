extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("battle-contracts", [
        "_test_card_zone_service_contract",
        "_test_battle_flow_coordinator_contract",
        "_test_battle_timing_system_contract_and_integration",
        "_test_defense_retention_policy_and_round_decay",
        "_test_passive_runtime_capacity_suppression_invocations_and_items",
        "_test_battle_passive_lifecycle_bridge_and_temporary_counters",
        "_test_battle_fine_grained_events_and_int_queries",
        "_test_battle_card_policy_ports",
        "_test_technique_and_cooperation_permission_wiring",
        "_test_unified_passive_effect_execution",
        "_test_effect_source_neutrality_runtime_paths",
        "_test_awakening_battle_runtime",
        "_test_f2d2_formal_enhancement_runtime",
        "_test_f2d2_opportunity_freeze_and_progress_sync",
        "_test_f2e1_formal_imprint_runtime_and_persistence",
        "_test_status_behavior_registry_contract",
        "_test_status_system_contract",
        "_test_action_controller_boundaries_and_strategy",
        "_test_structured_game_log_channels",
        "_test_action_preview_service_matches_engine_facade",
        "_test_battle_session_commands_snapshots_and_events",
        "_test_formal_enemy_pool_battle_setup",
        "_test_snapshot_boundaries_are_typed",
    ])
