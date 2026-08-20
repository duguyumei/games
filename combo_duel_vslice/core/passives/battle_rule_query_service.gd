class_name BattleRuleQueryService
extends RefCounted

const RequestScript = preload(
    "res://core/passives/battle_passive_int_query_request.gd")
const ResultScript = preload(
    "res://core/passives/battle_passive_int_query_result.gd")
const ResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")
const BattleIntQueryCatalogScript = preload(
    "res://core/passives/battle_int_query_catalog.gd")
const PureQueryGuardScript = preload(
    "res://core/passives/battle_pure_query_guard.gd")

const QUERY_HOOKS := BattleIntQueryCatalogScript.HOOKS

const EFFECTIVE_QI_PURPOSES := [
    "power_calculation", "effect_value", "target_query", "event_snapshot",
]
const EFFECTIVE_QI_EVALUATION_MODES := [
    "preview", "confirm", "runtime", "ai",
]
const CARD_ATTRIBUTES := ["wind", "forest", "fire", "mountain"]

var _resolver
var _scenario_error: Callable
var _rng: RandomNumberGenerator
var _committed_event_service = null
var _pure_query_guard

func _init(
        passive_runtime,
        scenario_error_callback: Callable = Callable(),
        pure_query_guard = null) -> void:
    _pure_query_guard = pure_query_guard \
        if pure_query_guard != null else PureQueryGuardScript.new()
    _resolver = ResolverScript.new(passive_runtime, _pure_query_guard)
    _scenario_error = scenario_error_callback

func use_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng
    _pure_query_guard.use_rng(rng)

func use_committed_event_service(service) -> void:
    _committed_event_service = service
    _pure_query_guard.use_committed_event_service(service)

func use_pure_query_guard(guard) -> void:
    _pure_query_guard = guard if guard != null else PureQueryGuardScript.new()
    _resolver.use_pure_query_guard(_pure_query_guard)
    if _rng != null:
        _pure_query_guard.use_rng(_rng)
    if _committed_event_service != null:
        _pure_query_guard.use_committed_event_service(
            _committed_event_service)

func resolve(request):
    var observed: Array = _observed_sides(request) \
        if request is RequestScript else []
    var guarded: Dictionary = _pure_query_guard.evaluate(
        Callable(self, "_resolve_unguarded").bind(request), observed)
    var purity_error := _purity_error(guarded)
    if purity_error != "":
        return _failure(request, purity_error)
    return guarded["value"]

func _resolve_unguarded(request):
    if not request is RequestScript:
        return _failure(null, "战斗整数查询必须使用 BattlePassiveIntQueryRequest")
    if request.hook not in QUERY_HOOKS:
        return _failure(request, "不是正式战斗整数查询 Hook：%s" % request.hook)
    var resolved = _resolver.resolve(request)
    if not resolved.success:
        return _failure(request, "；".join(resolved.errors))
    var values: Dictionary = resolved.to_dict()
    values["request_fingerprint"] = JSON.stringify({
        "hook": request.hook,
        "owner_id": _stable_object_id(request.owner),
        "actor_id": _stable_object_id(request.actor),
        "target_id": _stable_object_id(request.target),
        "subject_kind": request.subject_kind,
        "subject_id": request.subject_id,
        "base_value": request.base_value,
        "round_number": request.round_number,
        "action_token": request.action_token,
        "hand_id": request.hand_id,
        "source_kind": request.source_kind,
        "card_facts": _stable_value(request.card_facts),
        "purpose": request.purpose,
        "evaluation_mode": request.evaluation_mode,
        "subject_card_facts": _stable_value(request.subject_card_facts),
        "actual_played_count": request.actual_played_count,
        "exact_hand": _stable_value(request.exact_hand),
        "damage_segment_token": request.damage_segment_token,
        "action_window_id": request.action_window_id,
        "source_id": request.source_id,
        "source_instance_key": request.source_instance_key,
        "trigger_mode": request.trigger_mode,
        "cause": request.cause,
        "damage_type": request.damage_type,
        "direct_attack": request.direct_attack,
        "reflection_damage": request.reflection_damage,
        "synchronized": request.synchronized,
        "requested_damage": request.requested_damage,
        "final_damage": request.final_damage,
        "defense_before": request.defense_before,
        "defense_lost": request.defense_lost,
        "defense_after": request.defense_after,
        "life_before": request.life_before,
        "proposed_life_loss": request.proposed_life_loss,
        "lethal": request.lethal,
        "metadata": _stable_value(request.metadata),
        "source_snapshot": _stable_value(request.source_snapshot) \
            if request.has_source_snapshot else [],
        "source_fingerprint": resolved.source_fingerprint,
    }).sha256_text()
    return ResultScript.new().configure(values)

func resolve_values(values: Dictionary):
    return resolve(RequestScript.new().configure(values))

func capture_source_snapshot(owner, context: Dictionary = {}) -> Array:
    var runtime = _resolver._runtime_ref.get_ref()
    if runtime == null:
        return []
    return runtime.capture_source_snapshot({
        "owner": owner,
        "actor": context.get("actor", owner),
        "target": context.get("target"),
        "round_number": int(context.get("round_number", 0)),
    })

## 战斗中逐牌有效真气值的唯一正式入口。卡牌自身阶段仍由 QiCard 计算；
## 此方法只统一构造来源中立的战斗规则请求，并在全部来源完成后截断到零。
func resolve_effective_qi(owner, card, context: Dictionary = {}):
    if owner == null:
        return _effective_failure(card, "有效真气值查询缺少 owner/holder")
    if card == null:
        return _effective_failure(card, "有效真气值查询缺少 subject card")
    var participants := _context_sides(owner, context)
    var cards: Array = context.get(
        "cards", context.get("participating_cards", [card])).duplicate()
    if not cards.has(card):
        cards.append(card)
    var guarded: Dictionary = _pure_query_guard.evaluate(
        Callable(self, "_resolve_effective_qi_unguarded").bind(
            owner, card, context),
        participants,
        cards)
    var purity_error := _purity_error(guarded)
    if purity_error != "":
        return _effective_failure(card, purity_error)
    return guarded["value"]

func _resolve_effective_qi_unguarded(owner, card, context: Dictionary = {}):
    var purpose := str(context.get("purpose", "effect_value"))
    if purpose not in EFFECTIVE_QI_PURPOSES:
        return _effective_failure(card, "未知有效真气值查询用途：%s" % purpose)
    var evaluation_mode := str(context.get("evaluation_mode", "runtime"))
    if evaluation_mode not in EFFECTIVE_QI_EVALUATION_MODES:
        return _effective_failure(
            card, "未知有效真气值评估模式：%s" % evaluation_mode)
    var actor = context.get("actor", owner)
    var target = context.get("target")
    var cards: Array = context.get(
        "cards", context.get("participating_cards", [card])).duplicate()
    if not cards.has(card):
        cards.append(card)
    var default_participating: Array = cards.map(
        func(value): return str(value.id)) \
        if purpose == "power_calculation" else []
    var participating_ids: Array = context.get(
        "participating_card_ids", default_participating)
    var card_facts: Array = []
    for value in cards:
        card_facts.append(card_fact(
            value, owner, target, participating_ids.has(str(value.id))))
    var subject_facts := card_fact(
        card, owner, target, participating_ids.has(str(card.id)))
    var calculation_context: Dictionary = context.get(
        "calculation_context", {}).duplicate(true)
    calculation_context["participating"] = bool(
        subject_facts.get("participating", false))
    var base_value: int = int(card.effective_qi_value(
        false, calculation_context)) \
        if card.has_method("effective_qi_value") else int(card.qi_value)
    var hand_result: Dictionary = context.get("hand_result", {})
    var exact_hand := {
        "id": str(hand_result.get("id", context.get("hand_id", ""))),
        "name": str(hand_result.get("name", "")),
        "played_card_instance_ids": cards.map(
            func(value): return str(value.id)),
        "contributing_card_instance_ids": participating_ids.map(
            func(value): return str(value)),
    }
    var request_values := {
        "hook": "effective_qi_query",
        "owner": owner,
        "actor": actor,
        "target": target,
        "subject_kind": "qi_card",
        "subject_id": str(card.id),
        "base_value": base_value,
        "round_number": int(context.get("round_number", 0)),
        "action_token": str(context.get("action_token", "")),
        "hand_id": str(exact_hand["id"]),
        "source_kind": str(context.get("source_kind", "rule")),
        "card_facts": card_facts,
        "purpose": purpose,
        "evaluation_mode": evaluation_mode,
        "subject_card_facts": subject_facts,
        "actual_played_count": int(context.get(
            "actual_played_count",
            cards.size() if purpose == "power_calculation" \
                or not hand_result.is_empty() \
                or str(context.get("action_token", "")) != "" else 0)),
        "exact_hand": exact_hand,
        "metadata": {
            "purpose": purpose,
            "evaluation_mode": evaluation_mode,
            "subject_card_instance_id": str(card.id),
        },
    }
    if context.has("source_snapshot"):
        request_values["source_snapshot"] = context.get(
            "source_snapshot", []).duplicate(true)
    var result = resolve_values(request_values)
    if result.success:
        result.effective_value = maxi(0, int(result.effective_value))
    return result

## 防御吸收完成后、正式生命写入前的唯一查询入口。查询只能减少或取消本段
## proposed_life_loss；任何越界结果都作为失败返回，不能用此 Hook 放大伤害。
func resolve_pre_life_loss(owner, context: Dictionary):
    if owner == null:
        return _pre_life_loss_failure(context, "生命写入前查询缺少 owner/target")
    var guarded: Dictionary = _pure_query_guard.evaluate(
        Callable(self, "_resolve_pre_life_loss_unguarded").bind(
            owner, context),
        _context_sides(owner, context))
    var purity_error := _purity_error(guarded)
    if purity_error != "":
        return _pre_life_loss_failure(context, purity_error)
    return guarded["value"]

func _resolve_pre_life_loss_unguarded(owner, context: Dictionary):
    var segment_token := str(context.get("damage_segment_token", ""))
    if segment_token == "":
        return _pre_life_loss_failure(context, "生命写入前查询缺少 damage_segment_token")
    var proposed := int(context.get("proposed_life_loss", -1))
    if proposed < 0:
        return _pre_life_loss_failure(context, "预计生命损失不能为负数")
    var request_values := {
        "hook": "pre_life_loss_query",
        "owner": owner,
        "actor": context.get("actor"),
        "target": context.get("target", owner),
        "subject_kind": "life_loss",
        "subject_id": segment_token,
        "base_value": proposed,
        "round_number": int(context.get("round_number", 0)),
        "action_token": str(context.get("action_token", "")),
        "source_kind": str(context.get("source_kind", "")),
        "damage_segment_token": segment_token,
        "action_window_id": str(context.get("action_window_id", "")),
        "source_id": str(context.get("source_id", "")),
        "source_instance_key": str(context.get("source_instance_key", "")),
        "trigger_mode": str(context.get("trigger_mode", "")),
        "cause": str(context.get("cause", "damage")),
        "damage_type": str(context.get("damage_type", "normal")),
        "direct_attack": bool(context.get("direct_attack", false)),
        "reflection_damage": bool(context.get("reflection_damage", false)),
        "synchronized": bool(context.get("synchronized", false)),
        "requested_damage": int(context.get("requested_damage", 0)),
        "final_damage": int(context.get("final_damage", 0)),
        "defense_before": int(context.get("defense_before", 0)),
        "defense_lost": int(context.get("defense_lost", 0)),
        "defense_after": int(context.get("defense_after", 0)),
        "life_before": int(context.get("life_before", 0)),
        "proposed_life_loss": proposed,
        "lethal": bool(context.get("lethal", false)),
        "metadata": context.get("metadata", {}).duplicate(true),
    }
    if context.has("source_snapshot"):
        request_values["source_snapshot"] = context.get(
            "source_snapshot", []).duplicate(true)
    var result = resolve_values(request_values)
    if result.success and (result.effective_value < 0 \
            or result.effective_value > proposed):
        result.success = false
        result.errors.append(
            "生命写入前查询结果越界：%d 不在 0..%d" % [
                result.effective_value, proposed])
    return result

func card_fact(card, owner = null, target = null, participating: bool = false) -> Dictionary:
    var identity: Dictionary = {}
    var identity_policy = owner.card_identity_policy \
        if owner != null and owner.card_identity_policy != null else null
    if identity_policy != null and identity_policy.has_method("resolve"):
        var resolved: Dictionary = identity_policy.resolve(card, {
            "owner": owner, "actor": owner, "target": target,
        })
        if resolved.get("success", false):
            identity = resolved["facts"].to_dict()
    var attributes: Array[String] = []
    for attribute in CARD_ATTRIBUTES:
        if identity.get("effective_attributes", []).has(attribute) \
                or identity.is_empty() and card.is_attribute(attribute):
            attributes.append(attribute)
    var anomaly_snapshot: Dictionary = card.anomaly_snapshot() \
        if card.has_method("anomaly_snapshot") else {}
    var anomaly_summary := {
        "buff": _stable_ids(anomaly_snapshot.get("buffs", {}).keys()),
        "debuff": _stable_ids(anomaly_snapshot.get("debuffs", {}).keys()),
        "state": _stable_ids([str(anomaly_snapshot.get(
            "state", {}).get("id", ""))]),
        "mark": _stable_ids(anomaly_snapshot.get("marks", {}).keys()),
    }
    var temporary: Dictionary = card.temporary_reshapes \
        if card != null else {}
    var has_anomaly := false
    for ids in anomaly_summary.values():
        has_anomaly = has_anomaly or not ids.is_empty()
    return {
        "instance_id": str(card.id),
        "definition_id": str(card.current_definition_id()) \
            if card.has_method("current_definition_id") else str(card.definition_id),
        "current_base_qi": int(card.current_base_qi_value()) \
            if card.has_method("current_base_qi_value") else int(card.qi_value),
        "card_base_qi": int(card.qi_value),
        "rank_name": str(identity.get(
            "rank_name", card.current_rank_name())),
        "rank_order": int(identity.get(
            "rank_order", card.current_rank_order())),
        "effective_attributes": attributes,
        "has_anomaly": has_anomaly,
        "anomalies": anomaly_summary,
        "has_permanent_reshape": not card.reshape_origin.is_empty() \
            or str(card.reshape_enhancement) != "" \
            or str(card.reshape_imprint) != "" \
            or not card.reshape_others.is_empty(),
        "has_temporary_reshape": str(temporary.get("enhancement", "")) != "" \
            or str(temporary.get("attribute", "")) != "" \
            or not temporary.get("rank", {}).is_empty(),
        "burned_out": card.has_anomaly("debuff", "burned_out"),
        "normal_blazing_layers": card.normal_blazing_layers() \
            if card.has_method("normal_blazing_layers") else 0,
        "temporary_blazing_layers": card.temporary_blazing_layers_total() \
            if card.has_method("temporary_blazing_layers_total") else 0,
        "total_blazing_layers": card.total_blazing_layers() \
            if card.has_method("total_blazing_layers") else 0,
        "participating": participating,
    }

func _observed_sides(request) -> Array:
    var result: Array = []
    for side in [request.owner, request.actor, request.target]:
        if side != null and side.has_method("capture_transaction_state") \
                and not result.has(side):
            result.append(side)
    return result

func _context_sides(owner, context: Dictionary) -> Array:
    var result: Array = []
    for side in [owner, context.get("actor", owner), context.get("target")]:
        if side != null and side.has_method("capture_transaction_state") \
                and not result.has(side):
            result.append(side)
    return result

func _purity_error(report: Dictionary) -> String:
    var errors: Array[String] = []
    if bool(report.get("rng_advanced", false)):
        errors.append("纯查询 Handler 不得推进战斗 RNG")
    if bool(report.get("committed_event_sent", false)):
        errors.append("纯查询 Handler 不得发送 committed 事件")
    if bool(report.get("state_mutated", false)):
        errors.append("纯查询 Handler 不得修改战斗状态")
    var restore_errors: Array = report.get("restore_errors", [])
    if not restore_errors.is_empty():
        errors.append("纯查询状态回滚失败：%s" % "；".join(restore_errors))
    return "；".join(errors)

func _failure(request, reason: String):
    return ResultScript.new().configure({
        "success": false,
        "hook": request.hook if request != null else "",
        "subject_kind": request.subject_kind if request != null else "",
        "subject_id": request.subject_id if request != null else "",
        "base_value": request.base_value if request != null else 0,
        "effective_value": request.base_value if request != null else 0,
        "errors": [reason],
    })

func _effective_failure(card, reason: String):
    return ResultScript.new().configure({
        "success": false,
        "hook": "effective_qi_query",
        "subject_kind": "qi_card",
        "subject_id": str(card.id) if card != null else "",
        "base_value": 0,
        "effective_value": 0,
        "errors": [reason],
    })

func _pre_life_loss_failure(context: Dictionary, reason: String):
    var proposed := maxi(0, int(context.get("proposed_life_loss", 0)))
    return ResultScript.new().configure({
        "success": false,
        "hook": "pre_life_loss_query",
        "subject_kind": "life_loss",
        "subject_id": str(context.get("damage_segment_token", "")),
        "base_value": proposed,
        "effective_value": proposed,
        "errors": [reason],
    })

func _stable_ids(values: Array) -> Array[String]:
    var result: Array[String] = []
    for value in values:
        var id := str(value)
        if id != "" and not result.has(id):
            result.append(id)
    result.sort()
    return result

func _stable_object_id(value) -> String:
    if value == null:
        return ""
    if not value is Object or not value.has_method("get_property_list"):
        return str(value)
    for property_name in ["owner_id", "instance_id", "id", "definition_id"]:
        for property in value.get_property_list():
            if str(property.get("name", "")) == property_name:
                return str(value.get(property_name))
    return value.get_class()

func report_failure(result, boundary: String) -> void:
    if result != null and not result.success and _scenario_error.is_valid():
        _scenario_error.call("战斗整数查询失败 boundary=%s hook=%s reason=%s" % [
            boundary, result.hook, "；".join(result.errors)])

func _stable_value(value):
    if value is Dictionary:
        var result: Dictionary = {}
        var keys: Array = value.keys()
        keys.sort_custom(func(left, right): return str(left) < str(right))
        for key in keys:
            result[str(key)] = _stable_value(value[key])
        return result
    if value is Array:
        return value.map(func(entry): return _stable_value(entry))
    if value == null or value is bool or value is int \
            or value is float or value is String:
        return value
    if value is Object:
        return {
            "object_class": value.get_class(),
            "stable_id": _stable_object_id(value),
        }
    return str(value)
