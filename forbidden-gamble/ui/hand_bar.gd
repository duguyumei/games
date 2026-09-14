class_name HandBar
extends Control

## 经脉手牌层（D-044）：左端丹田＝抽牌堆（太极），右端气海＝弃牌堆（气旋），
## 中间管道嵌真气丹珠。孔位不再固定数量——按当前手牌数在活动区居中动态生成：
## 空孔不显示（花掉的真气不留坑），手牌数无上限（挤不下时自动收窄间距）。
## 运行期由 set_hand 生成孔环＋丹珠；画布里的演示珠在 _ready 清掉。
## 真气流动演出（M7c）：main.gd 经 dantian_center/qihai_center/socket_centers/
## orb_snapshots 取坐标，用幽灵丹珠播放抽牌/发动/回收的流动。

signal card_clicked(index: int)

const QI_ORB_SCENE := preload("res://ui/qi_orb.tscn")
# 丹珠 56×56 嵌在 48×48 孔位上，居中偏移 -4
const ORB_ON_SOCKET_OFFSET := Vector2(-4, -4)
# 孔位活动区（画布定稿：丹田与气海之间的管道段）与常规孔距
const SOCKET_AREA := Rect2(388, 36, 504, 48)
const SOCKET_PITCH := 76.0

var _runtime_orbs: Array[Control] = []
var _runtime_rings: Array[Control] = []

@onready var _socket_template: Control = $SocketTemplate

func _ready() -> void:
	_clear_orbs()

## 气海（共墙）/河（弃牌）计数（真气语法 v2）。
func set_piles(deck_count: int, discard_count: int) -> void:
	var deck_label: Label = get_node_or_null("Dantian/DantianNum")
	if deck_label != null:
		deck_label.text = str(deck_count)
	var discard_label: Label = get_node_or_null("QiHai/QiHaiNum")
	if discard_label != null:
		discard_label.text = str(discard_count)

## 顶部凝招信息行（牌型＋真气量，或操作提示）。
func set_meld_info(text: String) -> void:
	var info: Label = get_node_or_null("MeldInfo")
	if info != null:
		info.text = text

## 重摆手牌丹珠：cards 为真气卡（attribute/value/statuses），
## selected 为选中索引（金环），interactive 为 false 时整排压暗不可点。
func set_hand(cards: Array, selected: Array[int], interactive: bool) -> void:
	_clear_orbs()
	var sockets := _socket_positions(cards.size())
	for index in range(cards.size()):
		var ring: Control = _socket_template.duplicate()
		ring.visible = true
		ring.position = sockets[index]
		add_child(ring)
		_runtime_rings.append(ring)
		var card = cards[index]
		var orb: QiOrb = QI_ORB_SCENE.instantiate() as QiOrb
		orb.position = sockets[index] + ORB_ON_SOCKET_OFFSET
		orb.force_text = card.value_text()
		orb.suit_text = str(card.attribute)
		orb.orb_color = QiOrb.color_for_attribute(str(card.attribute))
		orb.selected = selected.has(index)
		orb.status_ring = not card.statuses.is_empty()
		add_child(orb)
		_runtime_orbs.append(orb)
		if not interactive:
			orb.modulate = Color(0.55, 0.55, 0.55)
			orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			orb.clicked.connect(_on_orb_clicked.bind(index))

func _on_orb_clicked(index: int) -> void:
	card_clicked.emit(index)

# 孔位坐标：count 个 48×48 孔位在活动区内居中；挤不下时收窄间距（数量无上限）。
func _socket_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var pitch := SOCKET_PITCH
	if count > 1:
		pitch = minf(SOCKET_PITCH, (SOCKET_AREA.size.x - 48.0) / float(count - 1))
	var row_width := (count - 1) * pitch + 48.0
	var x0 := SOCKET_AREA.position.x + (SOCKET_AREA.size.x - row_width) * 0.5
	for i in range(count):
		positions.append(Vector2(x0 + i * pitch, SOCKET_AREA.position.y))
	return positions

# ---------- 流动演出坐标接口（全局坐标，供 main.gd 播幽灵丹珠） ----------

func dantian_center() -> Vector2:
	var node := get_node_or_null("Dantian")
	return node.get_global_rect().get_center() if node != null else Vector2.ZERO

func qihai_center() -> Vector2:
	var node := get_node_or_null("QiHai")
	return node.get_global_rect().get_center() if node != null else Vector2.ZERO

# 当前手牌珠的孔位中心（仅占用孔——抽牌流动的目标点）。
func socket_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for local_pos in _socket_positions(_runtime_orbs.size()):
		centers.append(local_pos + global_position + Vector2(24, 24))
	return centers

# 当前手牌珠的位快照（发动功法的流动用：珠已从手牌移除，幽灵从原位起飞）。
func orb_snapshots(indices: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in indices:
		if index >= 0 and index < _runtime_orbs.size():
			var orb: Control = _runtime_orbs[index]
			if is_instance_valid(orb):
				out.append({
					"pos": orb.global_position + orb.size * 0.5,
					"color": (orb as QiOrb).orb_color,
				})
	return out

# 清场：画布演示珠（HandOrb*）与运行期创建的孔环/丹珠。
func _clear_orbs() -> void:
	if not is_inside_tree():
		return
	for node in _runtime_orbs:
		if is_instance_valid(node):
			node.queue_free()
	_runtime_orbs = []
	for node in _runtime_rings:
		if is_instance_valid(node):
			node.queue_free()
	_runtime_rings = []
	for child in get_children():
		if child is Panel and child.name.begins_with("HandOrb"):
			child.queue_free()
