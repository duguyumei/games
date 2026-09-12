class_name BattleSettingsPopup
extends PanelContainer

# 战斗设置弹窗内容（PopupHost 负责定位与关闭交互）：
# 演出速度三档（立即生效，弹窗保持打开便于当场感受）＋结束演练两段确认＋继续。
# 弃战口径（C-017 定案）：结束演练回主菜单；"逃跑"另立项为道具。

signal pace_selected(factor: float)
signal abandon_requested
signal close_requested

const BP := preload("res://ui/battle_palette.gd")

func setup(current_pace: float) -> void:
	custom_minimum_size = Vector2(250, 0)
	add_theme_stylebox_override("panel", BP.popup_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(BP.plain_label("演出速度", 12, BP.COLOR_DIM))
	add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for option in [["快", 0.6], ["标准", 1.0], ["慢", 1.6]]:
		var pace_name := str(option[0])
		var factor := float(option[1])
		var btn := Button.new()
		btn.text = pace_name
		btn.focus_mode = Control.FOCUS_NONE
		if is_equal_approx(factor, current_pace):
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", BP.COLOR_GOLD)
		btn.pressed.connect(func(): pace_selected.emit(factor))
		row.add_child(btn)
	box.add_child(row)
	var abandon := ConfirmButton.new()
	abandon.setup("结束演练，回主菜单", "确定结束演练？")
	abandon.confirmed.connect(func(): abandon_requested.emit())
	box.add_child(abandon)
	var close := Button.new()
	close.text = "继续"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): close_requested.emit())
	box.add_child(close)
