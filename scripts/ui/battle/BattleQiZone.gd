## 真气战斗 HUD 的牌区组件；统一管理牌区显示和动态手牌布局。
extends Control
class_name BattleQiZone

## 牌区中的牌被点击时发出真气实例 UID。
signal card_clicked(qi_instance_uid: String)

## 当前牌区是否允许玩家选择牌。
var selectable: bool = false

## 横向滚动容器；手牌数量增加时不会丢弃牌。
var _scroll_container: ScrollContainer

## 牌组件的横向排列容器。
var _card_row: HBoxContainer

## 当前按真气实例 UID缓存的牌组件。
var _cards_by_uid: Dictionary[String, BattleQiCard] = {}

## 创建可横向滚动的动态牌区。
func _ready() -> void:
	_scroll_container = ScrollContainer.new()
	_scroll_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll_container)
	_card_row = HBoxContainer.new()
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_row.add_theme_constant_override("separation", 6)
	_card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_row.custom_minimum_size = Vector2(0.0, 156.0)
	_scroll_container.add_child(_card_row)

## 从战斗状态刷新一组牌；face_up_count 表示从左侧已经翻开的数量。
func render(
		qi_cards: Array[QiData],
		face_up_count: int = -1,
		_selected_uids: Array[String] = [],
		selection_order: Dictionary = {},
		_should_select: bool = false) -> void:
	selectable = _should_select
	var visible_uids: Dictionary[String, bool] = {}
	for qi_index: int in qi_cards.size():
		var qi_data: QiData = qi_cards[qi_index]
		if qi_data == null or qi_data.object_uid == "":
			continue
		var qi_uid: String = qi_data.object_uid
		visible_uids[qi_uid] = true
		var card: BattleQiCard = _cards_by_uid.get(qi_uid, null)
		if card == null:
			card = BattleQiCard.new()
			_cards_by_uid[qi_uid] = card
			_card_row.add_child(card)
			card.qi_clicked.connect(_on_card_clicked)
			card.setup(
				qi_data,
				Global.battle_qi_state,
				face_up_count >= 0 and qi_index >= face_up_count,
				_should_select)
		else:
			card.qi_data = qi_data
			card.battle_state = Global.battle_qi_state
			card.selectable = _should_select
			card.refresh_display()
			var should_face_down: bool = face_up_count >= 0 and qi_index >= face_up_count
			card.set_face_down(should_face_down)
		_card_row.move_child(card, qi_index)
		var order_value: int = int(selection_order.get(qi_uid, 0))
		card.set_selected(_selected_uids.has(qi_uid), order_value)

	for cached_uid: String in _cards_by_uid.keys():
		if visible_uids.has(cached_uid):
			continue
		var stale_card: BattleQiCard = _cards_by_uid[cached_uid]
		_cards_by_uid.erase(cached_uid)
		stale_card.queue_free()

	_update_card_layout(qi_cards.size())

## 清空牌区中的所有可视组件。
func clear_zone() -> void:
	for cached_card: BattleQiCard in _cards_by_uid.values():
		cached_card.queue_free()
	_cards_by_uid.clear()

## 根据牌数调整牌的缩放；逻辑上不设置手牌数量上限。
func _update_card_layout(card_count: int) -> void:
	var layout_scale: float = 1.0
	if card_count > 8:
		layout_scale = clamp(8.0 / float(card_count), 0.58, 1.0)
	for card: BattleQiCard in _cards_by_uid.values():
		card.custom_minimum_size = Vector2(112.0, 148.0) * layout_scale
		card.set_layout_scale(layout_scale)
	_card_row.custom_minimum_size.y = 156.0 * layout_scale

func _on_card_clicked(qi_instance_uid: String) -> void:
	if selectable:
		card_clicked.emit(qi_instance_uid)
