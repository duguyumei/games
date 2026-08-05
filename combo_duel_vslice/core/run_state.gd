class_name ComboRunState
extends RefCounted

signal changed

const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")

var navigation = MapNavigationServiceScript.new()
var growth = GrowthInventoryScript.new()

func _init(navigation_override = null, growth_override = null) -> void:
    if navigation_override != null:
        navigation = navigation_override
    if growth_override != null:
        growth = growth_override

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
var insight_multipliers: Dictionary:
    get:
        return growth.insight_multipliers
    set(value):
        growth.insight_multipliers = value
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
    growth.reset("run-%d" % seed_value)
    navigation.setup(seed_value)
    changed.emit()

func available_node_ids() -> Array[String]:
    return navigation.available_node_ids()

func begin_node(node_id: String) -> Dictionary:
    var result: Dictionary = navigation.begin_node(node_id)
    if result.get("success", false):
        changed.emit()
    return result

func complete_current_node() -> Dictionary:
    var result: Dictionary = navigation.complete_current_node()
    if not result.get("success", false):
        return result
    growth.experience += int(result.get("reward", 0))
    growth.clear_practice_purchases()
    changed.emit()
    return result

func complete_boss_chest() -> Dictionary:
    var result: Dictionary = navigation.complete_boss_chest()
    if result.get("success", false):
        changed.emit()
    return result

func node_definition(node_id: String) -> Dictionary:
    return navigation.node_definition(node_id)

func node_dispatch_context() -> Dictionary:
    return navigation.node_dispatch_context()

func can_open_practice() -> bool:
    return navigation.can_open_practice()

func purchase_consumable(consumable_id: String, price: int) -> Dictionary:
    var result: Dictionary = growth.purchase_consumable(
        consumable_id,
        price,
        navigation.can_open_practice())
    if result.get("success", false):
        changed.emit()
    return result

func apply_to_battle_side(side) -> void:
    growth.apply_to_battle_side(side)

func sync_from_battle_side(side) -> void:
    growth.sync_from_battle_side(side)
    changed.emit()
