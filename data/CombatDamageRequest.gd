## 一次正式战斗伤害请求；请求本身不保存到本局存档。
extends RefCounted
class_name CombatDamageRequest

## 普通直接伤害。
const DAMAGE_NORMAL: String = "normal"

## 无视护盾的真实直接伤害。
const DAMAGE_TRUE: String = "true"

## 可以被护盾吸收的间接毒伤。
const DAMAGE_POISON: String = "poison"

## 可以被护盾吸收的间接反震伤害。
const DAMAGE_REFLECT: String = "reflect"

## 支持的伤害类型。
const DAMAGE_TYPES: Array[String] = [
	DAMAGE_NORMAL,
	DAMAGE_TRUE,
	DAMAGE_POISON,
	DAMAGE_REFLECT,
]

## 请求伤害数值。
var amount: int = 0

## 固定伤害类型。
var damage_type: String = DAMAGE_NORMAL

## 伤害来源阵营。
var source_side: String = ""

## 伤害来源实例 UID。
var source_instance_id: String = ""

## 伤害来源类别，例如 gongfa、neigong、qiwu 或 action。
var source_kind: String = ""

## 伤害目标阵营。
var target_side: String = ""

## 伤害来源效果或行为 UID。
var source_effect_id: String = ""

## 是否允许本次伤害触发反震；反震伤害本身固定为 false。
var can_trigger_reflect: bool = true

## 判断伤害类型是否合法。
func is_valid_damage_type() -> bool:
	return DAMAGE_TYPES.has(damage_type)

## 判断是否为直接伤害。
func is_direct_damage() -> bool:
	return damage_type == DAMAGE_NORMAL or damage_type == DAMAGE_TRUE

## 判断是否为间接伤害；毒伤和反震伤害属于间接伤害。
func is_indirect_damage() -> bool:
	return damage_type == DAMAGE_POISON or damage_type == DAMAGE_REFLECT

## 判断是否可以被护盾吸收。
func can_be_absorbed_by_shield() -> bool:
	return damage_type != DAMAGE_TRUE

## 创建一份独立请求副本。
func copy_request() -> CombatDamageRequest:
	var copied_request: CombatDamageRequest = CombatDamageRequest.new()
	copied_request.amount = amount
	copied_request.damage_type = damage_type
	copied_request.source_side = source_side
	copied_request.source_instance_id = source_instance_id
	copied_request.source_kind = source_kind
	copied_request.target_side = target_side
	copied_request.source_effect_id = source_effect_id
	copied_request.can_trigger_reflect = can_trigger_reflect
	return copied_request
