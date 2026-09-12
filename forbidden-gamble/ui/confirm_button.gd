class_name ConfirmButton
extends Button

# 两段式确认按钮：第一次点＝武装（换确认文案），再点＝触发 confirmed。
# 用于不可逆操作（弃战/放弃远征/弃档开新）。弹窗重开时内容重建即自动复位；
# 需要外部复位时调 disarm()。

signal confirmed

var normal_text := ""
var confirm_text := "确定？再点一次"

var _armed := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)

func setup(text_normal: String, text_confirm: String) -> void:
	normal_text = text_normal
	confirm_text = text_confirm
	disarm()

func arm() -> void:
	_armed = true
	text = confirm_text

func disarm() -> void:
	_armed = false
	text = normal_text

func is_armed() -> bool:
	return _armed

func _on_pressed() -> void:
	if _armed:
		disarm()
		confirmed.emit()
	else:
		arm()
