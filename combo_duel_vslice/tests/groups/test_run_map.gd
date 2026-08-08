extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("run-map", [
        "_test_run_state_node_and_practice_gate",
        "_test_run_service_boundaries_and_progress_snapshot",
        "_test_run_session_commands_snapshots_events_and_logs",
        "_test_boss_chest_flow",
        "_test_layered_life_progression_and_battle_persistence",
        "_test_run_state_battle_growth_persistence",
    ])
