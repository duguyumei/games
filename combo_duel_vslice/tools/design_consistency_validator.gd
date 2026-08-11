class_name DesignConsistencyValidator
extends RefCounted

## 设计文档与运行数据的一致性校验器。
##
## 权威源是 godot/docs/design-current/，本工程数据必须与它一致。
## 本校验器不接受任何"代码里怎么写就算对"的推断：名单、池归属与废弃状态
## 全部从设计文档正文解析，数据文件只作为被检查对象。

## 池标题中文名 → techniques.json 使用的池代码。
const POOL_LABEL_TO_CODE := {
    "高牌池": "high",
    "对子池": "pair",
    "三条池": "three",
    "顺子池": "straight",
    "炸弹池": "bomb",
}

## 设计文档已明确废弃、不得作为活跃内容出现在数据或规则中的牌型。
const ABOLISHED_HAND_IDS := ["flush", "straight_flush", "royal_flush"]

var errors: Array[String] = []
var warnings: Array[String] = []
var authoritative: Dictionary = {}
var runtime: Dictionary = {}
var abolished_names: Array[String] = []
var authoritative_empty_declared: bool = false

func validate(pool_dir: String, technique_dir: String) -> Dictionary:
    errors.clear()
    warnings.clear()
    authoritative.clear()
    runtime.clear()
    abolished_names.clear()
    authoritative_empty_declared = false
    _parse_authoritative_pools(pool_dir)
    _parse_runtime_techniques(technique_dir)
    if errors.is_empty() and authoritative.is_empty() \
            and not authoritative_empty_declared:
        errors.append("未能从设计文档解析出任何活跃功法，解析规则可能已与文档格式脱节")
    _compare_names_and_pools()
    return result()

func result() -> Dictionary:
    var not_integrated: Array[String] = []
    for name in authoritative:
        if not runtime.has(name):
            not_integrated.append(str(name))
    not_integrated.sort()
    return {
        "errors": errors.duplicate(),
        "warnings": warnings.duplicate(),
        "authoritative_count": authoritative.size(),
        "runtime_count": runtime.size(),
        "not_integrated": not_integrated,
    }

## 从三个功法池文档解析权威活跃名单。
## 池归属由 `**高牌（6 门）**` 这类加粗分组标题决定；条目为 `- **名称**（…）：…`。
## 同时收集"已废弃"段落中列出的名称，它们不得作为活跃功法出现。
func _parse_authoritative_pools(pool_dir: String) -> void:
    var group_pattern := RegEx.create_from_string("^\\*\\*(.+?)（\\d+ 门）\\*\\*")
    var entry_pattern := RegEx.create_from_string("^- \\*\\*(.+?)\\*\\*")
    var directory := DirAccess.open(pool_dir)
    if directory == null:
        errors.append("无法打开功法池文档目录：%s" % pool_dir)
        return
    var file_names: Array[String] = []
    for file_name in directory.get_files():
        if file_name.ends_with(".md") and file_name.begins_with("2"):
            file_names.append(file_name)
    file_names.sort()
    if file_names.is_empty():
        errors.append("功法池文档目录中没有找到池文件：%s" % pool_dir)
        return
    for file_name in file_names:
        var path := pool_dir.path_join(file_name)
        var text := FileAccess.get_file_as_string(path)
        if text == "":
            errors.append("无法读取功法池文档：%s" % path)
            continue
        if file_name == "20-gongfa-framework.md" \
                and text.contains("当前五个正式功法池全部为空"):
            authoritative_empty_declared = true
        var archived_file := text.contains("# 历史归档")
        var current_pool := ""
        for line_value in text.split("\n"):
            var line := str(line_value)
            var group_match := group_pattern.search(line)
            if group_match != null:
                var label := group_match.get_string(1)
                var normalized_label := label.trim_prefix("归档·")
                current_pool = str(POOL_LABEL_TO_CODE.get(normalized_label, ""))
                if current_pool == "":
                    warnings.append("%s 出现未登记的池标题：%s" % [file_name, label])
                continue
            if line.contains("已废弃"):
                _collect_abolished_names(line)
                continue
            var entry_match := entry_pattern.search(line)
            if entry_match == null or current_pool == "":
                continue
            var technique_name := entry_match.get_string(1)
            if archived_file:
                if not abolished_names.has(technique_name):
                    abolished_names.append(technique_name)
                continue
            if authoritative.has(technique_name):
                errors.append("权威功法名重复：%s" % technique_name)
                continue
            authoritative[technique_name] = current_pool

## 从"……原属同花池，现均已废弃"这类句子中提取被废弃的功法名。
func _collect_abolished_names(line: String) -> void:
    var head := line.split("原属")[0]
    head = head.split("现均已废弃")[0]
    for candidate in head.split("、"):
        var name := candidate.strip_edges()
        if name != "" and not name.contains("：") and name.length() <= 8:
            if not abolished_names.has(name):
                abolished_names.append(name)

## 读取每个功法资源的 display_name 与 pool。
func _parse_runtime_techniques(technique_dir: String) -> void:
    var name_pattern := RegEx.create_from_string("(?m)^display_name = \"(.+?)\"")
    var pool_pattern := RegEx.create_from_string("(?m)^pool = \"(.+?)\"")
    var directory := DirAccess.open(technique_dir)
    if directory == null:
        errors.append("无法打开功法资源目录：%s" % technique_dir)
        return
    var file_names: Array[String] = []
    for file_name in directory.get_files():
        if file_name.ends_with(".tres"):
            file_names.append(file_name)
    file_names.sort()
    for file_name in file_names:
        var path := technique_dir.path_join(file_name)
        var text := FileAccess.get_file_as_string(path)
        if text == "":
            errors.append("无法读取功法资源：%s" % file_name)
            continue
        var name_match := name_pattern.search(text)
        if name_match == null:
            errors.append("功法资源缺少 display_name：%s" % file_name)
            continue
        var pool_match := pool_pattern.search(text)
        runtime[name_match.get_string(1)] = {
            "pool": "" if pool_match == null else pool_match.get_string(1),
            "file": file_name,
        }

## 逐条比对名单、池归属与废弃状态。
func _compare_names_and_pools() -> void:
    for technique_name in runtime:
        var entry: Dictionary = runtime[technique_name]
        var pool := str(entry.get("pool", ""))
        var file_name := str(entry.get("file", ""))
        if abolished_names.has(technique_name):
            errors.append("已废弃功法仍作为活跃内容存在：%s（%s）" % [technique_name, file_name])
            continue
        if not authoritative.has(technique_name):
            errors.append("功法在权威活跃名单中查无此名：%s（%s）" % [technique_name, file_name])
            continue
        var expected := str(authoritative[technique_name])
        if pool != expected:
            errors.append("功法池归属不符：%s 数据为 %s，权威为 %s" % [technique_name, pool, expected])
    for hand_id in ABOLISHED_HAND_IDS:
        for technique_name in runtime:
            if str((runtime[technique_name] as Dictionary).get("pool", "")) == hand_id:
                errors.append("功法挂在已废弃牌型池上：%s（pool=%s）" % [technique_name, hand_id])
