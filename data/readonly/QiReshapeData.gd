## 真气重塑的固定定义；只描述规则，不保存任何一局运行时状态。
extends SerializableData
class_name QiReshapeData

## 重塑可以持续到本局结束，或只存在于一场战斗。
const SCOPE_RUN: String = "run"
const SCOPE_BATTLE: String = "battle"

## 固定重塑槽位 ID，业务代码通过这些 ID 读取和替换重塑。
const SLOT_ORIGIN: String = "origin"
const SLOT_ENHANCEMENT: String = "enhancement"
const SLOT_MARK: String = "mark"
const SLOT_OTHER: String = "other"
const SLOT_TEMPORARY_ENHANCEMENT: String = "temporary_enhancement"
const SLOT_TEMPORARY_ATTRIBUTE: String = "temporary_attribute"
const SLOT_TEMPORARY_RANK: String = "temporary_rank"

## 重塑的固定分类；分类决定槽位和替换规则。
const KIND_ORIGIN: String = "origin"
const KIND_ENHANCEMENT: String = "enhancement"
const KIND_MARK: String = "mark"
const KIND_OTHER: String = "other"
const KIND_TEMPORARY: String = "temporary"

## 本源重塑的操作类型。
const ORIGIN_ATTRIBUTE: String = "attribute"
const ORIGIN_RANK_SHIFT: String = "rank_shift"
const ORIGIN_AWAKEN: String = "awaken"

## 允许的重塑槽位集合。
const VALID_SLOTS: Array[String] = [
	SLOT_ORIGIN,
	SLOT_ENHANCEMENT,
	SLOT_MARK,
	SLOT_OTHER,
	SLOT_TEMPORARY_ENHANCEMENT,
	SLOT_TEMPORARY_ATTRIBUTE,
	SLOT_TEMPORARY_RANK,
]

## 重塑显示名称。
@export var reshape_name: String = ""

## 重塑说明文本。
@export_multiline var reshape_description: String = ""

## 重塑显示图片路径。
@export var reshape_texture_path: String = ""

## 重塑所属槽位；同槽位默认只能保留一个实例。
@export var reshape_slot: String = SLOT_OTHER

## 重塑固定分类；旧内容缺省时根据槽位兼容推断。
@export var reshape_kind: String = KIND_OTHER

## 本源重塑的具体操作类型；非本源重塑必须为空。
@export var origin_operation: String = ""

## 固定定义允许的生命周期范围；实际状态会再次保存 scope。
@export var default_scope: String = SCOPE_RUN

## 允许行为覆盖的生命周期范围；为空时只允许 default_scope。
@export var allowed_scopes: Array[String] = []

## 同一替换组内的重塑互斥，例如转属、易阶和觉醒。
@export var replacement_group: String = ""

## 固定效果脚本路径；脚本只能通过上下文产生行为，不能直接修改存档。
@export var effect_script_path: String = ""

## 传给效果脚本的 JSON 兼容配置。
@export var effect_config: Dictionary[String, Variant] = {}

## 校验重塑固定定义是否合法。
func is_valid_definition() -> bool:
	var scopes: Array[String] = allowed_scopes
	if scopes.is_empty():
		scopes = [default_scope]
	return object_id != "" \
		and VALID_SLOTS.has(reshape_slot) \
		and _is_valid_kind_for_slot() \
		and _is_valid_origin_operation() \
		and (default_scope == SCOPE_RUN or default_scope == SCOPE_BATTLE) \
		and _is_valid_scope_for_slot() \
		and scopes.all(func(scope: String) -> bool:
			return scope == SCOPE_RUN or scope == SCOPE_BATTLE) \
		and scopes.has(default_scope) \
		and JsonStateValidator.is_json_compatible(effect_config)

## 检查分类和槽位是否匹配，避免固定内容占用错误状态空间。
func _is_valid_kind_for_slot() -> bool:
	if reshape_slot == SLOT_ORIGIN:
		return reshape_kind == KIND_ORIGIN
	if reshape_slot == SLOT_ENHANCEMENT:
		return reshape_kind == KIND_ENHANCEMENT
	if reshape_slot == SLOT_MARK:
		return reshape_kind == KIND_MARK
	if reshape_slot == SLOT_OTHER:
		return reshape_kind == KIND_OTHER
	return reshape_kind == KIND_TEMPORARY

## 检查本源操作类型是否完整且非本源定义没有误填。
func _is_valid_origin_operation() -> bool:
	if reshape_kind != KIND_ORIGIN:
		return origin_operation == ""
	return origin_operation == ORIGIN_ATTRIBUTE \
		or origin_operation == ORIGIN_RANK_SHIFT \
		or origin_operation == ORIGIN_AWAKEN

## 检查永久和临时槽位是否使用了正确的生命周期。
func _is_valid_scope_for_slot() -> bool:
	var is_temporary: bool = reshape_kind == KIND_TEMPORARY
	if is_temporary:
		return default_scope == SCOPE_BATTLE \
			and (allowed_scopes.is_empty() or allowed_scopes == [SCOPE_BATTLE])
	return default_scope == SCOPE_RUN \
		and (allowed_scopes.is_empty() or allowed_scopes == [SCOPE_RUN])

## 将旧版本的属性和牌阶槽位映射到本源槽位。
static func normalize_legacy_slot(slot: String) -> String:
	if slot == "attribute" or slot == "rank":
		return SLOT_ORIGIN
	return slot

## 判断某个生命周期范围能否用于此固定定义。
func allows_scope(scope: String) -> bool:
	if scope != SCOPE_RUN and scope != SCOPE_BATTLE:
		return false
	if allowed_scopes.is_empty():
		return scope == default_scope
	return allowed_scopes.has(scope)
