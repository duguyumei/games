class_name CardZoneService
extends RefCounted

const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")
const BattleRuntimeMutationTransactionScript = preload(
    "res://core/battle_runtime_mutation_transaction.gd")

## 单个参战者的牌区移动与索引维护服务。
##
## 这里只保持抽牌堆、手牌、待出区和弃牌堆的一致性，不判断牌型、不结算功法，
## 也不决定一次行动何时提交。

const ACTIVE_ZONES := ["draw_pile", "hand", "staging", "discard_pile"]

var card_state_lifecycle
var status_system
var card_reshape_runtime
var committed_event_service
var round_number_reader: Callable
var battle_permission_service
var passive_rule_runtime
var battle_rng: RandomNumberGenerator
var trigger_queue
var card_batch_recorder
var mutation_scope_service = null
var _effect_batch_entries: Dictionary = {}

func _init(lifecycle = null) -> void:
    card_state_lifecycle = lifecycle

func use_card_state_lifecycle(lifecycle) -> void:
    card_state_lifecycle = lifecycle

func use_status_system(system) -> void:
    status_system = system

func use_card_reshape_runtime(runtime) -> void:
    card_reshape_runtime = runtime

func use_committed_event_service(service, round_reader: Callable = Callable()) -> void:
    committed_event_service = service
    round_number_reader = round_reader

func use_battle_permission_service(service) -> void:
    battle_permission_service = service

func use_passive_rule_runtime(runtime) -> void:
    passive_rule_runtime = runtime

func use_runtime_transaction_dependencies(
        rng: RandomNumberGenerator, queue) -> void:
    battle_rng = rng
    if queue != null:
        trigger_queue = queue

func use_card_batch_recorder(recorder) -> void:
    card_batch_recorder = recorder

func use_mutation_scope_service(service) -> void:
    mutation_scope_service = service

func _begin_mutation_transaction(
        sides: Array,
        rng_override: RandomNumberGenerator = null) -> Dictionary:
    if mutation_scope_service != null:
        return mutation_scope_service.begin()
    return BattleRuntimeMutationTransactionScript.begin(
        sides, committed_event_service, trigger_queue,
        rng_override if rng_override != null else battle_rng)

func _commit_mutation_transaction(transaction: Dictionary) -> Dictionary:
    if mutation_scope_service != null:
        return mutation_scope_service.commit(transaction)
    return BattleRuntimeMutationTransactionScript.commit(transaction)

func _rollback_mutation_transaction(transaction: Dictionary) -> bool:
    if mutation_scope_service != null:
        return mutation_scope_service.rollback(transaction)
    return BattleRuntimeMutationTransactionScript.rollback(transaction)

func capture_runtime_state() -> Dictionary:
    return {"effect_batch_entries": _effect_batch_entries.duplicate(true)}

func restore_runtime_state(state: Dictionary) -> void:
    _effect_batch_entries = state.get(
        "effect_batch_entries", {}).duplicate(true)

func take_effect_batch_entries(effect_execution_token: String) -> Array:
    var entries: Array = _effect_batch_entries.get(
        effect_execution_token, []).duplicate(true)
    _effect_batch_entries.erase(effect_execution_token)
    return entries

func reset_zones(side, cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    side.hand.clear()
    side.staging.clear()
    side.discard_pile.clear()
    side.temporarily_removed_cards.clear()
    side.draw_pile = cards.duplicate()
    for card in side.draw_pile:
        _bind_card_policies(side, card)
    if shuffle_cards:
        shuffle(side.draw_pile, rng)

func draw(
        side,
        count: int,
        draw_reason: String = "rule_draw",
        source_metadata: Dictionary = {}) -> Array:
    var drawn: Array = []
    var source := source_metadata.duplicate(true)
    if source.is_empty():
        source = {
            "source_kind": "rule",
            "source_id": draw_reason,
            "source_name": draw_reason,
            "source_instance_key": "rule:%s" % draw_reason,
            "trigger_mode": "direct",
        }
    source = EffectSourceProtocolScript.from_values(source)
    var transaction := _begin_mutation_transaction([side])
    var depletion_receipts: Array = []
    var failure := ""
    for _index in range(maxi(0, count)):
        if side.draw_pile.is_empty():
            if side.discard_pile.is_empty():
                break
            var replenished := _replace_draw_depletion(side, source)
            if not replenished.get("success", false):
                failure = str(replenished.get(
                    "reason", "牌库耗尽替换事务失败"))
                break
            if not replenished.get("replaced", false):
                break
            depletion_receipts.append(replenished)
            if side.draw_pile.is_empty():
                break
        var card = side.draw_pile.back()
        var metadata := source.duplicate(true)
        metadata["draw_reason"] = draw_reason
        var moved := move_card(
            side, "draw_pile", "hand", card, "draw", metadata)
        if not moved.get("success", false) \
                or not moved.get("passive_event_success", true):
            failure = str(moved.get("passive_event_reason", moved.get(
                "reason", "抽牌移动失败")))
            break
        drawn.append(card)
    if failure == "":
        var transaction_commit := _commit_mutation_transaction(transaction)
        if not transaction_commit.get("success", false):
            failure = str(transaction_commit.get(
                "reason", "抽牌事务提交失败"))
            drawn.clear()
            depletion_receipts.clear()
    else:
        _rollback_mutation_transaction(transaction)
        drawn.clear()
        depletion_receipts.clear()
    side.last_draw_result = {
        "success": failure == "",
        "requested_count": maxi(0, count),
        "drawn_count": drawn.size(),
        "cards": drawn.duplicate(),
        "depletion_receipts": depletion_receipts.duplicate(true),
        "reason": failure,
    }
    return drawn

func _replace_draw_depletion(side, source_metadata: Dictionary) -> Dictionary:
    if side == null or side.discard_pile.is_empty() \
            or passive_rule_runtime == null:
        return {"success": true, "replaced": false}
    var context_values := {
        "hook": "draw_depletion_replacement_query",
        "owner": side,
        "actor": side,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "payload": {
            "commit": true,
            "discard_count": side.discard_pile.size(),
            "draw_count": side.draw_pile.size(),
            "action_token": str(source_metadata.get("action_token", "")),
        },
    }
    var plan = passive_rule_runtime.build_execution_plan(
        "draw_depletion_replacement_query", context_values)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    for invocation in plan.invocations:
        var executed: Dictionary = passive_rule_runtime.execute_invocation(
            invocation, null, "mutation")
        if not executed.get("success", false):
            return executed
        var handler_result: Dictionary = executed.get("result", {})
        if not handler_result.get("matched", false):
            continue
        var metadata := _invocation_source_metadata(invocation)
        metadata.merge(source_metadata, false)
        var cards: Array = side.discard_pile.duplicate()
        var moved_entries: Array = []
        for card in cards:
            var moved := move_card(
                side, "discard_pile", "draw_pile", card,
                "draw_depletion_shuffle", metadata)
            if not moved.get("success", false) \
                    or moved.get("passive_event_success", true) == false:
                return {
                    "success": false,
                    "reason": str(moved.get(
                        "passive_event_reason", moved.get(
                            "reason", "耗尽洗回提交失败"))),
                }
            moved_entries.append(moved)
        if moved_entries.is_empty():
            return {"success": true, "replaced": false}
        shuffle(side.draw_pile, battle_rng)
        return {
            "success": true,
            "replaced": true,
            "source_instance_key": invocation.source.source_instance_key,
            "moved_count": moved_entries.size(),
            "counter": handler_result,
        }
    return {"success": true, "replaced": false}

func place_on_draw_pile_top(
        side, card, source_metadata: Dictionary = {}) -> Dictionary:
    if not side.draw_pile.has(card):
        return {"success": false, "reason": "目标真气不在抽牌堆"}
    var metadata := _with_frozen_counts(
        side, side, "draw_pile", "draw_pile", source_metadata)
    side.draw_pile.erase(card)
    side.draw_pile.append(card)
    metadata = _complete_frozen_counts(
        side, side, "draw_pile", "draw_pile", metadata)
    var event_result := _publish_card_moved(
        side, side, card, "draw_pile", "draw_pile",
        "place_on_top", "top", metadata)
    var result := {
        "success": true,
        "card": card,
        "from": "draw_pile",
        "to": "draw_pile_top",
    }
    _merge_event_failure(result, event_result)
    return result

func place_on_zone_bottom(
        side, zone_name: String, card,
        source_metadata: Dictionary = {}) -> Dictionary:
    if zone_name not in ACTIVE_ZONES:
        return {"success": false, "reason": "目标牌区无效"}
    var cards: Array = zone(side, zone_name)
    if not cards.has(card):
        return {"success": false, "reason": "目标真气不在指定牌区"}
    var metadata := _with_frozen_counts(
        side, side, zone_name, zone_name, source_metadata)
    cards.erase(card)
    cards.push_front(card)
    metadata = _complete_frozen_counts(
        side, side, zone_name, zone_name, metadata)
    var event_result := _publish_card_moved(
        side, side, card, zone_name, zone_name,
        "place_on_bottom", "bottom", metadata)
    var result := {
        "success": true,
        "card": card,
        "from": zone_name,
        "to": "%s_bottom" % zone_name,
    }
    _merge_event_failure(result, event_result)
    return result

func stage_cards(side, card_ids: Array) -> bool:
    var found: Array = []
    for card_id in card_ids:
        var card = find_card(side, "hand", str(card_id))
        if card == null or found.has(card):
            return false
        found.append(card)
    for card in found:
        if not _card_play_permission(side, card).get("allowed", false):
            return false
    for card in found:
        move_card(side, "hand", "staging", card, "stage")
    return true

func rollback_staging(side) -> Array:
    var cards: Array = side.staging.duplicate()
    for card in cards:
        move_card(side, "staging", "hand", card, "stage_rollback")
    return cards

func commit_staging(side) -> Array:
    return commit_selected_staging(side, side.staging.duplicate(), {})

func commit_selected_staging(
        side,
        selected_cards: Array,
        source_metadata: Dictionary = {}) -> Array:
    var committed: Array = []
    for card in selected_cards:
        if not side.staging.has(card):
            continue
        var logical_hand_before: int = side.hand.size() + side.staging.size()
        var metadata := source_metadata.duplicate(true)
        metadata.merge({
            "logical_from_zone": "hand",
            "hand_count_before": logical_hand_before,
            "hand_count_after": maxi(0, logical_hand_before - 1),
            "from_hand_count_before": logical_hand_before,
            "from_hand_count_after": maxi(0, logical_hand_before - 1),
            "from_zone_count_before": logical_hand_before,
            "from_zone_count_after": maxi(0, logical_hand_before - 1),
        }, true)
        committed.append(card)
        move_card(
            side, "staging", "discard_pile", card, "normal_play",
            metadata)
    return committed

func random_discard(
        side, count: int, rng: RandomNumberGenerator,
        source_metadata: Dictionary = {}) -> Array:
    return random_discard_result(
        side, count, rng, source_metadata).get("cards", [])

func random_discard_result(
        side, count: int, rng: RandomNumberGenerator,
        source_metadata: Dictionary = {}) -> Dictionary:
    var transaction := _begin_mutation_transaction([side], rng)
    var discarded: Array = []
    for _index in range(maxi(0, count)):
        var candidates: Array = side.hand.filter(
            func(card): return _can_explicit_discard(side, card))
        if candidates.is_empty():
            break
        var card = candidates[rng.randi_range(0, candidates.size() - 1)]
        var result := move_card(
            side, "hand", "discard_pile", card, "explicit_discard",
            source_metadata)
        if not result.get("success", false) \
                or not result.get("passive_event_success", true):
            _rollback_mutation_transaction(transaction)
            return {
                "success": false,
                "reason": str(result.get("passive_event_reason", result.get(
                    "reason", "随机弃牌提交失败"))),
                "cards": [],
            }
        discarded.append(card)
    var transaction_commit := _commit_mutation_transaction(transaction)
    if not transaction_commit.get("success", false):
        return {
            "success": false,
            "reason": str(transaction_commit.get(
                "reason", "随机弃牌事务提交失败")),
            "cards": [],
            "rolled_back": true,
        }
    return {"success": true, "cards": discarded}

func discard_all(side, source_metadata: Dictionary = {}) -> Array:
    return discard_all_result(side, source_metadata).get("cards", [])

func discard_all_result(
        side, source_metadata: Dictionary = {}) -> Dictionary:
    var transaction := _begin_mutation_transaction([side])
    var discarded: Array = []
    for card in side.hand.duplicate():
        if not _can_explicit_discard(side, card):
            continue
        var result := move_card(
            side, "hand", "discard_pile", card, "explicit_discard",
            source_metadata)
        if not result.get("success", false) \
                or not result.get("passive_event_success", true):
            _rollback_mutation_transaction(transaction)
            return {
                "success": false,
                "reason": str(result.get("passive_event_reason", result.get(
                    "reason", "全部弃牌提交失败"))),
                "cards": [],
            }
        discarded.append(card)
    var transaction_commit := _commit_mutation_transaction(transaction)
    if not transaction_commit.get("success", false):
        return {
            "success": false,
            "reason": str(transaction_commit.get(
                "reason", "全部弃牌事务提交失败")),
            "cards": [],
            "rolled_back": true,
        }
    return {"success": true, "cards": discarded}

func recover_from_discard(
        side,
        count: int,
        destination: String = "draw_pile") -> Array:
    if destination not in ["draw_pile", "hand"]:
        return []
    var recovered: Array = []
    for _index in range(maxi(0, count)):
        if side.discard_pile.is_empty():
            break
        var card = side.discard_pile.back()
        move_card(side, "discard_pile", destination, card, "recover")
        recovered.append(card)
    return recovered

func temporarily_remove(
        side,
        instance_id: String,
        reason: String = "burn",
        source_metadata: Dictionary = {}) -> Dictionary:
    if reason == "cost":
        return {
            "success": false,
            "reason": "reason=cost 必须使用正式真气消耗事务",
        }
    var location := find_active_location(side, instance_id)
    if location.is_empty():
        return {"success": false, "reason": "找不到要临时移出战斗的真气"}
    return _temporarily_remove_transaction(
        side, location["card"], str(location["zone"]), reason,
        source_metadata)

func permanently_remove(
        side,
        instance_id: String,
        reason: String = "permanent_remove",
        source_metadata: Dictionary = {}) -> Dictionary:
    var location := find_active_location(side, instance_id)
    if location.is_empty():
        for card in side.temporarily_removed_cards:
            if str(card.id) == instance_id:
                location = {"zone": "temporarily_removed", "card": card}
                break
    if location.is_empty():
        return {"success": false, "reason": "找不到要永久移出的真气"}
    var card = location["card"]
    var source_zone := str(location["zone"])
    var metadata := _with_frozen_counts(
        side, side, source_zone, "permanently_removed", source_metadata)
    if source_zone == "temporarily_removed":
        side.temporarily_removed_cards.erase(card)
    else:
        zone(side, source_zone).erase(card)
    var lifecycle_event_result := _apply_state_lifecycle(
        side, card, source_zone, "permanently_removed", reason, metadata)
    if not bool(card.temporary_card) and str(card.original_owner_id) == "":
        side.mark_permanently_removed(instance_id)
    metadata = _complete_frozen_counts(
        side, side, source_zone, "permanently_removed", metadata)
    var event_result := lifecycle_event_result
    if event_result.get("success", true) and reason != "battle_end_temporary":
        event_result = _publish_card_moved(
            side, side, card, source_zone, "permanently_removed",
            reason, "top", metadata)
    var result := {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": "permanently_removed",
        "reason": reason,
    }
    _merge_event_failure(result, event_result)
    return result

func temporarily_transfer(
        source_side,
        target_side,
        instance_id: String,
        destination: String = "draw_pile",
        reason: String = "temporary_transfer",
        source_metadata: Dictionary = {},
        placement: String = "top") -> Dictionary:
    if destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "临时夺取的目标牌区无效"}
    if placement not in ["top", "bottom"]:
        return {"success": false, "reason": "目标位置无效"}
    var location := find_active_location(source_side, instance_id)
    if location.is_empty():
        return {"success": false, "reason": "找不到要临时夺取的真气"}
    if has_instance(target_side, instance_id):
        return {"success": false, "reason": "目标牌区已经存在相同实例 ID"}
    var card = location["card"]
    var source_zone := str(location["zone"])
    var metadata := source_metadata.duplicate(true)
    metadata["original_owner_id"] = str(card.original_owner_id) \
        if str(card.original_owner_id) != "" else str(source_side.owner_id)
    metadata = _with_frozen_counts(
        source_side, target_side, source_zone, destination, metadata)
    zone(source_side, source_zone).erase(card)
    if str(card.original_owner_id) == "":
        card.original_owner_id = source_side.owner_id
    _insert_in_zone(target_side, destination, card, placement)
    metadata = _complete_frozen_counts(
        source_side, target_side, source_zone, destination, metadata)
    var result := {
        "success": true,
        "card": card,
        "from_owner": source_side.owner_id,
        "to_owner": target_side.owner_id,
        "from": source_zone,
        "to": destination,
        "reason": reason,
    }
    var event_result := _notify_arrival(
        source_side, target_side, card, source_zone, destination,
        reason, placement, metadata)
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

func temporarily_transfer_many(records: Array) -> Array:
    ## Freeze every cross-side source, remove them all, then publish arrivals.
    ## Responses therefore cannot observe only part of one atomic transfer batch.
    var prepared: Array = []
    var seen: Dictionary = {}
    var count_ledger: Dictionary = {}
    for record_value in records:
        var record: Dictionary = record_value
        var source_side = record.get("source_side")
        var target_side = record.get("target_side")
        var card = record.get("card")
        var source_zone := str(record.get("source_zone", "hand"))
        var destination_zone := str(record.get("destination_zone", "draw_pile"))
        var reason := str(record.get("reason", "temporary_transfer"))
        var placement := str(record.get("placement", "top"))
        if source_side == null or target_side == null or source_side == target_side \
                or card == null or seen.has(str(card.id)) \
                or source_zone not in ACTIVE_ZONES \
                or destination_zone not in ACTIVE_ZONES \
                or placement not in ["top", "bottom"]:
            continue
        if not zone(source_side, source_zone).has(card) \
                or has_instance(target_side, str(card.id)):
            continue
        seen[str(card.id)] = true
        var metadata: Dictionary = record.get(
            "source_metadata", {}).duplicate(true)
        metadata["pre_move_snapshot"] = _pre_move_snapshot(
            source_side, card, source_zone)
        metadata["original_owner_id"] = str(card.original_owner_id) \
            if str(card.original_owner_id) != "" else str(source_side.owner_id)
        metadata = _with_ledger_counts(
            source_side, target_side, source_zone, destination_zone,
            metadata, count_ledger)
        prepared.append({
            "source_side": source_side, "target_side": target_side,
            "source_zone": source_zone, "destination_zone": destination_zone,
            "card": card, "reason": reason, "placement": placement,
            "source_metadata": metadata,
        })
    _stamp_movement_batch(prepared, "temporary_transfer")
    for entry in prepared:
        zone(entry["source_side"], entry["source_zone"]).erase(entry["card"])
        if str(entry["card"].original_owner_id) == "":
            entry["card"].original_owner_id = entry["source_side"].owner_id
    for entry in prepared:
        _insert_in_zone(
            entry["target_side"], entry["destination_zone"], entry["card"],
            entry["placement"])
    var moved: Array = []
    for entry in prepared:
        var metadata: Dictionary = entry["source_metadata"].duplicate(true)
        _notify_arrival(
            entry["source_side"], entry["target_side"], entry["card"],
            entry["source_zone"], entry["destination_zone"],
            entry["reason"], entry["placement"], metadata)
        moved.append(entry["card"])
    return moved

func return_transferred(
        holder_side,
        original_side,
        instance_id: String,
        destination: String = "draw_pile") -> Dictionary:
    if destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "归还真气的目标牌区无效"}
    var location := find_active_location(holder_side, instance_id)
    if location.is_empty():
        return {"success": false, "reason": "当前持有者没有要归还的真气"}
    var card = location["card"]
    if str(card.original_owner_id) != original_side.owner_id:
        return {"success": false, "reason": "真气的原持有者不匹配"}
    var source_zone := str(location["zone"])
    var metadata := _with_frozen_counts(
        holder_side, original_side, source_zone, destination, {
            "original_owner_id": str(card.original_owner_id),
        })
    zone(holder_side, source_zone).erase(card)
    card.original_owner_id = ""
    zone(original_side, destination).append(card)
    metadata = _complete_frozen_counts(
        holder_side, original_side, source_zone, destination, metadata)
    var result := {
        "success": true,
        "card": card,
        "from_owner": holder_side.owner_id,
        "to_owner": original_side.owner_id,
        "from": source_zone,
        "to": destination,
        "reason": "return_transfer",
    }
    var event_result := _notify_arrival(
        holder_side, original_side, card, source_zone, destination,
        "return_transfer", "top", metadata)
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

func return_all_transferred_cards(sides: Array) -> Array:
    var side_by_owner_id := {}
    for side in sides:
        if side != null:
            side_by_owner_id[str(side.owner_id)] = side
    var frozen: Array = []
    for holder in sides:
        if holder == null:
            continue
        for zone_name in ACTIVE_ZONES + ["temporarily_removed"]:
            var source: Array = (
                holder.temporarily_removed_cards
                if zone_name == "temporarily_removed"
                else zone(holder, zone_name))
            for card in source:
                var original_owner_id := str(card.original_owner_id)
                if original_owner_id != "" and side_by_owner_id.has(original_owner_id):
                    frozen.append({
                        "holder": holder,
                        "source_zone": zone_name,
                        "card": card,
                        "original": side_by_owner_id[original_owner_id],
                    })
    var returned: Array = []
    for entry in frozen:
        var holder = entry["holder"]
        var original = entry["original"]
        var card = entry["card"]
        var source_zone := str(entry["source_zone"])
        var source: Array = (
            holder.temporarily_removed_cards
            if source_zone == "temporarily_removed"
            else zone(holder, source_zone))
        if not source.has(card):
            continue
        if holder == original:
            card.original_owner_id = ""
            returned.append(card)
            continue
        source.erase(card)
        card.original_owner_id = ""
        original.draw_pile.append(card)
        returned.append(card)
    return returned

func add_generated(
        side, card, destination: String, temporary: bool,
        source_metadata: Dictionary = {}) -> Dictionary:
    if card == null or destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "生成真气的目标牌区无效"}
    if has_instance(side, str(card.id)):
        return {"success": false, "reason": "真气实例 ID 已存在于战斗牌区"}
    card.temporary_card = temporary
    _bind_card_policies(side, card)
    var metadata := _with_frozen_counts(
        null, side, "generated", destination, source_metadata)
    zone(side, destination).append(card)
    var reason := "temporary_generate" if temporary else "permanent_generate"
    var result := {
        "success": true,
        "card": card,
        "from": "generated",
        "to": destination,
        "reason": reason,
    }
    metadata = _complete_frozen_counts(
        null, side, "generated", destination, metadata)
    var event_result := _notify_arrival(
        null, side, card, "generated", destination, reason, "top", metadata)
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

func move_card(
        side,
        source_zone: String,
        destination_zone: String,
        card,
        reason: String,
        event_metadata: Dictionary = {},
        placement: String = "top") -> Dictionary:
    if source_zone not in ACTIVE_ZONES or destination_zone not in ACTIVE_ZONES:
        return {"success": false, "reason": "未知牌区"}
    var source: Array = zone(side, source_zone)
    if not source.has(card):
        return {"success": false, "reason": "来源牌区没有目标真气"}
    if reason == "explicit_discard":
        var permission := _explicit_discard_permission(side, card)
        if not permission.get("allowed", true):
            return {
                "success": false,
                "reason": str(permission.get("reason", "此真气不能被明确弃掉")),
            }
    if placement not in ["top", "bottom"]:
        return {"success": false, "reason": "目标位置无效"}
    var pre_move_snapshot := _pre_move_snapshot(side, card, source_zone)
    event_metadata = event_metadata.duplicate(true)
    event_metadata["pre_move_snapshot"] = pre_move_snapshot
    if card.has_anomaly("mark", "void") and reason in ["normal_play", "explicit_discard"]:
        return _resolve_void_departure(
            side, source_zone, card, reason, event_metadata, pre_move_snapshot)
    if destination_zone == "discard_pile":
        var disposition := _resolve_disposition_replacement(
            side, card, source_zone, reason, event_metadata)
        if not disposition.get("success", false):
            return disposition
        if disposition.get("replaced", false):
            return _commit_disposition_replacement(
                side, card, source_zone, reason, event_metadata,
                pre_move_snapshot, disposition)
    var publish_fact := reason not in ["stage", "stage_rollback"]
    if publish_fact:
        event_metadata = _with_frozen_counts(
            side, side, source_zone, destination_zone, event_metadata)
    _remove_from_source_zone(side, card, source_zone, reason)
    _insert_in_zone(side, destination_zone, card, placement)
    var event_result := {"success": true}
    if publish_fact:
        event_metadata = _complete_frozen_counts(
            side, side, source_zone, destination_zone, event_metadata)
        event_result = _notify_arrival(
            side, side, card, source_zone, destination_zone,
            reason, placement, event_metadata)
    var result := {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": destination_zone,
        "reason": reason,
        "pre_move_snapshot": pre_move_snapshot,
    }
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

func _resolve_disposition_replacement(
        side, card, source_zone: String, reason: String,
        event_metadata: Dictionary) -> Dictionary:
    if passive_rule_runtime == null:
        return {"success": true, "replaced": false}
    var context_values := {
        "hook": "card_disposition_replacement_query",
        "owner": side,
        "actor": side,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "payload": {
            "card": card,
            "card_instance_id": str(card.id),
            "source_zone": source_zone,
            "original_destination": "discard_pile",
            "reason": reason,
            "explicit_discard": reason == "explicit_discard",
            "normal_play": reason == "normal_play",
            "action_token": str(event_metadata.get("action_token", "")),
        },
    }
    var plan = passive_rule_runtime.build_execution_plan(
        "card_disposition_replacement_query", context_values)
    if not plan.is_valid():
        return {"success": false, "reason": "；".join(plan.errors)}
    for invocation in plan.invocations:
        var executed: Dictionary = passive_rule_runtime.execute_invocation(
            invocation, null, "read")
        if not executed.get("success", false):
            return executed
        var handler_result: Dictionary = executed.get("result", {})
        if not handler_result.get("matched", false):
            continue
        return {
            "success": true,
            "replaced": true,
            "destination": str(handler_result.get("destination", "")),
            "invocation": invocation,
            "source_instance_key": invocation.source.source_instance_key,
        }
    return {"success": true, "replaced": false}

func _commit_disposition_replacement(
        side, card, source_zone: String, reason: String,
        event_metadata: Dictionary, pre_move_snapshot: Dictionary,
        disposition: Dictionary) -> Dictionary:
    var destination := str(disposition.get("destination", ""))
    if destination not in ["draw_pile_bottom", "permanently_removed"]:
        return {"success": false, "reason": "牌区处置替换返回了无效去向"}
    var final_zone := "draw_pile" \
        if destination == "draw_pile_bottom" else "permanently_removed"
    var invocation = disposition.get("invocation")
    var metadata := _with_disposition_metadata(
        event_metadata, invocation, reason, final_zone,
        str(disposition.get("source_instance_key", "")))
    metadata.merge({
        "pre_move_snapshot": pre_move_snapshot,
    }, true)
    metadata = _with_frozen_counts(
        side, side, source_zone, final_zone, metadata)
    var transaction := _begin_mutation_transaction([side])
    _remove_from_source_zone(side, card, source_zone, reason)
    if final_zone == "draw_pile":
        _insert_in_zone(side, final_zone, card, "bottom")
    elif not bool(card.temporary_card) and str(card.original_owner_id) == "":
        side.mark_permanently_removed(str(card.id))
    var lifecycle := _apply_state_lifecycle(
        side, card, source_zone, final_zone, reason, metadata)
    if not lifecycle.get("success", true):
        _rollback_mutation_transaction(transaction)
        return {
            "success": false,
            "reason": str(lifecycle.get("reason", "处置替换生命周期失败")),
        }
    metadata = _complete_frozen_counts(
        side, side, source_zone, final_zone, metadata)
    var moved := _publish_card_moved(
        side, side, card, source_zone, final_zone, reason,
        "bottom" if final_zone == "draw_pile" else "top", metadata, true)
    if not moved.get("success", true):
        _rollback_mutation_transaction(transaction)
        return {
            "success": false,
            "reason": str(moved.get("reason", "处置替换 card_moved 提交失败")),
        }
    if reason == "explicit_discard":
        var explicit := _emit_logical_explicit_discard_event(
            side, card, source_zone, final_zone, metadata)
        if not explicit.get("success", true):
            _rollback_mutation_transaction(transaction)
            return {
                "success": false,
                "reason": str(explicit.get(
                    "reason", "处置替换明确弃置事实提交失败")),
            }
    _dispatch_deferred_card_moved_response(moved)
    var transaction_commit := _commit_mutation_transaction(transaction)
    if not transaction_commit.get("success", false):
        return {
            "success": false,
            "reason": str(transaction_commit.get(
                "reason", "处置替换事务提交失败")),
            "rolled_back": true,
        }
    return {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": final_zone,
        "reason": reason,
        "placement": "bottom" if final_zone == "draw_pile" else "top",
        "pre_move_snapshot": pre_move_snapshot,
        "logical_explicit_discard": reason == "explicit_discard",
        "disposition_replaced": true,
        "disposition_source_instance_key": str(
            disposition.get("source_instance_key", "")),
    }

func _emit_logical_explicit_discard_event(
        side, card, source_zone: String, final_zone: String,
        metadata: Dictionary) -> Dictionary:
    if committed_event_service == null:
        return {"success": true}
    var event_serial := int(committed_event_service.next_serial())
    var source := EffectSourceProtocolScript.from_values(metadata)
    return committed_event_service.commit("card_explicitly_discarded", {
        "actor": side,
        "owner": side,
        "holder": side,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "event_serial": event_serial,
        "event_token": committed_event_service.make_token(
            "card_explicitly_discarded", side, event_serial,
            str(metadata.get("action_token", "")), str(card.id)),
        "action_token": str(metadata.get("action_token", "")),
        "card": card,
        "card_instance_id": str(card.id),
        "from_zone": source_zone,
        "to_zone": final_zone,
        "reason": "explicit_discard",
        "explicit_discard": true,
        "logical_explicit_discard": true,
        "disposition_replaced": true,
        "original_destination": "discard_pile",
        "final_destination": final_zone,
        "source_kind": source["source_kind"],
        "source_id": source["source_id"],
        "source_name": source["source_name"],
        "source_instance_key": source["source_instance_key"],
        "trigger_mode": source["trigger_mode"],
        "metadata": metadata,
    })

func _invocation_source_metadata(invocation) -> Dictionary:
    if invocation == null or invocation.source == null:
        return {}
    return {
        "source_kind": invocation.source.source_kind,
        "source_id": invocation.source.content_id,
        "source_name": str(invocation.source.definition.get(
            "name", invocation.source.content_id)),
        "source_instance_key": invocation.source.source_instance_key,
        "trigger_mode": "automatic",
    }

func _with_disposition_metadata(
        base: Dictionary, invocation, reason: String, final_zone: String,
        source_instance_key: String) -> Dictionary:
    var metadata := base.duplicate(true)
    var disposition_source := _invocation_source_metadata(invocation)
    metadata.merge({
        "logical_explicit_discard": reason == "explicit_discard",
        "explicit_discard": reason == "explicit_discard",
        "disposition_replaced": true,
        "original_destination": "discard_pile",
        "final_destination": final_zone,
        "disposition_source_kind": str(disposition_source.get(
            "source_kind", "")),
        "disposition_source_id": str(disposition_source.get("source_id", "")),
        "disposition_source_name": str(disposition_source.get(
            "source_name", "")),
        "disposition_source_instance_key": source_instance_key,
    }, true)
    return metadata

func move_cards_synchronously(records: Array) -> Dictionary:
    ## Freeze and remove every source first, then publish arrivals in stable order.
    ## This prevents bilateral discard and exchange responses from observing a half-moved state.
    var prepared: Array = []
    var seen: Dictionary = {}
    var count_ledger: Dictionary = {}
    var transaction_sides: Array = []
    for record_value in records:
        var record: Dictionary = record_value
        var side = record.get("side")
        var card = record.get("card")
        var source_zone := str(record.get("source_zone", "hand"))
        var destination_zone := str(record.get("destination_zone", "discard_pile"))
        var reason := str(record.get("reason", "effect"))
        var placement := str(record.get("placement", "top"))
        if side == null or card == null or source_zone not in ACTIVE_ZONES \
                or destination_zone not in ACTIVE_ZONES \
                or placement not in ["top", "bottom"] \
                or seen.has(str(card.id)):
            continue
        if not zone(side, source_zone).has(card):
            continue
        if reason == "explicit_discard" \
                and not _explicit_discard_permission(side, card).get("allowed", true):
            continue
        seen[str(card.id)] = true
        if not transaction_sides.has(side):
            transaction_sides.append(side)
        var metadata: Dictionary = record.get(
            "source_metadata", {}).duplicate(true)
        var snapshot := _pre_move_snapshot(side, card, source_zone)
        metadata["pre_move_snapshot"] = snapshot
        var void_departure: bool = card.has_anomaly("mark", "void") \
            and reason in ["normal_play", "explicit_discard"]
        var disposition := {"success": true, "replaced": false}
        if not void_departure and destination_zone == "discard_pile":
            disposition = _resolve_disposition_replacement(
                side, card, source_zone, reason, metadata)
            if not disposition.get("success", false):
                return {
                    "success": false,
                    "reason": str(disposition.get(
                        "reason", "同步牌区处置替换查询失败")),
                    "cards": [],
                    "entries": [],
                }
        var final_zone := destination_zone
        var final_placement := placement
        if disposition.get("replaced", false):
            final_zone = "draw_pile" \
                if str(disposition.get("destination", "")) \
                    == "draw_pile_bottom" else "permanently_removed"
            if final_zone not in ["draw_pile", "permanently_removed"]:
                return {
                    "success": false,
                    "reason": "同步牌区处置替换返回了无效去向",
                    "cards": [],
                    "entries": [],
                }
            final_placement = "bottom" if final_zone == "draw_pile" else "top"
            metadata = _with_disposition_metadata(
                metadata, disposition.get("invocation"), reason, final_zone,
                str(disposition.get("source_instance_key", "")))
        var ledger_destination := "temporarily_removed" \
            if void_departure else final_zone
        metadata = _with_ledger_counts(
            side, side, source_zone, ledger_destination,
            metadata, count_ledger)
        prepared.append({
            "side": side, "card": card, "source_zone": source_zone,
            "destination_zone": final_zone, "reason": reason,
            "placement": final_placement,
            "source_metadata": metadata,
            "void": void_departure,
            "disposition_replaced": disposition.get("replaced", false),
        })
    if prepared.is_empty():
        return {"success": true, "cards": [], "entries": []}
    _stamp_movement_batch(prepared, "synchronous_move")
    var transaction := _begin_mutation_transaction(transaction_sides)
    for entry in prepared:
        if bool(entry["void"]):
            _place_in_temporary_removed(
                entry["side"], entry["card"], entry["source_zone"], "void")
        else:
            _remove_from_source_zone(
                entry["side"], entry["card"], entry["source_zone"],
                entry["reason"])
    for entry in prepared:
        if not bool(entry["void"]) \
                and entry["destination_zone"] != "permanently_removed":
            _insert_in_zone(
                entry["side"], entry["destination_zone"], entry["card"],
                entry["placement"])
        elif not bool(entry["void"]) \
                and not bool(entry["card"].temporary_card) \
                and str(entry["card"].original_owner_id) == "":
            entry["side"].mark_permanently_removed(str(entry["card"].id))
    var committed_entries: Array = []
    for entry in prepared:
        var side = entry["side"]
        var card = entry["card"]
        var metadata: Dictionary = entry["source_metadata"].duplicate(true)
        var result: Dictionary
        if bool(entry["void"]):
            if entry["reason"] == "explicit_discard":
                if status_system != null:
                    status_system.on_card_explicit_discard(side, card, true)
                metadata["explicit_discard"] = true
                metadata["logical_explicit_discard"] = true
                metadata["original_destination"] = "discard_pile"
                metadata["final_destination"] = "temporarily_removed"
            var lifecycle_event_result := _apply_temporary_remove_lifecycle(
                side, card, entry["source_zone"], "void", metadata)
            result = _finish_temporary_remove(
                side, card, entry["source_zone"], "void", metadata,
                lifecycle_event_result)
        elif bool(entry["disposition_replaced"]):
            var lifecycle := _apply_state_lifecycle(
                side, card, entry["source_zone"], entry["destination_zone"],
                entry["reason"], metadata)
            result = lifecycle
            var moved_result := {"success": true}
            if result.get("success", true):
                moved_result = _publish_card_moved(
                    side, side, card, entry["source_zone"],
                    entry["destination_zone"], entry["reason"],
                    entry["placement"], metadata, true)
                result = moved_result
            if result.get("success", true) \
                    and entry["reason"] == "explicit_discard":
                result = _emit_logical_explicit_discard_event(
                    side, card, entry["source_zone"],
                    entry["destination_zone"], metadata)
            if result.get("success", true):
                _dispatch_deferred_card_moved_response(moved_result)
        else:
            result = _notify_arrival(
                side, side, card, entry["source_zone"],
                entry["destination_zone"], entry["reason"],
                entry["placement"], metadata)
        if not result.get("success", true):
            _rollback_mutation_transaction(transaction)
            return {
                "success": false,
                "reason": str(result.get("reason", "同步牌区移动提交失败")),
                "cards": [],
                "entries": [],
            }
        committed_entries.append({
            "card": card,
            "from": entry["source_zone"],
            "to": "temporarily_removed" if bool(entry["void"]) \
                else entry["destination_zone"],
            "reason": entry["reason"],
            "logical_explicit_discard": entry["reason"] == "explicit_discard",
            "disposition_replaced": bool(entry["disposition_replaced"]),
        })
    var transaction_commit := _commit_mutation_transaction(transaction)
    if not transaction_commit.get("success", false):
        return {
            "success": false,
            "reason": str(transaction_commit.get(
                "reason", "同步牌区移动事务提交失败")),
            "cards": [],
            "entries": [],
            "rolled_back": true,
        }
    return {
        "success": true,
        "cards": committed_entries.map(func(value): return value["card"]),
        "entries": committed_entries,
    }

## Atomically replaces the draw-pile order after a caller has frozen the
## complete before/after arrays. Reordering does not move a card between zones,
## so it deliberately emits no card_moved fact; all writes still stay owned by
## CardZoneService instead of an effect Handler.
func reorder_draw_pile(
        side,
        expected_order: Array,
        replacement_order: Array) -> Dictionary:
    if side == null:
        return {"success": false, "reason": "重排牌库缺少持有者"}
    if side.draw_pile != expected_order:
        return {"success": false, "reason": "牌库顺序已离开冻结快照"}
    if expected_order.size() != replacement_order.size():
        return {"success": false, "reason": "重排前后牌库数量不一致"}
    var expected_ids: Dictionary = {}
    var replacement_ids: Dictionary = {}
    for card in expected_order:
        if card == null or expected_ids.has(str(card.id)):
            return {"success": false, "reason": "重排前牌库包含无效或重复实例"}
        expected_ids[str(card.id)] = true
    for card in replacement_order:
        if card == null or replacement_ids.has(str(card.id)):
            return {"success": false, "reason": "重排后牌库包含无效或重复实例"}
        replacement_ids[str(card.id)] = true
    if expected_ids != replacement_ids:
        return {"success": false, "reason": "重排前后牌库实例集合不一致"}
    side.draw_pile.assign(replacement_order)
    return {
        "success": true,
        "card_count": replacement_order.size(),
    }

func atomic_exchange(
        actor_side, actor_zone: String, actor_card,
        target_side, target_zone: String, target_card,
        event_metadata: Dictionary = {}) -> Dictionary:
    if actor_side == null or target_side == null or actor_side == target_side:
        return {"success": false, "reason": "原子交换需要不同的双方"}
    if not zone(actor_side, actor_zone).has(actor_card) \
            or not zone(target_side, target_zone).has(target_card):
        return {"success": false, "reason": "原子交换来源牌已离开冻结牌区"}
    var actor_snapshot := _pre_move_snapshot(actor_side, actor_card, actor_zone)
    var target_snapshot := _pre_move_snapshot(target_side, target_card, target_zone)
    var count_ledger: Dictionary = {}
    var actor_metadata := event_metadata.duplicate(true)
    actor_metadata.merge({
        "pre_move_snapshot": actor_snapshot,
        "original_owner_id": str(actor_card.original_owner_id) \
            if str(actor_card.original_owner_id) != "" else str(actor_side.owner_id),
    }, true)
    actor_metadata = _with_ledger_counts(
        actor_side, target_side, actor_zone, "hand",
        actor_metadata, count_ledger)
    var target_metadata := event_metadata.duplicate(true)
    target_metadata.merge({
        "pre_move_snapshot": target_snapshot,
        "original_owner_id": str(target_card.original_owner_id) \
            if str(target_card.original_owner_id) != "" else str(target_side.owner_id),
    }, true)
    target_metadata = _with_ledger_counts(
        target_side, actor_side, target_zone, "hand",
        target_metadata, count_ledger)
    var batch_entries := [
        {"source_metadata": actor_metadata},
        {"source_metadata": target_metadata},
    ]
    _stamp_movement_batch(batch_entries, "atomic_exchange")
    actor_metadata = batch_entries[0]["source_metadata"]
    target_metadata = batch_entries[1]["source_metadata"]
    _remove_from_source_zone(
        actor_side, actor_card, actor_zone, "atomic_exchange")
    _remove_from_source_zone(
        target_side, target_card, target_zone, "atomic_exchange")
    if str(actor_card.original_owner_id) == "":
        actor_card.original_owner_id = actor_side.owner_id
    if str(target_card.original_owner_id) == "":
        target_card.original_owner_id = target_side.owner_id
    zone(actor_side, "hand").append(target_card)
    zone(target_side, "hand").append(actor_card)
    _notify_arrival(
        actor_side, target_side, actor_card, actor_zone, "hand",
        "atomic_exchange", "top", actor_metadata)
    _notify_arrival(
        target_side, actor_side, target_card, target_zone, "hand",
        "atomic_exchange", "top", target_metadata)
    return {"success": true, "actor_received": target_card, "target_received": actor_card,
        "actor_sent_snapshot": actor_snapshot, "target_sent_snapshot": target_snapshot}

func _resolve_void_departure(
        side,
        source_zone: String,
        card,
        reason: String,
        event_metadata: Dictionary,
        pre_move_snapshot: Dictionary) -> Dictionary:
    if reason == "explicit_discard":
        if status_system != null:
            status_system.on_card_explicit_discard(side, card, true)
        event_metadata["explicit_discard"] = true
        event_metadata["logical_explicit_discard"] = true
        event_metadata["original_destination"] = "discard_pile"
        event_metadata["final_destination"] = "temporarily_removed"
    var result := _temporarily_remove_transaction(
        side, card, source_zone, "void", event_metadata, pre_move_snapshot)
    result["reason"] = reason
    result["dispersed"] = true
    return result

func _temporarily_remove_transaction(
        side, card, source_zone: String, reason: String,
        event_metadata: Dictionary = {}, frozen_snapshot: Dictionary = {}) -> Dictionary:
    if reason == "cost" and not bool(event_metadata.get(
            "qi_consumption_transaction", false)):
        return {
            "success": false,
            "reason": "reason=cost 不得绕过正式真气消耗事务",
        }
    if side == null or card == null or source_zone not in ACTIVE_ZONES \
            or not zone(side, source_zone).has(card):
        return {"success": false, "reason": "临时移出来源已失效"}
    var snapshot := frozen_snapshot.duplicate(true) \
        if not frozen_snapshot.is_empty() else _pre_move_snapshot(side, card, source_zone)
    var metadata := event_metadata.duplicate(true)
    metadata["pre_move_snapshot"] = snapshot
    metadata = _with_frozen_counts(
        side, side, source_zone, "temporarily_removed", metadata)
    _place_in_temporary_removed(side, card, source_zone, reason)
    var lifecycle_event_result := _apply_temporary_remove_lifecycle(
        side, card, source_zone, reason, metadata)
    return _finish_temporary_remove(
        side, card, source_zone, reason, metadata, lifecycle_event_result)


func capture_pre_move_snapshot(
        side, card, source_zone: String) -> Dictionary:
    if side == null or card == null or source_zone not in ACTIVE_ZONES \
            or not zone(side, source_zone).has(card):
        return {}
    return _pre_move_snapshot(side, card, source_zone)


func commit_qi_consumption_entries(
        side,
        plan: Dictionary,
        source_metadata: Dictionary = {}) -> Dictionary:
    var operation_token := str(plan.get("operation_token", ""))
    var batch_token := str(plan.get("consumption_batch_token", ""))
    var entries: Array = plan.get("entries", [])
    if side == null or operation_token == "" or batch_token == "" \
            or entries.is_empty():
        return {"success": false, "reason": "真气消耗计划缺少稳定事务身份或目标"}
    if side.qi_consumption_receipts.has(operation_token):
        var planned_ids: Array = entries.map(func(entry):
            return str(entry.get("card_instance_id", "")))
        var receipt_ids: Array = side.qi_consumption_receipts[
            operation_token].get("card_instance_ids", [])
        if planned_ids != receipt_ids:
            return {
                "success": false,
                "reason": "真气消耗 operation token 已绑定另一批目标",
            }
        var reused: Dictionary = side.qi_consumption_receipts[
            operation_token].duplicate(true)
        reused["reused"] = true
        return reused
    var count := entries.size()
    var exact_count := int(plan.get("exact_count", -1))
    var minimum_count := maxi(0, int(plan.get("minimum_count", 0)))
    if str(plan.get("holder_id", "")) != str(side.owner_id):
        return {"success": false, "reason": "真气消耗计划持有者已变化"}
    if exact_count >= 0 and count != exact_count:
        return {"success": false, "reason": "真气消耗计划不再满足精确支付数量"}
    if count < minimum_count:
        return {"success": false, "reason": "真气消耗计划不再满足最低支付数量"}
    var seen: Dictionary = {}
    for index in range(entries.size()):
        var entry: Dictionary = entries[index]
        var card = entry.get("card")
        var instance_id := str(entry.get("card_instance_id", ""))
        var source_zone := str(entry.get("from_zone", ""))
        var current_original_owner := str(card.original_owner_id) \
            if card != null and str(card.original_owner_id) != "" \
            else str(side.owner_id)
        if card == null or instance_id == "" or str(card.id) != instance_id \
                or seen.has(instance_id):
            return {"success": false, "reason": "真气消耗计划包含无效或重复实例"}
        if str(entry.get("holder_id", "")) != str(side.owner_id) \
                or source_zone not in ACTIVE_ZONES \
                or not zone(side, source_zone).has(card) \
                or str(entry.get("original_owner_id", "")) \
                    != current_original_owner \
                or bool(entry.get("temporary", false)) \
                    != bool(card.temporary_card):
            return {
                "success": false,
                "reason": "真气消耗目标的冻结牌区、持有者或归属事实已变化",
            }
        seen[instance_id] = true
    var count_ledger: Dictionary = {}
    var prepared: Array = []
    for index in range(count):
        var entry: Dictionary = entries[index]
        var metadata := source_metadata.duplicate(true)
        metadata.merge({
            "qi_consumption_transaction": true,
            "operation_token": operation_token,
            "consumption_batch_token": batch_token,
            "consumption_batch_index": index,
            "consumption_batch_size": count,
            "movement_batch_token": batch_token,
            "movement_batch_index": index,
            "cause": "cost",
            "reason": "cost",
            "pre_move_snapshot": entry.get(
                "pre_move_snapshot", {}).duplicate(true),
            "original_owner_id": str(entry.get("original_owner_id", "")),
            "temporary": bool(entry.get("temporary", false)),
        }, true)
        metadata = _with_ledger_counts(
            side, side, str(entry["from_zone"]),
            "temporarily_removed", metadata, count_ledger)
        prepared.append({
            "card": entry["card"],
            "from_zone": str(entry["from_zone"]),
            "metadata": metadata,
        })
    # 全批先离开活动牌区；任何 committed Hook 都看不到尚未移动的同批目标。
    for entry in prepared:
        _place_in_temporary_removed(
            side, entry["card"], entry["from_zone"], "cost")
    # 生命周期仍是唯一牌状态离场清理入口，并先于 card_moved。
    for entry in prepared:
        var lifecycle: Dictionary = _apply_temporary_remove_lifecycle(
            side, entry["card"], entry["from_zone"], "cost", entry["metadata"])
        if not lifecycle.get("success", true):
            return {
                "success": false,
                "reason": str(lifecycle.get("reason", "真气消耗生命周期失败")),
                "mutation_started": true,
            }
    var moved_events: Array = []
    for entry in prepared:
        var moved: Dictionary = _publish_card_moved(
            side, side, entry["card"], entry["from_zone"],
            "temporarily_removed", "cost", "top", entry["metadata"], true)
        if not moved.get("success", true):
            return {
                "success": false,
                "reason": str(moved.get("reason", "card_moved 提交失败")),
                "mutation_started": true,
            }
        moved_events.append(moved)
    var consumed_events: Array = []
    for entry in prepared:
        var consumed_event: Dictionary = _emit_qi_consumed_event(
            side, entry["card"], entry["from_zone"], entry["metadata"])
        if not consumed_event.get("success", true):
            return {
                "success": false,
                "reason": str(consumed_event.get(
                    "reason", "qi_consumed 提交失败")),
                "mutation_started": true,
            }
        consumed_events.append(consumed_event)
    for moved in moved_events:
        _dispatch_deferred_card_moved_response(moved)
    var cards: Array = prepared.map(func(entry): return entry["card"])
    var receipt := {
        "success": true,
        "reused": false,
        "operation_token": operation_token,
        "consumption_batch_token": batch_token,
        "consumption_batch_size": count,
        "holder_id": str(side.owner_id),
        "cards": cards,
        "card_instance_ids": cards.map(func(card): return str(card.id)),
        "moved_event_receipts": moved_events.map(func(event):
            return event.get("receipt", {}).duplicate(true)),
        "qi_consumed_event_receipts": consumed_events.map(func(event):
            return event.get("receipt", {}).duplicate(true)),
    }
    side.qi_consumption_receipts[operation_token] = receipt.duplicate(true)
    return receipt


func _emit_qi_consumed_event(
        side, card, source_zone: String, metadata: Dictionary) -> Dictionary:
    if committed_event_service == null:
        return {"success": true, "receipt": {}}
    var source := EffectSourceProtocolScript.from_values(metadata)
    var event_serial := int(committed_event_service.next_serial())
    var action_token := str(metadata.get("action_token", ""))
    var values := {
        "event_token": committed_event_service.make_token(
            "qi_consumed", side, event_serial, action_token, str(card.id)),
        "event_serial": event_serial,
        "operation_token": str(metadata.get("operation_token", "")),
        "consumption_batch_token": str(metadata.get(
            "consumption_batch_token", "")),
        "consumption_batch_index": int(metadata.get(
            "consumption_batch_index", -1)),
        "consumption_batch_size": int(metadata.get(
            "consumption_batch_size", 0)),
        "card": card,
        "card_instance_id": str(card.id),
        "source_card_instance_id": str(metadata.get(
            "source_card_instance_id", str(card.id))),
        "pre_move_snapshot": metadata.get(
            "pre_move_snapshot", {}).duplicate(true),
        "from_zone": source_zone,
        "to_zone": "temporarily_removed",
        "reason": "cost",
        "cause": "cost",
        "actor": side,
        "owner": side,
        "holder": side,
        "holder_id": str(side.owner_id),
        "from_holder": side,
        "to_holder": side,
        "from_holder_id": str(side.owner_id),
        "to_holder_id": str(side.owner_id),
        "original_owner_id": str(metadata.get("original_owner_id", "")),
        "temporary": bool(metadata.get("temporary", false)),
        "source_kind": source["source_kind"],
        "source_id": source["source_id"],
        "source_name": source["source_name"],
        "source_instance_key": source["source_instance_key"],
        "trigger_mode": source["trigger_mode"],
        "action_token": action_token,
        "root_action_token": str(metadata.get(
            "root_action_token", action_token)),
        "execution_token": str(metadata.get("execution_token", "")),
        "technique_execution_token": str(metadata.get(
            "technique_execution_token", metadata.get("execution_token", ""))),
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "observe_all_sides": true,
        "metadata": metadata.duplicate(true),
    }
    var committed: Dictionary = committed_event_service.commit(
        "qi_consumed", values)
    committed["values"] = values
    return committed

func _remove_from_source_zone(
        side, card, source_zone: String, reason: String) -> void:
    zone(side, source_zone).erase(card)

func _finish_temporary_remove(
        side, card, source_zone: String, reason: String,
        event_metadata: Dictionary,
        lifecycle_event_result: Dictionary) -> Dictionary:
    var metadata := _complete_frozen_counts(
        side, side, source_zone, "temporarily_removed", event_metadata)
    var moved_event_result := lifecycle_event_result
    if moved_event_result.get("success", true):
        moved_event_result = _publish_card_moved(
            side, side, card, source_zone, "temporarily_removed",
            reason, "top", metadata, true)
    var event_result := moved_event_result
    if moved_event_result.get("success", true) \
            and bool(metadata.get("explicit_discard", false)):
        event_result = _emit_void_explicit_discard_event(
            side, card, source_zone, metadata)
    if event_result.get("success", true):
        _dispatch_deferred_card_moved_response(moved_event_result)
    var result := {
        "success": true, "card": card, "from": source_zone,
        "to": "temporarily_removed", "reason": reason,
        "pre_move_snapshot": metadata.get("pre_move_snapshot", {}).duplicate(true),
    }
    _merge_event_failure(result, event_result)
    return result


func _place_in_temporary_removed(
        side, card, source_zone: String, reason: String) -> void:
    _remove_from_source_zone(side, card, source_zone, reason)
    if not side.temporarily_removed_cards.has(card):
        side.temporarily_removed_cards.append(card)


func _apply_temporary_remove_lifecycle(
        side, card, source_zone: String, reason: String,
        event_metadata: Dictionary) -> Dictionary:
    return _apply_state_lifecycle(
        side, card, source_zone, "temporarily_removed", reason,
        event_metadata)

func _emit_void_explicit_discard_event(
        side,
        card,
        source_zone: String,
        metadata: Dictionary) -> Dictionary:
    if committed_event_service == null:
        return {"success": true}
    var event_serial: int = int(committed_event_service.next_serial())
    return committed_event_service.commit("card_explicitly_discarded", {
        "actor": side,
        "owner": side,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "event_serial": event_serial,
        "event_token": committed_event_service.make_token(
            "card_explicitly_discarded", side, event_serial, "", str(card.id)),
        "card": card,
        "card_instance_id": str(card.id),
        "from_zone": source_zone,
        "reason": "explicit_discard",
        "explicit_discard": true,
        "normal_play": false,
        "void_dispersal": true,
        "metadata": metadata,
    })

func _apply_state_lifecycle(
        holder, card, source_zone: String, destination_zone: String,
        reason: String, event_metadata: Dictionary) -> Dictionary:
    if status_system == null or bool(event_metadata.get(
            "state_lifecycle_applied", false)):
        return {"success": true}
    event_metadata["state_lifecycle_applied"] = true
    var metadata := event_metadata.duplicate(true)
    metadata["holder"] = holder
    metadata["holder_frozen"] = true
    if not metadata.has("source_actor") and not metadata.has("actor"):
        metadata["source_actor"] = holder
    return status_system.on_card_zone_transition(
        card, source_zone, destination_zone, reason, metadata)

func _pre_move_snapshot(side, card, source_zone: String) -> Dictionary:
    var effective_query := _event_effective_qi(side, card, "card_moved")
    var effective := int(effective_query.get("effective_value", 0))
    var attributes: Array[String] = []
    for attribute in ["wind", "forest", "fire", "mountain"]:
        if card.is_attribute(attribute):
            attributes.append(attribute)
    return {
        "card": card,
        "instance_id": str(card.id),
        "source_zone": source_zone,
        "effective_qi": maxi(0, effective),
        "effective_qi_query": effective_query,
        "base_qi": int(card.current_base_qi_value()),
        "card_base_qi": int(card.qi_value),
        "rank_name": str(card.current_rank_name()),
        "rank_order": int(card.current_rank_order()),
        "base_attribute": str(card.current_attribute()),
        "attributes": attributes,
        "anomalies": card.anomaly_snapshot(),
        "growth_layers": card.anomaly_layers("buff", "growth"),
        "heat_layers": card.total_blazing_layers() \
            if card.has_method("total_blazing_layers") \
            else card.anomaly_layers("buff", "qi_heat"),
        "normal_heat_layers": card.normal_blazing_layers() \
            if card.has_method("normal_blazing_layers") \
            else card.anomaly_layers("buff", "qi_heat"),
        "temporary_heat_layers": card.temporary_blazing_layers_total() \
            if card.has_method("temporary_blazing_layers_total") else 0,
        "temporary_blazing_sources": card.temporary_blazing_layers.duplicate(true),
        "had_poison": card.has_anomaly("state", "poison"),
        "had_burned_out": card.has_anomaly("debuff", "burned_out"),
    }

func _notify_arrival(
        from_side,
        to_side,
        card,
        source_zone: String,
        destination_zone: String,
        reason: String,
        placement: String,
        event_metadata: Dictionary) -> Dictionary:
    var lifecycle_event_result := _apply_state_lifecycle(
        from_side if from_side != null else to_side, card,
        source_zone, destination_zone, reason, event_metadata)
    if not lifecycle_event_result.get("success", true):
        return lifecycle_event_result
    if destination_zone == "discard_pile":
        if status_system != null:
            status_system.on_card_enter_discard_behaviors(to_side, card)
        if reason == "explicit_discard" and status_system != null:
            status_system.on_card_explicit_discard(to_side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_entered_discard(to_side, card, reason)
        if status_system != null:
            status_system.on_card_enter_discard_late(to_side, card)
        elif card_state_lifecycle != null:
            card_state_lifecycle.on_enter_discard(card)
    elif destination_zone == "hand" and reason == "draw":
        if status_system != null:
            status_system.on_card_drawn(to_side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_drawn(to_side, card)
    var moved_committed: Dictionary = _publish_card_moved(
        from_side, to_side, card, source_zone, destination_zone,
        reason, placement, event_metadata, true)
    var committed := moved_committed
    if moved_committed.get("success", true):
        committed = _emit_specialized_card_events(
            to_side, card, source_zone, destination_zone,
            reason, event_metadata)
    if committed.get("success", true):
        _dispatch_deferred_card_moved_response(moved_committed)
    return committed

func _publish_card_moved(
        from_side,
        to_side,
        card,
        physical_from_zone: String,
        to_zone: String,
        reason: String,
        placement: String,
        event_metadata: Dictionary,
        defer_dynamic_response: bool = false) -> Dictionary:
    var metadata := event_metadata.duplicate(true)
    var from_zone := str(metadata.get(
        "logical_from_zone", physical_from_zone))
    var actor = to_side if to_side != null else from_side
    var original_owner_id := str(metadata.get("original_owner_id", ""))
    if original_owner_id == "" and card != null:
        original_owner_id = str(card.original_owner_id)
    if original_owner_id == "":
        var original_side = from_side if from_side != null else to_side
        original_owner_id = str(original_side.owner_id) \
            if original_side != null else ""
    var source := EffectSourceProtocolScript.from_values(metadata)
    var event_serial := -1
    var event_token := ""
    if committed_event_service != null:
        event_serial = int(committed_event_service.next_serial())
        event_token = committed_event_service.make_token(
            "card_moved", actor, event_serial,
            str(metadata.get("action_token", "")), str(card.id))
    var snapshot: Dictionary = metadata.get(
        "pre_move_snapshot", {}).duplicate(true)
    if not snapshot.is_empty():
        snapshot["source_zone"] = from_zone
    var values := {
        "event_token": event_token,
        "event_serial": event_serial,
        "action_token": str(metadata.get("action_token", "")),
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "actor": actor,
        "target": from_side if from_side != to_side else null,
        "owner": actor,
        "holder": to_side,
        "from_holder": from_side,
        "to_holder": to_side,
        "from_holder_id": str(from_side.owner_id) \
            if from_side != null else "",
        "to_holder_id": str(to_side.owner_id) if to_side != null else "",
        "original_owner_id": original_owner_id,
        "observe_all_sides": true,
        "defer_dynamic_response": defer_dynamic_response,
        "card": card,
        "card_instance_id": str(card.id),
        "source_card_instance_id": str(metadata.get(
            "source_card_instance_id", str(card.id))),
        "from_zone": from_zone,
        "to_zone": to_zone,
        "reason": reason,
        "placement": placement,
        "logical_explicit_discard": bool(metadata.get(
            "logical_explicit_discard", reason == "explicit_discard")),
        "disposition_replaced": bool(metadata.get(
            "disposition_replaced", false)),
        "original_destination": str(metadata.get(
            "original_destination", to_zone)),
        "final_destination": str(metadata.get(
            "final_destination", to_zone)),
        "transition_kind": _transition_kind(from_zone, to_zone),
        "from_zone_count_before": int(metadata.get(
            "from_zone_count_before", 0)),
        "from_zone_count_after": int(metadata.get(
            "from_zone_count_after", 0)),
        "to_zone_count_before": int(metadata.get(
            "to_zone_count_before", 0)),
        "to_zone_count_after": int(metadata.get(
            "to_zone_count_after", 0)),
        "hand_count_before": int(metadata.get("hand_count_before", 0)),
        "hand_count_after": int(metadata.get("hand_count_after", 0)),
        "from_hand_count_before": int(metadata.get(
            "from_hand_count_before", 0)),
        "from_hand_count_after": int(metadata.get(
            "from_hand_count_after", 0)),
        "to_hand_count_before": int(metadata.get(
            "to_hand_count_before", 0)),
        "to_hand_count_after": int(metadata.get(
            "to_hand_count_after", 0)),
        "movement_batch_token": str(metadata.get(
            "movement_batch_token", "")),
        "movement_batch_index": int(metadata.get(
            "movement_batch_index", -1)),
        "consumption_batch_token": str(metadata.get(
            "consumption_batch_token", "")),
        "consumption_batch_index": int(metadata.get(
            "consumption_batch_index", -1)),
        "consumption_batch_size": int(metadata.get(
            "consumption_batch_size", 0)),
        "operation_token": str(metadata.get("operation_token", "")),
        "cause": str(metadata.get("cause", "")),
        "temporary": bool(metadata.get("temporary", false)),
        "effective_qi": int(snapshot.get("effective_qi", 0)),
        "effective_qi_query": snapshot.get(
            "effective_qi_query", {}).duplicate(true),
        "pre_move_snapshot": snapshot,
        "metadata": metadata,
        "source_kind": source["source_kind"],
        "source_id": source["source_id"],
        "source_name": source["source_name"],
        "source_instance_key": source["source_instance_key"],
        "trigger_mode": source["trigger_mode"],
    }
    if committed_event_service != null:
        var committed: Dictionary = committed_event_service.commit(
            "card_moved", values)
        committed["values"] = values
        if committed.get("success", false):
            _record_effect_batch_entry(values)
        return committed
    if status_system != null:
        status_system.handle_response_event("card_moved", values)
    return {"success": true, "values": values}

func _record_effect_batch_entry(values: Dictionary) -> void:
    var metadata: Dictionary = values.get("metadata", {})
    var effect_token := str(metadata.get("effect_execution_token", ""))
    if effect_token == "":
        return
    if not _effect_batch_entries.has(effect_token):
        _effect_batch_entries[effect_token] = []
    _effect_batch_entries[effect_token].append({
        "event_serial": int(values.get("event_serial", -1)),
        "card_instance_id": str(values.get("card_instance_id", "")),
        "from_zone": str(values.get("from_zone", "")),
        "to_zone": str(values.get("to_zone", "")),
        "reason": str(values.get("reason", "")),
        "placement": str(values.get("placement", "")),
        "logical_explicit_discard": bool(values.get(
            "logical_explicit_discard", metadata.get(
                "logical_explicit_discard", false))),
        "disposition_replaced": bool(values.get(
            "disposition_replaced", metadata.get(
                "disposition_replaced", false))),
        "original_destination": str(values.get(
            "original_destination", metadata.get(
                "original_destination", values.get("to_zone", "")))),
        "final_destination": str(values.get(
            "final_destination", metadata.get(
                "final_destination", values.get("to_zone", "")))),
        "movement_batch_token": str(values.get("movement_batch_token", "")),
        "movement_batch_index": int(values.get("movement_batch_index", -1)),
    })

func _dispatch_deferred_card_moved_response(event_result: Dictionary) -> void:
    if status_system == null:
        return
    var values: Dictionary = event_result.get("values", {})
    if not values.is_empty():
        status_system.handle_response_event("card_moved", values)

func _with_frozen_counts(
        from_side,
        to_side,
        from_zone: String,
        to_zone: String,
        source_metadata: Dictionary) -> Dictionary:
    var metadata := source_metadata.duplicate(true)
    if bool(metadata.get("movement_counts_frozen", false)):
        return metadata
    var logical_from := str(metadata.get("logical_from_zone", from_zone))
    var from_count := _zone_count(from_side, logical_from)
    var to_count := _zone_count(to_side, to_zone)
    var from_hand := _zone_count(from_side, "hand")
    var to_hand := _zone_count(to_side, "hand")
    if not metadata.has("from_zone_count_before"):
        metadata["from_zone_count_before"] = from_count
    if not metadata.has("to_zone_count_before"):
        metadata["to_zone_count_before"] = to_count
    if not metadata.has("from_hand_count_before"):
        metadata["from_hand_count_before"] = from_hand
    if not metadata.has("to_hand_count_before"):
        metadata["to_hand_count_before"] = to_hand
    if not metadata.has("hand_count_before"):
        metadata["hand_count_before"] = (
            from_hand if logical_from == "hand" else to_hand)
    return metadata

func _complete_frozen_counts(
        from_side,
        to_side,
        from_zone: String,
        to_zone: String,
        source_metadata: Dictionary) -> Dictionary:
    var metadata := source_metadata.duplicate(true)
    if bool(metadata.get("movement_counts_frozen", false)):
        return metadata
    var logical_from := str(metadata.get("logical_from_zone", from_zone))
    if not metadata.has("from_zone_count_after"):
        metadata["from_zone_count_after"] = _zone_count(
            from_side, logical_from)
    if not metadata.has("to_zone_count_after"):
        var to_count := _zone_count(to_side, to_zone)
        if to_zone == "permanently_removed" \
                and to_count <= int(metadata.get("to_zone_count_before", 0)):
            to_count = int(metadata.get("to_zone_count_before", 0)) + 1
        metadata["to_zone_count_after"] = to_count
    if not metadata.has("from_hand_count_after"):
        metadata["from_hand_count_after"] = _zone_count(from_side, "hand")
    if not metadata.has("to_hand_count_after"):
        metadata["to_hand_count_after"] = _zone_count(to_side, "hand")
    if not metadata.has("hand_count_after"):
        metadata["hand_count_after"] = (
            int(metadata["from_hand_count_after"])
            if logical_from == "hand"
            else int(metadata["to_hand_count_after"]))
    return metadata

func _with_ledger_counts(
        from_side,
        to_side,
        from_zone: String,
        to_zone: String,
        source_metadata: Dictionary,
        ledger: Dictionary) -> Dictionary:
    var metadata := source_metadata.duplicate(true)
    var from_before := _ledger_count(ledger, from_side, from_zone)
    var to_before := _ledger_count(ledger, to_side, to_zone)
    var from_hand_before := _ledger_count(ledger, from_side, "hand")
    var to_hand_before := _ledger_count(ledger, to_side, "hand")
    var same_zone: bool = from_side == to_side and from_zone == to_zone
    var from_after := from_before - (0 if same_zone else 1)
    var to_after := to_before + (0 if same_zone else 1)
    _set_ledger_count(ledger, from_side, from_zone, from_after)
    _set_ledger_count(ledger, to_side, to_zone, to_after)
    var from_hand_after := _ledger_count(ledger, from_side, "hand")
    var to_hand_after := _ledger_count(ledger, to_side, "hand")
    metadata.merge({
        "movement_counts_frozen": true,
        "from_zone_count_before": from_before,
        "from_zone_count_after": from_after,
        "to_zone_count_before": to_before,
        "to_zone_count_after": to_after,
        "from_hand_count_before": from_hand_before,
        "from_hand_count_after": from_hand_after,
        "to_hand_count_before": to_hand_before,
        "to_hand_count_after": to_hand_after,
        "hand_count_before": from_hand_before \
            if from_zone == "hand" else to_hand_before,
        "hand_count_after": from_hand_after \
            if from_zone == "hand" else to_hand_after,
    }, true)
    return metadata

func _ledger_count(ledger: Dictionary, side, zone_name: String) -> int:
    if side == null or zone_name == "generated":
        return 0
    var key := "%s|%s" % [str(side.get_instance_id()), zone_name]
    if not ledger.has(key):
        ledger[key] = _zone_count(side, zone_name)
    return int(ledger[key])

func _set_ledger_count(
        ledger: Dictionary, side, zone_name: String, value: int) -> void:
    if side == null or zone_name == "generated":
        return
    ledger["%s|%s" % [str(side.get_instance_id()), zone_name]] = maxi(0, value)

func _stamp_movement_batch(entries: Array, batch_kind: String) -> void:
    if entries.is_empty():
        return
    var batch_token := "%s:%d" % [batch_kind, entries.size()]
    if committed_event_service != null:
        var batch_serial := int(committed_event_service.next_serial())
        batch_token = committed_event_service.make_token(
            "card_moved_batch", null, batch_serial, batch_kind, "")
    for index in range(entries.size()):
        var metadata: Dictionary = entries[index].get(
            "source_metadata", {}).duplicate(true)
        metadata["movement_batch_token"] = batch_token
        metadata["movement_batch_index"] = index
        entries[index]["source_metadata"] = metadata

func _zone_count(side, zone_name: String) -> int:
    if side == null or zone_name == "generated":
        return 0
    if zone_name == "temporarily_removed":
        return side.temporarily_removed_cards.size()
    if zone_name == "permanently_removed":
        return side.permanently_removed_card_ids.size()
    if zone_name in ACTIVE_ZONES:
        return zone(side, zone_name).size()
    return 0

func _insert_in_zone(
        side, zone_name: String, card, placement: String) -> void:
    if placement == "bottom":
        zone(side, zone_name).push_front(card)
    else:
        zone(side, zone_name).append(card)

func _transition_kind(from_zone: String, to_zone: String) -> String:
    if from_zone == "generated":
        return "create"
    if to_zone in ["temporarily_removed", "permanently_removed"]:
        return "remove"
    if from_zone == to_zone:
        return "reorder"
    return "move"

func _merge_event_failure(result: Dictionary, event_result: Dictionary) -> void:
    if event_result.get("success", true):
        return
    result["passive_event_success"] = false
    result["passive_event_reason"] = event_result.get("reason", "")

func _emit_specialized_card_events(
        side,
        card,
        source_zone: String,
        destination_zone: String,
        reason: String,
        metadata: Dictionary) -> Dictionary:
    if committed_event_service == null:
        return {"success": true}
    var event_serial: int = int(committed_event_service.next_serial())
    var common := {
        "actor": side,
        "owner": side,
        "round_number": int(round_number_reader.call()) \
            if round_number_reader.is_valid() else 0,
        "event_serial": event_serial,
        "card": card,
        "card_instance_id": str(card.id),
        "from_zone": source_zone,
        "to_zone": destination_zone,
        "reason": reason,
        "metadata": metadata,
    }
    var event_source := EffectSourceProtocolScript.from_values(metadata)
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode"]:
        common[field] = event_source[field]
    if destination_zone == "hand" and reason == "draw":
        common["draw_reason"] = str(metadata.get("draw_reason", "rule_draw"))
        var effective_query := _event_effective_qi(
            side, card, "card_drawn")
        common["effective_qi"] = int(effective_query.get(
            "effective_value", 0))
        common["effective_qi_query"] = effective_query
        common["event_token"] = committed_event_service.make_token(
            "card_drawn", side, event_serial, "", str(card.id))
        return committed_event_service.commit("card_drawn", common)
    if destination_zone != "discard_pile":
        return {"success": true}
    common["explicit_discard"] = reason == "explicit_discard"
    common["normal_play"] = reason == "normal_play"
    common["event_token"] = committed_event_service.make_token(
        "card_entered_discard", side, event_serial, "", str(card.id))
    var entered: Dictionary = committed_event_service.commit(
        "card_entered_discard", common)
    if not entered.get("success", false) or reason != "explicit_discard":
        return entered
    var explicit := common.duplicate(false)
    explicit["event_token"] = committed_event_service.make_token(
        "card_explicitly_discarded", side, event_serial, "", str(card.id))
    return committed_event_service.commit(
        "card_explicitly_discarded", explicit)

func _can_explicit_discard(side, card) -> bool:
    return bool(_explicit_discard_permission(side, card).get("allowed", true))

func _event_effective_qi(side, card, boundary: String) -> Dictionary:
    if side != null and side.battle_rule_query_service != null:
        var query = side.battle_rule_query_service.resolve_effective_qi(
            side, card, {
                "actor": side,
                "purpose": "event_snapshot",
                "evaluation_mode": "runtime",
                "cards": [card],
                "participating_card_ids": [],
                "source_kind": "committed_event",
            })
        if query.success:
            return query.to_dict()
        side.battle_rule_query_service.report_failure(
            query, "%s_effective_qi" % boundary)
        return query.to_dict()
    var value := int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value)
    return {
        "success": true,
        "base_value": value,
        "effective_value": maxi(0, value),
        "source_breakdown": [],
        "fingerprint": "",
        "request_fingerprint": "",
        "errors": [],
    }

func _explicit_discard_permission(side, card) -> Dictionary:
    if battle_permission_service != null:
        return battle_permission_service.can_explicit_discard(side, card)
    if card_reshape_runtime != null:
        return card_reshape_runtime.can_explicit_discard(side, card)
    if card.has_method("can_explicit_discard"):
        return card.can_explicit_discard()
    return {"allowed": true}

func _card_play_permission(side, card) -> Dictionary:
    if battle_permission_service != null:
        return battle_permission_service.can_play_card(side, card)
    if status_system != null:
        return status_system.can_play_card(side, card)
    return {"allowed": true}

func find_card(side, zone_name: String, instance_id: String):
    for card in zone(side, zone_name):
        if str(card.id) == instance_id:
            return card
    return null

func find_active_location(side, instance_id: String) -> Dictionary:
    for zone_name in ACTIVE_ZONES:
        var card = find_card(side, zone_name, instance_id)
        if card != null:
            return {"zone": zone_name, "card": card}
    return {}

func has_instance(side, instance_id: String) -> bool:
    if not find_active_location(side, instance_id).is_empty():
        return true
    for card in side.temporarily_removed_cards:
        if str(card.id) == instance_id:
            return true
    return false

func zone(side, zone_name: String) -> Array:
    match zone_name:
        "draw_pile": return side.draw_pile
        "hand": return side.hand
        "staging": return side.staging
        "discard_pile": return side.discard_pile
    return []

func _bind_card_policies(side, card) -> void:
    if card == null:
        return
    if card.has_method("configure_identity_policy"):
        card.configure_identity_policy(side.card_identity_policy)
    if card.has_method("configure_battle_permission_service"):
        card.configure_battle_permission_service(side.battle_permission_service)

func bind_card_policies(side, card) -> void:
    _bind_card_policies(side, card)

func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary
