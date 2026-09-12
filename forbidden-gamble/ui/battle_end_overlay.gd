class_name BattleEndOverlay
extends Control

# 终局结算浮层：胜/败/平摘要 + 明确出口（重开一场 / 回演武场）。
# 结局文案由场景根计算后经 show_result 灌入；本组件只管呈现与按钮上抛。

signal report_requested
signal restart_requested
signal return_requested

const BP := preload("res://ui/battle_palette.gd")

@onready var title: Label = $Center/Panel/Margin/Column/Title
@onready var sub: Label = $Center/Panel/Margin/Column/Sub
@onready var report_button: Button = $Center/Panel/Margin/Column/BtnRow/ReportButton
@onready var restart_button: Button = $Center/Panel/Margin/Column/BtnRow/RestartButton
@onready var return_button: Button = $Center/Panel/Margin/Column/BtnRow/ReturnButton

func _ready() -> void:
	report_button.pressed.connect(func(): report_requested.emit())
	restart_button.pressed.connect(func(): restart_requested.emit())
	return_button.pressed.connect(func(): return_requested.emit())

# kind：player/enemy/draw。重开与返回两个出口常驻（演武场口径）。
func show_result(kind: String, sub_lines: Array[String]) -> void:
	var accent := BP.COLOR_GOLD
	var title_text := "—— 战斗胜利 ——"
	match kind:
		"enemy":
			accent = BP.COLOR_ENEMY
			title_text = "—— 战斗败北 ——"
		"draw":
			accent = BP.COLOR_DRAW
			title_text = "—— 平局 ——"
	title.text = title_text
	title.add_theme_color_override("font_color", accent)
	sub.text = "\n".join(sub_lines)
	restart_button.visible = true
	return_button.visible = true
	return_button.text = "回演武场"
	visible = true
