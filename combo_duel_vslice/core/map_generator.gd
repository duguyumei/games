class_name ComboMapGenerator
extends RefCounted

const DATA_PATH := "res://data/map_rules.json"

var rules: Dictionary = {}

func _init() -> void:
    load_rules()

func load_rules(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("地图规则无法解析：%s" % path)
        return false
    rules = parsed.duplicate(true)
    return true

func generate(seed_value: int, act: int = 1) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var width: int = int(rules.get("width", 7))
    var route_rows: int = int(rules.get("route_rows", 15))
    var path_count: int = int(rules.get("path_count", 6))
    var boss_column: int = int(rules.get("boss_column", width / 2))
    var nodes_by_id: Dictionary = {}
    var edges: Array = []
    var edge_keys: Dictionary = {}
    var start_columns: Array = []
    for column in range(width):
        start_columns.append(column)
    _shuffle(start_columns, rng)

    for path_index in range(path_count):
        var column: int = int(start_columns[path_index % start_columns.size()])
        _ensure_node(nodes_by_id, 0, column)
        for row in range(route_rows - 1):
            var candidates: Array = []
            for next_column in [column - 1, column, column + 1]:
                if next_column >= 0 and next_column < width:
                    candidates.append(next_column)
            _shuffle(candidates, rng)
            var chosen: int = int(candidates[0])
            for candidate_value in candidates:
                var candidate: int = int(candidate_value)
                if not _would_cross(edges, row, column, candidate):
                    chosen = candidate
                    break
            var from_id := _node_id(row, column)
            var to_id := _node_id(row + 1, chosen)
            _ensure_node(nodes_by_id, row, column)
            _ensure_node(nodes_by_id, row + 1, chosen)
            _add_edge(edges, edge_keys, from_id, to_id, row, column, row + 1, chosen)
            column = chosen

    var boss_id := _node_id(route_rows, boss_column)
    nodes_by_id[boss_id] = {
        "id": boss_id,
        "row": route_rows,
        "column": boss_column,
        "type": "boss",
    }
    for node in nodes_by_id.values():
        if int(node["row"]) == route_rows - 1:
            _add_edge(
                edges, edge_keys, node["id"], boss_id,
                route_rows - 1, int(node["column"]), route_rows, boss_column)

    _assign_node_types(nodes_by_id, edges, rng, route_rows)
    var nodes: Array = nodes_by_id.values()
    nodes.sort_custom(func(left, right):
        if int(left["row"]) == int(right["row"]):
            return int(left["column"]) < int(right["column"])
        return int(left["row"]) < int(right["row"]))
    return {
        "seed": seed_value,
        "act": act,
        "width": width,
        "route_rows": route_rows,
        "boss_id": boss_id,
        "nodes": nodes,
        "edges": edges,
    }

func _assign_node_types(
        nodes_by_id: Dictionary,
        edges: Array,
        rng: RandomNumberGenerator,
        route_rows: int) -> void:
    var fixed_rows: Dictionary = rules.get("fixed_rows", {})
    for node in nodes_by_id.values():
        var row_key := str(node["row"])
        if int(node["row"]) == route_rows:
            node["type"] = "boss"
        elif fixed_rows.has(row_key):
            node["type"] = str(fixed_rows[row_key])

    var ordered: Array = nodes_by_id.values()
    ordered.sort_custom(func(left, right):
        if int(left["row"]) == int(right["row"]):
            return int(left["column"]) < int(right["column"])
        return int(left["row"]) < int(right["row"]))
    for node in ordered:
        if str(node.get("type", "")) != "":
            continue
        var weights: Dictionary = rules.get("weights", {}).duplicate(true)
        var minimum_rows: Dictionary = rules.get("minimum_random_row", {})
        for type_id in minimum_rows:
            if int(node["row"]) < int(minimum_rows[type_id]):
                weights.erase(type_id)
        for repeated_type in rules.get("no_direct_repeat", []):
            var type_id := str(repeated_type)
            if _has_parent_type(node["id"], type_id, nodes_by_id, edges):
                weights.erase(type_id)
            if _has_fixed_child_type(node["id"], type_id, nodes_by_id, edges):
                weights.erase(type_id)
        node["type"] = _weighted_type(weights, rng)

func _weighted_type(weights: Dictionary, rng: RandomNumberGenerator) -> String:
    var keys: Array = weights.keys()
    keys.sort()
    var total := 0
    for key in keys:
        total += maxi(0, int(weights[key]))
    if total <= 0:
        return "combat"
    var roll := rng.randi_range(1, total)
    var cursor := 0
    for key in keys:
        cursor += maxi(0, int(weights[key]))
        if roll <= cursor:
            return str(key)
    return "combat"

func _has_parent_type(node_id: String, type_id: String, nodes: Dictionary, edges: Array) -> bool:
    for edge in edges:
        if edge["to"] == node_id and str(nodes[edge["from"]].get("type", "")) == type_id:
            return true
    return false

func _has_fixed_child_type(node_id: String, type_id: String, nodes: Dictionary, edges: Array) -> bool:
    for edge in edges:
        if edge["from"] == node_id and str(nodes[edge["to"]].get("type", "")) == type_id:
            return true
    return false

func _ensure_node(nodes: Dictionary, row: int, column: int) -> void:
    var id := _node_id(row, column)
    if not nodes.has(id):
        nodes[id] = {"id": id, "row": row, "column": column, "type": ""}

func _add_edge(
        edges: Array,
        edge_keys: Dictionary,
        from_id: String,
        to_id: String,
        from_row: int,
        from_column: int,
        to_row: int,
        to_column: int) -> void:
    var key := "%s>%s" % [from_id, to_id]
    if edge_keys.has(key):
        return
    edge_keys[key] = true
    edges.append({
        "from": from_id,
        "to": to_id,
        "from_row": from_row,
        "from_column": from_column,
        "to_row": to_row,
        "to_column": to_column,
    })

func _would_cross(edges: Array, row: int, from_column: int, to_column: int) -> bool:
    for edge in edges:
        if int(edge["from_row"]) != row:
            continue
        var other_from: int = int(edge["from_column"])
        var other_to: int = int(edge["to_column"])
        if other_from == from_column or other_to == to_column:
            continue
        if (from_column < other_from and to_column > other_to) \
                or (from_column > other_from and to_column < other_to):
            return true
    return false

func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
    for index in range(values.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = values[index]
        values[index] = values[other]
        values[other] = temporary

func _node_id(row: int, column: int) -> String:
    return "%d_%d" % [row, column]
