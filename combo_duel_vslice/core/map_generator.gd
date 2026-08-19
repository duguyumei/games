class_name ComboMapGenerator
extends RefCounted

const DATA_PATH := "res://data/map_rules.json"
const START_ID := "map_start"

var rules: Dictionary = {}

func _init(rule_definition: Dictionary = {}) -> void:
    if rule_definition.is_empty():
        load_rules()
    else:
        configure(rule_definition)

func load_rules(path: String = DATA_PATH) -> bool:
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not parsed is Dictionary:
        push_error("地图规则无法解析：%s" % path)
        return false
    return configure(parsed)

func configure(definition: Dictionary) -> bool:
    rules = definition.duplicate(true)
    return not rules.is_empty()

func generate(
        seed_value: int,
        act: int = 1,
        generation_serial: int = 0) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value + _act_seed_offset(act) \
        + int(generation_serial) * 104729
    var width: int = int(rules.get("width", 7))
    var route_rows: int = int(rules.get("route_rows", 15))
    var path_count: int = int(rules.get("path_count", 6))
    var boss_column: int = int(rules.get("boss_column", width / 2))
    var grid := _create_grid(route_rows, width)

    _create_paths(grid, path_count, rng, route_rows, width)
    _trim_redundant_first_floor_edges(grid)
    _assign_node_types(grid, rng, route_rows, width)

    var nodes: Array = [{
        "id": START_ID,
        "row": -1,
        "column": boss_column,
        "type": "start",
        "generation_type": "start",
    }]
    var edges: Array = []
    for row in range(route_rows):
        for column in range(width):
            if not _is_active(grid, row, column, route_rows):
                continue
            var source: Dictionary = grid[row][column]
            var generation_type := str(source.get("type", "combat"))
            nodes.append({
                "id": _node_id(row, column),
                "row": row,
                "column": column,
                "type": _display_type(generation_type),
                "generation_type": generation_type,
            })
            for target_column_value in source["out_columns"]:
                var target_column: int = int(target_column_value)
                if _is_active(grid, row + 1, target_column, route_rows):
                    edges.append(_edge(row, column, row + 1, target_column))

    for column in range(width):
        if _is_active(grid, 0, column, route_rows):
            edges.append({
                "from": START_ID,
                "to": _node_id(0, column),
                "from_row": -1,
                "from_column": boss_column,
                "to_row": 0,
                "to_column": column,
            })

    var boss_id := _node_id(route_rows, boss_column)
    nodes.append({
        "id": boss_id,
        "row": route_rows,
        "column": boss_column,
        "type": "boss",
        "generation_type": "boss",
    })
    for column in range(width):
        if _is_active(grid, route_rows - 1, column, route_rows):
            edges.append(_edge(route_rows - 1, column, route_rows, boss_column))

    return {
        "seed": seed_value,
        "act": act,
        "generation_serial": generation_serial,
        "width": width,
        "route_rows": route_rows,
        "visual_jitter_x": float(rules.get("visual_jitter_x", 22)),
        "visual_jitter_y": float(rules.get("visual_jitter_y", 10)),
        "start_id": START_ID,
        "boss_id": boss_id,
        "boss_variant": _boss_variant(
            seed_value + int(generation_serial) * 104729, act),
        "nodes": nodes,
        "edges": edges,
    }

func _create_grid(route_rows: int, width: int) -> Array:
    var grid: Array = []
    for row in range(route_rows):
        var row_nodes: Array = []
        for column in range(width):
            row_nodes.append({
                "row": row,
                "column": column,
                "out_columns": [],
                "parent_columns": [],
                "type": "",
            })
        grid.append(row_nodes)
    return grid

func _create_paths(
        grid: Array,
        path_count: int,
        rng: RandomNumberGenerator,
        route_rows: int,
        width: int) -> void:
    var first_start := -1
    for path_index in range(path_count):
        var column := rng.randi_range(0, width - 1)
        if path_index == 0:
            first_start = column
        elif path_index == 1:
            while column == first_start:
                column = rng.randi_range(0, width - 1)
        for row in range(route_rows - 1):
            var next_column := _next_path_column(grid, row, column, rng, width)
            _connect_grid_nodes(grid, row, column, next_column)
            column = next_column

func _next_path_column(
        grid: Array,
        row: int,
        column: int,
        rng: RandomNumberGenerator,
        width: int) -> int:
    var minimum_delta := 0 if column == 0 else -1
    var maximum_delta := 0 if column == width - 1 else 1
    var next_column := column + rng.randi_range(minimum_delta, maximum_delta)
    var original_target: Dictionary = grid[row + 1][next_column]
    var minimum_gap: int = int(rules.get("minimum_remerge_gap", 3))
    var search_depth: int = int(rules.get("common_ancestor_search_depth", 5))
    var current_point := {"row": row, "column": column}

    for parent_column_value in original_target["parent_columns"]:
        var parent_column: int = int(parent_column_value)
        if parent_column == column:
            continue
        var ancestor := _common_ancestor(
            grid,
            {"row": row, "column": parent_column},
            current_point,
            search_depth)
        if ancestor.is_empty() or row + 1 - int(ancestor["row"]) >= minimum_gap:
            continue
        if next_column > column:
            next_column = column + rng.randi_range(-1, 0)
            if next_column < 0:
                next_column = column
        elif next_column == column:
            next_column = column + rng.randi_range(-1, 1)
            if next_column >= width:
                next_column = column - 1
            elif next_column < 0:
                next_column = column + 1
        else:
            next_column = column + rng.randi_range(0, 1)
            if next_column >= width:
                next_column = column

    if column > 0:
        var left_destinations: Array = grid[row][column - 1]["out_columns"]
        if not left_destinations.is_empty():
            var rightmost_left: int = int(left_destinations.max())
            if rightmost_left > next_column:
                next_column = rightmost_left
    if column < width - 1:
        var right_destinations: Array = grid[row][column + 1]["out_columns"]
        if not right_destinations.is_empty():
            var leftmost_right: int = int(right_destinations.min())
            if leftmost_right < next_column:
                next_column = leftmost_right
    return clampi(next_column, 0, width - 1)

func _common_ancestor(
        grid: Array,
        first: Dictionary,
        second: Dictionary,
        max_depth: int) -> Dictionary:
    if int(first["row"]) != int(second["row"]) \
            or int(first["column"]) == int(second["column"]):
        return {}
    var compare_against: int = int(second["row"]) if bool(rules.get("legacy_common_ancestor_comparison", true)) \
        else int(second["column"])
    var left: Dictionary = first if int(first["column"]) < compare_against else second
    var right: Dictionary = second if left == first else first
    var depth := 0
    while int(left["row"]) >= 0 and depth <= max_depth:
        var left_parents := _parent_points(grid, left)
        var right_parents := _parent_points(grid, right)
        if left_parents.is_empty() or right_parents.is_empty():
            return {}
        left = _point_with_extreme_column(left_parents, true)
        right = _point_with_extreme_column(right_parents, false)
        if int(left["row"]) == int(right["row"]) \
                and int(left["column"]) == int(right["column"]):
            return left
        depth += 1
    return {}

func _parent_points(grid: Array, point: Dictionary) -> Array:
    var row: int = int(point["row"])
    if row <= 0:
        return []
    var result: Array = []
    for parent_column in grid[row][int(point["column"])]["parent_columns"]:
        result.append({"row": row - 1, "column": int(parent_column)})
    return result

func _point_with_extreme_column(points: Array, maximum: bool) -> Dictionary:
    var selected: Dictionary = points[0]
    for point in points:
        if maximum and int(point["column"]) > int(selected["column"]):
            selected = point
        elif not maximum and int(point["column"]) < int(selected["column"]):
            selected = point
    return selected

func _connect_grid_nodes(grid: Array, row: int, column: int, next_column: int) -> void:
    var source: Dictionary = grid[row][column]
    var target: Dictionary = grid[row + 1][next_column]
    if not source["out_columns"].has(next_column):
        source["out_columns"].append(next_column)
        source["out_columns"].sort()
    if not target["parent_columns"].has(column):
        target["parent_columns"].append(column)
        target["parent_columns"].sort()

func _trim_redundant_first_floor_edges(grid: Array) -> void:
    var used_destinations: Dictionary = {}
    for column in range(grid[0].size()):
        var source: Dictionary = grid[0][column]
        var retained: Array = []
        for destination_value in source["out_columns"]:
            var destination: int = int(destination_value)
            if used_destinations.has(destination):
                pass
            else:
                used_destinations[destination] = true
                retained.append(destination)
        source["out_columns"] = retained

func _assign_node_types(
        grid: Array,
        rng: RandomNumberGenerator,
        route_rows: int,
        width: int) -> void:
    var fixed_rows: Dictionary = rules.get("fixed_rows", {})
    for row in range(route_rows):
        var row_key := str(row)
        if not fixed_rows.has(row_key):
            continue
        for column in range(width):
            if _is_active(grid, row, column, route_rows):
                grid[row][column]["type"] = str(fixed_rows[row_key])

    var room_pool := _build_room_pool(_room_count_basis(grid, route_rows, width))
    _shuffle(room_pool, rng)
    for row in range(route_rows):
        for column in range(width):
            if not _is_active(grid, row, column, route_rows):
                continue
            var node: Dictionary = grid[row][column]
            if str(node["type"]) != "" or node["out_columns"].is_empty():
                continue
            var selected_index := -1
            for pool_index in range(room_pool.size()):
                if _can_assign_type(grid, row, column, str(room_pool[pool_index])):
                    selected_index = pool_index
                    break
            if selected_index >= 0:
                node["type"] = str(room_pool[selected_index])
                room_pool.remove_at(selected_index)
            else:
                node["type"] = "combat"

    for row in range(route_rows):
        for column in range(width):
            if _is_active(grid, row, column, route_rows) \
                    and str(grid[row][column]["type"]) == "":
                grid[row][column]["type"] = "combat"

func _room_count_basis(grid: Array, route_rows: int, width: int) -> int:
    var count := 0
    for row in range(route_rows):
        if row == route_rows - 2:
            continue
        for column in range(width):
            if _is_active(grid, row, column, route_rows):
                count += 1
    return count

func _build_room_pool(room_count: int) -> Array:
    var pool: Array = []
    var weights: Dictionary = rules.get("weights", {})
    for type_value in rules.get("pool_order", ["rest", "elite", "event"]):
        var type_id := str(type_value)
        var type_count := int(round(room_count * float(weights.get(type_id, 0)) / 100.0))
        for _index in range(type_count):
            pool.append(type_id)
    while pool.size() < room_count:
        pool.append("combat")
    return pool

func _display_type(generation_type: String) -> String:
    return str(rules.get("display_types", {}).get(generation_type, generation_type))

func _can_assign_type(
        grid: Array,
        row: int,
        column: int,
        type_id: String) -> bool:
    var minimum_rows: Dictionary = rules.get("minimum_random_row", {})
    if minimum_rows.has(type_id) and row < int(minimum_rows[type_id]):
        return false
    var maximum_rows: Dictionary = rules.get("maximum_random_row", {})
    if maximum_rows.has(type_id) and row > int(maximum_rows[type_id]):
        return false
    if type_id in rules.get("no_direct_repeat", []):
        for parent_column in grid[row][column]["parent_columns"]:
            if str(grid[row - 1][int(parent_column)]["type"]) == type_id:
                return false
    if bool(rules.get("sibling_types_must_differ", true)):
        for parent_column in grid[row][column]["parent_columns"]:
            for sibling_column in grid[row - 1][int(parent_column)]["out_columns"]:
                if int(sibling_column) == column:
                    continue
                if str(grid[row][int(sibling_column)]["type"]) == type_id:
                    return false
    return true

func _is_active(grid: Array, row: int, column: int, route_rows: int) -> bool:
    if row < 0 or row >= route_rows:
        return false
    var node: Dictionary = grid[row][column]
    if row == 0:
        return not node["out_columns"].is_empty()
    if row == route_rows - 1:
        return not node["parent_columns"].is_empty()
    return not node["parent_columns"].is_empty() and not node["out_columns"].is_empty()

func _edge(from_row: int, from_column: int, to_row: int, to_column: int) -> Dictionary:
    return {
        "from": _node_id(from_row, from_column),
        "to": _node_id(to_row, to_column),
        "from_row": from_row,
        "from_column": from_column,
        "to_row": to_row,
        "to_column": to_column,
    }

func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
    for index in range(values.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = values[index]
        values[index] = values[other]
        values[other] = temporary

func _act_seed_offset(act: int) -> int:
    var offsets: Array = rules.get("act_seed_offsets", [1, 200, 600])
    if offsets.is_empty():
        return 0
    return int(offsets[clampi(act - 1, 0, offsets.size() - 1)])

func _boss_variant(seed_value: int, act: int) -> int:
    var count: int = maxi(1, int(rules.get("boss_variant_count", 3)))
    var boss_rng := RandomNumberGenerator.new()
    boss_rng.seed = seed_value + _act_seed_offset(act) + 32452843
    return boss_rng.randi_range(0, count - 1)

func _node_id(row: int, column: int) -> String:
    return "%d_%d" % [row, column]
