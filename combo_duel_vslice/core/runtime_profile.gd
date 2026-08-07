class_name RuntimeProfile
extends RefCounted

enum LaunchMode {
    PRODUCTION,
    DEVELOPMENT,
    TEST,
}

const MODE_NAMES := {
    LaunchMode.PRODUCTION: "production",
    LaunchMode.DEVELOPMENT: "development",
    LaunchMode.TEST: "test",
}
const DEBUG_RESOURCE_PATHS := [
    "res://data/vertical_slice_sequences.json",
    "res://data/scripted_battle.json",
]
const DEBUG_RESOURCE_MARKERS := [
    "vertical_slice",
    "scripted_battle",
    "mock_ai_provider",
]
const PRODUCTION_CONTENT_PATHS := {
    "inner_skills": "res://config/production_inner_skills.json",
    "node_content": "res://data/production_node_content.json",
    "scripted_battle": "res://data/production_enemy_entry.json",
    "sequences": "res://data/production_sequences.json",
}
const TEST_SEED := 2308

var launch_mode: LaunchMode = LaunchMode.PRODUCTION

func _init(mode: LaunchMode = LaunchMode.PRODUCTION) -> void:
    launch_mode = mode

static func production():
    return RuntimeProfile.new(LaunchMode.PRODUCTION)

static func development():
    return RuntimeProfile.new(LaunchMode.DEVELOPMENT)

static func test():
    return RuntimeProfile.new(LaunchMode.TEST)

static func current():
    return from_user_arguments(OS.get_cmdline_user_args())

static func from_user_arguments(arguments: PackedStringArray):
    var requested := "production"
    var expect_value := false
    for argument_value in arguments:
        var argument := str(argument_value)
        if expect_value:
            requested = argument
            expect_value = false
        elif argument in ["--launch-mode", "--mode"]:
            expect_value = true
        elif argument.begins_with("--launch-mode="):
            requested = argument.trim_prefix("--launch-mode=")
        elif argument.begins_with("--mode="):
            requested = argument.trim_prefix("--mode=")
    return from_name(requested)

static func from_name(value: String):
    match value.strip_edges().to_lower():
        "development", "dev":
            return development()
        "test":
            return test()
        _:
            return production()

func mode_name() -> String:
    return str(MODE_NAMES.get(launch_mode, "production"))

func is_production() -> bool:
    return launch_mode == LaunchMode.PRODUCTION

func is_development() -> bool:
    return launch_mode == LaunchMode.DEVELOPMENT

func is_test() -> bool:
    return launch_mode == LaunchMode.TEST

func allows_debug_content() -> bool:
    return not is_production()

func allows_debug_menu() -> bool:
    return not is_production()

func allows_fast_entry() -> bool:
    return not is_production()

func uses_fixed_seed() -> bool:
    return is_test()

func default_seed(requested_seed: int = TEST_SEED) -> int:
    return TEST_SEED if uses_fixed_seed() else requested_seed

func uses_fixed_card_order() -> bool:
    return is_test()

func enemy_entry_kind() -> String:
    return "formal" if is_production() else "scripted"

func ai_provider_kind() -> String:
    return "mock" if is_test() else "remote"

func content_path_overrides() -> Dictionary:
    return PRODUCTION_CONTENT_PATHS.duplicate(true) if is_production() else {}

func allows_resource_path(path: String) -> bool:
    if allows_debug_content():
        return true
    if DEBUG_RESOURCE_PATHS.has(path):
        return false
    var normalized := path.to_lower()
    for marker in DEBUG_RESOURCE_MARKERS:
        if marker in normalized:
            return false
    return true

func validate_content_paths(paths: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    if not is_production():
        return errors
    for content_key in paths:
        var path := str(paths[content_key])
        if not allows_resource_path(path):
            errors.append(
                "runtime_profile.production: %s 禁止引用调试资源 %s" % [
                    str(content_key), path])
    return errors

func battle_defaults() -> Dictionary:
    return {
        "entry_kind": enemy_entry_kind(),
        "fixed_card_order": uses_fixed_card_order(),
    }
