class_name LocalizationCatalog
extends RefCounted

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "zh_CN"
const DEFAULT_DIRECTORY := "res://localization/catalogs"
const MISSING_KEY_TEMPLATE := "⟦%s⟧"
const FormatterScript = preload("res://core/localization/localization_text_formatter.gd")

var current_locale: String = DEFAULT_LOCALE
var errors: Array[String] = []
var _catalogs: Dictionary = {}


func load_directory(path: String = DEFAULT_DIRECTORY) -> bool:
    errors.clear()
    var directory := DirAccess.open(path)
    if directory == null:
        errors = ["无法打开本地化目录：%s" % path]
        return false
    var documents: Array[Dictionary] = []
    var file_names := directory.get_files()
    file_names.sort()
    for file_name in file_names:
        if not file_name.ends_with(".json"):
            continue
        var file_path := "%s/%s" % [path, file_name]
        var parsed = JSON.parse_string(FileAccess.get_file_as_string(file_path))
        if not parsed is Dictionary:
            errors.append("本地化文件不是合法 JSON 对象：%s" % file_path)
            continue
        documents.append(parsed)
    if not errors.is_empty():
        return false
    return load_from_documents(documents)


func load_from_documents(documents: Array) -> bool:
    errors.clear()
    _catalogs.clear()
    for document_value in documents:
        if not document_value is Dictionary:
            errors.append("语言目录必须是字典")
            continue
        var document: Dictionary = document_value
        var locale := str(document.get("locale", ""))
        if locale.is_empty():
            errors.append("语言目录缺少 locale")
            continue
        if _catalogs.has(locale):
            errors.append("语言目录重复：%s" % locale)
            continue
        var entries_value = document.get("entries", [])
        if not entries_value is Array:
            errors.append("%s.entries 必须是数组" % locale)
            continue
        var catalog: Dictionary = {}
        for entry_index in entries_value.size():
            var entry_value = entries_value[entry_index]
            var scope := "%s.entries[%d]" % [locale, entry_index]
            if not entry_value is Dictionary:
                errors.append("%s 必须是字典" % scope)
                continue
            var entry: Dictionary = entry_value
            var key := str(entry.get("key", ""))
            if not _is_valid_key(key):
                errors.append("%s 使用非法文本 key：%s" % [scope, key])
                continue
            if catalog.has(key):
                errors.append("%s 文本 key 重复：%s" % [locale, key])
                continue
            if not entry.get("text") is String:
                errors.append("%s.text 必须是字符串" % scope)
                continue
            var value: String = entry["text"]
            var placeholder_report: Dictionary = FormatterScript.inspect_placeholders(value)
            for placeholder_error in placeholder_report["errors"]:
                errors.append("%s.%s：%s" % [locale, key, placeholder_error])
            catalog[key] = value
        _catalogs[locale] = catalog
    _validate_default_catalog()
    _validate_placeholder_consistency()
    if not _catalogs.has(current_locale):
        current_locale = DEFAULT_LOCALE
    return errors.is_empty()


func set_locale(locale: String) -> bool:
    if not _catalogs.has(locale):
        return false
    if current_locale == locale:
        return true
    current_locale = locale
    locale_changed.emit(locale)
    return true


func text(key: String, parameters: Dictionary = {}) -> String:
    var template := raw_text(key)
    if template == "":
        return MISSING_KEY_TEMPLATE % key
    return FormatterScript.interpolate(template, parameters)


func raw_text(key: String, locale: String = current_locale) -> String:
    var selected: Dictionary = _catalogs.get(locale, {})
    if selected.has(key):
        return str(selected[key])
    var defaults: Dictionary = _catalogs.get(DEFAULT_LOCALE, {})
    return str(defaults.get(key, ""))


func has_key(key: String, locale: String = DEFAULT_LOCALE) -> bool:
    return _catalogs.get(locale, {}).has(key)


func available_locales() -> Array[String]:
    var locales: Array[String] = []
    for locale in _catalogs.keys():
        locales.append(str(locale))
    locales.sort()
    return locales


func number(value: float, decimals: int = -1) -> String:
    return FormatterScript.format_number(value, decimals, current_locale)


func percent(ratio: float, decimals: int = 0) -> String:
    return FormatterScript.format_percent(ratio, decimals, current_locale)


func keyword(key: String, color: String = "#D6AA52") -> String:
    return FormatterScript.format_keyword(text(key), color)


func tooltip(title_key: String, body_key: String, parameters: Dictionary = {}) -> String:
    return FormatterScript.format_tooltip(text(title_key), text(body_key, parameters))


func _validate_default_catalog() -> void:
    if not _catalogs.has(DEFAULT_LOCALE):
        errors.append("缺少默认中文目录 %s" % DEFAULT_LOCALE)
        return
    var defaults: Dictionary = _catalogs[DEFAULT_LOCALE]
    for locale in _catalogs:
        if locale == DEFAULT_LOCALE:
            continue
        var catalog: Dictionary = _catalogs[locale]
        for key in catalog:
            if not defaults.has(key):
                errors.append("缺失默认中文：%s（由 %s 提供）" % [key, locale])


func _validate_placeholder_consistency() -> void:
    if not _catalogs.has(DEFAULT_LOCALE):
        return
    var defaults: Dictionary = _catalogs[DEFAULT_LOCALE]
    for locale in _catalogs:
        if locale == DEFAULT_LOCALE:
            continue
        var catalog: Dictionary = _catalogs[locale]
        for key in catalog:
            if not defaults.has(key):
                continue
            var default_names: Array = FormatterScript.inspect_placeholders(str(defaults[key]))["names"]
            var translated_names: Array = FormatterScript.inspect_placeholders(str(catalog[key]))["names"]
            if default_names != translated_names:
                errors.append(
                    "%s.%s 参数不一致：默认中文 %s，当前语言 %s"
                    % [locale, key, str(default_names), str(translated_names)])


func _is_valid_key(key: String) -> bool:
    if key.is_empty() or not key.contains("."):
        return false
    for segment in key.split("."):
        if segment.is_empty():
            return false
        var first := segment.substr(0, 1)
        if first < "a" or first > "z":
            return false
        for index in range(1, segment.length()):
            var character := segment.substr(index, 1)
            var is_lowercase := character >= "a" and character <= "z"
            if not is_lowercase and not character.is_valid_int() and character != "_":
                return false
    return true
