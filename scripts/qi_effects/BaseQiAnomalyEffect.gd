## 真气异状效果的逻辑基类；固定定义只保存脚本路径和配置。
extends RefCounted
class_name BaseQiAnomalyEffect

## 当前异状固定定义。
var anomaly_data: QiAnomalyData = null

## 当前真气实例 UID。
var qi_instance_uid: String = ""

## 当前状态提供的运行时数据副本。
var runtime_state: Dictionary[String, Variant] = {}

## 初始化效果脚本；只保存上下文引用，不在创建时自动结算。
func init(
		_anomaly_data: QiAnomalyData,
		_qi_instance_uid: String,
		_state: QiAnomalyState = null) -> void:
	anomaly_data = _anomaly_data
	qi_instance_uid = _qi_instance_uid
	if _state != null:
		runtime_state = _state.runtime_state.duplicate(true)

## 异状应用时的钩子；具体效果通过 Action/Interceptor 实现。
func on_apply(_context: Dictionary[String, Variant]) -> void:
	pass

## 真气事件发生时的钩子；事件只应来自已提交的现场变更。
func on_event(_event_id: String, _context: Dictionary[String, Variant]) -> void:
	pass

## 修改有效真气值的钩子；默认保持查询结果不变。
func modify_qi_value(
		value: int,
		_stacks: int,
		_context: Dictionary[String, Variant]) -> int:
	return value

## 移除异状时的钩子；具体效果不能直接写固定资源。
func on_remove(_context: Dictionary[String, Variant]) -> void:
	pass
