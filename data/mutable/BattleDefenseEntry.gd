## 一条战斗防御效果来源；只存在于 BattleQiState，不写入本局存档。
extends RefCounted
class_name BattleDefenseEntry

## 护盾来源。
const KIND_SHIELD: String = "shield"

## 反震比例来源。
const KIND_REFLECT: String = "reflect"

## 格挡次数来源。
const KIND_GUARD: String = "guard"

## 化解值来源。
const KIND_RESOLUTION: String = "resolution"

## 穿透比例来源。
const KIND_PENETRATION: String = "penetration"

## 防御来源的持续范围标识。
const SCOPE_BATTLE: String = "battle"
const SCOPE_ROUNDS: String = "rounds"
const SCOPE_HITS: String = "hits"

## 来源所属的固定类型，例如 neigong、gongfa、qiwu 或 action。
var source_kind: String = ""

## 来源实例 UID；没有实例来源时使用效果或行为 UID。
var source_instance_id: String = ""

## 防御条目的稳定运行时 UID。
var entry_uid: String = ""

## 当前条目类型。
var kind: String = ""

## 该条目影响的伤害类型；为空表示影响所有适用类型。
var affected_damage_types: Array[String] = []

## 该条目的数值；护盾、化解使用整数语义，比例使用浮点语义。
var value: float = 0.0

## 条目注册时的稳定顺序；同值时也用于确定性处理。
var registration_order: int = 0

## 持续范围：rounds、hits 或 battle。
var duration_scope: String = "battle"

## 剩余回合数；负数表示不按回合过期。
var remaining_rounds: int = -1

## 剩余匹配次数；负数表示不按次数过期。
var remaining_hits: int = -1

## 护盾衰减方式；当前默认每回合减半。
var decay_policy: String = "halve"

## 创建一条带来源和生命周期的战斗防御条目。
static func create(
		_entry_uid: String,
		_kind: String,
		_value: float,
		_source_kind: String,
		_source_instance_id: String,
		_registration_order: int,
		_affected_damage_types: Array[String] = [],
		_duration_scope: String = SCOPE_BATTLE,
		_remaining_rounds: int = -1,
		_remaining_hits: int = -1,
		_decay_policy: String = "halve") -> BattleDefenseEntry:
	var entry: BattleDefenseEntry = BattleDefenseEntry.new()
	entry.entry_uid = _entry_uid
	entry.kind = _kind
	entry.value = _value
	entry.source_kind = _source_kind
	entry.source_instance_id = _source_instance_id
	entry.registration_order = _registration_order
	entry.affected_damage_types = _affected_damage_types.duplicate()
	entry.duration_scope = _duration_scope
	entry.remaining_rounds = _remaining_rounds
	entry.remaining_hits = _remaining_hits
	entry.decay_policy = _decay_policy
	return entry

## 判断条目是否仍然有效。
func is_active() -> bool:
	return value > 0.0 and (remaining_rounds != 0) and (remaining_hits != 0)

## 判断该条目是否影响指定伤害类型。
func affects_damage_type(damage_type: String) -> bool:
	return affected_damage_types.is_empty() or affected_damage_types.has(damage_type)

## 创建完全独立的战斗条目副本。
func copy_entry() -> BattleDefenseEntry:
	return BattleDefenseEntry.create(
		entry_uid,
		kind,
		value,
		source_kind,
		source_instance_id,
		registration_order,
		affected_damage_types,
		duration_scope,
		remaining_rounds,
		remaining_hits,
		decay_policy)
