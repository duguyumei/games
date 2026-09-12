extends Control

# 大地图档的节点印（D-059「纸与棋子」的棋子）：
# 印章式圆点＋地名——未勘灰、已勘亮（带色＝D-051 动态带）；当前节点金环；
# 可前往节点亮起并挂边价角标；撤离点带旗。点击＝前往（或回地块）。
# 铁律：运行时对象，永不烙进底图。

signal travel_requested(pos: Vector2i)
signal zoom_requested()

const Palette := preload("res://ui/board_palette.gd")

const BAND_COL := {"浅": Color("#5a5346"), "中": Color("#8a6134"), "深": Color("#a3382a")}
const R_INK := Color("#2e2418")
const UNEXPLORED := Color("#6f675a")

var _pos: Vector2i
var _name := ""
var _band := ""
var _hub := false
var _explored := false
var _current := false
var _travelable := false
var _cost := 0
var _extract := false
var _hunter_here := false

func setup(pos: Vector2i, site: Dictionary, is_current: bool, travelable: bool,
		cost: int, hunter_here: bool) -> void:
	_pos = pos
	_name = str(site.get("name", ""))
	_band = str(site.get("band", "浅"))
	_hub = str(site.get("tier", "")) == "hub"
	_explored = bool(site.get("explored", false))
	_extract = bool(site.get("extract", false))
	_current = is_current
	_travelable = travelable
	_cost = cost
	_hunter_here = hunter_here
	size = Vector2(30, 30)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _travelable or _current:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): modulate = Color(1.12, 1.08, 0.96))
		mouse_entered.connect(func(): queue_redraw())
		mouse_exited.connect(func(): modulate = Color.WHITE)
		mouse_exited.connect(func(): queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		if _current:
			zoom_requested.emit()
		else:
			travel_requested.emit(_pos)

func _draw() -> void:
	var c := size / 2.0
	var r := 14.0 if _hub else 10.0
	# 纸底衬圈（压住底图纹理）
	draw_circle(c, r + 4.0, Color(Palette.COLOR_CARD, 0.85 if _explored else 0.55))
	# 本体：未勘灰／已勘带色
	draw_circle(c, r, Color(BAND_COL.get(_band, UNEXPLORED) if _explored else UNEXPLORED, 0.95))
	if _hub and _explored:
		draw_arc(c, r + 3.5, 0, TAU, 40, Color(BAND_COL.get(_band, R_INK), 0.6), 2.0, true)
	# 当前节点：金环
	if _current:
		draw_arc(c, r + 6.0, 0, TAU, 48, Palette.COLOR_GOLD, 2.6, true)
	# 镇物驻留
	if _hunter_here:
		draw_string(Palette.BRUSH_FONT, c + Vector2(r * 0.2, -r - 2.0), "镇",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color("#6B4A8A"))
	# 撤离旗（已勘撤离点）
	if _explored and _extract:
		draw_string(Palette.BRUSH_FONT, c + Vector2(-r - 12.0, -r + 6.0), "⚑",
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Palette.COLOR_GOLD)
	# 边价角标（可前往且边价 >1）
	if _travelable and _cost > 1:
		var bc := c + Vector2(r + 2.0, -r - 2.0)
		draw_circle(bc, 9.0, Color(Palette.COLOR_CARD, 0.95))
		draw_arc(bc, 9.0, 0, TAU, 24, R_INK, 1.4, true)
		draw_string(Palette.BRUSH_FONT, bc + Vector2(0.0, 4.5), str(_cost),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12, R_INK)
	# 地名：未勘不示名（地图迷雾），已勘带纸晕描边（大地图档整体缩得小，字号给足）
	if _explored:
		var label := _name
		if not label.is_empty():
			var np := Vector2(c.x - label.length() * 7.5, c.y + r + 16.0)
			var offs: Array[Vector2] = [Vector2(1.4, 1.4), Vector2(-1.4, 1.4), Vector2(1.4, -1.4), Vector2(-1.4, -1.4)]
			for off in offs:
				draw_string(Palette.BRUSH_FONT, np + off, label,
					HORIZONTAL_ALIGNMENT_CENTER, -1, 15, Color(Palette.COLOR_CARD, 0.92))
			draw_string(Palette.BRUSH_FONT, np, label,
				HORIZONTAL_ALIGNMENT_CENTER, -1, 15, R_INK)
