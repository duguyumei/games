class_name TechniqueBar
extends Control

## 功法层（D-044）：6 卡位均分 1280（功法＋空位，间距 54），卡右缘圆形镶孔组。
## 运行期由 set_techniques 重建卡位；画布里的演示卡在 _ready 清掉。

signal technique_clicked(technique_id: String)

const TECHNIQUE_CARD_SCENE := preload("res://ui/technique_card.tscn")
const QI_SLOT_GROUP_SCENE := preload("res://ui/qi_slot_group.tscn")
const EMPTY_SLOT_SCENE := preload("res://ui/technique_empty_slot.tscn")

const CARD_WIDTH := 150.0
const CARD_HEIGHT := 210.0
const SLOT_PITCH := 204.0   # 相邻卡位左缘间距
const START_X := 54.0
const CARD_Y := 14.0
const MAX_SLOTS := 6

var _cards: Dictionary = {}   # technique_id -> TechniqueCard
var _slot_groups: Dictionary = {}  # technique_id -> QiSlotGroup
var _runtime: Array[Control] = []  # 运行期创建的卡/空位（清场用）

func _ready() -> void:
	_clear_cards()

## entries: [{id, name, effect, level, slot_count, slot_layout(qi_slot_group.SlotLayout)}]
func set_techniques(entries: Array) -> void:
	_clear_cards()
	var position_index := 0
	for entry in entries:
		if position_index >= MAX_SLOTS:
			push_warning("功法数超过卡位上限 %d" % MAX_SLOTS)
			break
		var card: TechniqueCard = TECHNIQUE_CARD_SCENE.instantiate() as TechniqueCard
		card.position = Vector2(START_X + position_index * SLOT_PITCH, CARD_Y)
		card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
		card.set_card(str(entry.get("name", entry.get("id", ""))), str(entry.get("effect", "")), int(entry.get("level", 1)))
		card.clicked.connect(_on_card_clicked.bind(str(entry.get("id", ""))))
		add_child(card)
		var slots: QiSlotGroup = QI_SLOT_GROUP_SCENE.instantiate() as QiSlotGroup
		slots.slot_count = int(entry.get("slot_count", 1))
		slots.slot_layout = int(entry.get("slot_layout", 0))
		slots.demo_filled = 0
		card.add_child(slots)
		var id := str(entry.get("id", ""))
		_cards[id] = card
		_slot_groups[id] = slots
		_runtime.append(card)
		position_index += 1
	while position_index < MAX_SLOTS:
		var empty := _make_empty_slot(position_index)
		add_child(empty)
		_runtime.append(empty)
		position_index += 1

## states: id -> {state: TechniqueCard.CardState, reason: String, fill: Array[Color]}
func set_states(states: Dictionary) -> void:
	for id in _cards:
		var card: TechniqueCard = _cards[id]
		var info: Dictionary = states.get(id, {})
		card.set_state(int(info.get("state", TechniqueCard.CardState.NORMAL)), str(info.get("reason", "")))
		var slots: QiSlotGroup = _slot_groups.get(id)
		if slots != null:
			slots.set_fill(info.get("fill", []))

func _on_card_clicked(technique_id: String) -> void:
	technique_clicked.emit(technique_id)

func _make_empty_slot(index: int) -> Panel:
	# 空位＝编辑器模板（technique_empty_slot.tscn）实例化，样式进场景改，不进代码。
	var panel: Panel = EMPTY_SLOT_SCENE.instantiate() as Panel
	panel.position = Vector2(START_X + index * SLOT_PITCH, CARD_Y)
	panel.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	return panel

# 清场：画布演示卡（Card*/EmptySlot）与运行期创建的卡/空位（记录在 _runtime）
# 都要清；风格色块背景（Bg）保留。
func _clear_cards() -> void:
	if not is_inside_tree():
		return
	for node in _runtime:
		if is_instance_valid(node):
			node.queue_free()
	_runtime = []
	for child in get_children():
		if child.name.begins_with("Card") or child.name == "EmptySlot":
			child.queue_free()
	_cards = {}
	_slot_groups = {}
