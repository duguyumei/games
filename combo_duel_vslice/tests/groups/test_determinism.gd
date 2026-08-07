extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("determinism", [
        "_test_map_generation_is_deterministic_and_constrained",
        "_test_map_routes_reach_boss_without_crossing",
        "_test_node_dispatcher_is_data_driven_and_deterministic",
        "_test_scripted_enemy_is_deterministic_and_locked",
        "_test_enemy_ai_plan_is_deterministic_and_hidden",
    ])
