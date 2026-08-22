## 一方本次真气行动的纯牌型识别结果；只保存识别数据，不执行任何行为。
extends RefCounted
class_name QiHandPatternResult

## 没有足够真气时使用的空牌型。
const HAND_TYPE_NONE: String = "none"

## 识别出的精确牌型 ID。
var hand_type_id: String = HAND_TYPE_NONE

## 参与牌型结构计算的真气实例 UID，顺序与输入牌区保持稳定。
var participating_qi_instance_uids: Array[String] = []

## 没有参与牌型结构计算的踢脚牌 UID。
var kicker_qi_instance_uids: Array[String] = []

## 牌型要求的参与牌数量。
var required_participating_count: int = 0

## 四种属性在参与牌中的完整计数。
var attribute_counts: Dictionary[String, int] = {
	"wind": 0,
	"forest": 0,
	"fire": 0,
	"mountain": 0,
}

## 每种属性对应的参与牌 UID，允许一张多属性真气同时出现在多个列表中。
var attribute_qi_instance_uids: Dictionary[String, Array] = {
	"wind": [],
	"forest": [],
	"fire": [],
	"mountain": [],
}

## 四种属性计数中的最大值。
var max_same_qi: int = 0

## 并列达到最大同气数的属性 ID。
var max_same_qi_attribute_ids: Array[String] = []

## 牌型比较使用的稳定分值，数值越大表示牌型内部越强。
var comparison_values: Array[int] = []

## 返回是否识别出了可结算牌型。
func is_valid() -> bool:
	return hand_type_id != HAND_TYPE_NONE \
		and not participating_qi_instance_uids.is_empty()

## 返回指定属性的同气数量；未知属性返回零。
func get_attribute_count(attribute_id: String) -> int:
	return int(attribute_counts.get(attribute_id, 0))

## 根据当前参与牌重新计算四属性同气摘要；不会修改任何真气实例。
func rebuild_same_qi_summary() -> void:
	max_same_qi = 0
	max_same_qi_attribute_ids.clear()
	for attribute_id: String in QiData.ATTRIBUTE_IDS:
		var count: int = int(attribute_counts.get(attribute_id, 0))
		max_same_qi = max(max_same_qi, count)
	for attribute_id: String in QiData.ATTRIBUTE_IDS:
		if int(attribute_counts.get(attribute_id, 0)) == max_same_qi \
			and max_same_qi > 0:
			max_same_qi_attribute_ids.append(attribute_id)

## 返回一份完全独立的识别结果，供行动请求冻结使用。
func copy_result() -> QiHandPatternResult:
	var copied_result: QiHandPatternResult = QiHandPatternResult.new()
	copied_result.hand_type_id = hand_type_id
	copied_result.participating_qi_instance_uids = participating_qi_instance_uids.duplicate()
	copied_result.kicker_qi_instance_uids = kicker_qi_instance_uids.duplicate()
	copied_result.required_participating_count = required_participating_count
	copied_result.attribute_counts = attribute_counts.duplicate(true)
	copied_result.attribute_qi_instance_uids = attribute_qi_instance_uids.duplicate(true)
	copied_result.max_same_qi = max_same_qi
	copied_result.max_same_qi_attribute_ids = max_same_qi_attribute_ids.duplicate()
	copied_result.comparison_values = comparison_values.duplicate()
	return copied_result
