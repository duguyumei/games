class_name MJBTopCenter
extends VBoxContainer

## 顶部中央块（居中，纯展示）：气海背牌墙（剩余张数一背牌一格）。
## 记牌浮窗＝**小牌矩阵**，挂点＝背牌墙网格（小麻将本体）——气海两字不挂（2026-09-17 用户令）。
## 最新打出行已迁往中部打出交换区（play_line）。


var _wall_count := Label.new()
var _wall_grid := GridContainer.new()
var _wall_title := Label.new()
var _counter_panel := VBoxContainer.new()
var _counter_counts: Array = []  # [suit][value] -> Label（×N）
var _counter_left := Label.new()


func _init() -> void:
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(0, 32)  # 固定高＝满墙两行背牌（2026-09-17 用户令）：残墙变一行不抖布局
	var wall_line := HBoxContainer.new()
	wall_line.add_theme_constant_override("separation", 8)
	wall_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(wall_line)
	_wall_title.text = "气海"
	_wall_title.add_theme_font_size_override("font_size", 12)
	_wall_title.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	wall_line.add_child(_wall_title)
	_wall_grid.columns = 54
	_wall_grid.add_theme_constant_override("h_separation", 1)
	_wall_grid.add_theme_constant_override("v_separation", 1)
	wall_line.add_child(_wall_grid)
	_wall_count.add_theme_font_size_override("font_size", 12)
	_wall_count.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	wall_line.add_child(_wall_count)
	_build_counter()
	MJBTipFloat.bind_custom(_wall_grid, "气海·记牌", _counter_panel)  # 只挂背牌墙（小麻将本体）


# 记牌面板：三门行 ×9 实体小牌，每张底部 ×剩余数；尾行余 N 张未见。
func _build_counter() -> void:
	_counter_panel.add_theme_constant_override("separation", 6)
	for suit in MJTile.SUITS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		_counter_panel.add_child(row)
		var counts: Array = []
		for v in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX + 1):
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			cell.add_child(MJBTileFace.make_tile(MJTile.new(suit, v), 22, 30))
			var count := Label.new()
			count.text = "×4"
			count.add_theme_font_size_override("font_size", 9)
			count.add_theme_color_override("font_color", Color(0.86, 0.83, 0.76))
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(count)
			row.add_child(cell)
			counts.append(count)
		_counter_counts.append(counts)
	_counter_left.add_theme_font_size_override("font_size", 10)
	_counter_left.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	_counter_panel.add_child(_counter_left)


func update_center(wall_left: int, river: MJRiver = null) -> void:
	for child in _wall_grid.get_children():
		child.queue_free()
	for _i in range(wall_left):
		_wall_grid.add_child(MJBTileFace.make_back(11, 15))
	_wall_count.text = "×%d" % wall_left
	if river != null:
		_refresh_counter(river)


# 记牌：三门 ×1–9 各 4 张，减去气河已见——每张小牌底部 ×剩余数。
func _refresh_counter(river: MJRiver) -> void:
	var seen := {}
	for t in river.tiles:
		var key := (t as MJTile).key()
		seen[key] = int(seen.get(key, 0)) + 1
	for si in range(MJTile.SUITS.size()):
		var suit: String = MJTile.SUITS[si]
		for v in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX + 1):
			var left := 4 - int(seen.get("%s%d" % [suit, v], 0))
			var count: Label = _counter_counts[si][v - MJTile.VALUE_MIN]
			count.text = "×%d" % left
			count.add_theme_color_override("font_color",
				Color(0.86, 0.83, 0.76) if left > 0 else Color(0.45, 0.43, 0.4))
	_counter_left.text = "余 %d 张未入气河" % (108 - river.size())
