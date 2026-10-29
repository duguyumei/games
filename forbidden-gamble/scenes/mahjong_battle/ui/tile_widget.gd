class_name MJBTileFace
extends RefCounted

## 牌面构件（占位美术：代码绘制，零商业资产提取）。
## 正面（属性色＋数值）、背牌（敌方手牌明码张数）、高亮描边——全部静态构造，供各区块共用。
## 2.5D 牌体（2026-09-18 用户令「牌不能像一张纸」）：FluffyStuff 图集贴面＋顶面/厚沿——
## 站立正面／站立背面／躺牌三形态，样板见 previews/tile_25d_demo。


const SUIT_COLORS := {"万": Color(0.2, 0.47, 0.34), "筒": Color(0.66, 0.25, 0.22), "条": Color(0.5, 0.42, 0.2)}
const SUIT_ATLAS := {"万": "m", "筒": "p", "条": "s"}


# 2.5D 精灵（2026-09-18 v5 用户令：改用 mahjong_graphic 资产——可随意商用·M+ 条款，
# 见 assets/mj25d/LICENSE；默认风格深蓝饰层已批量染深绿 h135）。竖＝站立字面，横＝躺牌字面，
# 背＝站立背（雀魂 green 染齐）＋躺背（b_01 染绿）。
static func stand_tex(tile: MJTile) -> Texture2D:
	return load("res://assets/mj25d/竖/%d%s.png" % [tile.value, SUIT_ATLAS.get(tile.suit, "m")]) as Texture2D


static func flat_tex(tile: MJTile) -> Texture2D:
	return load("res://assets/mj25d/横/h%d%s.png" % [tile.value, SUIT_ATLAS.get(tile.suit, "m")]) as Texture2D


static func back_stand_tex() -> Texture2D:
	return load("res://assets/mj25d/背/站立背.png") as Texture2D


static func back_flat_tex() -> Texture2D:
	return load("res://assets/mj25d/背/b_01.png") as Texture2D


## 2.5D 牌体（2026-09-18 v5 用户令：改用 mahjong_graphic 精灵资产）：
## 贴图自带专业双层/圆角/透视/阴影——程序画法（v1–v4）退役。装载器见上（竖/横/站背/躺背）。
## mode＝"stand"｜"back"｜"flat"｜"flat_back"；宽 w＝透视牌宽，高随贴图纵横比。
static func make_25d(tex: Texture2D, w: int, h: int, mode := "stand") -> Control:
	var t := Tile25D.new(tex, w, h, mode)
	return t


class Tile25D extends Control:
	var face: Texture2D
	var mode := "stand"
	var _w := 0

	# v5：贴图渲染（mahjong_graphic 精灵自带双层/圆角/透视/阴影）——程序画法退役。
	# 宽 w＝透视牌宽（物理短边 19.4mm 的屏幕投影）。**躺牌横着的是牌高（26mm 长边横向）**
	# ——躺牌显示宽＝w×359/272（精灵同 scale：竖 272px↔19.4mm、横 359px↔26mm；
	# 2026-09-18 用户纠偏：拿高比长是物理对应错位）。姿态规范纵横比保证多源精灵同宽必同高。
	const STAND_ASPECT := 389.0 / 272.0
	const FLAT_W_MUL := 359.0 / 272.0  # 躺牌横向＝牌高边：显示宽放大系数
	const FLAT_ASPECT := 301.0 / 359.0

	func _init(p_face: Texture2D, w: int, _h: int, p_mode: String) -> void:
		face = p_face
		_w = w
		mode = p_mode
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if p_mode == "flat" or p_mode == "flat_back":
			var fw := roundi(_w * FLAT_W_MUL)
			custom_minimum_size = Vector2(fw, roundi(fw * FLAT_ASPECT))
		else:
			custom_minimum_size = Vector2(_w, roundi(_w * STAND_ASPECT))

	func _draw() -> void:
		draw_texture_rect(face, Rect2(Vector2.ZERO, size), false)


static func make_tile(tile: MJTile, w: int, h: int, dimmed := false) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 不随行高拉伸（2026-09-18 尺寸系统：牌体尺寸只归透视管）
	var sb := StyleBoxFlat.new()
	sb.bg_color = SUIT_COLORS.get(tile.suit, Color.GRAY)
	if dimmed:
		sb.bg_color = sb.bg_color.darkened(0.25)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(0.1, 0.09, 0.08)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	var value_label := Label.new()
	value_label.text = str(tile.value)
	value_label.add_theme_font_size_override("font_size", maxi(11, int(h * 0.5)))
	value_label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	value_label.set_anchors_preset(Control.PRESET_CENTER)
	value_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	value_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(value_label)
	var suit_label := Label.new()
	suit_label.text = tile.suit
	suit_label.add_theme_font_size_override("font_size", maxi(9, int(h * 0.2)))
	suit_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.8))
	suit_label.position = Vector2(3, 1)
	panel.add_child(suit_label)
	return panel


## 背牌（敌方手牌：明码张数，不露内容）。
static func make_back(w: int, h: int) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 不随行高拉伸（2026-09-18 尺寸系统：牌体尺寸只归透视管）
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.22, 0.2)
	sb.set_corner_radius_all(5)
	sb.border_color = Color(0.38, 0.35, 0.3)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	return panel


static func glow(widget: Control, color: Color) -> Control:
	var sb := widget.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		var glow_sb := sb.duplicate() as StyleBoxFlat
		glow_sb.set_border_width_all(3)
		glow_sb.border_color = color
		widget.add_theme_stylebox_override("panel", glow_sb)
	return widget


## 刚摸到的牌（2026-09-17 用户令）：顶缘金条＝新牌标记（选中他牌即消失）。
static func fresh_mark(widget: Control) -> void:
	var bar := ColorRect.new()
	bar.color = Color(0.98, 0.82, 0.3)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widget.add_child(bar)
	bar.position = Vector2(2, 1)
	bar.size = Vector2(widget.custom_minimum_size.x - 4, 3)
