class_name ConsumableRepository
extends RefCounted

const DATA_PATH := "res://data/consumables.json"

var consumables: Dictionary = {}

func load_from_file(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("消耗品数据无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(value: Dictionary) -> bool:
    consumables.clear()
    var parsed := value.duplicate(true)
    for definition in parsed.get("consumables", []):
        consumables[str(definition["id"])] = definition.duplicate(true)
    return not consumables.is_empty()

func get_consumable(consumable_id: String) -> Dictionary:
    return consumables.get(consumable_id, {}).duplicate(true)

func target_limits(consumable_id: String) -> Dictionary:
    var definition := get_consumable(consumable_id)
    var targeting: Dictionary = definition.get("targeting", {})
    return {
        "zone": str(targeting.get("zone", "none")),
        "minimum": int(targeting.get("minimum", 0)),
        "maximum": int(targeting.get("maximum", 0)),
    }

func validate_targets(consumable_id: String, cards: Array) -> Dictionary:
    var definition := get_consumable(consumable_id)
    if definition.is_empty():
        return {"ok": false, "reason": "消耗品不存在"}
    var limits := target_limits(consumable_id)
    if limits["zone"] == "none":
        return {
            "ok": cards.is_empty(),
            "reason": "该消耗品不需要选择真气" if not cards.is_empty() else "目标满足",
        }
    if cards.size() < limits["minimum"] or cards.size() > limits["maximum"]:
        return {
            "ok": false,
            "reason": "需要选择 %d～%d 张真气" % [limits["minimum"], limits["maximum"]],
        }
    return {"ok": true, "reason": "目标满足"}
