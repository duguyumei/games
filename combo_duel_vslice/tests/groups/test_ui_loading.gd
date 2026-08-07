extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("ui-loading", [
        "_test_map_practice_and_battle_scene_integration",
        "_test_front_menu_and_starter_build_flow",
    ])
