class_name MapEdges
extends Control

# 大地图路网层（D-059）：加权边按造价分样式——实线 1AP、长虚 2AP、短虚 3AP；
# 密道朱红虚线（本局掷定的才画）。纯绘制，不吃鼠标。
# 边价存于 link_costs（"ax,ay|bx,by" → cost），密道存于 secret_links。

const INK2 := Color("#4c3f2c")
const SEAL := Color("#a3382a")

var _pairs: Array = []       # [[Vector2i, Vector2i], ...] 常规边
var _costs: Dictionary = {}  # 与 BoardState.link_costs 同构
var _secrets: Array = []     # [{a: Vector2i, b: Vector2i}, ...]

func setup(pairs: Array, costs: Dictionary, secrets: Array) -> void:
	_pairs = pairs
	_costs = costs
	_secrets = secrets
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	for pair in _pairs:
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		var pa := BoardLayout.pixel(a)
		var pb := BoardLayout.pixel(b)
		var cost := _cost_of(a, b)
		if cost <= 1:
			draw_line(pa, pb, Color(INK2, 0.5), 2.0)
		elif cost == 2:
			draw_dashed_line(pa, pb, Color(INK2, 0.5), 2.0, 6.0)
		else:
			draw_dashed_line(pa, pb, Color(INK2, 0.5), 2.0, 3.0)
	for secret in _secrets:
		var sa: Vector2i = secret.get("a", Vector2i.ZERO)
		var sb: Vector2i = secret.get("b", Vector2i.ZERO)
		draw_dashed_line(BoardLayout.pixel(sa), BoardLayout.pixel(sb), Color(SEAL, 0.75), 2.4, 4.0)

func _cost_of(a: Vector2i, b: Vector2i) -> int:
	if _costs.has(_key(a, b)):
		return int(_costs[_key(a, b)])
	if _costs.has(_key(b, a)):
		return int(_costs[_key(b, a)])
	return 1

static func _key(a: Vector2i, b: Vector2i) -> String:
	return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
