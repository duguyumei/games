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
    zone(holder_side, str(location["zone"])).erase(card)
    card.original_owner_id = ""
    zone(original_side, destination).append(card)
    var result := {
        "success": true,
        "card": card,
        "from_owner": holder_side.owner_id,
        "to_owner": original_side.owner_id,
        "from": str(location["zone"]),
        "to": destination,
        "reason": "return_transfer",
    }
    var event_result := _notify_arrival(
        original_side, card, str(location["zone"]), destination,
        "return_transfer", {})
    if not event_result.get("success", true):
        result["passive_event_success"] = false
        result["passive_event_reason"] = event_result.get("reason", "")
    return result

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
        "rank_name": str(card.current_rank_name()),
        "rank_order": int(card.current_rank_order()),
        "base_attribute": str(card.current_attribute()),
        "attributes": attributes,
        "anomalies": card.anomaly_snapshot(),
        "growth_layers": card.anomaly_layers("buff", "growth"),
        "heat_layers": card.anomaly_layers("buff", "qi_heat"),
        "had_poison": card.has_anomaly("state", "poison"),
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
