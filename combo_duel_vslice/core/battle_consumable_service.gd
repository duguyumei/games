class_name BattleConsumableService
extends RefCounted

## 战斗内消耗品用例。
## 消耗品定义来自 ContentCatalog；这里只把已校验的效果应用到玩家状态。

var player
var consumable_repository
var technique_repository
var action_resolver
var trigger_queue
var rng: RandomNumberGenerator
var battle_state_reader: Callable
var state_changed: Callable

func _init(
        player_side,
        consumables,
        techniques,
        resolver,
        history,
        random_source: RandomNumberGenerator,
        battle_state_callback: Callable,
        state_changed_callback: Callable) -> void:
    player = player_side
    consumable_repository = consumables
    technique_repository = techniques
    action_resolver = resolver
    trigger_queue = history
    rng = random_source
    battle_state_reader = battle_state_callback
    state_changed = state_changed_callback

func use_game_log_queue(history) -> void:
    trigger_queue = history

func grant(side, consumable_id: String, source: String = "效果") -> bool:
    var definition: Dictionary = consumable_repository.get_consumable(consumable_id)
    if definition.is_empty():
        return false
    var granted: bool = side.grant_consumable(consumable_id)
    trigger_queue.add_history(
        "consumable_gain",
        "获得%s" % definition.get("name", consumable_id),
        source,
        "成功" if granted else "失败",
        "进入共享消耗品栏" if granted else "共享消耗品栏已满，不生成")
    if granted:
        state_changed.call()
    return granted

func use_player(slot_index: int, card_ids: Array = []) -> Dictionary:
    if battle_state_reader.call() != "active":
        return {"success": false, "reason": "战斗已经结束"}
    if action_resolver.has_pending_choice():
        return {"success": false, "reason": "正在等待功法选择，不能使用消耗品"}
    if slot_index < 0 or slot_index >= player.consumable_ids.size():
        return {"success": false, "reason": "消耗品槽位无效"}

    var consumable_id: String = player.consumable_ids[slot_index]
    var definition: Dictionary = consumable_repository.get_consumable(consumable_id)
    var cards: Array = []
    for card_id_value in card_ids:
        var card = player.find_hand_card(str(card_id_value))
        if card == null or cards.has(card):
            return {"success": false, "reason": "目标包含不在当前手牌中的真气"}
        cards.append(card)
    var target_check: Dictionary = consumable_repository.validate_targets(consumable_id, cards)
    if not target_check["ok"]:
        return {"success": false, "reason": target_check["reason"]}

    var details: Array[String] = []
    var acquired_technique_id: String = ""
    for effect in definition.get("effects", []):
        var op: String = effect.get("op", "")
        match op:
            "gain_insight":
                var hand_id: String = effect.get("hand", "")
                var amount: int = int(effect.get("multiplier", 0))
                var total: int = player.add_insight(hand_id, amount)
                details.append("%s心得倍率 +%d（累计 +%d）" % [hand_id, amount, total])
                acquired_technique_id = _learn_random_technique(effect.get("pools", []))
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
    state_changed.call()
    return {
        "success": true,
        "consumable_id": consumable_id,
        "cards": cards,
        "acquired_technique_id": acquired_technique_id,
        "detail": "；".join(details),
    }

func _learn_random_technique(pools: Array) -> String:
    var candidates: Array[String] = []
    for technique_id_value in technique_repository.techniques.keys():
        var technique_id: String = str(technique_id_value)
        var technique: Dictionary = technique_repository.get_technique(technique_id)
        if pools.has(technique.get("pool", "")) and not player.owned_technique_ids.has(technique_id):
            candidates.append(technique_id)
    candidates.sort()
    if candidates.is_empty():
        return ""
    var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
    player.learn_technique(chosen)
    return chosen

func _technique_name(technique_id: String) -> String:
    return technique_repository.get_technique(technique_id).get("name", "空序列")

func _enhancement_name(enhancement_id: String) -> String:
    return {"bonus": "奖励牌", "multiplier": "倍率牌"}.get(enhancement_id, enhancement_id)

func _finish_name(finish_id: String) -> String:
    return {"foil": "箔面", "holographic": "镭射", "polychrome": "多彩"}.get(finish_id, finish_id)
