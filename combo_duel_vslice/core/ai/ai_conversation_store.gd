class_name AiConversationStore
extends RefCounted

## AI 对话审计记录的磁盘边界。
##
## 这里只负责编码、递归脱敏与文件读写，不决定何时压缩历史，也不参与
## Provider 请求生命周期；这些职责分别属于对话模型与决策网关。

const DEFAULT_DIRECTORY := "user://ai/conversations"
const REDACTED := "[REDACTED]"
const SECRET_KEYS := [
    "api_key",
    "apikey",
    "authorization",
    "proxy-authorization",
    "x-api-key",
]

func encode(snapshot) -> String:
    var values: Dictionary = (
        snapshot.to_dict()
        if snapshot is Object and snapshot.has_method("to_dict")
        else snapshot.duplicate(true) if snapshot is Dictionary else {})
    return JSON.stringify(_sanitize(values))

func decode(encoded: String) -> Dictionary:
    var parsed = JSON.parse_string(encoded)
    return parsed if parsed is Dictionary else {}

func save(path: String, snapshot) -> bool:
    if not _ensure_parent_directory(path):
        return false
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(encode(snapshot))
    return true

func load(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    return decode(FileAccess.get_file_as_string(path))

func path_for_battle(
        battle_id: String,
        directory: String = DEFAULT_DIRECTORY) -> String:
    var safe_id := _safe_file_stem(battle_id)
    if safe_id == "":
        safe_id = "unknown-battle"
    return "%s/%s.json" % [directory.rstrip("/"), safe_id]

func save_battle(
        snapshot,
        directory: String = DEFAULT_DIRECTORY) -> bool:
    var values: Dictionary = (
        snapshot.to_dict()
        if snapshot is Object and snapshot.has_method("to_dict")
        else snapshot.duplicate(true) if snapshot is Dictionary else {})
    var battle_id := str(values.get("battle_id", ""))
    if battle_id == "":
        return false
    return save(path_for_battle(battle_id, directory), values)

func load_battle(
        battle_id: String,
        directory: String = DEFAULT_DIRECTORY) -> Dictionary:
    return self.load(path_for_battle(battle_id, directory))

func _sanitize(value):
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value:
            var normalized := str(key).to_lower()
            result[key] = REDACTED if SECRET_KEYS.has(normalized) else _sanitize(value[key])
        return result
    if value is Array:
        var result: Array = []
        for item in value:
            result.append(_sanitize(item))
        return result
    return value

func _ensure_parent_directory(path: String) -> bool:
    var parent := path.get_base_dir()
    if parent == "":
        return true
    var error := DirAccess.make_dir_recursive_absolute(
        ProjectSettings.globalize_path(parent))
    return error in [OK, ERR_ALREADY_EXISTS]

func _safe_file_stem(value: String) -> String:
    var result := ""
    var allowed := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
    for character in value:
        result += character if allowed.contains(character) else "_"
    return result.left(120)
