class_name MJBWallPanel
extends VBoxContainer

## 气海牌墙（牌桌左列，2026-09-17 用户令）：墩列制——每墩上下两层背牌（真实码墙），
## 摸牌自右下端起：先上层后下层、墩自右向左耗。墩按阅读序排（左→右、上→下），
## 活墙占序列头、从尾耗——尾即右下端，与真实摸牌方向一致。
## 记牌计数不在此（整合进日志面板）；气海浮窗已随牌桌轮退役。


const TILE_W := 11
const TILE_H := 15
const BANKS := 5  # 横向墩列数（纵向不限）

var _grid := GridContainer.new()
var _count := Label.new()


func _init() -> void:
	add_theme_constant_override("separation", 3)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = "气海"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	head.add_child(title)
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", Color(0.66, 0.63, 0.56))
	head.add_child(_count)
	add_child(head)
	_grid.columns = BANKS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	add_child(_grid)
	custom_minimum_size = Vector2(BANKS * (TILE_W + 3) + 10, 0)


func update_wall(live_left: int) -> void:
	for child in _grid.get_children():
		child.queue_free()
	var cells := int(ceil(live_left / 2.0))
	var rem := live_left
	for _i in range(cells):
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 1)
		var layers := mini(rem, 2)
		rem -= layers
		if layers == 1:  # 尾墩单张＝上层已摸、下层留：占位垫上，牌落下层位
			var pad := Control.new()
			pad.custom_minimum_size = Vector2(TILE_W, TILE_H)
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(pad)
		for _l in range(layers):
			cell.add_child(MJBTileFace.make_back(TILE_W, TILE_H))
		_grid.add_child(cell)
	_count.text = "×%d" % live_left


## 摸牌飞行源：下一张将被摸走的位置（尾墩——先上层后下层，取该墩现存最上张）。
func draw_origin_rect() -> Rect2:
	var cells := _grid.get_child_count()
	if cells == 0:
		return get_global_rect()
	var cell := _grid.get_child(cells - 1) as Control
	var picks := cell.get_child_count()
	if picks == 0:
		return cell.get_global_rect()
	# 墩内首张实牌＝现存最上层（单张墩垫了占位，首张实牌即下层）
	for child in cell.get_children():
		if child is MJBTileFace.TileBody:
			return (child as Control).get_global_rect()
	return cell.get_global_rect()
