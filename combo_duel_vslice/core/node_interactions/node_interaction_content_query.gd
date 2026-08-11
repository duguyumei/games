class_name NodeInteractionContentQuery
extends RefCounted

## Handler 可用的只读内容查询端口。

var _catalog

func _init(catalog_override = null) -> void:
    _catalog = catalog_override

func has_id(content_type: String, content_id: String) -> bool:
    return _catalog != null and _catalog.has_id(content_type, content_id)

func get_by_id(content_type: String, content_id: String) -> Dictionary:
    if _catalog == null:
        return {}
    return _catalog.get_by_id(content_type, content_id).duplicate(true)

func all_of(content_type: String) -> Array:
    if _catalog == null:
        return []
    return _catalog.all_of(content_type).duplicate(true)

func definition(content_key: String) -> Dictionary:
    if _catalog == null:
        return {}
    return _catalog.definition(content_key).duplicate(true)

func is_formally_obtainable(content_type: String, content_id: String) -> bool:
    return _catalog != null \
        and _catalog.is_formally_obtainable(content_type, content_id)
