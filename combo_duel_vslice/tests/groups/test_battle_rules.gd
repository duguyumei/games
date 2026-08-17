extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("battle-rules", [
        "_test_no_automatic_damage_or_draw",
        "_test_representative_damage_draw_discard",
        "_test_multi_damage_and_consecutive_chase",
        "_test_visible_queue_left_to_right",
        "_test_inner_skill_equipment_and_extra_qi_defense",
        "_test_inner_skill_preview_and_enemy_plan",
        "_test_consumable_shared_slots_and_generation_limit",
        "_test_unified_run_and_battle_consumable_order_and_records",
        "_test_battle_unique_consumable_and_query_purity",
        "_test_battle_consumable_multi_effect_rollback",
        "_test_zengyuan_pill_enhancement_and_preview",
        "_test_simple_reshape_behaviors",
        "_test_synchronized_defense_before_damage",
        "_test_synchronized_lethal_and_battle_results",
    ])
