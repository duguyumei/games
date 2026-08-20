class_name BattlePureQueryGuard
extends RefCounted

## 战斗与本局只读策略的共享、可重入纯查询边界。
##
## 同一条嵌套查询链只在最外层捕获一次状态，并在最外层结束时统一检查、
## 回滚。内层查询可以补充新的状态参与者或独立卡牌，但不会再次深拷贝
## 已观察对象。完整 mutation 事务仍由 BattleRuntimeMutationTransaction 负责；
## 本类只验证查询纯度，二者不能互换。

var _rng: RandomNumberGenerator = null
var _committed_event_service = null

var _depth: int = 0
var _participant_entries: Array[Dictionary] = []
var _participant_keys: Dictionary = {}
var _card_entries: Array[Dictionary] = []
var _card_keys: Dictionary = {}
var _captured_status_keys: Dictionary = {}
var _rng_state: int = 0
var _has_rng_state: bool = false
var _event_scope_open: bool = false

func use_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng

func use_committed_event_service(service) -> void:
    _committed_event_service = service

## 执行一个纯查询。返回值位于 value；纯度报告与值并列返回。
## participants 支持 BattleSide 的正式事务快照，也支持 Run 侧
## capture_mutation_state/replace_mutation_state 协议。
func evaluate(
        callback: Callable,
        participants: Array = [],
        cards: Array = []) -> Dictionary:
    var root_scope := _depth == 0
    if root_scope:
        _begin_root_scope()
    _observe_participants(participants)
    _observe_cards(cards)
    _depth += 1
    var value = callback.call()
    _depth = maxi(0, _depth - 1)
    if not root_scope:
        return _report(value)
    return _finish_root_scope(value)

func active_depth() -> int:
    return _depth

func _begin_root_scope() -> void:
    _participant_entries.clear()
    _participant_keys.clear()
    _card_entries.clear()
    _card_keys.clear()
    _captured_status_keys.clear()
    _has_rng_state = _rng != null
    _rng_state = int(_rng.state) if _rng != null else 0
    _event_scope_open = false
    if _committed_event_service != null \
            and _committed_event_service.has_method("begin_pure_query"):
        _committed_event_service.begin_pure_query()
        _event_scope_open = true

func _finish_root_scope(value) -> Dictionary:
    var event_violation := false
    if _event_scope_open and _committed_event_service != null \
            and _committed_event_service.has_method("end_pure_query"):
        event_violation = bool(_committed_event_service.end_pure_query())
    _event_scope_open = false

    var rng_advanced := _has_rng_state and _rng != null \
        and int(_rng.state) != _rng_state
    if rng_advanced:
        _rng.state = _rng_state

    var current_participant_states: Array = []
    var current_card_states: Array = []
    var state_mutated := false
    for entry in _participant_entries:
        var current: Dictionary = _capture_participant(
            entry["participant"], str(entry["kind"]), entry["options"])
        current_participant_states.append(current)
        if current != entry["state"]:
            state_mutated = true
    for entry in _card_entries:
        var current: Dictionary = _capture_card_state(entry["card"])
        current_card_states.append(current)
        if current != entry["state"]:
            state_mutated = true

    var restore_errors: Array[String] = []
    if state_mutated:
        for index in range(_participant_entries.size()):
            if current_participant_states[index] == _participant_entries[index]["state"]:
                continue
            restore_errors.append_array(_restore_participant(
                _participant_entries[index]))
        for index in range(_card_entries.size()):
            if current_card_states[index] == _card_entries[index]["state"]:
                continue
            _restore_card_state(
                _card_entries[index]["card"], _card_entries[index]["state"])

    var result := _report(value)
    result.merge({
        "is_pure": not state_mutated and not rng_advanced \
            and not event_violation and restore_errors.is_empty(),
        "state_mutated": state_mutated,
        "rng_advanced": rng_advanced,
        "committed_event_sent": event_violation,
        "restore_errors": restore_errors,
    }, true)
    _participant_entries.clear()
    _participant_keys.clear()
    _card_entries.clear()
    _card_keys.clear()
    _captured_status_keys.clear()
    _has_rng_state = false
    return result

func _report(value) -> Dictionary:
    return {
        "value": value,
        "is_pure": true,
        "state_mutated": false,
        "rng_advanced": false,
        "committed_event_sent": false,
        "restore_errors": [] as Array[String],
    }

func _observe_participants(participants: Array) -> void:
    for participant in participants:
        if participant == null or not participant is Object:
            continue
        var key := str(participant.get_instance_id())
        if _participant_keys.has(key):
            continue
        var kind := _participant_kind(participant)
        if kind == "":
            continue
        var options := _capture_options(participant, kind)
        _participant_entries.append({
            "participant": participant,
            "kind": kind,
            "options": options,
            "state": _capture_participant(participant, kind, options),
        })
        _participant_keys[key] = true

func _observe_cards(cards: Array) -> void:
    for card in cards:
        if card == null or not card is Object:
            continue
        var key := str(card.get_instance_id())
        if _card_keys.has(key):
            continue
        _card_entries.append({
            "card": card,
            "state": _capture_card_state(card),
        })
        _card_keys[key] = true

func _participant_kind(participant) -> String:
    if participant.has_method("capture_transaction_state") \
            and participant.has_method("restore_transaction_state"):
        return "transaction"
    if participant.has_method("capture_mutation_state") \
            and participant.has_method("replace_mutation_state"):
        return "run_mutation"
    return ""

func _capture_options(participant, kind: String) -> Dictionary:
    if kind != "transaction" \
            or not participant.has_method("all_cards_for_run_sync"):
        return {}
    var status = participant.status_system
    if status == null:
        return {"include_status_system": false}
    var status_key := str(status.get_instance_id())
    var include_status := not _captured_status_keys.has(status_key)
    if include_status:
        _captured_status_keys[status_key] = true
    return {"include_status_system": include_status}

func _capture_participant(
        participant,
        kind: String,
        options: Dictionary) -> Dictionary:
    if kind == "run_mutation":
        return participant.capture_mutation_state()
    if participant.has_method("all_cards_for_run_sync"):
        return participant.capture_transaction_state(options)
    return participant.capture_transaction_state()

func _restore_participant(entry: Dictionary) -> Array[String]:
    var participant = entry["participant"]
    if str(entry["kind"]) == "run_mutation":
        var errors = participant.replace_mutation_state(entry["state"])
        if errors is Array:
            var result: Array[String] = []
            for error in errors:
                result.append(str(error))
            return result
        return [] as Array[String]
    participant.restore_transaction_state(entry["state"])
    return [] as Array[String]

func _capture_card_state(card) -> Dictionary:
    return {
        "definition_id": str(card.definition_id),
        "rank_name": str(card.rank_name),
        "rank_order": int(card.rank_order),
        "qi_value": int(card.qi_value),
        "attribute": str(card.attribute),
        "attribute_name": str(card.attribute_name),
        "is_true_qi": bool(card.is_true_qi),
        "reshape_origin": card.reshape_origin.duplicate(true),
        "reshape_enhancement": str(card.reshape_enhancement),
        "reshape_imprint": str(card.reshape_imprint),
        "reshape_others": card.reshape_others.duplicate(true),
        "anomalies": card.anomalies.duplicate(true),
        "temporary_reshapes": card.temporary_reshapes.duplicate(true),
        "temporary_blazing_layers": card.temporary_blazing_layers.duplicate(true),
        "origin_base_identity": card.origin_base_identity.duplicate(true),
        "original_owner_id": str(card.original_owner_id),
        "temporary_card": bool(card.temporary_card),
        "reshape_rule_service": card.reshape_rule_service,
    }

func _restore_card_state(card, state: Dictionary) -> void:
    card.definition_id = str(state["definition_id"])
    card.rank_name = str(state["rank_name"])
    card.rank_order = int(state["rank_order"])
    card.qi_value = int(state["qi_value"])
    card.attribute = str(state["attribute"])
    card.attribute_name = str(state["attribute_name"])
    card.is_true_qi = bool(state["is_true_qi"])
    card.reshape_origin = state["reshape_origin"].duplicate(true)
    card.reshape_enhancement = str(state["reshape_enhancement"])
    card.reshape_imprint = str(state["reshape_imprint"])
    card.reshape_others = state["reshape_others"].duplicate(true)
    card.anomalies = state["anomalies"].duplicate(true)
    card.temporary_reshapes = state["temporary_reshapes"].duplicate(true)
    card.temporary_blazing_layers = state["temporary_blazing_layers"].duplicate(true)
    card.origin_base_identity = state["origin_base_identity"].duplicate(true)
    card.original_owner_id = str(state["original_owner_id"])
    card.temporary_card = bool(state["temporary_card"])
    card.reshape_rule_service = state["reshape_rule_service"]
