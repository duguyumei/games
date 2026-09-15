extends Control

## 演武场（战斗工作台）：择敌 → 卡槽点选构筑（功法六/内功五/本命牌组）→ 开战。
## 槽位与选卡弹层全部由编辑器模板实例化；选择写入 DojoConfig，battle.gd 优先读取。

const ATTRS := ["风", "火", "山"]
const ATTR_ROW_NAMES := ["FengRow", "HuoRow", "ShanRow"]
const CELL_SCENE := preload("res://ui/qi_count_cell.tscn")
const TECH_CARD_SCENE := preload("res://ui/technique_card.tscn")
const XINFA_CARD_SCENE := preload("res://ui/xinfa_card.tscn")
const EMPTY_SLOT_SCENE := preload("res://ui/technique_empty_slot.tscn")
const PICKER_SCENE := preload("res://ui/card_picker.tscn")

var _enemies: Dictionary = {}
var _technique_ids: Array = []
var _xinfa_ids: Array = []
var _cells: Dictionary = {}
var _tech_sel: Array[String] = ["", "", "", "", "", ""]
var _xinfa_sel: Array[String] = ["", "", "", "", ""]
var _picker: CardPicker
# 敌情弹窗宿主（对手卡详情页：点敌卡弹出）
var _enemy_popup: PopupHost

@onready var enemy_pick: OptionButton = $Margin/VBox/Body/Left/EnemyPick
@onready var enemy_card_slot: Control = $Margin/VBox/Body/Left/EnemyCardSlot
@onready var tech_slots: HFlowContainer = $Margin/VBox/Body/RightScroll/Right/TechSlots
@onready var xinfa_slots: HFlowContainer = $Margin/VBox/Body/RightScroll/Right/XinfaSlots
@onready var deck_total: Label = $Margin/VBox/Body/RightScroll/Right/DeckTotal
@onready var start_button: Button = $Margin/VBox/BottomRow/StartButton


func _ready() -> void:
	_load_data()
	_build_enemy_pick()
	_build_qi_cells()
	_picker = PICKER_SCENE.instantiate()
	add_child(_picker)
	_picker.picked.connect(_on_picked)
	_enemy_popup = PopupHost.new()
	add_child(_enemy_popup)
	var player: Dictionary = DataRepo.load_json(DataRepo.PLAYER_PATH)
	var dt: Array = player.get("techniques", [])
	for i in range(mini(6, dt.size())):
		_tech_sel[i] = str(dt[i])
	var dx: Array = player.get("xinfa", [])
	for i in range(mini(5, dx.size())):
		_xinfa_sel[i] = str(dx[i])
	_render_tech_slots()
	_render_xinfa_slots()
	start_button.pressed.connect(_on_start)
	($Margin/VBox/BottomRow/MjButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(SceneRoutes.MJ_BATTLE))
	($Margin/VBox/BottomRow/HomeButton as Button).pressed.connect(
		func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))


func _load_data() -> void:
	_enemies = DataRepo.load_json(DataRepo.ENEMIES_PATH)
	_technique_ids = (DataRepo.load_json(DataRepo.TECHNIQUES_PATH) as Dictionary).keys()
	_xinfa_ids = (DataRepo.load_json(DataRepo.XINFA_PATH) as Dictionary).keys()


func _build_enemy_pick() -> void:
	for id in _enemies.keys():
		var e: Dictionary = _enemies[id]
		enemy_pick.add_item("%s（气血 %d）" % [str(e.get("name", id)), int(e.get("max_hp", 0))])
		enemy_pick.set_item_metadata(enemy_pick.item_count - 1, str(id))
	enemy_pick.item_selected.connect(_on_enemy_selected)
	enemy_pick.select(0)
	_on_enemy_selected(0)


# 敌方信息（敌方系统 v2，同核对手卡）：敌人也是卡牌——卡面一句概览，点击弹出
# 对手卡详情页（功法表卡组＋出招梯＋钩子＋真气构成＋换手策略，全明码）。
func _on_enemy_selected(_index: int) -> void:
	var id := str(enemy_pick.get_item_metadata(enemy_pick.selected))
	var e: Dictionary = _enemies.get(id, {})
	for child in enemy_card_slot.get_children():
		child.queue_free()
	var card := XINFA_CARD_SCENE.instantiate() as XinfaCard
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var techs := _enemy_techniques(e)
	var school := str(TechniqueResolver.data_for(techs[0]).get("school", "通用")) if not techs.is_empty() else "通用"
	card.setup(str(e.get("name", id)), 1, school,
		"功法 %d 门：%s\n点击查看对手卡（出招梯／应·能截什么／气海）" % [techs.size(), "、".join(techs)])
	# 敌卡不显示"× 阶"——阶别条改显气血
	(card.get_node("Margin/VBox/TierLabel") as Label).text = "气血 %d · %s" % [int(e.get("max_hp", 0)), school]
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_open_enemy_detail(e))
	enemy_card_slot.add_child(card)


# 敌方功法表（梯级声明序，去重；截牌选功法＝声明序第一个可付的）
func _enemy_techniques(e: Dictionary) -> Array[String]:
	var techs: Array[String] = []
	for rule in e.get("ladder", []):
		var technique := str((rule as Dictionary).get("technique", ""))
		if technique.is_empty() or technique == "架势" or technique == "换牌":
			continue
		if not techs.has(technique):
			techs.append(technique)
	return techs


# 对手卡详情页：功法表（真功法卡）＋出招梯＋钩子明码＋真气构成＋换手策略。
func _open_enemy_detail(e: Dictionary) -> void:
	var id := str(enemy_pick.get_item_metadata(enemy_pick.selected))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.949, 0.91, 0.835)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.169, 0.141, 0.11)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", sb)
	# 内容可能长（功法卡组＋梯＋钩子）——限高走滚动，居中弹窗永不出屏
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	var title := _detail_label("%s ｜ 气血 %d ｜ 换手：%s" % [
		str(e.get("name", id)), int(e.get("max_hp", 0)),
		{"all": "全换", "low_value": "弃低值", "high_value": "弃高值", "singletons": "弃孤张"}.get(
			str(e.get("swap_policy", "all")), "全换")], 19)
	box.add_child(title)
	box.add_child(_detail_label("主场气海（双方共吸）：%s" % _enemy_qi_text(e), 14))
	box.add_child(_detail_label("起手丹田：%s" % _enemy_hand_text(e), 14))
	box.add_child(_detail_label("功法表", 16))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("separation", 8)
	for technique in _enemy_techniques(e):
		var card := TECH_CARD_SCENE.instantiate()
		card.set_card(str(technique), TechniqueResolver.effect_summary(str(technique)), _tech_level(str(technique)))
		flow.add_child(card)
	box.add_child(flow)
	var ladder_label := _detail_label("出招梯：%s" % EnemyBrain.new(e).ladder_overview(), 14)
	ladder_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	ladder_label.custom_minimum_size = Vector2(532, 0)
	box.add_child(ladder_label)
	box.add_child(_detail_label("应·它能截什么（按起手活算，战斗中随其手牌与冷却实时变）：%s" % _enemy_threat_text(e), 14))
	var close_hint := _detail_label("（点击弹窗外任意处关闭）", 12)
	close_hint.modulate = Color(0.4, 0.36, 0.3)
	box.add_child(close_hint)
	_enemy_popup.open_centered(panel)


func _detail_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.15, 0.12, 0.09))
	return label


# 应读数（按 authored 起手活算）：你架势弃出这些牌会被它截下当场轰出。
func _enemy_threat_text(e: Dictionary) -> String:
	var probe := FighterState.new("probe", str(e.get("name", "")), 1)
	EncounterLoader.fill_enemy_body(probe, e)
	var threats := CombatState.claim_threats_for(probe)
	if threats.is_empty():
		return "暂无（起手搭子不齐或功法不匹配）——弃牌安全"
	var parts: Array[String] = []
	for threat in threats:
		parts.append("%s%s%d" % [str(threat.get("claim", "")), str(threat.get("attribute", "")), int(threat.get("value", 0))])
	return "；".join(parts)


# 主场气海汇总：deck 配置按属性×数值聚合（"风 3×2 4×2 ｜ …"）。
func _enemy_qi_text(e: Dictionary) -> String:
	var lines: Array[String] = []
	var sea: Dictionary = e.get("deck", {})
	for attribute in ATTRS:
		if not sea.has(attribute):
			continue
		var parts: Array[String] = []
		var values: Dictionary = sea[attribute]
		for value in range(QiCard.VALUE_MIN, QiCard.VALUE_MAX + 1):
			if int(values.get(str(value), 0)) > 0:
				parts.append("%d×%d" % [value, int(values[str(value)])])
		if not parts.is_empty():
			lines.append("%s %s" % [attribute, " ".join(parts)])
	return " ｜ ".join(lines)


# 起手丹田：hand 简写串直接拼（"山4、山4、风3"）。
func _enemy_hand_text(e: Dictionary) -> String:
	var parts: Array[String] = []
	for token in e.get("hand", []):
		parts.append(str(token))
	return "、".join(parts)



# ---------- 功法六槽 / 内功五槽：卡槽点选（弹窗标注当前槽；选已装项＝换位，一门不占两槽） ----------

func _render_tech_slots() -> void:
	_clear_slots(tech_slots)
	for i in range(6):
		var sel := _tech_sel[i]
		if sel.is_empty():
			var empty := EMPTY_SLOT_SCENE.instantiate() as Control
			empty.custom_minimum_size = Vector2(150, 150)
			empty.size = Vector2(150, 150)
			empty.mouse_filter = Control.MOUSE_FILTER_STOP  # 模板默认忽略鼠标，空位槽必须可点
			_bind_slot_click(empty, "tech", i)
			tech_slots.add_child(empty)
		else:
			var card := TECH_CARD_SCENE.instantiate()
			card.set_card(sel, TechniqueResolver.effect_summary(sel), _tech_level(sel))
			_bind_slot_click(card, "tech", i)
			tech_slots.add_child(card)


func _render_xinfa_slots() -> void:
	_clear_slots(xinfa_slots)
	for i in range(5):
		var sel := _xinfa_sel[i]
		var card := XINFA_CARD_SCENE.instantiate()
		if sel.is_empty():
			card.setup("（空）", 0, "点击选择", "点此槽挑一门内功")
			card.modulate = Color(0.75, 0.73, 0.68, 1)
		else:
			var x: Dictionary = (DataRepo.load_json(DataRepo.XINFA_PATH) as Dictionary).get(sel, {})
			card.setup(sel, int(x.get("tier", 1)), str(x.get("school", "—")), str(x.get("desc", "")))
		_bind_slot_click(card, "xinfa", i)
		xinfa_slots.add_child(card)


func _clear_slots(row: Node) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _bind_slot_click(card: Control, kind: String, index: int) -> void:
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open_picker(kind, index))


func _open_picker(kind: String, index: int) -> void:
	var entries: Array = []
	if kind == "tech":
		for tid in _technique_ids:
			var card := TECH_CARD_SCENE.instantiate()
			card.set_card(str(tid), TechniqueResolver.effect_summary(str(tid)), _tech_level(str(tid)))
			_mark_picker_card(card, kind, index, str(tid))
			entries.append({"card": card, "value": {"kind": "tech", "index": index, "id": str(tid)}})
		var empty_entry := EMPTY_SLOT_SCENE.instantiate() as Control
		empty_entry.custom_minimum_size = Vector2(150, 150)
		entries.append({"card": empty_entry, "value": {"kind": "tech", "index": index, "id": ""}})
		_picker.open("功法 · 第 %d 槽" % (index + 1), entries)
	else:
		for xid in _xinfa_ids:
			var x: Dictionary = (DataRepo.load_json(DataRepo.XINFA_PATH) as Dictionary).get(xid, {})
			var card := XINFA_CARD_SCENE.instantiate()
			card.setup(str(xid), int(x.get("tier", 1)), str(x.get("school", "—")), str(x.get("desc", "")))
			_mark_picker_card(card, kind, index, str(xid))
			entries.append({"card": card, "value": {"kind": "xinfa", "index": index, "id": str(xid)}})
		var blank := XINFA_CARD_SCENE.instantiate()
		blank.setup("（空）", 0, "留空", "此槽不挂内功")
		blank.modulate = Color(0.75, 0.73, 0.68, 1)
		entries.append({"card": blank, "value": {"kind": "xinfa", "index": index, "id": ""}})
		_picker.open("内功 · 第 %d 槽" % (index + 1), entries)


# 弹窗标注槽位现状：本槽已装的＝金签"当前"（功法卡另上金边）；装在他槽的＝"第N槽"签＋换位提示。
# 等级色边框不是选中态——没这层标注时唯一异色的卡（如等级2绿边）会被误读成"已选中"。
func _mark_picker_card(card: Control, kind: String, index: int, id: String) -> void:
	var sel: Array = _tech_sel if kind == "tech" else _xinfa_sel
	var at := sel.find(id)
	if at == index:
		_corner_tag(card, "当前", Color(0.78, 0.58, 0.12))
		card.tooltip_text = "本槽当前选择"
		if card is TechniqueCard:
			card.set_state(TechniqueCard.CardState.SATISFIED)
	elif at >= 0:
		_corner_tag(card, "第%d槽" % (at + 1), Color(0.35, 0.30, 0.24))
		card.tooltip_text = "已装第 %d 槽 · 点选即互换位置" % (at + 1)


func _corner_tag(card: Control, text: String, color: Color) -> void:
	var tag := Label.new()
	tag.text = text
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", color)
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -44
	tag.offset_right = -4
	tag.offset_top = 3
	tag.offset_bottom = 20
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tag)


func _on_picked(value) -> void:
	var v: Dictionary = value
	var kind := str(v.get("kind", ""))
	var index := int(v.get("index", 0))
	var id := str(v.get("id", ""))
	var sel: Array = _tech_sel if kind == "tech" else _xinfa_sel
	if not id.is_empty():
		# 一门只占一槽：选了已装在他槽的＝两槽互换（本槽旧项填回原槽；本槽空则原槽清空）
		var old := sel.find(id)
		if old >= 0 and old != index:
			sel[old] = sel[index]
	sel[index] = id
	if kind == "tech":
		_render_tech_slots()
	else:
		_render_xinfa_slots()


func _tech_level(tid: String) -> int:
	var t: Dictionary = (DataRepo.load_json(DataRepo.TECHNIQUES_PATH) as Dictionary).get(tid, {})
	return int(t.get("level", 1))


# ---------- 真气 ----------

# 数值域 2–8（真气语法 v2）：4 属性 × 7 数值网格
const VALUES := [2, 3, 4, 5, 6, 7, 8]

func _build_qi_cells() -> void:
	var player: Dictionary = DataRepo.load_json(DataRepo.PLAYER_PATH)
	var counts: Dictionary = {}
	for c in player.get("deck", []):
		var key := "%s%d" % [str(c.get("attribute")), int(c.get("value", 3))]
		counts[key] = int(counts.get(key, 0)) + 1
	for attr_i in range(ATTRS.size()):
		var row: HBoxContainer = get_node("Margin/VBox/Body/RightScroll/Right/" + ATTR_ROW_NAMES[attr_i])
		var head := Label.new()
		head.text = ATTRS[attr_i]
		head.add_theme_font_size_override("font_size", 18)
		head.custom_minimum_size = Vector2(28, 0)
		row.add_child(head)
		for value in VALUES:
			var cell := CELL_SCENE.instantiate() as QiCountCell
			cell.setup(value, int(counts.get("%s%d" % [ATTRS[attr_i], value], 0)))
			cell.count_changed.connect(_refresh_deck_total)
			row.add_child(cell)
			_cells["%s%d" % [ATTRS[attr_i], value]] = cell
	_refresh_deck_total()


func _refresh_deck_total() -> void:
	deck_total.text = "本命合计：%d 张（开局洗抽 8）" % _deck_total()


func _deck_total() -> int:
	var total := 0
	for cell in _cells.values():
		total += (cell as QiCountCell).count
	return total


func _on_start() -> void:
	DojoConfig.active = true
	DojoConfig.enemy_id = str(enemy_pick.get_item_metadata(enemy_pick.selected))
	DojoConfig.techniques = []
	for sel in _tech_sel:
		if not sel.is_empty():
			DojoConfig.techniques.append(sel)
	DojoConfig.xinfa = []
	for sel in _xinfa_sel:
		if not sel.is_empty():
			DojoConfig.xinfa.append(sel)
	DojoConfig.deck = []
	for key in _cells.keys():
		var cell: QiCountCell = _cells[key]
		for n in range(cell.count):
			DojoConfig.deck.append({
				"id": "dojo_%s_%d" % [key, n],
				"attribute": str(key).left(1),
				"value": cell.value,
			})
	get_tree().change_scene_to_file(SceneRoutes.BATTLE)
