extends RefCounted

# 牌阵 UI 共享调色板与样式工厂（24 号水墨武侠方案：宣纸底、墨色、金、朱红）。
# 注意：本工厂产出的装饰节点一律 mouse_filter=IGNORE，否则会把下层控件的点击吃掉
#（牌面/标签盖住地块导致点不动，是 M1 时期踩过的坑）。

const COLOR_CARD := Color("#F2E8D5")
const COLOR_INK := Color("#2B241C")
const COLOR_GOLD := Color("#D4A017")
const COLOR_BACK := Color("#3A332A")
const BRUSH_FONT := preload("res://assets/fonts/MaShanZheng.ttf")

const FRAME_COLORS := {
	"enemy": Color("#C0392B"),
	"pursuer": Color("#C0392B"),
	"zhenwu": Color("#6B4A8A"),
	"chest": Color("#B8860B"),
	"scatter": Color("#2E8B6F"),
	"location": Color("#3B7EA1"),
	"npc": Color("#D9D9D9"),
	"body": Color("#7A6A5A"),
}
const RARITY_COLORS := {
	"fine": Color(0.45, 0.65, 1.0),
	"rare": Color(0.75, 0.45, 1.0),
	"legend": Color(1.0, 0.75, 0.2),
}

static func card_style(kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD
	var border: Color = FRAME_COLORS.get(kind, COLOR_INK)
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 4
	return style

# 标题/地名/牌名用毛笔字
static func brush_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BRUSH_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

# 正文/数字用默认字体（Noto Sans SC）
static func plain_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func card_back(card_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = card_size
	panel.size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BACK
	style.border_color = COLOR_CARD
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 3
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func empty_slot(card_size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = card_size
	panel.size = card_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(COLOR_INK, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func card_mini(kind: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(40, 56)
	panel.size = Vector2(40, 56)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", card_style(kind))
	return panel
