extends Control

# 青锋剑冢·锚点编辑器（D-059 节点制的布点调整工具）
# 用法：在 Godot 编辑器打开本场景 → F6 运行 → 拖动圆点调整位置（滚轮缩放、空白处拖拽平移）
#       → 点「保存」写回 data/qingfeng_map.json（生成器与预览图都读这份图纸）。
# 铁律：舆图（纸）永不修改；节点、路网、印章全部是运行时对象。

const MAP_IMAGE := preload("res://assets/bg/qingfeng_map.png")
const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng.ttf")
const PLAIN_FONT := preload("res://assets/fonts/NotoSansSC.ttf")
const JSON_PATH := "res://data/qingfeng_map.json"
const W := 1672.0
const H := 940.0

const INK := Color("#2e2418")
const INK2 := Color("#4c3f2c")
const SEAL := Color("#a3382a")
const PAPER := Color("#ecdfbe")
const BAND_COL := {"浅": Color("#5a5346"), "中": Color("#8a6134"), "深": Color("#a3382a")}

var data: Dictionary
var viewport_area: Control
var canvas: Control
var edge_layer: Control
var node_layer: Control
var markers := {}
var status_label: Label
var dirty := false
var _panning := false
var _pan_from := Vector2.ZERO

func _ready() -> void:
	_build_ui()
	_load_from_json()
	# 首帧布局完成后按窗口适配
	await get_tree().process_frame
	_fit_view()

# ---------- UI ----------

func _build_ui() -> void:
	# 上下排布：顶栏与画布区互不重叠（早前全幅画布盖住顶栏，按钮点击被平移手势吞掉）
	var box_root := VBoxContainer.new()
	box_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	box_root.add_theme_constant_override("separation", 0)
	add_child(box_root)

	var bar := PanelContainer.new()
	box_root.add_child(bar)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	bar.add_child(box)

	var mk_btn := func(text: String) -> Button:
		var b := Button.new()
		b.text = text
		b.add_theme_font_override("font", PLAIN_FONT)
		box.add_child(b)
		return b

	var save_btn: Button = mk_btn.call("保存到 JSON")
	save_btn.pressed.connect(_save_json)
	var reload_btn: Button = mk_btn.call("重新加载")
	reload_btn.pressed.connect(func(): _load_from_json(); _fit_view())
	var fit_btn: Button = mk_btn.call("复位视图")
	fit_btn.pressed.connect(_fit_view)

	var names_cb := CheckButton.new()
	names_cb.text = "地名"
	names_cb.button_pressed = true
	names_cb.toggled.connect(func(on: bool):
		for id in markers: markers[id].show_name = on; markers[id].queue_redraw())
	box.add_child(names_cb)

	var roads_cb := CheckButton.new()
	roads_cb.text = "路网"
	roads_cb.button_pressed = true
	roads_cb.toggled.connect(func(on: bool): edge_layer.visible = on)
	box.add_child(roads_cb)

	status_label = Label.new()
	status_label.add_theme_font_override("font", PLAIN_FONT)
	status_label.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	box.add_child(status_label)

	viewport_area = Control.new()
	viewport_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_area.clip_contents = true
	viewport_area.gui_input.connect(_on_viewport_input)
	box_root.add_child(viewport_area)

	canvas = Control.new()
	viewport_area.add_child(canvas)

	var bg := TextureRect.new()
	bg.texture = MAP_IMAGE
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(bg)

	edge_layer = Control.new()
	edge_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_layer.draw.connect(_draw_roads)
	canvas.add_child(edge_layer)

	node_layer = Control.new()
	node_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(node_layer)

# ---------- 数据 ----------

func _load_from_json() -> void:
	for id in markers:
		markers[id].queue_free()
	markers.clear()
	var f := FileAccess.open(JSON_PATH, FileAccess.READ)
	if f == null:
		status_label.text = "找不到 data/qingfeng_map.json"
		return
	data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		status_label.text = "JSON 解析失败"
		return

	var badges := {}  # node_id -> [印章字]
	for s in data.get("spawns", []):
		badges.get_or_add(str(s["node"]), []).append("入")
	for x in data.get("extracts", []):
		badges.get_or_add(str(x["node"]), []).append("撤")
	badges.get_or_add("jz_master", []).append("掌")

	for n in data.get("nodes", []):
		var mk := AnchorMark.new(str(n["id"]), str(n["name"]), BAND_COL.get(str(n["band"]), INK2),
			str(n["tier"]) == "hub", badges.get(str(n["id"]), []))
		mk.moved.connect(_on_marker_moved)
		node_layer.add_child(mk)
		mk.position = Vector2(float(n["x"]) * W, float(n["y"]) * H) - mk.size / 2.0
		markers[str(n["id"])] = mk
	dirty = false
	_refresh_status()
	edge_layer.queue_redraw()

func _refresh_status() -> void:
	status_label.text = "%d 节点·%d 边%s" % [data.get("nodes", []).size(), data.get("edges", []).size(),
		"·未保存" if dirty else ""]

func _on_marker_moved() -> void:
	dirty = true
	_refresh_status()
	edge_layer.queue_redraw()

func _save_json() -> void:
	for n in data.get("nodes", []):
		var mk: Control = markers.get(str(n["id"]))
		if mk == null:
			continue
		var center := mk.position + mk.size / 2.0
		n["x"] = snappedf(center.x / W, 0.0005)
		n["y"] = snappedf(center.y / H, 0.0005)
	var f := FileAccess.open(JSON_PATH, FileAccess.WRITE)
	if f == null:
		status_label.text = "保存失败：错误码 %d（文件被占用？）" % FileAccess.get_open_error()
		return
	f.store_string(JSON.stringify(data, "\t", false, true))
	f.close()
	dirty = false
	var time := Time.get_time_string_from_system().substr(0, 5)
	status_label.text = "已保存 ✓ %d 节点 → data/qingfeng_map.json（%s）" % [data.get("nodes", []).size(), time]
	print("[map_editor] 已保存 ", ProjectSettings.globalize_path(JSON_PATH))

# ---------- 视图（缩放/平移） ----------

func _fit_view() -> void:
	var s := minf(viewport_area.size.x / W, viewport_area.size.y / H) * 0.96
	canvas.scale = Vector2(s, s)
	canvas.position = (viewport_area.size - Vector2(W, H) * s) / 2.0

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_panning = event.pressed
			_pan_from = event.position
	elif event is InputEventMouseMotion and _panning:
		canvas.position += event.position - _pan_from
		_pan_from = event.position

func _zoom_at(factor: float, at: Vector2) -> void:
	var old := canvas.scale.x
	var new := clampf(old * factor, 0.3, 4.0)
	if is_equal_approx(old, new):
		return
	var map_point := (at - canvas.position) / old
	canvas.scale = Vector2(new, new)
	canvas.position = at - map_point * new

# ---------- 路网绘制 ----------

func _draw_roads() -> void:
	if data.is_empty():
		return
	for e in data.get("edges", []):
		if not (markers.has(str(e["a"])) and markers.has(str(e["b"]))):
			continue
		var a := _center(str(e["a"]))
		var b := _center(str(e["b"]))
		var cost := int(e.get("cost", 1))
		if cost == 1:
			edge_layer.draw_line(a, b, Color(INK2, 0.5), 1.6)
		elif cost == 2:
			edge_layer.draw_dashed_line(a, b, Color(INK2, 0.5), 1.6, 6)
		else:
			edge_layer.draw_dashed_line(a, b, Color(INK2, 0.5), 1.6, 3)
	for s in data.get("secrets", []):
		if not (markers.has(str(s["a"])) and markers.has(str(s["b"]))):
			continue
		var a := _center(str(s["a"]))
		var b := _center(str(s["b"]))
		edge_layer.draw_dashed_line(a, b, Color(SEAL, 0.75), 2.2, 4)

func _center(id: String) -> Vector2:
	var mk: Control = markers[id]
	return mk.position + mk.size / 2.0

# ---------- 节点标记 ----------

class AnchorMark:
	extends Control

	signal moved

	var id := ""
	var title := ""
	var band_col := Color.WHITE
	var hub := false
	var badges: Array = []
	var font: Font
	var show_name := true
	var _drag_off := Vector2.ZERO

	func _init(nid: String, ntitle: String, col: Color, is_hub: bool, badge_list: Array) -> void:
		id = nid
		title = ntitle
		band_col = col
		hub = is_hub
		badges = badge_list

	func _ready() -> void:
		size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_STOP
		font = preload("res://assets/fonts/MaShanZheng.ttf")

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_off = _canvas_local(event.global_position) - position
				_raise_to_top()
				accept_event()
			else:
				accept_event()
		elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			position = _canvas_local(event.global_position) - _drag_off
			moved.emit()
			accept_event()

	func _canvas_local(g: Vector2) -> Vector2:
		# 视口全局坐标 → 画布（地图像素）坐标
		var canvas := get_parent().get_parent() as Control
		return (g - canvas.global_position) / canvas.scale.x

	func _raise_to_top() -> void:
		var layer := get_parent()
		layer.move_child(self, layer.get_child_count() - 1)

	func _draw() -> void:
		var c := size / 2.0
		draw_circle(c, (19.0 if hub else 15.0), Color(PAPER, 0.85))
		draw_circle(c, 13.0 if hub else 9.0, Color(band_col, 0.95))
		if hub:
			draw_arc(c, 18.0, 0, TAU, 40, Color(band_col, 0.6), 2.0, true)
		if show_name:
			var w := minf(120.0, font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 13).x)
			var np := Vector2(c.x - w / 2.0, c.y - 28.0)
			var offs: Array[Vector2] = [Vector2(1.5, 1.5), Vector2(-1.5, 1.5), Vector2(1.5, -1.5), Vector2(-1.5, -1.5)]
			for off in offs:
				draw_string(font, np + off, title, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(PAPER, 0.9))
			draw_string(font, np, title, HORIZONTAL_ALIGNMENT_CENTER, -1, 13, INK)
		var by := -24.0
		for i in badges.size():
			var g := str(badges[i])
			var r := Rect2(c + Vector2(20.0, by), Vector2(17.0, 17.0))
			draw_rect(r, Color(PAPER, 0.8))
			draw_rect(r, Color(SEAL, 0.92))
			draw_string(font, r.position + Vector2(8.5, 13.0), g, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color("#f0e8d2"))
			by += 22.0
