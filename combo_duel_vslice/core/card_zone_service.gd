class_name CardZoneService
extends RefCounted

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

func draw(side, count: int, draw_reason: String = "rule_draw") -> Array:
    var drawn: Array = []
    for _index in range(maxi(0, count)):
        if side.draw_pile.is_empty():
            break
        var card = side.draw_pile.back()
        move_card(side, "draw_pile", "hand", card, "draw", {
            "draw_reason": draw_reason,
        })
        drawn.append(card)
    return drawn

func place_on_draw_pile_top(side, card) -> Dictionary:
    if not side.draw_pile.has(card):
        return {"success": false, "reason": "目标真气不在抽牌堆"}
    side.draw_pile.erase(card)
    side.draw_pile.append(card)
    return {
        "success": true,
        "card": card,
        "from": "draw_pile",
        "to": "draw_pile_top",
    }

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
    return commit_selected_staging(side, side.staging.duplicate())

func commit_selected_staging(side, selected_cards: Array) -> Array:
    var committed: Array = []
    for card in selected_cards:
        if not side.staging.has(card):
            continue
        committed.append(card)
        move_card(side, "staging", "discard_pile", card, "normal_play")
    return committed

func random_discard(side, count: int, rng: RandomNumberGenerator) -> Array:
    var discarded: Array = []
    for _index in range(maxi(0, count)):
        var candidates: Array = side.hand.filter(
            func(card): return _can_explicit_discard(side, card))
        if candidates.is_empty():
            break
        var card = candidates[rng.randi_range(0, candidates.size() - 1)]
        var result := move_card(
            side, "hand", "discard_pile", card, "explicit_discard")
        if result.get("success", false):
            discarded.append(card)
    return discarded

func discard_all(side) -> Array:
    var discarded: Array = []
    for card in side.hand.duplicate():
        var result := move_card(
            side, "hand", "discard_pile", card, "explicit_discard")
        if result.get("success", false):
            discarded.append(card)
    return discarded

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

func temporarily_remove(side, instance_id: String, reason: String = "burn") -> Dictionary:
    var location := find_active_location(side, instance_id)
    if location.is_empty():
        return {"success": false, "reason": "找不到要临时移出战斗的真气"}
    var card = location["card"]
    var source_zone := str(location["zone"])
    _clear_meridian_on_real_hand_departure(card, source_zone, reason)
    zone(side, source_zone).erase(card)
    side.temporarily_removed_cards.append(card)
    return {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": "temporarily_removed",
        "reason": reason,
    }

func permanently_remove(side, instance_id: String, reason: String = "permanent_remove") -> Dictionary:
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
    _clear_meridian_on_real_hand_departure(card, source_zone, reason)
    if source_zone == "temporarily_removed":
        side.temporarily_removed_cards.erase(card)
    else:
        zone(side, source_zone).erase(card)
    if not bool(card.temporary_card) and str(card.original_owner_id) == "":
        side.mark_permanently_removed(instance_id)
    return {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": "permanently_removed",
        "reason": reason,
    }

func temporarily_transfer(
        source_side,
        target_side,
        instance_id: String,
        destination: String = "draw_pile",
        reason: String = "temporary_transfer") -> Dictionary:
    if destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "临时夺取的目标牌区无效"}
    var location := find_active_location(source_side, instance_id)
    if location.is_empty():
        return {"success": false, "reason": "找不到要临时夺取的真气"}
    if has_instance(target_side, instance_id):
        return {"success": false, "reason": "目标牌区已经存在相同实例 ID"}
    var card = location["card"]
    var source_zone := str(location["zone"])
    _clear_meridian_on_real_hand_departure(card, source_zone, reason)
    zone(source_side, source_zone).erase(card)
    if str(card.original_owner_id) == "":
        card.original_owner_id = source_side.owner_id
    zone(target_side, destination).append(card)
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
        target_side, card, source_zone, destination, reason, {})
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

func temporarily_transfer_many(records: Array) -> Array:
    ## Freeze every cross-side source, remove them all, then publish arrivals.
    ## Responses therefore cannot observe only part of one atomic transfer batch.
    var prepared: Array = []
    var seen: Dictionary = {}
    for record_value in records:
        var record: Dictionary = record_value
        var source_side = record.get("source_side")
        var target_side = record.get("target_side")
        var card = record.get("card")
        var source_zone := str(record.get("source_zone", "hand"))
        var destination_zone := str(record.get("destination_zone", "draw_pile"))
        var reason := str(record.get("reason", "temporary_transfer"))
        if source_side == null or target_side == null or source_side == target_side \
                or card == null or seen.has(str(card.id)) \
                or source_zone not in ACTIVE_ZONES \
                or destination_zone not in ACTIVE_ZONES:
            continue
        if not zone(source_side, source_zone).has(card) \
                or has_instance(target_side, str(card.id)):
            continue
        seen[str(card.id)] = true
        prepared.append({
            "source_side": source_side, "target_side": target_side,
            "source_zone": source_zone, "destination_zone": destination_zone,
            "card": card, "reason": reason,
            "pre_move_snapshot": _pre_move_snapshot(source_side, card, source_zone),
        })
    for entry in prepared:
        _clear_meridian_on_real_hand_departure(
            entry["card"], entry["source_zone"], entry["reason"])
        zone(entry["source_side"], entry["source_zone"]).erase(entry["card"])
        if str(entry["card"].original_owner_id) == "":
            entry["card"].original_owner_id = entry["source_side"].owner_id
    for entry in prepared:
        zone(entry["target_side"], entry["destination_zone"]).append(entry["card"])
    var moved: Array = []
    for entry in prepared:
        _notify_arrival(
            entry["target_side"], entry["card"], entry["source_zone"],
            entry["destination_zone"], entry["reason"], {
                "pre_move_snapshot": entry["pre_move_snapshot"],
                "original_owner_id": entry["source_side"].owner_id,
            })
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
    _clear_meridian_on_real_hand_departure(card, source_zone, "return_transfer")
    zone(holder_side, source_zone).erase(card)
    card.original_owner_id = ""
    zone(original_side, destination).append(card)
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
        original_side, card, source_zone, destination,
        "return_transfer", {})
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

func add_generated(side, card, destination: String, temporary: bool) -> Dictionary:
    if card == null or destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "生成真气的目标牌区无效"}
    if has_instance(side, str(card.id)):
        return {"success": false, "reason": "真气实例 ID 已存在于战斗牌区"}
    card.temporary_card = temporary
    _bind_card_policies(side, card)
    zone(side, destination).append(card)
    var reason := "temporary_generate" if temporary else "permanent_generate"
    var result := {
        "success": true,
        "card": card,
        "from": "generated",
        "to": destination,
        "reason": reason,
    }
    var event_result := _notify_arrival(
        side, card, "generated", destination, reason, {})
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
        event_metadata: Dictionary = {}) -> Dictionary:
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
    var pre_move_snapshot := _pre_move_snapshot(side, card, source_zone)
    event_metadata = event_metadata.duplicate(true)
    event_metadata["pre_move_snapshot"] = pre_move_snapshot
    if card.has_anomaly("mark", "void") and reason in ["normal_play", "explicit_discard"]:
        return _resolve_void_departure(
            side, source_zone, card, reason, event_metadata, pre_move_snapshot)
    _clear_meridian_on_real_hand_departure(card, source_zone, reason)
    source.erase(card)
    zone(side, destination_zone).append(card)
    var event_result := _notify_arrival(
        side, card, source_zone, destination_zone, reason, event_metadata)
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

func move_cards_synchronously(records: Array) -> Array:
    ## Freeze and remove every source first, then publish arrivals in stable order.
    ## This prevents bilateral discard and exchange responses from observing a half-moved state.
    var prepared: Array = []
    var seen: Dictionary = {}
    for record_value in records:
        var record: Dictionary = record_value
        var side = record.get("side")
        var card = record.get("card")
        var source_zone := str(record.get("source_zone", "hand"))
        var destination_zone := str(record.get("destination_zone", "discard_pile"))
        var reason := str(record.get("reason", "effect"))
        if side == null or card == null or source_zone not in ACTIVE_ZONES \
                or destination_zone not in ACTIVE_ZONES or seen.has(str(card.id)):
            continue
        if not zone(side, source_zone).has(card):
            continue
        if reason == "explicit_discard" \
                and not _explicit_discard_permission(side, card).get("allowed", true):
            continue
        seen[str(card.id)] = true
        prepared.append({
            "side": side, "card": card, "source_zone": source_zone,
            "destination_zone": destination_zone, "reason": reason,
            "pre_move_snapshot": _pre_move_snapshot(side, card, source_zone),
            "void": card.has_anomaly("mark", "void") \
                and reason in ["normal_play", "explicit_discard"],
        })
    for entry in prepared:
        _clear_meridian_on_real_hand_departure(
            entry["card"], entry["source_zone"], entry["reason"])
        zone(entry["side"], entry["source_zone"]).erase(entry["card"])
    for entry in prepared:
        if not bool(entry["void"]):
            zone(entry["side"], entry["destination_zone"]).append(entry["card"])
    var moved: Array = []
    for entry in prepared:
        var side = entry["side"]
        var card = entry["card"]
        var metadata := {"pre_move_snapshot": entry["pre_move_snapshot"]}
        if bool(entry["void"]):
            if entry["reason"] == "explicit_discard":
                if status_system != null:
                    status_system.on_card_explicit_discard(side, card, true)
                _emit_void_explicit_discard_event(
                    side, card, entry["source_zone"], metadata)
            side.temporarily_removed_cards.append(card)
            if status_system != null:
                status_system.handle_response_event("card_moved", {
                    "actor": side, "holder": side, "card": card,
                    "source_card_instance_id": str(card.id),
                    "from_zone": entry["source_zone"],
                    "to_zone": "temporarily_removed", "reason": "void",
                    "round_number": int(round_number_reader.call()) \
                        if round_number_reader.is_valid() else 0,
                    "pre_move_snapshot": entry["pre_move_snapshot"],
                })
        else:
            _notify_arrival(side, card, entry["source_zone"],
                entry["destination_zone"], entry["reason"], metadata)
        moved.append(card)
    return moved

func atomic_exchange(
        actor_side, actor_zone: String, actor_card,
        target_side, target_zone: String, target_card) -> Dictionary:
    if actor_side == null or target_side == null or actor_side == target_side:
        return {"success": false, "reason": "原子交换需要不同的双方"}
    if not zone(actor_side, actor_zone).has(actor_card) \
            or not zone(target_side, target_zone).has(target_card):
        return {"success": false, "reason": "原子交换来源牌已离开冻结牌区"}
    var actor_snapshot := _pre_move_snapshot(actor_side, actor_card, actor_zone)
    var target_snapshot := _pre_move_snapshot(target_side, target_card, target_zone)
    _clear_meridian_on_real_hand_departure(actor_card, actor_zone, "atomic_exchange")
    _clear_meridian_on_real_hand_departure(target_card, target_zone, "atomic_exchange")
    zone(actor_side, actor_zone).erase(actor_card)
    zone(target_side, target_zone).erase(target_card)
    if str(actor_card.original_owner_id) == "":
        actor_card.original_owner_id = actor_side.owner_id
    if str(target_card.original_owner_id) == "":
        target_card.original_owner_id = target_side.owner_id
    zone(actor_side, "hand").append(target_card)
    zone(target_side, "hand").append(actor_card)
    _notify_arrival(actor_side, target_card, target_zone, "hand", "atomic_exchange", {
        "pre_move_snapshot": target_snapshot, "original_owner_id": target_side.owner_id})
    _notify_arrival(target_side, actor_card, actor_zone, "hand", "atomic_exchange", {
        "pre_move_snapshot": actor_snapshot, "original_owner_id": actor_side.owner_id})
    return {"success": true, "actor_received": target_card, "target_received": actor_card,
        "actor_sent_snapshot": actor_snapshot, "target_sent_snapshot": target_snapshot}

func _resolve_void_departure(
        side,
        source_zone: String,
        card,
        reason: String,
        event_metadata: Dictionary,
        pre_move_snapshot: Dictionary) -> Dictionary:
    _clear_meridian_on_real_hand_departure(card, source_zone, reason)
    zone(side, source_zone).erase(card)
    var response_result := {"success": true}
    if reason == "explicit_discard":
        if status_system != null:
            status_system.on_card_explicit_discard(side, card, true)
        response_result = _emit_void_explicit_discard_event(
            side, card, source_zone, event_metadata)
    side.temporarily_removed_cards.append(card)
    if response_result.get("success", true) and status_system != null:
        status_system.handle_response_event("card_moved", {
            "actor": side,
            "holder": side,
            "card": card,
            "source_card_instance_id": str(card.id),
            "from_zone": source_zone,
            "to_zone": "temporarily_removed",
            "reason": "void",
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "pre_move_snapshot": pre_move_snapshot,
        })
    return {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": "temporarily_removed",
        "reason": reason,
        "dispersed": true,
        "pre_move_snapshot": pre_move_snapshot,
        "passive_event_success": response_result.get("success", true),
        "passive_event_reason": response_result.get("reason", ""),
    }

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

func _clear_meridian_on_real_hand_departure(
        card,
        source_zone: String,
        reason: String) -> void:
    var real_departure := source_zone == "hand" and reason != "stage"
    real_departure = real_departure or source_zone == "staging" and reason == "normal_play"
    if real_departure and card.has_anomaly("mark", "meridian"):
        card.remove_anomaly("mark", "meridian")

func _pre_move_snapshot(side, card, source_zone: String) -> Dictionary:
    var effective := int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value)
    if status_system != null:
        effective = status_system.effective_qi_value(card)
    var attributes: Array[String] = []
    for attribute in ["wind", "forest", "fire", "mountain"]:
        if card.is_attribute(attribute):
            attributes.append(attribute)
    return {
        "card": card,
        "instance_id": str(card.id),
        "source_zone": source_zone,
        "effective_qi": maxi(0, effective),
        "base_qi": int(card.current_base_qi_value()),
        "card_base_qi": int(card.qi_value),
        "rank_name": str(card.current_rank_name()),
        "rank_order": int(card.current_rank_order()),
        "base_attribute": str(card.current_attribute()),
        "attributes": attributes,
        "anomalies": card.anomaly_snapshot(),
        "growth_layers": card.anomaly_layers("buff", "growth"),
        "heat_layers": card.anomaly_layers("buff", "qi_heat"),
        "had_poison": card.has_anomaly("state", "poison"),
        "had_burned_out": card.has_anomaly("mark", "burned_out"),
    }

func _notify_arrival(
        side,
        card,
        source_zone: String,
        destination_zone: String,
        reason: String,
        event_metadata: Dictionary) -> Dictionary:
    if destination_zone == "discard_pile":
        if status_system != null:
            status_system.on_card_enter_discard_behaviors(side, card)
        if reason == "explicit_discard" and status_system != null:
            status_system.on_card_explicit_discard(side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_entered_discard(side, card, reason)
        if status_system != null:
            status_system.on_card_enter_discard(card, reason)
            status_system.on_card_enter_discard_late(side, card)
        elif card_state_lifecycle != null:
            card_state_lifecycle.on_enter_discard(card)
    elif destination_zone == "hand" and reason == "draw":
        if status_system != null:
            status_system.on_card_drawn(side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_drawn(side, card)
    var committed: Dictionary = _emit_committed_card_events(
        side, card, source_zone, destination_zone, reason, event_metadata)
    if committed.get("success", true) and status_system != null:
        status_system.handle_response_event("card_moved", {
            "actor": side,
            "holder": side,
            "card": card,
            "source_card_instance_id": str(card.id),
            "from_zone": source_zone,
            "to_zone": destination_zone,
            "reason": reason,
            "round_number": int(round_number_reader.call()) \
                if round_number_reader.is_valid() else 0,
            "pre_move_snapshot": event_metadata.get("pre_move_snapshot", {}),
        })
    return committed

func _emit_committed_card_events(
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
        "reason": reason,
        "metadata": metadata,
    }
    if destination_zone == "hand" and reason == "draw":
        common["draw_reason"] = str(metadata.get("draw_reason", "rule_draw"))
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
