class_name AiDecisionTraceStore
extends RefCounted

const DEFAULT_DIRECTORY := "user://ai/traces"
const REDACTED := "[REDACTED]"
const SECRET_KEYS := [
    "api_key", "apikey", "authorization", "proxy-authorization",
    "x-api-key", "extra_headers",
]

var last_error: String = ""

func path_for_battle(battle_id: String, directory: String = DEFAULT_DIRECTORY) -> String:
    var safe_id := _safe_file_stem(battle_id)
    if safe_id == "":
        safe_id = "unknown-battle"
    var base := "%s/%s" % [directory.rstrip("/"), safe_id]
    var path := "%s.json" % base
    var serial := 1
    while FileAccess.file_exists(path):
        path = "%s-%03d.json" % [base, serial]
        serial += 1
    return path

func save(path: String, trace) -> bool:
    var values: Dictionary = trace.snapshot() if trace is Object \
        and trace.has_method("snapshot") else trace.duplicate(true) \
        if trace is Dictionary else {}
    var error := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(path.get_base_dir()))
    if error not in [OK, ERR_ALREADY_EXISTS]:
        last_error = "AI 私有轨迹目录无法创建（错误 %d）" % error
        return false
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        last_error = "AI 私有轨迹无法写入：%s" % path
        return false
    file.store_string(JSON.stringify(_sanitize(values), "  "))
    last_error = ""
    return true

func load(path: String) -> Dictionary:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) \
        if FileAccess.file_exists(path) else null
    return parsed if parsed is Dictionary else {}

func _sanitize(value):
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value:
            result[key] = REDACTED if SECRET_KEYS.has(str(key).to_lower()) \
                else _sanitize(value[key])
        return result
    if value is Array:
        return value.map(func(item): return _sanitize(item))
    return value

func _safe_file_stem(value: String) -> String:
    var result := ""
    var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    for character in value:
        result += character if allowed.contains(character) else "_"
    return result.left(120)

