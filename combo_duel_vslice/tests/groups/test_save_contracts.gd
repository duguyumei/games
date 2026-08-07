extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("save-contracts", [
        "_test_qi_instance_state_contract",
        "_test_run_deck_contract",
        "_test_battle_consumable_reshape_persists_via_run_deck",
    ])
