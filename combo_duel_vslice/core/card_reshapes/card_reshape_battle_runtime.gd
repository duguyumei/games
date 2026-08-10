class_name CardReshapeBattleRuntime
extends RefCounted

## 战斗事件与重塑行为之间的轻量适配器。
##
## 牌区、异状和数值规则仍由现有服务负责；这里仅把稳定战斗时点转换为
## CardReshapeRuleService 调用，并向 Handler 提供 BattleEffectPorts。

var _rules
var _effect_ports_ref: WeakRef
var _rng: RandomNumberGenerator

func _init(rules, effect_ports, rng: RandomNumberGenerator, timing_system) -> void:
    _rules = rules
    _effect_ports_ref = weakref(effect_ports)
    _rng = rng
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

func on_card_drawn(holder, card) -> Array[Dictionary]:
    return _dispatch(card, "card_drawn", holder)

func on_card_entered_discard(holder, card) -> Array[Dictionary]:
    return _dispatch(card, "card_entered_discard", holder)

func _on_group_end(event) -> Dictionary:
    var record = event.context.get("record")
    if record == null or not bool(record.triggered):
        return {"success": true, "detail": "本组功法未触发"}
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

func _dispatch(card, trigger: String, holder) -> Array[Dictionary]:
    return _rules.dispatch_battle_event(card, trigger, {
        "holder": holder,
        "effect_ports": _effect_ports_ref.get_ref(),
        "rng": _rng,
    })

func _applied_count(results: Array[Dictionary]) -> int:
    var count := 0
    for result in results:
        if bool(result.get("applied", false)):
            count += 1
    return count
