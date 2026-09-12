extends Control

# 地块组件（C-028 明牌网格版）：
# - 非当前地块：一张卡大小（缩小压暗）——地名/牌数角标/撤离旗，已勘过的悬停可预览
#   牌面（tooltip）；点击＝前往。
# - 当前地块：放大成 3 列卡牌网格（高度封顶 3 行，超出滚动），全部亮牌，点击即互动：
#   敌牌＝迎战（连坐组描金边）、物资＝拾取、箱/遗体＝弹窗翻牌（D-028：开启费开盖、
#   逐张翻 1 行动力、拿取免费；拿空的壳灰化留场）、NPC＝交谈、地点卡＝打开。
#   警戒角标：惊动黄（警n）、准备红（！）。
# 纯展示：内容由 setup() 按 BoardState 数据填充；交互经信号上抛给 board.gd。

signal travel_requested(pos: Vector2i)
signal card_action_requested(cell: int)
signal battle_requested(cell: int)
signal extract_requested()
signal wheel_scrolled(up: bool, at: Vector2)
signal gesture_zoomed(factor: float, at: Vector2)
signal gesture_panned(delta: Vector2)

const Palette := preload("res://ui/board_palette.gd")
const CardFaceScene := preload("res://ui/card_face.tscn")

const TILE_SIZE := BoardLayout.TILE_SIZE
const CARD_SIZE := BoardLayout.CARD_SIZE
const CUR_SIZE := BoardLayout.CURRENT_TILE_SIZE
const GRID_COLS := BoardLayout.GRID_COLS
const GRID_GAP := BoardLayout.GRID_GAP
const GRID_PAD := BoardLayout.GRID_PAD
const GRID_HEADER := BoardLayout.GRID_HEADER
const SCALE_SMALL := 0.6
const SFX_DIR := "res://assets/sfx/"
const READY_COLOR := Color("#B33A2B")
const ALERT_COLOR := Color("#C9A227")
const LIVE_ENEMY_KINDS := ["enemy", "pursuer", "zhenwu"]

var _pos: Vector2i

func _ready() -> void:
	gui_input.connect(_on_gui_input)

func setup(pos: Vector2i, site: Dictionary, board: BoardState, is_current: bool, run_over: bool,
		confirm_extract: bool, extract_value: int, animate_focus: bool, travelable: bool,
		chain_cells: Array = []) -> void:
	_pos = pos
	for child in get_children():
		child.queue_free()
	var explored := bool(site.get("explored", false))
	var grid: Array = site.get("grid", [])
	if is_current:
		_build_current(board, grid, run_over, confirm_extract, extract_value, chain_cells)
		if animate_focus:
			pivot_offset = CUR_SIZE / 2
			scale = Vector2(SCALE_SMALL, SCALE_SMALL)
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_build_small(board, site, grid, explored, travelable)
		pivot_offset = TILE_SIZE / 2
		scale = Vector2(SCALE_SMALL, SCALE_SMALL)
		modulate = Color(1, 1, 1, 0.55)
		if travelable:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			mouse_entered.connect(func(): modulate = Color(1, 1, 1, 0.9))
			mouse_exited.connect(func(): modulate = Color(1, 1, 1, 0.55))

# ---------- 当前地块：放大的明牌网格 ----------

func _build_current(board: BoardState, grid: Array, run_over: bool, confirm_extract: bool,
		extract_value: int, chain_cells: Array) -> void:
	var rows: int = maxi(1, ceili(grid.size() / float(GRID_COLS))) if not grid.is_empty() else 1
	var body_h: float = mini(rows, BoardLayout.GRID_ROWS_SHOWN) * CARD_SIZE.y \
		+ (mini(rows, BoardLayout.GRID_ROWS_SHOWN) - 1) * float(GRID_GAP)
	var panel_h: float = mini(GRID_HEADER + body_h + 6.0, CUR_SIZE.y)
	size = Vector2(CUR_SIZE.x, panel_h)
	var site := board.current_site()
	# 金边纸底外框（不吃鼠标——点击留给卡牌格与桌面手势）
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(Palette.COLOR_CARD, 0.96)
	frame_style.border_color = Palette.COLOR_GOLD
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(10)
	frame_style.content_margin_left = 0
	frame_style.content_margin_right = 0
	frame_style.content_margin_top = 0
	frame_style.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", frame_style)
	add_child(frame)
	# 标题行：地名（毛笔金字）＋ 牌数
	var name_label := Palette.brush_label(str(site.get("name", "？")), 22, Palette.COLOR_GOLD)
	name_label.position = Vector2(GRID_PAD + 2, 6)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	var count_label := Palette.brush_label("牌 %d" % _live_count(grid), 14, Palette.COLOR_INK)
	count_label.position = Vector2(CUR_SIZE.x - GRID_PAD - 64, 10)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)
	# 撤离按钮（撤离点专属，两段式确认由 board.gd 管）
	if board.is_extract_site(board.hero_site) and not run_over:
		var extract_btn := Button.new()
		extract_btn.text = ("确认撤离？携带物资价值 %d" % extract_value) if confirm_extract else "撤离"
		extract_btn.focus_mode = Control.FOCUS_NONE
		extract_btn.add_theme_font_size_override("font_size", 14)
		extract_btn.position = Vector2(GRID_PAD, 4)
		extract_btn.size = Vector2(150, 30)
		extract_btn.pressed.connect(func(): extract_requested.emit())
		add_child(extract_btn)
		name_label.position = Vector2(GRID_PAD + 158, 6)
		count_label.position = Vector2(CUR_SIZE.x - GRID_PAD - 58, 10)
	# 卡牌网格（高度封顶，超出滚动）
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(GRID_PAD, GRID_HEADER)
	scroll.size = Vector2(CUR_SIZE.x - GRID_PAD * 2, panel_h - GRID_HEADER - 4)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid_box := GridContainer.new()
	grid_box.columns = GRID_COLS
	grid_box.add_theme_constant_override("h_separation", GRID_GAP)
	grid_box.add_theme_constant_override("v_separation", GRID_GAP)
	scroll.add_child(grid_box)
	for cell in range(grid.size()):
		grid_box.add_child(_make_cell(board, grid, cell, chain_cells))
	if grid.is_empty():
		var empty_hint := Palette.plain_label("（空地）", 15, Palette.COLOR_INK)
		empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid_box.add_child(empty_hint)

func _live_count(grid: Array) -> int:
	var count := 0
	for entry in grid:
		if not (entry as Dictionary).is_empty():
			count += 1
	return count

# 单个卡牌格：卡面＋警戒角标＋连坐金边；点击按类别上抛。
func _make_cell(board: BoardState, grid: Array, cell: int, chain_cells: Array) -> Control:
	var card: Dictionary = grid[cell]
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	if card.is_empty():
		var hole := Palette.empty_slot(CARD_SIZE)
		hole.set_anchors_preset(Control.PRESET_FULL_RECT)
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(hole)
		return holder
	var kind := str(card.get("kind", ""))
	# 拿空的容器壳：灰化留场不可再点（开着的容器可再点＝弹窗续翻）
	var shell_dead := kind in ["chest", "body"] and bool(card.get("opened", false)) \
		and (card.get("contents", []) as Array).is_empty()
	var face = CardFaceScene.instantiate()
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(face)
	face.setup(board.card_display(card), kind)
	holder.tooltip_text = board.card_tooltip(card)
	# 警戒角标（活敌）／迫近角标（压顶镇物）
	if kind in LIVE_ENEMY_KINDS:
		holder.add_child(_alert_badge(board, card))
	# 连坐预告：与已交战敌牌上下左右连通的，描金边
	if cell in chain_cells:
		var mark := Panel.new()
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mark_style := Palette.card_style(kind)
		mark_style.border_color = Palette.COLOR_GOLD
		mark_style.set_border_width_all(3)
		mark.add_theme_stylebox_override("panel", mark_style)
		holder.add_child(mark)
	if shell_dead:
		holder.modulate = Color(0.62, 0.6, 0.55, 0.8)
		holder.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
		return holder
	holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	holder.mouse_entered.connect(func(): holder.modulate = Color(1.06, 1.02, 0.92))
	holder.mouse_exited.connect(func(): holder.modulate = Color.WHITE)
	holder.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if kind in LIVE_ENEMY_KINDS:
				battle_requested.emit(cell)
			else:
				card_action_requested.emit(cell))
	return holder

# 警戒角标：准备态红「！」、惊动态黄「警n」、迫近另加「迫n」。
func _alert_badge(board: BoardState, card: Dictionary) -> Control:
	var badge_info: Dictionary = board.alert_badge(card)
	var box := HBoxContainer.new()
	box.position = Vector2(2, CARD_SIZE.y - 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	var state := str(badge_info.get("state", "calm"))
	if state == "ready":
		var bang := Palette.brush_label("！", 16, READY_COLOR)
		bang.pivot_offset = bang.size / 2
		box.add_child(bang)
		var tip := Label.new()
		tip.text = "准备袭击"
		tip.add_theme_font_size_override("font_size", 11)
		tip.add_theme_color_override("font_color", READY_COLOR)
		box.add_child(tip)
	elif state == "alerted":
		var warn := Label.new()
		warn.text = "警%d" % int(badge_info.get("value", 0))
		warn.add_theme_font_size_override("font_size", 12)
		warn.add_theme_color_override("font_color", ALERT_COLOR)
		box.add_child(warn)
	if str(card.get("kind", "")) == "zhenwu":
		var prox: int = board.hunter_proximity()
		if prox >= 0:
			var prox_label := Label.new()
			prox_label.text = "迫%d" % prox
			prox_label.add_theme_font_size_override("font_size", 12)
			prox_label.add_theme_color_override("font_color", READY_COLOR if prox >= 3 else ALERT_COLOR)
			box.add_child(prox_label)
	return box

# ---------- 非当前地块：一张卡大小 ----------

func _build_small(board: BoardState, site: Dictionary, grid: Array, explored: bool, travelable: bool) -> void:
	size = TILE_SIZE
	var count := _live_count(grid)
	# 牌背堆（厚度最多 3 层）
	var layers: int = mini(count, 3)
	for i in range(layers - 1, -1, -1):
		var back := Palette.card_back(Vector2(88, 124))
		back.position = Vector2(TILE_SIZE.x / 2 - 44 + i * 3, 70 - i * 3)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
	if count == 0:
		var empty := Palette.empty_slot(Vector2(88, 124))
		empty.position = Vector2(TILE_SIZE.x / 2 - 44, 70)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(empty)
	# 牌数角标（右上）
	if count > 0:
		var badge := Palette.brush_label(str(count), 13, Palette.COLOR_INK)
		badge.position = Vector2(TILE_SIZE.x / 2 + 52, 56)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
	# 撤离旗
	if explored and bool(site.get("extract", false)):
		var flag := Palette.brush_label("⚑", 20, Palette.COLOR_GOLD)
		flag.position = Vector2(TILE_SIZE.x / 2 - 62, 56)
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(flag)
	# 地名（未探索＝？？？）
	var name_label := Palette.brush_label(str(site.get("name", "？？？")) if explored else "？？？", 20, Palette.COLOR_INK)
	name_label.position = Vector2(0, 232)
	name_label.size = Vector2(TILE_SIZE.x, 28)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	# 明牌侦察：已勘过的地块悬停可看牌面构成
	if explored and travelable:
		var peek: Array[String] = board.site_peek(_pos)
		if not peek.is_empty():
			tooltip_text = "、".join(peek)

# ---------- 输入 ----------

# 小地块：点击＝前往；手势/滚轮转发镜头。当前地块的空白处留给桌面手势。
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		gesture_zoomed.emit(event.factor, get_global_mouse_position())
	elif event is InputEventPanGesture:
		gesture_panned.emit(event.delta)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				travel_requested.emit(_pos)
			MOUSE_BUTTON_WHEEL_UP:
				wheel_scrolled.emit(true, get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_DOWN:
				wheel_scrolled.emit(false, get_global_mouse_position())
