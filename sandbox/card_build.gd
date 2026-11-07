@tool
extends RefCounted
# 卡牌构建器：数据字典 → 整卡（300×422 基准，含式/气要求徽章）
# 改卡面内容不动这里——改调用方（card_lab.gd）的 DATA 字典；
# 只有改布局/位置才动下面的常量。
# shell 两档："art"＝AI 壳图华丽版（Fill 剪影＋壳贴图＋光效）
#            "simple"＝引擎画简版（细金边圆角直框＋金色分割线，零贴图）

const FILL_SHADER: Shader = preload("res://sandbox/card_fill_tex.gdshader")
const GLINT_SHADER: Shader = preload("res://sandbox/card_glint.gdshader")
const FILL_SHAPE: Texture2D = preload("res://sandbox/card_fill_v2.png")
const SHELL_TEX: Texture2D = preload("res://sandbox/card_shell_v9.png")
const FILL_TEX: Texture2D = preload("res://sandbox/card_fill_tex.png")

const W: float = 300.0
const H: float = 422.0

# 华丽版（AI 壳图＋纹理＋光效）完整配方存档——CardLab 已改回场景手调线，
# 此构建器留着备用：要用代码批量出卡（如四色并排）时 CardBuild.build(parent, FANCY_PRESET)
const FANCY_PRESET: Dictionary = {
	"title": "撩",
	"tag": "剑式·撩",
	"desc": "造成10点伤害，目标优先为预攻击敌人。",
	"art": "res://qiforge/assets/portraits/youming.png",
	"tint": Color(0.26, 0.26, 0.28, 1),
	"req_qi": 2,
	"req_shi": "撩",
	"shell": "art",
	"badge_shape": "circle",
}

# ── 布局常量（想微调位置就改这些数）──────────────────
const ART_RECT := Rect2(17, 51, 266, 354)     # 立绘窗（壳图版）
const ART_RECT_S := Rect2(16, 46, 268, 248)   # 立绘窗（简版：顶到分割线止）
const MASK_RECT := Rect2(16, 295, 268, 110)   # 底部蒙层
const DIVIDER_Y := 294.0                      # 分割线高度（3:7 立绘7）
const TITLE_RECT := Rect2(110, 0, 80, 43)     # 大字标题
const DESC_RECT := Rect2(19, 296, 262, 107)   # 效果文
const TAG_RECT := Rect2(101, 404, 95, 12)     # 底部小签
const BADGE_SIZE: float = 36.0                # 式/气徽章边长
const BADGE_Y: float = 5.0                    # 徽章离卡顶

# ── 定版色 ──────────────────────────────────────────
const IVORY := Color(0.94509804, 0.92156863, 0.8509804, 1)
const INK := Color(0.08235294, 0.08627451, 0.09803922, 1)
const MASK_COL := Color(0.94509804, 0.92156863, 0.8509804, 0.39215687)
const SHELL_TINT := Color(0.85, 0.845, 0.83, 1)
const GOLD := Color(0.76, 0.68, 0.46, 1)      # 简版细金边


static func build(parent: Control, d: Dictionary) -> Panel:
	var simple: bool = d.get("shell", "art") == "simple"
	var p: Panel = Panel.new()
	p.name = "Card"
	p.size = Vector2(W, H)
	p.add_theme_stylebox_override("panel", _simple_style(d) if simple else StyleBoxEmpty.new())
	parent.add_child(p)

	if not simple:
		_fill(p, d)
	_art(p, d, simple)
	_mask(p)
	_title(p, d)
	_desc(p, d)
	_tag(p, d)
	if simple:
		_divider(p, d)
	else:
		_shell(p)
	# 式/气要求徽章：DATA 里没填就不显示；形状 badge_shape："circle"圆章 / "half"半圆章
	var shape: String = d.get("badge_shape", "circle")
	var bw: float = (BADGE_SIZE + 8.0) if shape == "half" else BADGE_SIZE
	if d.has("req_qi"):
		_badge(p, Vector2(7.0, BADGE_Y), str(d["req_qi"]), "气", shape)
	if d.has("req_shi"):
		_badge(p, Vector2(W - 7.0 - bw, BADGE_Y), str(d["req_shi"]), "式", shape)
	return p


# ── 各层（叠放顺序＝下面调用顺序）────────────────────

static func _fill(p: Panel, d: Dictionary) -> void:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = FILL_SHADER
	m.set_shader_parameter("fill_tex", FILL_TEX)
	m.set_shader_parameter("tint", d.get("tint", Color(0.26, 0.26, 0.28, 1)))
	m.set_shader_parameter("pattern_strength", 0.9)
	m.set_shader_parameter("grain", 0.06)
	var r: TextureRect = TextureRect.new()
	r.name = "Fill"
	r.material = m
	r.texture = FILL_SHAPE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.add_child(r)
	_full_rect(r)

static func _art(p: Panel, d: Dictionary, simple: bool) -> void:
	var rect: Rect2 = ART_RECT_S if simple else ART_RECT
	var r: TextureRect = TextureRect.new()
	r.name = "Art"
	r.clip_contents = true
	r.position = rect.position
	r.size = rect.size
	r.texture = load(d.get("art", ""))
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	p.add_child(r)

static func _mask(p: Panel) -> void:
	var c: ColorRect = ColorRect.new()
	c.name = "Mask"
	c.position = MASK_RECT.position
	c.size = MASK_RECT.size
	c.color = MASK_COL
	p.add_child(c)

static func _title(p: Panel, d: Dictionary) -> void:
	var l: Label = Label.new()
	l.name = "title"
	l.text = d.get("title", "")
	l.position = TITLE_RECT.position
	l.size = TITLE_RECT.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _kaiti())
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", IVORY)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)

static func _desc(p: Panel, d: Dictionary) -> void:
	var l: Label = Label.new()
	l.name = "content"
	l.text = d.get("desc", "")
	l.custom_minimum_size = Vector2(DESC_RECT.size.x, 0)
	l.position = DESC_RECT.position
	l.size = DESC_RECT.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _kaiti())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)

static func _tag(p: Panel, d: Dictionary) -> void:
	var l: Label = Label.new()
	l.name = "tag"
	l.text = d.get("tag", "")
	l.position = TAG_RECT.position
	l.size = TAG_RECT.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 10)
	p.add_child(l)

static func _shell(p: Panel) -> void:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = GLINT_SHADER
	m.set_shader_parameter("base_tint", SHELL_TINT)
	m.set_shader_parameter("light_pos", Vector2(0.5, 0.35))
	m.set_shader_parameter("sheen_phase", 0.4)
	m.set_shader_parameter("glint_strength", 1.0)
	var r: TextureRect = TextureRect.new()
	r.name = "Shell"
	r.material = m
	r.texture = SHELL_TEX
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.add_child(r)
	_full_rect(r)

static func _simple_style(d: Dictionary) -> StyleBoxFlat:
	# 简版卡体：tint 底色 ＋ 细金边 ＋ 圆角（粗细/颜色/圆角都能在 DATA 里改）
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = d.get("tint", Color(0.26, 0.26, 0.28, 1))
	sb.set_border_width_all(int(d.get("border_w", 2)))
	sb.border_color = d.get("border_col", GOLD)
	sb.set_corner_radius_all(int(d.get("corner_r", 10)))
	return sb

static func _divider(p: Panel, d: Dictionary) -> void:
	# 金色分割线（3:7 位，立绘 7 文案 3）
	var col: Color = d.get("border_col", GOLD)
	var ln: ColorRect = ColorRect.new()
	ln.name = "divider"
	ln.position = Vector2(16.0, DIVIDER_Y)
	ln.size = Vector2(268.0, 2.0)
	ln.color = Color(col.r, col.g, col.b, 0.8)
	p.add_child(ln)

static func _badge(p: Panel, pos: Vector2, val: String, cap: String, shape: String = "circle") -> void:
	if shape == "half":
		var w: float = BADGE_SIZE + 8.0
		var hb: HalfBadge = HalfBadge.new()
		hb.name = "badge_" + cap
		hb.position = pos
		hb.size = Vector2(w, w / 2.0)
		p.add_child(hb)
		var hv: Label = Label.new()
		hv.text = val
		hv.position = Vector2(0, 1)
		hv.size = Vector2(w, w / 2.0)
		hv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hv.add_theme_font_override("font", _kaiti())
		hv.add_theme_font_size_override("font_size", 15)
		hv.add_theme_color_override("font_color", IVORY)
		hv.add_theme_color_override("font_outline_color", INK)
		hv.add_theme_constant_override("outline_size", 2)
		hb.add_child(hv)
		var hc: Label = Label.new()
		hc.text = cap
		hc.position = Vector2(pos.x, pos.y + w / 2.0 + 1.0)
		hc.size = Vector2(w, 12)
		hc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hc.add_theme_font_size_override("font_size", 9)
		hc.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68, 1))
		p.add_child(hc)
		return
	var b: Panel = Panel.new()
	b.name = "badge_" + cap
	b.position = pos
	b.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.06, 0.92)
	sb.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	sb.set_border_width_all(1)
	sb.border_color = Color(0.78, 0.68, 0.5, 0.9)
	b.add_theme_stylebox_override("panel", sb)
	p.add_child(b)
	var v: Label = Label.new()
	v.text = val
	v.position = Vector2(0, 1)
	v.size = Vector2(BADGE_SIZE, 22)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_theme_font_override("font", _kaiti())
	v.add_theme_font_size_override("font_size", 17)
	v.add_theme_color_override("font_color", IVORY)
	v.add_theme_color_override("font_outline_color", INK)
	v.add_theme_constant_override("outline_size", 2)
	b.add_child(v)
	var c: Label = Label.new()
	c.text = cap
	c.position = Vector2(0, 21)
	c.size = Vector2(BADGE_SIZE, 13)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override("font_size", 9)
	c.add_theme_color_override("font_color", Color(0.78, 0.75, 0.68, 1))
	b.add_child(c)


# ── 小件 ────────────────────────────────────────────

# 半圆徽章壳：真 180° 弧 StyleBoxFlat 画不出（圆角上限＝短边一半），自绘多边形
class HalfBadge extends Control:
	func _draw() -> void:
		var r: float = size.x / 2.0
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 24
		for i in range(n + 1):
			var a: float = PI + PI * float(i) / float(n)
			pts.append(Vector2(r + cos(a) * r, r + sin(a) * r))
		draw_colored_polygon(pts, Color(0.07, 0.065, 0.06, 0.92))
		draw_polyline(pts, Color(0.78, 0.68, 0.5, 0.9), 1.0, true)
		draw_line(Vector2(0.0, r), Vector2(size.x, r), Color(0.78, 0.68, 0.5, 0.9), 1.0, true)

static func _full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func _kaiti() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray(["Kaiti SC", "STKaiti"])
	return f
