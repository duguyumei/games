## 连击·金丹（2026-11-06 用户出图）：六边形退场，改「丹」。
## 丹体＋涡旋流光＋墨笔触圈＋裂纹＋飞火星；数字刻在丹面。
## 无连击整件隐藏；有连击显示 ×N；连击越高丹越烫（流光更快、裂纹浮现、火星更多）。
extends Control

const QISTYLE := preload("res://qiforge/QiStyle.gd")
const JD := preload("res://qiforge/QiJinAtlas.gd")

const PEARL := 190.0
const BRUSH := 268.0
const INK_NUM := Color(0.06, 0.11, 0.17)

var _value := 0
var _num_lbl: Label = null
var _x_lbl: Label = null
var _preview := -1
var _on := false
var _t := 0.0
var _pulse := 0.0

var _brush: TextureRect = null
var _pearl: TextureRect = null
var _flow: TextureRect = null
var _cracks: TextureRect = null
var _embers: Array = []
var _lbl_glow: TextureRect = null
var _smoke: Array = []
var _swirl_num: TextureRect = null
var _glow_n: Array = []
var _glow_x: Array = []
var _pearl_glow: TextureRect = null
var _floats: Array = []
var _halo: TextureRect = null
var _glyphs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(360.0, 360.0)
	pivot_offset = size * 0.5
	_build()
	visible = false
	set_process(true)

func _center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.5 - 60.0)   # 珠子整体上提，底下留出数字带

func _mk(cell_i: int, sz: float, col: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = JD.cell(cell_i)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(sz, sz)
	t.position = _center() - t.size * 0.5
	t.pivot_offset = t.size * 0.5
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = col
	add_child(t)
	return t

func _build() -> void:
	_halo = _mk(7, 330.0, Color(1, 1, 1, 0.0))
	_brush = _mk(2, BRUSH, Color(1, 1, 1, 0.85))
	_pearl = _mk(1, PEARL, Color(0.94, 1.0, 0.76))   # 压蓝 → 玉青，跟左侧气珠区分
	_flow = _mk(6, PEARL, Color(0.96, 1.0, 0.82))
	_cracks = _mk(8, PEARL * 0.94, Color(1, 1, 1, 0.0))
	for i in 4:
		var e := TextureRect.new()
		e.texture = JD.cell(3)
		e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e.size = Vector2(150.0, 150.0)
		e.pivot_offset = e.size * 0.5
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.modulate = Color(1, 1, 1, 0.0)
		e.set_meta("ph", float(i) / 4.0)
		e.set_meta("sw", 30.0 + 18.0 * float(i))
		add_child(e)
		_embers.push_back(e)
	for i in 2:
		var g := TextureRect.new()
		g.texture = JD.cell(4)
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.size = Vector2(150.0, 150.0)
		g.pivot_offset = g.size * 0.5
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.modulate = Color(0.16, 0.20, 0.26, 0.0)      # 墨色符纹：亮丹面与宣纸上都立得住
		g.set_meta("ph", float(i) / 2.0)
		add_child(g)
		_glyphs.push_back(g)
	_swirl_num = TextureRect.new()
	_swirl_num.texture = JD.cell(2)
	_swirl_num.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_swirl_num.size = Vector2(196.0, 196.0)
	_swirl_num.pivot_offset = _swirl_num.size * 0.5
	_swirl_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_swirl_num.modulate = Color(1, 1, 1, 0.0)
	_swirl_num.z_index = 1
	add_child(_swirl_num)
	_pearl_glow = TextureRect.new()
	_pearl_glow.texture = _radial()
	_pearl_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pearl_glow.size = Vector2(300.0, 300.0)
	_pearl_glow.pivot_offset = _pearl_glow.size * 0.5
	_pearl_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pearl_glow.modulate = Color(1.0, 0.88, 0.58, 0.0)
	add_child(_pearl_glow)
	_build_labels()

func _build_labels() -> void:
	var lx := Label.new()
	_x_lbl = lx
	lx.text = "×"
	QISTYLE.font(lx, 36, true)
	QISTYLE.text_color(lx, Color(1.0, 0.85, 0.46))
	lx.add_theme_color_override("font_outline_color", Color(0.14, 0.10, 0.05, 0.95))
	lx.add_theme_constant_override("outline_size", 5)
	lx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lx)
	_floats.push_back(lx)
	var l := Label.new()
	_num_lbl = l
	l.text = "1"
	QISTYLE.font(l, 66, true)
	QISTYLE.text_color(l, Color(1.0, 0.85, 0.46))
	l.add_theme_color_override("font_outline_color", Color(0.14, 0.10, 0.05, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.30))
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_floats.push_back(l)
	for gi in 2:
		var gn := Label.new()
		gn.text = "1"
		QISTYLE.font(gn, 66, true)
		QISTYLE.text_color(gn, Color(1.0, 0.86, 0.50))
		gn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gn.set_meta("sc", 1.05 + 0.06 * float(gi))
		gn.set_meta("al", 0.30 - 0.12 * float(gi))
		add_child(gn)
		_glow_n.push_back(gn)
	for gi2 in 2:
		var gx := Label.new()
		gx.text = "×"
		QISTYLE.font(gx, 36, true)
		QISTYLE.text_color(gx, Color(1.0, 0.86, 0.50))
		gx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gx.set_meta("sc", 1.06 + 0.07 * float(gi2))
		gx.set_meta("al", 0.26 - 0.10 * float(gi2))
		add_child(gx)
		_glow_x.push_back(gx)
	# 影子要在字后面
	for n in _glow_n.size():
		move_child(_glow_n[n], get_child_count() - 1 - (n + 1))
	for n2 in _glow_x.size():
		move_child(_glow_x[n2], get_child_count() - 1 - (n2 + 1) - _glow_n.size())
	# 烟：三缕从丹顶往右上溢
	for i in 3:
		var sm := TextureRect.new()
		sm.texture = JD.cell(9)
		sm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sm.size = Vector2(130.0, 210.0)
		sm.pivot_offset = sm.size * 0.5
		sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sm.modulate = Color(0.92, 0.97, 1.0, 0.0)
		sm.set_meta("ph", float(i) / 3.0)
		sm.set_meta("sw", 8.0 + 6.0 * float(i))
		add_child(sm)
		_smoke.push_back(sm)

static var _radial_cache: GradientTexture2D = null
static func _radial() -> GradientTexture2D:
	if _radial_cache != null:
		return _radial_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 96
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_radial_cache = t
	return t

func update_from(b: RefCounted) -> void:
	if b == null:
		return
	set_combo(int(b.get("combo_count")), bool(b.get("combo_enabled")))

func set_combo(v: int, on: bool) -> void:
	var jumped := v > _value
	_value = v
	_apply_scale()
	visible = on and v >= 1
	if visible and jumped:
		_pulse = 1.0
		_plume_flash()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(1.10, 1.10), 0.07)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.22)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 预览：悬卡时显示打出后的连击数（-1＝还原真值）
func set_preview(v: int) -> void:
	if _preview == v:
		return
	_preview = v
	_apply_scale()

## 连击数字：数值越大字号越大（2026-11-08 用户令；抖动后议）
func _apply_scale() -> void:
	var v := maxi(1, _value if _preview < 0 else _preview)
	var k := clampf(float(v - 1) / 7.0, 0.0, 1.0)
	var fs := int(round(54.0 + 46.0 * k))
	var xs := int(round(30.0 + 20.0 * k))
	if _num_lbl != null:
		_num_lbl.add_theme_font_size_override("font_size", fs)
		_num_lbl.text = str(v)
		_num_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.93, 0.62) if _preview >= 0 else Color(1.0, 0.85, 0.46))
	if _x_lbl != null:
		_x_lbl.add_theme_font_size_override("font_size", xs)
	for g in _glow_n:
		var gl: Label = g
		gl.add_theme_font_size_override("font_size", fs)
		gl.text = str(v)
	for gx in _glow_x:
		(gx as Label).add_theme_font_size_override("font_size", xs)
#endregion
func _plume_flash() -> void:
	var c := _center()
	var t := TextureRect.new()
	t.texture = JD.cell(9)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.size = Vector2(110.0, 230.0)
	t.position = Vector2(c.x - t.size.x * 0.5, c.y - 110.0 - t.size.y * 0.5)
	t.pivot_offset = Vector2(t.size.x * 0.5, t.size.y)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = Color(1, 1, 1, 0.0)
	t.z_index = 3
	add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.85, 0.06)
	tw.parallel().tween_property(t, "scale", Vector2(1.1, 1.35), 0.34)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(t, "modulate:a", 0.0, 0.26)
	tw.tween_callback(t.queue_free)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 2.2)
	var k := clampf(float(_value) / 6.0, 0.0, 1.0)
	var beat := 0.5 + 0.5 * sin(_t * (2.0 + 1.6 * k))       # 丹在「呼」
	if _pearl != null:
		_pearl.scale = Vector2.ONE * (1.0 + 0.018 * beat + 0.05 * _pulse)
		_pearl.modulate = Color(1, 1, 1, 1).lerp(Color(1.12, 1.10, 1.02, 1), k)
	if _flow != null:
		_flow.rotation += delta * (0.55 + 1.5 * k)
		_flow.scale = Vector2.ONE * (1.0 + 0.02 * beat)
		_flow.modulate.a = (0.30 + 0.55 * k) * (0.85 + 0.15 * beat) * (1.0 + 0.5 * _pulse)
	if _cracks != null:
		_cracks.modulate.a = 0.0 if _value < 4 else minf(0.85, 0.30 + 0.14 * float(_value - 4))
		_cracks.rotation = sin(_t * 0.7) * 0.03
	if _brush != null:
		_brush.rotation -= delta * (0.10 + 0.25 * k)
		_brush.modulate.a = 0.70 + 0.25 * k
	var c := _center()
	for i in _embers.size():
		var e: TextureRect = _embers[i]
		var ph: float = e.get_meta("ph")
		var pr: float = fmod(_t * (0.28 + 0.22 * k) + ph, 1.0)
		var sw: float = e.get_meta("sw")
		e.position = Vector2(c.x + sin(pr * 6.0 + ph * 6.28) * sw - e.size.x * 0.5,
			c.y + 40.0 - pr * 175.0 - e.size.y * 0.5)
		e.modulate.a = sin(pr * PI) * (0.20 + 0.55 * k) * (1.0 + 0.6 * _pulse)
		e.rotation = pr * 1.6
	if _floats.size() >= 2:
		var lx: Label = _floats[0]
		var ln: Label = _floats[1]
		var txt := str(maxi(1, _value))
		if ln.text != txt:
			ln.text = txt
		var fnt := ln.get_theme_font("font")
		var fs := ln.get_theme_font_size("font_size")
		var wn := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var fx := lx.get_theme_font("font")
		var fsx := lx.get_theme_font_size("font_size")
		var wx := fx.get_string_size("×", HORIZONTAL_ALIGNMENT_LEFT, -1, fsx).x
		var right := c.x + 108.0
		var top := c.y - 128.0
		ln.position = Vector2(right - wn, top)
		lx.position = Vector2(right - wn - wx - 2.0, top + (fs - fsx) * 0.62)
		var al := (0.86 + 0.14 * beat) * (0.85 + 0.15 * k) * (1.0 + 0.5 * _pulse)
		ln.modulate.a = al
		lx.modulate.a = al
		var sc := 1.0 + 0.05 * _pulse
		ln.scale = Vector2.ONE * sc
		lx.scale = Vector2.ONE * sc
		for n3 in _glow_n.size():
			var gn: Label = _glow_n[n3]
			gn.text = ln.text
			gn.position = ln.position
			gn.pivot_offset = Vector2(wn * 0.5, fs * 0.45)
			gn.scale = Vector2.ONE * float(gn.get_meta("sc"))
			gn.modulate.a = float(gn.get_meta("al")) * (0.35 + 0.65 * k) * (1.0 + 0.5 * _pulse)
		for n4 in _glow_x.size():
			var gx: Label = _glow_x[n4]
			gx.position = lx.position
			gx.pivot_offset = Vector2(wx * 0.5, fsx * 0.45)
			gx.scale = Vector2.ONE * float(gx.get_meta("sc"))
			gx.modulate.a = float(gx.get_meta("al")) * (0.35 + 0.65 * k) * (1.0 + 0.5 * _pulse)
		if _pearl_glow != null:
			_pearl_glow.position = c - _pearl_glow.size * 0.5
			_pearl_glow.modulate.a = (0.06 + 0.22 * k) * (0.92 + 0.08 * beat) * (1.0 + 0.4 * _pulse)
	for i in _smoke.size():
		var sm: TextureRect = _smoke[i]
		var sp: float = fmod(_t * (0.16 + 0.10 * k) + float(sm.get_meta("ph")), 1.0)
		var sw: float = sm.get_meta("sw")
		sm.position = Vector2(c.x - 6.0 + sp * 58.0 + sin(sp * 5.0 + float(i)) * sw - sm.size.x * 0.5,
			c.y - 34.0 - sp * 172.0 - sm.size.y * 0.5)
		sm.modulate.a = sin(sp * PI) * (0.16 + 0.26 * k) * (1.0 + 0.4 * _pulse)
		sm.rotation = sin(sp * 3.0 + float(i) * 2.0) * 0.22
		sm.scale = Vector2.ONE * (0.72 + 0.45 * sp)
