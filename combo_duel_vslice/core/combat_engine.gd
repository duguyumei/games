class_name ComboCombatEngine
extends RefCounted

signal state_changed

const DeckFactoryScript = preload("res://core/deck_factory.gd")
const HandEvaluatorScript = preload("res://core/hand_evaluator.gd")
const PowerCalculatorScript = preload("res://core/power_calculator.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const SequenceBookScript = preload("res://core/sequence_book.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const ScriptedScenarioScript = preload("res://core/scripted_battle_scenario.gd")
const EnemyCombatAIScript = preload("res://core/enemy_combat_ai.gd")

var rng := RandomNumberGenerator.new()
var repository := TechniqueRepositoryScript.new()
var sequence_book := SequenceBookScript.new()
var enemy_sequence_book := SequenceBookScript.new()
var trigger_queue := TriggerQueueScript.new()
var effect_executor
var enemy_ai
var player := BattleSideScript.new("玩家")
var enemy := BattleSideScript.new("敌人")
var scenario := ScriptedScenarioScript.new()

var turn_number: int = 0
var actions_available: int = 0
var enemy_actions_available: int = 0
var natural_combo_used: bool = false
var enemy_natural_combo_used: bool = false
var enemy_action_index: int = 0
var locked_enemy_card_ids: Array = []
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

var _damage_buffer_active: bool = false
var _damage_buffer: Array = []
var _damage_shadows: Dictionary = {}
var _damage_actor_start_alive: Dictionary = {}
var _recycle_after_play: Dictionary = {}

func _init() -> void:
    repository.load_from_file()
    sequence_book.load_from_file()
    enemy_sequence_book.load_from_file()
    effect_executor = EffectExecutorScript.new(rng)
    enemy_ai = EnemyCombatAIScript.new(rng)

func setup(seed_value: int = 2308, shuffle_cards: bool = true) -> void:
    rng.seed = seed_value
    player.reset(DeckFactoryScript.create_standard_deck(), rng, shuffle_cards)
    enemy.reset(DeckFactoryScript.create_standard_deck(), rng, shuffle_cards)
    sequence_book.reset()
    enemy_sequence_book.reset()
    trigger_queue.clear()
    delayed_effects.clear()
    power_modifiers.clear()
    last_preview.clear()
    last_enemy_preview.clear()
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()
    last_played_hand = ""
    turn_number = 0
    actions_available = 0
    enemy_actions_available = 0
    natural_combo_used = false
    enemy_natural_combo_used = false
    enemy_action_index = 0
    locked_enemy_card_ids.clear()
    scripted_mode = false
    enemy_ai_enabled = false
    enemy_ai_policy.clear()
    enemy_plan.clear()
    round_ended = false
    battle_state = "active"
    battle_state_detail = ""
    _clear_damage_buffer()
    _recycle_after_play.clear()
    state_changed.emit()

func setup_scripted_battle(
        seed_value: int = 2308,
        scenario_path: String = ScriptedScenarioScript.DEFAULT_PATH,
        use_enemy_ai: bool = false) -> bool:
    setup(seed_value, true)
    if not scenario.load_from_file(scenario_path):
        battle_state = "scenario_error"
        battle_state_detail = "脚本化战斗场景无法载入"
        state_changed.emit()
        return false
    scripted_mode = true
    enemy_ai_enabled = use_enemy_ai
    enemy_ai_policy = scenario.enemy_ai_policy()
    enemy.name = scenario.scenario_name()
    var enemy_definition := scenario.enemy_definition()
    enemy.max_life = int(enemy_definition.get("life", 100))
    enemy.life = enemy.max_life
    enemy.draw_pile = scenario.arrange_enemy_deck(DeckFactoryScript.create_standard_deck())
    enemy.hand.clear()
    enemy.staging.clear()
    enemy.discard_pile.clear()
    var enemy_sequences := scenario.enemy_sequences()
    if not enemy_sequences.is_empty():
        enemy_sequence_book.configure(enemy_sequences)
    trigger_queue.add_history(
        "battle_setup", enemy.name, "纵切场景", "成功",
        "调试 AI 已载入；不代表正式敌方策略" if enemy_ai_enabled else "固定脚本场景已载入")
    state_changed.emit()
    return true

func start_player_turn() -> Array:
    if battle_state != "active":
        return []
    turn_number += 1
    natural_combo_used = false
    enemy_natural_combo_used = false
    enemy_action_index = 0
    round_ended = false
    last_preview.clear()
    last_enemy_preview.clear()
    last_player_action_cards.clear()
    last_enemy_action_cards.clear()
    enemy_plan.clear()
    actions_available = 1
    enemy_actions_available = 1 if scripted_mode else 0
    var drawn := player.draw_to_limit()
    var enemy_drawn: Array = enemy.draw_to_limit() if scripted_mode else []
    trigger_queue.add_history(
        "round_start" if scripted_mode else "player_turn_start",
        "双方正常补牌" if scripted_mode else "正常补牌",
        "规则",
        "成功",
        "我方抽 %d 张｜对手抽 %d 张" % [drawn.size(), enemy_drawn.size()] if scripted_mode else "补至上限：抽 %d 张" % drawn.size())
    if scripted_mode:
        _lock_enemy_action()
    _update_battle_state()
    state_changed.emit()
    return drawn

func end_player_turn() -> void:
    if round_ended and scripted_mode:
        return
    actions_available = 0
    round_ended = true
    _resolve_player_turn_end_delays()
    trigger_queue.add_history("player_turn_end", "玩家回合结束", "规则", "成功")
    _update_battle_state()
    state_changed.emit()

func preview(card_ids: Array) -> Dictionary:
    return _preview_for_side(player, card_ids, sequence_book, power_modifiers)

func _preview_for_side(side, card_ids: Array, book, modifiers_by_hand: Dictionary = {}) -> Dictionary:
    if card_ids.size() < 1 or card_ids.size() > 5:
        return {"valid": false, "reason": "每次必须选择 1～5 张真气"}
    var cards: Array = []
    for card_id in card_ids:
        var card = side.find_hand_card(str(card_id))
        if card == null or cards.has(card):
            return {"valid": false, "reason": "选择包含不在手牌中的真气"}
        cards.append(card)
    var hand_result := HandEvaluatorScript.evaluate(cards)
    if hand_result.is_empty():
        return {"valid": false, "reason": "无法识别牌型"}
    var modifiers: Dictionary = modifiers_by_hand.get(hand_result["id"], {})
    var values := PowerCalculatorScript.calculate(hand_result, modifiers)
    var technique_id: String = book.current_id(hand_result["id"])
    var technique := repository.get_technique(technique_id)
    var condition := {"ok": true, "reason": "空序列"}
    if not technique.is_empty():
        condition = repository.conditions_met(technique, hand_result)
    var intent := {"damage": 0, "defense": 0, "segments": 0, "technique_combo": false}
    if not technique.is_empty() and condition["ok"]:
        intent = effect_executor.summarize_intent(
            technique.get("effects", []),
            {"hand_result": hand_result, "power": values["technique_value"], "captures": {}},
            int(side.stacks.get("momentum", 0)))
    var natural_combo_available := (
        _is_same_attribute_action(cards)
        and not (natural_combo_used if side == player else enemy_natural_combo_used))
    intent["natural_combo"] = natural_combo_available
    intent["combo"] = natural_combo_available or bool(intent.get("technique_combo", false))
    return {
        "valid": true,
        "cards": cards,
        "hand": hand_result,
        "values": values,
        "technique_id": technique_id,
        "technique": technique,
        "condition": condition,
        "intent": intent,
        "next_technique_id": book.next_id(hand_result["id"]),
        "next_technique": repository.get_technique(book.next_id(hand_result["id"])),
    }

func confirm_play(card_ids: Array) -> Dictionary:
    if battle_state != "active":
        return {"success": false, "reason": battle_state_detail if battle_state_detail != "" else "战斗已经结束"}
    if scripted_mode:
        return _confirm_synchronized_play(card_ids)
    return _confirm_solo_player(card_ids)

func _confirm_solo_player(card_ids: Array) -> Dictionary:
    if actions_available <= 0:
        return {"success": false, "reason": "当前没有可用出牌机会"}
    var action_preview := preview(card_ids)
    if not action_preview.get("valid", false):
        return {"success": false, "reason": action_preview.get("reason", "选择无效")}
    if not player.stage_cards(card_ids):
        return {"success": false, "reason": "真气无法进入待出区"}
    actions_available -= 1
    _log_calculation(player, action_preview)
    var record := _make_action_record(player, enemy, action_preview, sequence_book, 100)
    _resolve_action_records([record], false)
    var player_commit := _commit_staging_for(player)
    var played_cards: Array = player_commit["committed"]
    _log_cards_leave(player, played_cards, player_commit["recycled"])
    _finish_action_record(record)
    last_player_action_cards = played_cards
    last_enemy_action_cards.clear()
    last_played_hand = action_preview["hand"]["id"]
    if _is_same_attribute_action(played_cards) and not natural_combo_used:
        natural_combo_used = true
        gain_extra_actions_for(player, 1, "通用同属性连击")
    state_changed.emit()
    return {
        "success": true,
        "preview": action_preview,
        "technique_triggered": record["triggered"],
        "played_cards": played_cards,
        "actions_available": actions_available,
    }

func _confirm_synchronized_play(card_ids: Array) -> Dictionary:
    if actions_available <= 0:
        return {"success": false, "reason": "当前没有可用出牌机会"}
    var player_preview := preview(card_ids)
    if not player_preview.get("valid", false):
        return {"success": false, "reason": player_preview.get("reason", "选择无效")}
    var enemy_preview: Dictionary = {}
    var enemy_will_act := enemy_actions_available > 0 and not locked_enemy_card_ids.is_empty()
    if enemy_will_act:
        enemy_preview = _preview_for_side(enemy, locked_enemy_card_ids, enemy_sequence_book)
        if not enemy_preview.get("valid", false):
            _set_scenario_error("对手锁定出牌失效：%s" % enemy_preview.get("reason", "未知错误"))
            return {"success": false, "reason": battle_state_detail}
    if not player.stage_cards(card_ids):
        return {"success": false, "reason": "我方真气无法进入待出区"}
    if enemy_will_act and not enemy.stage_cards(locked_enemy_card_ids):
        player.hand.append_array(player.staging)
        player.staging.clear()
        _set_scenario_error("对手锁定真气无法进入待出区")
        return {"success": false, "reason": battle_state_detail}

    actions_available -= 1
    if enemy_will_act:
        enemy_actions_available -= 1
    last_preview = player_preview
    last_enemy_preview = enemy_preview
    trigger_queue.add_history("reveal", "双方揭示出牌", "同步规则", "成功", _reveal_detail(player_preview, enemy_preview))
    _log_calculation(player, player_preview)
    var records: Array = [_make_action_record(player, enemy, player_preview, sequence_book, 100)]
    if enemy_will_act:
        _log_calculation(enemy, enemy_preview)
        records.append(_make_action_record(enemy, player, enemy_preview, enemy_sequence_book, 200))
    _resolve_action_records(records, true)

    var player_commit := _commit_staging_for(player)
    var enemy_commit: Dictionary = _commit_staging_for(enemy) if enemy_will_act else {"committed": [], "recycled": []}
    var player_cards: Array = player_commit["committed"]
    var enemy_cards: Array = enemy_commit["committed"]
    _log_cards_leave(player, player_cards, player_commit["recycled"])
    if enemy_will_act:
        _log_cards_leave(enemy, enemy_cards, enemy_commit["recycled"])
    for record in records:
        _finish_action_record(record)
    last_player_action_cards = player_cards
    last_enemy_action_cards = enemy_cards
    last_played_hand = player_preview["hand"]["id"]

    if _is_same_attribute_action(player_cards) and not natural_combo_used:
        natural_combo_used = true
        gain_extra_actions_for(player, 1, "通用同属性连击")
    if enemy_will_act:
        enemy_action_index += 1
        if _is_same_attribute_action(enemy_cards) and not enemy_natural_combo_used:
            enemy_natural_combo_used = true
            gain_extra_actions_for(enemy, 1, "通用同属性连击")
    _update_battle_state()
    if battle_state == "active" and enemy_actions_available > 0:
        _lock_enemy_action()
    else:
        locked_enemy_card_ids.clear()
        enemy_plan.clear()
    if battle_state == "active" and actions_available <= 0 and enemy_actions_available > 0:
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

func _make_action_record(actor, target, action_preview: Dictionary, book, order: int) -> Dictionary:
    return {
        "actor": actor,
        "target": target,
        "preview": action_preview,
        "book": book,
        "order": order,
        "triggered": false,
        "failed": false,
        "token": "%s-%d-%d" % [actor.name, turn_number, order],
    }

func _resolve_action_records(records: Array, synchronized: bool) -> void:
    for record in records:
        var action_preview: Dictionary = record["preview"]
        var technique: Dictionary = action_preview["technique"]
        if technique.is_empty():
            continue
        if not action_preview["condition"]["ok"]:
            trigger_queue.add_history(
                "on_play_resolve", technique["name"], "%s功法" % record["actor"].name,
                "条件失败", action_preview["condition"]["reason"])
            continue
        record["triggered"] = true

    for phase in ["prepare", "damage", "zones"]:
        var timing: String = ("sync_" if synchronized else "solo_") + phase
        var phase_has_entries := false
        for record in records:
            if not record["triggered"]:
                continue
            var technique: Dictionary = record["preview"]["technique"]
            var effects := _effects_for_phase(technique.get("effects", []), phase)
            if effects.is_empty():
                continue
            phase_has_entries = true
            var context := {
                "engine": self,
                "actor": record["actor"],
                "target": record["target"],
                "hand_result": record["preview"]["hand"],
                "power": record["preview"]["values"]["technique_value"],
                "technique_id": technique["id"],
                "technique_name": technique["name"],
                "action_token": record["token"],
                "captures": record.get("captures", {}),
            }
            record["captures"] = context["captures"]
            trigger_queue.enqueue(
                timing, technique["name"], "%s功法" % record["actor"].name,
                record["order"], effects, context)
        if not phase_has_entries and phase != "damage":
            continue
        if phase == "damage" and synchronized:
            _begin_damage_buffer(records)
        var results: Array = trigger_queue.process_timing(timing, effect_executor) if phase_has_entries else []
        for resolution in results:
            if resolution["result"].get("success", false):
                continue
            var token: String = resolution["entry"]["context"].get("action_token", "")
            for record in records:
                if record["token"] == token:
                    record["failed"] = true
                    record["triggered"] = false
        if phase == "damage":
            _resolve_played_card_statuses(records)
        if phase == "damage" and synchronized:
            _flush_damage_buffer()

func _effects_for_phase(effects: Array, phase: String) -> Array:
    var result: Array = []
    var prepare_ops := ["defense", "add_stack", "add_target_stack", "register_attack_counter_delay"]
    var damage_ops := ["damage", "multi_damage"]
    for effect in effects:
        var explicit_phase: String = effect.get("phase", "")
        if explicit_phase != "":
            if explicit_phase == phase:
                result.append(effect)
            continue
        var op: String = effect.get("op", "")
        if phase == "prepare" and op in prepare_ops:
            result.append(effect)
        elif phase == "damage" and op in damage_ops:
            result.append(effect)
        elif phase == "zones" and not op in prepare_ops and not op in damage_ops:
            result.append(effect)
    return result

func _finish_action_record(record: Dictionary) -> void:
    var action_preview: Dictionary = record["preview"]
    var technique: Dictionary = action_preview["technique"]
    var hand_id: String = action_preview["hand"]["id"]
    if record["triggered"]:
        record["book"].advance(hand_id)
        trigger_queue.add_history(
            "group_end", "功法序列推进", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]],
            "成功", "下一门：%s" % _technique_name(record["book"].current_id(hand_id)))
    elif not technique.is_empty():
        trigger_queue.add_history(
            "group_end", "功法序列保持", "%s·%s" % [record["actor"].name, action_preview["hand"]["name"]], "未推进")

func _log_calculation(side, action_preview: Dictionary) -> void:
    var hand_result: Dictionary = action_preview["hand"]
    var values: Dictionary = action_preview["values"]
    if side == enemy and enemy_ai_enabled:
        trigger_queue.add_history(
            "calculate", "%s·隐藏出招" % side.name, "牌型", "成功",
            "敌方牌型、牌张与功法值不公开")
        return
    trigger_queue.add_history(
        "calculate", "%s·%s" % [side.name, hand_result["name"]], "牌型", "成功",
        "基础值 %d｜牌型基准值 %d｜功法值 %d（不自动造成伤害）" % [
            values["base_value"], values["baseline_value"], values["technique_value"]])

func _log_cards_leave(side, cards: Array, recycled: Array = []) -> void:
    trigger_queue.add_history(
        "cards_leave_play", "%s打出真气离开待出区" % side.name, "规则", "成功",
        "%d 张；其中 %d 张因蛊印洗回牌库；这不视为弃掉" % [cards.size(), recycled.size()])

func _resolve_played_card_statuses(records: Array) -> void:
    for record in records:
        var holder = record["actor"]
        for card in holder.staging:
            if not card.has_combat_status("outplay", "lethal_poison"):
                continue
            card.remove_combat_status("outplay")
            var poison_damage := maxi(0, card.qi_value)
            deal_damage(holder, holder, poison_damage, "烈毒")
            trigger_queue.add_history(
                "card_status_damage", "%s·%s触发烈毒" % [holder.name, card.display_name()],
                "真气异状", "结算", "%d 点伤害" % poison_damage)
            if int(holder.stacks.get("gu_mark", 0)) > 0:
                holder.stacks["gu_mark"] = int(holder.stacks["gu_mark"]) - 1
                var side_id: int = holder.get_instance_id()
                if not _recycle_after_play.has(side_id):
                    _recycle_after_play[side_id] = {}
                _recycle_after_play[side_id][card.id] = {
                    "slot": "outplay",
                    "status": "lethal_poison",
                }
                trigger_queue.add_history(
                    "gu_mark_consume", "%s消耗 1 层蛊印" % holder.name,
                    "蛊印", "成功", "%s续上烈毒，结算后洗回牌库" % card.display_name())

func _commit_staging_for(side) -> Dictionary:
    var side_recycles: Dictionary = _recycle_after_play.get(side.get_instance_id(), {})
    var result: Dictionary = side.commit_staging_with_recycles(side_recycles, rng)
    _recycle_after_play.erase(side.get_instance_id())
    return result

func _reveal_detail(player_preview: Dictionary, enemy_preview: Dictionary) -> String:
    var player_name: String = player_preview["hand"]["name"]
    if enemy_preview.is_empty():
        return "我方 %s｜对手本击不出牌" % player_name
    if enemy_ai_enabled:
        return "我方 %s｜对手按公开计划出招" % player_name
    return "我方 %s｜对手 %s" % [player_name, enemy_preview["hand"]["name"]]

func _lock_enemy_action() -> void:
    enemy_plan.clear()
    if enemy_ai_enabled:
        var choice: Dictionary = enemy_ai.choose_action(
            enemy.hand,
            func(card_ids: Array): return _preview_for_side(enemy, card_ids, enemy_sequence_book),
            enemy_ai_policy)
        locked_enemy_card_ids = choice.get("card_ids", [])
        if not choice.is_empty():
            enemy_plan = _public_enemy_plan(choice["preview"].get("intent", {}))
    else:
        locked_enemy_card_ids = scenario.enemy_action_ids(turn_number, enemy_action_index)
    if locked_enemy_card_ids.is_empty():
        enemy_actions_available = 0
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
    while battle_state == "active" and actions_available <= 0 and enemy_actions_available > 0:
        if locked_enemy_card_ids.is_empty():
            _lock_enemy_action()
        if locked_enemy_card_ids.is_empty():
            break
        var action_preview := _preview_for_side(enemy, locked_enemy_card_ids, enemy_sequence_book)
        if not action_preview.get("valid", false) or not enemy.stage_cards(locked_enemy_card_ids):
            _set_scenario_error("对手连击计划无法执行")
            return
        enemy_actions_available -= 1
        last_preview.clear()
        last_enemy_preview = action_preview
        trigger_queue.add_history("enemy_combo_reveal", "对手发动单方连击", "连击", "成功", "计划已转为实际出招")
        _log_calculation(enemy, action_preview)
        var record := _make_action_record(enemy, player, action_preview, enemy_sequence_book, 200)
        _resolve_action_records([record], false)
        var enemy_commit := _commit_staging_for(enemy)
        var enemy_cards: Array = enemy_commit["committed"]
        _log_cards_leave(enemy, enemy_cards, enemy_commit["recycled"])
        _finish_action_record(record)
        last_player_action_cards.clear()
        last_enemy_action_cards = enemy_cards
        enemy_action_index += 1
        if _is_same_attribute_action(enemy_cards) and not enemy_natural_combo_used:
            enemy_natural_combo_used = true
            gain_extra_actions_for(enemy, 1, "通用同属性连击")
        _update_battle_state()
        locked_enemy_card_ids.clear()
        enemy_plan.clear()
        if battle_state == "active" and enemy_actions_available > 0:
            _lock_enemy_action()

func gain_extra_actions(amount: int, source: String) -> void:
    gain_extra_actions_for(player, amount, source)

func gain_extra_actions_for(side, amount: int, source: String) -> void:
    var gained := maxi(0, amount)
    if side == player:
        actions_available += gained
    elif side == enemy:
        enemy_actions_available += gained
    trigger_queue.add_history("action_end", "%s额外出牌机会" % side.name, source, "成功", "+%d（连击不自动补牌）" % gained)

func deal_damage(actor, target, base_amount: int, source_kind: String, true_damage: bool = false) -> Dictionary:
    var final_amount := maxi(0, base_amount)
    if not true_damage and source_kind in ["technique", "chase", "counter", "delayed_chase"]:
        final_amount = int(floor(final_amount * (1.0 + int(actor.stacks.get("momentum", 0)) / 100.0)))
    var result: Dictionary
    if _damage_buffer_active:
        result = _buffer_damage(actor, target, final_amount, source_kind, true_damage)
    else:
        result = target.receive_damage(final_amount, true_damage)
        _log_damage(actor, target, final_amount, source_kind, result)
    if source_kind in ["technique", "chase", "counter"]:
        for delayed in delayed_effects:
            if delayed["actor"] == actor:
                delayed["attack_count"] = int(delayed["attack_count"]) + 1
    return result

func _begin_damage_buffer(records: Array) -> void:
    _clear_damage_buffer()
    _damage_buffer_active = true
    for record in records:
        var actor = record["actor"]
        _damage_actor_start_alive[actor.get_instance_id()] = actor.life > 0

func _buffer_damage(actor, target, amount: int, source_kind: String, true_damage: bool) -> Dictionary:
    var target_id: int = target.get_instance_id()
    if not _damage_shadows.has(target_id):
        _damage_shadows[target_id] = {"life": target.life, "defense": target.defense}
    var shadow: Dictionary = _damage_shadows[target_id]
    var result := _preview_receive_damage(shadow, amount, true_damage)
    _damage_shadows[target_id] = shadow
    _damage_buffer.append({
        "actor": actor,
        "target": target,
        "amount": amount,
        "source_kind": source_kind,
        "true_damage": true_damage,
        "preview": result,
    })
    return result

func _preview_receive_damage(shadow: Dictionary, amount: int, true_damage: bool) -> Dictionary:
    var incoming := maxi(0, amount)
    var defense_lost := 0
    var life_lost := 0
    if true_damage:
        life_lost = mini(int(shadow["life"]), incoming)
        shadow["life"] = int(shadow["life"]) - life_lost
    else:
        defense_lost = mini(int(shadow["defense"]), incoming)
        shadow["defense"] = int(shadow["defense"]) - defense_lost
        var remainder := incoming - defense_lost
        life_lost = mini(int(shadow["life"]), remainder)
        shadow["life"] = int(shadow["life"]) - life_lost
    return {
        "requested": incoming,
        "defense_lost": defense_lost,
        "life_lost": life_lost,
        "true_damage": true_damage,
    }

func _flush_damage_buffer() -> void:
    var buffered := _damage_buffer.duplicate()
    _damage_buffer_active = false
    for intent in buffered:
        var actual: Dictionary = intent["target"].receive_damage(intent["amount"], intent["true_damage"])
        _log_damage(intent["actor"], intent["target"], intent["amount"], intent["source_kind"], actual)
    _clear_damage_buffer()

func _clear_damage_buffer() -> void:
    _damage_buffer_active = false
    _damage_buffer.clear()
    _damage_shadows.clear()
    _damage_actor_start_alive.clear()

func damage_actor_can_continue(side) -> bool:
    if not _damage_buffer_active:
        return side.life > 0
    return bool(_damage_actor_start_alive.get(side.get_instance_id(), side.life > 0))

func damage_target_can_receive(side) -> bool:
    if not _damage_buffer_active:
        return side.life > 0
    var shadow: Dictionary = _damage_shadows.get(side.get_instance_id(), {"life": side.life})
    return int(shadow["life"]) > 0

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
    delayed_effects.append({
        "label": label,
        "remaining_turn_ends": turn_ends,
        "snapshot_power": snapshot_power,
        "damage_per_segment": damage_per_segment,
        "attack_count": 0,
        "actor": actor,
        "target": target,
    })
    trigger_queue.add_history("delayed_register", label, "%s延迟功法" % actor.name, "成功", "记录建立时 P=%d" % snapshot_power)

func _resolve_player_turn_end_delays() -> void:
    var due: Array = []
    for delayed in delayed_effects:
        if delayed["actor"] != player:
            continue
        delayed["remaining_turn_ends"] = int(delayed["remaining_turn_ends"]) - 1
        if int(delayed["remaining_turn_ends"]) <= 0:
            due.append(delayed)
    for delayed in due:
        delayed_effects.erase(delayed)
        trigger_queue.add_history(
            "player_turn_end", delayed["label"], "延迟功法", "结算",
            "快照 P=%d｜记录攻击段=%d｜每段=%d" % [
                delayed["snapshot_power"], delayed["attack_count"], delayed["damage_per_segment"]])
        for _index in range(int(delayed["attack_count"])):
            if delayed["target"].life <= 0:
                break
            deal_damage(delayed["actor"], delayed["target"], delayed["damage_per_segment"], "delayed_chase")

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
        actions_available = 0
        enemy_actions_available = 0
        locked_enemy_card_ids.clear()
        trigger_queue.add_history("battle_end", battle_state_detail, "战斗结果", "结算")

func _set_scenario_error(detail: String) -> void:
    battle_state = "scenario_error"
    battle_state_detail = detail
    actions_available = 0
    enemy_actions_available = 0
    locked_enemy_card_ids.clear()
    trigger_queue.add_history("scenario_error", "脚本场景错误", "脚本场景", "失败", detail)
    state_changed.emit()

func _is_same_attribute_action(cards: Array) -> bool:
    if cards.is_empty():
        return false
    var attribute: String = cards[0].attribute
    if attribute == "":
        return false
    for card in cards:
        if card.attribute != attribute:
            return false
    return true

func _technique_name(technique_id: String) -> String:
    return repository.get_technique(technique_id).get("name", "空序列")
