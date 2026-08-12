extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("ui-loading", [
        "_test_run_build_query_dto_and_empty_formal_pools",
        "_test_run_build_consumable_target_selection_and_cancel",
        "_test_run_build_prepared_preview_and_enum_protocol",
        "_test_run_build_technique_removals_and_independent_drafts",
        "_test_s2f6a_repeated_technique_slot_index_operations",
        "_test_run_build_inner_skill_draft_and_forgetting",
        "_test_run_build_read_only_layout_and_ui_domain_boundary",
        "_test_map_practice_and_battle_scene_integration",
        "_test_battle_scene_prefers_injected_session_and_keeps_standalone_fallback",
        "_test_front_menu_and_starter_build_flow",
    ])
