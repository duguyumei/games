extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("battle-rules", [
        "_test_sequence_progression_and_condition_failure",
        "_test_no_automatic_damage_or_draw",
        "_test_representative_damage_draw_discard",
        "_test_representative_defense_and_layers",
        "_test_representative_multi_attack",
        "_test_representative_special_technique",
        "_test_delayed_power_snapshot",
        "_test_visible_queue_left_to_right",
        "_test_inner_skill_equipment_and_extra_qi_defense",
        "_test_inner_skill_preview_and_enemy_plan",
        "_test_inner_skill_and_technique_left_to_right",
        "_test_consumable_shared_slots_and_generation_limit",
        "_test_battle_consumable_multi_effect_rollback",
        "_test_insight_growth_and_technique_acquisition",
        "_test_hierophant_bonus_enhancement_and_preview",
        "_test_aura_seeded_finish_and_preview",
        "_test_synchronized_defense_before_damage",
        "_test_synchronized_lethal_and_battle_results",
        "_test_data_driven_lethal_gu_needle",
        "_test_lethal_poison_and_gu_recycle_chain",
        "_test_scripted_poison_demo_reaches_recycle",
    ])
