extends "res://tests/support/main_test_group.gd"


func _initialize() -> void:
    _run_group("remote-ai", [
        "_test_remote_ai_module_contract",
        "_test_chat_completions_provider_contract",
        "_test_ai_settings_and_conversation_disk_contract",
        "_test_remote_ai_action_window_session_gate",
    ])
