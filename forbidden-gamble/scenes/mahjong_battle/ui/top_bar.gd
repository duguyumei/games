class_name MJBTopBar
extends PanelContainer

## 战斗顶栏（对齐 v2.2 BattleTopBar 惯例：遭遇名＋回合·行动方＋按钮）。
## 纯展示＋信号上抛：返回＝中局随时回演武场；设置＝齿轮弹层（自动理牌等）。


signal back_pressed
signal settings_pressed
signal help_pressed

var _turn := Label.new()


func _init() -> void:
	custom_minimum_size = Vector2(0, 38)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.085, 0.08, 0.95)
	sb.border_width_bottom = 1
	sb.border_color = Color(0.44, 0.39, 0.3, 0.8)
	add_theme_stylebox_override("panel", sb)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var back := Button.new()
	back.text = "‹ 演武场"
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(func(): back_pressed.emit())
	bar.add_child(back)
	var title := Label.new()
	title.text = "麻将演武"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7))
	bar.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	_turn.add_theme_font_size_override("font_size", 14)
	bar.add_child(_turn)
	var help := Button.new()
	help.text = "?"
	help.tooltip_text = "词条（式与面子、罡气、变招…）"
	help.add_theme_font_size_override("font_size", 15)
	help.pressed.connect(func(): help_pressed.emit())
	bar.add_child(help)
	var gear := Button.new()
	gear.text = "⚙"
	gear.tooltip_text = "设置"
	gear.add_theme_font_size_override("font_size", 15)
	gear.pressed.connect(func(): settings_pressed.emit())
	bar.add_child(gear)


func set_turn(text: String, color: Color) -> void:
	_turn.text = text
	_turn.add_theme_color_override("font_color", color)
