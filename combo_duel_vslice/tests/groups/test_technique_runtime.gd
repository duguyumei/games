extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-runtime", [
        "_test_wind_common_card_flow_rules",
        "_test_wind_high_technique_batch",
        "_test_wind_cooperation_group_resolution",
        "_test_wind_echo_and_five_card_power",
        "_test_wind_four_kind_card_flow_and_persistent_trigger",
        "_test_structured_results_and_pending_boundary",
        "_test_resumable_selection_does_not_replay_completed_effects",
        "_test_combat_action_pauses_and_resumes_transactionally",
    ])
