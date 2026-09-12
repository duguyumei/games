class_name QiCountCell
extends HBoxContainer

# 演武场真气牌组编辑的计数格（编辑器模板）：某属性某品级的携带张数（品级 1/2/3＝下/中/上）。
# setup() 在入树前调用（父容器 add_child 之前），不能依赖 @onready。
# "凝"按钮：请求把本格 2 张凝成 1 张品阶更高的真气（合法性由 dojo 侧 FusionRules 裁定，
# 这里只按"看得见可凝"控制按钮显隐）。

signal count_changed
signal fuse_requested

var value := 1
var count := 0

const GRADE_LABELS := ["下品", "中品", "上品"]


func _ready() -> void:
	($MinusButton as Button).pressed.connect(_on_minus_pressed)
	($PlusButton as Button).pressed.connect(_on_plus_pressed)
	($FuseButton as Button).pressed.connect(func(): fuse_requested.emit())
	_refresh()


func setup(new_value: int, initial: int) -> void:
	value = new_value
	count = initial
	_refresh()


# 外部改数（凝的增减走这里，保持 count_changed 通知链）
func set_count(new_count: int) -> void:
	count = clampi(new_count, 0, 99)
	_refresh()
	count_changed.emit()


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
	var fuse := get_node_or_null("FuseButton") as Button
	if fuse != null:
		fuse.visible = value < 3 and count >= 2
