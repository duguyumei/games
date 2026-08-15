class_name PassiveRuleRuntime
extends RefCounted

const ContextScript = preload("res://core/passives/passive_rule_context.gd")
const SourceResolverScript = preload(
    "res://core/passives/passive_rule_source_resolver.gd")
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
const BattlePassiveEffectPortsScript = preload(
    "res://core/passives/battle_passive_effect_ports.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

const BATTLE_MUTATION_HOOKS := \
    BattleEventCatalogScript.TIMING_EVENTS + BattleEventCatalogScript.COMMITTED_EVENTS

var registry
var source_resolver
var suppression_service
var activation_policy
var capacity_policy
var _battle_effect_ports_ref: WeakRef
var _battle_effect_scenario_error: Callable
var _battle_effect_command_receipts: Dictionary = {}
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

func open_battle_effect_commands(_battle_instance_id: String = "") -> void:
    _battle_effect_command_receipts.clear()
    _active_effect_chain.clear()
    _effect_execution_depth = 0

func close_battle_effect_commands() -> void:
    _battle_effect_command_receipts.clear()
    _active_effect_chain.clear()
    _effect_execution_depth = 0

func coerce_context(value):
    if value is ContextScript:
        return value
    if value is Dictionary:
        return ContextScript.new().configure(value)
    return ContextScript.new().configure({"owner": value})

func collect_sources(context) -> Array:
    return source_resolver.collect_sources(coerce_context(context))

func capture_source_snapshot(context) -> Array:
    return source_resolver.capture_source_snapshot(coerce_context(context))

func equipped_inner_skill_entries(context) -> Array:
    return source_resolver.equipped_inner_skill_entries(
        coerce_context(context))

func has_content(source_kind: String, content_id: String) -> bool:
    var catalog = source_resolver._catalog
    if catalog == null:
        return false
    return catalog.has_id(
        "inner_skill" if source_kind == "inner_skill" else "item",
        content_id)

func is_source_active(source, hook: String, context):
    return activation_policy.is_source_active(
        source, hook, coerce_context(context))

func resolve_inner_skill_capacity(
        growth_or_context,
        proposed_equipped_inner_skill_ids: Array = []) -> Dictionary:
    var context = coerce_context(growth_or_context)
    context.has_proposed_inner_skill_ids = true
    context.proposed_equipped_inner_skill_ids = proposed_equipped_inner_skill_ids.duplicate()
    return capacity_policy.resolve(context, proposed_equipped_inner_skill_ids)

func build_execution_plan(hook: String, context):
    var resolved_context = coerce_context(context)
    resolved_context.hook = hook
    var plan = ExecutionPlanScript.new().configure({"hook": hook})
    if not registry.has_hook(hook):
        plan.errors.append("未知被动 hook：%s" % hook)
        return plan
    var sources := collect_sources(resolved_context)
    for source in sources:
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
            source, sources, resolved_context)
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
        _attach_battle_effect_port(invocation, invocation_context)
    elif invocation_context.has_method("use_battle_effect_ports"):
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
    # The scoped port retains its Invocation context while the Handler runs.  Clear
    # both references before returning so a RefCounted context/port cycle cannot
    # survive a completed event.
    if mutation_hook and invocation_context.has_method("use_battle_effect_ports"):
        invocation_context.use_battle_effect_ports(null, {})
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

func _attach_battle_effect_port(invocation, context) -> void:
    var base_ports = (
        _battle_effect_ports_ref.get_ref()
        if _battle_effect_ports_ref != null else null)
    if base_ports == null or not context.has_method("use_battle_effect_ports"):
        if context.has_method("use_battle_effect_ports"):
            context.use_battle_effect_ports(null, {})
        return
    var existing_scope: Dictionary = context.battle_effect_scope.duplicate(false)
    existing_scope["hook"] = invocation.hook
    var action_token := str(existing_scope.get("action_token", ""))
    if action_token == "":
        action_token = str(context.payload.get("action_token", ""))
    existing_scope["action_token"] = action_token
    var event_token := str(existing_scope.get("event_token", ""))
    if event_token == "":
        event_token = str(context.payload.get("event_token", ""))
    existing_scope["event_token"] = event_token
    var port = BattlePassiveEffectPortsScript.new(
        base_ports,
        context,
        _battle_effect_command_receipts,
        _active_effect_chain,
        _battle_effect_scenario_error)
    context.use_battle_effect_ports(port, existing_scope)

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
            "active": entry["activation"].active,
            "blocked_by": entry["activation"].blocked_by.duplicate(),
        })
    var invocations: Array = []
    for invocation in plan.invocations:
        invocations.append({
            "source_instance_key": invocation.source.source_instance_key,
            "behavior_id": invocation.source.behavior_id,
            "behavior_index": invocation.source.behavior_index,
            "execution_index": invocation.execution_index,
            "execution_count": invocation.execution_count,
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

func _attach_counter_ports(source, context, access: String) -> Array:
    context.counter_read_port = null
    context.counter_mutation_port = null
    context.persistent_counter_read_port = null
    context.persistent_counter_mutation_port = null
    context.battle_counter_read_port = null
    context.battle_counter_mutation_port = null
    var result: Array = []
    if access == "none" or context.owner == null:
        return result
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
    context.source = source
    return result

func _property_value(owner, property_name: String):
    if owner == null or not owner.has_method("get_property_list"):
        return null
    for property in owner.get_property_list():
        if str(property.get("name", "")) == property_name:
            return owner.get(property_name)
    return null
