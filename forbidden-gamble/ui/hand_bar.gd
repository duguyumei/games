class_name HandBar
extends Control

## 经脉手牌层（D-044）：左端丹田＝抽牌堆（太极），右端气海＝弃牌堆（气旋），
## 中间管道开孔位嵌真气丹珠。运行期由 set_hand 填珠；画布里的演示珠在 _ready 清掉。
## 真气流动演出（M7c）：main.gd 经 dantian_center/qihai_center/socket_centers/
## orb_snapshots 取坐标，用幽灵丹珠播放抽牌/发动/回收的流动。

signal card_clicked(index: int)

const QI_ORB_SCENE := preload("res://ui/qi_orb.tscn")
# 丹珠 56×56 嵌在 48×48 孔位上，居中偏移 -4
const ORB_ON_SOCKET_OFFSET := Vector2(-4, -4)

var _runtime_orbs: Array[Control] = []

func _ready() -> void:
	_clear_orbs()

## 抽牌堆/弃牌堆计数。
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

## 重摆手牌丹珠：cards 为真气卡（attribute/grade/statuses），
## selected 为选中索引（金环），interactive 为 false 时整排压暗不可点。
func set_hand(cards: Array, selected: Array[int], interactive: bool) -> void:
	_clear_orbs()
	var sockets := _socket_positions()
	for index in range(cards.size()):
		if index >= sockets.size():
			push_warning("手牌数 %d 超过孔位数 %d" % [cards.size(), sockets.size()])
			break
		var card = cards[index]
		var orb: QiOrb = QI_ORB_SCENE.instantiate() as QiOrb
		orb.position = sockets[index] + ORB_ON_SOCKET_OFFSET
		orb.force_text = card.grade_short()
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

# 孔位坐标取自场景里的 Socket* 子节点（画布定稿位置）。
func _socket_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var sockets: Array = []
	for child in get_children():
		if child.name.begins_with("Socket"):
			sockets.append(child)
	sockets.sort_custom(func(a, b): return a.position.x < b.position.x)
	for socket in sockets:
		positions.append(socket.position)
	return positions

# ---------- 流动演出坐标接口（全局坐标，供 main.gd 播幽灵丹珠） ----------

func dantian_center() -> Vector2:
	var node := get_node_or_null("Dantian")
	return node.get_global_rect().get_center() if node != null else Vector2.ZERO

func qihai_center() -> Vector2:
	var node := get_node_or_null("QiHai")
	return node.get_global_rect().get_center() if node != null else Vector2.ZERO

func socket_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for local_pos in _socket_positions():
		centers.append(local_pos + global_position)
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

# 清场：画布演示珠（HandOrb*）与运行期创建的珠（记录在 _runtime_orbs）。
func _clear_orbs() -> void:
	if not is_inside_tree():
		return
	for node in _runtime_orbs:
		if is_instance_valid(node):
			node.queue_free()
	_runtime_orbs = []
	for child in get_children():
		if child is Panel and child.name.begins_with("HandOrb"):
			child.queue_free()
