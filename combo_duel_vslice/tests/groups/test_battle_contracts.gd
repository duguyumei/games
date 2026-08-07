extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("battle-contracts", [
        "_test_card_zone_service_contract",
        "_test_battle_flow_coordinator_contract",
        "_test_battle_timing_system_contract_and_integration",
        "_test_status_system_contract",
        "_test_action_controller_boundaries_and_strategy",
        "_test_structured_game_log_channels",
        "_test_action_preview_service_matches_engine_facade",
        "_test_action_resolver_boundary_and_queue_rebind",
        "_test_battle_session_commands_snapshots_and_events",
        "_test_snapshot_boundaries_are_typed",
    ])
