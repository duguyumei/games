## 一方真气行动的牌型、同气和功法值快照；只读结算器输出。
extends RefCounted
class_name QiActionSideResult

## 行动所属阵营。
var side: String = ""

## 牌型识别结果。
var pattern: QiHandPatternResult = null

## 参与牌的有效真气值总和 C。
var qi_value_sum: int = 0

## 牌型属性最大计数 N。
var base_multiplier: int = 0

## 功法和内功提供的倍率修正总和。
var multiplier_modifiers: int = 0

## 功法直接提供的固定功法值修正。
var direct_fixed_modifier: int = 0

## 功法直接提供的百分比功法值修正，100 表示增加一倍。
var direct_percent_modifier: int = 0

## 连势等直接修正前的功法值 P0。
var initial_power: int = 0

## 结算所有直接修正后的最终功法值 P。
var final_power: int = 0

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
	copied_result.qi_value_sum = qi_value_sum
	copied_result.base_multiplier = base_multiplier
	copied_result.multiplier_modifiers = multiplier_modifiers
	copied_result.direct_fixed_modifier = direct_fixed_modifier
	copied_result.direct_percent_modifier = direct_percent_modifier
	copied_result.initial_power = initial_power
	copied_result.final_power = final_power
	copied_result.gongfa_instance_uids = gongfa_instance_uids.duplicate()
	copied_result.gongfa_slot_instance_ids = gongfa_slot_instance_ids.duplicate()
	copied_result.gongfa_copy_count = gongfa_copy_count
	return copied_result
