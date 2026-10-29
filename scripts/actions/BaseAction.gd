## 真气动作基类
##
## 职责：
##   1. 定义动作的元数据（名称、来源、目标）
##   2. 统一处理拦截器的 BEFORE / AFTER 两个阶段
##   3. 提供模板方法 _execute_core()，子类只实现核心逻辑
##   4. 追踪动作来源链（哪个功法/内功/真气产生的，为什么产生）
##
## 子类只需重写 _execute_core() 实现具体行为，拦截器逻辑由基类统一处理。
extends RefCounted
class_name BaseAction

## 动作的显示名称
var action_name: String = ""

## 动作的执行上下文（真气容器、事件总线等）
var context: QiActionContext = null

## 动作的发起者（战斗者实例）；用于拦截器的阵营判定
var parent_combatant: Variant = null

## 动作的配置参数；拦截器通过 resolver 读写，子类通过 get_action_value() 读取
var values: Dictionary = {}

## 动作来源追踪
var source: ActionSource = null


## ============================================================
## 构造
## ============================================================

static func create(
		_name: String,
		_context: QiActionContext,
		_actor: Variant,
		_source: ActionSource = null) -> BaseAction:
	var action := new()
	action.action_name = _name
	action.context = _context
	action.parent_combatant = _actor
	action.source = _source if _source != null else ActionSource.new()
	return action


## ============================================================
## 执行流程（模板方法）
## ============================================================

## 执行本动作，返回是否成功。
##
## 流程：
##   1. BEFORE 拦截链 —— 可修改参数、可拒绝
##   2. _execute_core() —— 子类实现的核心逻辑
##   3. AFTER 拦截链  —— 只读结果、追加效果
##
## 拦截器拒绝时直接返回 false，不执行核心逻辑与 AFTER 链。
func execute() -> bool:
	# BEFORE 阶段拦截
	var before_resolver := QiInterceptorResolver.new(self, QiInterceptorData.PHASES.BEFORE)
	if not before_resolver.run(false):
		return false  # 被拦截器拒绝

	# 执行核心逻辑
	var success := _execute_core(before_resolver)
	if not success:
		return false

	# AFTER 阶段拦截
	var after_resolver := QiInterceptorResolver.new(self, QiInterceptorData.PHASES.AFTER)
	after_resolver.run(false)

	return true


## 预览模式执行：禁止副作用，只返回计算结果。
##
## 用于界面预览「打出这张牌会造成多少伤害」，不能真的扣血或消耗资源。
## 拦截器通过 resolver.is_preview_mode() 判断并跳过副作用。
func execute_preview() -> Dictionary:
	var before_resolver := QiInterceptorResolver.new(self, QiInterceptorData.PHASES.BEFORE)
	if not before_resolver.run(true):
		return {"rejected": true}

	var result := _execute_preview(before_resolver)

	var after_resolver := QiInterceptorResolver.new(self, QiInterceptorData.PHASES.AFTER)
	after_resolver.run(true)

	return result


## ============================================================
## 待子类重写
## ============================================================

## 执行核心逻辑，返回是否成功。
##
## resolver 已跑完 BEFORE 链，参数已被拦截器修改过。
## 读参数用 resolver.get_shadowed_value(key, default)，不要直接读 values。
func _execute_core(_resolver: QiInterceptorResolver) -> bool:
	push_warning("BaseAction: _execute_core() 未实现于 %s" % get_script().resource_path)
	return false


## 预览模式执行，返回计算结果字典。
##
## 默认实现返回空字典。需要预览的子类（伤害动作、抽牌动作等）应重写此方法。
func _execute_preview(_resolver: QiInterceptorResolver) -> Dictionary:
	return {}


## ============================================================
## 参数读取
## ============================================================

## 读取动作参数；带默认值。
##
## 拦截器通过 resolver.get_shadowed_value() 读取已修改的值，
## 这个方法只在构造期与不需要拦截器修改的地方使用。
func get_action_value(key: String, default_value: Variant) -> Variant:
	var key_name := _resolve_key_name(key)
	return values.get(key_name, default_value)


## 设置动作参数。
func set_action_value(key: String, value: Variant) -> void:
	values[_resolve_key_name(key)] = value


## 应用参数键别名。
func _resolve_key_name(key: String) -> String:
	var custom: Dictionary = values.get("custom_key_names", {})
	return custom.get(key, key)


## ============================================================
## 调试
## ============================================================

## 返回动作的调试描述。
func get_debug_text() -> String:
	var actor_name := "?"
	if parent_combatant != null and parent_combatant.has("combatant_name"):
		actor_name = parent_combatant.combatant_name
	var source_text := source.get_debug_text() if source != null else "无来源"
	return "%s (发起者: %s, 来源: %s)" % [action_name, actor_name, source_text]
