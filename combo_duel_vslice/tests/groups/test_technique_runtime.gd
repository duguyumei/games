extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-runtime", [
        "_test_empty_and_failed_techniques_leave_momentum_untouched",
        "_test_unchanged_momentum_is_used_then_cleared",
        "_test_changed_momentum_is_used_then_preserved",
        "_test_retrigger_reuses_frozen_snapshot",
        "_test_delayed_effect_reuses_frozen_snapshot",
        "_test_reflection_override_sources_and_recursion_guard",
        "_test_synchronized_reflection_matches_normal_damage",
    ])
