## 真气的持久重塑；跨探索永久保留，写入存档。
##
## 重塑是玩家在局外用资源改造真气的结果，与战斗状态（QiStateEntry）分属两层：
## 重塑永久生效且不被净化清除，战斗状态只存活一场战斗或一次探索。
##
## 一张真气可挂多个重塑，数量受该真气的重塑槽容量约束。
extends SerializableData
class_name QiReshape

## 重塑的四种类型。
enum KINDS {
	ELEMENT_REPLACE,   ## 属性替换：改变当前属性；多个并存时取应用顺序最大的一个
	VALUE_ADJUST,      ## 内力调整：改变存有的内力，可为负；多个并存时全部累加
	PERSISTENT_STATE,  ## 持久状态：战斗开始时自动获得指定状态
	MARK,              ## 标记：不改变数值，供功法与内功识别
}

## 重塑类型对应的稳定 ID。
const KIND_IDS: Array[String] = ["element_replace", "value_adjust", "persistent_state", "mark"]

## 本次重塑的类型。
@export var reshape_kind: int = KINDS.VALUE_ADJUST

## 属性替换的目标属性；仅 ELEMENT_REPLACE 使用，取值见 QiEnums.ELEMENTS。
@export var target_element: int = -1

## 内力调整的增减量；仅 VALUE_ADJUST 使用，可为负。
@export var value_delta: int = 0

## 持久状态的状态 ID；仅 PERSISTENT_STATE 使用。
@export var state_id: String = ""

## 标记 ID；仅 MARK 使用。标记本身没有效果，价值来自读取它的功法与内功数量。
@export var mark_id: String = ""

## 应用顺序；属性替换取该值最大的一个生效，因此移除某个重塑后能正确回退到前一个。
@export var applied_order: int = 0


## 创建一个属性替换重塑。
static func create_element_replace(element: int, order: int = 0) -> QiReshape:
	var reshape := QiReshape.new()
	reshape.reshape_kind = KINDS.ELEMENT_REPLACE
	reshape.target_element = element
	reshape.applied_order = order
	return reshape

## 创建一个内力调整重塑；delta 可为负。
static func create_value_adjust(delta: int, order: int = 0) -> QiReshape:
	var reshape := QiReshape.new()
	reshape.reshape_kind = KINDS.VALUE_ADJUST
	reshape.value_delta = delta
	reshape.applied_order = order
	return reshape

## 创建一个持久状态重塑。
static func create_persistent_state(id: String, order: int = 0) -> QiReshape:
	var reshape := QiReshape.new()
	reshape.reshape_kind = KINDS.PERSISTENT_STATE
	reshape.state_id = id
	reshape.applied_order = order
	return reshape

## 创建一个标记重塑。
static func create_mark(id: String, order: int = 0) -> QiReshape:
	var reshape := QiReshape.new()
	reshape.reshape_kind = KINDS.MARK
	reshape.mark_id = id
	reshape.applied_order = order
	return reshape


## 返回重塑类型对应的稳定 ID；越界时返回空字符串。
func get_kind_id() -> String:
	if reshape_kind < 0 or reshape_kind >= KIND_IDS.size():
		return ""
	return KIND_IDS[reshape_kind]

## 校验本重塑的字段是否与其类型匹配。
func is_valid() -> bool:
	match reshape_kind:
		KINDS.ELEMENT_REPLACE:
			return QiEnums.is_valid_element(target_element)
		KINDS.VALUE_ADJUST:
			return value_delta != 0
		KINDS.PERSISTENT_STATE:
			return not state_id.is_empty()
		KINDS.MARK:
			return not mark_id.is_empty()
	return false

## 返回用于界面展示的一行描述。
func get_display_text() -> String:
	match reshape_kind:
		KINDS.ELEMENT_REPLACE:
			return "属性替换 → " + QiEnums.get_element_name(target_element)
		KINDS.VALUE_ADJUST:
			return "内力 %+d" % value_delta
		KINDS.PERSISTENT_STATE:
			return "持久状态：" + state_id
		KINDS.MARK:
			return "标记：" + mark_id
	return ""
