class_name ItemRepository
extends RefCounted

const DATA_PATH := "res://data/items.json"

var items: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("物品数据无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    items.clear()
    for definition in value.get("items", []):
        if not definition is Dictionary or str(definition.get("id", "")) == "":
            continue
        items[str(definition["id"])] = definition.duplicate(true)
    return true

func get_item(item_id: String) -> Dictionary:
    return items.get(item_id, {}).duplicate(true)

func formal_shop_ids() -> Array[String]:
    var result: Array[String] = []
    for item_id in items:
        var definition: Dictionary = items[item_id]
        if str(definition.get("status", "")) == "formal" \
                and definition.get("price") is int:
            result.append(str(item_id))
    result.sort()
    return result
