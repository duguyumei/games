## qi-forge 统一样式令牌：全场唯一视觉常量源（配色／字号／样式盒构建器）。
## 风格依据 game-ui-ux skill（参考分辨率 1920×1080＋canvas_items/expand；容器优先；字号下限：正文≥18、小字≥16）。
## 凡绘制 UI（卡面工厂外的一切面板/浮窗/弹窗/HUD）一律引此处令牌，禁止散落硬编码颜色。
extends RefCounted

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")

## Theme 资源（2026-10-26 少码优先制·样式进 Theme 轮）：按钮样式进变体（QiGhost/QiPrimary），
## 屏幕根挂 apply_root_theme、按钮挂 theme_type_variation。面板/浮窗等带参数样式盒仍用下方构建器。
const THEME_PATH := "res://qiforge/qi_theme.tres"

static func apply_root_theme(c: Control) -> void:
	c.theme = load(THEME_PATH)
	# 字体制（2026-10-27 修断链）：根 Window 默认字体＝Noto 必须在此顺挂——
	# 此前唯一调用方在已退役旧界面里，主场景切 QiRoot 后整链断掉＝乱码回潮
	QIF_FONTS.apply_default_font(c.get_window())

static func apply_ghost(b: Button) -> void:
	b.theme_type_variation = "QiGhost"

static func apply_primary(b: Button) -> void:
	b.theme_type_variation = "QiPrimary"

# —— 墨金武侠配色（全场唯一） ——
const INK_BG := Color("17130d")          # 墨底（战场/全屏底）
const INK_PANEL := Color("241f16")       # 面板底
const INK_PANEL_DEEP := Color("0f0c08")  # 深底（浮窗/遮罩上层面）
const TEXT_MAIN := Color("f0e6c8")       # 主文（米金）
const TEXT_SUB := Color("9a8f74")        # 次文（灰褐）
const AMBER := Color("c9a227")           # 琥珀（边框/强调）
const AMBER_BRIGHT := Color("ffd766")    # 亮琥珀（数值/高亮）
const CREAM := Color("f2ebd8")           # 奶油（弹窗底/反色文字）
const NAVY := Color("1a2130")            # 藏青（确认键底）
const RED := Color("b8543f")             # 敌/血条
const JADE := Color("7fae62")            # 我方/增益
const PURPLE := Color("cbb2ef")          # 异常/状态

# —— 字号（1080p 参考分辨率） ——
const FS_TITLE := 26                     # 弹窗标题/浮窗标题（display 字体）
const FS_BIG := 22                       # 单位名/按钮主文
const FS_BODY := 18                      # 正文（下限）
const FS_SMALL := 16                     # 小字（下限，低于此违法）

# —— 样式盒构建器 ——
## 深底浮窗/面板（浮窗、HUD 面板通用）
static func panel_tip() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_PANEL_DEEP.r, INK_PANEL_DEEP.g, INK_PANEL_DEEP.b, 0.96)
	sb.border_color = AMBER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	return sb

## 常规面板（备战舱三栏、卡片容器）
static func panel(back_alpha := 0.55) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK_PANEL.r, INK_PANEL.g, INK_PANEL.b, back_alpha)
	sb.border_color = Color(AMBER.r * 0.7, AMBER.g * 0.7, AMBER.b * 0.7, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	return sb

## 琥珀系按钮（主操作：结束阶段/出战/确认）
static func button_primary() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("8a6428")
	sb.border_color = AMBER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb

## 墨底次级按钮（左侧按钮组/功能钮）
static func button_ghost() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.23, 0.18, 0.13, 0.92)
	sb.border_color = Color("6b5426")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	return sb

## 统一字体应用（title 用 display 展示体，其余 Noto 正文体——字体制）
static func font(node: Control, size: int, is_title := false) -> void:
	if is_title:
		node.add_theme_font_override("font", QIF_FONTS.display())
	node.add_theme_font_size_override("font_size", size)

## 统一文字色（Label/RichTextLabel 用）
static func text_color(node: Control, color: Color) -> void:
	node.add_theme_color_override("font_color", color)
