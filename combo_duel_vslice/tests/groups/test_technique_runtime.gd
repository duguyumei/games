extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("technique-runtime", [
        "_test_empty_and_failed_techniques_leave_momentum_untouched",
        "_test_unchanged_momentum_is_used_then_cleared",
        "_test_changed_momentum_is_used_then_preserved",
        "_test_retrigger_reuses_frozen_snapshot",
        "_test_delayed_effect_reuses_frozen_snapshot",
        "_test_stable_slots_temporary_insert_and_call_orders",
        "_test_source_markers_life_and_defense_ports",
        "_test_manual_advance_only_suppresses_effects",
        "_test_automatic_trigger_uses_special_p0_and_nested_order",
        "_test_equipped_max_life_marker_and_snapshot_migration",
        "_test_poison_damage_modifiers_apply_per_segment",
        "_test_normal_automatic_technique_manual_effects",
        "_test_automatic_multi_threshold_and_event_idempotency",
        "_test_automatic_opponent_event_multi_marker_batches_and_source_kind",
        "_test_nested_invocation_recursion_and_options",
        "_test_invocation_rejection_does_not_move_slot",
        "_test_invocation_choice_resume_freezes_randomness",
        "_test_manual_automatic_invoked_resolution_consistency",
        "_test_battle_session_invocation_choice_resume",
        "_test_source_marker_response_and_private_projections",
        "_test_temporary_slots_do_not_duplicate_run_max_life",
        "_test_reflection_override_sources_and_recursion_guard",
        "_test_synchronized_reflection_matches_normal_damage",
        "_test_unblockable_damage_still_absorbs_and_reflects",
        "_test_permanent_loadout_capacity_insight_and_runtime_compatibility",
    ])
