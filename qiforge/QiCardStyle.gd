## qi-forge 统一卡牌系统（卡面 v3.1，2026-10-28 用户裁定：左上＝能量消耗）：
## **唯一基准 300×422 ＋ 场合缩放系数**（替代旧三档实物尺寸制）——全项目只有一套按 300×422
## 标定的卡面布局，五档系数：单位 0.60（180×253）／手牌 0.72（216×304）／备战 0.78（234×329）
## ／详情 0.90（270×380）／迷你 0.11（33×46）。系数在建卡时按真实像素等比落位（非节点 scale，
## 避容器量尺寸陷阱）；除五档系数外不得另立宽高、不得缩放、不得散建卡面。
## 分区（v3.2，2026-10-28 用户裁定：心法/术法之分整体退场——器灵就是器灵、牌一律功法）：
## **左上＝功法卡能量点（器灵卡留空）** → 右上留空 → 立绘区（暂空压暗）→ 名字带
## （**器灵卡＝菱头横带、功法卡＝长方形匾额**）→ 效果区。
## 区域保护（用户裁定）：效果/详情文字逐级自适应缩号（_wire_fit），到底仍溢出行尾省略，
## 且效果面板 clip_contents 硬裁——长文案绝不画出卡面；完整信息由详情卡承载。
## 升级预览（v3.0 起）：make_spell_card 可带 diff 行（增「＋」绿／删「－」红／改「改」琥珀，
## 其余「·」墨色），名字/费用变化时名字带文字与能量点描边转琥珀。
## 弹窗走 QiDialog；字体＝QiFontBank（≥18px 展示字走 display()）。
## @tool：仅为 TcgCard（含光效驱动）能在编辑器预览台里跑 _process；静态工厂函数不受影响。
@tool
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
## 式徽公共件（2026-11-05 用户令：卡内式徽章与顶部已积攒式同款）
const STANCE_BADGE = preload("res://qiforge/QiStanceBadge.gd")
## 金件光效（外框＋分割线光泽带）：band_pos 由 TcgCard._process 驱动（待机慢扫/悬停跟手）
const GLINT_SHADER: Shader = preload("res://qiforge/assets/tcg_glint.gdshader")

## 唯一基准画布（一套布局只按此标定）
const BASE_SIZE: Vector2 = Vector2(300, 422)
## 场合系数表（宽度锚定旧制横宽：180/216/234/270/33，高度随基准比例）
const SCALES: Dictionary = {"field": 0.60, "hand": 0.72, "prep": 0.78, "detail": 0.90, "mini": 0.11}
## 效果文自适应字号下限
const FIT_FLOOR: int = 10

static func scale_of(ctx: String) -> float:
	return float(SCALES.get(ctx, SCALES["field"]))

static func size_of(ctx: String) -> Vector2:
	return Vector2(round(BASE_SIZE.x * scale_of(ctx)), round(BASE_SIZE.y * scale_of(ctx)))

## HUD 贴图（运行时读 PNG；与 QiVcCabinet._art 同源）
static var _hud_tex_cache: Dictionary = {}

static func _hud_tex(name: String) -> Texture2D:
	if _hud_tex_cache.has(name):
		return _hud_tex_cache[name]
	var p := "res://qiforge/assets/hud/%s.png" % name
	var t: Texture2D = null
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	if img != null and not img.is_empty():
		t = ImageTexture.create_from_image(img)
	_hud_tex_cache[name] = t
	return t

## 心法线配色（攻击/防御/身法三线——仅旧线兼容别名在用，随 Root 线终裁再删）
const IDENTITY_COLORS: Dictionary = {
	"身法": Color(0.227, 0.651, 0.353),
	"护体": Color(0.788, 0.635, 0.227),
	"催破": Color(0.788, 0.227, 0.227),
}
## 功法卡配色（蓝）
const SPELL_COLOR: Color = Color(0.227, 0.435, 0.788)
## 器灵卡体色（绿；原心法「身法」色系沿用——2026-10-28 心法/术法退场后器灵卡唯一定色）
const SPIRIT_COLOR: Color = Color(0.227, 0.651, 0.353)

## 包 → 旧线心法体色（现役器灵卡用上方 SPIRIT_COLOR；随 Root 线终裁再删）
const PACK_IDENTITY: Dictionary = {
	"run_start_option_qif_B": "身法",
	"run_start_option_qif_C": "身法",
	"run_start_option_qif_E": "身法",
	"run_start_option_qif_F": "身法",
	"run_start_option_qif_G": "身法",
}

const COLOR_CREAM: Color = Color(0.949, 0.922, 0.847)
const COLOR_AMBER: Color = Color(0.976, 0.859, 0.451)
const COLOR_AMBER_DARK: Color = Color(0.788, 0.635, 0.227)
const COLOR_AMBER_TEXT: Color = Color(0.416, 0.329, 0.063)
const COLOR_INK: Color = Color(0.16, 0.14, 0.11)
const COLOR_NAVY: Color = Color(0.102, 0.129, 0.192)
const COLOR_INK_TEXT: Color = Color(0.2, 0.188, 0.165)
## diff 行配色（增/删/改）
const COLOR_DIFF_ADD: Color = Color(0.227, 0.651, 0.353)
const COLOR_DIFF_DEL: Color = Color(0.788, 0.227, 0.227)
const COLOR_DIFF_MOD: Color = Color(0.70, 0.50, 0.10)

static func identity_of(pack_id: String) -> String:
	return PACK_IDENTITY.get(pack_id, "身法")

## 器灵立绘索引（名→res 路径；未录者保持压暗占位；资源未导入/缺失时 portrait_of 返 null 退占位）
const PORTRAITS: Dictionary = {
	"幽冥剑": "res://qiforge/assets/portraits/youming.png",
}
static var _portrait_cache: Dictionary = {}

static func portrait_of(name_text: String) -> Texture2D:
	if not PORTRAITS.has(name_text):
		return null
	if not _portrait_cache.has(name_text):
		var tex: Texture2D = load(String(PORTRAITS[name_text])) as Texture2D
		if tex == null:
			return null
		_portrait_cache[name_text] = tex
	return _portrait_cache[name_text]

## 菱头名字带（StyleBoxFlat 只有圆角做不了斜角，自绘六边形）
class DiamondBand extends Control:
	var band_color: Color = Color(0.0, 0.0, 0.0, 0.32)
	var tip: float = 13.0
	func _draw() -> void:
		var half: float = size.y * 0.5
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(tip, 0.0), Vector2(size.x - tip, 0.0), Vector2(size.x, half),
			Vector2(size.x - tip, size.y), Vector2(tip, size.y), Vector2(0.0, half),
		])
		draw_colored_polygon(points, band_color)

#region 统一入口（一套基准布局 × 场合系数）
## 器灵卡（菱头名字带；基础效果面；左上/右上留空——器灵等级轴 v0.6 已退役，无 Lv 徽）
static func make_spirit_card(spirit: Dictionary, ctx: String = "field") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPIRIT_COLOR, k)
	_add_art_zone(card, k, false, portrait_of(str(spirit.get("name", ""))))
	_add_band(card, k, str(spirit.get("name", "")), true)
	_add_effect_panel(card, k, str(spirit.get("desc", "")), 0, "")
	return card

## 纯立绘卡（整卡＝立绘位，COVERED 裁切；备战舱展示位/战斗我方位共用件；
## 无立绘器灵退「立绘位」占位——2026-10-29 用户裁定战斗我方卡整卡改立绘）
static func make_portrait_panel(name_text: String, ctx: String = "prep") -> Panel:
	var k: float = scale_of(ctx)
	var p: Panel = Panel.new()
	p.custom_minimum_size = size_of(ctx)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.165, 0.141, 0.094)
	sb.border_color = Color("6b5426")
	sb.set_border_width_all(maxi(2, roundi(3.0 * k)))
	sb.set_corner_radius_all(maxi(4, roundi(13.0 * k)))
	p.add_theme_stylebox_override("panel", sb)
	var pic: Texture2D = portrait_of(name_text)
	if pic != null:
		var tr: TextureRect = TextureRect.new()
		tr.texture = pic
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		var inset: float = maxi(3.0, roundi(4.0 * k))
		tr.offset_left = inset
		tr.offset_top = inset
		tr.offset_right = -inset
		tr.offset_bottom = -inset
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(tr)
		return p
	_center_text(p, "立绘位", _fs(23, k), Color(0.36, 0.31, 0.24))
	return p

## 旧线兼容别名（心法制遗名；复原中的 Root 线在用——随 Root 线终裁一并删）
static func make_xinfa_card(xinfa: Dictionary, level: int, ctx: String = "field") -> Button:
	var identity: String = identity_of(str(xinfa.get("id", "")))
	var k: float = scale_of(ctx)
	var card: Button = _new_card(IDENTITY_COLORS.get(identity, Color(0.42, 0.42, 0.48)), k)
	_add_lv_pill(card, k, level)
	_add_art_zone(card, k)
	_add_band(card, k, str(xinfa.get("name", "")), true)
	_add_effect_panel(card, k, str(xinfa.get("desc", "")), 0, "")
	return card

## 功法卡（左上能量点＋长方形名字带；preview 携 diff 行与变化标记）
## preview: {"lines": [{t, cls}], "name_changed": bool, "cost_changed": bool}
static func make_spell_card(spell_name: String, cost: int, desc: String,
		power: int = 0, spec: String = "", ctx: String = "field",
		preview: Dictionary = {}) -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPELL_COLOR, k)
	_add_cost_pip(card, k, cost, bool(preview.get("cost_changed", false)))
	_add_art_zone(card, k)
	_add_band(card, k, spell_name, false, bool(preview.get("name_changed", false)))
	_add_effect_panel(card, k, desc, power, spec, preview.get("lines", []))
	return card

## 战斗手牌卡（并入统一布局，手牌档系数；保留旧入口名）
static func make_hand_spell_card(spell_name: String, cost: int, desc: String) -> Button:
	return make_spell_card(spell_name, cost, desc, 0, "", "hand")

#region VC 制卡（复刻线 2026-10-31；2026-11-03 像素卡面轮：照「吸血鬼爬行者」卡面语言重排）
## 版式（基准 300×422，仍走五档系数，不另立宽高）：
## 左上＝费用球（半搭角）→ 立绘窗（像素立绘＋暗底）→ 名字带（色底横匾）→ 效果窗（正文）→ 底部卡型色条。
## 像素感＝硬直角＋粗外框＋内斜切高光＋文字描边＋最近邻放大立绘；不用位图素材、不引像素字体。
## 四色轴沿用：红武器／蓝防御／黄特殊／紫法力（体色只换色，不换版式）。
const VC_COLORS: Dictionary = {
	"red": Color(0.647, 0.263, 0.227),
	"blue": Color(0.243, 0.398, 0.616),
	"yellow": Color(0.702, 0.573, 0.239),
	"purple": Color(0.486, 0.345, 0.639),
}

## 像素卡四色（frame＝外框/名字带底色，body＝卡体，band＝名字带，gem＝费用球）
const VC_PIXEL: Dictionary = {
	"red": {"frame": Color("d9564a"), "body": Color("2a1416"), "band": Color("7a2a24")},
	"blue": {"frame": Color("5b8fd6"), "body": Color("131c2c"), "band": Color("2b4a78")},
	"yellow": {"frame": Color("e0b84f"), "body": Color("2a2211"), "band": Color("6b5220")},
	"purple": {"frame": Color("a97ad6"), "body": Color("1f1730"), "band": Color("4a3061")},
}
const VC_TEXT: Color = Color("ded6c6")
const VC_TEXT_DIM: Color = Color("b6ad9c")

static func vc_color_of(color_key: String) -> Color:
	return VC_COLORS.get(color_key, VC_COLORS["red"])

static func vc_pixel_of(color_key: String) -> Dictionary:
	return VC_PIXEL.get(color_key, VC_PIXEL["red"])

## VC 卡（卡定义来自 QiVcData.CARDS：name/cost/color/desc/pip）
static func make_vc_card(card_def: Dictionary, ctx: String = "hand") -> Button:
	var key: String = str(card_def.get("color", "red"))
	var k: float = scale_of(ctx)
	var pal: Dictionary = vc_pixel_of(key)
	var card: Button = _vc_pixel_card(k, pal)
	# 立绘窗（14~286 × 14~182）：暗底＋像素立绘居中
	var art: Panel = Panel.new()
	_place_abs(art, 14.0 * k, 14.0 * k, 286.0 * k, 206.0 * k)
	art.add_theme_stylebox_override("panel", _vc_box(Color(pal["frame"]).darkened(0.74),
		Color(pal["frame"]).darkened(0.5), maxi(2, roundi(3.0 * k)), 2.0 * k))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	card.add_child(art)
	var sprite := TextureRect.new()
	sprite.texture = _vc_sprite(key)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(176.0 * k, 176.0 * k)
	sprite.position = Vector2(272.0 * 0.5 * k - 88.0 * k, 192.0 * 0.5 * k - 88.0 * k)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(sprite)
	# 名字带（186~228）：色底横匾＋上下深描
	var band: Panel = Panel.new()
	_place_abs(band, 0.0, 210.0 * k, 300.0 * k, 252.0 * k)
	var band_box: StyleBoxFlat = _vc_box(Color(pal["band"]), Color(pal["band"]).darkened(0.45),
		maxi(1, roundi(2.0 * k)), 0.0)
	band_box.border_width_top = maxi(2, roundi(3.0 * k))
	band_box.border_width_bottom = maxi(2, roundi(3.0 * k))
	band.add_theme_stylebox_override("panel", band_box)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(band)
	var name_lbl: Label = _vc_label(band, str(card_def.get("name", "")),
		_fs(24, k), COLOR_CREAM, maxi(2, roundi(4.0 * k)))
	name_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(name_lbl, _fs(24, k), true)
	# 效果窗（236~406）：正文顶对齐，超长走缩号＋裁切
	var eff: Panel = Panel.new()
	_place_abs(eff, 14.0 * k, 258.0 * k, 286.0 * k, 398.0 * k)
	eff.add_theme_stylebox_override("panel", _vc_box(Color("121016"),
		Color(pal["frame"]).darkened(0.45), maxi(2, roundi(3.0 * k)), 2.0 * k))
	eff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eff.clip_contents = true
	card.add_child(eff)
	# 2026-11-07 用户令：攻击卡描述＝伤害/暴击句——整句亮色＋描边（伤害跟连击走、暴击是
	# 词条，两类特殊字段统一高亮；词条详解住 hover 浮窗不进卡面）
	var desc: Label = _vc_label(eff, str(card_def.get("desc", "")),
		_fs(20, k), COLOR_CREAM if String(card_def.get("kind", "")) == "attack" else VC_TEXT,
		maxi(1, roundi(2.0 * k)))
	desc.set_anchors_preset(Control.PRESET_FULL_RECT)
	desc.offset_left = 10.0 * k
	desc.offset_top = 8.0 * k
	desc.offset_right = -10.0 * k
	desc.offset_bottom = -8.0 * k
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(desc, _fs(20, k))
	# 底部卡型色条（406~422）
	var strip: Panel = Panel.new()
	_place_abs(strip, 0.0, 398.0 * k, 300.0 * k, 422.0 * k)
	strip.add_theme_stylebox_override("panel", _vc_box(Color(pal["frame"]),
		Color(pal["band"]).darkened(0.4), 0, 0.0))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(strip)
	var kind: String = {"red": "武学", "blue": "御守", "yellow": "奇珍", "purple": "气机"}.get(key, "武学")
	var kind_lbl: Label = _vc_label(strip, kind, _fs(15, k), Color(0.12, 0.09, 0.07), 0)
	kind_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	kind_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 费用球（半搭左上角）：方球＋深描＋内高光
	var pip_val: Variant = card_def.get("pip", int(card_def.get("cost", 0)))   # pip 覆写：式型/×N/气费
	var pip: Panel = Panel.new()
	_place_abs(pip, -12.0 * k, -12.0 * k, 46.0 * k, 46.0 * k)
	pip.name = "CostPip"
	pip.add_theme_stylebox_override("panel", _vc_box(Color(pal["frame"]),
		Color("0b0a0e"), maxi(2, roundi(4.0 * k)), maxi(2, roundi(8.0 * k))))
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gloss: Panel = Panel.new()
	_place_abs(gloss, 7.0 * k, 7.0 * k, 33.0 * k, 13.0 * k)
	gloss.add_theme_stylebox_override("panel", _vc_box(Color(1, 1, 1, 0.22), Color(0, 0, 0, 0), 0, 2.0 * k))
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.add_child(gloss)
	var pip_text: String = str(pip_val)
	var pip_lbl: Label = _vc_label(pip, pip_text,
		_fs(26, k) if pip_text.length() < 2 else _fs(19, k), COLOR_CREAM, maxi(2, roundi(3.0 * k)))
	pip_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.add_child(pip)
	return card

## VC 卡定义 → TCG 卡定义（战斗手牌/奖励屏接入用；2026-11-03 普攻催破合并轮）
## kind→tone/type_line 映射；need={stance,n}→耗式图标序列；gain/stance→得式；cost→气费。
static func tcg_def_of(d: Dictionary) -> Dictionary:
	# 状态制（2026-11-08）：stance＝剑型四类（short/long/great/flex）；need/gain 轨道退役
	# （式不再攒耗——卡面左右式轨不画）；type_line 按 FORMS 中文；tone 按型配色。
	var kind := String(d.get("kind", "effect"))
	var stance := String(d.get("stance", ""))
	var out := {"name": String(d.get("name", "")), "qi": int(d.get("cost", 0)),
		"need": [], "gain": "", "rules": String(d.get("desc", "")), "flavor": "",
		"tone": "red", "type_line": "攻击", "stance": String(d.get("stance", ""))}
	match kind:
		"defense":
			out["tone"] = "green"
			out["type_line"] = "护体"
		"effect":
			out["tone"] = "gold"
			out["type_line"] = "奇窍"
		_:
			# 颜色按**功能**（2026-11-08 用户口径）：攻击一律红，不再按剑型上色；
			# 剑型只走底部的型图标＋文字（短/长/巨/变招）
			out["tone"] = "red"
			var fcn: String = String({"short": "短剑", "long": "长剑", "great": "巨剑", "flex": "变招"}.get(stance, ""))
			out["type_line"] = ("攻击 · %s" % fcn) if fcn != "" else "攻击"
	return out

## 卡体：硬直角＋粗色框；悬停转亮琥珀描边（不改版式）
static func _vc_pixel_card(k: float, pal: Dictionary) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(round(BASE_SIZE.x * k), round(BASE_SIZE.y * k))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var radius: int = roundi(2.0 * k)
	var normal: StyleBoxFlat = _vc_box(Color(pal["body"]), Color(pal["frame"]),
		maxi(2, roundi(5.0 * k)), radius)
	normal.shadow_color = Color(0, 0, 0, 0.45)
	normal.shadow_size = maxi(2, roundi(6.0 * k))
	normal.shadow_offset = Vector2(0, 3.0 * k)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = COLOR_CREAM
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return card

static func _vc_box(bg: Color, edge: Color, border: int, radius: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.anti_aliasing = true   # 金框/分割线/效果区统一开抗锯齿（2026-11-08 用户指正外框锯齿）
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(roundi(radius))
	return sb

static func _vc_label(parent: Control, text: String, size: int, color: Color,
		outline: int) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

## 像素立绘（32×32 手绘点阵，最近邻放大）：红剑／蓝盾／黄方孔钱／紫焰
static func _vc_sprite(color_key: String) -> ImageTexture:
	var s: int = 32
	var img: Image = Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match color_key:
		"blue":
			_vc_sprite_shield(img, s)
		"yellow":
			_vc_sprite_coin(img, s)
		"purple":
			_vc_sprite_flame(img, s)
		_:
			_vc_sprite_sword(img, s)
	return ImageTexture.create_from_image(img)

static func _vc_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)

static func _vc_sprite_sword(img: Image, s: int) -> void:
	var steel: Color = Color("d6dbe6")
	var shade: Color = Color("8d95a8")
	var gold: Color = Color("e0b84f")
	var dark: Color = Color("23262f")
	for i in 4:                                    # 剑尖
		for x in range(16 - i, 16 + i):
			_vc_px(img, x, 1 + i, dark)
	for y in range(4, 21):                         # 剑身
		for x in range(14, 18):
			_vc_px(img, x, y, steel if x < 16 else shade)
		for x in [13, 18]:
			_vc_px(img, x, y, dark)
	for y in [21, 22]:                             # 护手
		for x in range(8, 24):
			_vc_px(img, x, y, gold)
	for y in range(23, 29):                        # 剑柄
		for x in range(15, 17):
			_vc_px(img, x, y, dark)
	for x in range(13, 19):                        # 剑首
		_vc_px(img, x, 29, gold)

static func _vc_sprite_shield(img: Image, s: int) -> void:
	var face: Color = Color("6f9fd8")
	var edge: Color = Color("274067")
	var mark: Color = Color("efe7d2")
	for y in range(5, 27):
		var half: float = 11.0 if y < 19 else 11.0 - float(y - 19) * 0.9
		var lo: int = int(round(16.0 - half))
		var hi: int = int(round(16.0 + half))
		for x in range(lo, hi):
			var c: Color = face if (x - lo > 1 and hi - x > 1 and y > 6) else edge
			_vc_px(img, x, y, c)
	for y in range(9, 24):                         # 竖纹
		_vc_px(img, 15, y, mark)
		_vc_px(img, 16, y, mark)
	for x in range(10, 23):                        # 横纹
		_vc_px(img, x, 14, mark)
		_vc_px(img, x, 15, mark)

static func _vc_sprite_coin(img: Image, s: int) -> void:
	var gold: Color = Color("e0b84f")
	var deep: Color = Color("8a6a20")
	for y in range(s):
		for x in range(s):
			var dx: float = float(x) - 15.5
			var dy: float = float(y) - 15.5
			var d: float = sqrt(dx * dx + dy * dy)
			if d <= 11.0:
				_vc_px(img, x, y, gold if d < 9.5 else deep)
			if d <= 6.5 and d > 4.5:
				_vc_px(img, x, y, deep)
	for y in range(13, 19):                        # 方孔
		for x in range(13, 19):
			_vc_px(img, x, y, Color("2a2211"))

static func _vc_sprite_flame(img: Image, s: int) -> void:
	for y in range(3, 29):
		var t: float = float(y - 3) / 25.0
		var half: float = 2.0 + 8.0 * sin(t * PI * 0.9)
		var lo: int = int(round(16.0 - half))
		var hi: int = int(round(16.0 + half))
		for x in range(lo, hi):
			var edge_hit: bool = (x - lo <= 1 or hi - x <= 2)
			_vc_px(img, x, y, Color("5b3a86") if edge_hit else Color("a97ad6"))
	for y in range(14, 27):                        # 内焰
		var half2: float = 1.0 + 4.0 * sin(float(y - 14) / 12.0 * PI)
		for x in range(int(round(16.0 - half2)), int(round(16.0 + half2))):
			_vc_px(img, x, y, Color("efe0ff"))
#region TCG 卡（2026-11-03：金框武侠卡；顶部带＝气／名／得式；立绘占满中段；
## 耗式图标悬浮于立绘左上；种类条与效果区均为半透明蒙层浮在立绘上（用户裁定：不再分区占位））
## 版式（基准 300×422，仍走五档系数）：先铺立绘（整段）→ 再浮种类条／效果蒙层／耗式icons。
const TCG_INK := Color("2a1d12")
const TCG_INK_SOFT := Color("5f513c")
const TCG_PARCH := Color("e9dfc6")
const TCG_PARCH_DARK := Color("d9cbaa")
const TCG_PARCH_EDGE := Color("a8905f")
const TCG_GOLD := Color("c8a24e")
const TCG_GOLD_DARK := Color("7d5f22")

## —— 卡框金件参数（唯一源）：外框／分割线／气珠环都从这里取，后续加件也走这套 ——
const FRAME_INSET: float = 0.0      # 金框距卡边（单层贴边，去掉卡体自身描边）
const FRAME_W: float = 4.0          # 金框宽（四边等宽）
const FILLET_R: int = 9             # 分割线与外框相接的圆角半径
const DIVIDER_H: float = 4.0        # 分割线厚度
const BAND_BOTTOM: float = 52.0     # 顶条底边（分割线上沿）
const QI_R: float = 20.0            # 气珠半径
const QI_EDGE: float = 2.0          # 气珠金环宽
## 卡型色（顶条底）：攻击朱／防御靛／效果赭金／器灵墨
const TCG_HEADERS: Dictionary = {
	"red": Color("5a2320"),
	"blue": Color("1f3352"),
	"green": Color("1f3a2a"),
	"gold": Color("4a3a18"),
	"ink": Color("241f1a"),
}

const QI_FILL: Color = Color("e4ebf3")   # 气色：银白（真气）——与四色轴区分最清楚

const TCG_FRAMES: Dictionary = {
	"blue": Color("1c2c3f"),
	"red": Color("3a1f1d"),
	"green": Color("1f3126"),
	"gold": Color("3a2f18"),
	"ink": Color("221d18"),
}

## 三式图标配色（劈朱／刺青／撩紫——同一式在卡面与战斗计数上同色）
const STANCE_COLORS: Dictionary = {
	"斩": Color("a3352c"),
	"刺": Color("2c4a6e"),
	"撩": Color("3d5a44"),
}

static func tcg_frame_color(tone: String) -> Color:
	return TCG_FRAMES.get(tone, TCG_FRAMES["blue"])

## TCG 卡实体（Button＋光泽带驱动）：待机＝斜光带慢扫金件；悬停＝光带跟鼠标走
class TcgCard extends Button:
	var glint_mat: ShaderMaterial
	var _phase: float = 0.2
	func _process(delta: float) -> void:
		if glint_mat == null:
			return
		var target: float
		var r: Rect2 = get_global_rect()
		var m: Vector2 = get_global_mouse_position()
		if r.grow(8.0).has_point(m):
			# 判「鼠标在卡矩形内」不判按钮悬停态——手牌内层不收鼠标也能跟光
			var uv: Vector2 = Vector2(
				clampf((m.x - r.position.x) / maxf(1.0, r.size.x), 0.0, 1.0),
				clampf((m.y - r.position.y) / maxf(1.0, r.size.y), 0.0, 1.0))
			target = (uv.x * 0.71 + uv.y) * 0.7071
		else:
			# 2026-11-05 用户令「左上角一直泛白光」：待机慢扫撤（全手牌同相位＝常亮观感）——
			# 待机 band 推出卡外全暗，光带只在悬停跟手时出现
			target = -0.35
		_phase = lerpf(_phase, target, minf(1.0, 5.0 * delta))
		glint_mat.set_shader_parameter("band_pos", _phase)

## 武侠卡（def：name / qi（气费）/ gain（获得的式，空不显）/ fragile（脆皮）/ need（耗式图标序列）
## / type_line / rules / flavor / tone / art）
static func make_tcg_card(def: Dictionary, ctx: String = "detail") -> Button:
	var k: float = scale_of(ctx)
	var tone: String = str(def.get("tone", "blue"))
	var frame: Color = tcg_frame_color(tone)
	var qi_v: Variant = def.get("qi", null)
	var gain_v: Variant = def.get("gain", "")
	var gain_icons: Array = gain_v if gain_v is Array else ([] if str(gain_v) == "" else [str(gain_v)])
	var gain_text: String = ""
	var fragile: bool = bool(def.get("fragile", false))
	var cracked: bool = bool(def.get("cracked", false))   # 2026-11-06 碎牌：打过 3 次的裂痕态
	var need: Array = def.get("need", [])
	var has_qi: bool = qi_v != null
	var card: TcgCard = TcgCard.new()
	card.custom_minimum_size = Vector2(round(BASE_SIZE.x * k), round(BASE_SIZE.y * k))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var glint_mat: ShaderMaterial = ShaderMaterial.new()
	glint_mat.shader = GLINT_SHADER
	# 2026-11-08 用户报「左上角一直亮」：shader 默认 band_pos=0.2 正好压在左上角，
	# 静态卡（无 _process 驱动）就会常亮——初始化直接推到卡外
	glint_mat.set_shader_parameter("band_pos", -0.35)
	glint_mat.set_shader_parameter("strength", 0.0)   # 临时：排查明暗不均是否为光带所致
	card.glint_mat = glint_mat
	# 卡底＝深色（深底不会露出米白边）；圆角比金框**更大**，
	# 让卡底的四角始终缩在金框笔画之内（不再需要额外描边来盖缝）——2026-11-08 用户指正
	# 卡底：深色，圆角比金框大 → 四角缩在金框内（2026-11-08）
	var normal: StyleBoxFlat = _vc_box(frame, TCG_GOLD, 0, roundi((12.0 + FRAME_W) * k))
	var hover: StyleBoxFlat = normal.duplicate()
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", hover)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# 顶部条带（气／名／得式）：浅一档羊皮纸＋底金线，与立绘区分隔
	var hdr := Panel.new()
	_place_abs(hdr, round((FRAME_INSET + FRAME_W) * k), round((FRAME_INSET + FRAME_W) * k),
		round((300.0 - FRAME_INSET - FRAME_W) * k), round(BAND_BOTTOM * k))
	var hdr_box: StyleBoxFlat = _vc_box(TCG_HEADERS.get(tone, TCG_HEADERS["blue"]), TCG_GOLD, 0, 0)
	var hdr_r: int = maxi(2, roundi(12.0 * k) - 2 * maxi(2, roundi(FRAME_W * k)))
	hdr_box.corner_radius_top_left = hdr_r
	hdr_box.corner_radius_top_right = hdr_r
	hdr.add_theme_stylebox_override("panel", hdr_box)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hdr)
	# 立绘先落：整段中区（56~402）通铺，后面一切皆为浮层
	var art := Panel.new()
	_place_abs(art, round((FRAME_INSET + FRAME_W) * k), round(54.0 * k),
		round((300.0 - FRAME_INSET - FRAME_W) * k), round((422.0 - FRAME_INSET - FRAME_W) * k))
	art.add_theme_stylebox_override("panel", _vc_box(frame, TCG_GOLD_DARK, 0, 0))
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	card.add_child(art)
	var art_tex: Variant = def.get("art", null)
	var pic := TextureRect.new()
	pic.texture = art_tex if art_tex is Texture2D else _tcg_art_texture(frame)
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(pic)

	# 金件：外框＋分割线（参数集中在 FRAME_* / DIVIDER_* / BAND_BOTTOM）
	# 先画分割线、再画外框：外框永远压在上面，两侧接缝表现一致
	_frame_divider(card, k, glint_mat)
	if not OS.has_environment("QI_NO_RING"):
		_frame_ring(card, k, glint_mat)
	# —— 顶部带：左＝气费圆 · 中＝名字 · 右＝获得的式（空则不显）——
	var name_x0: float = 60.0
	var name_x1: float = 240.0 if gain_text != "" else 244.0
	if has_qi:
		var cost_c := Panel.new()
		cost_c.name = "CostPip"   # 不可打红描边走同名查找（战斗屏 _refresh_playability）
		_place_abs(cost_c, 12.0 * k, (FRAME_INSET + FRAME_W + BAND_BOTTOM - QI_R * 2.0) * 0.5 * k,
			(12.0 + QI_R * 2.0) * k, (FRAME_INSET + FRAME_W + BAND_BOTTOM + QI_R * 2.0) * 0.5 * k)
		cost_c.add_theme_stylebox_override("panel", _vc_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
		cost_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cost_c)
		# 气费统一用 HUD 的气珠图（2026-11-04 用户令）
		var qi_tex: Texture2D = _hud_tex("c_qi")
		if qi_tex != null:
			var qi_img := TextureRect.new()
			qi_img.name = "QiIcon"
			qi_img.texture = qi_tex
			qi_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			qi_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			qi_img.position = Vector2(-QI_R * 0.35 * k, -QI_R * 0.35 * k)
			qi_img.size = Vector2(QI_R * 2.7 * k, QI_R * 2.7 * k)
			qi_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_c.add_child(qi_img)
		# 2026-11-06 用户裁定（对齐原作）：可打＝墨蓝、不可打＝灰（战斗屏另描红边）、
		# 可打且有连击加成＝金
		var cost_col: Color = TCG_INK
		if bool(def.get("combo_gold", false)):
			cost_col = Color(0.80, 0.58, 0.14)
		var q_lbl: Label = _vc_label(cost_c, str(qi_v), _fs(19, k), cost_col, 0)
		q_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	else:
		var plate := Panel.new()
		_place_abs(plate, 13.0 * k, 12.0 * k, 218.0 * k, 50.0 * k)
		plate.add_theme_stylebox_override("panel", _vc_box(TCG_PARCH_DARK, TCG_GOLD,
			maxi(2, roundi(3.0 * k)), roundi(5.0 * k)))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(plate)
		var costs_v: Variant = def.get("cost", [])
		var costs: Array = costs_v if costs_v is Array else [costs_v]
		var n := costs.size()
		for i in n:
			var d: float = 23.0 * k
			var gap: float = 3.0 * k
			var x: float = 291.0 * k - d - float(n - 1 - i) * (d + gap)
			var pip := Panel.new()
			_place_abs(pip, x, 14.0 * k, x + d, 14.0 * k + d)
			pip.add_theme_stylebox_override("panel", _vc_box(TCG_PARCH, TCG_GOLD_DARK,
				maxi(1, roundi(2.0 * k)), roundi(d * 0.5)))
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(pip)
			var pl: Label = _vc_label(pip, str(costs[i]), _fs(13, k), TCG_INK, 0)
			pl.set_anchors_preset(Control.PRESET_FULL_RECT)
			pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_x0 = 22.0
		name_x1 = 210.0
	# 2026-11-05 用户令：标题 28＋2px 黑描边；区间改与顶带同区（4k~52k）真·带心垂直居中——
	# 原 14~50 区间中心偏带心 4px，且 28 号行高会顶出旧区间致居中失效
	var name_lbl: Label = _vc_label(card, str(def.get("name", "")), _fs(28, k), COLOR_CREAM, 2)
	_place_abs(name_lbl, name_x0 * k, (FRAME_INSET + FRAME_W) * k, name_x1 * k, BAND_BOTTOM * k)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(name_lbl, _fs(28, k), true)
	if gain_text != "":
		var gchip := Panel.new()
		_place_abs(gchip, 244.0 * k, 16.0 * k, 289.0 * k, 48.0 * k)
		gchip.add_theme_stylebox_override("panel", _vc_box(TCG_PARCH_DARK, TCG_GOLD_DARK,
			maxi(1, roundi(2.0 * k)), roundi(4.0 * k)))
		gchip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(gchip)
		var gl: Label = _vc_label(gchip, gain_text, _fs(13, k), TCG_INK, 0)
		gl.set_anchors_preset(Control.PRESET_FULL_RECT)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(gl, _fs(13, k), true)
	# —— 效果区：满宽蒙层，高度按文长自适应（不留空底）——
	var rules_str: String = str(def.get("rules", ""))
	var fs_rules: int = _fs(16, k)
	var inner_w: float = (282.0 - 18.0 - 16.0) * k
	var per_line: int = maxi(6, int(inner_w / (float(fs_rules) * 1.1)))
	var text_lines: int = 0
	for seg in rules_str.split("\n"):
		text_lines += maxi(1, int(ceil(float(seg.length()) / float(per_line))))
	var box_h: float = clampf(float(text_lines) * float(fs_rules) * 1.5 + 52.0 * k,
		132.0 * k, 186.0 * k)
	var box_top: float = 404.0 * k - box_h
	var box := Panel.new()
	_place_abs(box, round(18.0 * k), round(box_top), round(282.0 * k), round(404.0 * k))
	# 卡型＝当前型：效果区边框转亮金（与型符号方块同一种金）——2026-11-08 用户令
	var st_now := String(def.get("stance", ""))
	# 变招天生活合（不锁型）——2026-11-08 用户令：变招一律算匹配
	var st_matched := st_now != "" and (st_now == "flex" or st_now == String(def.get("cur_form", "")))
	var eff_box: StyleBoxFlat = _vc_box(Color(TCG_PARCH.r, TCG_PARCH.g, TCG_PARCH.b, 0.74),
		(Color(1.0, 0.86, 0.46) if st_matched else TCG_GOLD_DARK),
		maxi(1, roundi(1.0 * k)), roundi(4.0 * k))
	eff_box.shadow_color = Color(0, 0, 0, 0.45)
	# （2026-11-08 撤）box/badge 挂 glint 材质后悬停与浮窗异常，先去掉

	eff_box.shadow_size = maxi(2, roundi(6.0 * k))
	box.add_theme_stylebox_override("panel", eff_box)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	card.add_child(box)
	var flavor_text: String = str(def.get("flavor", ""))
	var rules: Label = _vc_label(box, rules_str, fs_rules, TCG_INK, 0)
	rules.set_anchors_preset(Control.PRESET_FULL_RECT)
	rules.offset_left = 9.0 * k
	rules.offset_top = 6.0 * k
	rules.offset_right = -9.0 * k
	rules.offset_bottom = (-26.0 if flavor_text != "" else -24.0) * k
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(rules, fs_rules)
	if flavor_text != "":
		var fl: Label = _vc_label(box, flavor_text, _fs(11, k), TCG_INK_SOFT, 0)
		fl.anchor_top = 1.0
		fl.anchor_bottom = 1.0
		fl.anchor_left = 0.0
		fl.anchor_right = 1.0
		fl.offset_left = 9.0 * k
		fl.offset_top = -42.0 * k
		fl.offset_right = -9.0 * k
		fl.offset_bottom = -21.0 * k
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_wire_fit(fl, _fs(11, k))
	# 种类小字：效果区底缘一行（淡色），不另占一条空带
	var kind_foot: Label = _vc_label(box, str(def.get("type_line", "")), _fs(10, k),
		Color(TCG_INK_SOFT.r, TCG_INK_SOFT.g, TCG_INK_SOFT.b, 0.85), 0)
	kind_foot.anchor_top = 1.0
	kind_foot.anchor_bottom = 1.0
	kind_foot.anchor_left = 0.0
	kind_foot.anchor_right = 1.0
	kind_foot.offset_left = 9.0 * k
	kind_foot.offset_top = -22.0 * k
	kind_foot.offset_right = -9.0 * k
	kind_foot.offset_bottom = -2.0 * k
	kind_foot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	kind_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_wire_fit(kind_foot, _fs(9, k), true)
	# —— 式列：效果区上方，自下而上（2026-11-04 用户令：槽＝图同尺寸 39）——
	# 2026-11-05 用户令（终版）：槽＝卡固定的 need（无需要＝空轨，直刺类左轨一个不画）；
	# 每枚样式动态——玩家持有够这一枚＝实心块，需要但没持有＝虚线框＋对角线
	# （样式＝_stance_shape_tex 原设定件，勿再换）。own_stances 由战斗屏建卡时注入，
	# 手牌全量重建时取最新持有＝实时连锁。
	# 四型符号：原「式列」左轨格位，方块底＋金边＋图标；卡型＝当前型时整体转金
	var st_kind := String(def.get("stance", ""))
	if st_kind != "":
		var matched := st_matched
		var badge := Panel.new()
		var sbf := StyleBoxFlat.new()
		# 底色＝卡面标题带同色（2026-11-08 用户令：攻击蓝卡就是墨蓝底）
		var tone_k := String(def.get("tone", "red"))
		sbf.bg_color = TCG_HEADERS.get(tone_k, TCG_HEADERS["red"])   # 底始终＝标题带色，匹配也不变
		sbf.border_color = TCG_GOLD_DARK if not matched else Color(1.0, 0.87, 0.55)   # 匹配时亮金
		sbf.set_border_width_all(maxi(1, roundi(1.0 * k)))   # 与效果区同粗细
		sbf.set_corner_radius_all(roundi(4.0 * k))            # 与效果区同圆角
		sbf.anti_aliasing = true   # 去锯齿
		badge.add_theme_stylebox_override("panel", sbf)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.size = Vector2(39.0 * k, 39.0 * k)
		badge.position = Vector2(18.0 * k, (box_top - 4.0 * k) - 39.0 * k)   # 与效果区左边框对齐
		card.add_child(badge)
		var pth := "res://qiforge/assets/ui/type_%s%s.png" % [st_kind, "_gold" if matched else "_light"]
		var stex: Texture2D = ResourceLoader.load(pth)
		if stex != null:
			var sic := TextureRect.new()
			sic.texture = stex
			sic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			sic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sic.set_anchors_preset(Control.PRESET_FULL_RECT)
			sic.stretch_mode = TextureRect.STRETCH_SCALE
			sic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # 缩放采样用线性，去锯齿
			sic.offset_left = 3.0 * k
			sic.offset_top = 3.0 * k
			sic.offset_right = -3.0 * k
			sic.offset_bottom = -3.0 * k
			badge.add_child(sic)
	var rail_w: float = 39.0
	var rail_bottom: float = box_top - 6.0 * k
	var rail_px: float = rail_w * k
	var y_cursor: float = box_top - 4.0 * k
	var rail_top_min: float = (BAND_BOTTOM + 6.0) * k   # 不越过顶条/分割线
	var own: Dictionary = def.get("own_stances", {})
	var seen: Dictionary = {}
	for st in need:
		var s := str(st)
		seen[s] = int(seen.get(s, 0)) + 1
		var lit: bool = int(own.get(s, 0)) >= int(seen[s])
		if y_cursor - rail_px < rail_top_min:
			break
		var b: Panel = _stance_badge(s, k, false, lit, 1)
		b.size = Vector2(rail_px, rail_px)
		b.position = Vector2(22.0 * k, y_cursor - rail_px)
		card.add_child(b)
		y_cursor -= rail_px + 3.0 * k
	for i in gain_icons.size():
		var gy: float = rail_bottom - (rail_w + 35.0 * float(i)) * k
		if gy < (BAND_BOTTOM + 8.0) * k:
			break
		var b2: Panel = _stance_badge(str(gain_icons[i]), k, true, true, 1)
		b2.size = Vector2(rail_w * k, rail_w * k)
		b2.position = Vector2((284.0 - 6.0 - rail_w) * k, gy)
		card.add_child(b2)
	# 2026-11-06 碎牌：裂痕态——卡面叠程序裂纹（正式裂纹贴图归美术，此为留位）
	if cracked:
		var cr := TextureRect.new()
		cr.texture = _crack_texture(clampi(int(def.get("crack_level", 3)), 1, 3))
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cr.stretch_mode = TextureRect.STRETCH_SCALE
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.z_index = 8
		card.add_child(cr)
	return card

## 裂纹贴图（2026-11-06 表现层接手：真贴图两档，按卡名哈希取——1=轻 2=重）
static var _crack_cache := {}
static func _crack_texture(variant: int) -> Texture2D:
	var v: int = clampi(variant, 1, 3)
	if _crack_cache.has(v):
		return _crack_cache[v]
	var p := "res://qiforge/assets/hud/crack_%d.png" % v
	var img := Image.load_from_file(ProjectSettings.globalize_path(p))
	var t: Texture2D = null
	if img != null and not img.is_empty():
		t = ImageTexture.create_from_image(img)
	_crack_cache[v] = t
	return t

## 金件①外框：四边等宽金环（后续加角标/攻防角也按 FRAME_* 这套参数排）
static func _frame_ring(card: Control, k: float, glint: ShaderMaterial = null) -> void:
	var goldband := Panel.new()
	_place_abs(goldband, round(FRAME_INSET * k), round(FRAME_INSET * k),
		round((300.0 - FRAME_INSET) * k), round((422.0 - FRAME_INSET) * k))
	var ring_b: int = maxi(2, roundi(FRAME_W * k)) + 1   # +1px：内侧多压 1px，盖住卡底与金框之间的缝
	var ring_r: int = maxi(2, roundi(12.0 * k))
	goldband.add_theme_stylebox_override("panel", _vc_box(Color(0, 0, 0, 0), TCG_GOLD,
		ring_b, ring_r))
	goldband.material = glint
	goldband.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(goldband)

## 金件②分割线：直段＋两端圆角缺口（上收顶条下角／下收立绘上角），宽度贴外框内侧
static func _frame_divider(card: Control, k: float, glint: ShaderMaterial = null) -> void:
	# 2026-11-08 用户令：与外框**同一种画法**（都走 StyleBoxFlat 纯色填充），
	# 这样颜色/抗锯齿/发光完全一致；两端做成胶囊圆头，接在外框内侧。
	# 两端做方头（不做胶囊圆头）：圆头会在与外框相接处收成尖，看起来"细/有空隙"
	var w_px: float = round((300.0 - 2.0 * (FRAME_INSET + FRAME_W)) * k) + 6.0
	var bar_h: float = maxf(1.0, round(DIVIDER_H * k))
	var junc := Panel.new()
	var jsb := StyleBoxFlat.new()
	jsb.bg_color = TCG_GOLD
	jsb.anti_aliasing = true
	jsb.set_corner_radius_all(0)
	junc.add_theme_stylebox_override("panel", jsb)
	# 左右各向金框内伸 1px，让接缝重叠，消灭抗锯齿造成的"缝"
	# 两端各往金框里多伸 3px（画在金框上，同色不可见），确保接缝无空隙
	junc.position = Vector2(round((FRAME_INSET + FRAME_W) * k) - 3.0, round(BAND_BOTTOM * k) - bar_h * 0.5)
	junc.size = Vector2(w_px, bar_h)
	junc.material = glint
	junc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(junc)

## 光晕贴图：径向渐变（中心白、边缘透明），给气珠当光效
static func _glow_texture() -> ImageTexture:
	var n: int = 64
	var img: Image = Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx: float = (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.9
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

## 式图标形状（26×26 坐标）：三式都是剑，用「剑的朝向＋剑身宽窄」区分
## 劈＝重剑由左下斜劈向右上；刺＝长剑自左向右直刺；撩＝轻剑上撩带一道剑风弧
static func _stance_polys(stance: String) -> Array:
	match stance:
		"刺":
			return _sword_shape(Vector2(7.0, 13.0), Vector2(23.0, 13.0), 2.6, 5.0, 3.2, true)
		"撩":
			var out: Array = _sword_shape(Vector2(9.0, 18.0), Vector2(21.0, 5.0), 1.4, 3.6, 3.2, false)
			var wake := PackedVector2Array()
			var inner := PackedVector2Array()
			for i in 12:
				var t: float = float(i) / 11.0
				var x: float = 3.0 + t * 12.0
				var y: float = 21.5 - t * 7.0 - sin(t * PI) * 2.0
				wake.append(Vector2(x, y))
				inner.append(Vector2(x, y + 2.2))
			for i in range(11, -1, -1):
				wake.append(inner[i])
			out.append(wake)
			return out
		_:
			return _sword_shape(Vector2(8.0, 19.0), Vector2(20.0, 7.0), 4.2, 5.4, 3.4, false)  # 重剑：宽身、平头无锋

## 剑件：刃（base→tip，可带尖）＋护手（垂直于刃）＋柄；half_w 控制宽窄（重剑 vs 轻剑）
static func _sword_shape(base: Vector2, tip: Vector2, half_w: float, guard_len: float,
		grip_len: float, point: bool) -> Array:
	var d: Vector2 = (tip - base).normalized()
	var p: Vector2 = Vector2(-d.y, d.x)
	var bw: Vector2 = p * half_w
	var tw: Vector2 = p * half_w * (0.18 if point else 0.75)
	var blade: PackedVector2Array
	if point:
		blade = PackedVector2Array([base + bw, tip + tw, tip - tw, base - bw])
	else:
		blade = PackedVector2Array([base + bw, tip + tw, tip - tw, base - bw])
	var g: Vector2 = p * guard_len
	var gd: Vector2 = d * (half_w * 0.65)
	var guard := PackedVector2Array([base + g + gd, base + g - gd, base - g - gd, base - g + gd])
	var gb: Vector2 = base - d * grip_len
	var gw: Vector2 = p * (half_w * 0.55)
	var grip := PackedVector2Array([base + gw, gb + gw, gb - gw, base - gw])
	return [blade, guard, grip]

## 交界金带贴图（像素空间 1:1 生成，不经缩放）：上两角填＋直段＋下两角填
static func _junction_texture(w: int, bar_h: int, r: int) -> ImageTexture:
	var h: int = r * 2 + bar_h
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u: float = float(x) + 0.5
			var v: float = float(y) + 0.5
			var on: bool = v >= float(r) and v <= float(r + bar_h)
			if not on and v < float(r):
				var dl: float = (u - float(r)) * (u - float(r)) + v * v
				var dr: float = (u - float(w - r)) * (u - float(w - r)) + v * v
				if (u < float(r) and dl > float(r * r)) or (u > float(w - r) and dr > float(r * r)):
					on = true
			if not on and v > float(r + bar_h):
				var bl: float = (u - float(r)) * (u - float(r)) + (v - float(h)) * (v - float(h))
				var br: float = (u - float(w - r)) * (u - float(w - r)) + (v - float(h)) * (v - float(h))
				if (u < float(r) and bl > float(r * r)) or (u > float(w - r) and br > float(r * r)):
					on = true
			img.set_pixel(x, y, TCG_GOLD if on else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

## 式图标（2026-11-05 用户令）：需要＝正方形、可获得＝菱形、已拥有＝朱砂实底、三式三色
static var _stance_shape_cache: Dictionary = {}

static func _stance_shape_tex(shape: String, col: Color, lit: bool) -> Texture2D:
	var key := "%s_%s_%s" % [shape, col.to_html(), lit]
	if _stance_shape_cache.has(key):
		return _stance_shape_cache[key]
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	# 有＝实底＋亮边；没有＝同色描边（0.55 透明）——保留式种辨识，不填色
	var edge := col.lightened(0.25) if lit else Color(col.r, col.g, col.b, 0.55)
	var fill := col if lit else Color(0, 0, 0, 0)
	var c := 31.5
	var r := 27.0
	var bw := 4.0
	for y in n:
		for x in n:
			var dx: float = float(x) - c
			var dy: float = float(y) - c
			var inside := false
			var dist_edge := 0.0
			if shape == "diamond":
				var m: float = absf(dx) + absf(dy)
				inside = m <= r
				dist_edge = r - m
			else:
				var m2: float = maxf(absf(dx), absf(dy))
				inside = m2 <= r
				dist_edge = r - m2
			if not inside:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dist_edge <= bw:
				# 2026-11-05 用户令：没有的式用虚线边（同一圈按角度切段），有的＝实心
				img.set_pixel(x, y, edge)
			else:
				if lit:
					img.set_pixel(x, y, fill)
				else:
					# 没有的式：实线框＋内部斜向虚线填充
					var d1: float = dx + dy
					var d2: float = dx - dy
					var on_line: bool = fmod(absf(d1), 7.0) < 1.4
					var on_dash: bool = fmod(absf(d2), 7.0) < 3.6
					var diag: bool = absf(dx - dy) < 1.8   # 单条实线对角线（↘）
					if diag:
						img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.85))
					elif on_line and on_dash:
						img.set_pixel(x, y, Color(col.r, col.g, col.b, 0.55))
					else:
						img.set_pixel(x, y, Color(0, 0, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	_stance_shape_cache[key] = tex
	return tex

static func _stance_badge(stance: String, k: float, is_gain := false, lit := true,
		layers := 1) -> Panel:
	# 2026-11-05 用户纠正：卡内式徽章＝另一 AI 定死的贴图制（_stance_shape_tex）——
	# 没有的式＝实线框＋斜向虚线填充＋↘对角线，有的式＝实心色块。勿再换件。
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", _vc_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = STANCE_COLORS.get(stance, Color("d9564a"))
	var tex := _stance_shape_tex("diamond" if is_gain else "square", col, lit)
	if tex == null:
		return badge
	var side: float = 39.0 * k
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(side, side)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(tr)
	return badge

## 剑件：刃（base→tip，可带尖）＋护手（垂直于刃）＋柄；half_w 控制宽窄（重剑 vs 轻剑）
## 画框占位：程序水墨——天色渐变＋月＋三层山影（96×96 生成图；接真图时走 art 纹理）
static func _tcg_art_texture(frame: Color) -> ImageTexture:
	var w: int = 96
	var h: int = 96
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var sky_top: Color = frame.lightened(0.22)
	var sky_bot: Color = frame.lightened(0.62)
	for y in h:
		var t: float = float(y) / float(h - 1)
		var c: Color = sky_top.lerp(sky_bot, pow(t, 1.6))
		for x in w:
			img.set_pixel(x, y, c)
	var mx: int = 66
	var my: int = 28
	var mr: int = 8
	for y in range(my - mr, my + mr + 1):
		for x in range(mx - mr, mx + mr + 1):
			if (x - mx) * (x - mx) + (y - my) * (y - my) <= mr * mr:
				img.set_pixel(x, y, Color(0.96, 0.94, 0.86))
	var layers: Array = [
		[46.0, 9.0, frame.darkened(0.12), 1.2],
		[58.0, 11.0, frame.darkened(0.32), 2.4],
		[72.0, 7.0, frame.darkened(0.5), 0.6],
	]
	for L in layers:
		for x in w:
			var fx: float = float(x) / float(w - 1)
			var hgt: float = float(L[0]) + sin(fx * 6.0 + float(L[3])) * float(L[1]) 				+ sin(fx * 15.0 + float(L[3]) * 2.0) * float(L[1]) * 0.32
			for y in range(int(hgt), h):
				img.set_pixel(x, y, L[2])
	return ImageTexture.create_from_image(img)
#endregion
#endregion

## 升级预览卡：升级后面貌＋diff 标记（效果区逐行「＋/－/改/·」；名字/费用变化转琥珀）
static func make_spell_preview_card(up_spell: Dictionary, diff: Dictionary,
		ctx: String = "field") -> Button:
	var preview: Dictionary = {
		"lines": diff.get("lines", []),
		"name_changed": diff.get("name_changed", false),
		"cost_changed": diff.get("cost_changed", false),
	}
	return make_spell_card(str(up_spell.get("name", "")), int(up_spell.get("cost", 0)),
		str(up_spell.get("desc", "")), int(up_spell.get("power", 0)),
		str(up_spell.get("spec", "")), ctx, preview)
#endregion

#region 详情卡（基准布局 ×0.9；立绘压成短条给全文让位）
## 器灵详情卡（v3.2 现役；无 Lv 徽）
static func make_spirit_detail_card(spirit: Dictionary, up1: String = "",
		up2: String = "", ctx: String = "detail") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPIRIT_COLOR, k)
	_add_art_zone(card, k, true, portrait_of(str(spirit.get("name", ""))))
	_add_band(card, k, str(spirit.get("name", "")), true)
	_add_detail_panel(card, k, str(spirit.get("desc", "")), 0, "", up1, up2)
	return card

## 旧线兼容别名（随 Root 线终裁一并删）
static func make_xinfa_detail_card(xinfa: Dictionary, level: int, up1: String = "",
		up2: String = "", ctx: String = "detail") -> Button:
	var identity: String = identity_of(str(xinfa.get("id", "")))
	var k: float = scale_of(ctx)
	var card: Button = _new_card(IDENTITY_COLORS.get(identity, Color(0.42, 0.42, 0.48)), k)
	_add_lv_pill(card, k, level)
	_add_art_zone(card, k, true)
	_add_band(card, k, str(xinfa.get("name", "")), true)
	_add_detail_panel(card, k, str(xinfa.get("desc", "")), 0, "", up1, up2)
	return card

## 功法详情卡
static func make_spell_detail_card(spell_name: String, cost: int, desc: String,
		up1: String = "", up2: String = "", power: int = 0, spec: String = "",
		ctx: String = "detail") -> Button:
	var k: float = scale_of(ctx)
	var card: Button = _new_card(SPELL_COLOR, k)
	_add_cost_pip(card, k, cost)
	_add_art_zone(card, k, true)
	_add_band(card, k, spell_name, false)
	_add_detail_panel(card, k, desc, power, spec, up1, up2)
	return card
#endregion

#region 遴选轮播件：竖版迷你卡（等比缩小，无字纯色）＋选入描边圈
static func make_face_mini(mini_color: Color, tip: String) -> Button:
	var mini: Button = Button.new()
	mini.custom_minimum_size = size_of("mini")
	mini.tooltip_text = tip
	var dim: Color = mini_color.darkened(0.55)
	var normal: StyleBoxFlat = _mini_style(dim, 0)
	var hover: StyleBoxFlat = _mini_style(mini_color.darkened(0.2), 0)
	var active: StyleBoxFlat = _mini_style(mini_color, 3)
	mini.add_theme_stylebox_override("normal", normal)
	mini.add_theme_stylebox_override("hover", hover)
	mini.add_theme_stylebox_override("pressed", hover)
	mini.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mini.set_meta("style_active", active)
	mini.set_meta("style_normal", normal)
	return mini

static func set_face_mini_active(mini: Button, active: bool) -> void:
	mini.add_theme_stylebox_override("normal",
		mini.get_meta("style_active" if active else "style_normal") as StyleBoxFlat)

## 选入描边圈：垫在卡面之下（卡位外扩 6px），选中时显示
static func make_pick_ring() -> Panel:
	var ring: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(4)
	style.border_color = TCG_GOLD
	style.set_corner_radius_all(14)
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	return ring
#endregion

#region 详情层公共件（遴选窗/装备窗共用）
## 「详情」按钮全场统一制服：藏青底奶油字，永远可按（选中态由各窗自行表达，按钮只管放大）
static func make_detail_button() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(180, 36)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", COLOR_CREAM)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = COLOR_NAVY
	normal.border_color = COLOR_CREAM
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.text = "详情"
	return button

## 详情层：压满弹窗＋0.45 黑罩＋内容居中（锚点 0.5＋显式偏移——弹窗内部容器重整也压不跑，
## 且不走 PRESET_CENTER 的 MINSIZE 语义，那个会按瞬时最小尺寸算出 ±4 崩坏偏移）。
## card_size 缺省（零向量）＝详情档尺寸；组合行传自身 combined min size。
## 点遮罩即关；点卡关闭由调用方连接；返回层节点由调用方持有、queue_free 关闭。
static func make_detail_layer(detail_card: Control, card_size: Vector2 = Vector2.ZERO) -> Control:
	var real_size: Vector2 = card_size if card_size.x > 0.0 else size_of("detail")
	var layer: Control = Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim: ColorRect = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			layer.queue_free())
	layer.add_child(scrim)
	detail_card.size = real_size
	detail_card.anchor_left = 0.5
	detail_card.anchor_right = 0.5
	detail_card.anchor_top = 0.5
	detail_card.anchor_bottom = 0.5
	var half: Vector2 = real_size * 0.5
	detail_card.offset_left = -half.x
	detail_card.offset_right = half.x
	detail_card.offset_top = -half.y
	detail_card.offset_bottom = half.y
	layer.add_child(detail_card)
	return layer

#region 空装备位（与实卡同尺寸的灰格，可点）
static func make_empty_slot_button(ctx: String = "field") -> Button:
	var k: float = scale_of(ctx)
	var slot: Button = Button.new()
	slot.custom_minimum_size = size_of(ctx)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.80, 0.77, 0.70)
	style.set_corner_radius_all(maxi(4, roundi(17.0 * k)))
	style.set_border_width_all(maxi(2, roundi(3.0 * k)))
	style.border_color = Color(0.68, 0.64, 0.56)
	slot.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = TCG_GOLD
	slot.add_theme_stylebox_override("hover", hover)
	slot.add_theme_stylebox_override("pressed", hover)
	var empty_label: Label = _text(slot, "空", _fs(23, k), Color(0.62, 0.59, 0.53))
	empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return slot
#endregion

#region 基准卡装配（坐标按 300×422 标定，k＝场合系数）
static func _new_card(body_color: Color, k: float) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(round(BASE_SIZE.x * k), round(BASE_SIZE.y * k))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# 卡体不再画自己的描边（2026-11-08）：外圈那 1px 米白就是它，金框已负责边框
	var normal: StyleBoxFlat = _card_style(body_color, maxi(4, roundi(17.0 * k)), 0)
	var hover: StyleBoxFlat = _card_style(body_color, normal.corner_radius_top_left, normal.border_width_left)
	hover.border_color = TCG_GOLD
	var pressed: StyleBoxFlat = hover.duplicate()
	card.add_theme_stylebox_override("normal", normal)
	card.add_theme_stylebox_override("hover", hover)
	card.add_theme_stylebox_override("pressed", pressed)

	# 调试
	if OS.has_environment("QI_DUMP_CARD"):
		var all := card.find_children("*", "", true, false)
		print("CARDDUMP n=", all.size())
		for ch2 in all:
			if ch2 is Control:
				var c3 := ch2 as Control
				var line := "CARDDUMP %s|%s|%s|%s" % [c3.name, c3.get_class(), str(c3.position.round()), str(c3.size.round())]
				if c3 is Panel:
					var sb3 = (c3 as Panel).get_theme_stylebox("panel")
					if sb3 is StyleBoxFlat:
						line += "|bg=%s|bd=%s|bw=%d" % [(sb3 as StyleBoxFlat).bg_color.to_html(), (sb3 as StyleBoxFlat).border_color.to_html(), (sb3 as StyleBoxFlat).border_width_top]
				print(line)
	return card

## 左上能量点（v3.1 用户裁定：费用徽居左上；升级预览费用变化时描边转琥珀）
static func _add_cost_pip(card: Control, k: float, cost: Variant, changed: bool = false) -> void:
	var pip: Panel = Panel.new()
	pip.name = "CostPip"
	# 半搭卡左上角（2026-10-28 用户裁定对齐攻次宝珠同族位；原全内置 13/7 偏内）
	_place_abs(pip, -14.0 * k, -14.0 * k, 60.0 * k, 60.0 * k)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_NAVY
	style.set_corner_radius_all(roundi(30.0 * k))
	style.set_border_width_all(maxi(2, roundi(5.0 * k)))
	style.border_color = TCG_GOLD if changed else COLOR_CREAM
	pip.add_theme_stylebox_override("panel", style)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pip_fs := _fs(27, k)
	if str(cost).length() > 1:
		pip_fs = _fs(20, k)   # 「劈×2」等多字符费用点缩号
	_center_text(pip, str(cost), pip_fs, COLOR_CREAM)
	card.add_child(pip)

## 右上 Lv 琥珀角标（仅旧线心法别名在用；现役器灵卡无等级概念）
static func _add_lv_pill(card: Control, k: float, level: int) -> void:
	var pill: Panel = Panel.new()
	pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -107.0 * k
	pill.offset_top = 13.0 * k
	pill.offset_right = -12.0 * k
	pill.offset_bottom = 66.0 * k
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_AMBER
	style.set_corner_radius_all(maxi(4, roundi(22.0 * k)))
	style.set_border_width_all(maxi(1, roundi(3.0 * k)))
	style.border_color = TCG_GOLD_DARK
	pill.add_theme_stylebox_override("panel", style)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(pill, "Lv{0}".format([level]), _fs(22, k), COLOR_AMBER_TEXT)
	card.add_child(pill)

## 立绘区（无立绘＝压暗占位；strip=true 详情短条；portrait 非空时铺图 COVERED 裁切）
static func _add_art_zone(card: Control, k: float, strip: bool = false,
		portrait: Texture2D = null) -> void:
	var art: Panel = Panel.new()
	if strip:
		_place(art, 15.0 * k, 73.0 * k, -15.0 * k, -292.0 * k)
	else:
		_place(art, 15.0 * k, 73.0 * k, -15.0 * k, -235.0 * k)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.15)
	style.set_corner_radius_all(maxi(3, roundi(11.0 * k)))
	art.add_theme_stylebox_override("panel", style)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if portrait != null:
		var pic: TextureRect = TextureRect.new()
		pic.texture = portrait
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(pic)

	card.add_child(art)

## 名字带：is_xinfa=true 菱头横带；false 长方形匾额；升级换名时文字转琥珀
static func _add_band(card: Control, k: float, name_text: String, is_xinfa: bool,
		name_changed: bool = false) -> void:
	var band: Control
	if is_xinfa:
		var diamond: DiamondBand = DiamondBand.new()
		diamond.tip = 13.0 * k
		band = diamond
	else:
		var rect_band: Panel = Panel.new()
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.24)
		style.set_corner_radius_all(maxi(2, roundi(7.0 * k)))
		rect_band.add_theme_stylebox_override("panel", style)
		band = rect_band
	_place(band, 33.0 * k, 196.0 * k, -33.0 * k, -182.0 * k)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(band, name_text, _fs(25, k), COLOR_AMBER if name_changed else COLOR_CREAM)
	_wire_fit(band.get_child(0) as Label, _fs(25, k), true)
	card.add_child(band)

## 效果区：基础效果（威力徽在前）＋可选特殊效果块；diff 行非空时逐行标记渲染
static func _add_effect_panel(card: Control, k: float, desc: String, power: int,
		spec: String, diff_lines: Array = []) -> void:
	var panel: Panel = Panel.new()
	_place(panel, 15.0 * k, 249.0 * k, -15.0 * k, -17.0 * k)
	_eff_style(panel, k)
	card.add_child(panel)

	var box: VBoxContainer = _panel_box(panel, k)

	if power > 0:
		var power_row: HBoxContainer = _row_container(HBoxContainer.new())
		power_row.add_child(_make_chip(k, "威力 {0}".format([power]), 83.0,
			COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
		box.add_child(power_row)

	if not diff_lines.is_empty():
		for line: Dictionary in diff_lines:
			var cls: String = str(line.get("cls", "same"))
			var mark: String = {"add": "＋ ", "del": "－ ", "mod": "改 "}.get(cls, "· ")
			var color: Color = {"add": COLOR_DIFF_ADD, "del": COLOR_DIFF_DEL,
				"mod": COLOR_DIFF_MOD}.get(cls, COLOR_INK_TEXT)
			var line_label: Label = _text(box, mark + str(line.get("t", "")),
				_fs(_effect_font_base("field"), k), color)
			line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_wire_fit(line_label, _fs(_effect_font_base("field"), k))
	else:
		var desc_label: Label = _text(box, desc, _fs(20, k), COLOR_INK_TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(desc_label, _fs(20, k))

	if spec != "":
		var line: ColorRect = ColorRect.new()
		line.color = Color(0.847, 0.816, 0.751)
		line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(line)
		var spec_row: HBoxContainer = _row_container(HBoxContainer.new())
		spec_row.add_child(_make_chip(k, "特殊", 60.0,
			Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
		var spec_label: Label = _text(spec_row, spec, _fs(20, k), COLOR_INK_TEXT)
		spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(spec_label, _fs(20, k))
		box.add_child(spec_row)
#endregion

#region 详情面板（基准布局；升一/升二全文行）
static func _add_detail_panel(card: Control, k: float, desc: String, power: int,
		spec: String, up1: String, up2: String) -> void:
	var panel: Panel = Panel.new()
	_place(panel, 15.0 * k, 249.0 * k, -15.0 * k, -17.0 * k)
	_eff_style(panel, k)
	card.add_child(panel)

	var box: VBoxContainer = _panel_box(panel, k, 8.0)
	var text_base: int = _fs(_effect_font_base("detail"), k)

	if power > 0:
		var power_row: HBoxContainer = _row_container(HBoxContainer.new())
		power_row.add_child(_make_chip(k, "威力 {0}".format([power]), 83.0,
			COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
		box.add_child(power_row)

	var desc_label: Label = _text(box, desc, text_base, COLOR_INK_TEXT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(desc_label, text_base)

	if spec != "":
		var spec_line: ColorRect = ColorRect.new()
		spec_line.color = Color(0.847, 0.816, 0.751)
		spec_line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(spec_line)
		var spec_row: HBoxContainer = _row_container(HBoxContainer.new())
		spec_row.add_child(_make_chip(k, "特殊", 60.0,
			Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
		var spec_label: Label = _text(spec_row, spec, text_base, COLOR_INK_TEXT)
		spec_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		spec_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spec_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wire_fit(spec_label, text_base)
		box.add_child(spec_row)

	if up1 != "" or up2 != "":
		var up_line: ColorRect = ColorRect.new()
		up_line.color = Color(0.847, 0.816, 0.751)
		up_line.custom_minimum_size = Vector2(0, maxi(1.0, roundi(2.5 * k)))
		box.add_child(up_line)
		if up1 != "":
			var row1: HBoxContainer = _row_container(HBoxContainer.new())
			row1.add_child(_make_chip(k, "升一", 60.0, COLOR_AMBER, COLOR_AMBER_DARK, COLOR_AMBER_TEXT))
			_up_text(row1, up1, text_base)
			box.add_child(row1)
		if up2 != "":
			var row2: HBoxContainer = _row_container(HBoxContainer.new())
			row2.add_child(_make_chip(k, "升二", 60.0,
				Color(0.867, 0.902, 0.953), SPELL_COLOR, Color(0.153, 0.29, 0.5)))
			_up_text(row2, up2, text_base)
			box.add_child(row2)

static func _up_text(row: HBoxContainer, text: String, size: int) -> void:
	var label: Label = _text(row, text, size, COLOR_INK_TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_wire_fit(label, size)
#endregion

#region 内部工具
## 详情档正文用较小基号（×0.9 后 ≈13px，避免误入 ≥18 展示字通道）
static func _effect_font_base(ctx: String) -> int:
	return 14 if ctx == "detail" else 20

## 字号按场合系数缩放（下限 9——迷你档无字，保险闸）
static func _fs(base: int, k: float) -> int:
	return maxi(9, roundi(float(base) * k))

static func _panel_box(panel: Panel, k: float, pad: float = 10.0) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12.0 * k
	box.offset_top = pad * k
	box.offset_right = -12.0 * k
	box.offset_bottom = -pad * k
	box.add_theme_constant_override("separation", maxi(3, roundi(7.0 * k)))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	return box

## 内缩矩形：四边锚点（0,0,1,1）后给偏移，负值＝从右/下边内缩
static func _place(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

## 绝对矩形：锚点全 0，偏移即距父左上的像素
static func _place_abs(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 0.0
	node.anchor_bottom = 0.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

static func _card_style(body_color: Color, radius: int, border_px: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = body_color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(border_px)
	# 卡体自带描边用金色（原为米白：金色框压在上面时，米白边从外沿露出来→顶部泛白）
	style.border_color = TCG_GOLD
	return style

static func _mini_style(mini_color: Color, border_px: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = mini_color
	style.set_corner_radius_all(4)
	if border_px > 0:
		style.set_border_width_all(border_px)
		style.border_color = COLOR_CREAM
	return style

static func _eff_style(panel: Panel, k: float) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.961, 0.941, 0.902)
	style.set_corner_radius_all(maxi(3, roundi(13.0 * k)))
	style.set_border_width_all(maxi(1, roundi(3.0 * k)))
	style.border_color = Color(0.788, 0.761, 0.678)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true	# 区域保护最后一道闸：缩号＋省略号都兜不住时硬裁

static func _row_container(row: HBoxContainer) -> HBoxContainer:
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row

static func _make_chip(k: float, text: String, base_width: float, bg: Color, border: Color,
		text_color: Color) -> Panel:
	var chip: Panel = Panel.new()
	chip.custom_minimum_size = Vector2(roundi(base_width * k), maxi(16.0, roundi(33.0 * k)))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(maxi(2, roundi(6.0 * k)))
	style.set_border_width_all(maxi(1, roundi(2.0 * k)))
	style.border_color = border
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_text(chip, text, _fs(18, k), text_color)
	return chip

static func _text(parent: Control, text: String, size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	if size >= 18:
		label.add_theme_font_override("font", QIF_FONTS.display())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## 区域保护·自适应字号（2026-10-25 用户裁定）：效果/详情/名字带文字挂此线——
## 字号 base→FIT_FLOOR 逐级缩小直到塞进标签实测区域；到底仍溢出由行尾省略号＋面板 clip 兜底。
## width_only=true 时按单行宽测（名字带）；否则按换行宽×高测（效果文）。
static func _wire_fit(label: Label, base: int, width_only: bool = false) -> void:
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.set_meta("fit_base", base)
	label.set_meta("fit_width_only", width_only)
	label.item_rect_changed.connect(_refit_text.bind(label))

static func _refit_text(label: Label) -> void:
	if not label.is_inside_tree() or label.text.is_empty():
		return
	var font: Font = label.get_theme_font("font")
	if font == null:
		return
	var base: int = int(label.get_meta("fit_base", 12))
	var width_only: bool = bool(label.get_meta("fit_width_only", false))
	var avail_w: float = maxf(1.0, label.size.x - (6.0 if width_only else 0.0))
	var avail_h: float = label.size.y
	for size: int in range(base, FIT_FLOOR - 1, -1):
		var fits: bool = false
		if width_only:
			fits = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, size).x <= avail_w
		else:
			fits = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT,
				avail_w, size).y <= avail_h + 0.5
		if fits:
			label.add_theme_font_size_override("font_size", size)
			return
	label.add_theme_font_size_override("font_size", FIT_FLOOR)

static func _center_text(parent: Control, text: String, size: int, color: Color) -> void:
	var label: Label = _text(parent, text, size, color)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
#endregion
