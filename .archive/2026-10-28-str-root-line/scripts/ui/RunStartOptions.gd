# 开局心法遴选（5 选 2）——基于 qi-forge 统一弹窗（QiDialogBox Control 模态，STS2 制）。
# 交互（2026-10-25 用户裁定）：点击卡面＝选中／再点取消（金圈亮灭，选满 2 锁定不顶替）；
# 卡下「详情」按钮＝弹出放大详情卡（点卡或遮罩关闭）；卡下竖版迷你卡（等比缩小，
# 绿＝心法、蓝＝术法一/二）切换三面；弹窗底部确认键＝确定入组。
extends Control

var _option_type_to_option_ids: Dictionary = {}
const MIXED_OPTION_COUNT: int = 3	# number of options to populate that have both an upside and downside
const COMPLETE_OPTION_COUNT: int = 5	# qi-forge：心法遴选展示全部 5 门（五个一行）

const QIF_XINFA_PICK_COUNT: int = 2
const QIF_DIALOG_FACTORY = preload("res://qiforge/QiDialog.gd")
const QIF_CARD_STYLE = preload("res://qiforge/QiCardStyle.gd")
const QIF_FONTS = preload("res://qiforge/QiFontBank.gd")
const QIF_GEN = preload("res://qiforge/QiForgeDataGenerator.gd")

var _picked_columns: Array[Control] = []
var _dialog: Control = null   # QiDialogBox（Control 弹窗制，勿回 AcceptDialog）
var _pick_hint_label: Label = null
var _cards_host: HBoxContainer = null
var _option_column_to_id: Dictionary = {}
var _detail_layer: Control = null

func _ready():
	QIF_FONTS.apply_default_font(get_tree().root)	# 全项目默认字体＝Noto（Godot 默认字体零 CJK）
	_build_dialog()
	_aggregate_run_start_options()
	Signals.run_started.connect(_on_run_started)
	Signals.player_killed.connect(_on_player_killed)
	Signals.run_ended.connect(_on_run_ended)

## 弹窗骨架＝统一工厂产出（原生 AcceptDialog＋标准遮罩）；内容＝提示行＋五列（卡＋迷你卡＋选择）
func _build_dialog() -> void:
	var made: Array = QIF_DIALOG_FACTORY.create(self, "备战 · 心法遴选", Vector2(1080, 600), "确认入组（0/2）")
	_dialog = made[1]
	_dialog.confirmed.connect(_on_confirm_pressed)

	var content: MarginContainer = MarginContainer.new()
	content.add_theme_constant_override("margin_left", 20)
	content.add_theme_constant_override("margin_right", 20)
	content.add_theme_constant_override("margin_top", 6)
	content.add_theme_constant_override("margin_bottom", 6)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog.add_child(content)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(column)

	_pick_hint_label = Label.new()
	_pick_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pick_hint_label.add_theme_font_override("font", QIF_FONTS.display())
	_pick_hint_label.add_theme_font_size_override("font_size", 18)
	_pick_hint_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.32))
	column.add_child(_pick_hint_label)

	_cards_host = HBoxContainer.new()
	_cards_host.add_theme_constant_override("separation", 16)
	_cards_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_cards_host)

func _aggregate_run_start_options() -> void:
	for option_type in RunStartOptionData.RUN_START_OPTION_TYPES.values():
		_option_type_to_option_ids[option_type] = [] as Array[String]
	for run_start_option_data in Global._id_to_run_start_option_data.values() as Array[RunStartOptionData]:
		_option_type_to_option_ids[run_start_option_data.run_start_option_type].append(run_start_option_data.object_id)

func populate_run_start_options() -> void:
	_picked_columns.clear()
	_option_column_to_id.clear()
	_close_column_detail()
	for child in _cards_host.get_children():
		child.queue_free()
	_update_pick_hint()

	var complete_option_ids: Array[String] = (_option_type_to_option_ids[RunStartOptionData.RUN_START_OPTION_TYPES.COMPLETE] as Array[String]).duplicate()
	var rng_run_start_options: RandomNumberGenerator = Global.player_data.get_player_rng("rng_run_start_options")
	Random.shuffle_array(rng_run_start_options, complete_option_ids)

	for i in min(COMPLETE_OPTION_COUNT, len(complete_option_ids)):
		var complete_option_id: String = complete_option_ids.pop_back()
		var complete_run_start_option_data: RunStartOptionData = Global.get_run_start_option_data(complete_option_id)
		var option_actions: Array[Dictionary] = complete_run_start_option_data.run_start_option_actions

		var option_column: Control = _create_option_column(complete_option_id, option_actions)
		_cards_host.add_child(option_column)
		_option_column_to_id[option_column] = complete_option_id

## 遴选列＝卡位（选入描边圈＋三张可切卡面）＋竖版迷你卡（切面）＋「详情」按钮
func _create_option_column(option_id: String, option_actions: Array[Dictionary]) -> Control:
	var full: Dictionary = QIF_GEN.get_xinfa_pack_full(option_id)
	var identity: String = QIF_CARD_STYLE.identity_of(option_id)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)

	var stack: Control = Control.new()
	stack.custom_minimum_size = QIF_CARD_STYLE.size_of("field") + Vector2(12.0, 12.0)
	column.add_child(stack)
	var ring: Panel = QIF_CARD_STYLE.make_pick_ring()
	# 贴卡边（不留 6px 间隙）：卡在卡位 (6,6) 起 180×230，圈线画在面板边内 4px → 正好贴住卡边
	ring.anchor_left = 0.0
	ring.anchor_top = 0.0
	ring.anchor_right = 1.0
	ring.anchor_bottom = 1.0
	ring.offset_left = 2.0
	ring.offset_top = 2.0
	ring.offset_right = -6.0
	ring.offset_bottom = -6.0
	stack.add_child(ring)

	var face_names: Array[String] = ["face_xinfa", "face_spell1", "face_spell2"]
	var faces: Array[Button] = []
	faces.append(QIF_CARD_STYLE.make_xinfa_card(
		{"id": option_id, "name": full.get("name", ""), "desc": full.get("desc", "")}, 1))
	var spells: Array = full.get("spells", [])
	var spell_suffixes: Array[String] = ["一", "二", "三", "四", "五", "六"]
	for spell_index in spells.size():
		var spell: Array = spells[spell_index]
		faces.append(QIF_CARD_STYLE.make_spell_card(
			"术法{0}".format([spell_suffixes[spell_index]]),
			int(spell[0]), str(spell[1]), 0, "", identity))
	for face_index in faces.size():
		var face: Button = faces[face_index]
		face.name = face_names[face_index]
		face.position = Vector2(6.0, 6.0)
		face.visible = face_index == 0
		face.pressed.connect(_on_face_pressed.bind(column))
		stack.add_child(face)
	column.set_meta("ring", ring)
	column.set_meta("action_data", option_actions)
	column.set_meta("xinfa_full", full)
	column.set_meta("face_index", 0)

	var minis: HBoxContainer = HBoxContainer.new()
	minis.add_theme_constant_override("separation", 7)
	minis.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(minis)
	var mini_specs: Array = [
		[QIF_CARD_STYLE.IDENTITY_COLORS.get(identity, Color(0.42, 0.42, 0.48)), "心法"],
		[QIF_CARD_STYLE.SPELL_COLOR, "术法一"],
		[QIF_CARD_STYLE.SPELL_COLOR, "术法二"],
	]
	for mini_index in mini_specs.size():
		var mini: Button = QIF_CARD_STYLE.make_face_mini(mini_specs[mini_index][0], str(mini_specs[mini_index][1]))
		mini.pressed.connect(_on_face_mini_pressed.bind(column, mini_index))
		minis.add_child(mini)
	QIF_CARD_STYLE.set_face_mini_active(minis.get_child(0), true)

	var detail_button: Button = QIF_CARD_STYLE.make_detail_button()
	detail_button.pressed.connect(_on_detail_button_pressed.bind(column))
	column.add_child(detail_button)
	column.set_meta("detail_button", detail_button)
	return column

## 迷你卡切面（不自动播放）；同步列的当前面序号
func _on_face_mini_pressed(column: Control, face_index: int) -> void:
	var stack: Control = column.get_child(0)
	var minis: HBoxContainer = column.get_child(1)
	for mini_index in minis.get_child_count():
		QIF_CARD_STYLE.set_face_mini_active(minis.get_child(mini_index), mini_index == face_index)
	var face_seen: int = 0
	for child in stack.get_children():
		if child is Button:
			child.visible = face_seen == face_index
			face_seen += 1
	column.set_meta("face_index", face_index)

## 「详情」按钮＝弹出放大详情卡（点卡或遮罩关闭）；选中状态只由卡面金圈表达，按钮永远可按
func _on_detail_button_pressed(column: Control) -> void:
	_open_column_detail(column)

## 点击卡面＝选中／再点取消；选满 2 后未选卡点击无效（先取消再改选）
func _on_face_pressed(column: Control) -> void:
	var picked_index: int = _picked_columns.find(column)
	if picked_index == -1:
		if _picked_columns.size() >= QIF_XINFA_PICK_COUNT:
			return
		_picked_columns.append(column)
		(column.get_meta("ring") as Panel).visible = true
	else:
		_picked_columns.remove_at(picked_index)
		(column.get_meta("ring") as Panel).visible = false
	_update_pick_hint()

#region 详情卡（「详情」按钮弹出放大卡，点卡或遮罩关闭）
func _open_column_detail(column: Control) -> void:
	_close_column_detail()
	var full: Dictionary = column.get_meta("xinfa_full")
	var identity: String = QIF_CARD_STYLE.identity_of(str(full.get("id", "")))
	var face_index: int = int(column.get_meta("face_index"))
	var detail_card: Button
	if face_index == 0:
		detail_card = QIF_CARD_STYLE.make_xinfa_detail_card(
			{"id": full.get("id", ""), "name": full.get("name", ""), "desc": full.get("desc", "")},
			1, str(full.get("up1", "")), str(full.get("up2", "")))
	else:
		var spells: Array = full.get("spells", [])
		var spell: Array = spells[face_index - 1] if face_index - 1 < spells.size() else [0, "", "", ""]
		var suffix: String = "一二三四五六".substr(face_index - 1, 1)
		detail_card = QIF_CARD_STYLE.make_spell_detail_card(
			"术法{0}".format([suffix]), int(spell[0]), str(spell[1]),
			str(spell[2]), str(spell[3]), 0, "", identity)
	detail_card.pressed.connect(_close_column_detail)
	_detail_layer = QIF_CARD_STYLE.make_detail_layer(detail_card)
	_dialog.add_child(_detail_layer)

func _close_column_detail() -> void:
	if _detail_layer != null:
		_detail_layer.queue_free()
		_detail_layer = null
#endregion

func _on_confirm_pressed() -> void:
	if _picked_columns.size() < QIF_XINFA_PICK_COUNT:
		return
	_close_column_detail()

	# 已选心法（生成器全量）传给备战层展示
	var chosen_xinfa: Array = []
	for picked_column: Control in _picked_columns:
		var full: Dictionary = QIF_GEN.get_xinfa_pack_full(str(_option_column_to_id.get(picked_column, "")))
		chosen_xinfa.append({
			"id": full.get("id", ""), "name": full.get("name", ""),
			"desc": full.get("desc", ""), "bundle": full.get("bundle", []),
		})
	get_node("%QiRunFlow").set_chosen_xinfa(chosen_xinfa)

	var player: Player = Global.get_player()
	var merged_action_data: Array[Dictionary] = []
	for picked_column: Control in _picked_columns:
		merged_action_data.append_array(picked_column.get_meta("action_data"))
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, player, false, false)
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [player], merged_action_data, null)
	ActionHandler.add_actions(generated_actions)
	_picked_columns.clear()
	visible = false
	_dialog.hide()

	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended

	# 遴选完毕交备战层（小丑牌式流程，无地图）
	get_node("%QiRunFlow").show_prep()

func _update_pick_hint() -> void:
	var picked_count: int = _picked_columns.size()
	if _pick_hint_label != null:
		var remaining: int = QIF_XINFA_PICK_COUNT - picked_count
		_pick_hint_label.text = "点卡面选中两门 · 迷你卡切面 · 「详情」放大细看" if remaining > 0 else "已选满两门，点「确认入组」生效"
	var ok_button: Button = _dialog.get_ok_button() if _dialog != null else null
	if ok_button != null:
		ok_button.text = "确认入组（{0}/{1}）".format([picked_count, QIF_XINFA_PICK_COUNT])
		ok_button.disabled = picked_count < QIF_XINFA_PICK_COUNT

func _on_run_started():
	visible = true
	populate_run_start_options()
	_dialog.popup_centered(Vector2i(1080, 600))
	_dialog.size = Vector2i(1080, 600)	# 无头/最小尺寸钳制兜底，保证按设计尺寸弹
	QIF_DIALOG_FACTORY.restyle_ok.call_deferred(_dialog)	# popup 的延迟重整会清确认键最小尺寸，须排其后重设

func _on_run_ended():
	_close_column_detail()
	visible = false
	_dialog.hide()

func _on_player_killed(_player: Player) -> void:
	_close_column_detail()
	visible = false
	_dialog.hide()
