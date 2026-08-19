class_name ComboRunState
extends RefCounted

const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")

signal changed

const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")

var navigation = MapNavigationServiceScript.new()
var growth = GrowthInventoryScript.new()
var terminal_result = null
var practice_is_open: bool = false
var practice_open_sequence: int = 0
var committed_passive_event_tokens: Array[String] = []
var run_command_receipts: Dictionary = {}
var _run_mutation_service

func _init(navigation_override = null, growth_override = null) -> void:
    if navigation_override != null:
        navigation = navigation_override
    if growth_override != null:
        growth = growth_override
    var catalog = growth.get("_content_catalog") if growth != null else null
    _run_mutation_service = RunMutationServiceScript.new(
        catalog.run_effect_registry if catalog != null else null,
        catalog)

# Compatibility facade for existing domain tests and callers. New code should
# use RunSession commands and snapshots instead of mutating these properties.
var map_generator:
    get:
        return navigation.map_generator
var seed: int:
    get:
        return navigation.seed
    set(value):
        navigation.seed = value
var act: int:
    get:
        return navigation.act
    set(value):
        navigation.act = value
var phase: String:
    get:
        return navigation.phase
    set(value):
        navigation.phase = value
var graph: Dictionary:
    get:
        return navigation.graph
    set(value):
        navigation.graph = value
var current_node_id: String:
    get:
        return navigation.current_node_id
    set(value):
        navigation.current_node_id = value
var completed_node_ids: Dictionary:
    get:
        return navigation.completed_node_ids
    set(value):
        navigation.completed_node_ids = value
var experience: int:
    get:
        return growth.experience
    set(value):
        growth.experience = value
var consumable_ids: Array[String]:
    get:
        return growth.consumable_ids
    set(value):
        growth.consumable_ids = value
var hand_technique_progression: Dictionary:
    get:
        return growth.hand_technique_progression
    set(value):
        growth.hand_technique_progression = value
var learned_technique_ids: Array[String]:
    get:
        return growth.learned_technique_ids
    set(value):
        growth.learned_technique_ids = value
var run_deck:
    get:
        return growth.run_deck
    set(value):
        growth.run_deck = value
var practice_purchases: Dictionary:
    get:
        return growth.practice_purchases
    set(value):
        growth.practice_purchases = value

func setup(seed_value: int = 2308) -> void:
    terminal_result = null
    reset_passive_run_state()
    growth.reset("run-%d" % seed_value)
    navigation.setup(seed_value)
    changed.emit()

func reset_passive_run_state() -> void:
    practice_is_open = false
    practice_open_sequence = 0
    committed_passive_event_tokens.clear()
    run_command_receipts.clear()

func capture_transaction_state() -> Dictionary:
    return {
        "terminal_result": terminal_result,
        "practice_is_open": practice_is_open,
        "practice_open_sequence": practice_open_sequence,
        "committed_passive_event_tokens": committed_passive_event_tokens.duplicate(),
        "run_command_receipts": run_command_receipts.duplicate(true),
    }

## 聚合事务恢复只写内存状态；调用方负责决定何时统一通知观察者。
func restore_transaction_state(state: Dictionary) -> void:
    terminal_result = state.get("terminal_result")
    practice_is_open = bool(state.get("practice_is_open", false))
    practice_open_sequence = int(state.get("practice_open_sequence", 0))
    committed_passive_event_tokens.assign(
        state.get("committed_passive_event_tokens", []))
    run_command_receipts = state.get(
        "run_command_receipts", {}).duplicate(true)

func available_node_ids() -> Array[String]:
    return navigation.available_node_ids()

func begin_node(node_id: String) -> Dictionary:
    var result: Dictionary = navigation.begin_node(node_id)
    if result.get("success", false):
        changed.emit()
    return result

func complete_current_node() -> Dictionary:
    var navigation_before: Dictionary = navigation.capture_transaction_state()
    var growth_before: Dictionary = growth.capture_mutation_state()
    var result: Dictionary = navigation.complete_current_node()
    if not result.get("success", false):
        return result
    var reward := int(result.get("reward", 0))
    if reward > 0:
        var rewarded: Dictionary = _run_mutation_service.change_experience_in_place(
            growth, reward, {
                "transaction_token": "compat_node_reward:%d:%s" % [
                    navigation.act, navigation.current_node_id],
                "operation": "node_reward",
                "reason": "node_reward",
                "source_kind": "map_node",
                "source_id": navigation.current_node_id,
            })
        if not rewarded.get("success", false):
            navigation.restore_transaction_state(navigation_before)
            growth.replace_mutation_state(growth_before)
            return rewarded
    var interest: Dictionary = _run_mutation_service.settle_experience_interest_in_place(
        growth, {
            "settlement_token": "compat_node_interest:%d:%s" % [
                navigation.act, navigation.current_node_id],
            "source_kind": "run_rule",
            "source_id": "experience_interest",
        })
    if not interest.get("success", false):
        navigation.restore_transaction_state(navigation_before)
        growth.replace_mutation_state(growth_before)
        return interest
    result["experience_interest"] = interest
    result["experience"] = growth.experience
    growth.clear_practice_purchases()
    changed.emit()
    return result

func complete_boss_chest() -> Dictionary:
    if navigation.phase != "boss_chest":
        return {"success": false, "reason": "当前没有待完成的 Boss 宝箱"}
    var navigation_before: Dictionary = navigation.capture_transaction_state()
    var growth_before: Dictionary = growth.capture_mutation_state()
    var interest: Dictionary = _run_mutation_service \
        .settle_experience_interest_in_place(growth, {
            "settlement_token": "compat_boss_interest:%d" % navigation.act,
            "source_kind": "run_rule",
            "source_id": "experience_interest",
        })
    if not interest.get("success", false):
        return interest
    var result: Dictionary = navigation.complete_boss_chest()
    if result.get("success", false):
        result["experience_interest"] = interest
        result["experience"] = growth.experience
        changed.emit()
    else:
        navigation.restore_transaction_state(navigation_before)
        growth.replace_mutation_state(growth_before)
    return result

func node_definition(node_id: String) -> Dictionary:
    return navigation.node_definition(node_id)

func node_dispatch_context() -> Dictionary:
    return navigation.node_dispatch_context()

func can_open_practice() -> bool:
    return navigation.can_open_practice()

func purchase_consumable(consumable_id: String, price: int) -> Dictionary:
    if not navigation.can_open_practice():
        return {"success": false, "reason": "节点进行中不能修习"}
    if growth.practice_purchases.has(consumable_id):
        return {"success": false, "reason": "本次修习已购买"}
    var capacity: Dictionary = growth.effective_consumable_capacity_result()
    if not capacity.get("success", false):
        return capacity
    if int(capacity.get("available_slots", 0)) <= 0:
        return {"success": false, "reason": "共享消耗品栏已满"}
    var working = growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立兼容购买工作副本"}
    var token := "compat_consumable_purchase:%s" % consumable_id
    var paid: Dictionary = _run_mutation_service.change_experience_in_place(
        working, -price, {
            "transaction_token": token,
            "operation_token": "%s:price" % token,
            "operation": "practice_purchase",
            "reason": "practice_purchase",
            "source_kind": "practice",
            "source_id": consumable_id,
        })
    if not paid.get("success", false):
        return paid
    working.consumable_ids.append(consumable_id)
    working.practice_purchases[consumable_id] = true
    working.refresh_consumable_capacity_state()
    var errors: Array = growth.replace_mutation_state(working.capture_mutation_state())
    var result: Dictionary = {
        "success": errors.is_empty(),
        "reason": "；".join(errors),
        "remaining_experience": growth.experience,
        "experience_change": paid,
    }
    if result.get("success", false):
        changed.emit()
    return result

func apply_insight_growth(
        hand_id: String,
        candidates: Array = [],
        rng = null,
        source_metadata: Dictionary = {}) -> Dictionary:
    var result: Dictionary = growth.apply_insight_growth(
        hand_id, candidates, rng, source_metadata)
    if result.get("success", false):
        changed.emit()
    return result

func get_hand_technique_loadout(hand_id: String) -> Dictionary:
    return growth.get_hand_technique_loadout(hand_id)

func set_hand_technique_loadout(hand_id: String, technique_ids: Array) -> Dictionary:
    var result: Dictionary = growth.set_hand_technique_loadout(hand_id, technique_ids)
    if result.get("success", false):
        changed.emit()
    return result

func apply_to_battle_side(side) -> void:
    growth.apply_to_battle_side(side)

func sync_from_battle_side(side) -> void:
    growth.sync_from_battle_side(side)
    changed.emit()
