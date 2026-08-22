## 真气异状的固定定义；只描述规则，不保存某张真气的当前层数。
extends SerializableData
class_name QiAnomalyData

## 异状可以持续到本局结束，或只存在于一场战斗。
const SCOPE_RUN: String = "run"
const SCOPE_BATTLE: String = "battle"

## 异状的展示分类。
const CATEGORY_BUFF: String = "buff"
const CATEGORY_DEBUFF: String = "debuff"
const CATEGORY_STATUS: String = "status"
const CATEGORY_MARKER: String = "marker"

## 异状重复施加时的层数处理方式。
const STACK_ADD: String = "add"
const STACK_REPLACE: String = "replace"
const STACK_KEEP: String = "keep"

## 异状显示名称。
@export var anomaly_name: String = ""

## 异状说明文本。
@export_multiline var anomaly_description: String = ""

## 异状显示图片路径。
@export var anomaly_texture_path: String = ""

## 异状展示分类。
@export var anomaly_category: String = CATEGORY_STATUS

## 固定定义的默认生命周期范围；实际状态会再次保存 scope。
@export var default_scope: String = SCOPE_BATTLE

## 允许行为覆盖的生命周期范围；为空时只允许 default_scope。
@export var allowed_scopes: Array[String] = []

## 重复施加时的层数策略。
@export var stack_policy: String = STACK_ADD

## 层数最大值；小于 0 表示不设上限。
@export var max_stacks: int = -1

## 异状在这些已提交事件发生后失效；空数组表示只在 scope 结束时清理。
@export var expire_events: Array[String] = []

## 固定效果脚本路径；脚本只能通过上下文产生行为，不能直接修改存档。
@export var effect_script_path: String = ""

## 传给效果脚本的 JSON 兼容配置。
@export var effect_config: Dictionary[String, Variant] = {}

## 校验异状固定定义是否合法。
func is_valid_definition() -> bool:
	var scopes: Array[String] = allowed_scopes
	if scopes.is_empty():
		scopes = [default_scope]
	return object_id != "" \
		and (anomaly_category == CATEGORY_BUFF \
		or anomaly_category == CATEGORY_DEBUFF \
		or anomaly_category == CATEGORY_STATUS \
		or anomaly_category == CATEGORY_MARKER) \
		and (default_scope == SCOPE_RUN or default_scope == SCOPE_BATTLE) \
		and scopes.all(func(scope: String) -> bool:
			return scope == SCOPE_RUN or scope == SCOPE_BATTLE) \
		and scopes.has(default_scope) \
		and (stack_policy == STACK_ADD \
		or stack_policy == STACK_REPLACE \
		or stack_policy == STACK_KEEP) \
		and max_stacks != 0 \
		and JsonStateValidator.is_json_compatible(effect_config)

## 判断某个生命周期范围能否用于此固定定义。
func allows_scope(scope: String) -> bool:
	if scope != SCOPE_RUN and scope != SCOPE_BATTLE:
		return false
	if allowed_scopes.is_empty():
		return scope == default_scope
	return allowed_scopes.has(scope)
