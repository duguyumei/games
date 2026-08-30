## 一条真气拦截器注册记录。
##
## 与旧的 ActionInterceptorRegistration 的关键区别是多了 owner —— 记录这个效果属于谁。
## 注册表按动作类型分组，因此判断一个拦截器是否生效不看它挂在哪个位置，
## 而是比较 owner 与动作发起者：相同即「自己发起」，不同即「对方发起」。
extends RefCounted
class_name QiInterceptorRegistration

## 固定 QiInterceptorData 的内容 ID。
var interceptor_id: String = ""

## 效果的归属者，实际类型为 BaseCombatant。
## 声明为 Object 以避免注册表层依赖战斗者实现，便于脱离场景树做单元测试。
## 判定「自己发起」还是「对方发起」的依据。
var owner: Object = null

## 来源类别，例如 neigong、gongfa、qi_state 或 artifact。
var source_kind: String = ""

## 本局来源实例 UID；用于精确注销单个来源。
var source_instance_id: String = ""

## 来源在装备或持有列表中的顺序；同优先级时数值小者先处理。
var source_order: int = 0

## 全局稳定注册序号；用于处理完全相同的排序条件。
var registration_order: int = 0


## 创建一条不可序列化的运行时注册记录。
func _init(
		_interceptor_id: String = "",
		_owner: Object = null,
		_source_kind: String = "",
		_source_instance_id: String = "",
		_source_order: int = 0,
		_registration_order: int = 0) -> void:
	interceptor_id = _interceptor_id
	owner = _owner
	source_kind = _source_kind
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
