extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("run-map", [
        "_test_run_state_node_and_practice_gate",
        "_test_run_service_boundaries_and_progress_snapshot",
        "_test_run_session_commands_snapshots_events_and_logs",
        "_test_inner_skill_loadout_and_forgetting",
        "_test_experience_interest_node_settlement",
        "_test_s2f2f1_formal_pills_and_transactions",
        "_test_s2f2f2_formal_curios_and_protocols",
        "_test_s2f2f3_practice_shop_packs_items_and_migration",
        "_test_boss_chest_flow",
        "_test_layered_life_progression_and_battle_persistence",
        "_test_run_state_battle_growth_persistence",
    ])
