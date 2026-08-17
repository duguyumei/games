class_name BattleAiAdapter
extends RefCounted

## CombatEngine 与远程 AI 协议之间的防腐适配层。
##
## 这里把领域对象投影为公开上下文、观察和候选，并回写公开行动结果；故意
## 不选择候选、不调用 Provider，也不绕过引擎执行远程动作。

const BattleContextScript = preload("res://core/ai/ai_battle_context.gd")
const DecisionObservationScript = preload("res://core/ai/ai_decision_observation.gd")
const CandidateScript = preload("res://core/ai/ai_candidate.gd")
const ProtocolScript = preload("res://core/ai/ai_protocol.gd")
const StableEncoderScript = preload("res://core/ai/ai_stable_value_encoder.gd")
const SemanticProjectorScript = preload(
    "res://core/ai/ai_content_semantic_projector.gd")
const StateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")
const PublicStateDeltaScript = preload(
    "res://core/ai/ai_public_state_delta.gd")

var engine
var encoder := StableEncoderScript.new()
var state_projector := StateProjectorScript.new()
var state_delta := PublicStateDeltaScript.new()
var context_snapshot: Dictionary = {}
var _before_visible_state: Dictionary = {}

func _init(combat_engine) -> void:
    engine = combat_engine

func build_context(battle_id: String):
    var semantic_projector = SemanticProjectorScript.new(engine.content_catalog)
    var semantics: Dictionary = semantic_projector.project(
        engine.player, engine.enemy, engine.sequence_book,
        engine.enemy_sequence_book)
    context_snapshot = {
        "battle_id": battle_id,
        "rules_version": ProtocolScript.RULES_VERSION,
        "content_version": ProtocolScript.CONTENT_VERSION,
        "content_fingerprint": semantic_projector.fingerprint(semantics),
        "ai_protocol_version": ProtocolScript.AI_PROTOCOL_VERSION,
        "prompt_version": ProtocolScript.PROMPT_VERSION,
        "player_build": _side_build(engine.player, engine.sequence_book),
        "enemy_build": _side_build(engine.enemy, engine.enemy_sequence_book),
        "content_semantics": semantics,
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
    }
    return BattleContextScript.new().configure(context_snapshot)

func build_window(battle_id: String, window_serial: int) -> Dictionary:
    var player_can_act: bool = engine.battle_flow.can_act(engine.player)
    var enemy_can_act: bool = engine.battle_flow.can_act(engine.enemy)
    var window_id := "%s:r%d:w%d" % [
        battle_id,
        engine.turn_number,
        window_serial,
    ]
    var candidates: Array = []
    var fallback_proposal = null
    var observation = null
    var candidate_set: Dictionary = {}
    if enemy_can_act:
        var candidate_set_values: Dictionary = engine.enemy_candidate_set()
        candidate_set = candidate_set_values
        var battle_observation = engine.enemy_decision_observation()
        var self_state := state_projector.project_self(
            engine.enemy, engine.enemy_sequence_book, engine.battle_flow)
        var opponent_state := state_projector.project_opponent(
            engine.player, engine.sequence_book, engine.battle_flow)
        opponent_state["opponent_threat"] = battle_observation.opponent_threat.duplicate(true)
        observation = DecisionObservationScript.new().configure({
            "decision_id": window_id,
            "window_id": window_id,
            "state_hash": "pending",
            "round_number": engine.turn_number,
            "action_index": engine.enemy_action_index,
            "self_state": self_state,
            "opponent_public_state": opponent_state,
            "metadata": {
                "resolution_mode": "synchronized" if player_can_act else "single",
            },
        })
        var records: Array = candidate_set.get("records", [])
        var proposals: Array = candidate_set.get("proposals", [])
        for index in range(proposals.size()):
            candidates.append(_candidate_from_proposal(
                proposals[index], index, engine.enemy.hand.size(),
                records[index] if index < records.size() else {}))
        var state_hash := _state_hash(observation, candidates)
        observation.state_hash = state_hash
        fallback_proposal = Callable(
            engine.enemy_planning_service,
            "choose_from_candidate_set").bind(proposals.duplicate())
    _before_visible_state = _visible_battle_state()
    return {
        "window_id": window_id,
        "decision_id": window_id,
        "state_hash": observation.state_hash if observation != null else "",
        "round_number": engine.turn_number,
        "action_index": engine.enemy_action_index,
        "player_can_act": player_can_act,
        "enemy_can_act": enemy_can_act,
        "observation": observation,
        "candidates": candidates,
        "fallback_proposal": fallback_proposal,
        "possible_enemy_intents": candidate_set.get(
            "possible_enemy_intents", []).duplicate(true) if enemy_can_act else [],
        "candidate_reduction": engine.enemy_planning_service.last_candidate_reduction.duplicate(true),
        "candidate_diagnostics": engine.enemy_planning_service.candidate_reduction_diagnostics(),
        "versions": _versions(),
    }

func record_action_result(coordinator, result: Dictionary) -> void:
    if coordinator == null:
        return
    var player_preview: Dictionary = result.get("preview", {})
    if not player_preview.is_empty():
        _record_event(coordinator, {
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
        _record_event(coordinator, {
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
    var after_state := _visible_battle_state()
    var delta := {
        "player": state_delta.between(
            _before_visible_state.get("player", {}), after_state["player"]),
        "enemy": state_delta.between(
            _before_visible_state.get("enemy", {}), after_state["enemy"]),
    }
    var player_damage := maxi(
        0, -int(delta["enemy"]["life_delta"].get("delta", 0)))
    var enemy_damage := maxi(
        0, -int(delta["player"]["life_delta"].get("delta", 0)))
    if player_damage > 0:
        _record_event(coordinator, {
            "round_number": engine.turn_number,
            "action_index": coordinator.current_action_index,
            "window_id": coordinator.current_window_id,
            "event_type": "damage_resolved",
            "actor_id": "player",
            "visibility": "public",
            "payload": {"amount": player_damage, "target_id": "enemy"},
        })
    if enemy_damage > 0:
        _record_event(coordinator, {
            "round_number": engine.turn_number,
            "action_index": coordinator.current_action_index,
            "window_id": coordinator.current_window_id,
            "event_type": "damage_resolved",
            "actor_id": "enemy",
            "visibility": "public",
            "payload": {"amount": enemy_damage, "target_id": "player"},
        })
    for change_value in result.get("same_qi_changes", []):
        if not change_value is Dictionary:
            continue
        var change: Dictionary = change_value
        if change.get("reused", false):
            continue
        _record_event(coordinator, {
            "round_number": engine.turn_number,
            "action_index": coordinator.current_action_index,
            "window_id": coordinator.current_window_id,
            "event_type": "same_qi_changed",
            "actor_id": str(change.get("side", "system")),
            "visibility": "public",
            "payload": {
                "before": int(change.get("same_qi_before", 0)),
                "gained": int(change.get("gained", 0)),
                "spent": int(change.get("spent", 0)),
                "after": int(change.get("same_qi_after", 0)),
                "capacity": int(change.get("same_qi_capacity", 5)),
                "granted_actions": int(change.get("granted_actions", 0)),
                "source": str(change.get("source", "")),
                "action_token": str(change.get("action_token", "")),
            },
        })
    _record_event(coordinator, {
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
            "state_delta": delta,
        },
    })
    _before_visible_state = after_state
    coordinator.record_actual_result(coordinator.current_decision_id, {
        "life_delta": {
            "player": delta["player"]["life_delta"],
            "enemy": delta["enemy"]["life_delta"],
        },
        "defense_delta": {
            "player": delta["player"]["defense_delta"],
            "enemy": delta["enemy"]["defense_delta"],
        },
        "zone_count_delta": {
            "player": delta["player"]["zone_count_delta"],
            "enemy": delta["enemy"]["zone_count_delta"],
        },
        "revealed_zone_changes": (
            delta["player"]["revealed_zone_changes"]
            + delta["enemy"]["revealed_zone_changes"]),
        "status_changes": delta["player"]["status_changes"] \
            + delta["enemy"]["status_changes"],
        "passive_triggers": delta["player"]["passive_changes"] \
            + delta["enemy"]["passive_changes"],
        "sequence_changes": delta["player"]["sequence_changes"] \
            + delta["enemy"]["sequence_changes"],
        "battle_state_after": engine.battle_state,
        "actual_damage": _actual_damage(delta),
        "actual_defense": maxi(0, int(delta["enemy"]["defense_delta"]["delta"])),
        "lethal": engine.player.life <= 0,
        "avoided_death": engine.enemy.life > 0,
        "waited_for_choice": bool(result.get("pending_choice", false)),
        "local_revalidation_failed": false,
    })

func record_consumable_use(
        coordinator,
        card_ids: Array,
        result: Dictionary) -> void:
    if coordinator == null:
        return
    _record_event(coordinator, {
        "round_number": engine.turn_number,
        "action_index": engine.enemy_action_index,
        "window_id": coordinator.current_window_id,
        "event_type": "consumable_used",
        "actor_id": "player",
        "visibility": "public",
        "payload": {
            "consumable_id": str(result.get("consumable_id", "")),
            "hidden_target_count": card_ids.size(),
            "technique_acquired": str(result.get("technique_acquired", "")),
            "technique_equipped": bool(result.get("technique_equipped", false)),
        },
    })

func _candidate_from_proposal(
        proposal, index: int, hand_size: int, record: Dictionary = {}):
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
            "same_qi_gain": int(preview.get("same_qi_gain", 0)),
            "same_qi_trigger_count": int(preview.get(
                "same_qi_trigger_count", 0)),
            "retained_hand_count": maxi(0, hand_size - proposal.card_ids.size()),
            "strategic_features": _remote_feature_snapshot(record.get("features", {})),
        },
        "tags": [
            str(preview.get("hand", {}).get("id", "")),
            str(preview.get("technique_id", "")),
        ],
        "diagnostic_candidate_id": str(record.get("diagnostic_candidate_id", "")),
    }, proposal)

func _remote_feature_snapshot(features: Dictionary) -> Dictionary:
    if features.is_empty():
        return {}
    var result := features.duplicate(true)
    result.erase("internal")
    return result

func _enemy_self_state(observation) -> Dictionary:
    var result: Dictionary = observation.public_snapshot()
    result["hand_cards"] = _card_snapshots(engine.enemy.hand)
    result["equipped_inner_skill_ids"] = engine.enemy.equipped_inner_skill_ids.duplicate()
    result["owned_technique_ids"] = engine.enemy.owned_technique_ids.duplicate()
    result["hand_proficiency_fixed"] = engine.enemy.hand_proficiency_fixed.duplicate(true)
    return result

func _player_public_state() -> Dictionary:
    return {
        "life": engine.player.life,
        "max_life": engine.player.max_life,
        "defense": engine.player.defense,
        "same_qi_value": engine.player.same_qi_value,
        "same_qi_capacity": int(engine.player.effective_same_qi_capacity_result({
            "source_kind": "ai_observation",
        }).get("effective_value", 5)),
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
        "hand_proficiency_fixed": side.hand_proficiency_fixed.duplicate(true),
        "sequences": sequence_book.sequences.duplicate(true),
        "sequence_positions": sequence_book.positions.duplicate(true),
        "technique_slot_usage": sequence_book.public_slot_usage_snapshot(),
    }

func _state_hash(observation, candidates: Array) -> String:
    var observation_snapshot: Dictionary = observation.snapshot()
    observation_snapshot.erase("state_hash")
    var candidate_snapshots: Array = []
    for candidate in candidates:
        candidate_snapshots.append(candidate.public_snapshot())
    return encoder.sha256({
        "observation": observation_snapshot,
        "candidates": candidate_snapshots,
        "rules_version": context_snapshot.get("rules_version", ""),
        "content_fingerprint": context_snapshot.get("content_fingerprint", ""),
        "passive_source_fingerprint": encoder.sha256({
            "enemy": observation_snapshot.get("self", {}).get("passive_progress", []),
            "player": observation_snapshot.get("opponent", {}).get("public_passive_progress", []),
        }),
    })

func _versions() -> Dictionary:
    return {
        "rules_version": context_snapshot.get("rules_version", ""),
        "content_version": context_snapshot.get("content_version", 0),
        "content_fingerprint": context_snapshot.get("content_fingerprint", ""),
        "ai_protocol_version": ProtocolScript.AI_PROTOCOL_VERSION,
        "prompt_version": ProtocolScript.PROMPT_VERSION,
    }

func _visible_battle_state() -> Dictionary:
    return {
        "player": state_projector.project_opponent(
            engine.player, engine.sequence_book, engine.battle_flow),
        "enemy": state_projector.project_self(
            engine.enemy, engine.enemy_sequence_book, engine.battle_flow),
    }

func _record_event(coordinator, event: Dictionary) -> Dictionary:
    var projected: Dictionary = coordinator.record_public_event(event)
    if not projected.is_empty():
        engine.enemy_planning_service.record_public_ai_event(projected)
    return projected

func _actual_damage(delta: Dictionary) -> int:
    var player_life: Dictionary = delta.get("player", {}).get("life_delta", {})
    var enemy_life: Dictionary = delta.get("enemy", {}).get("life_delta", {})
    return maxi(0, -int(player_life.get("delta", 0))) \
        + maxi(0, -int(enemy_life.get("delta", 0)))

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
