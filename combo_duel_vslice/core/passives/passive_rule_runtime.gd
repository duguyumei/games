class_name PassiveRuleRuntime
extends RefCounted

const ContextScript = preload("res://core/passives/passive_rule_context.gd")
const SourceResolverScript = preload(
    "res://core/passives/passive_rule_source_resolver.gd")
const SourceScript = preload("res://core/passives/passive_rule_source.gd")
const SuppressionServiceScript = preload(
    "res://core/passives/passive_suppression_service.gd")
const ActivationPolicyScript = preload(
    "res://core/passives/passive_rule_activation_policy.gd")
const InvocationScript = preload(
    "res://core/passives/passive_rule_invocation.gd")
const ExecutionPlanScript = preload(
    "res://core/passives/passive_rule_execution_plan.gd")
const CapacityPolicyScript = preload(
    "res://core/passives/inner_skill_capacity_policy.gd")
const CounterReadPortScript = preload(
    "res://core/passives/passive_counter_read_port.gd")
const CounterMutationPortScript = preload(
    "res://core/passives/passive_counter_mutation_port.gd")
const BattleCounterReadPortScript = preload(
    "res://core/passives/battle_passive_counter_read_port.gd")
const BattleCounterMutationPortScript = preload(
    "res://core/passives/battle_passive_counter_mutation_port.gd")
const SourceBehaviorTransformationPortScript = preload(
    "res://core/passives/source_behavior_transformation_port.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

const BATTLE_MUTATION_HOOKS := \
    BattleEventCatalogScript.TIMING_EVENTS \
    + BattleEventCatalogScript.COMMITTED_EVENTS \
    + BattleEventCatalogScript.LIFECYCLE_MUTATION_HOOKS

var registry
var source_resolver
var suppression_service
var activation_policy
var capacity_policy
var _battle_effect_ports_ref: WeakRef
var _effect_executor_ref: WeakRef
var _battle_effect_scenario_error: Callable
var _battle_effect_invocation_receipts: Dictionary = {}
var _active_effect_chain: Dictionary = {}
var _effect_execution_depth: int = 0

func _init(
        handler_registry,
        content_catalog = null,
        suppression_override = null,
        activation_override = null,
        resolver_override = null) -> void:
    registry = handler_registry
    source_resolver = (
        resolver_override
        if resolver_override != null
        else SourceResolverScript.new(content_catalog))
    suppression_service = (
        suppression_override
        if suppression_override != null
        else SuppressionServiceScript.new())
    activation_policy = (
        activation_override
        if activation_override != null
        else ActivationPolicyScript.new(suppression_service))
    capacity_policy = CapacityPolicyScript.new(self)

func use_battle_effect_ports(
        ports,
        scenario_error_callback: Callable = Callable()) -> void:
    _battle_effect_ports_ref = weakref(ports) if ports != null else null
    _battle_effect_scenario_error = scenario_error_callback

func use_effect_executor(executor) -> void:
    _effect_executor_ref = weakref(executor) if executor != null else null
    if registry != null and registry.has_method("use_effect_registry") \
            and executor != null:
        registry.use_effect_registry(executor.registry)

func open_battle_effect_commands(_battle_instance_id: String = "") -> void:
    _battle_effect_invocation_receipts.clear()
    _active_effect_chain.clear()
    _effect_execution_depth = 0

func close_battle_effect_commands() -> void:
    _battle_effect_invocation_receipts.clear()
    _active_effect_chain.clear()
    _effect_execution_depth = 0

func capture_battle_effect_command_state() -> Dictionary:
    return {
        "invocation_receipts": _battle_effect_invocation_receipts.duplicate(true),
        "active_effect_chain": _active_effect_chain.duplicate(true),
        "effect_execution_depth": _effect_execution_depth,
    }

func restore_battle_effect_command_state(state: Dictionary) -> void:
    _battle_effect_invocation_receipts = state.get(
        "invocation_receipts", {}).duplicate(true)
    _active_effect_chain = state.get("active_effect_chain", {}).duplicate(true)
    _effect_execution_depth = int(state.get("effect_execution_depth", 0))

func coerce_context(value):
    if value is ContextScript:
        return value
    if value is Dictionary:
        return ContextScript.new().configure(value)
    return ContextScript.new().configure({"owner": value})

func collect_sources(context) -> Array:
    return source_resolver.collect_sources(coerce_context(context))

func content_catalog():
    return source_resolver.content_catalog() \
        if source_resolver != null and source_resolver.has_method(
            "content_catalog") else null

func capture_source_snapshot(context) -> Array:
    return source_resolver.capture_source_snapshot(coerce_context(context))

func equipped_inner_skill_entries(context) -> Array:
    return source_resolver.equipped_inner_skill_entries(
        coerce_context(context))

func has_content(source_kind: String, content_id: String) -> bool:
    var catalog = content_catalog()
    if catalog == null:
        return false
    return catalog.has_id(
        "inner_skill" if source_kind == "inner_skill" else "item",
        content_id)

func is_source_active(source, hook: String, context):
    return activation_policy.is_source_active(
        source, hook, coerce_context(context))

func is_source_identity_active(
        source_kind: String,
        content_id: String,
        source_instance_key: String,
        hook: String,
        _owner = null,
        round_number: int = 0) -> bool:
    if suppression_service == null:
        return true
    var source = SourceScript.new().configure({
        "source_kind": source_kind,
        "content_id": content_id,
        "source_instance_key": source_instance_key,
        "behavior_id": "source_contribution",
        "definition": {},
        "configuration": {},
    })
    return suppression_service.blockers_for(source, hook, round_number).is_empty()

func resolve_inner_skill_capacity(
        growth_or_context,
        proposed_equipped_inner_skill_ids: Array = []) -> Dictionary:
    var context = coerce_context(growth_or_context)
    context.has_proposed_inner_skill_ids = true
    context.proposed_equipped_inner_skill_ids = proposed_equipped_inner_skill_ids.duplicate()
    return capacity_policy.resolve(context, proposed_equipped_inner_skill_ids)

## 在战斗生命周期装配时一次性建立随机/锁定投影。查询与 build_execution_plan
## 只读取这些记录，因此预览、AI 与只读查询不会推进 RNG 或写状态。
func prepare_battle_projections(
        sides: Array, rng: RandomNumberGenerator) -> Dictionary:
    var snapshots: Array = []
    for side in sides:
        var store = _property_value(side, "passive_behavior_projection_store")
        if store != null:
            snapshots.append({"store": store, "state": store.capture_state()})
    var rng_state := int(rng.state) if rng != null else 0
    for side in sides:
        if side == null:
            continue
        var context = coerce_context({"owner": side})
        var raw_sources := collect_sources(context)
        var random_result := _prepare_locked_mode(
            "battle_locked_random_other", side, context, raw_sources, rng, -1)
        if not random_result.get("success", false):
            _restore_projection_preparation(snapshots, rng, rng_state)
            return random_result
    for side in sides:
        if side == null:
            continue
        var context = coerce_context({"owner": side})
        var raw_sources := collect_sources(context)
        var equipped_count: int = source_resolver.equipped_inner_skill_entries(
            context).size()
        var equipped_value = _property_value(side, "equipped_inner_skill_ids")
        var equipped_ids: Array = (
            equipped_value if equipped_value is Array else [])
        var capacity := resolve_inner_skill_capacity(
            context, equipped_ids)
        if not capacity.get("errors", []).is_empty():
            _restore_projection_preparation(snapshots, rng, rng_state)
            return {
                "success": false,
                "reason": "锁定被动投影的容量查询失败：%s" % "；".join(
                    capacity.get("errors", [])),
            }
        var empty_slots := maxi(
            0, int(capacity.get("effective_capacity", 0)) - equipped_count)
        var repeat_result := _prepare_locked_mode(
            "battle_locked_leftmost_repeat", side, context,
            raw_sources, rng, empty_slots)
        if not repeat_result.get("success", false):
            _restore_projection_preparation(snapshots, rng, rng_state)
            return repeat_result
    return {"success": true}

## Run committed 事件中把当前来源永久替换为另一门已装备内功的可复制
## 正文。选择使用事件身份派生的稳定随机，不占用战斗 RNG，也不会因重试
## 得到不同目标；真正结果写入 GrowthInventory 的事务状态。
func commit_source_behavior_transformation(source, context) -> Dictionary:
    if source == null or context == null or context.owner == null:
        return {"success": false, "reason": "来源行为替换缺少来源或 owner"}
    if source.source_kind != "inner_skill" or source.is_projected():
        return {"success": false, "reason": "只有未投影的内功来源可以永久替换正文"}
    var store = _property_value(
        context.owner, "source_behavior_transformation_store")
    if store == null:
        return {"success": false, "reason": "owner 缺少来源行为替换 Store"}
    if store.has_record(source):
        var existing: Dictionary = store.record_for(source)
        return {
            "success": true,
            "transformed": true,
            "reused": true,
            "target_content_id": str(existing.get(
                "target_content_id", "")),
            "target_behaviors": existing.get(
                "target_behaviors", []).duplicate(true),
        }
    var raw_sources: Array = source_resolver.collect_sources(
        coerce_context({"owner": context.owner}))
    var groups: Array = _inner_source_groups(raw_sources)
    var candidates: Array = _eligible_target_groups(source, groups)
    if candidates.is_empty():
        return {
            "success": true,
            "transformed": false,
            "no_legal_target": true,
        }
    var selected: Dictionary = candidates[_stable_transformation_index(
        source, context, candidates.size())]
    var target_values := _persistent_target_values(selected)
    var locked: Dictionary = store.lock(source, target_values)
    if not locked.get("success", false):
        return locked
    return {
        "success": true,
        "transformed": true,
        "reused": bool(locked.get("reused", false)),
        "target_content_id": str(target_values.get(
            "target_content_id", "")),
        "target_behaviors": target_values.get(
            "target_behaviors", []).duplicate(true),
    }

func effective_sources(context) -> Dictionary:
    var resolved_context = coerce_context(context)
    var raw_sources := collect_sources(resolved_context)
    var expanded := _expand_projected_sources(raw_sources, resolved_context)
    expanded["raw_sources"] = raw_sources
    return expanded

func build_execution_plan(hook: String, context):
    var resolved_context = coerce_context(context)
    resolved_context.hook = hook
    var plan = ExecutionPlanScript.new().configure({"hook": hook})
    if not registry.has_hook(hook):
        plan.errors.append("未知被动 hook：%s" % hook)
        return plan
    var source_result := effective_sources(resolved_context)
    if not source_result.get("success", false):
        plan.errors.append_array(source_result.get("errors", []))
        return plan
    var raw_sources: Array = source_result.get("raw_sources", [])
    var sources: Array = source_result.get("sources", [])
    for source in sources:
        if hook == "experience_change_resolved":
            var ancestry = resolved_context.payload.get(
                "experience_response_ancestry", [])
            var behavior_key: String = source.behavior_ancestry_key()
            if ancestry is Array and ancestry.has(behavior_key):
                continue
        var handler = registry.handler(source.behavior_id)
        if handler == null:
            plan.errors.append("未注册的被动行为：%s" % source.behavior_id)
            continue
        if not handler.supported_hooks().has(hook):
            continue
        var activation = is_source_active(source, hook, resolved_context)
        plan.activations.append({
            "source": source,
            "activation": activation,
        })
        if not activation.active:
            continue
        var repeat: Dictionary = _resolve_additional_executions(
            source, raw_sources, resolved_context)
        if not repeat.get("success", false):
            plan.errors.append(str(repeat.get("reason", "额外执行次数无效")))
            continue
        var execution_count := 1 + int(repeat.get("additional_executions", 0))
        if execution_count < 0:
            plan.errors.append("被动执行次数必须是非负整数：%s" % source.source_instance_key)
            continue
        for execution_index in range(execution_count):
            plan.invocations.append(InvocationScript.new().configure({
                "source": source,
                "hook": hook,
                "execution_index": execution_index,
                "execution_count": execution_count,
                "repeat_origin": repeat.get("repeat_origin", []),
                "context": resolved_context,
            }))
    return plan

func dispatch_event(
        hook: String,
        context,
        counter_access: String = "none") -> Dictionary:
    if hook == "action_preview" and counter_access == "none":
        counter_access = "read"
    var plan = build_execution_plan(hook, context)
    var results: Array = []
    if not plan.is_valid():
        return {"success": false, "plan": plan, "results": results, "errors": plan.errors.duplicate()}
    for invocation in plan.invocations:
        var executed: Dictionary = execute_invocation(
            invocation, null, counter_access)
        results.append(executed)
        if not executed.get("success", false):
            return {
                "success": false,
                "plan": plan,
                "results": results,
                "errors": [str(executed.get("reason", "被动行为执行失败"))],
            }
    return {"success": true, "plan": plan, "results": results, "errors": []}

func execute_invocation(
        invocation,
        context_override = null,
        counter_access: String = "none") -> Dictionary:
    var invocation_context = (
        context_override
        if context_override != null
        else invocation.context.for_invocation(invocation))
    var mutation_hook: bool = invocation.hook in BATTLE_MUTATION_HOOKS
    if mutation_hook:
        _begin_effect_chain()
    if invocation_context.has_method("use_battle_effect_ports"):
        invocation_context.use_battle_effect_ports(null, {})
    var ports: Array = _attach_counter_ports(
        invocation.source, invocation_context, counter_access)
    var result: Dictionary = registry.execute(
        invocation.source.behavior_id,
        invocation.hook,
        invocation_context,
        invocation.source.configuration)
    var port_errors: Array[String] = []
    for port in ports:
        if not port.is_valid():
            port_errors.append_array(port.errors())
    if not port_errors.is_empty():
        result = {
            "success": false,
            "reason": "；".join(port_errors),
        }
    if result.get("success", false) \
            and mutation_hook \
            and invocation.hook != "action_resolve" \
            and result.get("effects") is Array \
            and not result.get("effects", []).is_empty():
        result = _execute_standard_effects(
            invocation, invocation_context, result)
    # The scoped port retains its Invocation context while the Handler runs.  Clear
    # both references before returning so a RefCounted context/port cycle cannot
    # survive a completed event.
    invocation_context.source_behavior_transformation_port = null
    if mutation_hook:
        _end_effect_chain()
    if not result.get("success", false):
        return {
            "success": false,
            "reason": "%s · %s · %s：%s" % [
                invocation.hook,
                invocation.source.source_instance_key,
                invocation.source.behavior_id,
                str(result.get("reason", "被动行为执行失败"))],
            "source": invocation.source,
            "invocation": invocation,
            "result": result,
        }
    return {
        "success": true,
        "source": invocation.source,
        "invocation": invocation,
        "result": result,
    }

func _execute_standard_effects(
        invocation,
        context,
        handler_result: Dictionary) -> Dictionary:
    var executor = _effect_executor_ref.get_ref() \
        if _effect_executor_ref != null else null
    var effect_ports = _battle_effect_ports_ref.get_ref() \
        if _battle_effect_ports_ref != null else null
    if executor == null or effect_ports == null:
        return {"success": false, "reason": "被动标准效果执行入口尚未装配"}
    var receipt_token := _effect_invocation_token(invocation, context)
    if _battle_effect_invocation_receipts.has(receipt_token):
        var reused: Dictionary = _battle_effect_invocation_receipts[
            receipt_token].duplicate(true)
        reused["reused"] = true
        return reused
    var effect_context = context.effect_context_for(invocation.source)
    effect_context.ports = effect_ports
    effect_context.effect_chain_state = _active_effect_chain
    effect_context.effect_execution_scope_token = receipt_token
    if invocation.hook == "experience_change_resolved":
        var ancestry: Array = _active_effect_chain.get(
            "experience_response_ancestry", []).duplicate()
        var behavior_key: String = invocation.source.behavior_ancestry_key()
        if not ancestry.has(behavior_key):
            ancestry.append(behavior_key)
        _active_effect_chain["experience_response_ancestry"] = ancestry
    var executed: Dictionary = executor.execute_all(
        handler_result.get("effects", []), effect_context)
    if executed.get("pending_choice", false):
        if bool(context.payload.get("lifecycle_choice_managed", false)):
            return {
                "success": true,
                "pending_choice": true,
                "effect_result": executed,
                "effect_continuation": executed.get("_continuation"),
                "choice_request": executed.get(
                    "choice_request", {}).duplicate(true),
                "receipt_token": receipt_token,
                "handler_result": handler_result.duplicate(true),
            }
        return {
            "success": false,
            "reason": "%s 不允许悬挂未接管的被动选择；请在 action_resolve 建立选择链" \
                % invocation.hook,
        }
    if not executed.get("success", false):
        var reason := str(executed.get("detail", "被动标准效果执行失败"))
        if _battle_effect_scenario_error.is_valid():
            _battle_effect_scenario_error.call(
                "战斗被动标准效果失败：%s" % reason)
        return {"success": false, "reason": reason, "effect_result": executed}
    var result := handler_result.duplicate(true)
    result["effect_result"] = executed
    result["receipt_token"] = receipt_token
    result["reused"] = false
    _battle_effect_invocation_receipts[receipt_token] = result.duplicate(true)
    return result

func resume_managed_invocation_effects(
        invocation,
        context,
        continuation,
        request_id: String,
        selected_ids: Array,
        receipt_token: String,
        handler_result: Dictionary) -> Dictionary:
    if not bool(context.payload.get("lifecycle_choice_managed", false)):
        return {"success": false, "reason": "当前被动选择没有生命周期接管者"}
    var executor = _effect_executor_ref.get_ref() \
        if _effect_executor_ref != null else null
    if executor == null:
        return {"success": false, "reason": "被动标准效果执行入口尚未装配"}
    _begin_effect_chain()
    var resumed: Dictionary = executor.resume(
        continuation, request_id, selected_ids)
    _end_effect_chain()
    if resumed.get("pending_choice", false):
        return {
            "success": true,
            "pending_choice": true,
            "effect_result": resumed,
            "effect_continuation": resumed.get("_continuation"),
            "choice_request": resumed.get("choice_request", {}).duplicate(true),
            "receipt_token": receipt_token,
            "handler_result": handler_result.duplicate(true),
        }
    if not resumed.get("success", false):
        var reason := str(resumed.get("detail", "被动选择恢复失败"))
        if _battle_effect_scenario_error.is_valid():
            _battle_effect_scenario_error.call(
                "战斗被动标准效果失败：%s" % reason)
        return {"success": false, "reason": reason, "effect_result": resumed}
    var result := handler_result.duplicate(true)
    result["effect_result"] = resumed
    result["receipt_token"] = receipt_token
    result["reused"] = false
    _battle_effect_invocation_receipts[receipt_token] = result.duplicate(true)
    return result

func _effect_invocation_token(invocation, context) -> String:
    var effect_ports = _battle_effect_ports_ref.get_ref() \
        if _battle_effect_ports_ref != null else null
    var battle_id: String = effect_ports.battle_instance_id() \
        if effect_ports != null else "battle-unavailable"
    var semantic_token := str(context.battle_effect_scope.get(
        "event_token", context.payload.get("event_token", "")))
    if semantic_token == "":
        semantic_token = str(context.battle_effect_scope.get(
            "action_token", context.payload.get("action_token", "")))
    if semantic_token == "":
        semantic_token = "%s:%s" % [
            invocation.hook,
            str(context.battle_effect_scope.get("timing_serial", -1))]
    var projection_suffix := (
        "|projection:%s" % invocation.source.projection_key().sha256_text().left(16)
        if invocation.source.is_projected() else "")
    return "%s|%s|%s|%d|%d%s" % [
        battle_id,
        semantic_token,
        invocation.source.source_instance_key,
        invocation.source.behavior_index,
        invocation.execution_index,
        projection_suffix,
    ]

func _begin_effect_chain() -> void:
    if _effect_execution_depth == 0:
        _active_effect_chain = {"command_count": 0}
    _effect_execution_depth += 1

func _end_effect_chain() -> void:
    _effect_execution_depth = maxi(0, _effect_execution_depth - 1)
    if _effect_execution_depth == 0:
        _active_effect_chain = {}

func source_fingerprint(hooks: Array, context) -> Dictionary:
    var values: Array = []
    var errors: Array[String] = []
    for hook_value in hooks:
        var hook := str(hook_value)
        var plan = build_execution_plan(hook, context)
        if not plan.is_valid():
            errors.append_array(plan.errors)
            continue
        values.append(execution_plan_fingerprint_values(plan))
    return {
        "success": errors.is_empty(),
        "fingerprint": (
            JSON.stringify(values[0]).sha256_text()
            if values.size() == 1
            else JSON.stringify(values).sha256_text()),
        "errors": errors,
        "plans": values,
    }

func execution_plan_fingerprint(plan) -> String:
    return JSON.stringify(execution_plan_fingerprint_values(plan)).sha256_text()

func execution_plan_fingerprint_values(plan) -> Dictionary:
    var activations: Array = []
    for entry in plan.activations:
        activations.append({
            "source_instance_key": entry["source"].source_instance_key,
            "behavior_id": entry["source"].behavior_id,
            "plan_identity": entry["source"].plan_identity(),
            "projection": entry["source"].projection.duplicate(true),
            "active": entry["activation"].active,
            "blocked_by": entry["activation"].blocked_by.duplicate(),
        })
    var invocations: Array = []
    for invocation in plan.invocations:
        invocations.append({
            "source_instance_key": invocation.source.source_instance_key,
            "behavior_id": invocation.source.behavior_id,
            "behavior_index": invocation.source.behavior_index,
            "plan_identity": invocation.source.plan_identity(),
            "projection": invocation.source.projection.duplicate(true),
            "execution_index": invocation.execution_index,
            "execution_count": invocation.execution_count,
            "repeat_origin": invocation.repeat_origin.duplicate(),
        })
    return {
        "hook": plan.hook,
        "activations": activations,
        "invocations": invocations,
    }

func query_modifiers(hook: String, context) -> Dictionary:
    return dispatch_event(hook, context, "read")

func execution_counts_for(hook: String, context) -> Dictionary:
    var plan = build_execution_plan(hook, context)
    var result: Dictionary = {}
    for invocation in plan.invocations:
        result[invocation.source.source_instance_key] = invocation.execution_count
    return result

func _resolve_additional_executions(target_source, sources: Array, context) -> Dictionary:
    var additional := 0
    var origins: Array[String] = []
    var query_context = context.for_plan_target(target_source)
    for provider_source in sources:
        var handler = registry.handler(provider_source.behavior_id)
        if handler == null \
                or not handler.supported_hooks().has("passive_invocation_plan_query"):
            continue
        var activation = is_source_active(
            provider_source, "passive_invocation_plan_query", query_context)
        if not activation.active:
            continue
        var ports: Array = _attach_counter_ports(
            provider_source, query_context, "read")
        var result: Dictionary = registry.execute(
            provider_source.behavior_id,
            "passive_invocation_plan_query",
            query_context,
            provider_source.configuration)
        var port_errors: Array[String] = []
        for port in ports:
            if not port.is_valid():
                port_errors.append_array(port.errors())
        if not port_errors.is_empty():
            return {"success": false, "reason": "；".join(port_errors)}
        if not result.get("success", false):
            return result
        if not _repeat_result_targets(result, target_source):
            continue
        var value = result.get("additional_executions", 0)
        if not value is int or int(value) < 0:
            return {
                "success": false,
                "reason": "additional_executions 必须是确定的非负整数",
            }
        additional += int(value)
        if int(value) > 0:
            origins.append(provider_source.source_instance_key)
    return {
        "success": true,
        "additional_executions": additional,
        "repeat_origin": origins,
    }

func _repeat_result_targets(result: Dictionary, target_source) -> bool:
    if result.has("target_instance_key") \
            and str(result["target_instance_key"]) != target_source.source_instance_key:
        return false
    if result.has("target_content_id") \
            and str(result["target_content_id"]) != target_source.content_id:
        return false
    if result.has("target_source_kind") \
            and str(result["target_source_kind"]) != target_source.source_kind:
        return false
    return true

func _prepare_locked_mode(
        mode: String,
        owner,
        context,
        raw_sources: Array,
        rng: RandomNumberGenerator,
        additional_executions: int) -> Dictionary:
    var store = _property_value(owner, "passive_behavior_projection_store")
    if store == null:
        return {"success": false, "reason": "战斗参与方缺少被动投影状态 Store"}
    var groups := _inner_source_groups(raw_sources)
    var providers := _projection_providers(raw_sources, mode)
    for provider in providers:
        if store.has_record(provider):
            continue
        var candidates := _eligible_target_groups(provider, groups)
        var selected: Dictionary = {}
        if mode == "battle_locked_random_other" and not candidates.is_empty():
            if rng == null:
                return {"success": false, "reason": "随机被动投影缺少战斗 RNG"}
            selected = candidates[int(rng.randi_range(0, candidates.size() - 1))]
        elif mode == "battle_locked_leftmost_repeat" \
                and not candidates.is_empty():
            selected = candidates[0]
        var values := {
            "mode": mode,
            "has_target": not selected.is_empty(),
            "additional_executions": (
                additional_executions
                if mode == "battle_locked_leftmost_repeat" else 0),
        }
        if not selected.is_empty():
            values.merge(_locked_target_values(selected), true)
        var locked: Dictionary = store.lock(provider, values)
        if not locked.get("success", false):
            return locked
    return {"success": true}

func _restore_projection_preparation(
        snapshots: Array,
        rng: RandomNumberGenerator,
        rng_state: int) -> void:
    for entry in snapshots:
        entry["store"].replace_state(entry["state"])
    if rng != null:
        rng.state = rng_state

func _projection_providers(sources: Array, expected_mode: String = "") -> Array:
    var result: Array = []
    for source in sources:
        if source.is_projected():
            continue
        var spec: Dictionary = registry.copy_projection_spec(
            source.behavior_id, source.configuration)
        if spec.is_empty():
            continue
        if expected_mode != "" and str(spec.get("mode", "")) != expected_mode:
            continue
        result.append(source)
    result.sort_custom(Callable(self, "_source_less"))
    return result

func _expand_projected_sources(
        raw_sources: Array, context) -> Dictionary:
    var result: Array = raw_sources.duplicate()
    var errors: Array[String] = []
    var groups := _inner_source_groups(raw_sources)
    for provider in _projection_providers(raw_sources):
        var spec: Dictionary = registry.copy_projection_spec(
            provider.behavior_id, provider.configuration)
        var mode := str(spec.get("mode", ""))
        var target_sources: Array = []
        if mode == "live_left_adjacent":
            var target_group: Dictionary = _live_left_target_group(
                provider, groups)
            if not target_group.is_empty():
                target_sources = _copyable_group_sources(target_group)
        elif mode == "battle_locked_random_other":
            var locked := _locked_target_sources(provider, context, raw_sources)
            if not locked.get("success", false):
                errors.append(str(locked.get(
                    "reason", "锁定被动投影目标无效")))
                continue
            target_sources = locked.get("sources", [])
        elif mode == "battle_locked_leftmost_repeat":
            continue
        else:
            errors.append("未知被动行为投影模式：%s" % mode)
            continue
        for target_source in target_sources:
            result.append(_project_source(provider, target_source))
    result.sort_custom(Callable(self, "_source_less"))
    return {
        "success": errors.is_empty(),
        "sources": result,
        "errors": errors,
    }

func _inner_source_groups(sources: Array) -> Array:
    var by_key: Dictionary = {}
    for source in sources:
        if source.source_kind != "inner_skill" or source.is_projected():
            continue
        var key := str(source.source_instance_key)
        if not by_key.has(key):
            by_key[key] = {
                "source_instance_key": key,
                "content_id": str(source.content_id),
                "source_order": int(source.source_order),
                "slot_index": int(source.slot_index),
                "content_instance_ordinal": int(
                    source.content_instance_ordinal),
                "sources": [],
            }
        by_key[key]["sources"].append(source)
    var result: Array = by_key.values()
    result.sort_custom(func(left, right):
        if int(left["slot_index"]) != int(right["slot_index"]):
            return int(left["slot_index"]) < int(right["slot_index"])
        return str(left["source_instance_key"]) < str(right["source_instance_key"]))
    return result

func _eligible_target_groups(provider, groups: Array) -> Array:
    var result: Array = []
    for group_value in groups:
        var group: Dictionary = group_value
        if str(group["source_instance_key"]) == provider.source_instance_key:
            continue
        if _copyable_group_sources(group).is_empty():
            continue
        result.append(group)
    result.sort_custom(func(left, right):
        if int(left["source_order"]) != int(right["source_order"]):
            return int(left["source_order"]) < int(right["source_order"])
        return str(left["source_instance_key"]) < str(right["source_instance_key"]))
    return result

func _live_left_target_group(provider, groups: Array) -> Dictionary:
    var expected_slot := int(provider.slot_index) - 1
    for group_value in groups:
        var group: Dictionary = group_value
        if int(group["slot_index"]) != expected_slot:
            continue
        if _copyable_group_sources(group).is_empty():
            return {}
        return group
    return {}

func _copyable_group_sources(group: Dictionary) -> Array:
    var sources: Array = group.get("sources", [])
    ## 复制类内功整体不可成为目标，即使同一内容还声明了其他普通 behavior。
    for source in sources:
        if not registry.copy_projection_spec(
                source.behavior_id, source.configuration).is_empty():
            return []
    var result: Array = []
    for source in sources:
        if bool(source.behavior_copyable) and registry.allows_behavior_copy(
                source.behavior_id, source.configuration):
            result.append(source)
    result.sort_custom(func(left, right):
        return int(left.behavior_index) < int(right.behavior_index))
    return result

func _locked_target_values(group: Dictionary) -> Dictionary:
    var behaviors: Array = []
    for source in _copyable_group_sources(group):
        behaviors.append({
            "source_kind": str(source.source_kind),
            "content_id": str(source.content_id),
            "source_instance_key": str(source.source_instance_key),
            "source_order": int(source.source_order),
            "slot_index": int(source.slot_index),
            "content_instance_ordinal": int(
                source.content_instance_ordinal),
            "behavior_id": str(source.behavior_id),
            "behavior_index": int(source.behavior_index),
        })
    return {
        "target_source_kind": "inner_skill",
        "target_content_id": str(group["content_id"]),
        "target_source_instance_key": str(group["source_instance_key"]),
        "target_source_order": int(group["source_order"]),
        "target_slot_index": int(group["slot_index"]),
        "target_content_instance_ordinal": int(
            group["content_instance_ordinal"]),
        "target_behaviors": behaviors,
    }

func _persistent_target_values(group: Dictionary) -> Dictionary:
    var behaviors: Array = []
    for source in _copyable_group_sources(group):
        behaviors.append({
            "behavior_id": str(source.behavior_id),
            "behavior_index": int(source.behavior_index),
        })
    return {
        "target_content_id": str(group.get("content_id", "")),
        "target_behaviors": behaviors,
    }

func _stable_transformation_index(
        source,
        context,
        candidate_count: int) -> int:
    if candidate_count <= 1:
        return 0
    var identity := JSON.stringify({
        "run_seed": int(context.get("run_seed")),
        "act": int(context.get("act")),
        "node_id": str(context.get("node_id")),
        "transaction_token": str(context.get("transaction_token")),
        "source_kind": str(source.source_kind),
        "content_id": str(source.content_id),
        "content_instance_ordinal": int(source.content_instance_ordinal),
        "behavior_index": int(source.behavior_index),
    }).sha256_text()
    return posmod(identity.hash(), candidate_count)

func _locked_target_sources(
        provider, context, raw_sources: Array) -> Dictionary:
    var owner = context.owner if context != null else null
    var store = _property_value(owner, "passive_behavior_projection_store")
    if store == null:
        return {"success": true, "sources": []}
    var record: Dictionary = store.record_for(provider)
    if record.is_empty() or not bool(record.get("has_target", false)):
        return {"success": true, "sources": []}
    var by_identity: Dictionary = {}
    for source in raw_sources:
        by_identity["%s|%d" % [
            source.source_instance_key, source.behavior_index]] = source
    var result: Array = []
    for descriptor_value in record.get("target_behaviors", []):
        if not descriptor_value is Dictionary:
            return {"success": false, "reason": "锁定投影包含无效行为描述"}
        var descriptor: Dictionary = descriptor_value
        var identity := "%s|%d" % [
            str(descriptor.get("source_instance_key", "")),
            int(descriptor.get("behavior_index", -1))]
        var target_source = by_identity.get(identity)
        if target_source == null:
            target_source = source_resolver.source_from_descriptor(descriptor)
        if target_source == null:
            return {
                "success": false,
                "reason": "无法恢复锁定投影行为：%s" % identity,
            }
        if not bool(target_source.behavior_copyable) \
                or not registry.allows_behavior_copy(
                    target_source.behavior_id, target_source.configuration):
            continue
        result.append(target_source)
    return {"success": true, "sources": result}

func _project_source(provider, target_source):
    var projection_key := "projection|%s|%d|%s|%d" % [
        provider.source_instance_key,
        provider.behavior_index,
        target_source.source_instance_key,
        target_source.behavior_index,
    ]
    var counter_instance_key := "copy_%d_projection_%d_%s_%d" % [
        maxi(0, int(provider.content_instance_ordinal)),
        int(provider.behavior_index),
        str(target_source.content_id),
        int(target_source.behavior_index),
    ]
    return SourceScript.new().configure({
        "source_kind": provider.source_kind,
        "content_id": provider.content_id,
        "source_instance_key": provider.source_instance_key,
        "definition": provider.definition,
        "behavior_id": target_source.behavior_id,
        "behavior_index": target_source.behavior_index,
        "state_key": target_source.state_key,
        "configuration": target_source.configuration,
        "source_order": provider.source_order,
        "slot_index": provider.slot_index,
        "content_instance_ordinal": provider.content_instance_ordinal,
        "behavior_copyable": false,
        "projection": {
            "projection_key": projection_key,
            "provider_content_id": str(provider.content_id),
            "provider_source_instance_key": str(provider.source_instance_key),
            "provider_behavior_id": str(provider.behavior_id),
            "provider_behavior_index": int(provider.behavior_index),
            "target_content_id": str(target_source.content_id),
            "target_source_instance_key": str(
                target_source.source_instance_key),
            "target_behavior_id": str(target_source.behavior_id),
            "target_behavior_index": int(target_source.behavior_index),
        },
        "counter_instance_key": counter_instance_key,
        "counter_definition_source_kind": target_source.source_kind,
        "counter_definition_content_id": target_source.content_id,
        "counter_definition_behavior_id": target_source.behavior_id,
        "counter_definition_behavior_index": target_source.behavior_index,
        "source_marker_definitions": target_source.source_marker_definitions,
    })

func _source_less(left, right) -> bool:
    if int(left.source_order) != int(right.source_order):
        return int(left.source_order) < int(right.source_order)
    if str(left.source_instance_key) != str(right.source_instance_key):
        return str(left.source_instance_key) < str(right.source_instance_key)
    if bool(left.is_projected()) != bool(right.is_projected()):
        return not left.is_projected()
    if int(left.behavior_index) != int(right.behavior_index):
        return int(left.behavior_index) < int(right.behavior_index)
    return str(left.plan_identity()) < str(right.plan_identity())

func _attach_counter_ports(source, context, access: String) -> Array:
    context.counter_read_port = null
    context.counter_mutation_port = null
    context.persistent_counter_read_port = null
    context.persistent_counter_mutation_port = null
    context.battle_counter_read_port = null
    context.battle_counter_mutation_port = null
    context.source_behavior_transformation_port = null
    # Handler 即使不声明任何计数器，也仍需通过 Invocation context 读取自己的
    # 来源身份；不能把 source 注入与计数器端口是否存在绑定在一起。
    context.source = source
    var result: Array = []
    if access == "none" or context.owner == null:
        return result
    if access == "mutation" \
            and _property_value(
                context.owner, "source_behavior_transformation_store") != null:
        context.source_behavior_transformation_port = (
            SourceBehaviorTransformationPortScript.new(
                self, source, context))
    var persistent_store = _property_value(
        context.owner, "passive_counter_store")
    if persistent_store != null:
        var persistent_definitions: Array = registry.counter_definitions(
            source.behavior_id, source.configuration)
        var persistent_port = (
            CounterMutationPortScript.new(
                persistent_store, source, persistent_definitions)
            if access == "mutation"
            else CounterReadPortScript.new(
                persistent_store, source, persistent_definitions))
        context.counter_read_port = persistent_port
        context.persistent_counter_read_port = persistent_port
        if access == "mutation":
            context.counter_mutation_port = persistent_port
            context.persistent_counter_mutation_port = persistent_port
        result.append(persistent_port)
    var battle_store = _property_value(
        context.owner, "battle_passive_counter_store")
    if battle_store != null:
        var battle_definitions: Array = registry.battle_counter_definitions(
            source.behavior_id, source.configuration)
        var owner_id := str(_property_value(context.owner, "owner_id"))
        var battle_port = (
            BattleCounterMutationPortScript.new(
                battle_store, owner_id, source, battle_definitions)
            if access == "mutation"
            else BattleCounterReadPortScript.new(
                battle_store, owner_id, source, battle_definitions))
        context.battle_counter_read_port = battle_port
        if access == "mutation":
            context.battle_counter_mutation_port = battle_port
        result.append(battle_port)
    return result

func _property_value(owner, property_name: String):
    if owner == null or not owner.has_method("get_property_list"):
        return null
    for property in owner.get_property_list():
        if str(property.get("name", "")) == property_name:
            return owner.get(property_name)
    return null
