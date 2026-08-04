class_name ComboRunState
extends RefCounted

signal changed

const MapGeneratorScript = preload("res://core/map_generator.gd")

var map_generator = MapGeneratorScript.new()
var seed: int = 2308
var act: int = 1
var experience: int = 0
var phase: String = "awaiting_node"
var graph: Dictionary = {}
var current_node_id: String = ""
var completed_node_ids: Dictionary = {}
var consumable_ids: Array[String] = []
var insight_multipliers: Dictionary = {}
var learned_technique_ids: Array[String] = []
var deck_modifiers: Dictionary = {}
var practice_purchases: Dictionary = {}

func setup(seed_value: int = 2308) -> void:
    seed = seed_value
    act = 1
    experience = 0
    phase = "awaiting_node"
    current_node_id = ""
    completed_node_ids.clear()
    consumable_ids.clear()
    insight_multipliers.clear()
    learned_technique_ids.clear()
    deck_modifiers.clear()
    practice_purchases.clear()
    graph = map_generator.generate(_act_seed(), act)
    changed.emit()

func available_node_ids() -> Array[String]:
    var result: Array[String] = []
    if phase != "awaiting_node":
        return result
    if current_node_id == "":
        for node in graph.get("nodes", []):
            if int(node["row"]) == 0:
                result.append(str(node["id"]))
        return result
    for edge in graph.get("edges", []):
        if str(edge["from"]) == current_node_id:
            result.append(str(edge["to"]))
    return result

func begin_node(node_id: String) -> Dictionary:
    if phase != "awaiting_node" or not available_node_ids().has(node_id):
        return {"success": false, "reason": "该节点当前不可选择"}
    current_node_id = node_id
    phase = "node_in_progress"
    changed.emit()
    return {"success": true, "node": node_definition(node_id)}

func complete_current_node() -> Dictionary:
    if phase != "node_in_progress" or current_node_id == "":
        return {"success": false, "reason": "当前没有进行中的节点"}
    var node := node_definition(current_node_id)
    var reward := _reward_for_type(str(node.get("type", "")))
    experience += reward
    completed_node_ids[current_node_id] = true
    practice_purchases.clear()
    if str(node.get("type", "")) == "boss":
        if act >= int(map_generator.rules.get("acts", 3)):
            phase = "run_complete"
        else:
            act += 1
            current_node_id = ""
            completed_node_ids.clear()
            graph = map_generator.generate(_act_seed(), act)
            phase = "awaiting_node"
    else:
        phase = "awaiting_node"
    changed.emit()
    return {"success": true, "reward": reward, "node": node, "phase": phase}

func node_definition(node_id: String) -> Dictionary:
    for node in graph.get("nodes", []):
        if str(node["id"]) == node_id:
            return node
    return {}

func can_open_practice() -> bool:
    return phase == "awaiting_node"

func purchase_consumable(consumable_id: String, price: int) -> Dictionary:
    if not can_open_practice():
        return {"success": false, "reason": "节点进行中不能修习"}
    if practice_purchases.has(consumable_id):
        return {"success": false, "reason": "本次修习已购买"}
    if consumable_ids.size() >= 3:
        return {"success": false, "reason": "共享消耗品栏已满"}
    if experience < price:
        return {"success": false, "reason": "历练不足"}
    experience -= price
    consumable_ids.append(consumable_id)
    practice_purchases[consumable_id] = true
    changed.emit()
    return {"success": true, "remaining_experience": experience}

func apply_to_battle_side(side) -> void:
    side.configure_consumables(consumable_ids)
    side.insight_multipliers = insight_multipliers.duplicate(true)
    for technique_id in learned_technique_ids:
        side.learn_technique(technique_id)
    for zone in [side.draw_pile, side.hand, side.staging, side.discard_pile]:
        for card in zone:
            var modifier: Dictionary = deck_modifiers.get(card.id, {})
            if modifier.has("enhancement"):
                card.enhancement = str(modifier["enhancement"])
            if modifier.has("edition"):
                card.edition = str(modifier["edition"])

func sync_from_battle_side(side) -> void:
    consumable_ids.clear()
    for consumable_id in side.consumable_ids:
        consumable_ids.append(str(consumable_id))
    insight_multipliers = side.insight_multipliers.duplicate(true)
    learned_technique_ids.clear()
    for technique_id in side.owned_technique_ids:
        learned_technique_ids.append(str(technique_id))
    for zone in [side.draw_pile, side.hand, side.staging, side.discard_pile]:
        for card in zone:
            if card.enhancement != "" or card.edition != "":
                deck_modifiers[card.id] = {
                    "enhancement": card.enhancement,
                    "edition": card.edition,
                }

func _reward_for_type(type_id: String) -> int:
    return {"combat": 3, "elite": 4, "boss": 5}.get(type_id, 0)

func _act_seed() -> int:
    return seed + (act - 1) * 104729
