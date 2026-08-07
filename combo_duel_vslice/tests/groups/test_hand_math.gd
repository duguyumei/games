extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("hand-math", [
        "_test_standard_deck",
        "_test_pool_structure_and_turn_draw_rules",
        "_test_active_hand_types_and_same_attribute_rules",
        "_test_power_calculation",
        "_test_damage_resolver_rules_and_facade",
    ])
