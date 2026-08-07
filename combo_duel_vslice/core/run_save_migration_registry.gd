class_name RunSaveMigrationRegistry
extends RefCounted

var current_schema_version: int
var _steps: Dictionary = {}

func _init(current_version: int = 1) -> void:
    current_schema_version = maxi(1, current_version)

func register_migration(from_version: int, to_version: int, migrate: Callable) -> Dictionary:
    if from_version < 1 or to_version != from_version + 1:
        return {"success": false, "reason": "存档迁移必须逐版本注册"}
    if not migrate.is_valid():
        return {"success": false, "reason": "存档迁移 Callable 无效"}
    if _steps.has(from_version):
        return {"success": false, "reason": "存档版本 %d 的迁移已注册" % from_version}
    _steps[from_version] = {"to": to_version, "migrate": migrate}
    return {"success": true}

func migrate(values: Dictionary, target_version: int = -1) -> Dictionary:
    var target := current_schema_version if target_version < 0 else target_version
    var source := int(values.get("schema_version", 0))
    if source < 1:
        return {"success": false, "reason": "存档缺少有效 schema_version"}
    if source > target:
        return {
            "success": false,
            "reason": "存档 schema_version %d 高于当前支持版本 %d" % [source, target],
        }
    var migrated := values.duplicate(true)
    var applied: Array[String] = []
    var version := source
    while version < target:
        if not _steps.has(version):
            return {
                "success": false,
                "reason": "没有从 schema_version %d 开始的迁移" % version,
            }
        var step: Dictionary = _steps[version]
        var transformed = step["migrate"].call(migrated.duplicate(true))
        if not transformed is Dictionary:
            return {
                "success": false,
                "reason": "schema_version %d 迁移没有返回对象" % version,
            }
        migrated = transformed
        version = int(step["to"])
        migrated["schema_version"] = version
        applied.append("v%d->v%d" % [version - 1, version])
    return {
        "success": true,
        "data": migrated,
        "source_schema_version": source,
        "schema_version": target,
        "migrations": applied,
    }
