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
    var runtime_context = RunEffectContextScript.new(
        working_growth, context, content_catalog)
    var applied: Array = []
    var staged_passive_event_tokens: Array = []
    for index in range(effects.size()):
        var effect: Dictionary = effects[index]
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
