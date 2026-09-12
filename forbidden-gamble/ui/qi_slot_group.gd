@tool
class_name QiSlotGroup
extends Control

## 真气槽组（设计画布）：圆形镶孔竖排在功法卡右缘，左嵌右贴（丹珠真气版）。
## 孔径：1~3 槽 = 40；4~5 槽 = 34。孔为正圆（高=宽）。
## 排布：垂直居中分布，槽间留隙（4~5 槽均分卡高）。
## 镶嵌深浅模式（孔心贴右缘程度，0.3 深嵌 ~ 0.7 半凸）：
##   UNIFORM 全部 0.5；ARCH（4 槽）0.38/0.62/0.62/0.38 拱形；
##   STRAIGHT（5 槽顺子）0.30→0.70 自上而下递增阶梯。
## 空孔为深色镶口（见 qi_slot.tscn），填入丹珠后点亮。

enum SlotLayout { UNIFORM, ARCH, STRAIGHT }
enum Orientation { RIGHT, TOP }

const QI_SLOT_SCENE := "res://ui/qi_slot.tscn"
const SLOT_W_SMALL := 40.0  # 1~3 槽孔径
const SLOT_W_BIG := 34.0    # 4~5 槽孔径
const STACK_MARGIN := 6.0   # 4~5 槽竖排上下边距
const ARCH_PROTRUDE: Array[float] = [0.38, 0.62, 0.62, 0.38]
const STRAIGHT_PROTRUDE: Array[float] = [0.30, 0.40, 0.50, 0.60, 0.70]

@export_range(1, 5) var slot_count: int = 1:
	set(value):
		slot_count = clampi(value, 1, 5)
		_rebuild()
@export var slot_layout: SlotLayout = SlotLayout.UNIFORM:
	set(value):
		slot_layout = value
		_rebuild()
## 0=RIGHT 卡右缘竖排；1=TOP 卡顶缘横排（深浅方向随之转向）。
@export_enum("RIGHT", "TOP") var orientation: int = 0:
	set(value):
		orientation = value
		_rebuild()
@export var card_width: float = 150.0:
	set(value):
		card_width = value
		_rebuild()
@export var card_height: float = 210.0:
	set(value):
		card_height = value
		_rebuild()
## 相邻槽的纵向空隙（5 槽自动改用 FIVE_GAP）。
@export var slot_gap: float = 8.0:
	set(value):
		slot_gap = maxf(value, 0.0)
		_rebuild()
## 演示用：前 N 个槽显示"已填入真气"。
@export var demo_filled: int = 0:
	set(value):
		demo_filled = maxi(value, 0)
		_rebuild()

## 运行期填充：colors[i] 为第 i 孔的填充色（真气属性色）；数组短于槽数的孔隐藏，
## 传空数组清空全部。比 demo_filled 优先（运行时最后一次调用生效）。
func set_fill(colors: Array) -> void:
	for index in get_child_count():
		var slot: Control = get_child(index)
		var fill: Control = slot.get_node_or_null("Fill")
		if fill == null:
			continue
		if index < colors.size():
			fill.visible = true
			var sb: StyleBoxFlat = (fill.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
			sb.bg_color = colors[index]
			fill.add_theme_stylebox_override("panel", sb)
		else:
			fill.visible = false

func slot_width() -> float:
	return SLOT_W_SMALL if slot_count <= 3 else SLOT_W_BIG

# 镶孔为正圆：高 = 宽。
func slot_height() -> float:
	return slot_width()

func _protrude_ratio(index: int) -> float:
	match slot_layout:
		SlotLayout.ARCH:
			return ARCH_PROTRUDE[mini(index, ARCH_PROTRUDE.size() - 1)]
		SlotLayout.STRAIGHT:
			return STRAIGHT_PROTRUDE[mini(index, STRAIGHT_PROTRUDE.size() - 1)]
	return 0.5

func _ready() -> void:
	# 镶孔组是装饰层，整块忽略鼠标（C-008 铁律），点击落到功法卡本体
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()

# 1~3 槽：固定间隙居中分布；4~5 槽：均分卡高。
func _slot_pitch(h: float) -> float:
	if slot_count <= 3:
		return h + slot_gap
	return (card_height - 2.0 * STACK_MARGIN - h) / (slot_count - 1)

func _start_y(h: float) -> float:
	if slot_count <= 3:
		return (card_height - (slot_count * h + (slot_count - 1) * slot_gap)) / 2.0
	return STACK_MARGIN

# TOP 方向的横向分布（与竖排同规则换轴）。
func _pitch_x(w: float) -> float:
	if slot_count <= 3:
		return w + slot_gap
	return (card_width - 2.0 * STACK_MARGIN - w) / (slot_count - 1)

func _start_x(w: float) -> float:
	if slot_count <= 3:
		return (card_width - (slot_count * w + (slot_count - 1) * slot_gap)) / 2.0
	return STACK_MARGIN

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var packed: PackedScene = load(QI_SLOT_SCENE)
	if packed == null:
		return
	var w := slot_width()
	var h := slot_height()
	var pitch := _slot_pitch(h)
	var start_y := _start_y(h)
	var pitch_x := _pitch_x(w)
	var start_x := _start_x(w)
	for index in range(slot_count):
		var slot: Control = packed.instantiate()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := _protrude_ratio(index)
		# 镶嵌深浅：p 小深嵌卡内，p 大贴缘半凸（方向随 orientation 转向）。
		if orientation == 1:
			slot.position = Vector2(start_x + index * pitch_x, 4.0 - p * (w / 2.0 + 6.0))
		else:
			slot.position = Vector2(card_width - w - 4.0 + p * (w / 2.0 + 6.0), start_y + index * pitch)
		slot.size = Vector2(w, h)
		var fill: Control = slot.get_node_or_null("Fill")
		if fill != null:
			fill.visible = index < demo_filled
		add_child(slot)
	size = Vector2(card_width + w, card_height)
	position = Vector2.ZERO
