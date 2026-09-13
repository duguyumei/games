class_name QiCountCell
extends HBoxContainer

# 演武场真气牌组编辑的计数格（编辑器模板）：某属性某品级的携带张数（品级 1/2/3＝下/中/上）。
# setup() 在入树前调用（父容器 add_child 之前），不能依赖 @onready。

signal count_changed

var value := 1
var count := 0

const GRADE_LABELS := ["下品", "中品", "上品"]


func _ready() -> void:
	($MinusButton as Button).pressed.connect(_on_minus_pressed)
	($PlusButton as Button).pressed.connect(_on_plus_pressed)
	_refresh()


func setup(new_value: int, initial: int) -> void:
	value = new_value
	count = initial
	_refresh()


func _on_plus_pressed() -> void:
	count = mini(count + 1, 99)
	_refresh()
	count_changed.emit()


func _on_minus_pressed() -> void:
	count = maxi(count - 1, 0)
	_refresh()
	count_changed.emit()


func _refresh() -> void:
	if not is_inside_tree():
		return
	($ValueLabel as Label).text = GRADE_LABELS[clampi(value, 1, 3) - 1]
	($CountLabel as Label).text = "×%d" % count
