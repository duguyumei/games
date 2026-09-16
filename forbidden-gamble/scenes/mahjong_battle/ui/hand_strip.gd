class_name MJBHandStrip
extends VBoxContainer

## 手牌区（丹田）——**张数不吃死**：多少张显示多少张，牌宽随张数自适应（挤牌收窄，
## 摸牌超上限/变招/岭上等任何瞬时张数都原样呈现，不裁不换行）。
## 标题行已退役（2026-09-17 用户令）：丹田张数移入资源读数条领衔位，本区只留牌行。
## 显示序（自动理牌）与引擎索引分离：点选回传引擎索引，弃牌应答不错位。
## 自动理牌开关在设置弹层（顶栏齿轮），本组件只持状态。


const HAND_BUDGET := 1000  # 手牌行宽度预算（视口 1280 下的排布参考，非张数上限）

var on_tile_clicked: Callable  # (engine_index: int) -> void

var _auto_sort := true
var _hand_row := HBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_hand_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_hand_row)
	# 选中态＝升起：HBox 每次布局会回写子节点 y，故挂 sort_children 在布局后重贴偏移
	_hand_row.sort_children.connect(_apply_raises)


func _apply_raises() -> void:
	for child in _hand_row.get_children():
		if child.get_meta("raise", false):
			child.position.y = -10.0


func auto_sort() -> bool:
	return _auto_sort


func set_auto_sort(on: bool) -> void:
	_auto_sort = on


## hand＝引擎手牌；selected＝引擎索引集（**选中态＝升起**，2026-09-17 用户令——不是边框变色）；
## candidate_ids＝武学备付候选牌（金边，攻击武学第一击后标出）；fresh_ids＝刚摸到的牌（顶缘金条）。
func update_hand(hand: Array, selected: Dictionary, candidate_ids: Array = [], fresh_ids: Array = []) -> void:
	for child in _hand_row.get_children():
		child.queue_free()
	var n := hand.size()
	if n == 0:
		return
	# 动态牌宽：预算内自适应，下限 30（挤而不糊）；张数少时用舒适上限 58
	# （牌高上限 74——底部块再收一点，手牌行位下移，2026-09-17 用户令）
	var w := clampi(int(HAND_BUDGET / n) - 2, 30, 58)
	var h := clampi(int(w * 1.42), 42, 74)
	_hand_row.add_theme_constant_override("separation", 2 if n > 13 else 5)
	for entry in _display_order(hand):
		var index := int(entry["i"])
		var tile := entry["t"] as MJTile
		var widget := MJBTileFace.make_tile(tile, w, h)
		var tid := tile.get_instance_id()
		widget.set_meta("raise", selected.has(index))  # 升起标记（布局后由 _apply_raises 落位）
		if not selected.has(index) and candidate_ids.has(tid):
			widget = MJBTileFace.glow(widget, Color(0.85, 0.75, 0.4))  # 候选＝金边（非选中时）
		if fresh_ids.has(tid):
			MJBTileFace.fresh_mark(widget)
		widget.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				on_tile_clicked.call(index))
		_hand_row.add_child(widget)
		if selected.has(index):
			widget.position.y = -10


# 显示序（自动理牌开）：全部手牌按属性序＋数值升序（摸到的牌也参与排序——用户裁定）。
func _display_order(hand: Array) -> Array:
	var entries: Array = []
	for i in range(hand.size()):
		entries.append({"i": i, "t": hand[i]})
	if _auto_sort:
		entries.sort_custom(func(a, b) -> bool:
			var ta := a["t"] as MJTile
			var tb := b["t"] as MJTile
			var sa := MJTile.SUITS.find(ta.suit)
			var sb := MJTile.SUITS.find(tb.suit)
			if sa != sb:
				return sa < sb
			return ta.value < tb.value)
	return entries
