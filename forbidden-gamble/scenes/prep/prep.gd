extends Control

# 备战页（C-027）：标题/据点「出发」进入，一次走完出征三件事——
# 一、选禁地（v1 只有青锋剑宗，做成卡片列表占位）；
# 二、配置栏：穿戴三槽（兵器/护具/行囊）——**点击装备即穿/换（旧件回仓库），
#    点击身上即卸下**；功法/心法占位（随身固定，据点「搭配·构筑」与「参悟」调整）；
# 三、装载：仓库消耗品选中后「带走→背包／贴身→锦囊」（上限＝行囊格数/局外升级格数）；
#    背包/锦囊里的东西**点击即整堆放回仓库**。装配（穿戴＋购物车）持续保存在 meta 档，
#    退出/重进原样恢复；「出发」才把载荷带走并清车。
# 「出发」把 ExpeditionPrep.payload() 交给 ExpeditionSession.start_run 进版图。
# 带不带、穿什么全由玩家决定——没有保底配发，空手开局是合法选择。

const Palette := preload("res://ui/board_palette.gd")

const WEAR_SLOT := Vector2(64, 84)
const WH_SLOT := Vector2(56, 74)
const CART_SLOT := Vector2(40, 54)
const POUCH_SLOT := Vector2(36, 48)
const WEAR_LABELS := {"weapon": "兵器", "armor": "护具", "bag": "行囊"}
const WEAR_ORDER := ["weapon", "armor", "bag"]

var prep: ExpeditionPrep
# 选中态（只服务消耗品装载）：area ∈ ""/"warehouse"；sel_index 为仓库下标
var sel_area := ""
var sel_index := -1

var _note_label: Label
var _wear_row: HBoxContainer
var _wh_grid: GridContainer
var _wh_title: Label
var _cart_grid: GridContainer
var _cart_title: Label
var _pouch_grid: GridContainer
var _pouch_title: Label
var _btn_take: Button
var _btn_pouch: Button

func _ready() -> void:
	prep = ExpeditionPrep.new()
	prep.setup(MetaArchive, DataRepo.config())
	_build_ui()
	_refresh()
	await PreviewCapture.maybe_capture(self)

# ---------- 静态骨架 ----------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Palette.COLOR_CARD
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(_build_map_panel())
	left.add_child(_build_config_panel())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	body.add_child(right)
	right.add_child(_build_warehouse_panel())
	right.add_child(_build_carry_panel())
	right.add_child(_build_depart_bar())

func _build_header() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var title := Palette.brush_label("出征备战", 30, Palette.COLOR_INK)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(title)
	_note_label = Palette.plain_label("", 15, Color("#8A6D1A"))
	_note_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_note_label.clip_text = true
	bar.add_child(_note_label)
	var back := Button.new()
	back.text = "返回据点"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.STRONGHOLD))
	bar.add_child(back)
	return bar

func _build_map_panel() -> Control:
	var panel := _panel()
	var vbox: VBoxContainer = panel.get_child(0).get_child(0)
	vbox.add_child(_section_title("一、选禁地"))
	var card := _map_card(str(DataRepo.config().get("name", "青锋剑宗")), "撤离带回物资与随身兵甲", true)
	vbox.add_child(card)
	var locked := _map_card("更多禁地", "敬请期待", false)
	vbox.add_child(locked)
	return panel

func _build_config_panel() -> Control:
	var panel := _panel()
	var vbox: VBoxContainer = panel.get_child(0).get_child(0)
	vbox.add_child(_section_title("二、配置"))
	_wear_row = HBoxContainer.new()
	_wear_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_wear_row)
	vbox.add_child(Palette.plain_label("装备点击即穿/换（旧件回仓库），身上点击即卸下", 12, Color(Palette.COLOR_INK, 0.5)))
	vbox.add_child(_sep())
	vbox.add_child(_section_title("功法（随身固定）"))
	vbox.add_child(Palette.plain_label("、".join(_technique_names()) + "（调整随秘籍系统开放）", 14, Palette.COLOR_INK))
	vbox.add_child(_section_title("心法"))
	var xinfa_list: Array = MetaArchive.loadout.get("xinfa", [])
	if xinfa_list.is_empty():
		vbox.add_child(Palette.plain_label("未装备（据点「搭配·构筑」调整）", 14, Color(Palette.COLOR_INK, 0.6)))
	else:
		vbox.add_child(Palette.plain_label("，".join(xinfa_list) + "（据点「搭配·构筑」调整）", 14, Palette.COLOR_INK))
	return panel

func _build_warehouse_panel() -> Control:
	var panel := _panel()
	var vbox: VBoxContainer = panel.get_child(0).get_child(0)
	var head := HBoxContainer.new()
	_wh_title = _section_title("三、据点仓库")
	head.add_child(_wh_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	vbox.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_wh_grid = GridContainer.new()
	_wh_grid.columns = 12
	_wh_grid.add_theme_constant_override("h_separation", 6)
	_wh_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_wh_grid)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	_btn_take = _action_button("带走 → 背包", _on_take)
	_btn_pouch = _action_button("贴身 → 锦囊", _on_take_pouch)
	actions.add_child(_btn_take)
	actions.add_child(_btn_pouch)
	vbox.add_child(actions)
	vbox.add_child(Palette.plain_label("装备点击即穿；消耗品选中后带走", 12, Color(Palette.COLOR_INK, 0.5)))
	return panel

func _build_carry_panel() -> Control:
	var panel := _panel()
	var vbox: VBoxContainer = panel.get_child(0).get_child(0)
	_cart_title = _section_title("出征携带 · 背包 0/0")
	vbox.add_child(_cart_title)
	_cart_grid = GridContainer.new()
	_cart_grid.columns = 13
	_cart_grid.add_theme_constant_override("h_separation", 4)
	_cart_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_cart_grid)
	vbox.add_child(Palette.plain_label("带错了？点击背包/锦囊格整堆放回仓库", 12, Color(Palette.COLOR_INK, 0.5)))
	vbox.add_child(_sep())
	_pouch_title = _section_title("贴身锦囊 0/0（死亡保底；格数随据点升级）")
	vbox.add_child(_pouch_title)
	_pouch_grid = GridContainer.new()
	_pouch_grid.columns = 3
	_pouch_grid.add_theme_constant_override("h_separation", 4)
	_pouch_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_pouch_grid)
	return panel

func _build_depart_bar() -> Control:
	var bar := HBoxContainer.new()
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var depart := Button.new()
	depart.text = "出 发"
	depart.focus_mode = Control.FOCUS_NONE
	depart.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD
	style.border_color = Palette.COLOR_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	depart.add_theme_stylebox_override("normal", style)
	depart.pressed.connect(_on_depart)
	bar.add_child(depart)
	return bar

# ---------- 动态刷新（唯一重画入口） ----------

func _refresh() -> void:
	_note_label.text = prep.last_note
	_wh_title.text = "三、据点仓库 · 总价值 %d" % prep.warehouse_value()
	for child in _wh_grid.get_children():
		child.free()
	if prep.warehouse().is_empty():
		_wh_grid.add_child(Palette.plain_label("（空空如也——撤离带回的物资都存这里）", 13, Color(Palette.COLOR_INK, 0.5)))
	else:
		for i in range(prep.warehouse().size()):
			_wh_grid.add_child(_make_wh_slot(i))
	for child in _wear_row.get_children():
		child.free()
	for slot_id in WEAR_ORDER:
		_wear_row.add_child(_make_wear_slot(slot_id, prep.equipped().get(slot_id, {})))
	var cap := prep.backpack_capacity()
	_cart_title.text = "出征携带 · 背包 %d/%d" % [prep.backpack.size(), cap]
	_cart_grid.columns = maxi(cap, 1)
	for child in _cart_grid.get_children():
		child.free()
	for i in range(cap):
		_cart_grid.add_child(_make_carry_slot(i, prep.backpack, "cart", CART_SLOT))
	_pouch_title.text = "贴身锦囊 %d/%d（死亡保底；格数随据点升级）" % [prep.pouch.size(), prep.pouch_capacity()]
	for child in _pouch_grid.get_children():
		child.free()
	for i in range(prep.pouch_capacity()):
		_pouch_grid.add_child(_make_carry_slot(i, prep.pouch, "pouch", POUCH_SLOT))
	_refresh_buttons()

func _refresh_buttons() -> void:
	var wh_sel := sel_area == "warehouse" and sel_index >= 0 and sel_index < prep.warehouse().size()
	var entry: Dictionary = prep.warehouse()[sel_index] if wh_sel else {}
	_btn_take.disabled = not wh_sel
	_btn_pouch.disabled = not wh_sel or BoardState.POUCH_BLOCKED_TYPES.has(str(entry.get("type", "")))

# ---------- 动作 ----------

func _act(result: bool) -> void:
	if result:
		sel_index = -1
	_refresh()

func _on_take() -> void:
	_act(prep.take(sel_index))

func _on_take_pouch() -> void:
	_act(prep.take_pouch(sel_index))

# 仓库格点击：装备＝直接穿上/换下（旧件回仓库）；其他＝选中供带走按钮用
func _on_wh_slot_click(i: int) -> void:
	if i < 0 or i >= prep.warehouse().size():
		return
	if _slot_for(prep.warehouse()[i]).is_empty():
		_select("warehouse", i)
	else:
		_act(prep.wear(i))

# 身上槽点击：有件即卸下回仓库
func _on_wear_slot_click(slot_id: String) -> void:
	if not (prep.equipped().get(slot_id, {}) as Dictionary).is_empty():
		_act(prep.unwear(slot_id))

# 背包/锦囊格点击：整堆放回仓库
func _on_cart_slot_click(i: int) -> void:
	if i >= 0 and i < prep.backpack.size():
		_act(prep.stash(i))

func _on_pouch_slot_click(i: int) -> void:
	if i >= 0 and i < prep.pouch.size():
		_act(prep.stash_pouch(i))

func _on_depart() -> void:
	ExpeditionSession.end_run()
	ExpeditionSession.start_run(randi(), prep.payload())
	ExpeditionSession.save_game()
	# 远征档已落盘，购物车才正式清空——中途崩溃时车还在 meta 档里，物资不丢
	prep.consume_cart()
	get_tree().change_scene_to_file(SceneRoutes.BOARD)

# ---------- 小件工厂 ----------

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.4)
	style.border_color = Color(Palette.COLOR_INK, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	return panel

func _section_title(text: String) -> Label:
	return Palette.brush_label(text, 18, Palette.COLOR_INK)

func _action_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(handler)
	return button

func _sep() -> Control:
	var line := ColorRect.new()
	line.color = Color(Palette.COLOR_INK, 0.18)
	line.custom_minimum_size = Vector2(0, 1)
	return line

func _map_card(title_text: String, sub_text: String, enabled: bool) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD if enabled else Color(Palette.COLOR_INK, 0.04)
	style.border_color = Palette.COLOR_GOLD if enabled else Color(Palette.COLOR_INK, 0.25)
	style.set_border_width_all(2 if enabled else 1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	var title := Palette.brush_label(title_text, 20, Palette.COLOR_INK if enabled else Color(Palette.COLOR_INK, 0.4))
	vbox.add_child(title)
	vbox.add_child(Palette.plain_label(sub_text, 12, Color(Palette.COLOR_INK, 0.55)))
	return panel

func _make_wh_slot(i: int) -> Panel:
	var slot := _slot_with_badge(prep.warehouse()[i], WH_SLOT, sel_area == "warehouse" and sel_index == i)
	_click(slot, func(): _on_wh_slot_click(i))
	return slot

func _make_wear_slot(slot_id: String, entry: Dictionary) -> Panel:
	var slot: Panel
	if entry.is_empty():
		slot = ItemSlot.make_empty(WEAR_SLOT)
		var tag := Palette.plain_label(WEAR_LABELS.get(slot_id, ""), 12, Color(Palette.COLOR_INK, 0.45))
		tag.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(tag)
	else:
		slot = _slot_with_badge(entry, WEAR_SLOT, false)
		_click(slot, func(): _on_wear_slot_click(slot_id))
	return slot

# 背包/锦囊格：空位不可点；有东西点击即整堆放回仓库
func _make_carry_slot(i: int, entries: Array, area: String, slot_size: Vector2) -> Panel:
	var slot: Panel
	if i >= entries.size():
		slot = ItemSlot.make_empty(slot_size)
	elif area == "cart":
		slot = _slot_with_badge(entries[i], slot_size, false)
		_click(slot, func(): _on_cart_slot_click(i))
	else:
		slot = _slot_with_badge(entries[i], slot_size, false)
		_click(slot, func(): _on_pouch_slot_click(i))
	return slot

# 物品格：名称＋数量角标（ItemSlot.make 已含）＋装备耐久角标＋悬停详情。
func _slot_with_badge(entry: Dictionary, slot_size: Vector2, selected: bool) -> Panel:
	var slot := ItemSlot.make(entry, slot_size, 10, selected)
	slot.tooltip_text = BoardPresenters.item_entry_tooltip(entry)
	if entry.has("dur"):
		var dur := Palette.plain_label("耐%d" % int(entry["dur"]), 9, Palette.COLOR_INK)
		dur.position = Vector2(2, 2)
		slot.add_child(dur)
	return slot

func _click(slot: Control, handler: Callable) -> void:
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# 延迟到信号栈退完再刷新——_refresh 会 free 掉正在发 gui_input 的槽，
			# 同步调用就是「Attempted to free a locked object」
			handler.call_deferred())

func _select(area: String, index: int) -> void:
	if sel_area == area and sel_index == index:
		sel_area = ""
		sel_index = -1
	else:
		sel_area = area
		sel_index = index
	_refresh()

func _slot_for(entry: Dictionary) -> String:
	var type_id := str(entry.get("type", ""))
	for slot_id in BoardState.EQUIP_SLOTS:
		if BoardState.EQUIP_SLOT_TYPES[slot_id] == type_id:
			return slot_id
	return ""

func _technique_names() -> Array:
	var names: Array = []
	for tech_id in DataRepo.player_def().get("techniques", []):
		names.append(str(tech_id))
	return names
