class_name RunSaveApplicationService
extends RefCounted

## 本局存档用例的应用层门面。
##
## 这里编排捕获、校验、保存与恢复，不实现文件原子替换和版本迁移细节，
## 也不允许存储层直接修改运行中的 RunSession。

const RunSaveDataScript = preload("res://core/run_save_data.gd")
const SaveRepositoryScript = preload("res://core/save_repository.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")

var repository
var content_catalog

func _init(repository_override = null, content_catalog_override = null) -> void:
    repository = (
        repository_override
        if repository_override != null else SaveRepositoryScript.new())
    content_catalog = (
        content_catalog_override
        if content_catalog_override != null else ContentCatalogScript.new())
    if content_catalog_override == null:
        content_catalog.load_all()

func execute(command: Dictionary) -> Dictionary:
    match str(command.get("type", "")):
        "save_run":
            return save_run(command.get("run_session"))
        "load_run":
            return load_run()
        "has_run_save":
            return {"success": true, "exists": repository.exists()}
        _:
            return {"success": false, "reason": "未知存档命令"}

func save_run(run_session) -> Dictionary:
    if run_session == null:
        return {"success": false, "reason": "save_run 缺少 run_session"}
    var data = RunSaveDataScript.new().capture(run_session)
    var errors: Array[String] = data.validate(content_catalog)
    if not errors.is_empty():
        return {"success": false, "reason": "；".join(errors), "errors": errors}
    return repository.save(data)

func load_run() -> Dictionary:
    var loaded: Dictionary = repository.load()
    if not loaded.get("success", false):
        return loaded
    var data = loaded["data"]
    var restored: Dictionary = data.restore_session(content_catalog)
    if not restored.get("success", false):
        return restored
    restored["source"] = loaded.get("source", "primary")
    restored["migrations"] = loaded.get("migrations", []).duplicate()
    restored["recovery_restored_primary"] = loaded.get("recovery_restored_primary", false)
    return restored
