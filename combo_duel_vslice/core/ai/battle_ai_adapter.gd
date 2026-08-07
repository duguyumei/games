class_name BattleAiAdapter
extends RefCounted

## CombatEngine 与远程 AI 协议之间的防腐适配层。
##
## 这里把领域对象投影为公开上下文、观察和候选，并回写公开行动结果；故意
## 不选择候选、不调用 Provider，也不绕过引擎执行远程动作。

const BattleContextScript = preload("res://core/ai/ai_battle_context.gd")
const DecisionObservationScript = preload("res://core/ai/ai_decision_observation.gd")
const CandidateScript = preload("res://core/ai/ai_candidate.gd")

var engine

func _init(combat_engine) -> void:
    engine = combat_engine

func build_context(battle_id: String):
    return BattleContextScript.new().configure({
        "battle_id": battle_id,
        "rules_version": "v0.30",
        "player_build": _side_build(engine.player, engine.sequence_book),
        "enemy_build": _side_build(engine.enemy, engine.enemy_sequence_book),
        "visibility": {
            "player_current_hand": false,
            "player_draw_order": false,
            "random_hidden_targets": false,
        },
        "protocol": {
            "candidate_selection_only": true,
            "history_delta": true,
            "synchronized_group_indices": true,
        },
    })

func build_window(battle_id: String, window_serial: int) -> Dictionary:
    var player_can_act: bool = engine.battle_flow.can_act(engine.player)
    var enemy_can_act: bool = engine.battle_flow.can_act(engine.enemy)
    var window_id := "%s:r%d:w%d" % [
        battle_id,
        engine.turn_number,
        window_serial,
    ]
    var state_hash := _state_hash(window_id)
    var candidates: Array = []
    var fallback_proposal = null
    var observation = null
    if enemy_can_act:
        var battle_observation = engine.enemy_decision_observation()
        observation = DecisionObservationScript.new().configure({
            "decision_id": window_id,
            "window_id": window_id,
            "state_hash": state_hash,
            "round_number": engine.turn_number,
            "action_index": engine.enemy_action_index,
            "self_state": _enemy_self_state(battle_observation),
            "opponent_public_state": _player_public_state(),
            "metadata": {
                "resolution_mode": "synchronized" if player_can_act else "single",
            },
        })
        var proposals: Array = engine.enemy_remote_action_proposals()
        for index in range(proposals.size()):
            candidates.append(_candidate_from_proposal(
                proposals[index], index, engine.enemy.hand.size()))
        fallback_proposal = engine.enemy_utility_action_proposal()
    return {
        "window_id": window_id,
        "decision_id": window_id,
        "state_hash": state_hash,
        "round_number": engine.turn_number,
        "action_index": engine.enemy_action_index,
        "player_can_act": player_can_act,
        "enemy_can_act": enemy_can_act,
        "observation": observation,
        "candidates": candidates,
        "fallback_proposal": fallback_proposal,
    }

func record_action_result(coordinator, result: Dictionary) -> void:
    if coordinator == null:
        return
    var player_preview: Dictionary = result.get("preview", {})
    if not player_preview.is_empty():
        coordinator.record_public_event({
            "round_number": engine.turn_number,
            "action_index": coordinator.current_action_index,
            "window_id": coordinator.current_window_id,
            "event_type": "cards_played",
            "actor_id": "player",
            "visibility": "public",
            "payload": {
                "played_card_ids": _card_ids(result.get("played_cards", [])),
                "hand_type": str(player_preview.get("hand", {}).get("id", "")),
                "technique_id": str(player_preview.get("technique_id", "")),
            },
        })
    var enemy_preview: Dictionary = result.get("enemy_preview", {})
    if not enemy_preview.is_empty():
        coordinator.record_public_event({
            "round_number": engine.turn_number,
            "action_index": coordinator.current_action_index,
            "window_id": coordinator.current_window_id,
            "event_type": "cards_played",
            "actor_id": "enemy",
            "visibility": "public",
            "payload": {
                "played_card_ids": _card_ids(result.get("enemy_played_cards", [])),
                "hand_type": str(enemy_preview.get("hand", {}).get("id", "")),
                "technique_id": str(enemy_preview.get("technique_id", "")),
            },
        })
    coordinator.record_public_event({
        "round_number": engine.turn_number,
        "action_index": coordinator.current_action_index,
        "window_id": coordinator.current_window_id,
        "event_type": "action_resolved",
        "actor_id": "system",
        "visibility": "public",
        "payload": {
            "player_life": engine.player.life,
            "player_defense": engine.player.defense,
            "enemy_life": engine.enemy.life,
            "enemy_defense": engine.enemy.defense,
            "battle_state": engine.battle_state,
        },
    })

func record_consumable_use(
        coordinator,
        card_ids: Array,
        result: Dictionary) -> void:
    if coordinator == null:
        return
    coordinator.record_public_event({
        "round_number": engine.turn_number,
        "action_index": engine.enemy_action_index,
        "window_id": coordinator.current_window_id,
        "event_type": "consumable_used",
        "actor_id": "player",
        "visibility": "public",
        "payload": {
            "consumable_id": str(result.get("consumable_id", "")),
            "hidden_target_count": card_ids.size(),
            "acquired_technique_id": str(result.get("acquired_technique_id", "")),
        },
    })

func _candidate_from_proposal(proposal, index: int, hand_size: int):
    var preview: Dictionary = proposal.preview
    var intent: Dictionary = preview.get("intent", {})
    var values: Dictionary = preview.get("values", {})
    return CandidateScript.new().configure({
        "candidate_id": "candidate-%03d" % index,
        "groups": proposal.groups.duplicate(true),
        "summary": {
            "hand_type": str(preview.get("hand", {}).get("id", "")),
            "technique_id": str(preview.get("technique_id", "")),
            "next_technique_id": str(preview.get("next_technique_id", "")),
            "technique_value": int(values.get("technique_value", 0)),
            "damage": maxi(0, int(intent.get("damage", 0))),
            "defense": maxi(0, int(intent.get("defense", 0))),
            "segments": maxi(0, int(intent.get("segments", 0))),
            "combo": bool(intent.get("combo", false)),
            "retained_hand_count": maxi(0, hand_size - proposal.card_ids.size()),
        },
        "tags": [
            str(preview.get("hand", {}).get("id", "")),
            str(preview.get("technique_id", "")),
        ],
    }, proposal)

func _enemy_self_state(observation) -> Dictionary:
    var result: Dictionary = observation.public_snapshot()
    result["hand_cards"] = _card_snapshots(engine.enemy.hand)
    result["stacks"] = engine.enemy.stacks.duplicate(true)
    result["equipped_inner_skill_ids"] = engine.enemy.equipped_inner_skill_ids.duplicate()
    result["owned_technique_ids"] = engine.enemy.owned_technique_ids.duplicate()
    result["insight_multipliers"] = engine.enemy.insight_multipliers.duplicate(true)
    return result

func _player_public_state() -> Dictionary:
    return {
        "life": engine.player.life,
        "max_life": engine.player.max_life,
        "defense": engine.player.defense,
        "stacks": engine.player.stacks.duplicate(true),
        "hand_count": engine.player.hand.size(),
        "draw_pile_count": engine.player.draw_pile.size(),
        "discard_count": engine.player.discard_pile.size(),
        "temporarily_removed_count": engine.player.temporarily_removed_cards.size(),
        "action_state": engine.actor_action_state(engine.player),
    }

func _side_build(side, sequence_book) -> Dictionary:
    var cards: Array = _card_snapshots(side.all_cards_for_run_sync())
    cards.sort_custom(func(left, right):
        return str(left.get("instance_id", "")) < str(right.get("instance_id", "")))
    return {
        "deck": cards,
        "equipped_inner_skill_ids": side.equipped_inner_skill_ids.duplicate(),
        "owned_technique_ids": side.owned_technique_ids.duplicate(),
        "insight_multipliers": side.insight_multipliers.duplicate(true),
        "sequences": sequence_book.sequences.duplicate(true),
        "sequence_positions": sequence_book.positions.duplicate(true),
    }

func _state_hash(window_id: String) -> String:
    var hand_ids: Array[String] = _card_ids(engine.enemy.hand)
    hand_ids.sort()
    return str(hash(JSON.stringify({
        "window_id": window_id,
        "round_number": engine.turn_number,
        "action_index": engine.enemy_action_index,
        "enemy_hand_ids": hand_ids,
        "enemy_action_state": engine.actor_action_state(engine.enemy),
        "enemy_sequence_positions": engine.enemy_sequence_book.positions.duplicate(true),
    })))

func _card_snapshots(cards: Array) -> Array:
    var result: Array = []
    for card in cards:
        result.append(card.to_dict())
    return result

func _card_ids(cards: Array) -> Array[String]:
    var result: Array[String] = []
    for card in cards:
        result.append(str(card.id))
    return result
