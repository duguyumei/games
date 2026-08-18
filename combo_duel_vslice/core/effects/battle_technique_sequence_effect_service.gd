class_name BattleTechniqueSequenceEffectService
extends RefCounted

## 战斗功法槽容量和临时功法生成的提交编排服务。
##
## TechniqueSequenceBook 是容量、实例和位置的唯一事实源；本服务只负责解析
## 来源中立请求、建立稳定批次顺序、调用领域原子入口，并在整个批次完成后发送
## 已提交事件。功法、内功、物品和消耗品共用这里，不按内容 ID 分支。

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

var _repository_ref: WeakRef
var _committed_event_service
var _round_number_reader: Callable
var _rng: RandomNumberGenerator
var _generation_batch_serial: int = 0
var _trigger_queue = null


func use_technique_repository(repository) -> void:
    _repository_ref = weakref(repository) if repository != null else null


func use_passive_battle_services(
        event_service,
        round_reader: Callable = Callable()) -> void:
    _committed_event_service = event_service
    _round_number_reader = round_reader


func use_battle_rng(rng: RandomNumberGenerator) -> void:
    _rng = rng

func use_trigger_queue(queue) -> void:
    _trigger_queue = queue

func complete_and_advance(
        side,
        hand_id: String,
        completed_slot_instance_id: String,
        extra_advance_count: int = 0,
        source_records: Array = [],
        action_token: String = "",
        root_action_token: String = "",
        technique_execution_token: String = "") -> Dictionary:
    var book = _book_for(side)
    if book == null:
        return {"success": false, "reason": "参战者缺少功法序列簿"}
    if extra_advance_count < 0:
        return {"success": false, "reason": "额外序列推进不能为负数"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        [side], _committed_event_service, _trigger_queue, _rng)
    var sequence_before: Array = book.ordered_slots(hand_id)
    var normal: Dictionary = book.complete_slot(
        hand_id, completed_slot_instance_id)
    if not normal.get("success", false):
        BattleRuntimeMutationTransactionScript.rollback(transaction)
        return normal
    var current_after_normal: Array = book.ordered_slots(hand_id)
    for _index in range(extra_advance_count):
        var current: Dictionary = book.current_slot(hand_id)
        var current_id := str(current.get("slot_instance_id", ""))
        if current_id == "":
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {"success": false, "reason": "额外推进缺少当前功法槽位"}
        var advanced: Dictionary = book.complete_slot(hand_id, current_id)
        if not advanced.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return advanced
    var sequence_after: Array = book.ordered_slots(hand_id)
    if _committed_event_service != null:
        var serial := int(_committed_event_service.next_serial())
        var event: Dictionary = _committed_event_service.commit(
            "technique_sequence_changed", {
                "event_token": _committed_event_service.make_token(
                    "technique_sequence_changed", side, serial, action_token),
                "event_serial": serial,
                "actor": side,
                "owner": side,
                "action_token": action_token,
                "root_action_token": root_action_token,
                "technique_execution_token": technique_execution_token,
                "hand_id": hand_id,
                "completed_slot_instance_id": completed_slot_instance_id,
                "normal_advance_count": 1,
                "extra_advance_count": extra_advance_count,
                "sequence_before": sequence_before.duplicate(true),
                "sequence_after": sequence_after.duplicate(true),
                "source_records": source_records.duplicate(true),
                "reason": "technique_complete_and_advance",
                "round_number": _round_number(),
            })
        if not event.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {"success": false, "reason": str(event.get(
                "reason", "功法序列变化事件提交失败")), "rolled_back": true}
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return {
        "success": true,
        "sequence_before": sequence_before,
        "sequence_after": sequence_after,
        "normal_advance_count": 1,
        "extra_advance_count": extra_advance_count,
        "source_records": source_records.duplicate(true),
        "current_after_normal": current_after_normal,
    }


func slot_usage(side, hand_id: String) -> Dictionary:
    var book = _book_for(side)
    if book == null:
        return {"success": false, "reason": "参战者缺少功法序列簿"}
    if hand_id not in HAND_IDS:
        return {"success": false, "reason": "未知精确牌型：%s" % hand_id}
    var result: Dictionary = book.slot_usage(hand_id)
    result["success"] = true
    result["hand_id"] = hand_id
    return result


func change_slot_capacity(
        side,
        hand_id: String,
        delta: int,
        metadata: Dictionary = {}) -> Dictionary:
    var book = _book_for(side)
    if book == null:
        return {"success": false, "reason": "参战者缺少功法序列簿"}
    if hand_id not in HAND_IDS:
        return {"success": false, "reason": "未知精确牌型：%s" % hand_id}
    var options := {
        "minimum_capacity": int(metadata.get("minimum_capacity", 1)),
        "maximum_capacity": int(metadata.get("maximum_capacity", 9)),
        "requested_delta": int(metadata.get("requested_delta", delta)),
    }
    var result: Dictionary = book.change_slot_capacity(
        hand_id, delta, options)
    if not result.get("success", false) or not result.get("changed", false):
        return result
    var source := EffectSourceProtocolScript.from_values(metadata)
    var action_token := str(metadata.get("action_token", ""))
    var event_result := _commit_capacity_changed(
        side, hand_id, result, source, action_token)
    if not event_result.get("success", true):
        book.set_slot_capacity(hand_id, int(result["capacity_before"]), options)
        return {
            "success": false,
            "reason": str(event_result.get(
                "reason", "功法槽容量变化事件提交失败")),
            "rolled_back": true,
        }
    result["source"] = source
    return result


func generate_temporary_techniques(effect: Dictionary, context) -> Dictionary:
    var runtime = EffectContextScript.coerce(context)
    var side = runtime.actor
    var book = _book_for(side)
    if side == null or book == null or runtime.sequence_book != book:
        return {"success": false, "reason": "临时功法生成缺少当前参战者序列簿"}
    if _rng == null:
        return {"success": false, "reason": "临时功法生成缺少战斗随机源"}
    var repository = _repository()
    if repository == null:
        return {"success": false, "reason": "临时功法生成缺少功法仓库"}
    var source_result := _resolve_copied_technique(effect, runtime, book)
    if not source_result.get("success", false):
        return source_result
    var target_result := _resolve_target_hands(
        effect.get("target_hands", "current"), runtime.actual_hand_id)
    if not target_result.get("success", false):
        return target_result
    var technique_id := str(source_result.get("technique_id", ""))
    if repository.get_definition(technique_id) == null:
        return {"success": false, "reason": "未知功法：%s" % technique_id}
    var copies := int(effect.get("copies", 1))
    if copies < 0:
        return {"success": false, "reason": "临时功法份数不能为负数"}
    var marker_mode := str(effect.get("marker_mode", "independent"))
    if marker_mode not in ["independent", "share_origin"]:
        return {"success": false, "reason": "未知临时功法标识模式"}
    var origin_slot_id := str(source_result.get("origin_slot_instance_id", ""))
    if marker_mode == "share_origin" and (
            origin_slot_id == "" or _find_slot(book, origin_slot_id).is_empty()):
        return {
            "success": false,
            "reason": "share_origin 缺少合法原功法实例",
        }
    var batch_mode := str(effect.get("batch_mode", "partial"))
    if batch_mode not in ["partial", "atomic"]:
        return {"success": false, "reason": "未知临时功法批次模式"}
    var position := str(effect.get("position", "after_current"))
    if position not in ["before_current", "after_current", "random"]:
        return {"success": false, "reason": "未知临时功法插入位置"}
    _generation_batch_serial += 1
    var batch_token := "%s:generate:%06d" % [
        runtime.root_action_token \
            if runtime.root_action_token != "" else runtime.action_token,
        _generation_batch_serial,
    ]
    var generator_source := EffectSourceProtocolScript.from_context(runtime)
    var requests: Array = []
    for hand_id_value in target_result["hand_ids"]:
        var hand_id := str(hand_id_value)
        for copy_index in range(copies):
            requests.append({
                "hand_id": hand_id,
                "copy_index": copy_index,
                "technique_id": technique_id,
                "position": position,
                "marker_mode": marker_mode,
                "origin_technique_id": str(source_result.get(
                    "origin_technique_id", technique_id)),
                "origin_slot_instance_id": origin_slot_id,
                "generation_batch_token": batch_token,
                "generator_source_kind": str(generator_source["source_kind"]),
                "generator_source_id": str(generator_source["source_id"]),
                "generator_source_instance_key": str(
                    generator_source["source_instance_key"]),
            })
    var result: Dictionary = book.commit_temporary_generation(
        requests, batch_mode, _rng)
    if not result.get("success", false):
        return result
    result["generation_batch_token"] = batch_token
    result["source"] = generator_source.duplicate(true)
    ## 批次状态已经完整提交，事件回调不能影响尚未完成的容量判断。
    for slot_value in result.get("generated_slots", []):
        var slot_id := str(slot_value.get("slot_instance_id", ""))
        var event_remaining: int = book.remaining_slot_count(str(
            slot_value.get("hand_id", "")))
        for attempt_value in result.get("attempts", []):
            if str(attempt_value.get("slot_instance_id", "")) == slot_id:
                event_remaining = int(attempt_value.get(
                    "remaining_capacity", event_remaining))
                break
        _commit_temporary_generated(
            side, slot_value, generator_source,
            runtime.action_token, event_remaining)
    if int(result.get("generated_count", 0)) > 0:
        emit_technique_sequence_changed(
            side, runtime.action_token, "temporary_generate",
            result.get("generated_slots", []))
    return result


func clear_temporary_techniques(
        side,
        action_token: String = "") -> Dictionary:
    var book = _book_for(side)
    if book == null:
        return {"success": false, "reason": "参战者缺少功法序列簿"}
    var transaction := BattleRuntimeMutationTransactionScript.begin(
        [side], _committed_event_service, _trigger_queue, _rng)
    var result: Dictionary = book.release_all_temporary_slots()
    if int(result.get("removed_count", 0)) > 0:
        var emitted: Dictionary = emit_technique_sequence_changed(
            side, action_token, "battle_end_temporary_release",
            result.get("removed_slots", []))
        if not emitted.get("success", false):
            BattleRuntimeMutationTransactionScript.rollback(transaction)
            return {
                "success": false,
                "reason": str(emitted.get(
                    "reason", "临时功法清理事件提交失败")),
                "rolled_back": true,
            }
    BattleRuntimeMutationTransactionScript.commit(transaction)
    return result


func emit_technique_sequence_changed(
        side,
        action_token: String,
        reason: String,
        changed_slots: Array) -> Dictionary:
    if _committed_event_service == null:
        return {"success": true, "skipped": true}
    var serial := int(_committed_event_service.next_serial())
    return _committed_event_service.commit("technique_sequence_changed", {
        "event_token": _committed_event_service.make_token(
            "technique_sequence_changed", side, serial, action_token),
        "event_serial": serial,
        "actor": side,
        "owner": side,
        "action_token": action_token,
        "reason": reason,
        "changed_slots": changed_slots.duplicate(true),
        "round_number": _round_number(),
    })


func _resolve_copied_technique(
        effect: Dictionary,
        runtime,
        book) -> Dictionary:
    var source_spec = effect.get("technique_source", effect.get(
        "source", "current_source"))
    if effect.has("technique_id") and not effect.has("technique_source") \
            and not effect.has("source"):
        source_spec = {
            "mode": "by_id",
            "technique_id": str(effect.get("technique_id", "")),
        }
    var mode := ""
    var technique_id := ""
    var slot_instance_id := ""
    var explicit_hand_id: String = runtime.actual_hand_id
    if source_spec is Dictionary:
        mode = str(source_spec.get("mode", "current_source"))
        technique_id = str(source_spec.get("technique_id", ""))
        slot_instance_id = str(source_spec.get("slot_instance_id", ""))
        explicit_hand_id = str(source_spec.get(
            "hand_id", runtime.actual_hand_id))
    else:
        var text := str(source_spec)
        if text in ["self", "current_source", "current_slot"]:
            mode = "current_source" if text != "current_slot" else text
        else:
            mode = "by_id"
            technique_id = text
    var slot: Dictionary = {}
    match mode:
        "current_source":
            if runtime.source_kind != "technique" \
                    or runtime.slot_instance_id == "":
                return {
                    "success": false,
                    "reason": "当前来源不能解析为真实功法实例",
                }
            slot = _find_slot(book, runtime.slot_instance_id)
        "current_slot":
            if explicit_hand_id == "current":
                explicit_hand_id = runtime.actual_hand_id
            slot = book.current_slot(explicit_hand_id)
        "by_slot":
            slot = _find_slot(book, slot_instance_id)
        "by_id":
            if technique_id == "":
                return {"success": false, "reason": "临时功法请求缺少功法 ID"}
            return {
                "success": true,
                "technique_id": technique_id,
                "origin_technique_id": technique_id,
                "origin_slot_instance_id": "",
            }
        _:
            return {"success": false, "reason": "未知被复制功法来源模式"}
    if slot.is_empty():
        return {"success": false, "reason": "被复制的实际功法实例不存在"}
    return {
        "success": true,
        "technique_id": str(slot.get("technique_id", "")),
        "origin_technique_id": str(slot.get("technique_id", "")),
        "origin_slot_instance_id": str(slot.get("slot_instance_id", "")),
    }


func _resolve_target_hands(spec, current_hand_id: String) -> Dictionary:
    var requested: Array = []
    if spec is Array:
        requested = spec.duplicate()
    else:
        match str(spec):
            "current":
                requested = [current_hand_id]
            "all_other":
                requested = HAND_IDS.filter(
                    func(hand_id): return hand_id != current_hand_id)
            _:
                requested = [str(spec)]
    var unknown: Array[String] = []
    var included: Dictionary = {}
    for hand_id_value in requested:
        var hand_id := str(hand_id_value)
        if hand_id not in HAND_IDS:
            unknown.append(hand_id)
        else:
            included[hand_id] = true
    if not unknown.is_empty():
        return {
            "success": false,
            "reason": "未知临时功法目标牌型：%s" % "、".join(unknown),
        }
    var ordered: Array[String] = []
    for hand_id in HAND_IDS:
        if included.has(hand_id):
            ordered.append(hand_id)
    return {"success": true, "hand_ids": ordered}


func _commit_capacity_changed(
        side,
        hand_id: String,
        receipt: Dictionary,
        source: Dictionary,
        action_token: String) -> Dictionary:
    if _committed_event_service == null:
        return {"success": true, "skipped": true}
    var serial := int(_committed_event_service.next_serial())
    return _committed_event_service.commit("technique_slot_capacity_changed", {
        "event_token": _committed_event_service.make_token(
            "technique_slot_capacity_changed", side, serial, action_token),
        "event_serial": serial,
        "actor": side,
        "owner": side,
        "hand_id": hand_id,
        "capacity_before": int(receipt["capacity_before"]),
        "capacity_after": int(receipt["capacity_after"]),
        "requested_delta": int(receipt["requested_delta"]),
        "actual_delta": int(receipt["actual_delta"]),
        "occupied_count": int(receipt["occupied_count"]),
        "remaining_capacity": int(receipt["remaining_capacity"]),
        "source_kind": str(source["source_kind"]),
        "source_id": str(source["source_id"]),
        "source_name": str(source["source_name"]),
        "source_instance_key": str(source["source_instance_key"]),
        "action_token": action_token,
        "round_number": _round_number(),
    })


func _commit_temporary_generated(
        side,
        slot: Dictionary,
        source: Dictionary,
        action_token: String,
        remaining_capacity: int) -> Dictionary:
    if _committed_event_service == null:
        return {"success": true, "skipped": true}
    var serial := int(_committed_event_service.next_serial())
    return _committed_event_service.commit("temporary_technique_generated", {
        "event_token": _committed_event_service.make_token(
            "temporary_technique_generated", side, serial, action_token,
            str(slot.get("slot_instance_id", ""))),
        "event_serial": serial,
        "actor": side,
        "owner": side,
        "source_kind": str(source["source_kind"]),
        "source_id": str(source["source_id"]),
        "source_name": str(source["source_name"]),
        "source_instance_key": str(source["source_instance_key"]),
        "host_hand_id": str(slot.get("hand_id", "")),
        "technique_id": str(slot.get("technique_id", "")),
        "slot_instance_id": str(slot.get("slot_instance_id", "")),
        "origin_technique_id": str(slot.get("origin_technique_id", "")),
        "origin_slot_instance_id": str(slot.get(
            "origin_slot_instance_id", "")),
        "insertion_serial": int(slot.get("insertion_serial", 0)),
        "insertion_position": int(slot.get("insertion_position", -1)),
        "marker_mode": str(slot.get("marker_mode", "independent")),
        "generation_batch_token": str(slot.get(
            "generation_batch_token", "")),
        "remaining_capacity": remaining_capacity,
        "temporary": true,
        "action_token": action_token,
        "round_number": _round_number(),
    })


func _find_slot(book, slot_instance_id: String) -> Dictionary:
    if slot_instance_id == "":
        return {}
    for slot_value in book.find_slots({}):
        var slot: Dictionary = slot_value
        if str(slot.get("slot_instance_id", "")) == slot_instance_id:
            return slot
    return {}


func _book_for(side):
    return side.technique_sequence_book \
        if side != null and side.get("technique_sequence_book") != null \
        else null


func _repository():
    return _repository_ref.get_ref() if _repository_ref != null else null


func _round_number() -> int:
    return int(_round_number_reader.call()) \
        if _round_number_reader.is_valid() else 0
