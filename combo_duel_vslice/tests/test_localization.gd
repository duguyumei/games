extends SceneTree

const CatalogScript = preload("res://core/localization/localization_catalog.gd")
const FormatterScript = preload("res://core/localization/localization_text_formatter.gd")
const ContentAdapterScript = preload("res://core/localization/localized_content_adapter.gd")
const TextPresenterScript = preload("res://core/localization/localized_text_presenter.gd")
const SAMPLE_PATH := "res://data/localization_samples/fire_sparks.json"

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
    _test_real_catalog_and_language_switch()
    _test_interpolation_and_formatters()
    _test_long_text_font_and_wrapping()
    _test_content_key_migration_boundary()
    _test_catalog_validation_failures()
    if failures.is_empty():
        print("LOCALIZATION TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("LOCALIZATION TEST FAIL: %s" % failure)
    print("LOCALIZATION TEST FAILURES: %d / %d assertions" % [failures.size(), assertions])
    quit(1)


func _test_real_catalog_and_language_switch() -> void:
    var catalog = CatalogScript.new()
    _assert_true(catalog.load_directory(), "中英文目录通过完整校验")
    _assert_equal(catalog.errors, [], "真实目录没有重复、缺失中文或参数错误")
    _assert_equal(catalog.available_locales(), ["en_US", "zh_CN"], "语言列表稳定排序")
    _assert_equal(catalog.text("content.technique.fire_sparks.name"), "火星连点", "默认语言为中文")
    var locale_events: Array[String] = []
    catalog.locale_changed.connect(func(locale: String) -> void: locale_events.append(locale))
    _assert_true(catalog.set_locale("en_US"), "可切换到已加载英文")
    _assert_equal(locale_events, ["en_US"], "语言切换发出刷新信号")
    _assert_equal(catalog.text("content.technique.fire_sparks.name"), "Spark Barrage", "切换语言更新文案")
    _assert_equal(catalog.text("ui.sample.default_only"), "默认中文回退可用", "次语言缺项回退默认中文")
    _assert_equal(catalog.text("missing.sample.key"), "⟦missing.sample.key⟧", "完全缺失的 key 保持可见")
    _assert_true(not catalog.set_locale("not_loaded"), "拒绝切换到未加载语言")
    _assert_equal(catalog.current_locale, "en_US", "失败的语言切换不改变当前语言")


func _test_interpolation_and_formatters() -> void:
    var catalog = CatalogScript.new()
    _assert_true(catalog.load_directory(), "格式化测试目录载入")
    var summary := catalog.text("ui.sample.turn_summary", {
        "turn": 2,
        "actor": "太吾",
        "technique": "火星连点",
    })
    _assert_equal(summary, "第 2 回合：太吾 打出 火星连点", "命名参数完成插值")
    _assert_equal(
        FormatterScript.interpolate("保留 {{value}}，缺少 {amount}", {}),
        "保留 {value}，缺少 ⟪amount?⟫",
        "转义花括号与缺失变量都有稳定可见输出")
    _assert_equal(catalog.number(12345.678, 2), "12,345.68", "数字格式化统一处理精度与分组")
    _assert_equal(catalog.percent(0.125, 1), "12.5%", "百分比格式化接受比例值")
    _assert_equal(
        catalog.keyword("keyword.power.name"),
        "[color=#D6AA52][b]威力[/b][/color]",
        "关键词格式化提供统一富文本样式")
    _assert_equal(
        catalog.tooltip("keyword.power.name", "tooltip.power.description", {"power": 18}),
        "威力\n本次功法结算使用的基础数值为 18。",
        "tooltip 标题与插值正文统一组合")


func _test_long_text_font_and_wrapping() -> void:
    var catalog = CatalogScript.new()
    _assert_true(catalog.load_directory(), "长文本测试目录载入")
    var long_text := catalog.text("ui.sample.long_text")
    _assert_true(long_text.length() > 80, "中文目录包含真实超长文本样本")
    var label := Label.new()
    TextPresenterScript.apply(label, long_text, "长文本提示")
    _assert_equal(label.text, long_text, "展示器写入完整长文本")
    _assert_equal(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "长文本启用智能自动换行")
    _assert_true(label.has_theme_font_override("font"), "控件应用中文字体 fallback")
    _assert_equal(label.tooltip_text, "长文本提示", "展示器写入 tooltip")
    label.free()


func _test_content_key_migration_boundary() -> void:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAMPLE_PATH))
    _assert_true(parsed is Dictionary, "功法本地化纵切样本可解析")
    var catalog = CatalogScript.new()
    _assert_true(catalog.load_directory(), "功法纵切样本目录载入")
    var view: Dictionary = ContentAdapterScript.technique_view(
        parsed, catalog, parsed.get("description_parameters", {}))
    _assert_equal(view["id"], "fire_sparks", "逻辑身份来自稳定 id")
    _assert_equal(view["display_name"], "火星连点", "新内容通过 name_key 取中文")
    _assert_equal(
        view["description"],
        "造成 3 次 4 点伤害；每个攻击段后获得 1 层连势。",
        "新内容通过 description_key 与参数生成说明")
    _assert_true(catalog.set_locale("en_US"), "功法样本切换英文")
    var english_view: Dictionary = ContentAdapterScript.technique_view(
        parsed, catalog, parsed.get("description_parameters", {}))
    _assert_equal(english_view["id"], view["id"], "语言切换不改变逻辑 id")
    _assert_equal(english_view["display_name"], "Spark Barrage", "同一内容 key 切换英文显示")
    var legacy_view: Dictionary = ContentAdapterScript.technique_view({
        "id": "legacy_technique",
        "name": "旧功法名",
        "description": "旧功法说明",
    }, catalog)
    _assert_equal(legacy_view["id"], "legacy_technique", "旧内容仍保留独立逻辑 id")
    _assert_equal(legacy_view["display_name"], "旧功法名", "未迁移记录兼容旧 name 字段")
    _assert_equal(legacy_view["description"], "旧功法说明", "未迁移记录兼容旧 description 字段")
    var broken_key_view: Dictionary = ContentAdapterScript.technique_view({
        "id": "broken",
        "name_key": "content.technique.broken.name",
        "name": "不应静默回退",
    }, catalog)
    _assert_equal(
        broken_key_view["display_name"],
        "⟦content.technique.broken.name⟧",
        "已迁移内容的缺失 key 保持可见而不回退旧文本")


func _test_catalog_validation_failures() -> void:
    var duplicate = CatalogScript.new()
    _assert_true(not duplicate.load_from_documents([
        _document("zh_CN", [
            _entry("ui.test.same", "甲"),
            _entry("ui.test.same", "乙"),
        ]),
    ]), "重复 key 校验失败")
    _assert_contains(duplicate.errors, "文本 key 重复：ui.test.same", "重复 key 错误可定位")

    var missing_default = CatalogScript.new()
    _assert_true(not missing_default.load_from_documents([
        _document("zh_CN", []),
        _document("en_US", [_entry("ui.test.english_only", "English only")]),
    ]), "非默认语言独有 key 校验失败")
    _assert_contains(missing_default.errors, "缺失默认中文：ui.test.english_only", "缺失默认中文错误可定位")

    var invalid_placeholder = CatalogScript.new()
    _assert_true(not invalid_placeholder.load_from_documents([
        _document("zh_CN", [_entry("ui.test.invalid", "数值 {bad-name}")]),
    ]), "非法占位符校验失败")
    _assert_contains(invalid_placeholder.errors, "非法占位符 {bad-name}", "非法占位符错误可定位")

    var mismatched = CatalogScript.new()
    _assert_true(not mismatched.load_from_documents([
        _document("zh_CN", [_entry("ui.test.parameters", "造成 {damage} 点伤害")]),
        _document("en_US", [_entry("ui.test.parameters", "Deal {amount} damage")]),
    ]), "不同语言参数不一致校验失败")
    _assert_contains(mismatched.errors, "参数不一致", "参数集合差异错误可定位")


func _document(locale: String, entries: Array) -> Dictionary:
    return {"locale": locale, "entries": entries}


func _entry(key: String, text: String) -> Dictionary:
    return {"key": key, "text": text}


func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])


func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)


func _assert_contains(values: Array, fragment: String, label: String) -> void:
    assertions += 1
    for value in values:
        if fragment in str(value):
            return
    failures.append("%s：未找到 %s，实际 %s" % [label, fragment, str(values)])
