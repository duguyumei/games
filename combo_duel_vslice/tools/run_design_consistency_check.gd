extends SceneTree

## 设计一致性检查入口。
##
## 权威源在本工程之外（godot/docs/design-current/），因此按工程目录向上定位，
## 不使用 res:// 路径。设计文档缺失时视为失败，不静默跳过。

const ValidatorScript = preload("res://tools/design_consistency_validator.gd")

func _initialize() -> void:
    var project_dir := ProjectSettings.globalize_path("res://")
    var repository_root := project_dir.path_join("..").simplify_path()
    var pool_dir := repository_root.path_join("godot/docs/design-current/martial-arts")
    var technique_dir := ProjectSettings.globalize_path("res://data/techniques")

    if not DirAccess.dir_exists_absolute(pool_dir):
        push_error("DESIGN CHECK ERROR: 找不到权威功法池文档目录：%s" % pool_dir)
        quit(2)
        return

    var validator = ValidatorScript.new()
    var report: Dictionary = validator.validate(pool_dir, technique_dir)
    var errors: Array = report["errors"]
    var warnings: Array = report["warnings"]

    for warning in warnings:
        print("DESIGN WARNING: %s" % warning)
    for error in errors:
        push_error("DESIGN ERROR: %s" % error)

    print("DESIGN CHECK: 权威活跃 %d 门，数据接入 %d 门，待接入 %d 门，错误 %d 条" % [
        report["authoritative_count"],
        report["runtime_count"],
        (report["not_integrated"] as Array).size(),
        errors.size(),
    ])
    if errors.is_empty():
        print("DESIGN CHECK PASS")
    quit(1 if not errors.is_empty() else 0)
