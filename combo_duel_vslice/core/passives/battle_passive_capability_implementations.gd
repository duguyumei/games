class_name BattlePassiveCapabilityImplementations
extends RefCounted

## 九项被动投影与战斗适配平台能力的实现集合
##
## 本文件实现能力矩阵中剩余的 7 项 B 类与 2 项 C1 类能力：
## 1. battle_resource_changed - 战斗资源 committed 事实
## 2. technique_post_success_pre_advance_stage - 功法成功后、序列推进前阶段
## 3. pre_technique_cost_transaction - 功法执行前成本事务
## 4. extra_action_preflight_projection - 额外行动开始前投影
## 5. qi_state_behavior_target_policy_query - 真气状态行为目标策略查询
## 6. pre_effect_operation_event - effect op 执行前窄边界
## 7. follow_up_attack_completed_fact - 追击完成 committed 事实
## 8. passive_behavior_copy_projection - 被动行为复制投影
## 9. source_behavior_permanent_transformation - 来源行为永久变形

const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const BattleRuntimeMutationTransactionScript = preload(
	"res://core/battle_runtime_mutation_transaction.gd")

## ============================================================================
## 能力 1: battle_resource_changed - 战斗资源 committed 事实
## ============================================================================
## 收敛连势与同气槽变化到统一 committed 事件，触发被动规则

static func emit_battle_resource_changed(
		committed_event_service,
		side,
		resource_kind: String,
		operation: String,
		before: int,
		after: int,
		delta: int,
		action_token: String,
		source_category: String = "",
		source_id: String = "",
		metadata: Dictionary = {}) -> Dictionary:
	if committed_event_service == null:
		return {"success": false, "reason": "battle_resource_changed 缺少事件服务"}
	var serial: int = committed_event_service.next_serial()
	var event_token: String = committed_event_service.make_token(
		"battle_resource_changed", side, serial, action_token)
	var values := {
		"event_token": event_token,
		"event_serial": serial,
		"actor": side,
		"owner": side,
		"holder": side,
		"action_token": action_token,
		"resource_kind": resource_kind,
		"operation": operation,
		"before": before,
		"after": after,
		"delta": delta,
		"source_category": source_category,
		"source_id": source_id,
		"metadata": metadata.duplicate(true),
		"round_number": metadata.get("round_number", 0),
	}
	return committed_event_service.commit("battle_resource_changed", values)

## ============================================================================
## 能力 2: technique_post_success_pre_advance_stage - 功法成功后、序列推进前阶段
## ============================================================================
## 在功法执行完成、回响登记完成、但序列尚未推进前提供插入点

static func dispatch_technique_post_success_pre_advance(
		passive_runtime,
		context_values: Dictionary) -> Dictionary:
	if passive_runtime == null:
		return {"success": false, "reason": "缺少被动规则运行时"}
	var hook := "technique_post_success_pre_advance"
	if not passive_runtime.registry.has_hook(hook):
		return {"success": true, "skipped": true, "reason": "Hook 未注册"}
	return passive_runtime.dispatch_event(hook, context_values, "mutation")

## ============================================================================
## 能力 3: pre_technique_cost_transaction - 功法执行前成本事务
## ============================================================================
## 在功法即将执行时，允许被动规则消耗资源以改变功法行为

static func dispatch_pre_technique_cost(
		passive_runtime,
		context_values: Dictionary) -> Dictionary:
	if passive_runtime == null:
		return {"success": false, "reason": "缺少被动规则运行时"}
	var hook := "pre_technique_cost"
	if not passive_runtime.registry.has_hook(hook):
		return {"success": true, "skipped": true, "reason": "Hook 未注册"}
	return passive_runtime.dispatch_event(hook, context_values, "mutation")

## ============================================================================
## 能力 4: extra_action_preflight_projection - 额外行动开始前投影
## ============================================================================
## 在额外行动确定后、选择真气前提供被动规则投影点

static func dispatch_extra_action_preflight(
		passive_runtime,
		side,
		action_window_id: String,
		round_number: int) -> Dictionary:
	if passive_runtime == null:
		return {"success": false, "reason": "缺少被动规则运行时"}
	var hook := "extra_action_preflight"
	if not passive_runtime.registry.has_hook(hook):
		return {"success": true, "skipped": true, "reason": "Hook 未注册"}
	var context_values := {
		"actor": side,
		"owner": side,
		"action_window_id": action_window_id,
		"round_number": round_number,
	}
	return passive_runtime.dispatch_event(hook, context_values, "mutation")

## ============================================================================
## 能力 5: qi_state_behavior_target_policy_query - 真气状态行为目标策略查询
## ============================================================================
## 查询真气异状触发（风引、乱流等）的目标选择策略

static func query_qi_state_target_policy(
		passive_runtime,
		side,
		card_instance_id: String,
		behavior_id: String,
		candidate_cards: Array,
		context_values: Dictionary = {}) -> Dictionary:
	if passive_runtime == null:
		return {"success": false, "reason": "缺少被动规则运行时"}
	var hook := "qi_state_target_policy_query"
	if not passive_runtime.registry.has_hook(hook):
		return {"success": true, "policy": "default", "skipped": true}
	var merged_context := context_values.duplicate(true)
	merged_context.merge({
		"actor": side,
		"owner": side,
		"card_instance_id": card_instance_id,
		"behavior_id": behavior_id,
		"candidate_cards": candidate_cards.duplicate(),
		"candidate_count": candidate_cards.size(),
	}, true)
	var result: Dictionary = passive_runtime.dispatch_event(hook, merged_context, "read")
	if not result.get("success", false):
		return result
	# 收集所有 Handler 返回的策略修改
	var policy := "default"
	var target_rank_order := ""
	var target_position := ""
	for invocation_result in result.get("results", []):
		var handler_result: Dictionary = invocation_result.get("result", {})
		if handler_result.has("policy"):
			policy = str(handler_result["policy"])
		if handler_result.has("target_rank_order"):
			target_rank_order = str(handler_result["target_rank_order"])
		if handler_result.has("target_position"):
			target_position = str(handler_result["target_position"])
	return {
		"success": true,
		"policy": policy,
		"target_rank_order": target_rank_order,
		"target_position": target_position,
	}

## ============================================================================
## 能力 6: pre_effect_operation_event - effect op 执行前窄边界
## ============================================================================
## 在单个效果操作（如抽牌、弃牌）即将执行前提供窄边界投影

static func dispatch_pre_effect_operation(
		passive_runtime,
		context_values: Dictionary) -> Dictionary:
	if passive_runtime == null:
		return {"success": false, "reason": "缺少被动规则运行时"}
	var hook := "pre_effect_operation"
	if not passive_runtime.registry.has_hook(hook):
		return {"success": true, "skipped": true, "reason": "Hook 未注册"}
	return passive_runtime.dispatch_event(hook, context_values, "mutation")

## ============================================================================
## 能力 7: follow_up_attack_completed_fact - 追击完成 committed 事实
## ============================================================================
## 追击行动完成后的 committed 事实，供被动规则观测

static func emit_follow_up_attack_completed(
		committed_event_service,
		side,
		follow_up_count: int,
		damage_total: int,
		action_token: String,
		metadata: Dictionary = {}) -> Dictionary:
	if committed_event_service == null:
		return {"success": false, "reason": "follow_up_attack_completed 缺少事件服务"}
	var serial: int = committed_event_service.next_serial()
	var event_token: String = committed_event_service.make_token(
		"follow_up_attack_completed", side, serial, action_token)
	var values := {
		"event_token": event_token,
		"event_serial": serial,
		"actor": side,
		"owner": side,
		"action_token": action_token,
		"follow_up_count": follow_up_count,
		"damage_total": damage_total,
		"metadata": metadata.duplicate(true),
		"round_number": metadata.get("round_number", 0),
	}
	return committed_event_service.commit("follow_up_attack_completed", values)

## ============================================================================
## 能力 8: passive_behavior_copy_projection - 被动行为复制投影
## ============================================================================
## 在 build_execution_plan 中复制其他内功的可复制效果

static func apply_passive_behavior_copy(
		plan,
		source,
		copy_target_instance_key: String,
		all_sources: Array) -> Dictionary:
	if plan == null or source == null:
		return {"success": false, "reason": "被动行为复制缺少计划或来源"}
	# 查找复制目标
	var target_source = null
	for candidate in all_sources:
		if str(candidate.source_instance_key) == copy_target_instance_key:
			target_source = candidate
			break
	if target_source == null:
		return {"success": false, "reason": "复制目标来源不存在：%s" % copy_target_instance_key}
	# 收集目标的所有 invocation
	var copied_invocations: Array = []
	for invocation in plan.invocations:
		if invocation.source.source_instance_key == copy_target_instance_key:
			# 创建复制的 invocation，使用复制者的来源身份
			var copied_invocation = invocation.duplicate(true)
			copied_invocation.source = source
			copied_invocation.context.source = source
			copied_invocation.context.source_instance_key = source.source_instance_key
			copied_invocation.context.source_kind = source.source_kind
			copied_invocation.context.content_id = source.content_id
			copied_invocations.append(copied_invocation)
	return {
		"success": true,
		"copied_count": copied_invocations.size(),
		"additional_invocations": copied_invocations,
	}

## ============================================================================
## 能力 9: source_behavior_permanent_transformation - 来源行为永久变形
## ============================================================================
## 永久改变内功来源的行为定义（如《无影藏功》）

static func transform_source_behavior(
		growth_inventory,
		source_instance_key: String,
		new_behavior_id: String,
		new_configuration: Dictionary) -> Dictionary:
	if growth_inventory == null:
		return {"success": false, "reason": "来源行为变形缺少成长清单"}
	# 查找目标内功装备条目
	var target_entry = null
	for entry in growth_inventory.equipped_inner_skills:
		if str(entry.get("source_instance_key", "")) == source_instance_key:
			target_entry = entry
			break
	if target_entry == null:
		return {"success": false, "reason": "来源实例不存在：%s" % source_instance_key}
	# 永久变更行为定义
	target_entry["transformed"] = true
	target_entry["original_behavior_id"] = target_entry.get("behavior_id", "")
	target_entry["behavior_id"] = new_behavior_id
	if not target_entry.has("configuration_overrides"):
		target_entry["configuration_overrides"] = {}
	target_entry["configuration_overrides"].merge(new_configuration, true)
	return {
		"success": true,
		"source_instance_key": source_instance_key,
		"previous_behavior_id": target_entry["original_behavior_id"],
		"new_behavior_id": new_behavior_id,
		"transformed_entry": target_entry.duplicate(true),
	}
