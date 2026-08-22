## 真气重塑效果的逻辑基类；固定定义只保存脚本路径和配置。
extends RefCounted
class_name BaseQiReshapeEffect

## 当前重塑固定定义。
var reshape_data: QiReshapeData = null

## 当前真气实例 UID。
var qi_instance_uid: String = ""

## 当前状态提供的运行时数据副本。
var runtime_state: Dictionary[String, Variant] = {}

## 初始化效果脚本；只保存上下文引用，不在创建时自动结算。
func init(
		_reshape_data: QiReshapeData,
		_qi_instance_uid: String,
		_state: QiReshapeState = null) -> void:
	reshape_data = _reshape_data
	qi_instance_uid = _qi_instance_uid
	if _state != null:
		runtime_state = _state.runtime_state.duplicate(true)

## 应用重塑时的钩子；具体效果通过 Action/Interceptor 实现。
func on_apply(_context: Dictionary[String, Variant]) -> void:
	pass

## 重塑监听已提交事件时的钩子。
func on_event(_event_id: String, _context: Dictionary[String, Variant]) -> void:
	pass

## 修改有效属性查询的钩子；默认保持查询结果不变。
func modify_attribute(
		attribute_id: String,
		_context: Dictionary[String, Variant]) -> String:
	return attribute_id

## 修改有效牌阶查询的钩子；默认保持查询结果不变。
func modify_rank(
		rank: int,
		_context: Dictionary[String, Variant]) -> int:
	return rank

## 移除重塑时的钩子；具体效果不能直接写固定资源。
func on_remove(_context: Dictionary[String, Variant]) -> void:
	pass
