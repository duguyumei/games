## 一方真气行动的牌型、同气和功法值快照；只读结算器输出。
extends RefCounted
class_name QiActionSideResult

## 行动所属阵营。
var side: String = ""

## 牌型识别结果。
var pattern: QiHandPatternResult = null

## 每张待结算真气的基础、有效和最终真气值快照。
var qi_value_details: Dictionary[String, Dictionary] = {}

## 参与牌最终真气值总和；旧界面继续通过 qi_value_sum 读取。
var final_qi_value_sum: int = 0

## 参与牌的最终真气值总和兼容字段。
var qi_value_sum: int = 0

## 全部待结算真气的四属性同气计数。
var attribute_counts: Dictionary[String, int] = {
	"wind": 0,
	"forest": 0,
	"fire": 0,
	"mountain": 0,
}

## 每种属性对应的全部待结算真气 UID。
var attribute_qi_instance_uids: Dictionary[String, Array] = {
	"wind": [],
	"forest": [],
	"fire": [],
	"mountain": [],
}

## 全部待结算真气的基础倍率。
var base_multiplier: int = 0

## 最终倍率；旧界面中的倍率修正字段由两者差值同步。
var final_multiplier: int = 0

## 最终倍率与基础倍率的差值兼容字段。
var multiplier_modifiers: int = 0

## 使用最终倍率计算出的基础功法值。
var base_power: int = 0

## 基础功法值兼容字段。
var initial_power: int = 0

## 经过后续效果顺序修改后的有效功法值。
var effective_power: int = 0

## 有效功法值兼容字段。
var final_power: int = 0

## 数值查询期间按实际应用顺序记录的效果来源。
var applied_effect_sources: Array[Dictionary] = []

## 确认成功后才允许正式消费的效果回执。
var effect_receipts: Array[Dictionary] = []

## 本次成功读取的功法实例 UID。
var gongfa_instance_uids: Array[String] = []

## 本次成功读取的战斗功法实例 UID；用于冻结队列中的具体槽位。
var gongfa_slot_instance_ids: Array[String] = []

## 本次功法效果请求复制自身的数量；由战斗队列按容量再次校验。
var gongfa_copy_count: int = 0

## 返回该方是否有可结算牌型。
func is_valid() -> bool:
	return pattern != null and pattern.is_valid()

## 返回一份独立快照，避免 UI 或牌区修改结果。
func copy_result() -> QiActionSideResult:
	var copied_result: QiActionSideResult = QiActionSideResult.new()
	copied_result.side = side
	copied_result.pattern = pattern.copy_result() if pattern != null else null
	copied_result.qi_value_details = qi_value_details.duplicate(true)
	copied_result.final_qi_value_sum = final_qi_value_sum
	copied_result.qi_value_sum = qi_value_sum
	copied_result.attribute_counts = attribute_counts.duplicate(true)
	copied_result.attribute_qi_instance_uids = attribute_qi_instance_uids.duplicate(true)
	copied_result.base_multiplier = base_multiplier
	copied_result.final_multiplier = final_multiplier
	copied_result.multiplier_modifiers = multiplier_modifiers
	copied_result.base_power = base_power
	copied_result.initial_power = initial_power
	copied_result.effective_power = effective_power
	copied_result.final_power = final_power
	copied_result.applied_effect_sources = applied_effect_sources.duplicate(true)
	copied_result.effect_receipts = effect_receipts.duplicate(true)
	copied_result.gongfa_instance_uids = gongfa_instance_uids.duplicate()
	copied_result.gongfa_slot_instance_ids = gongfa_slot_instance_ids.duplicate()
	copied_result.gongfa_copy_count = gongfa_copy_count
	return copied_result
