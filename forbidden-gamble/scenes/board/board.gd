extends Control

# 牌阵探索场景（C-028 明牌网格 × D-059 节点制两档视图）——编排层。
# 组件化：HUD（顶栏/日志/背包，board.tscn 内实例）、当前地块面板（ui/board_tile）、
# 大地图节点印（ui/map_node_mark）与路网层（ui/map_edges）、两档吸附视图（ui/map_view，
# 大地图↔当前地块，无连续缩放）、终态结算（BoardOutcomeOverlay）、顶栏弹窗（PopupHost）、
# 容器弹窗（ContainerPopup，D-028 弹窗翻牌）各归组件。
# 本脚本只做编排：刷新、连线、动作执行、袭击/连坐的战斗编排（C-028：每次玩家动作后
# 查准备态满表敌与迫近满的镇物，被袭击＝敌方先手；连坐组逐场 1v1 连战）。
# 规则全走 BoardState/ExpeditionSession，本层不做判定。构筑面板为占位。

const Palette := preload("res://ui/board_palette.gd")
const TileScene := preload("res://ui/board_tile.tscn")
const MapNodeMark := preload("res://ui/map_node_mark.gd")
const MAP_TEXTURE := preload("res://assets/bg/qingfeng_map.png")

const MAX_LOG_LINES := 100
const SFX_DIR := "res://assets/sfx/"

var board: BoardState
var view := MapView.new()
var outcome_overlay := BoardOutcomeOverlay.new()
var container_popup := ContainerPopup.new()
var _last_hero := Vector2i(9999, 9999)
var ui_layer: Control
var log_lines: Array[String] = []
var selected_inv := -1
var selected_pouch := -1
var selected_wear := ""
var _confirm_extract := false
# 顶栏弹窗（设置/构筑，互斥；PopupHost 管定位/点外关闭/ESC）
var _popup_host: PopupHost
var _popup_kind := ""  # "" / "settings" / "build"
var _last_alert_level := 0
var _outcome_sound_played := false
var _animate_focus := false
# 两档切换按钮（屏幕固定，ui_layer 会被刷新清空所以挂场景根）
var _toggle_btn: Button
# 舆图背景（Continent 世界层；_refresh 清场时豁免）
var _map_backdrop: TextureRect

# 场景组件（自定义方法经信号/动态调用，保持 Variant 类型）
@onready var table: ColorRect = $Table
@onready var continent: Control = $Table/Continent
@onready var top_bar = $TopBar
@onready var log_view = $LogView
@onready var backpack = $BackpackBar

func _ready() -> void:
	top_bar.build_pressed.connect(_on_build_pressed)
	top_bar.settings_pressed.connect(_on_settings_pressed)
	backpack.slot_pressed.connect(_on_inv_slot)
	backpack.use_pressed.connect(_on_use_selected)
	backpack.drop_pressed.connect(_on_drop_selected)
	backpack.stash_pressed.connect(_on_stash_selected)
	backpack.pouch_slot_pressed.connect(_on_pouch_slot)
	backpack.pouch_use_pressed.connect(_on_pouch_use_selected)
	backpack.unstash_pressed.connect(_on_unstash_selected)
	backpack.pouch_drop_pressed.connect(_on_pouch_drop_selected)
	backpack.equip_pressed.connect(_on_equip_selected)
	backpack.wear_slot_pressed.connect(_on_wear_slot)
	backpack.unequip_pressed.connect(_on_unequip_selected)
	var user_args := OS.get_cmdline_user_args()
	var force_fresh := user_args.has("--fresh")
	if force_fresh:
		ExpeditionSession.end_run()
	var battle_result := ExpeditionSession.consume_battle_result()
	if not ExpeditionSession.is_in_expedition():
		var resumed := false
		if not force_fresh:
			resumed = ExpeditionSession.resume_from_save()
		if not resumed:
			ExpeditionSession.start_run(randi())
			ExpeditionSession.save_game()
	elif not battle_result.is_empty():
		ExpeditionSession.board_state.resolve_battle_result(battle_result)
	board = ExpeditionSession.board_state
	_last_alert_level = board.alert_level
	ui_layer = Control.new()
	ui_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	view.setup(continent, self)
	view.on_hero_moved(board.hero_site)
	view.set_mode(false, false)
	_setup_map_backdrop()
	_setup_toggle_button()
	outcome_overlay.setup(board, ExpeditionSession)
	outcome_overlay.return_pressed.connect(_on_return_stronghold)
	add_child(outcome_overlay)
	# 容器弹窗（D-028 弹窗翻牌）：挂在场景根上，_refresh 清屏清不到，翻/拿后自刷新
	container_popup.flip_requested.connect(_on_container_flip)
	container_popup.take_requested.connect(_on_container_take)
	add_child(container_popup)
	_popup_host = PopupHost.new()
	_popup_host.closed.connect(func(): _popup_kind = "")
	add_child(_popup_host)
	_drain_events()
	# 战斗编排续接：连坐下一场；战斗中强退＝续战同一场（检查点语义）。
	if not board.is_run_over() and board.battle_cell >= 0:
		var pending := board.cell_card(board.hero_site, board.battle_cell)
		if not pending.is_empty() and str(pending.get("kind", "")) in ["enemy", "pursuer", "zhenwu"]:
			_enter_battle(str(pending.get("enemy_id", "")), board.battle_enemy_first)
			return
		board.battle_cell = -1
	if not board.is_run_over() and not board.chain_queue.is_empty():
		var next_id := board.next_chain()
		if not next_id.is_empty():
			_drain_events()
			_enter_battle(next_id, false)
			return
	_refresh()
	table.gui_input.connect(_on_table_input)
	# 预览截图：`-- --shot*` 时渲染后自动存 user://board_shot.png 并退出
	var shot_mode := ""
	for arg in user_args:
		if arg.begins_with("--shot"):
			shot_mode = arg
	if not shot_mode.is_empty():
		await get_tree().create_timer(2.0).timeout
		if shot_mode == "--shot-build":
			_popup_host.open(top_bar, _build_build_panel())
			await get_tree().create_timer(0.5).timeout
		elif shot_mode == "--shot-map":
			_set_map_mode(true)
			await get_tree().create_timer(1.2).timeout
		get_viewport().get_texture().get_image().save_png("user://board_shot.png")
		get_tree().quit()

# ---------- 刷新（唯一重画入口） ----------

# 移动后的重定焦：地块档补间到新面板中心；大地图档静态 fit，直接重画。
func _recenter_animated() -> void:
	view.on_hero_moved(board.hero_site)
	if view.map_mode:
		_refresh()
		return
	var from := continent.position
	var target: Vector2 = view.tile_transform()[0]
	_animate_focus = true
	_refresh()
	continent.position = from
	var tween := create_tween()
	tween.tween_property(continent, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _refresh() -> void:
	for child in continent.get_children():
		if child != _map_backdrop:
			child.queue_free()
	continent.move_child(_map_backdrop, 0)
	for child in ui_layer.get_children():
		child.queue_free()
	view.on_hero_moved(board.hero_site)
	view.apply_if_idle()
	_build_edges()
	if view.map_mode:
		_build_map_marks()
	else:
		_spawn_tile(board.hero_site)
	_render_screen_ui()
	_last_hero = board.hero_site
	_animate_focus = false

# 舆图世界层：底图只是"纸"，随档位变换平移缩放；节点、路网等"棋子"一律运行时叠加，
# 不烙进美术资源（D-059）
func _setup_map_backdrop() -> void:
	_map_backdrop = TextureRect.new()
	_map_backdrop.name = "MapBackdrop"
	_map_backdrop.texture = MAP_TEXTURE
	_map_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_map_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_backdrop.position = BoardLayout.MAP_ORIGIN
	_map_backdrop.size = BoardLayout.WORLD_SIZE
	continent.add_child(_map_backdrop)

# 两档切换按钮（D-059：大地图战略图 ↔ 当前地块网格）
func _setup_toggle_button() -> void:
	_toggle_btn = Button.new()
	_toggle_btn.text = "大地图"
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.add_theme_font_size_override("font_size", 16)
	_toggle_btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 20)
	_toggle_btn.pressed.connect(func(): _set_map_mode(not view.map_mode))
	add_child(_toggle_btn)

func _set_map_mode(to_map: bool) -> void:
	if to_map == view.map_mode:
		return
	view.set_mode(to_map, true)
	_refresh()

func _update_toggle_button() -> void:
	if _toggle_btn == null:
		return
	_toggle_btn.text = "当前地块" if view.map_mode else "大地图"

# 大地图档：全部节点落印章（未勘灰／已勘亮＋地名；可前往亮边价；当前金环）
func _build_map_marks() -> void:
	var inv_scale := 1.0 / maxf(view.map_scale(), 0.05)
	var hunter_site = board.hunter.get("site") if not board.hunter.is_empty() else null
	for pos in board.sites:
		var mark := MapNodeMark.new()
		mark.name = "Mark_%d_%d" % [pos.x, pos.y]
		continent.add_child(mark)
		mark.setup(pos, board.sites[pos], pos == board.hero_site, board.can_travel_to(pos),
			board.travel_cost(board.hero_site, pos), hunter_site != null and pos == hunter_site)
		mark.position = BoardLayout.pixel(pos) - mark.size / 2.0
		mark.scale = Vector2(inv_scale, inv_scale)
		mark.tooltip_text = _mark_tooltip(pos)
		mark.travel_requested.connect(_try_travel)
		mark.zoom_requested.connect(func(): _set_map_mode(false))

# 节点印悬停：已勘＝地名＋构成明牌侦察；相邻可走＝边价；未勘＝不漏
func _mark_tooltip(pos: Vector2i) -> String:
	var site: Dictionary = board.sites[pos]
	if not bool(site.get("explored", false)):
		if board.can_travel_to(pos):
			return "未探之地\n点击前往（%d 行动力）" % board.travel_cost(board.hero_site, pos)
		return "未探之地"
	var lines: Array[String] = ["%s（%s带·%s）" % [str(site.get("name", "？？？")), str(site.get("band", "浅")),
		"枢纽" if str(site.get("tier", "")) == "hub" else "途经"]]
	if board.is_extract_site(pos):
		lines.append("撤离点")
	var peek := board.site_peek(pos)
	if not peek.is_empty():
		lines.append("、".join(peek))
	if board.can_travel_to(pos):
		lines.append("点击前往（%d 行动力）" % board.travel_cost(board.hero_site, pos))
	elif pos != board.hero_site:
		lines.append("须沿通道逐点前往")
	return "\n".join(lines)

# 路网层（两档都画：地块档里衬在面板后面保持方位感）
func _build_edges() -> void:
	var pairs: Array = []
	for pos in board.sites:
		for link in board.sites[pos]["links"]:
			if [link, pos] in pairs:
				continue
			pairs.append([pos, link])
	var edges := MapEdges.new()
	continent.add_child(edges)
	edges.setup(pairs, board.link_costs, board.secret_links)
	edges.position = BoardLayout.MAP_ORIGIN
	edges.size = BoardLayout.WORLD_SIZE
	continent.move_child(edges, 1)  # 垫在底图之上、其余之下

func _spawn_tile(pos: Vector2i) -> void:
	var tile = TileScene.instantiate()
	continent.add_child(tile)
	tile.position = BoardLayout.pixel(pos)
	tile.travel_requested.connect(_try_travel)
	tile.card_action_requested.connect(_on_card_action)
	tile.battle_requested.connect(_on_battle_at)
	tile.extract_requested.connect(_on_extract_pressed)
	# 地块档里滚轮向下＝回大地图（面板内的滚动容器会先吃掉自己的滚动）
	tile.wheel_scrolled.connect(func(up: bool, at: Vector2):
		if not up:
			_set_map_mode(true))
	tile.setup(pos, board.sites[pos], board, pos == board.hero_site, board.is_run_over(),
		_confirm_extract, ExpeditionSession.carried_value(), _animate_focus, board.can_travel_to(pos))
# ---------- 屏幕固定 UI ----------

func _render_screen_ui() -> void:
	var alert := board.alert_info()
	top_bar.refresh(str(board.config.get("name", "江湖险地")), ExpeditionSession.carried_hp(), ExpeditionSession.carried_max_hp(),
		board.ap, int(board.config.get("ap", {}).get("start", 40)), board.ap_spent, alert)
	log_view.set_lines(log_lines)
	backpack.refresh(board.inventory, board.backpack_capacity(), selected_inv, board.is_run_over(),
		board.item_usable_in_explore(selected_inv) if selected_inv >= 0 and not board.is_run_over() else false,
		board.pouch, board.pouch_capacity(), selected_pouch,
		board.pouch_item_usable_in_explore(selected_pouch) if selected_pouch >= 0 and not board.is_run_over() else false,
		board.equipped, selected_wear,
		selected_inv >= 0 and selected_inv < board.inventory.size() and board.is_equipment(board.inventory[selected_inv]))
	outcome_overlay.render(ui_layer)
	_update_toggle_button()

func _on_build_pressed() -> void:
	if _popup_kind == "build":
		_close_popups()
		return
	_popup_kind = "build"
	_popup_host.open(top_bar, _build_build_panel())

func _on_settings_pressed() -> void:
	if _popup_kind == "settings":
		_close_popups()
		return
	_popup_kind = "settings"
	_popup_host.open(top_bar, _build_settings_panel())

func _close_popups() -> void:
	_popup_kind = ""
	_popup_host.close()

func _build_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD
	style.border_color = Palette.COLOR_INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var restart := ConfirmButton.new()
	restart.setup("放弃远征", "确定放弃本局？物资将全部丢失。")
	restart.confirmed.connect(_on_abandon)
	vbox.add_child(restart)
	var close := Button.new()
	close.text = "继续"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _close_popups())
	vbox.add_child(close)
	return panel

# 构筑面板：占位（真气牌库查看、功法位调整后续实现；内功位待内功系统落地）
func _build_build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.COLOR_CARD
	style.border_color = Palette.COLOR_INK
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(300, 0)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	vbox.add_child(Palette.brush_label("角色与构筑", 22, Palette.COLOR_INK))
	vbox.add_child(Palette.plain_label("气血 %d/%d ｜ %s" % [ExpeditionSession.carried_hp(),
		ExpeditionSession.carried_max_hp(), board.equipment_summary()], 15, Palette.COLOR_INK))
	vbox.add_child(Palette.plain_label("真气牌库：查看待实现", 15, Palette.COLOR_INK))
	vbox.add_child(Palette.plain_label("功法位：调整待实现", 15, Palette.COLOR_INK))
	vbox.add_child(Palette.plain_label("内功位：内功系统待落地", 15, Palette.COLOR_INK))
	var close := Button.new()
	close.text = "关闭"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _close_popups())
	vbox.add_child(close)
	return panel

func _on_return_stronghold() -> void:
	# 终态结算：撤离成功则背包入据点仓库（settle_and_end_run 内处理），随后回据点
	ExpeditionSession.settle_and_end_run()
	get_tree().change_scene_to_file(SceneRoutes.STRONGHOLD)

func _on_abandon() -> void:
	# 局内主动放弃：物资全丢（不入库）、穿戴散失、弃档，回据点
	ExpeditionSession.abandon_run()
	get_tree().change_scene_to_file(SceneRoutes.STRONGHOLD)

# ---------- 动作执行 ----------

# 任意玩家动作的统一收尾：事件→存档→音效→袭击判定→刷新/进战斗。
# 袭击判定是每动作一次（含 0 行动力的整理）——准备态满表的敌人咬你的时机。
func _run_action(action: Callable) -> void:
	_confirm_extract = false
	action.call()
	_drain_events()
	_finish_action()

func _finish_action() -> void:
	ExpeditionSession.save_game()
	_after_action_sounds()
	if board.is_run_over():
		_refresh()
		return
	var ambusher := board.check_ambush()
	_drain_events()
	if not ambusher.is_empty():
		_enter_battle(ambusher, true)
		return
	if board.hero_site != _last_hero:
		_recenter_animated()
	else:
		_refresh()

# 卡牌互动（点击即互动）：按类别路由到规则层，音效随行。
func _on_card_action(cell: int) -> void:
	var card := board.cell_card(board.hero_site, cell)
	match str(card.get("kind", "")):
		"scatter":
			_run_action(func():
				Sfx.play(SFX_DIR + "take.wav")
				board.pickup_cell(cell))
		"chest", "body":
			var cost: int = board.chest_open_cost(str(card.get("chest", "")))
			_run_action(func():
				Sfx.play_open(cost)
				board.open_cell(cell))
			_try_open_container(cell)
		"npc":
			_run_action(func():
				Sfx.play(SFX_DIR + "talk.wav")
				board.talk_cell(cell))
		"location":
			_run_action(func(): board.open_location_cell(cell))

# 点击敌牌＝迎战（你先手；连坐组由规则层排队，逐场连战）。
func _on_battle_at(cell: int) -> void:
	var enemy_id: String = board.engage_cell(cell)
	if enemy_id.is_empty():
		_refresh()
		return
	_drain_events()
	_enter_battle(enemy_id, false)

func _enter_battle(enemy_id: String, enemy_first: bool) -> void:
	Sfx.play(SFX_DIR + "battle.wav")
	ExpeditionSession.prepare_battle(enemy_id, enemy_first)
	ExpeditionSession.save_game()
	get_tree().change_scene_to_file(SceneRoutes.BATTLE)

# ---------- 容器弹窗（D-028：开启费开盖 → 弹窗逐张翻牌 → 拿取免费） ----------

# 开盖动作成功且局未终→弹窗；空壳（拿空）不弹；已开的再点＝免费续翻视图。
func _try_open_container(cell: int) -> void:
	if board.is_run_over() or board.battle_cell >= 0:
		return
	var card := board.cell_card(board.hero_site, cell)
	if str(card.get("kind", "")) in ["chest", "body"] and bool(card.get("opened", false)) \
			and not (card.get("contents", []) as Array).is_empty():
		container_popup.open(board, cell)

# 弹窗里点暗牌＝翻（1 行动力）。翻牌音效先给点击反馈，稀有度揭示音只在真翻开时播
# （暗牌不漏物品信息——漏了就不是赌博了）。
func _on_container_flip(cell: int, index: int) -> void:
	var done: Array = []
	_run_action(func():
		Sfx.play(SFX_DIR + "flip.wav")
		if board.flip_cell_content(cell, index):
			done.append(true))
	if done.is_empty():
		return
	var contents: Array = board.cell_card(board.hero_site, cell).get("contents", [])
	if index < contents.size():
		var item_id := str((contents[index] as Dictionary).get("item_id", ""))
		Sfx.play_reveal(_rarity_juice(item_id))
	_refresh_container(cell)

# 弹窗里点亮牌＝拿（免费，满格拒收东西留在容器里）。
func _on_container_take(cell: int, index: int) -> void:
	_run_action(func():
		Sfx.play(SFX_DIR + "take.wav")
		board.take_cell_content(cell, index))
	_refresh_container(cell)

# 翻/拿之后：进战斗或终态→收窗；拿空→自动收窗；否则弹窗原地重读状态。
func _refresh_container(cell: int) -> void:
	if board.is_run_over() or board.battle_cell >= 0 or board.hero_site != _last_hero:
		container_popup.close()
		return
	var card := board.cell_card(board.hero_site, cell)
	if str(card.get("kind", "")) not in ["chest", "body"] or (card.get("contents", []) as Array).is_empty():
		container_popup.close()
		return
	container_popup.refresh_view()

# 物品稀有度 → 揭示音效档（1~4）：普通 1、精良 2、稀有 3、传说 4。
func _rarity_juice(item_id: String) -> int:
	match board.item_rarity(item_id):
		"fine":
			return 2
		"rare":
			return 3
		"legend":
			return 4
	return 1

func _on_extract_pressed() -> void:
	if not _confirm_extract:
		_confirm_extract = true
		_refresh()
		return
	_confirm_extract = false
	board.extract()
	_drain_events()
	_finish_action()

func _on_inv_slot(i: int) -> void:
	if i >= board.inventory.size() or board.is_run_over():
		return
	selected_inv = -1 if selected_inv == i else i
	_refresh()

func _on_use_selected() -> void:
	if selected_inv < 0:
		return
	_run_action(func(): board.use_item(selected_inv))
	selected_inv = -1

func _on_drop_selected() -> void:
	if selected_inv < 0:
		return
	_run_action(func(): board.drop_item(selected_inv))
	selected_inv = -1

# 背包 → 锦囊（0 行动力；兵器/护具会被模型拒绝并播报）
func _on_stash_selected() -> void:
	if selected_inv < 0:
		return
	_run_action(func(): board.move_to_pouch(selected_inv))
	selected_inv = -1

func _on_pouch_slot(i: int) -> void:
	if i >= board.pouch.size() or board.is_run_over():
		return
	selected_pouch = -1 if selected_pouch == i else i
	_refresh()

func _on_pouch_use_selected() -> void:
	if selected_pouch < 0:
		return
	_run_action(func(): board.use_pouch_item(selected_pouch))
	selected_pouch = -1

# 锦囊 → 背包 / 锦囊内丢弃（0 行动力）
func _on_unstash_selected() -> void:
	if selected_pouch < 0:
		return
	_run_action(func(): board.move_to_bag(selected_pouch))
	selected_pouch = -1

func _on_pouch_drop_selected() -> void:
	if selected_pouch < 0:
		return
	_run_action(func(): board.drop_pouch_item(selected_pouch))
	selected_pouch = -1

# 背包 → 穿戴（0 行动力，整理类）：装备实例上身，旧穿戴件回背包
func _on_equip_selected() -> void:
	if selected_inv < 0:
		return
	_run_action(func(): board.equip_from_inventory(selected_inv))
	selected_inv = -1

# 点穿戴槽切换选中（空槽不可选）
func _on_wear_slot(slot_id: String) -> void:
	if board.is_run_over() or board.equipped.get(slot_id, {}).is_empty():
		return
	selected_wear = "" if selected_wear == slot_id else slot_id
	_refresh()

# 穿戴 → 背包（0 行动力）
func _on_unequip_selected() -> void:
	if selected_wear.is_empty():
		return
	_run_action(func(): board.unequip_to_inventory(selected_wear))
	selected_wear = ""

# ---------- 事件日志 ----------

func _drain_events() -> void:
	var drained := board.drain_events()
	log_lines.append_array(drained)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)

# UI 侧提示（如移动失败原因），与规则事件同入日志窗
func _log_local(msg: String) -> void:
	log_lines.append(msg)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)

# 动作后音效：警戒升级锣声、终态音效（各一次）
func _after_action_sounds() -> void:
	if board.alert_level > _last_alert_level:
		_last_alert_level = board.alert_level
		Sfx.play_alert(board.alert_level)
	if board.is_run_over() and not _outcome_sound_played:
		_outcome_sound_played = true
		if board.outcome == "extracted":
			Sfx.play(SFX_DIR + "extract.wav")
		else:
			Sfx.play(SFX_DIR + "exhausted.wav")

# ---------- 输入 ----------

# 键盘：M 切两档（HUD 上方的键入被控件吃掉，不会穿透）。
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_set_map_mode(not view.map_mode)

# 桌面（Table）空白处：滚轮切档（地图档向上滚＝进地块；地块档向下滚＝出大地图）。
# 无自由平移/缩放——两档吸附，中间态不存在（D-059）。
func _on_table_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and view.map_mode:
			_set_map_mode(false)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not view.map_mode:
			_set_map_mode(true)

func _try_travel(pos: Vector2i) -> void:
	if pos == board.hero_site:
		return
	if board.travel_to(pos):
		_confirm_extract = false
		_run_action(func(): pass)
		return
	# 走不了要给反馈：静默失败会被当成点不动
	_drain_events()
	if not board.is_run_over():
		if board.pending_intercept():
			_log_local("追兵拦在眼前，无法离开！")
		elif not (board.hero_site in board.site_at(pos).get("links", [])):
			_log_local("只能沿通道前往相邻地块。")
	_refresh()
