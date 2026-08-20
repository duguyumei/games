class_name TechniqueEffectExecutor
extends RefCounted

const RegistryScript = preload("res://core/effects/effect_handler_registry.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const ContinuationScript = preload("res://core/effects/technique_effect_continuation.gd")

var rng: RandomNumberGenerator
var registry

func _init(random_source: RandomNumberGenerator, registry_override = null, content_catalog = null) -> void:
    rng = random_source
    registry = (
        registry_override
        if registry_override != null
        else RegistryScript.new(random_source, null, content_catalog))

func execute_all(effects: Array, context) -> Dictionary:
    if context is Dictionary and not context.has("captures"):
        context["captures"] = {}
    return _continue(ContinuationScript.new().configure({
        "effects": effects,
        "context": context,
    }))

func resume(continuation, request_id: String, selected_ids: Array) -> Dictionary:
    if continuation == null or continuation.choice_request == null:
        return _failed_resume("当前没有可恢复的功法选择")
    if str(continuation.choice_request.request_id) != request_id:
        return _failed_resume("选择请求已失效或不匹配")
    var selection_check: Dictionary = continuation.choice_request.validate_selection(selected_ids)
    if not selection_check.get("ok", false):
        return _failed_resume(str(selection_check.get("reason", "选择不合法")), continuation)
    continuation.context.choice_responses[request_id] = selected_ids.duplicate()
    continuation.choice_request = null
    return _continue(continuation)

func _continue(continuation) -> Dictionary:
    while continuation.effect_index < continuation.effects.size():
        var effect_value = continuation.effects[continuation.effect_index]
        var effect: Dictionary = effect_value
        if not registry.condition_met(effect.get("when", {}), continuation.context):
            continuation.effect_index += 1
            continue
        if continuation.command_consumed_index != continuation.effect_index:
            var command_gate := _consume_effect_command(continuation.context)
            if not command_gate.get("success", false):
                return {
                    "status": EffectResultScript.FAILED,
                    "success": false,
                    "pending_choice": false,
                    "detail": str(command_gate.get("reason", "效果命令上限已触发")),
                    "effect_results": continuation.effect_results.duplicate(true),
                }
            continuation.command_consumed_index = continuation.effect_index
        _set_effect_execution_token(
            continuation.context, continuation.effect_index)
        var context_ports = (
            continuation.context.get("ports")
            if continuation.context is Dictionary
            else continuation.context.ports)
        if context_ports != null:
            context_ports.push_effect_context(continuation.context)
        var effect_transaction: Dictionary = continuation.active_effect_transaction
        continuation.active_effect_transaction = {}
        var owns_effect_transaction := not effect_transaction.is_empty()
        if effect_transaction.is_empty():
            effect_transaction = _context_effect_transaction(
                continuation.context)
            owns_effect_transaction = false if not effect_transaction.is_empty() \
                else true
        if effect_transaction.is_empty() and context_ports != null \
                and context_ports.has_method(
                    "begin_effect_mutation_transaction"):
            effect_transaction = \
                context_ports.begin_effect_mutation_transaction()
        _set_context_effect_transaction(
            continuation.context, effect_transaction)
        var pre_operation := _dispatch_pre_effect_operation(
            effect, continuation.context)
        var result: Dictionary
        if not pre_operation.get("success", false):
            result = EffectResultScript.failed(str(pre_operation.get(
                "reason", "效果前置响应失败"))).snapshot()
        else:
            result = EffectResultScript.normalize(
                registry.execute(effect, continuation.context))
        if result.get("success", false) \
                and not result.get("pending_choice", false) \
                and context_ports != null \
                and context_ports.has_method("commit_effect_card_batch"):
            var batch: Dictionary = context_ports.commit_effect_card_batch(
                continuation.context)
            if not batch.get("success", false):
                result = EffectResultScript.normalize(
                    EffectResultScript.failed(str(batch.get(
                        "reason", "真气批次汇总提交失败"))))
        if not effect_transaction.is_empty():
            if result.get("pending_choice", false):
                # 不在等待选择时提交；continuation 恢复后继续使用同一
                # EffectSpec 事务，避免功法调用成本与外层效果事务错层。
                if owns_effect_transaction:
                    continuation.active_effect_transaction = effect_transaction
            elif owns_effect_transaction and result.get("success", false):
                context_ports.commit_effect_mutation_transaction(
                    effect_transaction)
            elif owns_effect_transaction:
                context_ports.rollback_effect_mutation_transaction(
                    effect_transaction)
        if not result.get("pending_choice", false) or owns_effect_transaction:
            _set_context_effect_transaction(continuation.context, {})
        if context_ports != null:
            context_ports.pop_effect_context(continuation.context)
        continuation.effect_results.append(_public_effect_result(result))
        if result.get("pending_choice", false):
            var request_object = result.get("_choice_request_object")
            continuation.choice_request = request_object
            return {
                "status": EffectResultScript.PENDING_CHOICE,
                "success": false,
                "pending_choice": true,
                "detail": result.get("detail", "等待选择"),
                "choice_request": (
                    continuation.choice_snapshot()
                    if request_object != null
                    else result.get("choice_request", {}).duplicate(true)),
                "effect_results": continuation.effect_results.duplicate(true),
                "_continuation": continuation if request_object != null else null,
            }
        if not result.get("success", false):
            return {
                "status": EffectResultScript.FAILED,
                "success": false,
                "pending_choice": false,
                "detail": result.get("detail", "未知效果失败"),
                "effect_results": continuation.effect_results.duplicate(true),
            }
        if context_ports != null \
                and context_ports.has_method("take_immediate_effects"):
            var immediate_effects: Array = context_ports.take_immediate_effects(
                continuation.context)
            if not immediate_effects.is_empty():
                var insert_at: int = continuation.effect_index + 1
                for immediate_effect in immediate_effects:
                    continuation.effects.insert(insert_at, immediate_effect)
                    insert_at += 1
        if result.get("detail", "") != "":
            continuation.details.append(str(result["detail"]))
        continuation.command_consumed_index = -1
        continuation.effect_index += 1
    return {
        "status": EffectResultScript.SUCCEEDED,
        "success": true,
        "pending_choice": false,
        "detail": "；".join(continuation.details),
        "effect_results": continuation.effect_results.duplicate(true),
    }

func _set_effect_execution_token(context, effect_index: int) -> void:
    var base := ""
    if context is Dictionary:
        base = str(context.get("effect_execution_scope_token", ""))
        if base == "":
            base = str(context.get(
                "technique_execution_token", context.get(
                "action_token", context.get("source_instance_key", "effect"))))
        context["effect_execution_token"] = "%s:effect:%d" % [base, effect_index]
        return
    base = str(context.effect_execution_scope_token)
    if base == "":
        base = str(context.technique_execution_token)
    if base == "":
        base = str(context.action_token)
    if base == "":
        base = str(context.source_instance_key)
    if base == "":
        base = "effect"
    context.effect_execution_token = "%s:effect:%d" % [base, effect_index]

func _failed_resume(detail: String, continuation = null) -> Dictionary:
    var result := {
        "status": EffectResultScript.FAILED,
        "success": false,
        "pending_choice": continuation != null and continuation.choice_request != null,
        "detail": detail,
        "effect_results": (
            continuation.effect_results.duplicate(true)
            if continuation != null else []),
    }
    if continuation != null and continuation.choice_request != null:
        result["choice_request"] = continuation.choice_snapshot()
        result["_continuation"] = continuation
    return result

func _public_effect_result(result: Dictionary) -> Dictionary:
    var public_result := result.duplicate(true)
    public_result.erase("_choice_request_object")
    return public_result

func _context_effect_transaction(context) -> Dictionary:
    if context is Dictionary:
        var value = context.get("effect_transaction", {})
        return value if value is Dictionary else {}
    var value = context.effect_transaction
    return value if value is Dictionary else {}

func _set_context_effect_transaction(context, transaction: Dictionary) -> void:
    if context is Dictionary:
        context["effect_transaction"] = transaction
    else:
        context.effect_transaction = transaction

func _consume_effect_command(context) -> Dictionary:
    if context is Dictionary:
        return {"success": true}
    var limit := int(context.effect_command_limit)
    if limit <= 0:
        return {"success": true}
    var state: Dictionary = context.effect_chain_state
    if state.is_empty():
        state["command_count"] = 0
    var count := int(state.get("command_count", 0))
    if count >= limit:
        return {
            "success": false,
            "reason": "单次被动调用链效果命令超过 %d 次" % limit,
        }
    state["command_count"] = count + 1
    return {"success": true}

func _dispatch_pre_effect_operation(effect: Dictionary, context) -> Dictionary:
    # 目前只有“功法抽牌前”拥有正式消费者。其他 op 不经过这个边界，
    # 避免把每个效果都变成可任意拦截的脚本钩子。
    if str(effect.get("op", "")) != "draw":
        return {"success": true, "skipped": true}
    var runtime = context.passive_rule_runtime \
        if not context is Dictionary else context.get("passive_rule_runtime")
    var source_kind := str(context.source_kind) \
        if not context is Dictionary else str(context.get("source_kind", ""))
    if runtime == null or source_kind != "technique":
        return {"success": true, "skipped": true}
    var ports = context.ports \
        if not context is Dictionary else context.get("ports")
    if ports == null or not ports.has_method("transaction_sides"):
        return {"success": false, "reason": "效果前置响应缺少战斗参与方"}
    var actor = context.actor if not context is Dictionary else context.get("actor")
    var target = context.target if not context is Dictionary else context.get("target")
    var action_token := str(context.action_token) \
        if not context is Dictionary else str(context.get("action_token", ""))
    var execution_token := str(context.technique_execution_token) \
        if not context is Dictionary else str(context.get(
            "technique_execution_token", action_token))
    var payload := {
        "operation": "draw",
        "side": str(effect.get("side", "actor")),
        "count": effect.get("count", 0),
        "draw_reason": "technique_effect",
        "source_kind": source_kind,
        "source_id": str(context.source_id) \
            if not context is Dictionary else str(context.get("source_id", "")),
        "source_name": str(context.source_name) \
            if not context is Dictionary else str(context.get("source_name", "")),
        "source_instance_key": str(context.source_instance_key) \
            if not context is Dictionary else str(context.get(
                "source_instance_key", "")),
        "trigger_mode": str(context.trigger_mode) \
            if not context is Dictionary else str(context.get("trigger_mode", "")),
        "technique_execution_token": execution_token,
        "action_token": action_token,
        "root_action_token": str(context.root_action_token) \
            if not context is Dictionary else str(context.get(
                "root_action_token", action_token)),
        "effect_execution_token": str(context.effect_execution_token) \
            if not context is Dictionary else str(context.get(
                "effect_execution_token", "")),
        "effect_context_values": {
            "ports": ports,
            "actor": actor,
            "target": target,
            "action_token": action_token,
            "technique_execution_token": execution_token,
            "root_action_token": str(context.root_action_token) \
                if not context is Dictionary else str(context.get(
                    "root_action_token", action_token)),
            "trigger_mode": str(context.trigger_mode) \
                if not context is Dictionary else str(context.get(
                    "trigger_mode", "")),
            "round_number": int(context.round_number) \
                if not context is Dictionary else int(context.get(
                    "round_number", 0)),
            "effect_transaction": _context_effect_transaction(context),
        },
    }
    var effect_token := str(context.effect_execution_token) \
        if not context is Dictionary else str(context.get(
            "effect_execution_token", "effect"))
    var serial := str(execution_token) + ":pre:" + effect_token
    var index := 0
    for owner in ports.transaction_sides():
        if owner == null:
            continue
        var owner_payload := payload.duplicate(true)
        owner_payload["actor"] = actor
        owner_payload["target"] = target
        owner_payload["owner"] = owner
        owner_payload["event_token"] = "%s:%s:%d" % [
            serial, str(owner.owner_id), index]
        var dispatched: Dictionary = runtime.dispatch_event(
            "pre_effect_operation", {
                "owner": owner,
                "actor": actor,
                "target": target,
                "round_number": int(context.round_number) \
                    if not context is Dictionary else int(context.get(
                        "round_number", 0)),
                "payload": owner_payload,
            }, "mutation")
        if not dispatched.get("success", false):
            return {"success": false, "reason": "；".join(
                dispatched.get("errors", []))}
        index += 1
    return {"success": true, "skipped": false}

func summarize_intent(effects: Array, context, initial_damage_percent: int = 0) -> Dictionary:
    var intent := {
        "damage": 0,
        "defense": 0,
        "segments": 0,
        "technique_combo": false,
    }
    var state := {"damage_percent": initial_damage_percent}
    for effect_value in effects:
        var effect: Dictionary = effect_value
        if registry.condition_met(effect.get("when", {}), context):
            registry.summarize(effect, context, intent, state)
    return intent
