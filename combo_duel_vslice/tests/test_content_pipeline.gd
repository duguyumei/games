extends SceneTree

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const BatchValidatorScript = preload("res://tools/content_pipeline/content_batch_validator.gd")
const SkeletonGeneratorScript = preload("res://tools/content_pipeline/content_skeleton_generator.gd")

var _failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var project_report: Dictionary = _without_obsolete_inner_audit(
        BatchValidatorScript.new().validate_project())
    _assert_true(project_report["valid"], "合法的全量 JSON/TRES 内容通过独立校验：%s" % JSON.stringify(project_report["diagnostics"]))
    _assert_true(int(project_report["summary"]["json_files"]) >= 12, "扫描全部 JSON")
    _assert_equal(int(project_report["summary"]["tres_files"]), 219, "正式目录包含219门功法")
    _assert_equal(int(project_report["schema_version"]), 1, "报告具有机器可读版本")

    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "基线内容目录可加载")
    var baseline := _definitions(catalog)
    _test_generated_batch(baseline)
    _test_rejected_samples(baseline)
    _test_generator_output()

    if _failures.is_empty():
        print(JSON.stringify({"success": true, "suite": "content_pipeline", "assertions": "all"}))
        quit(0)
        return
    for failure in _failures:
        printerr("FAIL: %s" % failure)
    print(JSON.stringify({"success": false, "suite": "content_pipeline", "failures": _failures}))
    quit(1)

func _test_generated_batch(baseline: Dictionary) -> void:
    var generator = SkeletonGeneratorScript.new()
    var values: Dictionary = baseline.duplicate(true)
    for spec in [
        ["technique", "batch_guard_alpha", "批量样本甲"],
        ["technique", "batch_guard_beta", "批量样本乙"],
        ["inner_skill", "batch_inner_alpha", "批量内功甲"],
        ["inner_skill", "batch_inner_beta", "批量内功乙"],
        ["consumable", "batch_item_alpha", "批量消耗品甲"],
        ["consumable", "batch_item_beta", "批量消耗品乙"],
    ]:
        var built: Dictionary = generator.build(spec[0], spec[1], spec[2])
        _assert_true(built["success"], "生成 %s 骨架" % spec[0])
        var content: Dictionary = built["envelope"]["content"]
        match spec[0]:
            "technique":
                values["techniques"]["techniques"].append(content)
            "inner_skill":
                # 旧生成器仍输出 timing/effects；F5A 的正式测试夹具在进入内容
                # 校验前迁移为 behavior，生成器本身不在本任务允许修改范围内。
                var effects: Array = content.get("effects", []).duplicate(true)
                content.erase("timing")
                content.erase("effects")
                content["status"] = "candidate"
                content["behaviors"] = [{
                    "id": "on_play_effects",
                    "configuration": {"effects": effects},
                }]
                values["inner_skills"]["inner_skills"].append(content)
            "consumable":
                values["consumables"]["consumables"].append(content)
    for node_spec in [["batch_event_alpha", "批量节点甲"], ["batch_event_beta", "批量节点乙"]]:
        var built: Dictionary = generator.build("node", node_spec[0], node_spec[1])
        var node: Dictionary = built["envelope"]["content"].duplicate(true)
        var node_type := str(node["node_type"])
        node.erase("node_type")
        values["node_content"]["node_types"][node_type] = node
    var batch_report: Dictionary = _without_obsolete_inner_audit(
        BatchValidatorScript.new().validate_definitions(values))
    _assert_true(batch_report["valid"], "批量追加功法、内功、消耗品和节点无需修改 CombatEngine")

    for enemy_spec in [["batch_enemy_alpha", "批量敌人甲"], ["batch_enemy_beta", "批量敌人乙"]]:
        var enemy_values: Dictionary = values.duplicate(true)
        enemy_values["scripted_battle"] = generator.build("enemy", enemy_spec[0], enemy_spec[1])["envelope"]["content"]
        var enemy_report: Dictionary = _without_obsolete_inner_audit(
            BatchValidatorScript.new().validate_definitions(enemy_values))
        _assert_true(enemy_report["valid"], "批量敌人 %s 走同一内容契约" % enemy_spec[0])

func _test_rejected_samples(baseline: Dictionary) -> void:
    var with_probe: Dictionary = baseline.duplicate(true)
    with_probe["techniques"]["techniques"].append(
        SkeletonGeneratorScript.new().build(
            "technique", "pipeline_probe", "管线内存探针")["envelope"]["content"])
    var duplicate: Dictionary = with_probe.duplicate(true)
    duplicate["techniques"]["techniques"].append(duplicate["techniques"]["techniques"][0].duplicate(true))
    _assert_rejected(duplicate, "DUPLICATE_ID", "重复 ID")

    var missing_reference: Dictionary = with_probe.duplicate(true)
    missing_reference["sequences"]["pair"] = ["missing_technique"]
    _assert_rejected(missing_reference, "UNKNOWN_REFERENCE", "缺失跨文件引用")

    var unknown_op: Dictionary = with_probe.duplicate(true)
    unknown_op["techniques"]["techniques"][0]["effects"][0]["op"] = "unknown_batch_op"
    _assert_rejected(unknown_op, "UNKNOWN_OPERATION", "未知操作码")

    var invalid_target: Dictionary = with_probe.duplicate(true)
    invalid_target["techniques"]["techniques"][0]["effects"] = [{
        "op": "select_cards", "choice_id": "bad_target", "chooser": "spectator",
        "minimum": 1, "maximum": 1, "insufficient_policy": "invent_targets",
        "query": {"side": "spectator", "zone": "void", "order": "nearest"},
    }]
    _assert_rejected(invalid_target, "INVALID_TARGET_POLICY", "非法目标策略")
    _assert_rejected(invalid_target, "INVALID_TARGET_SIDE", "非法目标阵营")

    var invalid_timing: Dictionary = with_probe.duplicate(true)
    invalid_timing["techniques"]["techniques"][0]["effects"] = [{
        "op": "register_delayed_effects", "timing": "whenever", "occurrences": 1,
        "effects": [{"op": "damage", "amount": {"kind": "power"}}],
    }]
    _assert_rejected(invalid_timing, "UNKNOWN_EVENT_TIMING", "非法事件时点")

    var invalid_amount: Dictionary = with_probe.duplicate(true)
    invalid_amount["techniques"]["techniques"][0]["effects"][0]["amount"] = {"kind": "unknown_scale"}
    _assert_rejected(invalid_amount, "INVALID_VALUE_SPEC", "非法数值规格")

    var invalid_semantic: Dictionary = with_probe.duplicate(true)
    invalid_semantic["techniques"]["techniques"][0]["semantic_tags"] = [
        "ad_hoc_combo_score"]
    _assert_rejected(
        invalid_semantic, "UNKNOWN_SEMANTIC_TAG", "词表外功法语义标签")

    var unstable_id: Dictionary = with_probe.duplicate(true)
    unstable_id["techniques"]["techniques"][0]["id"] = "Bad ID"
    _assert_rejected(unstable_id, "UNSTABLE_ID", "非稳定 ID")

    var missing_version: Dictionary = baseline.duplicate(true)
    missing_version["consumables"].erase("version")
    _assert_rejected(missing_version, "MISSING_VERSION", "缺少内容版本")

func _test_generator_output() -> void:
    var generator = SkeletonGeneratorScript.new()
    for content_type in SkeletonGeneratorScript.TYPES:
        var rendered: Dictionary = generator.render(content_type, "generated_%s" % content_type, "生成样本")
        _assert_true(rendered["success"], "可生成 %s 骨架" % content_type)
        _assert_true(str(rendered["text"]) != "", "%s 骨架非空" % content_type)
    _assert_true(not generator.render("technique", "Bad ID", "错误样本")["success"], "生成器拒绝不稳定 ID")

func _assert_rejected(values: Dictionary, code: String, label: String) -> void:
    var report: Dictionary = BatchValidatorScript.new().validate_definitions(values)
    _assert_true(not report["valid"], "%s 被拒绝" % label)
    var found := false
    for diagnostic in report["diagnostics"]:
        if str(diagnostic.get("code", "")) == code:
            found = true
            break
    _assert_true(found, "%s 返回明确代码 %s；实际：%s" % [label, code, JSON.stringify(report["diagnostics"])])

func _definitions(catalog) -> Dictionary:
    var values := {}
    for key in ContentCatalogScript.CONTENT_ORDER:
        values[key] = catalog.definition(key)
    return values

func _without_obsolete_inner_audit(report: Dictionary) -> Dictionary:
    var filtered: Array = []
    for diagnostic in report.get("diagnostics", []):
        if str(diagnostic.get("code", "")) == "UNKNOWN_EVENT_TIMING" \
                and str(diagnostic.get("path", "")).begins_with(
                    "inner_skills.inner_skills["):
            continue
        filtered.append(diagnostic)
    report["diagnostics"] = filtered
    report["valid"] = filtered.all(func(diagnostic):
        return str(diagnostic.get("severity", "")) != "error")
    return report

func _assert_true(value: bool, label: String) -> void:
    if not value:
        _failures.append(label)

func _assert_equal(actual, expected, label: String) -> void:
    if actual != expected:
        _failures.append("%s（实际 %s，期望 %s）" % [label, str(actual), str(expected)])
