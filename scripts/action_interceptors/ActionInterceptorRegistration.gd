## 一条行为拦截器注册记录，用于区分相同效果的不同来源实例。
extends RefCounted
class_name ActionInterceptorRegistration

## 固定 ActionInterceptorData 的内容 ID。
var interceptor_id: String = ""

## 来源类别，例如 legacy、artifact 或 neigong。
var source_kind: String = "legacy"

## 本局来源实例 UID；旧注册留空并继续按拦截器 ID 去重。
var source_instance_id: String = ""

## 来源在装备或持有列表中的顺序；数值较小者先处理。
var source_order: int = 0

## 全局稳定注册序号，用于处理完全相同的排序条件。
var registration_order: int = 0

## 创建一条不可序列化的运行时注册记录。
func _init(
		_interceptor_id: String = "",
		_source_kind: String = "legacy",
		_source_instance_id: String = "",
		_source_order: int = 0,
		_registration_order: int = 0) -> void:
	interceptor_id = _interceptor_id
	source_kind = _source_kind if _source_kind != "" else "legacy"
	source_instance_id = _source_instance_id
	source_order = _source_order
	registration_order = _registration_order

## 返回拦截器处理时可读取的来源上下文副本。
func get_source_context() -> Dictionary[String, Variant]:
	return {
		"interceptor_id": interceptor_id,
		"source_kind": source_kind,
		"source_instance_id": source_instance_id,
		"source_order": source_order,
		"registration_order": registration_order,
	}
