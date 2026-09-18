extends Control

## m15 战场样机（设计稿，非功能场景）：「牌在桌上，人在戏里」构图。
## 上带＝影窗（横轴：左影人=我 ⇄ 右影人=敌，出招/受击在纱上演）；
## 下带＝真实牌桌（纵轴：敌手牌远端、悬停牌=招架窗在桌心、我手牌近端）。
## 两个时刻自动轮播：对峙（idle）／我方点穴式命中（clash）。F6 直接看。

const INK := Color("1c1712")        # 我方影人·墨
const EMBER := Color("26121a")      # 敌方影人·炭红
const WOOD := Color("33200f")
const WOOD_LIT := Color("6b4a26")
const GOLD := Color("e8c987")

# —— 布局带（精简版：影窗加大成主角，桌条只留打出通道＋副露；敌手牌撤＝窗框徽章） ——
const WIN_TOP := 28
const WIN_BOT := 408
const TAB_TOP := 396
const TAB_BOT := 640
const FIG_SCALE := 1.25

var _moment := 0  # 0=对峙 1=命中
var _left_clash: Node2D
var _left_idle: Node2D
var _right_idle: Node2D
var _right_hit: Node2D
var _fx_clash: Node2D
var _labels_clash: Node2D


func _ready() -> void:
	_build_table()
	_build_window()
	_build_hover()
	_build_meld()
	_build_hand()
	_build_bottom()
	_build_enemy_info()
	_build_counter_btn()
	_cycle()
	var t := Timer.new()
	t.wait_time = 2.4
	t.autostart = true
	t.timeout.connect(func() -> void:
		_moment = 1 - _moment
		_cycle())
	add_child(t)


func _cycle() -> void:
	var clash := _moment == 1
	_left_clash.visible = clash
	_left_idle.visible = not clash
	_right_hit.visible = clash
	_right_idle.visible = not clash
	_fx_clash.visible = clash
	_labels_clash.visible = clash


# —————————————— 影窗（横轴世界） ——————————————

func _build_window() -> void:
	var gauze := TextureRect.new()
	gauze.position = Vector2(24, WIN_TOP + 20)
	gauze.size = Vector2(1232, WIN_BOT - 20 - (WIN_TOP + 20))
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("f8ecc8"), Color("dcb87a"), Color("b28a4e")])
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.62)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 512
	gt.height = 192
	gauze.texture = gt
	gauze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gauze.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(gauze)

	# 窗框：粗木边＋内亮线＋四角饰块
	_frame_rect(Rect2(24, WIN_TOP, 1232, WIN_BOT - WIN_TOP), 18)

	# 双影人（脚踩窗底内沿，精简版放大）
	_left_idle = _figure(INK, LEFT_IDLE, Vector2(430, 392), FIG_SCALE)
	_left_clash = _figure(INK, LEFT_CLASH, Vector2(430, 392), FIG_SCALE)
	_right_idle = _figure(EMBER, RIGHT_IDLE, Vector2(860, 392), FIG_SCALE)
	_right_hit = _figure(EMBER, RIGHT_HIT, Vector2(860, 392), FIG_SCALE)

	# 命中特效（斩线＋火花）与飘字
	_fx_clash = Node2D.new()
	_fx_clash.position = Vector2(860, 392)
	_fx_clash.scale = Vector2(FIG_SCALE, FIG_SCALE)
	for pts in [[[28, -140], [58, -96], [54, -92], [24, -134]], [[20, -120], [66, -110], [65, -104], [18, -114]], [[30, -70], [48, -64], [46, -59], [28, -65]]]:
		_poly(_fx_clash, pts, Color(1.0, 0.42, 0.3, 0.9))
	for off in [Vector2(70, -128), Vector2(84, -104), Vector2(58, -88)]:
		_poly(_fx_clash, [[0, 0], [7, 2], [0, 5]], Color(1.0, 0.72, 0.4, 0.9), off)
	add_child(_fx_clash)

	_labels_clash = Node2D.new()
	var dmg := _label("-13", 34, Color("ff5a4a"), Vector2(916, 138))
	dmg.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	dmg.add_theme_constant_override("shadow_offset_x", 2)
	dmg.add_theme_constant_override("shadow_offset_y", 2)
	_labels_clash.add_child(dmg)
	_labels_clash.add_child(_label("点穴式", 17, Color("ffd9a0"), Vector2(916, 112)))
	add_child(_labels_clash)


# —————————————— 牌桌（纵轴世界） ——————————————

func _build_table() -> void:
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([Vector2(180, TAB_TOP), Vector2(1100, TAB_TOP), Vector2(1280, TAB_BOT), Vector2(0, TAB_BOT)])
	rim.color = Color("3a2417")
	add_child(rim)
	var felt := Polygon2D.new()
	felt.polygon = PackedVector2Array([Vector2(206, TAB_TOP + 10), Vector2(1074, TAB_TOP + 10), Vector2(1236, TAB_BOT - 12), Vector2(44, TAB_BOT - 12)])
	felt.color = Color("24462f")
	add_child(felt)


func _build_hover() -> void:
	var ring := Panel.new()
	ring.position = Vector2(640 - 31, 468 - 39)
	ring.size = Vector2(62, 78)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(0.98, 0.82, 0.3, 0.85)
	ring.add_theme_stylebox_override("panel", sb)
	add_child(ring)
	var tw := create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.35, 0.7)
	tw.tween_property(ring, "modulate:a", 1.0, 0.7)
	var tile := MJBTileFace.make_tile(MJTile.new("条", 7), 46, 61)
	tile.position = Vector2(640 - 23, 468 - 30)
	add_child(tile)
	add_child(_label("招架窗", 13, Color("cfe3c8"), Vector2(640 - 24, 512)))


func _build_meld() -> void:
	var row := HBoxContainer.new()
	row.position = Vector2(1030, 452)
	row.add_theme_constant_override("separation", 4)
	for i in 3:
		var t := MJBTileFace.make_tile(MJTile.new("筒", 7), 34, 45)
		row.add_child(t)
	add_child(row)
	add_child(_label("副露·筒7", 12, Color("9fb8a0"), Vector2(1030, 500)))


func _build_hand() -> void:
	var suit := ["万", "万", "万", "万", "万", "万", "万", "万", "万", "筒", "筒", "筒", "筒"]
	var val := [1, 2, 3, 4, 5, 6, 7, 8, 9, 2, 3, 5, 8]
	var pitch := 57.5
	var x0 := 640 - 13 * pitch / 2.0
	for i in 13:
		var t := MJBTileFace.make_tile(MJTile.new(suit[i], val[i]), 55, 73)
		t.position = Vector2(x0 + i * pitch, TAB_BOT - 88)
		add_child(t)
	var swap := MJBTileFace.make_tile(MJTile.new("条", 7), 55, 73)
	swap.position = Vector2(x0 + 13 * pitch + 22, TAB_BOT - 88)
	MJBTileFace.fresh_mark(swap)
	MJBTileFace.glow(swap, Color(0.98, 0.82, 0.3))
	add_child(swap)


func _build_bottom() -> void:
	var bg := ColorRect.new()
	bg.color = Color("161210")
	bg.position = Vector2(0, TAB_BOT)
	bg.size = Vector2(1280, 72)
	add_child(bg)
	add_child(_label("气血", 14, Color("e8d9c8"), Vector2(24, TAB_BOT + 14)))
	_bar(Vector2(64, TAB_BOT + 16), 190, 14, 0.74, Color("b8342c"))
	add_child(_label("74/100", 12, Color("cbb9a4"), Vector2(262, TAB_BOT + 16)))
	add_child(_label("罡气 ◆2", 15, GOLD, Vector2(24, TAB_BOT + 40)))
	var names := ["攻击", "护体", "变招"]
	for i in 3:
		_button(names[i], Vector2(1020 + i * 84, TAB_BOT + 16), 76, 40)


func _build_enemy_info() -> void:
	add_child(_label("刀客 · 马三", 19, GOLD, Vector2(64, WIN_TOP + 26)))
	_bar(Vector2(64, WIN_TOP + 54), 240, 12, 0.62, Color("a22c2c"))
	add_child(_label("气血 62/100", 11, Color("d9c2a0"), Vector2(312, WIN_TOP + 52)))
	add_child(_label("罡气 ◆3    手牌 ×8", 13, GOLD, Vector2(64, WIN_TOP + 72)))
	_hand_badge()


func _hand_badge() -> void:
	# 敌方手牌徽章（精简版：不摆背牌行，张数挂窗框）——×8 枚小背牌图形示意
	for i in 8:
		var t := MJBTileFace.make_back(13, 17)
		t.position = Vector2(190 + i * 15, WIN_TOP + 71)
		add_child(t)


func _build_counter_btn() -> void:
	_button("记牌器", Vector2(1160, WIN_TOP + 26), 90, 30)


# —————————————— 姿势数据（脚在原点，向上为负；左右影人各自朝对侧） ——————————————

const LEFT_IDLE := [
	[[2, -152], [16, -146], [20, -132], [14, -121], [2, -117], [-10, -121], [-16, -132], [-12, -146]],
	[[2, -117], [15, -110], [17, -62], [9, -54], [-3, -52], [-13, -56], [-16, -108], [-6, -115]],
	[[12, -108], [26, -102], [44, -96], [42, -88], [24, -92], [10, -100]],
	[[-8, -106], [-20, -98], [-14, -92], [-4, -102]],
	[[6, -54], [16, -50], [24, -2], [10, 0], [2, -48]],
	[[-6, -52], [-18, -46], [-30, -4], [-18, 0], [-10, -48]],
]
const LEFT_CLASH := [
	[[26, -146], [40, -138], [42, -124], [34, -115], [22, -114], [12, -122], [12, -138]],
	[[20, -114], [34, -104], [38, -58], [28, -50], [14, -52], [8, -108], [14, -114]],
	[[32, -102], [58, -96], [88, -90], [90, -82], [60, -84], [30, -92]],
	[[10, -104], [0, -94], [6, -88], [14, -98]],
	[[26, -52], [44, -44], [58, -6], [44, 0], [30, -46]],
	[[8, -50], [-12, -42], [-40, -10], [-34, -2], [-4, -46]],
]
const RIGHT_IDLE := [
	[[-2, -152], [-16, -146], [-20, -132], [-14, -121], [-2, -117], [10, -121], [16, -132], [12, -146]],
	[[-2, -117], [-15, -110], [-17, -62], [-9, -54], [3, -52], [13, -56], [16, -108], [6, -115]],
	[[-12, -108], [-28, -104], [-44, -110], [-46, -102], [-30, -96], [-10, -100]],
	[[-46, -108], [-96, -122], [-98, -113], [-48, -101]],
	[[8, -106], [20, -98], [14, -92], [4, -102]],
	[[-6, -54], [-16, -50], [-24, -2], [-10, 0], [-2, -48]],
	[[6, -52], [18, -46], [30, -4], [18, 0], [10, -48]],
]
const RIGHT_HIT := [
	[[14, -150], [28, -144], [32, -130], [24, -119], [10, -121], [2, -132], [4, -146]],
	[[10, -116], [20, -106], [18, -60], [8, -52], [-6, -54], [-14, -108], [-2, -116]],
	[[14, -104], [30, -96], [26, -88], [10, -98]],
	[[0, -100], [-14, -90], [-8, -84], [4, -96]],
	[[22, -96], [58, -86], [56, -79], [20, -89]],
	[[8, -52], [20, -46], [32, -4], [20, 0], [6, -48]],
	[[-6, -52], [-18, -44], [-28, -4], [-18, 0], [-8, -48]],
]


# —————————————— 小件 ——————————————

func _figure(color: Color, pose: Array, at: Vector2, scale := 1.0) -> Node2D:
	var node := Node2D.new()
	node.position = at
	node.scale = Vector2(scale, scale)
	for pts in pose:
		_poly(node, pts, color)
	add_child(node)
	return node


func _poly(parent: Node2D, pts: Array, color: Color, offset := Vector2.ZERO) -> void:
	var p := Polygon2D.new()
	var packed := PackedVector2Array()
	for pt in pts:
		packed.append(Vector2(pt[0], pt[1]) + offset)
	p.polygon = packed
	p.color = color
	parent.add_child(p)


func _frame_rect(rect: Rect2, thickness: int) -> void:
	for side in [
		Rect2(rect.position.x - thickness, rect.position.y - thickness, rect.size.x + thickness * 2, thickness),
		Rect2(rect.position.x - thickness, rect.position.y + rect.size.y, rect.size.x + thickness * 2, thickness),
		Rect2(rect.position.x - thickness, rect.position.y, thickness, rect.size.y),
		Rect2(rect.position.x + rect.size.x, rect.position.y, thickness, rect.size.y),
	]:
		var c := ColorRect.new()
		c.color = WOOD
		c.position = side.position
		c.size = side.size
		add_child(c)
	for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.position + rect.size]:
		var dot := ColorRect.new()
		dot.color = WOOD_LIT
		dot.size = Vector2(10, 10)
		dot.position = corner - Vector2(5, 5)
		add_child(dot)


func _label(text: String, size: int, color: Color, at: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _bar(at: Vector2, w: int, h: int, ratio: float, color: Color) -> void:
	var bg := ColorRect.new()
	bg.color = Color("241a16")
	bg.position = at
	bg.size = Vector2(w, h)
	add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = at
	fill.size = Vector2(int(w * ratio), h)
	add_child(fill)


func _button(text: String, at: Vector2, w: int, h: int) -> void:
	var p := Panel.new()
	p.position = at
	p.size = Vector2(w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2b2119")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.border_color = WOOD_LIT
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	var l := _label(text, 15, Color("e8d9c8"), at + Vector2(w / 2.0 - 15 * text.length() / 2.0, h / 2.0 - 11))
	add_child(l)
