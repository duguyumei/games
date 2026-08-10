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

func _init(lifecycle = null) -> void:
    card_state_lifecycle = lifecycle

func use_card_state_lifecycle(lifecycle) -> void:
    card_state_lifecycle = lifecycle

func use_status_system(system) -> void:
    status_system = system

func use_card_reshape_runtime(runtime) -> void:
    card_reshape_runtime = runtime

func reset_zones(side, cards: Array, rng: RandomNumberGenerator, shuffle_cards: bool = true) -> void:
    side.hand.clear()
    side.staging.clear()
    side.discard_pile.clear()
    side.temporarily_removed_cards.clear()
    side.draw_pile = cards.duplicate()
    if shuffle_cards:
        shuffle(side.draw_pile, rng)

func draw(side, count: int) -> Array:
    var drawn: Array = []
    for _index in range(maxi(0, count)):
        if side.draw_pile.is_empty():
            break
        var card = side.draw_pile.back()
        move_card(side, "draw_pile", "hand", card, "draw")
        drawn.append(card)
    return drawn

func stage_cards(side, card_ids: Array) -> bool:
    var found: Array = []
    for card_id in card_ids:
        var card = find_card(side, "hand", str(card_id))
        if card == null or found.has(card):
            return false
        found.append(card)
    for card in found:
        if status_system != null and not status_system.can_play_card(side, card).get("allowed", false):
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
    var committed: Array = side.staging.duplicate()
    for card in committed:
        move_card(side, "staging", "discard_pile", card, "normal_play")
    return committed

func commit_staging_with_recycles(
        side,
        recycle_anomalies: Dictionary,
        rng: RandomNumberGenerator) -> Dictionary:
    return commit_selected_staging_with_recycles(
        side, side.staging.duplicate(), recycle_anomalies, rng)

func commit_selected_staging_with_recycles(
        side,
        selected_cards: Array,
        recycle_anomalies: Dictionary,
        rng: RandomNumberGenerator) -> Dictionary:
    var committed: Array = []
    var recycled: Array = []
    var should_shuffle := false
    for card in selected_cards:
        if not side.staging.has(card):
            continue
        committed.append(card)
        if recycle_anomalies.has(card.id):
            var anomaly_data: Dictionary = recycle_anomalies[card.id]
            var anomaly_id := str(anomaly_data.get("anomaly", ""))
            if anomaly_id != "" and status_system != null:
                status_system.apply_card_anomaly(
                    card,
                    str(anomaly_data.get("category", "mark")),
                    anomaly_id,
                    {},
                    "出牌后回收")
            elif anomaly_id != "":
                card.set_anomaly(str(anomaly_data.get("category", "mark")), anomaly_id)
            var destination := str(anomaly_data.get("destination", "draw_pile"))
            if bool(anomaly_data.get("enter_discard_first", false)):
                move_card(side, "staging", "discard_pile", card, "normal_play")
                if side.discard_pile.has(card):
                    move_card(side, "discard_pile", destination, card, "played_return")
            else:
                move_card(side, "staging", destination, card, "gu_recycle")
            should_shuffle = should_shuffle or bool(anomaly_data.get("shuffle", destination == "draw_pile"))
            recycled.append(card)
        else:
            move_card(side, "staging", "discard_pile", card, "normal_play")
    if should_shuffle:
        shuffle(side.draw_pile, rng)
    return {"committed": committed, "recycled": recycled}

func random_discard(side, count: int, rng: RandomNumberGenerator) -> Array:
    var discarded: Array = []
    for _index in range(maxi(0, count)):
        if side.hand.is_empty():
            break
        var card = side.hand[rng.randi_range(0, side.hand.size() - 1)]
        move_card(side, "hand", "discard_pile", card, "explicit_discard")
        discarded.append(card)
    return discarded

func discard_all(side) -> Array:
    var discarded: Array = side.hand.duplicate()
    for card in discarded:
        move_card(side, "hand", "discard_pile", card, "explicit_discard")
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
        destination: String = "draw_pile") -> Dictionary:
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
    return {
        "success": true,
        "card": card,
        "from_owner": source_side.owner_id,
        "to_owner": target_side.owner_id,
        "from": source_zone,
        "to": destination,
        "reason": "temporary_transfer",
    }

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
    return {
        "success": true,
        "card": card,
        "from_owner": holder_side.owner_id,
        "to_owner": original_side.owner_id,
        "from": str(location["zone"]),
        "to": destination,
        "reason": "return_transfer",
    }

func add_generated(side, card, destination: String, temporary: bool) -> Dictionary:
    if card == null or destination not in ACTIVE_ZONES:
        return {"success": false, "reason": "生成真气的目标牌区无效"}
    if has_instance(side, str(card.id)):
        return {"success": false, "reason": "真气实例 ID 已存在于战斗牌区"}
    card.temporary_card = temporary
    zone(side, destination).append(card)
    return {
        "success": true,
        "card": card,
        "from": "generated",
        "to": destination,
        "reason": "temporary_generate" if temporary else "permanent_generate",
    }

func move_card(
        side,
        source_zone: String,
        destination_zone: String,
        card,
        reason: String) -> Dictionary:
    if source_zone not in ACTIVE_ZONES or destination_zone not in ACTIVE_ZONES:
        return {"success": false, "reason": "未知牌区"}
    var source: Array = zone(side, source_zone)
    if not source.has(card):
        return {"success": false, "reason": "来源牌区没有目标真气"}
    source.erase(card)
    zone(side, destination_zone).append(card)
    if destination_zone == "discard_pile":
        if status_system != null:
            status_system.on_card_enter_discard(card, reason)
        elif card_state_lifecycle != null:
            card_state_lifecycle.on_enter_discard(card)
        if reason == "explicit_discard" and status_system != null:
            status_system.on_card_explicit_discard(side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_entered_discard(side, card)
    elif destination_zone == "hand" and reason == "draw":
        if status_system != null:
            status_system.on_card_drawn(side, card)
        if card_reshape_runtime != null:
            card_reshape_runtime.on_card_drawn(side, card)
    return {
        "success": true,
        "card": card,
        "from": source_zone,
        "to": destination_zone,
        "reason": reason,
    }

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

func shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary
