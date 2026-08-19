extends GutTest

## 测试九项被动投影与战斗适配平台能力
##
## 本测试验证：
## 1. battle_resource_changed - 战斗资源 committed 事实
## 2. technique_post_success_pre_advance_stage - 功法成功后、序列推进前阶段
## 3. pre_technique_cost_transaction - 功法执行前成本事务
## 4. extra_action_preflight_projection - 额外行动开始前投影
## 5. qi_state_behavior_target_policy_query - 真气状态行为目标策略查询
## 6. pre_effect_operation_event - effect op 执行前窄边界
## 7. follow_up_attack_completed_fact - 追击完成 committed 事实
## 8. passive_behavior_copy_projection - 被动行为复制投影
## 9. source_behavior_permanent_transformation - 来源行为永久变形

const CapabilityScript = preload(
	"res://core/passives/battle_passive_capability_implementations.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")
const PassiveRuleRuntimeScript = preload("res://core/passives/passive_rule_runtime.gd")
const BattlePassiveCommittedEventServiceScript = preload(
	"res://core/passives/battle_passive_committed_event_service.gd")
const PassiveRuleHandlerRegistryScript = preload(
	"res://core/passives/passive_rule_handler_registry.gd")

var _runtime: PassiveRuleRuntimeScript
var _event_service: BattlePassiveCommittedEventServiceScript
var _registry: PassiveRuleHandlerRegistryScript
var _mock_side

func before_each() -> void:
	_registry = PassiveRuleHandlerRegistryScript.new()
	_runtime = PassiveRuleRuntimeScript.new(_registry)
	_event_service = BattlePassiveCommittedEventServiceScript.new(_runtime)
	_mock_side = _create_mock_side("player")

func after_each() -> void:
	_runtime = null
	_event_service = null
	_registry = null
	_mock_side = null

## ============================================================================
## 能力 1: battle_resource_changed
## ============================================================================

func test_battle_resource_changed_momentum() -> void:
	var result := CapabilityScript.emit_battle_resource_changed(
		_event_service,
		_mock_side,
		"momentum",
		"add",
		5,
		10,
		5,
		"action-001",
		"technique",
		"test_technique",
		{"round_number": 1})
	assert_true(result.get("success", false), "连势变化事件应成功提交")
	assert_eq(result.get("event_token", "").begins_with("battle-"), true,
		"事件令牌应包含战斗ID")

func test_battle_resource_changed_same_qi() -> void:
	var result := CapabilityScript.emit_battle_resource_changed(
		_event_service,
		_mock_side,
		"same_qi",
		"gain",
		3,
		5,
		2,
		"action-002",
		"effect",
		"",
		{"round_number": 2})
	assert_true(result.get("success", false), "同气变化事件应成功提交")

func test_battle_resource_changed_in_catalog() -> void:
	assert_true(BattleEventCatalogScript.is_committed("battle_resource_changed"),
		"battle_resource_changed 应在 COMMITTED_EVENTS 中")

## ============================================================================
## 能力 2: technique_post_success_pre_advance_stage
## ============================================================================

func test_technique_post_success_pre_advance_hook_registered() -> void:
	_registry.register_hook("technique_post_success_pre_advance")
	assert_true(_registry.has_hook("technique_post_success_pre_advance"),
		"technique_post_success_pre_advance Hook 应成功注册")

func test_technique_post_success_pre_advance_dispatch() -> void:
	_registry.register_hook("technique_post_success_pre_advance")
	var context := {
		"actor": _mock_side,
		"owner": _mock_side,
		"technique_id": "test_technique",
		"slot_instance_id": "slot-001",
	}
	var result := CapabilityScript.dispatch_technique_post_success_pre_advance(
		_runtime, context)
	assert_true(result.get("success", false) or result.get("skipped", false),
		"功法成功后阶段应可调度")

## ============================================================================
## 能力 3: pre_technique_cost_transaction
## ============================================================================

func test_pre_technique_cost_hook_registered() -> void:
	_registry.register_hook("pre_technique_cost")
	assert_true(_registry.has_hook("pre_technique_cost"),
		"pre_technique_cost Hook 应成功注册")

func test_pre_technique_cost_dispatch() -> void:
	_registry.register_hook("pre_technique_cost")
	var context := {
		"actor": _mock_side,
		"owner": _mock_side,
		"technique_id": "test_technique",
		"available_resources": {"experience": 10},
	}
	var result := CapabilityScript.dispatch_pre_technique_cost(
		_runtime, context)
	assert_true(result.get("success", false) or result.get("skipped", false),
		"功法成本事务应可调度")

## ============================================================================
## 能力 4: extra_action_preflight_projection
## ============================================================================

func test_extra_action_preflight_hook_registered() -> void:
	_registry.register_hook("extra_action_preflight")
	assert_true(_registry.has_hook("extra_action_preflight"),
		"extra_action_preflight Hook 应成功注册")

func test_extra_action_preflight_dispatch() -> void:
	_registry.register_hook("extra_action_preflight")
	var result := CapabilityScript.dispatch_extra_action_preflight(
		_runtime, _mock_side, "window-001", 3)
	assert_true(result.get("success", false) or result.get("skipped", false),
		"额外行动前投影应可调度")

func test_extra_action_preflight_in_catalog() -> void:
	assert_true(BattleEventCatalogScript.forwards_dynamic_response(
		"extra_action_preflight"),
		"extra_action_preflight 应在 RESPONSE_ONLY_EVENTS 中")

## ============================================================================
## 能力 5: qi_state_behavior_target_policy_query
## ============================================================================

func test_qi_state_target_policy_hook_registered() -> void:
	_registry.register_hook("qi_state_target_policy_query")
	assert_true(_registry.has_hook("qi_state_target_policy_query"),
		"qi_state_target_policy_query Hook 应成功注册")

func test_qi_state_target_policy_query_default() -> void:
	_registry.register_hook("qi_state_target_policy_query")
	var candidates := [
		{"card_instance_id": "card-001", "rank": 5},
		{"card_instance_id": "card-002", "rank": 10},
	]
	var result := CapabilityScript.query_qi_state_target_policy(
		_runtime, _mock_side, "card-trigger", "wind_guidance", candidates)
	assert_true(result.get("success", false) or result.get("skipped", false),
		"真气状态目标策略查询应可执行")
	assert_eq(result.get("policy", ""), "default",
		"无Handler时应返回默认策略")

## ============================================================================
## 能力 6: pre_effect_operation_event
## ============================================================================

func test_pre_effect_operation_hook_registered() -> void:
	_registry.register_hook("pre_effect_operation")
	assert_true(_registry.has_hook("pre_effect_operation"),
		"pre_effect_operation Hook 应成功注册")

func test_pre_effect_operation_dispatch() -> void:
	_registry.register_hook("pre_effect_operation")
	var context := {
		"actor": _mock_side,
		"owner": _mock_side,
		"operation": "draw",
		"amount": 2,
	}
	var result := CapabilityScript.dispatch_pre_effect_operation(
		_runtime, context)
	assert_true(result.get("success", false) or result.get("skipped", false),
		"效果操作前投影应可调度")

## ============================================================================
## 能力 7: follow_up_attack_completed_fact
## ============================================================================

func test_follow_up_attack_completed_emission() -> void:
	var result := CapabilityScript.emit_follow_up_attack_completed(
		_event_service,
		_mock_side,
		3,
		25,
		"action-003",
		{"round_number": 2})
	assert_true(result.get("success", false), "追击完成事件应成功提交")

func test_follow_up_attack_completed_in_catalog() -> void:
	assert_true(BattleEventCatalogScript.is_committed("follow_up_attack_completed"),
		"follow_up_attack_completed 应在 COMMITTED_EVENTS 中")

## ============================================================================
## 能力 8: passive_behavior_copy_projection
## ============================================================================

func test_passive_behavior_copy_basic() -> void:
	var source := _create_mock_source("inner_skill", "copier", "copy_behavior")
	var target := _create_mock_source("inner_skill", "target", "original_behavior")
	var plan := _create_mock_plan()
	var all_sources := [source, target]
	var result := CapabilityScript.apply_passive_behavior_copy(
		plan, source, "target", all_sources)
	assert_true(result.get("success", false), "被动行为复制应成功")
	assert_gte(result.get("copied_count", -1), 0, "应返回复制数量")

func test_passive_behavior_copy_target_not_found() -> void:
	var source := _create_mock_source("inner_skill", "copier", "copy_behavior")
	var plan := _create_mock_plan()
	var result := CapabilityScript.apply_passive_behavior_copy(
		plan, source, "nonexistent", [])
	assert_false(result.get("success", false), "复制不存在的目标应失败")

## ============================================================================
## 能力 9: source_behavior_permanent_transformation
## ============================================================================

func test_source_behavior_transformation_basic() -> void:
	var mock_inventory := _create_mock_growth_inventory()
	var result := CapabilityScript.transform_source_behavior(
		mock_inventory,
		"inner-001",
		"new_behavior",
		{"param": "value"})
	assert_true(result.get("success", false), "来源行为变形应成功")
	assert_eq(result.get("new_behavior_id", ""), "new_behavior",
		"应返回新行为ID")
	assert_eq(mock_inventory.equipped_inner_skills[0].get(
		"behavior_id", ""), "new_behavior",
		"内功条目应已变形")
	assert_true(mock_inventory.equipped_inner_skills[0].get(
		"transformed", false),
		"应标记为已变形")

func test_source_behavior_transformation_not_found() -> void:
	var mock_inventory := _create_mock_growth_inventory()
	var result := CapabilityScript.transform_source_behavior(
		mock_inventory,
		"nonexistent",
		"new_behavior",
		{})
	assert_false(result.get("success", false), "变形不存在的来源应失败")

## ============================================================================
## 辅助函数
## ============================================================================

func _create_mock_side(owner_id: String):
	var side := RefCounted.new()
	side.set_meta("owner_id", owner_id)
	side.set_meta("name", owner_id)
	side.owner_id = owner_id
	side.name = owner_id
	return side

func _create_mock_source(source_kind: String, instance_key: String, behavior_id: String):
	var source := RefCounted.new()
	source.set_meta("source_kind", source_kind)
	source.set_meta("source_instance_key", instance_key)
	source.set_meta("content_id", "test_content")
	source.set_meta("behavior_id", behavior_id)
	source.source_kind = source_kind
	source.source_instance_key = instance_key
	source.content_id = "test_content"
	source.behavior_id = behavior_id
	return source

func _create_mock_plan():
	var plan := RefCounted.new()
	plan.set_meta("invocations", [])
	plan.invocations = []
	return plan

func _create_mock_growth_inventory():
	var inventory := RefCounted.new()
	inventory.set_meta("equipped_inner_skills", [
		{
			"source_instance_key": "inner-001",
			"content_id": "test_inner_skill",
			"behavior_id": "original_behavior",
		}
	])
	inventory.equipped_inner_skills = [
		{
			"source_instance_key": "inner-001",
			"content_id": "test_inner_skill",
			"behavior_id": "original_behavior",
		}
	]
	return inventory
