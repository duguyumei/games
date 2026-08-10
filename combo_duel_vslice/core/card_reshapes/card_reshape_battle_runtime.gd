class_name CardReshapeBattleRuntime
extends RefCounted

const PowerCalculatorScript = preload("res://core/power_calculator.gd")

## 战斗事件与重塑行为之间的轻量适配器。
##
## 牌区、异状和数值规则仍由现有服务负责；这里仅把稳定战斗时点转换为
## CardReshapeRuleService 调用，并向 Handler 提供 BattleEffectPorts。

var _rules
var _effect_ports_ref: WeakRef
var _rng: RandomNumberGenerator
var last_successful_hand_by_side: Dictionary = {}

func _init(rules, effect_ports, rng: RandomNumberGenerator, timing_system) -> void:
    _rules = rules
    _effect_ports_ref = weakref(effect_ports)
    _rng = rng
    timing_system.register_weak_handler(
        timing_system.BATTLE_START,
        "card_reshape_runtime.opening_draw_priority",
        200,
        self,
        "_on_battle_start")
    timing_system.register_weak_handler(
        timing_system.GROUP_END,
        "card_reshape_runtime.group_resolved",
        800,
        self,
        "_on_group_end")
    timing_system.register_weak_handler(
        timing_system.TURN_END,
        "card_reshape_runtime.turn_end",
        900,
        self,
        "_on_turn_end")
    timing_system.register_weak_handler(
        timing_system.TURN_END,
        "card_reshape_runtime.turn_end_final",
        1000,
        self,
        "_on_turn_end_final")
    timing_system.register_weak_handler(
        timing_system.BATTLE_END,
        "card_reshape_runtime.battle_victory",
        50,
        self,
        "_on_battle_victory")

func on_card_drawn(holder, card) -> Array[Dictionary]:
    return _dispatch(card, "card_drawn", holder)

func on_card_entered_discard(
        holder,
        card,
        reason: String = "") -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    if reason == "explicit_discard":
        results.append_array(_dispatch(
            card, "card_explicitly_discarded", holder))
    results.append_array(_dispatch(card, "card_entered_discard", holder))
    return results

func on_card_played(holder, cards: Array) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    for card in cards:
        results.append_array(_dispatch(card, "card_played", holder))
    return results

func can_explicit_discard(holder, card) -> Dictionary:
    var results := _dispatch(card, "explicit_discard_attempt", holder)
    for result in results:
        if bool(result.get("blocked", false)):
            return {
                "allowed": false,
                "reason": str(result.get("reason", "此真气不能被明确弃掉")),
            }
    return {"allowed": true}

func finalize_action_preview(holder, preview: Dictionary) -> Dictionary:
    if bool(preview.get("reshape_action_confirmed", false)):
        return {"success": true, "reused": true}
    var frozen_by_card: Dictionary = {}
    var multiplier_bonus := 0
    for card in preview.get("hand", {}).get("contributing", []):
        var frozen_results: Array = []
        for result in _dispatch(card, "action_confirmed", holder):
            multiplier_bonus += int(result.get("card_multiplier_bonus", 0))
            if result.has("frozen"):
                frozen_results.append(result["frozen"].duplicate(true))
        if not frozen_results.is_empty():
            frozen_by_card[str(card.id)] = (
                frozen_results[0]
                if frozen_results.size() == 1 else frozen_results)
    preview["reshape_action_confirmed"] = true
    preview["reshape_action_results"] = frozen_by_card
    preview["values"] = PowerCalculatorScript.apply_frozen_card_multiplier_bonus(
        preview.get("values", {}), multiplier_bonus)
    return {
        "success": true,
        "reused": false,
        "card_multiplier_bonus": multiplier_bonus,
        "results": frozen_by_card.duplicate(true),
    }

func _on_group_end(event) -> Dictionary:
    var record = event.context.get("record")
    if record == null or not bool(record.triggered) or bool(record.failed):
        return {"success": true, "detail": "本组功法未触发"}
    last_successful_hand_by_side[_side_key(record.actor)] = str(
        record.preview.get("hand", {}).get("id", ""))
    var contributing: Array = record.preview["hand"].get("contributing", [])
    var applied := 0
    for card in contributing:
        applied += _applied_count(_dispatch(card, "group_resolved", record.actor))
    return {"success": true, "detail": "结算 %d 张参与真气的重塑行为" % applied}

func _on_turn_end(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "回合结束缺少行动方"}
    var applied := 0
    for card in event.actor.hand.duplicate():
        applied += _applied_count(_dispatch(card, "turn_end", event.actor))
    return {"success": true, "detail": "结算 %d 张留手真气的重塑行为" % applied}

func _on_turn_end_final(event) -> Dictionary:
    if event.actor == null:
        return {"success": false, "detail": "最终回合结束缺少行动方"}
    var applied := 0
    for card in event.actor.hand.duplicate():
        applied += _applied_count(_dispatch(card, "turn_end_final", event.actor))
    return {"success": true, "detail": "最终结算 %d 张留手真气" % applied}

func _on_battle_victory(event) -> Dictionary:
    var winner = event.context.get("winner")
    if winner == null:
        return {"success": true, "detail": "本场没有胜者奖励"}
    var applied := 0
    var hand_id := str(last_successful_hand_by_side.get(_side_key(winner), ""))
    for card in winner.hand.duplicate():
        applied += _applied_count(_dispatch(card, "battle_victory", winner, {
            "zone_name": "hand",
            "payload": {"last_successful_hand_id": hand_id},
        }))
    for card in winner.draw_pile.duplicate():
        applied += _applied_count(_dispatch(card, "battle_victory", winner, {
            "zone_name": "draw_pile",
            "payload": {"last_successful_hand_id": hand_id},
        }))
    return {"success": true, "detail": "结算 %d 张胜利区间真气" % applied}

func _on_battle_start(event) -> Dictionary:
    last_successful_hand_by_side.clear()
    var applied := 0
    for side in event.context.get("actors", []):
        # 牌库尾部是顶。按数组正序逐张置顶，恰好保持原本从顶到底的抽取顺序。
        for card in side.draw_pile.duplicate():
            applied += _applied_count(_dispatch(
                card, "battle_start_hand_priority", side))
    return {"success": true, "detail": "优先排列 %d 张起始真气" % applied}

func _dispatch(
        card,
        trigger: String,
        holder,
        extra_values: Dictionary = {}) -> Array[Dictionary]:
    var values := {
        "holder": holder,
        "effect_ports": _effect_ports_ref.get_ref(),
        "rng": _rng,
    }
    values.merge(extra_values, true)
    return _rules.dispatch_battle_event(card, trigger, values)

func _side_key(side) -> String:
    return str(side.owner_id)

func _applied_count(results: Array[Dictionary]) -> int:
    var count := 0
    for result in results:
        if bool(result.get("applied", false)):
            count += 1
    return count
