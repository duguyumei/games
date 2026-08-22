## 一次战斗伤害结算结果；只作为行为链和界面的运行时结果。
extends RefCounted
class_name CombatDamageResult

## 原始请求伤害。
var requested_damage: int = 0

## 实际被护盾吸收的伤害。
var shield_absorbed: int = 0

## 实际扣除生命的伤害。
var health_damage: int = 0

## 超过目标剩余生命的伤害。
var overkill_damage: int = 0

## 是否消耗了一层格挡。
var guard_consumed: bool = false

## 本次消耗的化解值。
var resolution_consumed: int = 0

## 本次产生的反震伤害。
var reflect_amount: int = 0

## 本次使用的伤害类型。
var damage_type: String = ""

## 本次伤害来源阵营。
var source_side: String = ""
## 本次伤害来源类别。
var source_kind: String = ""
## 本次伤害来源实例 UID。
var source_instance_id: String = ""
## 本次伤害来源效果 UID。
var source_effect_id: String = ""

## 目标阵营快照。
var target_side: String = ""

## 本次读取的穿透比例。
var penetration_ratio: float = 0.0

## 伤害是否被格挡或化解完全取消。
var was_prevented: bool = false

## 复制结算结果，避免后续行为修改原结果。
func copy_result() -> CombatDamageResult:
	var copied_result: CombatDamageResult = CombatDamageResult.new()
	copied_result.requested_damage = requested_damage
	copied_result.shield_absorbed = shield_absorbed
	copied_result.health_damage = health_damage
	copied_result.overkill_damage = overkill_damage
	copied_result.guard_consumed = guard_consumed
	copied_result.resolution_consumed = resolution_consumed
	copied_result.reflect_amount = reflect_amount
	copied_result.damage_type = damage_type
	copied_result.source_side = source_side
	copied_result.source_kind = source_kind
	copied_result.source_instance_id = source_instance_id
	copied_result.source_effect_id = source_effect_id
	copied_result.target_side = target_side
	copied_result.penetration_ratio = penetration_ratio
	copied_result.was_prevented = was_prevented
	return copied_result
