## 一张真气实例上的异状运行状态；战斗异状不会进入本局存档。
extends SerializableData
class_name QiAnomalyState

## 异状状态的生命周期范围。
const SCOPE_RUN: String = "run"
const SCOPE_BATTLE: String = "battle"

## 固定异状定义 ID。
@export var definition_id: String = ""

## 实际生效的生命周期范围。
@export var scope: String = SCOPE_BATTLE

## 当前主层数。
@export var stacks: int = 1

## 可供效果脚本使用的第二层数。
@export var secondary_stacks: int = 0

## 这些已提交事件发生后移除状态。
@export var expire_events: Array[String] = []

## 异状脚本可使用的扩展状态。
@export var runtime_state: Dictionary[String, Variant] = {}

## 用于稳定处理同一真气上的多个异状。
@export var applied_order: int = 0

## 校验异状实例状态是否可以被保存。
func is_valid_state() -> bool:
	return definition_id != "" \
		and (scope == SCOPE_RUN or scope == SCOPE_BATTLE) \
		and stacks > 0 \
		and JsonStateValidator.is_json_compatible(expire_events) \
		and JsonStateValidator.is_json_compatible(runtime_state)

## 创建一份完全独立的状态副本。
func copy_state() -> QiAnomalyState:
	var copied_state: QiAnomalyState = duplicate(true) as QiAnomalyState
	return copied_state
