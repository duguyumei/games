class_name RunMutationService
extends RefCounted

const RunEffectContextScript = preload(
    "res://core/run_effects/run_effect_context.gd")
const RunEffectValidationScript = preload(
    "res://core/run_effects/run_effect_validation.gd")
const RunEffectHandlerRegistryScript = preload(
    "res://core/run_effects/run_effect_handler_registry.gd")
const RunPassiveEventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

const CARD_ADDITION_OPERATIONS := [
    "add_run_cards",
    "add_run_card_instances",
    "copy_run_card",
    # ConsumableUseService 仍持有其独立 RNG/库存事务；该 operation 在完整
    # 随机强化结束后可通过 stage_card_mutation_facts 复用同一 added 派生。
    "generate_random_base_cards",
]
const CARD_RESHAPE_OPERATIONS := [
    "apply_run_card_reshape",
    "transform_run_card",
    "copy_run_card_state",
    # 消耗品旁路的正式 adapter operation IDs。
    "apply_enhancement",
    "apply_origin",
    "apply_imprint",
    "apply_random_imprint",
    "apply_random_enhancement",
    "apply_prepared_group_origin",
    "apply_origin_to_matching_rank",
]

var handler_registry
var content_catalog
var _run_passive_event_service_ref: WeakRef
var _marker_address_resolver = SourceMarkerAddressResolverScript.new()

func _init(registry_override = null, content_catalog_override = null) -> void:
    handler_registry = (
        registry_override
        if registry_override != null
        else RunEffectHandlerRegistryScript.new())
    content_catalog = content_catalog_override

## 组合根用弱引用补齐 Run canonical fact -> PassiveRuleRuntime 的闭环；
## RunPassiveEventService 仍可强持有本 Service 作为窄效果端口，不形成环。
func use_passive_event_service(service) -> void:
    _run_passive_event_service_ref = weakref(service) if service != null else null

## Run 历练的唯一正式写入口。调用方可以把 working Growth 交给本方法，从而
## 复用其外层事务；本方法只在该 working copy 内提交余额、幂等回执和 canonical
## fact，派发失败会在返回前恢复该次操作的局部状态。
func change_experience_in_place(
        growth,
        requested_delta: int,
        context: Dictionary = {},
        staged_passive_event_tokens: Array = []) -> Dictionary:
    if growth == null:
        return {"success": false, "reason": "历练修改缺少 GrowthInventory"}
    if requested_delta == 0:
        return {
            "success": true,
            "skipped": true,
            "requested_delta": 0,
            "actual_delta": 0,
            "committed_events": [],
            "command_requests": [],
        }
    var transaction_token := _transaction_token(context)
    var operation_token := str(context.get("operation_token", ""))
    if operation_token == "":
        operation_token = "%s:experience:%s:%s:%s:%s:%s" % [
            transaction_token,
            str(context.get("source_instance_key", "direct")),
            str(context.get("source_behavior_id", "direct")),
            str(context.get("source_execution_index", 0)),
            str(context.get("effect_index", context.get("operation_index", 0))),
            str(context.get("operation", "gain" if requested_delta > 0 else "spend")),
        ]
    if growth.experience_operation_receipts.has(operation_token):
        var duplicate: Dictionary = growth.experience_operation_receipts[
            operation_token].duplicate(true)
        duplicate["success"] = true
        duplicate["duplicate"] = true
        duplicate["committed_events"] = []
        duplicate["command_requests"] = []
        return duplicate
    var before := int(growth.experience)
    var actual_delta := requested_delta
    var query: Dictionary = {}
    if requested_delta > 0:
        query = growth.effective_experience_gain_result(requested_delta, {
            "source_snapshot": context.get("source_snapshot", []),
            "metadata": {
                "operation": str(context.get("operation", "gain")),
                "reason": str(context.get("reason", "")),
                "transaction_token": transaction_token,
                "operation_token": operation_token,
            },
        })
        if not query.get("success", false):
            return {
                "success": false,
                "reason": str(query.get("reason", "历练获得查询失败")),
                "query": query,
            }
        actual_delta = int(query.get("effective_gain", requested_delta))
    elif before + requested_delta < 0:
        return {
            "success": false,
            "reason": "历练不足，需要 %d，当前 %d" % [-requested_delta, before],
        }
    var after := before + actual_delta
    var source := _fact_source(context)
    var holder_id := _marker_address_resolver.stable_owner_id(growth)
    if holder_id == "":
        holder_id = "run"
    var fact := {
        "event_type": "experience_change_resolved",
        "hook": "experience_change_resolved",
        "scope": "run",
        "holder": holder_id,
        "holder_id": holder_id,
        "requested_delta": requested_delta,
        "actual_delta": actual_delta,
        "experience_before": before,
        "experience_after": after,
        "direction": "gain" if requested_delta > 0 else "spend",
        "prevented_amount": requested_delta - actual_delta \
            if requested_delta > 0 else 0,
        "changed": actual_delta != 0,
        "reason": str(context.get("reason", context.get("operation", "experience"))),
        "operation": str(context.get(
            "operation", "gain" if requested_delta > 0 else "spend")),
        "source": source.duplicate(true),
        "source_description": source.duplicate(true),
        "source_kind": str(source.get("source_kind", "")),
        "source_id": str(source.get("source_id", "")),
        "source_instance_key": str(source.get("source_instance_key", "")),
        "trigger_mode": str(source.get("trigger_mode", "direct")),
        "transaction_token": transaction_token,
        "operation_token": operation_token,
        "event_token": "experience_change_resolved:%s" % operation_token,
        "root_execution_token": str(context.get(
            "root_execution_token", transaction_token)),
    }
    var receipt := fact.duplicate(true)
    receipt.erase("holder")
    receipt["query"] = query.duplicate(true)
    growth.experience = after
    growth.experience_operation_receipts[operation_token] = receipt.duplicate(true)
    var dispatched := _dispatch_experience_fact(
        fact, growth, staged_passive_event_tokens, context)
    if not dispatched.get("success", false):
        growth.experience = before
        growth.experience_operation_receipts.erase(operation_token)
        return dispatched
    var committed_events: Array = [fact.duplicate(true)]
    committed_events.append_array(_committed_events_from_dispatch(dispatched))
    var command_requests := _command_requests_from_value(dispatched)
    receipt["committed_events"] = committed_events.duplicate(true)
    receipt["command_requests"] = command_requests.duplicate(true)
    receipt["success"] = true
    receipt["duplicate"] = false
    return receipt

func settle_experience_interest_in_place(
        growth,
        context: Dictionary = {},
        staged_passive_event_tokens: Array = []) -> Dictionary:
    var settlement_token := str(context.get("settlement_token", ""))
    if settlement_token == "":
        return {"success": false, "reason": "功行生息缺少 settlement_token"}
    var operation_token := "%s:experience_interest" % settlement_token
    if growth.experience_operation_receipts.has(operation_token):
        var stored: Dictionary = growth.experience_operation_receipts[
            operation_token]
        if stored.get("interest_settlement") is Dictionary:
            var reused: Dictionary = stored["interest_settlement"].duplicate(true)
            reused["success"] = true
            reused["duplicate"] = true
            reused["committed_events"] = []
            reused["command_requests"] = []
            return reused
    var experience_before := int(growth.experience)
    var cap_query: Dictionary = growth.effective_experience_interest_cap_result({
        "settlement_token": settlement_token,
        "source_snapshot": context.get("source_snapshot", []),
    })
    if not cap_query.get("success", false):
        return {
            "success": false,
            "reason": str(cap_query.get("reason", "功行生息上限查询失败")),
            "cap_query": cap_query,
        }
    var step := int(growth.EXPERIENCE_INTEREST_STEP)
    var base_cap := int(growth.EXPERIENCE_INTEREST_CAP)
    var effective_cap := int(cap_query.get("effective_cap", base_cap))
    var uncapped := floori(experience_before / step)
    var requested := mini(uncapped, effective_cap)
    var change_context := context.duplicate(true)
    change_context.merge({
        "transaction_token": str(context.get(
            "transaction_token", settlement_token)),
        "operation_token": operation_token,
        "operation": "experience_interest",
        "reason": "experience_interest",
    }, true)
    var changed := change_experience_in_place(
        growth, requested, change_context, staged_passive_event_tokens)
    if not changed.get("success", false):
        return changed
    var result := {
        "success": true,
        "experience_before": experience_before,
        "step": step,
        "base_cap": base_cap,
        "effective_cap": effective_cap,
        "uncapped_amount": uncapped,
        "requested_amount": requested,
        "actual_amount": int(changed.get("actual_delta", 0)),
        "amount": int(changed.get("actual_delta", 0)),
        "experience_after": int(growth.experience),
        "query_breakdown": cap_query.get("modifier_breakdown", []).duplicate(true),
        "source_fingerprint": str(cap_query.get("source_fingerprint", "")),
        "cap_query": cap_query.duplicate(true),
        "settlement_token": settlement_token,
        "experience_change": changed.duplicate(true),
        "committed_events": changed.get("committed_events", []).duplicate(true),
        "command_requests": changed.get("command_requests", []).duplicate(true),
    }
    var receipt: Dictionary = growth.experience_operation_receipts.get(
        operation_token, {}).duplicate(true)
    receipt["interest_settlement"] = result.duplicate(true)
    growth.experience_operation_receipts[operation_token] = receipt
    return result

func apply_effects(effects: Array, growth, context: Dictionary = {}) -> Dictionary:
    for registration_error in handler_registry.registration_errors():
        return _failure(str(registration_error), -1, "")
    for index in range(effects.size()):
        var effect_value = effects[index]
        if not effect_value is Dictionary:
            return _failure("本局效果必须是对象", index, "")
        var effect: Dictionary = effect_value
        var validation = RunEffectValidationScript.new()
        handler_registry.validate_effect(
            effect, validation, "effects[%d]" % index)
        if not validation.is_valid():
            return _failure(
                "；".join(validation.errors),
                index,
                str(effect.get("op", "")))

    var state_before: Dictionary = growth.capture_mutation_state()
    var working_growth = growth.create_mutation_copy()
    if working_growth == null:
        return _failure("无法建立本局事务工作副本", -1, "")
    var applied: Array = []
    var staged_passive_event_tokens: Array = []
    var runtime_context = RunEffectContextScript.new(
        working_growth, context, content_catalog, self,
        staged_passive_event_tokens)
    for index in range(effects.size()):
        var effect: Dictionary = effects[index]
        runtime_context.metadata["effect_index"] = index
        var cards_before: Array = working_growth.run_deck.cards_snapshot()
        var result: Dictionary = handler_registry.apply(effect, runtime_context)
        if not result.get("success", false):
            return _failure(
                str(result.get("reason", "本局效果执行失败")),
                index,
                str(effect.get("op", "")))
        var cards_after: Array = working_growth.run_deck.cards_snapshot()
        var fact_result := _record_and_dispatch_card_mutation(
            str(effect.get("op", "")),
            cards_before,
            cards_after,
            working_growth,
            runtime_context,
            staged_passive_event_tokens,
            index)
        if not fact_result.get("success", false):
            return _failure(
                str(fact_result.get("reason", "本局真气提交事实派发失败")),
                index,
                str(effect.get("op", "")))
        runtime_context.record_command_requests(
            _command_requests_from_value(fact_result))
        var applied_entry: Dictionary = result.get(
            "applied", {}).duplicate(true)
        if not fact_result.get("facts", []).is_empty():
            applied_entry["committed_facts"] = fact_result.get(
                "facts", []).duplicate(true)
        applied.append(applied_entry)

    working_growth.recalculate_effective_max_life()
    var state_after: Dictionary = working_growth.capture_mutation_state()
    var commit_errors: Array[String] = growth.replace_mutation_state(state_after)
    if not commit_errors.is_empty():
        return _failure("；".join(commit_errors), -1, "")
    return {
        "success": true,
        "applied": applied,
        "changed": state_before != state_after,
        "state_before": _summarize(state_before),
        "state_after": _summarize(state_after),
        # Run 命令只在整个工作副本提交成功后公开 canonical marker 事实；
        # 失败路径不会泄漏已经回滚的 source_marker_changed。
        "committed_events": runtime_context.committed_events.duplicate(true),
        "command_requests": runtime_context.command_requests.duplicate(true),
    }

## 供仍由其他正式事务持有者（目前主要是 ConsumableUseService）复用的窄
## adapter：调用方必须传入其工作副本在单个逻辑 operation 前后的牌组快照。
## 本方法会在该工作副本上同步消费事实，但不替调用方提交正式 Growth。
func stage_card_mutation_facts(
        operation_id: String,
        cards_before: Array,
        cards_after: Array,
        working_growth,
        context: Dictionary = {},
        operation_index: int = 0) -> Dictionary:
    if working_growth == null or working_growth.run_deck == null:
        return {"success": false, "reason": "真气事实暂存缺少本局工作副本"}
    var runtime_context = RunEffectContextScript.new(
        working_growth, context, content_catalog)
    var staged_tokens: Array = []
    var result := _record_and_dispatch_card_mutation(
        operation_id,
        cards_before,
        cards_after,
        working_growth,
        runtime_context,
        staged_tokens,
        operation_index)
    if not result.get("success", false):
        return result
    result["committed_events"] = runtime_context.committed_events.duplicate(true)
    result["staged_passive_event_tokens"] = staged_tokens.duplicate()
    return result

## 纯 before/after 派生；不读取来源、不写状态，可供旁路事务在同一 canonical
## 规则下审计其 operation。新增优先于重塑，因而完整实例新增不会同时发两类事实。
func derive_card_mutation_facts(
        operation_id: String,
        cards_before: Array,
        cards_after: Array,
        growth,
        context: Dictionary = {},
        operation_index: int = 0) -> Array:
    var facts: Array = []
    if operation_id not in CARD_ADDITION_OPERATIONS \
            and operation_id not in CARD_RESHAPE_OPERATIONS:
        return facts
    var before_by_id := _cards_by_instance_id(cards_before)
    var transaction_token := _transaction_token(context)
    var operation_token := "%s:operation:%d:%s" % [
        transaction_token, operation_index, operation_id]
    var fact_source := _fact_source(context)
    var holder_id := _marker_address_resolver.stable_owner_id(growth)
    if holder_id == "":
        holder_id = "run"
    if operation_id in CARD_ADDITION_OPERATIONS:
        for card_value in cards_after:
            if not card_value is Dictionary:
                continue
            var card: Dictionary = card_value
            var instance_id := str(card.get("instance_id", ""))
            if instance_id == "" or before_by_id.has(instance_id):
                continue
            var fact := {
                "event_type": "run_qi_permanently_added",
                "hook": "run_qi_permanently_added",
                "scope": "run",
                "persistence": "permanent",
                "holder": holder_id,
                "holder_id": holder_id,
                "transaction_token": transaction_token,
                "operation_token": operation_token,
                "operation_id": operation_id,
                "operation": operation_id,
                "operation_index": operation_index,
                "event_token": "run_qi_permanently_added:%s:%s" % [
                    operation_token, instance_id],
                "reason": str(context.get("reason", operation_id)),
                "source": fact_source.duplicate(true),
                "source_description": fact_source.duplicate(true),
                "source_kind": str(fact_source.get("source_kind", "")),
                "source_id": str(fact_source.get("source_id", "")),
                "source_instance_key": str(fact_source.get(
                    "source_instance_key", "")),
                "trigger_mode": str(fact_source.get("trigger_mode", "direct")),
                "instance_id": instance_id,
                "card_instance_id": instance_id,
                "definition_id": str(card.get("definition_id", "")),
                "card_snapshot": card.duplicate(true),
                "persistent_card_snapshot": card.duplicate(true),
                "actual_change_count": 1,
            }
            facts.append(fact)
        return facts
    for card_value in cards_after:
        if not card_value is Dictionary:
            continue
        var after_card: Dictionary = card_value
        var instance_id := str(after_card.get("instance_id", ""))
        if instance_id == "" or not before_by_id.has(instance_id):
            continue
        var before_card: Dictionary = before_by_id[instance_id]
        if before_card == after_card:
            continue
        var persistent_changes := _persistent_changes(before_card, after_card)
        var fact := {
            "event_type": "qi_reshape_committed",
            "hook": "qi_reshape_committed",
            "scope": "run",
            "persistence": "permanent",
            "holder": holder_id,
            "holder_id": holder_id,
            "transaction_token": transaction_token,
            "operation_token": operation_token,
            "operation_id": operation_id,
            "operation": operation_id,
            "operation_index": operation_index,
            "event_token": "qi_reshape_committed:%s:%s" % [
                operation_token, instance_id],
            "reason": str(context.get("reason", operation_id)),
            "source": fact_source.duplicate(true),
            "source_description": fact_source.duplicate(true),
            "source_kind": str(fact_source.get("source_kind", "")),
            "source_id": str(fact_source.get("source_id", "")),
            "source_instance_key": str(fact_source.get(
                "source_instance_key", "")),
            "trigger_mode": str(fact_source.get("trigger_mode", "direct")),
            "instance_id": instance_id,
            "card_instance_id": instance_id,
            "definition_id": str(after_card.get("definition_id", "")),
            "before": before_card.duplicate(true),
            "after": after_card.duplicate(true),
            "changes": persistent_changes,
            "actual_change_count": persistent_changes.size(),
        }
        facts.append(fact)
    return facts

func _record_and_dispatch_card_mutation(
        operation_id: String,
        cards_before: Array,
        cards_after: Array,
        working_growth,
        runtime_context,
        staged_passive_event_tokens: Array,
        operation_index: int) -> Dictionary:
    var facts := derive_card_mutation_facts(
        operation_id,
        cards_before,
        cards_after,
        working_growth,
        runtime_context.metadata,
        operation_index)
    var dispatches: Array = []
    for fact_value in facts:
        var fact: Dictionary = fact_value
        # Canonical fact 在派生响应之前排序；若随后失败，整个 runtime_context
        # 随 working Growth 一同被丢弃，不会由 apply_effects 返回。
        runtime_context.record_committed_events([fact])
        var dispatched := _dispatch_card_fact(
            fact, working_growth, staged_passive_event_tokens)
        if not dispatched.get("success", false):
            return {
                "success": false,
                "reason": str(dispatched.get(
                    "reason", "%s 被动消费失败" % str(fact.get("event_type", "")))),
                "failed_fact": fact.duplicate(true),
                "dispatch": dispatched,
            }
        dispatches.append(dispatched)
        runtime_context.record_committed_events(
            _committed_events_from_dispatch(dispatched))
    return {
        "success": true,
        "facts": facts.duplicate(true),
        "dispatches": dispatches,
    }

func _dispatch_card_fact(
        fact: Dictionary,
        working_growth,
        staged_passive_event_tokens: Array) -> Dictionary:
    var service = (
        _run_passive_event_service_ref.get_ref()
        if _run_passive_event_service_ref != null else null)
    if service == null:
        return {
            "success": true,
            "skipped": true,
            "reason": "未装配 RunPassiveEventService",
            "event_token": str(fact.get("event_token", "")),
            "results": [],
        }
    var invocation_payload := fact.duplicate(true)
    # canonical 事实本身只公开稳定 holder_id；Invocation 过滤阶段临时投影真实
    # owner，使 holder_is_owner 等来源中立条件不依赖字符串约定。
    invocation_payload["holder"] = working_growth
    var context_values := {
        "hook": str(fact.get("event_type", "")),
        "owner": working_growth,
        "actor": working_growth,
        "transaction_token": str(fact.get("transaction_token", "")),
        "operation_token": str(fact.get("operation_token", "")),
        "operation_id": str(fact.get("operation_id", "")),
        "event_token": str(fact.get("event_token", "")),
        "scope": str(fact.get("scope", "run")),
        "persistence": str(fact.get("persistence", "permanent")),
        "holder_id": str(fact.get("holder_id", "")),
        "card_instance_id": str(fact.get("card_instance_id", "")),
        "definition_id": str(fact.get("definition_id", "")),
        "reason": str(fact.get("reason", "")),
        "fact_source": fact.get("source", {}).duplicate(true),
        "card_snapshot": fact.get("card_snapshot", {}).duplicate(true),
        "before": fact.get("before", {}).duplicate(true),
        "after": fact.get("after", {}).duplicate(true),
        "changes": fact.get("changes", []).duplicate(true),
        "actual_change_count": int(fact.get("actual_change_count", 0)),
        # payload 是 generic Handler 的稳定公开面；上面的同名类型化字段用于
        # Handler 需要强字段访问时避免各自解析不同字典版本。
        "payload": invocation_payload,
    }
    return service.dispatch_staged(
        RunPassiveEventContextScript.new().configure(context_values),
        working_growth,
        staged_passive_event_tokens)

func _dispatch_experience_fact(
        fact: Dictionary,
        working_growth,
        staged_passive_event_tokens: Array,
        context: Dictionary) -> Dictionary:
    var service = (
        _run_passive_event_service_ref.get_ref()
        if _run_passive_event_service_ref != null else null)
    if service == null:
        return {
            "success": true,
            "skipped": true,
            "event_token": str(fact.get("event_token", "")),
            "results": [],
        }
    var payload := fact.duplicate(true)
    payload["holder"] = working_growth
    payload["experience_response_ancestry"] = context.get(
        "experience_response_ancestry", []).duplicate()
    var source_snapshot = context.get("source_snapshot", [])
    var values := {
        "hook": "experience_change_resolved",
        "owner": working_growth,
        "actor": working_growth,
        "transaction_token": fact["transaction_token"],
        "operation_token": fact["operation_token"],
        "operation_id": "experience_change_resolved",
        "event_token": fact["event_token"],
        "scope": "run",
        "holder_id": fact["holder_id"],
        "reason": fact["reason"],
        "fact_source": fact["source"],
        "payload": payload,
    }
    if source_snapshot is Array and not source_snapshot.is_empty():
        values["source_snapshot"] = source_snapshot.duplicate(true)
    return service.dispatch_staged(
        RunPassiveEventContextScript.new().configure(values),
        working_growth,
        staged_passive_event_tokens)

func _command_requests_from_value(value) -> Array:
    var result: Array = []
    var seen: Dictionary = {}
    _collect_command_requests(value, result, seen)
    return result

func _collect_command_requests(
        value,
        result: Array,
        seen: Dictionary) -> void:
    if value is Array:
        for entry in value:
            _collect_command_requests(entry, result, seen)
        return
    if not value is Dictionary:
        return
    var requests = value.get("command_requests")
    if requests is Array:
        for request_value in requests:
            if not request_value is Dictionary:
                continue
            var token := str(request_value.get("request_token", ""))
            if token == "" or seen.has(token):
                continue
            seen[token] = true
            result.append(request_value.duplicate(true))
    for key in value:
        if str(key) == "command_requests":
            continue
        _collect_command_requests(value[key], result, seen)

func _cards_by_instance_id(cards: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in cards:
        if not value is Dictionary:
            continue
        var instance_id := str(value.get("instance_id", ""))
        if instance_id != "":
            result[instance_id] = value.duplicate(true)
    return result

func _persistent_changes(before: Dictionary, after: Dictionary) -> Array:
    var fields: Array[String] = []
    for key in before:
        var field := str(key)
        if not fields.has(field):
            fields.append(field)
    for key in after:
        var field := str(key)
        if not fields.has(field):
            fields.append(field)
    fields.sort()
    var result: Array = []
    for field in fields:
        var before_value = before.get(field)
        var after_value = after.get(field)
        if before_value == after_value:
            continue
        result.append({
            "field": field,
            "before": _duplicate_variant(before_value),
            "after": _duplicate_variant(after_value),
        })
    return result

func _duplicate_variant(value):
    if value is Dictionary or value is Array:
        return value.duplicate(true)
    return value

func _transaction_token(context: Dictionary) -> String:
    var explicit := str(context.get("transaction_token", ""))
    if explicit != "":
        return explicit
    var reward_bundle = context.get("reward_bundle")
    if reward_bundle is Dictionary:
        var bundle_id := str(reward_bundle.get("id", ""))
        if bundle_id != "":
            return "reward_bundle:%s" % bundle_id
    for key in ["interaction_token", "purchase_token", "event_token"]:
        var value := str(context.get(key, ""))
        if value != "":
            return "%s:%s" % [str(key), value]
    var source_kind := str(context.get("source_kind", "rule"))
    var source_id := str(context.get("source_id", "run_mutation"))
    return "run_mutation:%s:%s" % [source_kind, source_id]

func _fact_source(context: Dictionary) -> Dictionary:
    var provided = context.get("fact_source", context.get("source_description"))
    if provided is Dictionary and not provided.is_empty():
        return provided.duplicate(true)
    return {
        "source_kind": str(context.get("source_kind", "rule")),
        "source_id": str(context.get("source_id", "run_mutation")),
        "source_name": str(context.get("source_name", "")),
        "source_instance_key": str(context.get("source_instance_key", "")),
        "trigger_mode": str(context.get("trigger_mode", "direct")),
    }

func _committed_events_from_dispatch(dispatched: Dictionary) -> Array:
    var result: Array = []
    var seen_tokens: Dictionary = {}
    _collect_committed_events(dispatched.get("results", []), result, seen_tokens)
    return result

func _collect_committed_events(
        value,
        result: Array,
        seen_tokens: Dictionary) -> void:
    if value is Array:
        for entry in value:
            _collect_committed_events(entry, result, seen_tokens)
        return
    if not value is Dictionary:
        return
    var committed = value.get("committed_events")
    if committed is Array:
        for event_value in committed:
            if not event_value is Dictionary:
                continue
            var event: Dictionary = event_value
            var event_token := str(event.get("event_token", ""))
            var dedup_key := event_token
            if dedup_key == "":
                dedup_key = "%s|%s|%s|%s" % [
                    str(event.get("event_type", "")),
                    str(event.get("source_instance_key", "")),
                    str(event.get("marker_id", "")),
                    str(event.get("operation_token", "")),
                ]
            if seen_tokens.has(dedup_key):
                continue
            seen_tokens[dedup_key] = true
            result.append(event.duplicate(true))
    for key in value:
        if str(key) == "committed_events":
            continue
        _collect_committed_events(value[key], result, seen_tokens)

func _failure(reason: String, effect_index: int, operation_id: String) -> Dictionary:
    return {
        "success": false,
        "reason": reason,
        "failed_effect_index": effect_index,
        "failed_operation_id": operation_id,
    }

func _summarize(state: Dictionary) -> Dictionary:
    return {
        "experience": int(state.get("experience", 0)),
        "life": int(state.get("life", 0)),
        "max_life": int(state.get("max_life", 0)),
        "consumable_count": state.get("consumable_ids", []).size(),
        "learned_technique_count": state.get("learned_technique_ids", []).size(),
        "learned_inner_skill_count": state.get("learned_inner_skill_ids", []).size(),
        "equipped_inner_skill_count": state.get("equipped_inner_skill_ids", []).size(),
        "run_deck_count": state.get("run_deck", {}).get("cards", []).size(),
        "practice_purchase_count": state.get("practice_purchases", {}).size(),
    }
