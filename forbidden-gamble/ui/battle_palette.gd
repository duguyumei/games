extends RefCounted

# 战斗界面共享调色板与样式工厂（暗墨武侠：夜战底色、米金、朱红）。
# 与 board_palette（宣纸亮色）成对——版图亮/战斗暗是刻意的氛围对比，各自收敛不强行统一。
# 本工厂产出的装饰节点一律 mouse_filter=IGNORE（M1 坑：装饰盖住下层控件会吃点击）。

const BRUSH_FONT: FontFile = preload("res://assets/fonts/MaShanZheng.ttf")

# ---- 语义色（由 main.gd 内联色收敛而来；敌方红四合一为一档） ----
const COLOR_GOLD := Color(0.85, 0.68, 0.32)       # 我方金：行动方/胜利/横幅/战报
const COLOR_ENEMY := Color(0.8, 0.38, 0.3)        # 敌方朱红：行动方/横幅/飘字/败北
const COLOR_TURN_END := Color(0.58, 0.7, 0.76)    # 回合/终态分隔灰蓝
const COLOR_DRAW := Color(0.62, 0.6, 0.56)        # 平局
const COLOR_HINT := Color(0.88, 0.76, 0.4)        # 提示黄
const COLOR_BODY := Color(0.78, 0.75, 0.68, 0.9)  # 战报正文
const COLOR_DIM := Color(0.62, 0.58, 0.5)         # 弹窗小注/页脚
const COLOR_SECONDARY := Color(0.7, 0.66, 0.58)   # 次要说明
const COLOR_ITEM_NAME := Color(0.85, 0.8, 0.7)    # 物品行文字
const COLOR_RARITY_FALLBACK := Color(0.6, 0.55, 0.45)

# ---- 底色/框色 ----
const POPUP_BG := Color(0.13, 0.12, 0.1, 0.98)
const POPUP_BORDER := Color(0.44, 0.39, 0.3, 0.9)
const TOPBAR_BG := Color(0.09, 0.085, 0.08, 0.95)
const TOPBAR_BORDER := Color(0.44, 0.39, 0.3, 0.8)
const BANNER_BG := Color(0.07, 0.065, 0.055, 0.85)
const STAGE_BG := Color(0.16, 0.17, 0.19)

# ---- 功法等级色（素白/绿/蓝/紫/金，D-044）；technique_card 同源使用 ----
const LEVEL_COLORS: Array[Color] = [
	Color(0.92, 0.9, 0.86),
	Color(0.45, 0.65, 0.4),
	Color(0.4, 0.55, 0.75),
	Color(0.6, 0.45, 0.7),
	Color(0.88, 0.66, 0.22),
]
const SATISFIED_COLOR := Color(0.95, 0.75, 0.25)
const REASON_COLOR := Color(0.72, 0.2, 0.16)

# 稀有度色与 board_palette 保持一致（稀有度是游戏语义不是主题色，两处同值）
const RARITY_COLORS := {
	"fine": Color(0.45, 0.65, 1.0),
	"rare": Color(0.75, 0.45, 1.0),
	"legend": Color(1.0, 0.75, 0.2),
}

static func popup_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = POPUP_BG
	style.border_color = POPUP_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style

static func brush_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BRUSH_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func plain_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
