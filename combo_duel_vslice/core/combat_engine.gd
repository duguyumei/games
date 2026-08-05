class_name ComboCombatEngine
extends RefCounted

signal state_changed

const DeckFactoryScript = preload("res://core/deck_factory.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const InnerSkillRepositoryScript = preload("res://core/inner_skill_repository.gd")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const ScriptedScenarioScript = preload("res://core/scripted_battle_scenario.gd")
const PlayerActionControllerScript = preload("res://core/player_action_controller.gd")
const EnemyActionControllerScript = preload("res://core/enemy_action_controller.gd")
const BattleObservationScript = preload("res://core/battle_observation.gd")
const ActionPreviewServiceScript = preload("res://core/action_preview_service.gd")
const ActionResolverScript = preload("res://core/action_resolver.gd")
const DamageResolverScript = preload("res://core/damage_resolver.gd")
const GameLogScript = preload("res://core/game_log.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const BattleFlowCoordinatorScript = preload("res://core/battle_flow_coordinator.gd")
const BattleTimingSystemScript = preload("res://core/battle_timing_system.gd")
const StatusSystemScript = preload("res://core/status_system.gd")

var rng := RandomNumberGenerator.new()
var game_log := GameLogScript.new()
var repository := TechniqueRepositoryScript.new()
var inner_skill_repository := InnerSkillRepositoryScript.new()
var consumable_repository := ConsumableRepositoryScript.new()
var sequence_book := SequenceBookScript.new()
var enemy_sequence_book := SequenceBookScript.new()
var trigger_queue := TriggerQueueScript.new(game_log)
var timing_system := BattleTimingSystemScript.new(trigger_queue)
var effect_executor
var player_action_controller := PlayerActionControllerScript.new()
var enemy_action_controller
var action_preview_service
var action_resolver
var damage_resolver := DamageResolverScript.new()
var card_state_lifecycle
var status_system
var player := BattleSideScript.new("玩家", "player")
var enemy := BattleSideScript.new("敌人", "enemy")
var battle_flow := BattleFlowCoordinatorScript.new()
var scenario := ScriptedScenarioScript.new()
var content_catalog
var content_ready: bool = false

var turn_number: int = 0
var actions_available: int:
    get: return battle_flow.available_action_count(player)
    set(value): battle_flow.set_action_count(player, value)
var enemy_actions_available: int:
    get: return battle_flow.available_action_count(enemy)
    set(value): battle_flow.set_action_count(enemy, value)
var natural_combo_used: bool:
    get: return battle_flow.has_claimed_combo(player, "natural_attribute")
    set(value): battle_flow.set_combo_claimed(player, "natural_attribute", value)
var enemy_natural_combo_used: bool:
    get: return battle_flow.has_claimed_combo(enemy, "natural_attribute")
    set(value): battle_flow.set_combo_claimed(enemy, "natural_attribute", value)
var enemy_action_index: int = 0
var locked_enemy_card_ids: Array = []
var locked_enemy_action_proposal = null
var scripted_mode: bool = false
var enemy_ai_enabled: bool = false
var enemy_ai_policy: Dictionary = {}
var enemy_plan: Dictionary = {}
var round_ended: bool = false
var battle_state: String = "active"
var battle_state_detail: String = ""

var delayed_effects: Array = []
var power_modifiers: Dictionary = {}
var last_preview: Dictionary = {}
var last_enemy_preview: Dictionary = {}
var last_played_hand: String = ""
var last_player_action_cards: Array = []
var last_enemy_action_cards: Array = []
var battle_cleanup_completed: bool = false
var battle_start_card_effects_applied: bool = false
var current_round_actors: Array = []

func _init(game_log_override = null, content_catalog_override = null) -> void:
    if game_log_override != null:
        use_game_log(game_log_override)
    content_catalog = (
        content_catalog_override
        if content_catalog_override != null
        else ContentCatalogScript.new())
    if content_catalog_override == null:
        content_catalog.load_all()
    content_ready = bool(content_catalog.loaded)
    if content_ready:
        repository.configure(content_catalog.definition("techniques"))
        inner_skill_repository.configure(content_catalog.definition("inner_skills"))
        consumable_repository.configure(content_catalog.definition("consumables"))
        sequence_book.configure(content_catalog.definition("sequences"))
        enemy_sequence_book.configure(content_catalog.definition("sequences"))
    else:
        game_log.record_system(
            "error",
            "content_catalog",
            "战斗内容目录校验失败",
            "\n".join(content_catalog.errors))
    status_system = StatusSystemScript.new(
        content_catalog,
        timing_system,
        game_log,
        self)
    delayed_effects = status_system.delayed_records
    card_state_lifecycle = status_system.lifecycle
    player.use_card_state_lifecycle(card_state_lifecycle)
    enemy.use_card_state_lifecycle(card_state_lifecycle)
    player.use_status_system(status_system)
    enemy.use_status_system(status_system)
    effect_executor = EffectExecutorScript.new(rng, null, content_catalog)
    enemy_action_controller = EnemyActionControllerScript.new(rng)
    timing_system.register_weak_handler(
        BattleTimingSystemScript.BATTLE_END,
        "combat_engine.flow_cleanup",
        950,
        self,
        "_on_flow_battle_end_timing")
    action_preview_service = ActionPreviewServiceScript.new(
        repository,
        inner_skill_repository,
        effect_executor)
    action_resolver = ActionResolverScript.new(
        self,
        repository,
        inner_skill_repository,
        trigger_queue,
        effect_executor,
        rng,
        timing_system)

func use_game_log(shared_game_log) -> void:
    if shared_game_log == null:
        return
    game_log = shared_game_log
    trigger_queue = TriggerQueueScript.new(game_log)
    timing_system.use_trigger_queue(trigger_queue)
    if status_system != null:
        status_system.use_game_log(game_log)
    if action_resolver != null:
        action_resolver.use_trigger_queue(trigger_queue)

func _create_standard_deck(instance_namespace: String = "") -> Array:
    return DeckFactoryScript.namespace_instance_ids(
        DeckFactoryScript.create_standard_deck_from_definition(
            content_catalog.definition("base_deck")),
        instance_namespace)

func setup(
        seed_value: int = 2308,
        shuffle_cards: bool = true,
        player_deck_override = null) -> void:
    if not content_ready:
        battle_state = "content_error"
        battle_state_detail = "统一内容目录无效"
        state_changed.emit()
        return
    rng.seed = seed_value
    battle_cleanup_completed = false
    battle_start_card_effects_applied = false
    var player_cards: Array = (
        _create_standard_deck()
        if player_deck_override == null
        else player_deck_override)
    player.reset(player_cards, rng, shuffle_cards)
    enemy.reset(_create_standard_deck("enemy"), rng, shuffle_cards)
    battle_flow.reset([player, enemy])
    sequence_book.reset()
    enemy_sequence_book.reset()
    _seed_owned_techniques(player, sequence_book)
    _seed_owned_techniques(enemy, enemy_sequence_book)
    trigger_queue.clear()
    timing_system.reset()
    status_system.reset()
    delayed_effects.clear()
    power_modifiers.clear()
    last_preview.clear()
    last_enemy_preview.clear()
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()
    last_played_hand = ""
    turn_number = 0
    enemy_action_index = 0
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    scripted_mode = false
    enemy_ai_enabled = false
    enemy_ai_policy.clear()
    enemy_plan.clear()
    round_ended = false
    battle_state = "active"
    battle_state_detail = ""
    damage_resolver.reset()
    action_resolver.reset()
    state_changed.emit()

func setup_scripted_battle(
        seed_value: int = 2308,
        scenario_path: String = ScriptedScenarioScript.DEFAULT_PATH,
        use_enemy_ai: bool = false,
        player_deck_override = null) -> bool:
    setup(seed_value, true, player_deck_override)
    if not content_ready:
        return false
    var scenario_loaded := false
    if scenario_path == content_catalog.path_for("scripted_battle"):
        scenario_loaded = scenario.configure(content_catalog.definition("scripted_battle"))
    else:
        scenario_loaded = scenario.load_from_file(scenario_path)
    if not scenario_loaded:
        battle_state = "scenario_error"
        battle_state_detail = "脚本化战斗场景无法载入"
        game_log.record_system(
            "error",
            "scenario_load",
            battle_state_detail,
            scenario_path)
        state_changed.emit()
        return false
    scripted_mode = true
    enemy_ai_enabled = use_enemy_ai
    enemy_ai_policy = scenario.enemy_ai_policy()
    enemy.name = scenario.scenario_name()
    var player_definition := scenario.player_definition()
    var enemy_definition := scenario.enemy_definition()
    player.configure_inner_skills(
        player_definition.get("inner_skills", []),
        int(player_definition.get("technique_slot_index", 0)))
    player.configure_consumables(player_definition.get("consumables", []))
    enemy.configure_inner_skills(
        enemy_definition.get("inner_skills", []),
        int(enemy_definition.get("technique_slot_index", 0)))
    enemy.max_life = int(enemy_definition.get("life", 100))
    enemy.life = enemy.max_life
    enemy.replace_deck(
        scenario.arrange_enemy_deck(_create_standard_deck("enemy")),
        rng,
        false)
    var enemy_sequences := scenario.enemy_sequences()
    if not enemy_sequences.is_empty():
        enemy_sequence_book.configure(enemy_sequences)
        _seed_owned_techniques(enemy, enemy_sequence_book)
    trigger_queue.add_history(
        "battle_setup", enemy.name, "纵切场景", "成功",
        "调试 AI 已载入；不代表正式敌方策略" if enemy_ai_enabled else "固定脚本场景已载入")
    state_changed.emit()
    return true

func replace_player_deck(cards: Array, shuffle_cards: bool = true) -> void:
    player.replace_deck(cards, rng, shuffle_cards)
    battle_start_card_effects_applied = false
    current_round_actors.clear()
    state_changed.emit()

func start_player_turn() -> Array:
    if battle_state != "active":
        return []
    if not battle_start_card_effects_applied:
        timing_system.emit_timing(BattleTimingSystemScript.BATTLE_START, {
            "round_number": 0,
            "actors": [player, enemy],
            "metadata": {"setup_mode": "scripted" if scripted_mode else "solo"},
        })
        battle_start_card_effects_applied = true
    turn_number += 1
    enemy_action_index = 0
    round_ended = false
    last_preview.clear()
    last_enemy_preview.clear()
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()
    enemy_plan.clear()
    current_round_actors = [player]
    if scripted_mode:
        current_round_actors.append(enemy)
    timing_system.emit_timing(BattleTimingSystemScript.ROUND_START, {
        "round_number": turn_number,
        "actors": current_round_actors,
    })
    battle_flow.begin_round([
        {"actor": player, "actions": 1},
        {"actor": enemy, "actions": 1 if scripted_mode else 0},
    ])
    var drawn: Array = []
    var enemy_drawn: Array = []
    for side in current_round_actors:
        timing_system.emit_timing(BattleTimingSystemScript.TURN_START, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
        })
        timing_system.emit_timing(BattleTimingSystemScript.BEFORE_NORMAL_DRAW, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
            "metadata": {
                "hand_count": side.hand.size(),
                "hand_limit": side.hand_limit,
            },
        })
        var side_drawn: Array = side.draw_to_limit()
        timing_system.emit_timing(BattleTimingSystemScript.AFTER_NORMAL_DRAW, {
            "round_number": turn_number,
            "actor": side,
            "actors": current_round_actors,
            "drawn_cards": side_drawn,
            "metadata": {
                "drawn_count": side_drawn.size(),
                "hand_count": side.hand.size(),
                "hand_limit": side.hand_limit,
            },
        })
        if side == player:
            drawn = side_drawn
        elif side == enemy:
            enemy_drawn = side_drawn
    trigger_queue.add_history(
        "round_start" if scripted_mode else "player_turn_start",
        "双方正常补牌" if scripted_mode else "正常补牌",
        "规则",
        "成功",
        "我方抽 %d 张｜对手抽 %d 张" % [drawn.size(), enemy_drawn.size()] if scripted_mode else "补至上限：抽 %d 张" % drawn.size())
    timing_system.emit_timing(BattleTimingSystemScript.ACTION_WINDOW_START, {
        "round_number": turn_number,
        "actors": current_round_actors,
        "metadata": {"scripted_mode": scripted_mode},
    })
    if player.hand.is_empty():
        battle_flow.forfeit_remaining(player, "没有可用于出招的手牌")
    if scripted_mode and battle_flow.can_act(enemy):
        _lock_enemy_action()
    _update_battle_state()
    if battle_state == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy):
        _resolve_enemy_only_actions()
    state_changed.emit()
    return drawn

func end_player_turn() -> void:
    if round_ended and scripted_mode:
        return
    battle_flow.forfeit_remaining(player, "玩家结束当前回合")
    if battle_state == "active" and battle_flow.can_act(enemy):
        _resolve_enemy_only_actions()
    round_ended = true
    var ending_actors: Array = (
        current_round_actors
        if not current_round_actors.is_empty()
        else [player])
    timing_system.emit_timing(BattleTimingSystemScript.ACTION_WINDOW_END, {
        "round_number": turn_number,
        "actors": ending_actors,
    })
    for side in ending_actors:
        timing_system.emit_timing(BattleTimingSystemScript.TURN_END, {
            "round_number": turn_number,
            "actor": side,
            "actors": ending_actors,
        })
    trigger_queue.add_history("player_turn_end", "玩家回合结束", "规则", "成功")
    _update_battle_state()
    state_changed.emit()

func preview(card_ids: Array) -> Dictionary:
    return _preview_for_side(player, card_ids, sequence_book, power_modifiers)

func _preview_for_side(side, card_ids: Array, book, modifiers_by_hand: Dictionary = {}) -> Dictionary:
    return action_preview_service.preview(
        side,
        card_ids,
        book,
        modifiers_by_hand,
        battle_flow.has_claimed_combo(side, "natural_attribute"))

func grant_consumable(side, consumable_id: String, source: String = "效果") -> bool:
    if consumable_repository.get_consumable(consumable_id).is_empty():
        return false
    var granted: bool = side.grant_consumable(consumable_id)
    trigger_queue.add_history(
        "consumable_gain",
        "获得%s" % consumable_repository.get_consumable(consumable_id).get("name", consumable_id),
        source,
        "成功" if granted else "失败",
        "进入共享消耗品栏" if granted else "共享消耗品栏已满，不生成")
    if granted:
        state_changed.emit()
    return granted

func use_player_consumable(slot_index: int, card_ids: Array = []) -> Dictionary:
    if battle_state != "active":
        return {"success": false, "reason": "战斗已经结束"}
    if slot_index < 0 or slot_index >= player.consumable_ids.size():
        return {"success": false, "reason": "消耗品槽位无效"}
    var consumable_id: String = player.consumable_ids[slot_index]
    var definition := consumable_repository.get_consumable(consumable_id)
    if definition.is_empty():
        return {"success": false, "reason": "消耗品数据不存在"}
    var cards: Array = []
    for card_id_value in card_ids:
        var card = player.find_hand_card(str(card_id_value))
        if card == null or cards.has(card):
            return {"success": false, "reason": "目标包含不在当前手牌中的真气"}
        cards.append(card)
    var target_check := consumable_repository.validate_targets(consumable_id, cards)
    if not target_check["ok"]:
        return {"success": false, "reason": target_check["reason"]}
    var details: Array[String] = []
    var acquired_technique_id := ""
    for effect in definition.get("effects", []):
        var op: String = effect.get("op", "")
        match op:
            "gain_insight":
                var hand_id: String = effect.get("hand", "")
                var amount: int = int(effect.get("multiplier", 0))
                var total: int = player.add_insight(hand_id, amount)
                details.append("%s心得倍率 +%d（累计 +%d）" % [hand_id, amount, total])
                acquired_technique_id = _learn_random_technique(player, effect.get("pools", []))
                if acquired_technique_id != "":
                    details.append("获得功法：%s" % _technique_name(acquired_technique_id))
                else:
                    details.append("合格池暂无未获得功法")
            "apply_enhancement":
                var enhancement_id: String = effect.get("enhancement", "")
                for card in cards:
                    card.set_enhancement(enhancement_id)
                details.append("%d 张真气获得%s强化" % [cards.size(), _enhancement_name(enhancement_id)])
            "apply_random_finish":
                var finishes: Array = effect.get("finishes", [])
                if finishes.is_empty():
                    return {"success": false, "reason": "品相候选为空"}
                for card in cards:
                    var finish_id: String = str(finishes[rng.randi_range(0, finishes.size() - 1)])
                    card.set_finish(finish_id)
                    details.append("%s获得%s品相" % [card.display_name(), _finish_name(finish_id)])
            _:
                return {"success": false, "reason": "不支持的消耗品效果：%s" % op}
    player.consume_at(slot_index)
    trigger_queue.add_history(
        "consumable_use", definition.get("name", consumable_id), "纵切调试构筑台", "成功",
        "；".join(details))
    state_changed.emit()
    return {
        "success": true,
        "consumable_id": consumable_id,
        "cards": cards,
        "acquired_technique_id": acquired_technique_id,
        "detail": "；".join(details),
    }

func _learn_random_technique(side, pools: Array) -> String:
    var candidates: Array[String] = []
    for technique_id_value in repository.techniques.keys():
        var technique_id := str(technique_id_value)
        var technique: Dictionary = repository.get_technique(technique_id)
        if pools.has(technique.get("pool", "")) and not side.owned_technique_ids.has(technique_id):
            candidates.append(technique_id)
    candidates.sort()
    if candidates.is_empty():
        return ""
    var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
    side.learn_technique(chosen)
    return chosen

func _seed_owned_techniques(side, book) -> void:
    side.owned_technique_ids.clear()
    for hand_id in book.sequences:
        for technique_id_value in book.sequences[hand_id]:
            side.learn_technique(str(technique_id_value))

func _enhancement_name(enhancement_id: String) -> String:
    return {"bonus": "奖励牌", "multiplier": "倍率牌"}.get(enhancement_id, enhancement_id)

func _finish_name(finish_id: String) -> String:
    return {"foil": "箔面", "holographic": "镭射", "polychrome": "多彩"}.get(finish_id, finish_id)

func confirm_play(card_ids: Array) -> Dictionary:
    if battle_state != "active":
        return {"success": false, "reason": battle_state_detail if battle_state_detail != "" else "战斗已经结束"}
    if not battle_flow.can_act(player):
        return {"success": false, "reason": _action_unavailable_reason(player)}
    var proposal = player_action_controller.propose(
        card_ids,
        func(selected_ids: Array): return preview(selected_ids))
    if not proposal.accepted:
        return {"success": false, "reason": proposal.rejection_reason}
    if scripted_mode:
        return _confirm_synchronized_play(proposal)
    return _confirm_solo_player(proposal)

func _confirm_solo_player(proposal) -> Dictionary:
    if not battle_flow.can_act(player):
        return {"success": false, "reason": _action_unavailable_reason(player)}
    var action_preview: Dictionary = proposal.preview
    if not player.stage_cards(proposal.card_ids):
        return {"success": false, "reason": "真气无法进入待出区"}
    battle_flow.lock_intent(player, action_preview)
    battle_flow.consume_action(player)
    action_resolver.log_calculation(player, action_preview)
    var record: Dictionary = action_resolver.make_action_record(
        player, enemy, action_preview, sequence_book, 100, turn_number)
    action_resolver.resolve_action_records(
        [record],
        battle_flow.resolution_mode() == "synchronized")
    var player_commit: Dictionary = action_resolver.commit_staging_for(player)
    var played_cards: Array = player_commit["committed"]
    action_resolver.log_cards_leave(player, played_cards, player_commit["recycled"])
    action_resolver.finish_action_record(record)
    last_player_action_cards = played_cards
    last_enemy_action_cards.clear()
    last_played_hand = action_preview["hand"]["id"]
    if ActionPreviewServiceScript.is_same_attribute_action(played_cards) \
            and battle_flow.claim_combo(player, "natural_attribute"):
        gain_extra_actions_for(player, 1, "通用同属性连击")
    battle_flow.clear_intents()
    state_changed.emit()
    return {
        "success": true,
        "preview": action_preview,
        "technique_triggered": record["triggered"],
        "played_cards": played_cards,
        "actions_available": actions_available,
    }

func _confirm_synchronized_play(player_proposal) -> Dictionary:
    if not battle_flow.can_act(player):
        return {"success": false, "reason": _action_unavailable_reason(player)}
    var player_preview: Dictionary = player_proposal.preview
    var enemy_preview: Dictionary = {}
    var enemy_will_act := (
        battle_flow.can_act(enemy)
        and not locked_enemy_card_ids.is_empty())
    if enemy_will_act:
        enemy_preview = _preview_for_side(enemy, locked_enemy_card_ids, enemy_sequence_book)
        if not enemy_preview.get("valid", false):
            _set_scenario_error("对手锁定出牌失效：%s" % enemy_preview.get("reason", "未知错误"))
            return {"success": false, "reason": battle_state_detail}
    if not player.stage_cards(player_proposal.card_ids):
        return {"success": false, "reason": "我方真气无法进入待出区"}
    if enemy_will_act and not enemy.stage_cards(locked_enemy_card_ids):
        player.rollback_staging()
        battle_flow.clear_intents()
        _set_scenario_error("对手锁定真气无法进入待出区")
        return {"success": false, "reason": battle_state_detail}

    battle_flow.lock_intent(player, player_preview)
    if enemy_will_act:
        battle_flow.lock_intent(enemy, enemy_preview)
    var resolution_mode := battle_flow.resolution_mode()
    battle_flow.consume_action(player)
    if enemy_will_act:
        battle_flow.consume_action(enemy)
    last_preview = player_preview
    last_enemy_preview = enemy_preview
    trigger_queue.add_history(
        "reveal",
        "双方揭示出牌" if resolution_mode == "synchronized" else "%s单方出招" % player.name,
        "同步规则" if resolution_mode == "synchronized" else "行动调度",
        "成功",
        _reveal_detail(player_preview, enemy_preview))
    action_resolver.log_calculation(player, player_preview)
    var records: Array = [action_resolver.make_action_record(
        player, enemy, player_preview, sequence_book, 100, turn_number)]
    if enemy_will_act:
        action_resolver.log_calculation(enemy, enemy_preview, enemy_ai_enabled)
        records.append(action_resolver.make_action_record(
            enemy, player, enemy_preview, enemy_sequence_book, 200, turn_number))
    action_resolver.resolve_action_records(
        records,
        resolution_mode == "synchronized")

    var player_commit: Dictionary = action_resolver.commit_staging_for(player)
    var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy) if enemy_will_act else {"committed": [], "recycled": []}
    var player_cards: Array = player_commit["committed"]
    var enemy_cards: Array = enemy_commit["committed"]
    action_resolver.log_cards_leave(player, player_cards, player_commit["recycled"])
    if enemy_will_act:
        action_resolver.log_cards_leave(enemy, enemy_cards, enemy_commit["recycled"])
    for record in records:
        action_resolver.finish_action_record(record)
    last_player_action_cards = player_cards
    last_enemy_action_cards = enemy_cards
    last_played_hand = player_preview["hand"]["id"]

    if ActionPreviewServiceScript.is_same_attribute_action(player_cards) \
            and battle_flow.claim_combo(player, "natural_attribute"):
        gain_extra_actions_for(player, 1, "通用同属性连击")
    if enemy_will_act:
        enemy_action_index += 1
        if ActionPreviewServiceScript.is_same_attribute_action(enemy_cards) \
                and battle_flow.claim_combo(enemy, "natural_attribute"):
            gain_extra_actions_for(enemy, 1, "通用同属性连击")
    battle_flow.clear_intents()
    _update_battle_state()
    if battle_state == "active" and battle_flow.can_act(enemy):
        _lock_enemy_action()
    else:
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
    if battle_state == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy):
        _resolve_enemy_only_actions()
    state_changed.emit()
    return {
        "success": true,
        "preview": player_preview,
        "enemy_preview": enemy_preview,
        "technique_triggered": records[0]["triggered"],
        "enemy_technique_triggered": records[1]["triggered"] if records.size() > 1 else false,
        "played_cards": player_cards,
        "enemy_played_cards": enemy_cards,
        "actions_available": actions_available,
        "enemy_actions_available": enemy_actions_available,
        "battle_state": battle_state,
    }

func combat_order_labels(side, technique_name: String = "当前功法") -> Array[String]:
    return action_resolver.combat_order_labels(side, technique_name)

func move_player_technique_slot(direction: int) -> Dictionary:
    if direction == 0:
        return {"success": false, "reason": "功法位移动方向无效"}
    var previous := player.technique_slot_index
    var next := clampi(
        previous + signi(direction),
        0,
        player.equipped_inner_skill_ids.size())
    if next == previous:
        return {"success": false, "reason": "功法位已经位于该方向边界"}
    player.technique_slot_index = next
    trigger_queue.add_history(
        "loadout_order",
        "调整功法结算位",
        "玩家命令",
        "成功",
        "%d → %d" % [previous, next])
    state_changed.emit()
    return {"success": true, "previous": previous, "current": next}

func _reveal_detail(player_preview: Dictionary, enemy_preview: Dictionary) -> String:
    var player_name: String = player_preview["hand"]["name"]
    if enemy_preview.is_empty():
        return "我方 %s｜对手本击不出牌" % player_name
    if enemy_ai_enabled:
        return "我方 %s｜对手按公开计划出招" % player_name
    return "我方 %s｜对手 %s" % [player_name, enemy_preview["hand"]["name"]]

func _lock_enemy_action() -> void:
    enemy_plan.clear()
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    if not battle_flow.can_act(enemy):
        trigger_queue.add_history(
            "enemy_lock",
            "对手本击无法行动",
            "行动调度",
            "跳过",
            _action_unavailable_reason(enemy))
        return
    if enemy_ai_enabled:
        var observation = BattleObservationScript.new().capture(
            enemy,
            player,
            enemy_sequence_book,
            battle_flow)
        locked_enemy_action_proposal = enemy_action_controller.propose_utility(
            observation,
            func(card_ids: Array): return _preview_for_side(enemy, card_ids, enemy_sequence_book),
            enemy_ai_policy)
    else:
        var requested_definition_ids := scenario.enemy_action_ids(
            turn_number, enemy_action_index)
        locked_enemy_action_proposal = enemy_action_controller.propose_scripted(
            requested_definition_ids,
            func(definition_ids: Array): return enemy.resolve_hand_definition_ids(definition_ids),
            func(card_ids: Array): return _preview_for_side(enemy, card_ids, enemy_sequence_book))
        if not locked_enemy_action_proposal.accepted \
                and not requested_definition_ids.is_empty():
            _set_scenario_error(
                "第 %d 回合对手行动生成失败：%s｜%s" % [
                    turn_number,
                    locked_enemy_action_proposal.rejection_reason,
                    str(requested_definition_ids)])
            return
    if locked_enemy_action_proposal != null \
            and locked_enemy_action_proposal.accepted:
        locked_enemy_card_ids = locked_enemy_action_proposal.card_ids.duplicate()
        if enemy_ai_enabled:
            enemy_plan = _public_enemy_plan(
                locked_enemy_action_proposal.preview.get("intent", {}))
            game_log.record_system(
                "debug",
                "enemy_decision",
                "敌方行动提案已生成",
                "控制器 %s｜优先级 %d｜评分 %.2f｜%d 张真气" % [
                    locked_enemy_action_proposal.controller_id,
                    int(locked_enemy_action_proposal.diagnostics.get("priority", 0)),
                    locked_enemy_action_proposal.score,
                    locked_enemy_card_ids.size()],
                {
                    "controller_id": locked_enemy_action_proposal.controller_id,
                    "priority": int(locked_enemy_action_proposal.diagnostics.get("priority", 0)),
                    "score": locked_enemy_action_proposal.score,
                    "score_components": locked_enemy_action_proposal.diagnostics.get(
                        "score_components", {}).duplicate(true),
                    "card_count": locked_enemy_card_ids.size(),
                })
    if locked_enemy_card_ids.is_empty():
        battle_flow.forfeit_remaining(enemy, "没有合法出牌方案")
        trigger_queue.add_history("enemy_lock", "对手本击无法行动", "纵切对手", "成功", "没有可用真气或脚本动作")
        return
    for card_id in locked_enemy_card_ids:
        if enemy.find_hand_card(str(card_id)) == null:
            _set_scenario_error("第 %d 回合对手脚本要求的真气不在手牌：%s" % [turn_number, card_id])
            return
    var detail := "%d 张背面真气" % locked_enemy_card_ids.size()
    if enemy_ai_enabled:
        detail = "预计伤害 %d｜预计防御 %d%s" % [
            enemy_plan.get("damage", 0), enemy_plan.get("defense", 0),
            "｜将获得连击" if enemy_plan.get("combo", false) else ""]
    trigger_queue.add_history("enemy_lock", "对手已确定本击计划", "纵切对手", "成功", detail)

func _public_enemy_plan(intent: Dictionary) -> Dictionary:
    return {
        "damage": maxi(0, int(intent.get("damage", 0))),
        "defense": maxi(0, int(intent.get("defense", 0))),
        "segments": maxi(0, int(intent.get("segments", 0))),
        "combo": bool(intent.get("combo", false)),
    }

func _resolve_enemy_only_actions() -> void:
    while battle_state == "active" \
            and not battle_flow.can_act(player) \
            and battle_flow.can_act(enemy):
        if locked_enemy_card_ids.is_empty():
            _lock_enemy_action()
        if locked_enemy_card_ids.is_empty():
            break
        var action_preview := _preview_for_side(enemy, locked_enemy_card_ids, enemy_sequence_book)
        if not action_preview.get("valid", false) or not enemy.stage_cards(locked_enemy_card_ids):
            _set_scenario_error("对手连击计划无法执行")
            return
        battle_flow.lock_intent(enemy, action_preview)
        battle_flow.consume_action(enemy)
        last_preview.clear()
        last_enemy_preview = action_preview
        trigger_queue.add_history("enemy_combo_reveal", "对手发动单方连击", "连击", "成功", "计划已转为实际出招")
        action_resolver.log_calculation(enemy, action_preview, enemy_ai_enabled)
        var record: Dictionary = action_resolver.make_action_record(
            enemy, player, action_preview, enemy_sequence_book, 200, turn_number)
        action_resolver.resolve_action_records(
            [record],
            battle_flow.resolution_mode() == "synchronized")
        var enemy_commit: Dictionary = action_resolver.commit_staging_for(enemy)
        var enemy_cards: Array = enemy_commit["committed"]
        action_resolver.log_cards_leave(enemy, enemy_cards, enemy_commit["recycled"])
        action_resolver.finish_action_record(record)
        last_player_action_cards.clear()
        last_enemy_action_cards = enemy_cards
        enemy_action_index += 1
        if ActionPreviewServiceScript.is_same_attribute_action(enemy_cards) \
                and battle_flow.claim_combo(enemy, "natural_attribute"):
            gain_extra_actions_for(enemy, 1, "通用同属性连击")
        battle_flow.clear_intents()
        _update_battle_state()
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
        if battle_state == "active" and battle_flow.can_act(enemy):
            _lock_enemy_action()

func gain_extra_actions(amount: int, source: String) -> void:
    gain_extra_actions_for(player, amount, source)

func gain_extra_actions_for(side, amount: int, source: String) -> void:
    var gained := battle_flow.grant_actions(side, amount)
    trigger_queue.add_history("action_end", "%s额外出牌机会" % side.name, source, "成功", "+%d（连击不自动补牌）" % gained)

func disable_actor_current_round(side, reason: String) -> void:
    battle_flow.disable_current_round(side, reason)
    if side == enemy:
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
    trigger_queue.add_history(
        "action_control",
        "%s本回合无法行动" % side.name,
        "行动调度",
        "成功",
        reason)
    state_changed.emit()

func disable_actor_next_rounds(side, reason: String, round_count: int = 1) -> void:
    battle_flow.disable_next_rounds(side, reason, round_count)
    trigger_queue.add_history(
        "action_control_schedule",
        "%s后续行动受限" % side.name,
        "行动调度",
        "成功",
        "%s｜%d 回合" % [reason, maxi(0, round_count)])

func forfeit_actor_actions(side, reason: String) -> void:
    battle_flow.forfeit_remaining(side, reason)
    if side == enemy:
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        enemy_plan.clear()
    state_changed.emit()

func actor_action_state(side) -> Dictionary:
    return battle_flow.snapshot_for(side)

func _action_unavailable_reason(side) -> String:
    var state: Dictionary = battle_flow.snapshot_for(side)
    var disabled_reasons: Array = state.get("disabled_reasons", [])
    if not disabled_reasons.is_empty():
        return "当前无法行动：%s" % "、".join(disabled_reasons)
    var forfeit_reason := str(state.get("last_forfeit_reason", ""))
    if forfeit_reason != "":
        return forfeit_reason
    return "当前没有可用出牌机会"

func deal_damage(actor, target, base_amount: int, source_kind: String, true_damage: bool = false) -> Dictionary:
    var result: Dictionary = damage_resolver.resolve(
        actor,
        target,
        base_amount,
        source_kind,
        true_damage,
        status_system)
    if not bool(result["buffered"]):
        _log_damage(actor, target, int(result["final_amount"]), source_kind, result)
    status_system.record_attack_segment(actor, source_kind)
    return result

func begin_synchronized_damage(records: Array) -> void:
    var actors: Array = []
    for record in records:
        actors.append(record["actor"])
    damage_resolver.begin_synchronized(actors)

func flush_synchronized_damage() -> void:
    for resolution in damage_resolver.flush_synchronized():
        _log_damage(
            resolution["actor"],
            resolution["target"],
            int(resolution["amount"]),
            resolution["source_kind"],
            resolution["result"])

func damage_actor_can_continue(side) -> bool:
    return damage_resolver.actor_can_continue(side)

func damage_target_can_receive(side) -> bool:
    return damage_resolver.target_can_receive(side)

func _log_damage(actor, target, final_amount: int, source_kind: String, result: Dictionary) -> void:
    trigger_queue.add_history(
        "damage_segment", "%s → %s" % [actor.name, target.name], source_kind, "成功",
        "%d 点：防御-%d / 生命-%d" % [final_amount, result["defense_lost"], result["life_lost"]])

func register_attack_counter_delay(
        label: String,
        turn_ends: int,
        snapshot_power: int,
        damage_per_segment: int,
        actor,
        target) -> void:
    status_system.register_attack_counter_delay(
        label,
        turn_ends,
        snapshot_power,
        damage_per_segment,
        actor,
        target)
    trigger_queue.add_history(
        "delayed_register",
        label,
        "%s延迟功法" % actor.name,
        "成功",
        "记录建立时 P=%d" % snapshot_power)

func _update_battle_state() -> void:
    if player.life <= 0 and enemy.life <= 0:
        battle_state = "unresolved_draw"
        battle_state_detail = "双方同时倒下：胜负规则尚未确认"
    elif enemy.life <= 0:
        battle_state = "player_victory"
        battle_state_detail = "试炼胜利"
    elif player.life <= 0:
        battle_state = "player_defeat"
        battle_state_detail = "玩家生命归零"
    elif scripted_mode and player.hand.is_empty() and player.draw_pile.is_empty() and player.staging.is_empty():
        battle_state = "player_defeat"
        battle_state_detail = "玩家没有可用真气且敌人尚未倒下"
    if battle_state != "active":
        if not battle_cleanup_completed:
            timing_system.emit_timing(BattleTimingSystemScript.BATTLE_END, {
                "round_number": turn_number,
                "actors": [player, enemy],
                "metadata": {
                    "battle_state": battle_state,
                    "battle_state_detail": battle_state_detail,
                },
            })
            battle_cleanup_completed = true
        actions_available = 0
        enemy_actions_available = 0
        locked_enemy_card_ids.clear()
        locked_enemy_action_proposal = null
        trigger_queue.add_history("battle_end", battle_state_detail, "战斗结果", "结算")

func _on_flow_battle_end_timing(_event) -> Dictionary:
    var cleared_power_modifiers := power_modifiers.size()
    var cleared_round_actors := current_round_actors.size()
    power_modifiers.clear()
    current_round_actors.clear()
    return {
        "success": true,
        "detail": "清理 %d 项功法修正与 %d 个回合行动方引用" % [
            cleared_power_modifiers,
            cleared_round_actors],
    }

func _set_scenario_error(detail: String) -> void:
    battle_state = "scenario_error"
    battle_state_detail = detail
    actions_available = 0
    enemy_actions_available = 0
    locked_enemy_card_ids.clear()
    locked_enemy_action_proposal = null
    game_log.record_system("error", "scenario_runtime", "脚本场景错误", detail)
    trigger_queue.add_history("scenario_error", "脚本场景错误", "脚本场景", "失败", detail)
    state_changed.emit()

func _technique_name(technique_id: String) -> String:
    return repository.get_technique(technique_id).get("name", "空序列")
