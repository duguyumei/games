class_name SaveRepository
extends RefCounted

## 本局存档的原子文件存储、备份恢复与迁移入口。
##
## 仓库只处理持久化可靠性和版本兼容，不理解地图与成长规则；领域完整性由
## RunSaveData 校验，运行中会话的捕获与恢复由应用服务编排。

const RunSaveDataScript = preload("res://core/run_save_data.gd")
const MigrationRegistryScript = preload("res://core/run_save_migration_registry.gd")

const DEFAULT_PATH := "user://saves/run-v1.json"

var save_path: String
var backup_path: String
var migration_registry

func _init(path: String = DEFAULT_PATH, registry = null) -> void:
    save_path = path
    backup_path = path + ".bak"
    migration_registry = (
        registry if registry != null
        else MigrationRegistryScript.new(RunSaveDataScript.SCHEMA_VERSION))

func exists() -> bool:
    return FileAccess.file_exists(save_path) or FileAccess.file_exists(backup_path)

func save(run_save_data) -> Dictionary:
    var values: Dictionary = (
        run_save_data.to_dict()
        if run_save_data is Object and run_save_data.has_method("to_dict")
        else run_save_data.duplicate(true) if run_save_data is Dictionary else {})
    if values.is_empty():
        return {"success": false, "reason": "不能保存空本局数据"}
    if not _ensure_parent_directory(save_path):
        return {"success": false, "reason": "无法建立存档目录"}
    var encoded := encode(values)
    var temp_path := _temporary_path(save_path, "write")
    var write_result := _write_and_verify(temp_path, encoded)
    if not write_result.get("success", false):
        _remove_if_exists(temp_path)
        return write_result
    if FileAccess.file_exists(save_path):
        var current := _decode_file(save_path)
        if current.get("success", false):
            var backup_result := _copy_atomically(save_path, backup_path)
            if not backup_result.get("success", false):
                _remove_if_exists(temp_path)
                return {
                    "success": false,
                    "reason": "无法更新有效存档备份：%s" % backup_result.get("reason", ""),
                }
    var replace_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(save_path))
    if replace_error != OK:
        _remove_if_exists(temp_path)
        return {
            "success": false,
            "reason": "原子替换存档失败，上一份有效存档保持不变（错误 %d）" % replace_error,
        }
    return {"success": true, "path": save_path, "backup_path": backup_path}

func load() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return _load_backup("主存档不存在", "missing")
    var primary := _decode_file(save_path)
    if primary.get("success", false):
        primary["source"] = "primary"
        return primary
    if primary.get("kind", "") == "incompatible":
        return primary
    return _load_backup(
        str(primary.get("reason", "主存档损坏")),
        str(primary.get("kind", "corrupt")))

func encode(values: Dictionary) -> String:
    var payload_json := JSON.stringify(values)
    return JSON.stringify({
        "format": RunSaveDataScript.SAVE_FORMAT,
        "schema_version": int(values.get("schema_version", 0)),
        "content_version": int(values.get("content_version", 0)),
        "payload_sha256": payload_json.sha256_text(),
        "payload_json": payload_json,
    })

func _decode_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"success": false, "kind": "missing", "reason": "存档文件不存在"}
    return _decode(FileAccess.get_file_as_string(path))

func _decode(encoded: String) -> Dictionary:
    var parser := JSON.new()
    var parse_error := parser.parse(encoded)
    if parse_error != OK or not parser.data is Dictionary:
        return {"success": false, "kind": "corrupt", "reason": "存档 JSON 损坏"}
    var envelope: Dictionary = parser.data
    if str(envelope.get("format", "")) != RunSaveDataScript.SAVE_FORMAT:
        return {"success": false, "kind": "corrupt", "reason": "存档格式标识无效"}
    var payload_json := str(envelope.get("payload_json", ""))
    var expected_hash := str(envelope.get("payload_sha256", ""))
    if expected_hash == "" or payload_json.sha256_text() != expected_hash:
        return {"success": false, "kind": "corrupt", "reason": "存档校验和不匹配"}
    var payload = JSON.parse_string(payload_json)
    if not payload is Dictionary:
        return {"success": false, "kind": "corrupt", "reason": "存档 payload 损坏"}
    var envelope_schema := int(envelope.get("schema_version", 0))
    var envelope_content := int(envelope.get("content_version", 0))
    if envelope_schema != int(payload.get("schema_version", 0)) \
            or envelope_content != int(payload.get("content_version", 0)):
        return {"success": false, "kind": "corrupt", "reason": "存档版本元数据不一致"}
    if envelope_schema > migration_registry.current_schema_version:
        return {
            "success": false,
            "kind": "incompatible",
            "reason": "未知 schema_version %d，当前仅支持至 %d" % [
                envelope_schema, migration_registry.current_schema_version],
        }
    var migration: Dictionary = migration_registry.migrate(payload)
    if not migration.get("success", false):
        migration["kind"] = "incompatible"
        return migration
    return {
        "success": true,
        "data": RunSaveDataScript.new(migration["data"]),
        "migrations": migration.get("migrations", []).duplicate(),
        "source_schema_version": migration.get("source_schema_version", envelope_schema),
    }

func _load_backup(primary_reason: String, primary_kind: String) -> Dictionary:
    var backup := _decode_file(backup_path)
    if not backup.get("success", false):
        var backup_kind := str(backup.get("kind", "corrupt"))
        var failure_kind: String = (
            "incompatible"
            if backup_kind == "incompatible"
            else (
                "missing"
                if primary_kind == "missing" and backup_kind == "missing"
                else "corrupt"))
        return {
            "success": false,
            "kind": failure_kind,
            "reason": "%s；备份恢复失败：%s" % [primary_reason, backup.get("reason", "未知错误")],
        }
    var restored := _copy_atomically(backup_path, save_path)
    backup["source"] = "backup"
    backup["recovery_restored_primary"] = restored.get("success", false)
    if not restored.get("success", false):
        backup["recovery_warning"] = restored.get("reason", "无法恢复主存档")
    return backup

func _copy_atomically(source: String, target: String) -> Dictionary:
    var temp_path := _temporary_path(target, "copy")
    var copy_error := DirAccess.copy_absolute(
        ProjectSettings.globalize_path(source),
        ProjectSettings.globalize_path(temp_path))
    if copy_error != OK:
        return {"success": false, "reason": "复制失败（错误 %d）" % copy_error}
    var verification := _decode_file(temp_path)
    if not verification.get("success", false):
        _remove_if_exists(temp_path)
        return {"success": false, "reason": "复制结果校验失败"}
    var replace_error := DirAccess.rename_absolute(
        ProjectSettings.globalize_path(temp_path),
        ProjectSettings.globalize_path(target))
    if replace_error != OK:
        _remove_if_exists(temp_path)
        return {"success": false, "reason": "替换失败（错误 %d）" % replace_error}
    return {"success": true}

func _write_and_verify(path: String, encoded: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"success": false, "reason": "无法写入存档临时文件"}
    file.store_string(encoded)
    file.flush()
    file = null
    var decoded := _decode_file(path)
    if not decoded.get("success", false):
        return {"success": false, "reason": "临时存档回读校验失败：%s" % decoded.get("reason", "")}
    return {"success": true}

func _ensure_parent_directory(path: String) -> bool:
    var parent := path.get_base_dir()
    if parent == "":
        return true
    var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent))
    return error in [OK, ERR_ALREADY_EXISTS]

func _temporary_path(target: String, purpose: String) -> String:
    return "%s.%s-%d-%d.tmp" % [
        target,
        purpose,
        Time.get_unix_time_from_system(),
        Time.get_ticks_msec(),
    ]

func _remove_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
