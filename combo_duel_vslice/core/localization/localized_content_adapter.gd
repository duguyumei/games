class_name LocalizedContentAdapter
extends RefCounted

## 迁移边界：新内容显式保存 *_key；只有尚未迁移的旧内容才读取显示文本字段。
## 无论使用哪条展示路径，逻辑身份始终来自 id，绝不从显示名称反推。


static func technique_view(definition: Dictionary, catalog, parameters: Dictionary = {}) -> Dictionary:
    var technique_id := str(definition.get("id", ""))
    var name_key := str(definition.get("name_key", ""))
    var description_key := str(definition.get("description_key", ""))
    return {
        "id": technique_id,
        "name_key": name_key,
        "description_key": description_key,
        "display_name": _localized_or_legacy(catalog, name_key, definition, "name", technique_id),
        "description": _localized_or_legacy(
            catalog, description_key, definition, "description", "", parameters),
    }


static func _localized_or_legacy(
        catalog,
        text_key: String,
        definition: Dictionary,
        legacy_field: String,
        fallback: String,
        parameters: Dictionary = {}) -> String:
    if not text_key.is_empty():
        return catalog.text(text_key, parameters)
    return str(definition.get(legacy_field, fallback))
