extends Panel

# 背包组件：右下角，容量数据驱动（每行最多 15 格，超出自动换行）。
# 上＝背包（使用/丢弃/入囊/穿上），中＝穿戴栏（兵器/护具/行囊，点选后卸下），
# 下＝贴身锦囊（使用/回包/丢弃，死亡保底）。点选/动作经信号上抛给 board.gd；
# 三段各有独立选中态（背包 selected / 穿戴 selected_wear / 锦囊 selected_pouch）。

signal slot_pressed(i: int)
signal use_pressed()
signal drop_pressed()
signal stash_pressed()
signal equip_pressed()
signal pouch_slot_pressed(i: int)
signal pouch_use_pressed()
signal unstash_pressed()
signal pouch_drop_pressed()
signal wear_slot_pressed(slot: String)
signal unequip_pressed()

const Palette := preload("res://ui/board_palette.gd")

const SLOT_SIZE := Vector2(42, 56)
const POUCH_SLOT_SIZE := Vector2(34, 46)
const WEAR_SLOT_SIZE := Vector2(40, 50)
# 穿戴槽空位占位字（兵器/护具/行囊）
const WEAR_LABELS := {"weapon": "兵器", "armor": "护具", "bag": "行囊"}
const WEAR_ORDER := ["weapon", "armor", "bag"]

func _ready() -> void:
	($Box/Head/UseButton as Button).pressed.connect(func(): use_pressed.emit())
	($Box/Head/DropButton as Button).pressed.connect(func(): drop_pressed.emit())
	($Box/Head/StashButton as Button).pressed.connect(func(): stash_pressed.emit())
	($Box/Head/EquipButton as Button).pressed.connect(func(): equip_pressed.emit())
	($Box/WearHead/UnequipButton as Button).pressed.connect(func(): unequip_pressed.emit())
	($Box/PouchHead/PouchUseButton as Button).pressed.connect(func(): pouch_use_pressed.emit())
	($Box/PouchHead/UnstashButton as Button).pressed.connect(func(): unstash_pressed.emit())
	($Box/PouchHead/PouchDropButton as Button).pressed.connect(func(): pouch_drop_pressed.emit())

func refresh(inventory: Array, capacity: int, selected: int, run_over: bool, selected_usable := false,
		pouch: Array = [], pouch_capacity := 2, selected_pouch := -1, pouch_selected_usable := false,
		equipped: Dictionary = {}, selected_wear := "", selected_equippable := false) -> void:
	($Box/Head/TitleLabel as Label).text = "背包 %d/%d" % [inventory.size(), capacity]
	($Box/Head/UseButton as Button).disabled = not selected_usable or run_over
	($Box/Head/DropButton as Button).disabled = selected < 0 or run_over
	($Box/Head/StashButton as Button).disabled = selected < 0 or run_over
	($Box/Head/EquipButton as Button).disabled = not selected_equippable or run_over
	($Box/WearHead/UnequipButton as Button).disabled = selected_wear.is_empty() or run_over
	($Box/PouchHead/PouchTitle as Label).text = "锦囊 %d/%d" % [pouch.size(), pouch_capacity]
	($Box/PouchHead/PouchUseButton as Button).disabled = not pouch_selected_usable or run_over
	($Box/PouchHead/UnstashButton as Button).disabled = selected_pouch < 0 or run_over
	($Box/PouchHead/PouchDropButton as Button).disabled = selected_pouch < 0 or run_over
	var grid := $Box/Grid as GridContainer
	grid.columns = mini(capacity, 15)
	# 旧槽位必须同步 free：queue_free 到帧尾才真死，本帧新旧两代同列会让
	# get_combined_minimum_size() 按双倍行数算高（操作后面板突然变大的元凶）
	for child in grid.get_children():
		child.free()
	for i in range(capacity):
		grid.add_child(_make_slot(i, inventory, selected, SLOT_SIZE, slot_pressed))
	var wear_row := $Box/WearRow as HBoxContainer
	for child in wear_row.get_children():
		child.free()
	for slot_id in WEAR_ORDER:
		wear_row.add_child(_make_wear_slot(slot_id, equipped.get(slot_id, {}), slot_id == selected_wear))
	var pouch_grid := $Box/PouchGrid as GridContainer
	pouch_grid.columns = mini(maxi(pouch_capacity, 1), 15)
	for child in pouch_grid.get_children():
		child.free()
	for i in range(pouch_capacity):
		pouch_grid.add_child(_make_slot(i, pouch, selected_pouch, POUCH_SLOT_SIZE, pouch_slot_pressed))
	# 尺寸由内容盒最小尺寸决定（按钮实际高度随主题走，手算常量会切掉锦囊行）
	size = ($Box as Container).get_combined_minimum_size() + Vector2(16, 10)  # Box 内边距 8/8/8/2
	# 锚点右下：size 设定默认保持左上不动（向下生长），把右下角钉回屏幕角
	var parent := get_parent_control()
	if parent != null:
		position = parent.size - size - Vector2(22, 12)

func _make_slot(i: int, entries: Array, selected: int, slot_size: Vector2, sig: Signal) -> Panel:
	var slot: Panel
	if i >= entries.size():
		slot = ItemSlot.make_empty(slot_size)
	else:
		slot = ItemSlot.make(entries[i], slot_size, 10, i == selected)
		slot.tooltip_text = BoardPresenters.item_entry_tooltip(entries[i])
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 延迟发信号：board 收到后会 refresh 并同步 free 槽位，同步链就是
			# 「Attempted to free a locked object」（槽还在 gui_input 发射栈上）
			sig.emit.call_deferred(i))
	return slot

# 穿戴槽：空位显示占位字（兵器/护具/行囊）；有装备显示名称＋耐久角标，点选可卸下。
func _make_wear_slot(slot_id: String, entry: Dictionary, selected: bool) -> Panel:
	var slot: Panel
	if entry.is_empty():
		slot = ItemSlot.make_empty(WEAR_SLOT_SIZE)
		var tag := Palette.plain_label(WEAR_LABELS.get(slot_id, ""), 10, Color(Palette.COLOR_INK, 0.45))
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(tag)
	else:
		slot = ItemSlot.make(entry, WEAR_SLOT_SIZE, 10, selected)
		slot.tooltip_text = BoardPresenters.item_entry_tooltip(entry)
		if entry.has("dur"):
			var dur := Palette.plain_label("耐%d" % int(entry["dur"]), 10, Palette.COLOR_INK)
			dur.position = Vector2(WEAR_SLOT_SIZE.x - 22, WEAR_SLOT_SIZE.y - 15)
			slot.add_child(dur)
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			wear_slot_pressed.emit.call_deferred(slot_id))
	return slot
