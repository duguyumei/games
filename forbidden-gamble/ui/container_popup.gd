class_name ContainerPopup
extends Control

# 容器弹窗（箱子/遗体，D-028 弹窗翻牌口径，C-028 网格化后的恢复版）：
# 点击网格里的容器牌弹出居中小窗——内容物摊成一排暗牌，点暗牌＝翻（1 行动力/张）、
# 点亮牌＝拿（免费）。可翻一半合窗走人，回来再点容器续翻（状态在牌上）。
# 纯展示＋信号上抛，规则与费用全在 BoardState；每次动作后由 board.gd 调 refresh_view
# 重读状态（弹窗不进 ui_layer——_refresh 清屏清不到它）。

signal flip_requested(cell: int, index: int)
signal take_requested(cell: int, index: int)
signal closed

const Palette := preload("res://ui/board_palette.gd")
const CardFaceScene := preload("res://ui/card_face.tscn")
const CARD_SIZE := Vector2(88.0, 124.0)
const SLOT_GAP := 10.0

var _board: BoardState
var _cell := -1
var _dim: ColorRect
var _window: PanelContainer
var _view: Dictionary = {}   # 最近一次 refresh 的 container_view（测试/调试读）

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _ready() -> void:
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_window = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD
	style.border_color = Palette.COLOR_GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_window.add_theme_stylebox_override("panel", style)
	center.add_child(_window)

func open(board: BoardState, cell: int) -> void:
	_board = board
	_cell = cell
	visible = true
	refresh_view()

func is_open() -> bool:
	return visible

# 最近的容器视图（弹窗测试与预览用）。
func view() -> Dictionary:
	return _view

func refresh_view() -> void:
	if not visible or _board == null:
		return
	_view = _board.container_view(_cell)
	for child in _window.get_children():
		child.queue_free()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_window.add_child(vbox)
	var title := Palette.brush_label(str(_view.get("name", "容器")), 24, Palette.COLOR_GOLD)
	vbox.add_child(title)
	var flip_cost: int = int(_board.config.get("ap", {}).get("flip", 1))
	vbox.add_child(Palette.plain_label("暗牌点击翻开（%d 行动力／张）｜亮牌点击拿取（免费）" % flip_cost,
		13, Palette.COLOR_INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(SLOT_GAP))
	vbox.add_child(row)
	var entries: Array = _view.get("entries", [])
	for i in range(entries.size()):
		row.add_child(_make_slot(entries[i], i))
	if entries.is_empty():
		vbox.add_child(Palette.plain_label("（里面已经空了）", 15, Palette.COLOR_INK))
	var close_btn := Button.new()
	close_btn.text = "关上"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

func close() -> void:
	if not visible:
		return
	visible = false
	_cell = -1
	_view = {}
	closed.emit()

# 单个内容物格：暗牌＝牌背（点击翻），亮牌＝卡面＋稀有度描边（点击拿）。
func _make_slot(entry: Dictionary, index: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	holder.tooltip_text = str(entry.get("tooltip", ""))
	var flipped := bool(entry.get("flipped", false))
	if not flipped:
		var back := Palette.card_back(CARD_SIZE)
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(back)
	else:
		var face = CardFaceScene.instantiate()
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(face)
		face.setup(str(entry.get("name", "？")), "scatter")
		var rarity := str(entry.get("rarity", "common"))
		if Palette.RARITY_COLORS.has(rarity):
			var edge := Panel.new()
			edge.set_anchors_preset(Control.PRESET_FULL_RECT)
			edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var edge_style := Palette.card_style("scatter")
			edge_style.border_color = Palette.RARITY_COLORS[rarity]
			edge_style.set_border_width_all(3)
			edge.add_theme_stylebox_override("panel", edge_style)
			holder.add_child(edge)
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.mouse_entered.connect(func(): holder.modulate = Color(1.06, 1.02, 0.92))
	holder.mouse_exited.connect(func(): holder.modulate = Color.WHITE)
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if flipped:
				take_requested.emit(_cell, index)
			else:
				flip_requested.emit(_cell, index))
	return holder

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
