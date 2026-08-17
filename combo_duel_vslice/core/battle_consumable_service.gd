class_name BattleConsumableService
extends RefCounted

## 战斗内消耗品用例（纵切兼容适配器）。
##
## 正式消耗品内容以 RunSession 的战斗外入口为准。这里保留历史纵切能力：
## 战斗状态门禁、当前手牌目标查找、战斗日志与 state_changed 仍由本服务负责，
## 但效果执行全部委托统一 ConsumableEffectHandlerRegistry，不再按 op 分支。

const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const BattleConsumableUseContextScript = preload(
    "res://core/consumables/battle_consumable_use_context.gd")
const RunEffectValidationScript = preload(
    "res://core/run_effects/run_effect_validation.gd")

var player
var consumable_repository
var technique_repository
var action_resolver
var trigger_queue
var rng: RandomNumberGenerator
var battle_state_reader: Callable
var state_changed: Callable
var _handler_registry := ConsumableEffectHandlerRegistryScript.new()

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
    if definition.is_empty():
        return {"success": false, "reason": "消耗品不存在"}
    var cards: Array = []
    var instance_ids: Array[String] = []
    for card_id_value in card_ids:
        var card = player.find_hand_card(str(card_id_value))
        if card == null or cards.has(card):
            return {"success": false, "reason": "目标包含不在当前手牌中的真气"}
        cards.append(card)
        instance_ids.append(str(card.id))
    var target_check: Dictionary = consumable_repository.validate_targets(consumable_id, cards)
    if not target_check["ok"]:
        return {"success": false, "reason": target_check["reason"]}

    var details: Array[String] = []
    var technique_acquired := ""
    var effects: Array = definition.get("effects", [])
    if not effects is Array or effects.is_empty():
        return {"success": false, "reason": "消耗品没有效果"}

    ## 先完成全部静态校验，再触碰真实战斗状态。
    for effect_index in range(effects.size()):
        var effect = effects[effect_index]
        if not effect is Dictionary:
            return {"success": false, "reason": "效果必须是对象"}
        var validation := RunEffectValidationScript.new()
        _handler_registry.validate_effect(
            effect, validation, "effects[%d]" % effect_index)
        if not validation.is_valid():
            return {"success": false, "reason": "；".join(validation.errors)}

    var context = BattleConsumableUseContextScript.new(
        player, instance_ids, rng, technique_repository, {
            "consumable_id": consumable_id,
        })
    var state_before: Dictionary = context.capture_transaction_state()
    var rng_state_before := rng.state
    for effect_index in range(effects.size()):
        var effect: Dictionary = effects[effect_index]
        context.metadata["effect_index"] = effect_index
        var result: Dictionary = _handler_registry.apply(effect, context)
        if not result.get("success", false):
            var restored: bool = context.restore_transaction_state(state_before)
            rng.state = rng_state_before
            result["rolled_back"] = restored
            result["failed_effect_index"] = effect_index
            if not restored:
                result["reason"] = "%s；战斗消耗品事务状态恢复不完整" % str(
                    result.get("reason", "消耗品效果执行失败"))
            return result
        var applied: Dictionary = result.get("applied", {})
        if applied.has("technique_acquired"):
            technique_acquired = str(applied.get("technique_acquired", ""))
        details.append_array(applied.get("details", []))

    var consumed_id: String = str(player.consume_at(slot_index))
    if consumed_id != consumable_id:
        context.restore_transaction_state(state_before)
        rng.state = rng_state_before
        return {"success": false, "reason": "消耗品槽位在事务期间发生变化", "rolled_back": true}
    trigger_queue.add_history(
        "consumable_use", definition.get("name", consumable_id), "纵切调试构筑台", "成功",
        "；".join(details))
    state_changed.call()
    return {
        "success": true,
        "consumable_id": consumable_id,
        "cards": cards,
        "technique_acquired": technique_acquired,
        "technique_equipped": false,
        "detail": "；".join(details),
    }
