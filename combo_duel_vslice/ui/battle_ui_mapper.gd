class_name BattleUiMapper
extends RefCounted

## BattleSnapshot -> UI-only Dictionary contract.
##
## This mapper is deliberately read-only: it does not hold a session, call preview,
## execute commands, advance RNG, or retain authoritative battle state.

const UiDesignScript = preload("res://ui/ui_design.gd")

const HAND_NAMES := {
    "high_card": "高牌",
    "pair": "一对",
    "two_pair": "两对",
    "three_of_a_kind": "三条",
    "straight": "顺子",
    "full_house": "葫芦",
    "four_of_a_kind": "四条",
    "five_of_a_kind": "五条",
}

static func map(snapshot: BattleSnapshot, context: Dictionary = {}) -> Dictionary:
    var selected_ids: Array = context.get("selected_ids", [])
    var preview: Dictionary = context.get("action_preview", {}).duplicate(true)
    var active_consumable_slot := int(context.get("active_consumable_slot", -1))
    var include_debug := bool(context.get("include_debug", true))
    var player := _side(snapshot.player, "player")
    var enemy := _side(snapshot.enemy, "enemy")
    var selected_cards: Array = []
    for card_value in player["hand"]:
        var card: Dictionary = card_value
        if selected_ids.has(str(card.get("id", ""))):
            selected_cards.append(card.duplicate(true))
    var ai_decision: Dictionary = snapshot.ai_decision
    var battle_active := snapshot.battle_state == "active"
    var commands := {
        "confirm": battle_active \
            and not selected_ids.is_empty() \
            and active_consumable_slot < 0 \
            and snapshot.actions_available > 0 \
            and bool(ai_decision.get("can_player_confirm", true)),
        "end_turn": battle_active,
        "start_turn": battle_active \
            and snapshot.actions_available <= 0 \
            and snapshot.enemy_actions_available <= 0,
        "use_consumable": bool(context.get("can_use_consumable", false)),
        "select_cards": battle_active and snapshot.actions_available > 0,
    }
    var action_index := int(context.get("action_index", 0))
    var result := {
        "player": player,
        "enemy": enemy,
        "hand": player["hand"].duplicate(true),
        "zones": {
            "player": player["zones"].duplicate(true),
            "enemy": enemy["zones"].duplicate(true),
        },
        "action_preview": _action_preview(preview, selected_cards),
        "technique_sequences": {
            "player": _technique_slots(snapshot.player),
            "enemy": _technique_slots(snapshot.enemy),
        },
        "resources": {
            "player": player["resources"].duplicate(true),
            "enemy": enemy["resources"].duplicate(true),
        },
        "statuses": {
            "player": player["statuses"].duplicate(true),
            "enemy": enemy["statuses"].duplicate(true),
        },
        "enemy_intents": _enemy_intents(snapshot.possible_enemy_intents),
        "available_commands": commands,
        "battle_phase": {
            "state": snapshot.battle_state,
            "detail": snapshot.battle_state_detail,
            "turn": snapshot.turn_number,
            "action_index": action_index,
            "player_actions": snapshot.actions_available,
            "enemy_actions": snapshot.enemy_actions_available,
            "resolution_mode": snapshot.resolution_mode,
            "round_ended": snapshot.round_ended,
        },
        "selection": {
            "ids": selected_ids.duplicate(),
            "count": selected_ids.size(),
            "limit": 5,
            "active_consumable_slot": active_consumable_slot,
        },
        "last_resolution": {
            "player_cards": snapshot.last_player_action_cards.duplicate(true),
            "enemy_cards": snapshot.last_enemy_action_cards.duplicate(true),
            "player_preview": snapshot.last_preview.duplicate(true),
            "enemy_preview": snapshot.last_enemy_preview.duplicate(true),
        },
        "notification": str(context.get("notification", "")),
    }
    if include_debug:
        result["debug_info"] = {
            "seed": int(context.get("seed", 2308)),
            "active_channel": str(context.get("active_log_channel", "battle")),
            "battle_log": snapshot.battle_log.duplicate(true),
            "system_log": snapshot.system_log.duplicate(true),
            "delayed_count": snapshot.delayed_count,
            "raw_state": snapshot.to_dict(),
        }
    return result

static func _side(side: BattleSideSnapshot, side_key: String) -> Dictionary:
    return {
        "side": side_key,
        "name": side.name if side.name != "" else ("太吾" if side_key == "player" else "未知敌手"),
        "life": side.life,
        "max_life": side.max_life,
        "defense": side.defense,
        "resources": {
            "momentum": side.momentum_value,
            "momentum_cap": side.momentum_cap,
            "same_qi": side.same_qi_value,
            "same_qi_capacity": side.same_qi_capacity,
            "poison": side.poison_total_amount,
            "direct_power_fixed": side.direct_power_fixed,
            "direct_power_percent": side.direct_power_percent,
        },
        "statuses": _statuses(side),
        "hand": side.hand.duplicate(true),
        "hand_count": side.hand_count,
        "hand_limit": side.hand_limit,
        "zones": {
            "draw": side.draw_pile.duplicate(true),
            "draw_count": side.draw_count,
            "discard": side.discard_pile.duplicate(true),
            "discard_count": side.discard_count,
            "consumed": side.temporarily_removed.duplicate(true),
            "consumed_count": side.temporarily_removed_count,
            "deck_count": side.deck_count,
        },
        "inner_skills": side.equipped_inner_skills.duplicate(true),
        "inner_skill_limit": side.inner_skill_limit,
        "items": side.item_ids.duplicate(),
        "consumables": side.consumables.duplicate(true),
        "consumable_limit": side.consumable_limit,
        "occupied_meridian_count": side.occupied_meridian_count,
    }

static func _statuses(side: BattleSideSnapshot) -> Array:
    var result: Array = [{
        "id": "momentum", "text": "连势 %d/%d" % [
            side.momentum_value, side.momentum_cap],
        "color": UiDesignScript.COLORS["orange"],
    }, {
        "id": "same_qi", "text": "同气 %d/%d" % [side.same_qi_value, side.same_qi_capacity],
        "color": UiDesignScript.COLORS["green"],
    }]
    if side.poison_total_amount > 0:
        result.append({
            "id": "poison", "text": "毒 %d" % side.poison_total_amount,
            "color": UiDesignScript.COLORS["poison"],
        })
    if side.current_reflection_percent > 0:
        result.append({
            "id": "reflection", "text": "反震 %d%%" % side.current_reflection_percent,
            "color": UiDesignScript.COLORS["purple"],
        })
    if not side.block_sources.is_empty():
        result.append({
            "id": "block", "text": "格挡 %d" % side.block_sources.size(),
            "color": UiDesignScript.COLORS["defense"],
        })
    if not side.deflection_sources.is_empty():
        result.append({
            "id": "deflection", "text": "卸力 %d" % side.deflection_sources.size(),
            "color": UiDesignScript.COLORS["blue"],
        })
    if not side.challenge_records.is_empty():
        result.append({
            "id": "challenge", "text": "邀战 %d" % side.challenge_records.size(),
            "color": UiDesignScript.COLORS["danger"],
        })
    return result

static func _action_preview(preview: Dictionary, selected_cards: Array) -> Dictionary:
    if preview.is_empty():
        return {
            "state": "idle", "valid": false, "cards": selected_cards,
            "hand_name": "?", "qi": 0, "multiplier": 0.0,
            "technique_name": "?", "technique_value": 0,
            "description": "选择真气后显示功法",
        }
    if not bool(preview.get("valid", false)):
        return {
            "state": "invalid", "valid": false, "cards": selected_cards,
            "hand_name": "无效选择", "qi": 0, "multiplier": 0.0,
            "technique_name": "?", "technique_value": 0,
            "description": str(preview.get("reason", "选择无效")),
        }
    var values: Dictionary = preview.get("values", {})
    var technique: Dictionary = preview.get("technique", {})
    return {
        "state": "preview", "valid": true,
        "cards": preview.get("cards", selected_cards).duplicate(true),
        "contributing_card_ids": preview.get("hand", {}).get(
            "contributing_card_ids", []).duplicate(),
        "hand_name": str(preview.get("hand", {}).get("name", "?")),
        "qi": int(values.get("contribution_total", 0)),
        "multiplier": float(values.get("attribute_concentration", 0)),
        "technique_name": str(technique.get("name", "空序列")),
        "technique_value": int(values.get("technique_value", 0)),
        "description": str(technique.get("description", "")),
        "same_qi_gain": int(preview.get("same_qi_gain", 0)),
        "inner_skill_defense": int(preview.get("intent", {}).get("inner_skill_defense", 0)),
        "next_technique": preview.get("next_technique", {}).duplicate(true),
    }

static func _enemy_intents(intents: Array) -> Array:
    var result: Array = []
    for value in intents.slice(0, 5):
        var intent: Dictionary = value
        result.append({
            "display_name": str(intent.get("display_name", "可能意图")),
            "direction": str(intent.get("direction", "prepare")),
            "damage": int(intent.get("damage", 0)),
            "defense": int(intent.get("defense", 0)),
            "same_qi_gain": int(intent.get("same_qi_gain", 0)),
            "played_count": int(intent.get("played_count", 0)),
            "public_tags": intent.get("public_tags", []).duplicate(),
        })
    return result

static func _technique_slots(side: BattleSideSnapshot) -> Array:
    var sequences: Dictionary = side.technique_sequences
    var usage: Dictionary = side.technique_slot_usage
    var hand_ids: Array = sequences.keys()
    for hand_id_value in usage:
        if not hand_ids.has(hand_id_value):
            hand_ids.append(hand_id_value)
    hand_ids.sort_custom(func(left, right):
        var left_index := HAND_NAMES.keys().find(str(left))
        var right_index := HAND_NAMES.keys().find(str(right))
        left_index = left_index if left_index >= 0 else 999
        right_index = right_index if right_index >= 0 else 999
        return left_index < right_index)
    var result: Array = []
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        var slots: Array = sequences.get(hand_id, [])
        var slot_usage: Dictionary = usage.get(hand_id, {})
        var current: Dictionary = slots[0] if not slots.is_empty() else {}
        result.append({
            "hand_id": hand_id,
            "hand_name": str(HAND_NAMES.get(hand_id, hand_id)),
            "technique_id": str(current.get("technique_id", "")),
            "occupied": int(slot_usage.get("occupied", slots.size())),
            "capacity": int(slot_usage.get("capacity", slots.size())),
            "slots": slots.duplicate(true),
        })
    return result
