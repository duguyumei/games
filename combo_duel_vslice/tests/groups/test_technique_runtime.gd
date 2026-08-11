extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-runtime", [
        "_test_empty_and_failed_techniques_leave_momentum_untouched",
        "_test_same_hand_momentum_is_used_and_retained",
        "_test_changed_hand_uses_old_momentum_then_keeps_new_gain",
        "_test_retrigger_reuses_frozen_snapshot",
        "_test_delayed_effect_reuses_frozen_snapshot",
        "_test_reflection_override_sources_and_recursion_guard",
        "_test_synchronized_reflection_matches_normal_damage",
    ])
