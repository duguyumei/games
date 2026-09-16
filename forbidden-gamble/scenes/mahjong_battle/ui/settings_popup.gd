class_name MJBSettingsPopup
extends PanelContainer

## 设置弹层（顶栏齿轮入口，2026-09-16 用户布局令）：自动理牌从手牌标题行迁入。
## 会话级暂存（持久化随设置面板轮）。


signal sort_toggled(on: bool)

var _auto_sort_box := CheckBox.new()


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.13)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.6, 0.55, 0.4)
	sb.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new()
	title.text = "设置"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)
	_auto_sort_box.text = "自动理牌"
	_auto_sort_box.add_theme_font_size_override("font_size", 14)
	_auto_sort_box.toggled.connect(func(on: bool): sort_toggled.emit(on))
	box.add_child(_auto_sort_box)
	var close := Button.new()
	close.text = "关 闭"
	close.pressed.connect(func(): visible = false)
	box.add_child(close)


func open(auto_sort: bool) -> void:
	_auto_sort_box.set_pressed_no_signal(auto_sort)
	visible = true
