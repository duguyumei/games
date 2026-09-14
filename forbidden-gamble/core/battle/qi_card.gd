class_name QiCard
extends RefCounted

# 真气卡（真气语法 v2，《真气语法_v2》§1）：属性（风/林/火/山）× 数值（2–8，占位）。
# 品级（下/中/上）已退役（2026-09-14 定案）——数值直接就是力度与结构材料：
# 刻子＝三张全同、顺子＝同属性数值连三。
var card_id: String
var attribute: String
var value: int  # 数值 2–8
# 真气状态词条（毒等）：status_id -> 层数。
var statuses: Dictionary = {}

const VALUE_MIN := 2
const VALUE_MAX := 8

func _init(new_id: String, new_attribute: String, new_value: int) -> void:
	card_id = new_id
	attribute = new_attribute
	value = new_value

static func value_valid(v: int) -> bool:
	return v >= VALUE_MIN and v <= VALUE_MAX

func value_text() -> String:
	return str(value)

func display_name() -> String:
	return "%s%d" % [attribute, value]

func add_status(status_id: String, delta: int) -> void:
	var stacks := int(statuses.get(status_id, 0)) + delta
	if stacks <= 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = stacks

func get_status(status_id: String) -> int:
	return int(statuses.get(status_id, 0))
