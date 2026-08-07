class_name MapNavigationService
extends RefCounted

const MapGeneratorScript = preload("res://core/map_generator.gd")

var map_generator
var seed: int = 2308
var act: int = 1
var phase: String = "awaiting_node"
var graph: Dictionary = {}
var current_node_id: String = ""
var completed_node_ids: Dictionary = {}

func _init(map_generator_override = null) -> void:
    map_generator = (
        map_generator_override
        if map_generator_override != null
        else MapGeneratorScript.new())

func setup(seed_value: int = 2308) -> void:
    seed = seed_value
    act = 1
    phase = "awaiting_node"
    current_node_id = ""
    completed_node_ids.clear()
    graph = map_generator.generate(seed, act)

func available_node_ids() -> Array[String]:
    var result: Array[String] = []
    if phase != "awaiting_node":
        return result
    if current_node_id == "":
        var start_id := str(graph.get("start_id", ""))
        for edge in graph.get("edges", []):
            if str(edge["from"]) == start_id:
                result.append(str(edge["to"]))
        if result.is_empty():
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
    return {"success": true, "node": node_definition(node_id)}

func complete_current_node() -> Dictionary:
    var prepared := complete_current_node_to_reward()
    if not prepared.get("success", false):
        return prepared
    var claimed := claim_current_node_reward()
    if not claimed.get("success", false):
        return claimed
    claimed["reward"] = _reward_for_type(str(prepared["node"].get("type", "")))
    return claimed

func complete_current_node_to_reward() -> Dictionary:
    if phase != "node_in_progress" or current_node_id == "":
        return {"success": false, "reason": "当前没有进行中的节点"}
    var node := node_definition(current_node_id)
    completed_node_ids[current_node_id] = true
    phase = "awaiting_reward"
    return {"success": true, "node": node, "phase": phase}

func claim_current_node_reward() -> Dictionary:
    if phase != "awaiting_reward" or current_node_id == "":
        return {"success": false, "reason": "当前没有待领取的节点奖励"}
    var node := node_definition(current_node_id)
    var reward := _reward_for_type(str(node.get("type", "")))
    if str(node.get("type", "")) == "boss":
        if _act_has_boss_chest():
            phase = "boss_chest"
        elif act >= int(map_generator.rules.get("acts", 3)):
            phase = "run_complete"
        else:
            _advance_act()
    else:
        phase = "awaiting_node"
    return {"success": true, "reward": reward, "node": node, "phase": phase}

func complete_boss_chest() -> Dictionary:
    if phase != "boss_chest":
        return {"success": false, "reason": "当前没有待完成的 Boss 宝箱"}
    _advance_act()
    return {"success": true, "act": act, "phase": phase}

func node_definition(node_id: String) -> Dictionary:
    for node in graph.get("nodes", []):
        if str(node["id"]) == node_id:
            return node
    return {}

func node_dispatch_context() -> Dictionary:
    return {
        "seed": seed,
        "act": act,
        "boss_variant": int(graph.get("boss_variant", -1)),
    }

func can_open_practice() -> bool:
    return phase == "awaiting_node"

func _reward_for_type(type_id: String) -> int:
    return {"combat": 3, "elite": 4, "boss": 5}.get(type_id, 0)

func _advance_act() -> void:
    act += 1
    current_node_id = ""
    completed_node_ids.clear()
    graph = map_generator.generate(seed, act)
    phase = "awaiting_node"

func _act_has_boss_chest() -> bool:
    for chest_act in map_generator.rules.get("boss_chest_acts", [1, 2]):
        if int(chest_act) == act:
            return true
    return false
