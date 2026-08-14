extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-contracts", [
        "_test_empty_repository_and_production_data",
        "_test_power_snapshot_formula_and_initial_power_reader",
        "_test_all_insights_grow_empty_slots",
        "_test_defense_decay_return_records",
        "_test_action_resolution_results_and_no_life_loss_disruption",
        "_test_s2f6a_basic_techniques_and_loadout_limits",
    ])
