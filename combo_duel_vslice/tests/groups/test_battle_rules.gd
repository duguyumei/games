extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("battle-rules", [
        "_test_no_automatic_damage_or_draw",
        "_test_visible_queue_left_to_right",
        "_test_inner_skill_equipment_and_extra_qi_defense",
        "_test_inner_skill_preview_and_enemy_plan",
        "_test_consumable_shared_slots_and_generation_limit",
        "_test_battle_consumable_multi_effect_rollback",
        "_test_zengyuan_pill_enhancement_and_preview",
        "_test_simple_reshape_behaviors",
        "_test_synchronized_defense_before_damage",
        "_test_synchronized_lethal_and_battle_results",
    ])
