class_name QiCard
extends RefCounted

# 真气卡（v1 三品化，《战斗系统底层_v1》§1）：属性（风/林/火/山）× 品级（下/中/上），
# 两个维度全部离散。品级值：下 1／中 2／上 3——真气量计算的唯一数值来源。
var card_id: String
var attribute: String
var grade: int  # 品级值 1/2/3
# 真气状态词条（毒等）：status_id -> 层数。跨战斗持续，随真气归位保留。
var statuses: Dictionary = {}

# JSON 数据用中文品级名（与 attribute 同风格），内存用 int。
const GRADE_NAMES := {"下品": 1, "中品": 2, "上品": 3}

func _init(new_id: String, new_attribute: String, new_grade: int) -> void:
	card_id = new_id
	attribute = new_attribute
	grade = new_grade

static func grade_from_name(grade_name: String) -> int:
	return int(GRADE_NAMES.get(grade_name, 1))

func grade_name() -> String:
	return ["下品", "中品", "上品"][clampi(grade, 1, 3) - 1]

# 品级单字（丹珠卡面标记，空间小）
func grade_short() -> String:
	return ["下", "中", "上"][clampi(grade, 1, 3) - 1]

func display_name() -> String:
	return "%s%s" % [attribute, grade_name()]

func add_status(status_id: String, delta: int) -> void:
	var stacks := int(statuses.get(status_id, 0)) + delta
	if stacks <= 0:
		statuses.erase(status_id)
	else:
		statuses[status_id] = stacks

func get_status(status_id: String) -> int:
	return int(statuses.get(status_id, 0))
