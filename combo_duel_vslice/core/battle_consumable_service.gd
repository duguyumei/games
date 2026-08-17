class_name BattleConsumableService
extends RefCounted

## 战斗内消耗品门禁、日志与 UI/CombatEngine 适配器。
##
## 槽位、定义、目标、unique、Handler 顺序、库存扣除、使用记录与原子回滚全部
## 委托 ConsumableUseService；本适配器不再维护第二套消耗品事务。

const ConsumableEffectHandlerRegistryScript = preload(
    "res://core/consumables/consumable_effect_handler_registry.gd")
const BattleConsumableUseContextScript = preload(
    "res://core/consumables/battle_consumable_use_context.gd")
const ConsumableUseServiceScript = preload(
    "res://core/consumables/consumable_use_service.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")

var player
var enemy
var consumable_repository
var technique_repository
var action_resolver
var trigger_queue
var rng: RandomNumberGenerator
var battle_state_reader: Callable
var state_changed: Callable
var _handler_registry := ConsumableEffectHandlerRegistryScript.new()
var _use_service
var _event_service
var _content_catalog

func _init(
        player_side,
        consumables,
        techniques,
        resolver,
        history,
        random_source: RandomNumberGenerator,
        battle_state_callback: Callable,
        state_changed_callback: Callable,
        enemy_side = null,
        event_service = null,
        content_catalog = null) -> void:
    player = player_side
    enemy = enemy_side
    consumable_repository = consumables
    technique_repository = techniques
    action_resolver = resolver
    trigger_queue = history
    rng = random_source
    battle_state_reader = battle_state_callback
    state_changed = state_changed_callback
    _event_service = event_service
    _content_catalog = content_catalog
    _use_service = ConsumableUseServiceScript.new(
        _handler_registry,
        _content_catalog,
        ContentValidatorScript.HAND_IDS,
        ContentValidatorScript.POOL_IDS)

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
    var consumable_id: String = (
        str(player.consumable_ids[slot_index])
        if slot_index >= 0 and slot_index < player.consumable_ids.size()
        else "")
    var definition: Dictionary = consumable_repository.get_consumable(consumable_id)
    var context = _context_for(slot_index, consumable_id, definition)
    var result: Dictionary = _use_service.use(
        context, slot_index, card_ids, 0, definition, {})
    if not result.get("success", false):
        return result
    var details: Array[String] = []
    var technique_acquired := ""
    for applied_value in result.get("applied", []):
        var applied: Dictionary = applied_value
        if applied.has("technique_acquired"):
            technique_acquired = str(applied.get("technique_acquired", ""))
        details.append_array(applied.get("details", []))
    var cards: Array = []
    for instance_id in result.get("instance_ids", []):
        var card = player.find_hand_card(str(instance_id))
        if card != null:
            cards.append(card)
    trigger_queue.add_history(
        "consumable_use", definition.get("name", consumable_id), "战斗消耗品", "成功",
        "；".join(details))
    state_changed.call()
    result["cards"] = cards
    result["technique_acquired"] = technique_acquired
    result["technique_equipped"] = false
    result["detail"] = "；".join(details)
    return result

func query_player(slot_index: int) -> Dictionary:
    if battle_state_reader.call() != "active":
        return {
            "success": true,
            "can_use": false,
            "reason": "战斗已经结束",
        }
    if action_resolver.has_pending_choice():
        return {
            "success": true,
            "can_use": false,
            "reason": "正在等待功法选择，不能使用消耗品",
        }
    var consumable_id: String = (
        str(player.consumable_ids[slot_index])
        if slot_index >= 0 and slot_index < player.consumable_ids.size()
        else "")
    var definition: Dictionary = consumable_repository.get_consumable(consumable_id)
    return _use_service.query_use(
        _context_for(slot_index, consumable_id, definition),
        slot_index, definition, 0)

func _context_for(
        slot_index: int,
        consumable_id: String,
        definition: Dictionary):
    var sequence := int(player.consumable_use_sequence)
    var stable_instance_key := "battle-consumable:%d:%d:%s" % [
        sequence, slot_index, consumable_id]
    return BattleConsumableUseContextScript.new(
        player, [], rng, technique_repository, consumable_repository,
        _event_service, trigger_queue, [player, enemy], {
            "consumable_id": consumable_id,
            "source_kind": "consumable",
            "source_id": consumable_id,
            "source_name": str(definition.get("name", consumable_id)),
            "source_instance_key": stable_instance_key,
            "action_token": "battle-consumable-use:%d:%d:%s" % [
                sequence, slot_index, consumable_id],
        })
