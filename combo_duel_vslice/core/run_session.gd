class_name RunSession
extends RefCounted

signal state_changed

const RunStateScript = preload("res://core/run_state.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunSnapshotScript = preload("res://core/run_snapshot.gd")
const RunEventScript = preload("res://core/run_event.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const ConsumableRepositoryScript = preload("res://core/consumable_repository.gd")
const GameLogScript = preload("res://core/game_log.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")

const PRACTICE_OFFER_IDS := ["high_card_insight", "hierophant", "aura"]

var game_log
var _run_state
var navigation
var growth
var _node_dispatcher
var _consumable_repository
var _content_catalog
var _event_queue: Array = []
var _event_serial: int = 0

func _init(
        run_state_override = null,
        node_dispatcher_override = null,
        game_log_override = null,
        consumable_repository_override = null,
        content_catalog_override = null) -> void:
    game_log = game_log_override if game_log_override != null else GameLogScript.new()
    _content_catalog = (
        content_catalog_override
        if content_catalog_override != null
        else ContentCatalogScript.new())
    if content_catalog_override == null:
        _content_catalog.load_all()
    if run_state_override != null:
        _run_state = run_state_override
        navigation = _run_state.navigation
        growth = _run_state.growth
        if _content_catalog.loaded:
            navigation.map_generator.configure(_content_catalog.definition("map_rules"))
    else:
        var map_generator = MapGeneratorScript.new(
            _content_catalog.definition("map_rules") if _content_catalog.loaded else {})
        navigation = MapNavigationServiceScript.new(map_generator)
        growth = GrowthInventoryScript.new(_content_catalog)
        _run_state = RunStateScript.new(navigation, growth)
    _node_dispatcher = (
        node_dispatcher_override
        if node_dispatcher_override != null
        else NodeDispatcherScript.new(
            _content_catalog.definition("node_content") if _content_catalog.loaded else {}))
    _consumable_repository = (
        consumable_repository_override
        if consumable_repository_override != null
        else ConsumableRepositoryScript.new())
    if consumable_repository_override == null and _content_catalog.loaded:
        _consumable_repository.configure(_content_catalog.definition("consumables"))
    elif consumable_repository_override == null:
        _consumable_repository.consumables.clear()
    if not _content_catalog.loaded:
        game_log.record_system(
            "error",
            "content_catalog",
            "本局内容目录校验失败",
            "\n".join(_content_catalog.errors))
    _run_state.changed.connect(_on_run_state_changed)

func create_battle_session():
    return BattleSessionScript.new(CombatEngineScript.new(game_log, _content_catalog))

func execute(command: Dictionary) -> Dictionary:
    var command_type := str(command.get("type", ""))
    var result: Dictionary
    match command_type:
        "setup_run":
            result = _setup_run(int(command.get("seed", 2308)))
        "begin_node":
            result = _begin_node(str(command.get("node_id", "")))
        "complete_node":
            result = _complete_node()
        "complete_boss_chest":
            result = _complete_boss_chest()
        "open_practice":
            result = _open_practice()
        "close_practice":
            result = _close_practice()
        "purchase_consumable":
            result = _purchase_consumable(str(command.get("consumable_id", "")))
        _:
            result = {"success": false, "reason": "未知本局命令：%s" % command_type}
    if not result.get("success", false):
        _record_command_rejected(command_type, str(result.get("reason", "命令执行失败")))
    return result

func snapshot():
    var graph: Dictionary = navigation.graph.duplicate(true)
    var completed: Dictionary = navigation.completed_node_ids.duplicate(true)
    var available: Array[String] = navigation.available_node_ids()
    return RunSnapshotScript.new({
        "seed": navigation.seed,
        "act": navigation.act,
        "act_count": int(navigation.map_generator.rules.get("acts", 3)),
        "phase": navigation.phase,
        "experience": growth.experience,
        "current_node_id": navigation.current_node_id,
        "completed_node_ids": completed,
        "completed_node_count": completed.size(),
        "available_node_ids": available,
        "available_node_count": available.size(),
        "can_open_practice": navigation.can_open_practice(),
        "graph": graph,
        "practice": _practice_snapshot(),
        "growth": _growth_snapshot(),
        "run_log": game_log.entries("run", 200),
        "battle_log": game_log.entries("battle", 200),
        "system_log": game_log.entries("system", 200),
    })

func drain_events() -> Array:
    var drained := _event_queue.duplicate()
    _event_queue.clear()
    return drained

func progress_snapshot():
    return growth.to_progress_snapshot()

func sync_progress_snapshot(progress_snapshot) -> void:
    if progress_snapshot == null:
        return
    var before: Dictionary = growth.to_progress_snapshot().to_dict()
    growth.apply_progress_snapshot(progress_snapshot)
    var after: Dictionary = growth.to_progress_snapshot().to_dict()
    if before == after:
        return
    var entry: Dictionary = game_log.record_run(
        "growth_sync",
        "战斗成长同步到本局",
        "牌组 %d 张，消耗品 %d/3，已获功法 %d 门" % [
            growth.run_deck.card_count(),
            growth.consumable_ids.size(),
            growth.learned_technique_ids.size()],
        {"act": navigation.act, "phase": navigation.phase})
    _queue_event("growth_synced", entry, {
        "run_deck_count": growth.run_deck.card_count(),
        "consumable_count": growth.consumable_ids.size(),
        "learned_technique_count": growth.learned_technique_ids.size(),
    })
    _run_state.changed.emit()

func _setup_run(seed_value: int) -> Dictionary:
    if not _content_catalog.loaded:
        return {"success": false, "reason": "统一内容目录无效"}
    game_log.clear("run")
    game_log.clear("battle")
    _event_queue.clear()
    _event_serial = 0
    growth.reset("run-%d" % seed_value)
    navigation.setup(seed_value)
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "run_lifecycle",
        "建立新本局",
        "第 1 层路线已生成",
        {"seed": seed_value, "act": 1, "phase": navigation.phase})
    _queue_event("run_setup", entry, {"seed": seed_value, "act": 1})
    return {"success": true, "seed": seed_value, "act": 1}

func _begin_node(node_id: String) -> Dictionary:
    var node: Dictionary = navigation.node_definition(node_id)
    var dispatch: Dictionary = _node_dispatcher.dispatch(
        node,
        navigation.node_dispatch_context())
    if not dispatch.get("success", false):
        return dispatch
    var result: Dictionary = navigation.begin_node(node_id)
    if not result.get("success", false):
        return result
    _run_state.changed.emit()
    result["dispatch"] = dispatch.duplicate(true)
    var entry: Dictionary = game_log.record_run(
        "node_lifecycle",
        "进入节点",
        "%s · %s" % [dispatch.get("title", node_id), dispatch.get("route", "")],
        {
            "seed": navigation.seed,
            "act": navigation.act,
            "node_id": node_id,
            "node_type": dispatch.get("node_type", ""),
            "content_id": dispatch.get("content_id", ""),
            "content_seed": dispatch.get("content_seed", 0),
        })
    _queue_event("node_started", entry, {
        "node_id": node_id,
        "node_type": dispatch.get("node_type", ""),
        "route": dispatch.get("route", ""),
    })
    return result

func _complete_node() -> Dictionary:
    var act_before: int = navigation.act
    var result: Dictionary = navigation.complete_current_node()
    if not result.get("success", false):
        return result
    growth.experience += int(result.get("reward", 0))
    growth.clear_practice_purchases()
    _run_state.changed.emit()
    var node: Dictionary = result.get("node", {})
    var entry: Dictionary = game_log.record_run(
        "node_lifecycle",
        "完成节点",
        "%s · 历练 +%d · 下一阶段 %s" % [
            node.get("type", ""), result.get("reward", 0), result.get("phase", "")],
        {
            "act": act_before,
            "node_id": node.get("id", ""),
            "node_type": node.get("type", ""),
            "reward": result.get("reward", 0),
            "experience": growth.experience,
            "next_phase": result.get("phase", ""),
        })
    _queue_event("node_completed", entry, {
        "act": act_before,
        "node_id": node.get("id", ""),
        "reward": result.get("reward", 0),
        "next_phase": result.get("phase", ""),
    })
    return result

func _complete_boss_chest() -> Dictionary:
    var act_before: int = navigation.act
    var result: Dictionary = navigation.complete_boss_chest()
    if not result.get("success", false):
        return result
    _run_state.changed.emit()
    var entry: Dictionary = game_log.record_run(
        "run_lifecycle",
        "完成 Boss 宝箱流程",
        "第 %d 层进入第 %d 层" % [act_before, result.get("act", act_before)],
        {
            "act": act_before,
            "next_act": result.get("act", act_before),
            "next_phase": result.get("phase", ""),
        })
    _queue_event("boss_chest_completed", entry, {
        "act": act_before,
        "next_act": result.get("act", act_before),
    })
    return result

func _open_practice() -> Dictionary:
    if not navigation.can_open_practice():
        return {"success": false, "reason": "当前节点尚未完成，不能修习"}
    var entry: Dictionary = game_log.record_run(
        "practice_lifecycle",
        "打开修习",
        "当前历练 %d" % growth.experience,
        {"act": navigation.act, "experience": growth.experience})
    _queue_event("practice_opened", entry, {"act": navigation.act})
    return {"success": true}

func _close_practice() -> Dictionary:
    var entry: Dictionary = game_log.record_run(
        "practice_lifecycle",
        "关闭修习",
        "返回地图待选状态",
        {"act": navigation.act, "phase": navigation.phase})
    _queue_event("practice_closed", entry, {"act": navigation.act})
    return {"success": true}

func _purchase_consumable(consumable_id: String) -> Dictionary:
    var definition: Dictionary = _consumable_repository.get_consumable(consumable_id)
    if definition.is_empty() or not PRACTICE_OFFER_IDS.has(consumable_id):
        return {"success": false, "reason": "当前修习没有该选项"}
    var price := int(definition.get("price", 0))
    var result: Dictionary = growth.purchase_consumable(
        consumable_id,
        price,
        navigation.can_open_practice())
    if not result.get("success", false):
        return result
    _run_state.changed.emit()
    result["price"] = price
    result["definition"] = definition.duplicate(true)
    var entry: Dictionary = game_log.record_run(
        "practice_purchase",
        "修习购入",
        "%s · 历练 -%d" % [definition.get("name", consumable_id), price],
        {
            "act": navigation.act,
            "consumable_id": consumable_id,
            "kind": definition.get("kind", ""),
            "price": price,
            "remaining_experience": growth.experience,
        })
    _queue_event("practice_purchased", entry, {
        "consumable_id": consumable_id,
        "price": price,
        "remaining_experience": growth.experience,
    })
    return result

func _practice_snapshot() -> Dictionary:
    var offers: Array = []
    for consumable_id in PRACTICE_OFFER_IDS:
        var definition: Dictionary = _consumable_repository.get_consumable(consumable_id).duplicate(true)
        if definition.is_empty():
            continue
        var price := int(definition.get("price", 0))
        var purchased: bool = growth.practice_purchases.has(consumable_id)
        definition["purchased"] = purchased
        definition["can_purchase"] = (
            navigation.can_open_practice()
            and not purchased
            and growth.experience >= price
            and growth.consumable_ids.size() < GrowthInventoryScript.CONSUMABLE_LIMIT)
        offers.append(definition)
    return {
        "available": navigation.can_open_practice(),
        "offer_ids": PRACTICE_OFFER_IDS.duplicate(),
        "offers": offers,
        "purchased_ids": growth.practice_purchases.keys(),
    }

func _growth_snapshot() -> Dictionary:
    var consumables: Array = []
    for consumable_id in growth.consumable_ids:
        consumables.append(
            _consumable_repository.get_consumable(consumable_id).duplicate(true))
    return {
        "consumable_limit": 3,
        "consumable_ids": growth.consumable_ids.duplicate(),
        "consumables": consumables,
        "insight_multipliers": growth.insight_multipliers.duplicate(true),
        "learned_technique_ids": growth.learned_technique_ids.duplicate(),
        "run_deck": growth.run_deck.to_snapshot(),
        "run_deck_count": growth.run_deck.card_count(),
    }

func _record_command_rejected(command_type: String, reason: String) -> void:
    var entry: Dictionary = game_log.record_system(
        "warning",
        "run_command",
        "本局命令被拒绝",
        reason,
        {"command": command_type, "act": navigation.act, "phase": navigation.phase})
    _queue_event("command_rejected", entry, {
        "command": command_type,
        "reason": reason,
    })

func _queue_event(event_type: String, log_entry: Dictionary, values: Dictionary = {}) -> void:
    var data := values.duplicate(true)
    data["type"] = event_type
    data["serial"] = _event_serial
    data["log_serial"] = int(log_entry.get("serial", -1))
    _event_queue.append(RunEventScript.new(data))
    _event_serial += 1

func _on_run_state_changed() -> void:
    state_changed.emit()
