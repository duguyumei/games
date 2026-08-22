## 一张真气实例上的可持久化重塑状态；固定定义仍由 QiReshapeData 提供。
extends SerializableData
class_name QiReshapeState

## 重塑状态的生命周期范围。
const SCOPE_RUN: String = "run"
const SCOPE_BATTLE: String = "battle"

## 固定重塑定义 ID。
@export var definition_id: String = ""

## 重塑实例稳定 ID；其他槽位需要依靠它精确移除。
@export var state_uid: String = ""

## 实际占用的重塑槽位。
@export var reshape_slot: String = ""

## 本源操作类型快照，便于恢复和校验旧存档。
@export var origin_operation: String = ""

## 实际生效的生命周期范围。
@export var scope: String = SCOPE_RUN

## 变化后的最终值，例如 attribute_id=fire 或 rank=10。
@export var result_values: Dictionary[String, Variant] = {}

## 重塑脚本可使用的本局或战斗扩展状态。
@export var runtime_state: Dictionary[String, Variant] = {}

## 用于同一槽位内的稳定替换顺序。
@export var applied_order: int = 0

## 校验重塑实例状态是否可以被保存。
func is_valid_state() -> bool:
	return definition_id != "" \
		and state_uid != "" \
		and QiReshapeData.VALID_SLOTS.has(reshape_slot) \
		and (scope == SCOPE_RUN or scope == SCOPE_BATTLE) \
		and ((reshape_slot.begins_with("temporary_") and scope == SCOPE_BATTLE) \
		or (not reshape_slot.begins_with("temporary_") and scope == SCOPE_RUN)) \
		and JsonStateValidator.is_json_compatible(result_values) \
		and JsonStateValidator.is_json_compatible(runtime_state)

## 创建一份完全独立的状态副本。
func copy_state() -> QiReshapeState:
	var copied_state: QiReshapeState = duplicate(true) as QiReshapeState
	return copied_state
