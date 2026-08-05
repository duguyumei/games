class_name ComboMapView
extends Control

const FLOOR_SPACING := 96.0
const LEFT_GUTTER := 84.0
const RIGHT_ACTION_GUTTER := 210.0

signal node_selected(node_id: String)
signal node_hovered(description: String)

const TYPE_LABELS := {
    "start": "始",
    "combat": "战",
    "elite": "精",
    "event": "?",
    "rest": "息",
    "treasure": "藏",
    "boss": "首",
}

const TYPE_COLORS := {
    "start": Color("d0a94b"),
    "combat": Color("b54d46"),
    "elite": Color("8d4ca8"),
    "event": Color("3e86a6"),
    "rest": Color("4e9b68"),
    "treasure": Color("c18a31"),
    "boss": Color("bd3d37"),
}

var run_snapshot: Dictionary = {}
var hovered_node_id: String = ""

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    resized.connect(queue_redraw)

func set_snapshot(value: Dictionary) -> void:
    run_snapshot = value.duplicate(true)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("121a20"), true)
    for y in range(0, int(size.y), 48):
        draw_line(Vector2(0, y), Vector2(size.x, y + 22), Color(0.18, 0.28, 0.3, 0.08), 1.0)
    var graph: Dictionary = run_snapshot.get("graph", {})
    if graph.is_empty():
        return
    var route_rows: int = int(graph.get("route_rows", 15))
    for row in range(route_rows + 1):
        var row_y := _node_position(row, 0).y
        draw_line(Vector2(34, row_y), Vector2(size.x - 34, row_y), Color(0.6, 0.7, 0.68, 0.055), 1.0)
    var available: Array[String] = []
    for node_id in run_snapshot.get("available_node_ids", []):
        available.append(str(node_id))
    var completed: Dictionary = run_snapshot.get("completed_node_ids", {})
    for edge in graph.get("edges", []):
        var from_position := _node_position(int(edge["from_row"]), int(edge["from_column"]))
        var to_position := _node_position(int(edge["to_row"]), int(edge["to_column"]))
        var color := Color("46545b")
        var width := 2.0
        if (str(edge["from"]) == str(graph.get("start_id", "")) \
                or completed.has(str(edge["from"]))) \
                and available.has(str(edge["to"])):
            color = Color("e7bd55")
            width = 4.0
        elif completed.has(str(edge["from"])) and completed.has(str(edge["to"])):
            color = Color("5fa879")
            width = 4.0
        draw_line(from_position, to_position, color, width, true)

    for node in graph.get("nodes", []):
        _draw_node(node, available, completed)

func _draw_node(node: Dictionary, available: Array[String], completed: Dictionary) -> void:
    var node_id: String = node["id"]
    var type_id: String = node["type"]
    var position := _node_position(int(node["row"]), int(node["column"]))
    var radius := 23.0 if type_id == "boss" else (15.0 if type_id == "start" else 18.0)
    var fill: Color = TYPE_COLORS.get(type_id, Color("59616a")).darkened(0.28)
    var border := Color("667279")
    var border_width := 2.0
    if type_id == "start":
        fill = Color("604b24")
        border = Color("f0c75e")
        border_width = 4.0
    elif completed.has(node_id):
        fill = Color("294d3a")
        border = Color("72ba89")
        border_width = 4.0
    elif available.has(node_id):
        fill = TYPE_COLORS.get(type_id, Color("59616a")).darkened(0.05)
        border = Color("f1c85c")
        border_width = 4.0
    elif hovered_node_id == node_id:
        border = Color("d7e2df")
        border_width = 3.0
    draw_circle(position, radius + border_width, border)
    draw_circle(position, radius, fill)
    var label: String = TYPE_LABELS.get(type_id, "·")
    draw_string(
        ThemeDB.fallback_font,
        position + Vector2(-18, 6),
        label,
        HORIZONTAL_ALIGNMENT_CENTER,
        36,
        15 if type_id != "boss" else 17,
        Color("fff3d2"))

func _gui_input(event: InputEvent) -> void:
    if run_snapshot.is_empty():
        return
    if event is InputEventMouseMotion:
        var nearest := _node_at(event.position)
        var new_hover := str(nearest.get("id", ""))
        if new_hover != hovered_node_id:
            hovered_node_id = new_hover
            if nearest.is_empty():
                node_hovered.emit("")
            else:
                node_hovered.emit(_node_description(nearest))
            queue_redraw()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var node := _node_at(event.position)
        if not node.is_empty() and run_snapshot.get("available_node_ids", []).has(str(node["id"])):
            node_selected.emit(str(node["id"]))
            accept_event()

func _node_at(mouse_position: Vector2) -> Dictionary:
    for node in run_snapshot.get("graph", {}).get("nodes", []):
        var position := _node_position(int(node["row"]), int(node["column"]))
        if position.distance_to(mouse_position) <= 26.0:
            return node
    return {}

func _node_position(row: int, column: int) -> Vector2:
    var graph: Dictionary = run_snapshot.get("graph", {})
    var width: int = int(graph.get("width", 7))
    var horizontal_space := maxf(1.0, size.x - LEFT_GUTTER - RIGHT_ACTION_GUTTER)
    var x := LEFT_GUTTER if width <= 1 \
        else LEFT_GUTTER + horizontal_space * column / float(width - 1)
    if row < 0:
        return Vector2(LEFT_GUTTER + horizontal_space * 0.5, size.y - 54.0)
    var y := size.y - 150.0 - FLOOR_SPACING * row
    return Vector2(x, y) + _visual_jitter(row, column)

func _visual_jitter(row: int, column: int) -> Vector2:
    var graph: Dictionary = run_snapshot.get("graph", {})
    var seed_value: int = int(graph.get("seed", 0))
    var act_value: int = int(graph.get("act", 1))
    var mixed: int = absi(seed_value * 1103515245 + act_value * 12345 + row * 265443576 + column * 97531)
    var quotient: int = mixed / 1001
    var jitter_x: float = float(mixed % 1001) / 1000.0 - 0.5
    var jitter_y: float = float(quotient % 1001) / 1000.0 - 0.5
    var range_x: float = float(graph.get("visual_jitter_x", 22))
    var range_y: float = float(graph.get("visual_jitter_y", 10))
    return Vector2(jitter_x * range_x * 2.0, jitter_y * range_y * 2.0)

func _node_description(node: Dictionary) -> String:
    if str(node.get("type", "")) == "start":
        return "旅程起点 · 选择上方第 1 层房间开始路线"
    var type_names := {
        "combat": "普通战斗",
        "elite": "精英战斗",
        "event": "事件",
        "rest": "休息",
        "treasure": "宝箱／特殊奖励",
        "boss": "层末 Boss",
    }
    return "第 %d 行 · %s" % [int(node["row"]) + 1, type_names.get(node["type"], "未知节点")]
