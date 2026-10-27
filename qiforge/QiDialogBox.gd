## qi-forge 弹窗盒（2026-10-27 按 STS2 NModalContainer 制重造，弃 Godot AcceptDialog）：
## Control＋dialogue_nine_patch 九宫格底层（NinePatchRect 直绘，边距 27/28/27/28）＋内容 VBox；
## confirmed/canceled 信号兼容旧 AcceptDialog 调用面（popup_centered/hide/get_ok_button/content）。
## qiforge 禁 class_name。
extends Control

signal confirmed
signal canceled

const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QIF_STYLE := preload("res://qiforge/QiStyle.gd")
const DLG_TEX: Texture2D = preload("res://qiforge/assets/sts2ref/dialogue_nine_patch.png")

var title_l: Label
var _content: VBoxContainer
var ok_btn: Button
var cancel_btn: Button
var _panel_size := Vector2(520, 300)
var _esc_close := true

func setup(title_text: String, ok_text: String, cancel_text: String,
		panel_size: Vector2, esc_close: bool) -> void:
	_panel_size = panel_size
	_esc_close = esc_close
	name = "QiDialog"
	custom_minimum_size = panel_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := NinePatchRect.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.texture = DLG_TEX
	bg.patch_margin_left = 27
	bg.patch_margin_top = 28
	bg.patch_margin_right = 27
	bg.patch_margin_bottom = 28
	bg.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bg.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 26.0
	box.offset_top = 20.0
	box.offset_right = -26.0
	box.offset_bottom = -22.0
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(box)

	title_l = Label.new()
	title_l.text = title_text
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	QIF_STYLE.font(title_l, 26, true)
	title_l.add_theme_color_override("font_color", QIF_STYLE.AMBER_BRIGHT)
	box.add_child(title_l)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(_content)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	if cancel_text != "":
		cancel_btn = Button.new()
		cancel_btn.text = cancel_text
		QIF_STYLE.apply_ghost(cancel_btn)
		QIF_STYLE.font(cancel_btn, 20)
		cancel_btn.add_theme_color_override("font_color", QIF_STYLE.TEXT_MAIN)
		cancel_btn.pressed.connect(func() -> void:
			canceled.emit())
		btns.add_child(cancel_btn)
	ok_btn = Button.new()
	ok_btn.text = ok_text
	ok_btn.custom_minimum_size = Vector2(220, 48)
	QIF_STYLE.apply_primary(ok_btn)
	QIF_STYLE.font(ok_btn, 21, true)
	ok_btn.add_theme_color_override("font_color", Color("ffe9b0"))
	ok_btn.pressed.connect(func() -> void:
		confirmed.emit())
	btns.add_child(ok_btn)
	box.add_child(btns)

func content() -> VBoxContainer:
	return _content

func get_ok_button() -> Button:
	return ok_btn

func get_cancel_button() -> Button:
	return cancel_btn

## 居中弹出（尺寸可覆写；等价旧 AcceptDialog.popup_centered）
func popup_centered(sz := Vector2i()) -> void:
	if sz.x > 0 and sz.y > 0:
		_panel_size = Vector2(sz)
		custom_minimum_size = _panel_size
	visible = true
	_recenter.call_deferred()

func _recenter() -> void:
	var par := get_parent_control()
	if par == null:
		return
	size = _panel_size
	position = (par.get_viewport_rect().size - _panel_size) * 0.5

func _unhandled_key_input(event: InputEvent) -> void:
	if _esc_close and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		canceled.emit()
		get_viewport().set_input_as_handled()
