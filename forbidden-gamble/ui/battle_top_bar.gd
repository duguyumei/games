class_name BattleTopBar
extends Panel

# 战斗顶栏（C-017）：遭遇名 + 回合·行动方 + 最新战报行 + 背包/战报/设置按钮。
# 纯展示组件——文本与配色语义由 main.gd 决定，按钮经信号上抛。

signal bag_pressed()
signal report_pressed()
signal settings_pressed()

@onready var context_label: Label = $Bar/ContextLabel
@onready var turn_label: Label = $Bar/TurnLabel
@onready var log_line: Label = $Bar/LogLine

func _ready() -> void:
	($Bar/BagButton as Button).pressed.connect(func(): bag_pressed.emit())
	($Bar/ReportButton as Button).pressed.connect(func(): report_pressed.emit())
	($Bar/GearButton as Button).pressed.connect(func(): settings_pressed.emit())

func set_context(text: String) -> void:
	context_label.text = text

func set_turn(text: String, color: Color) -> void:
	turn_label.text = text
	turn_label.add_theme_color_override("font_color", color)

func set_log_line(text: String, color: Color) -> void:
	log_line.text = text
	log_line.add_theme_color_override("font_color", color)
