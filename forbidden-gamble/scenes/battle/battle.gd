extends Control

const ENCOUNTER_PATH := DataRepo.SANDBOX_ENCOUNTER_PATH
const BP := preload("res://ui/battle_palette.gd")

# 牌型 → 中文名（真气语法 v2：刻子/顺子，输入固定三张）
const PATTERN_NAMES := {
	"KEZI": "刻子", "SHUNZI": "顺子",
}

var combat: CombatState
var turn_manager: TurnManager
var combat_log: CombatLog
# 装配流：点功法（一次）＝装配——已选真气带入镶孔，还缺则以已选为前提智能补齐，
# 补不齐提示并保持装配态；满足条件＝待确认。
var armed_technique: String = ""
var selected_indices: Array[int] = []
# 架势选弃中：真气点击＝标记弃置（金环），确认＝弃所选入自己的牌河并纳满丹田。
var swap_picking := false
var log_lines: Array[String] = []
var _end_message_shown := false
var _techniques_built := false
# 演出层（气影/横幅/飘字）与敌方连动编排（令牌/节奏）
var fx: BattleFx
var sequencer: BattleSequencer
# 演出速度档系数
var _pace := 1.0
# 顶栏弹窗（设置；PopupHost 管关闭交互）
var _popup_host: PopupHost
var _popup_kind := ""  # "" / "settings" / "claim"

@onready var top_bar: BattleTopBar = $Center/Column/TopBar
@onready var stage: Control = $Center/Column/Stage
@onready var player_panel: FighterPanel = $Center/Column/Stage/PlayerPanel
@onready var enemy_panel: FighterPanel = $Center/Column/Stage/EnemyPanel
@onready var confirm_button: Button = $Center/Column/Stage/CenterZone/Buttons/ConfirmButton
@onready var cancel_button: Button = $Center/Column/Stage/CenterZone/Buttons/CancelButton
@onready var swap_button: Button = $Center/Column/Stage/CenterZone/Buttons/BreatheButton
@onready var buttons_row: Control = $Center/Column/Stage/CenterZone/Buttons
@onready var hand_layer: HandBar = $Center/Column/HandLayer
@onready var tech_layer: TechniqueBar = $Center/Column/TechLayer
@onready var log_overlay: Control = $LogOverlay
@onready var battle_log = $LogOverlay/Panel
# 终局结算浮层
@onready var end_overlay: BattleEndOverlay = $EndOverlay

func _ready() -> void:
	confirm_button.pressed.connect(_confirm_pending)
	cancel_button.pressed.connect(_cancel_pending)
	swap_button.pressed.connect(_on_swap_pressed)
	end_overlay.report_requested.connect(func(): log_overlay.visible = true)
	end_overlay.restart_requested.connect(_on_restart_pressed)
	end_overlay.return_requested.connect(_on_return_to_map)
	top_bar.report_pressed.connect(_on_log_button_pressed)
	top_bar.settings_pressed.connect(_on_settings_pressed)
	# 演出挂载层：全屏、忽略鼠标，横幅/幽灵/飘字都进这层——绝不进 Column。
	var fx_layer := Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	_popup_host = PopupHost.new()
	_popup_host.closed.connect(func():
		if _popup_kind == "claim":
			_popup_kind = ""
			# 弹窗未选而关（ESC 等）＝放行：窗口作废，被动获得行动权
			_release_claim_window()
		else:
			_popup_kind = "")
	add_child(_popup_host)
	fx = BattleFx.new()
	fx.setup(stage, hand_layer, player_panel, fx_layer, enemy_panel)
	add_child(fx)
	sequencer = BattleSequencer.new()
	sequencer.pace_getter = func() -> float: return _pace
	sequencer.on_step = _enemy_step
	sequencer.chain_finished.connect(func(): _refresh_ui())
	sequencer.battle_ended.connect(_show_end_overlay)
	add_child(sequencer)
	log_overlay.gui_input.connect(_on_log_overlay_input)
	($LogOverlay/Panel as Control).gui_input.connect(_on_log_overlay_input)
	($LogOverlay/Panel/Scroll as Control).gui_input.connect(_on_log_overlay_input)
	hand_layer.card_clicked.connect(_on_card_clicked)
	tech_layer.technique_clicked.connect(_on_technique_clicked)
	_start_demo()

func _start_demo() -> void:
	if DojoConfig.active:
		# 演武场：敌人来自 enemies.json，构筑来自 DojoConfig（选敌→选构筑→对战）
		var dplayer := EncounterLoader.load_player(DataRepo.PLAYER_PATH)
		var denemy := EncounterLoader.load_enemy(DataRepo.ENEMIES_PATH, DojoConfig.enemy_id)
		if dplayer == null or denemy == null:
			log_lines.append("演武场配置加载失败：" + DojoConfig.enemy_id)
			_refresh_ui()
			return
		combat = CombatState.new(dplayer, denemy)
		combat.battle_seed = randi()
		if not DojoConfig.deck.is_empty():
			combat.player.destiny_pile.clear()
			combat.player.hand.clear()
			for i in range(DojoConfig.deck.size()):
				var dc: Dictionary = DojoConfig.deck[i]
				combat.player.destiny_pile.append(QiCard.new(
					str(dc.get("id", "")), str(dc.get("attribute", "")), int(dc.get("value", 3))))
		if not DojoConfig.techniques.is_empty():
			combat.player.techniques.assign(DojoConfig.techniques)
		if not DojoConfig.xinfa.is_empty():
			combat.player.xinfa.assign(DojoConfig.xinfa)
		if DojoConfig.hp > 0:
			combat.player.hp = clampi(DojoConfig.hp, 1, combat.player.max_hp)
	else:
		combat = EncounterLoader.load(ENCOUNTER_PATH)
	if combat == null:
		log_lines.append("遭遇战配置加载失败：" + ENCOUNTER_PATH)
		_refresh_ui()
		return
	combat_log = CombatLog.new()
	print("战斗日志：", combat_log.absolute_path())
	combat_log.write("遭遇战：%s ｜ 敌人：%s ｜ 随机种子：%d" % [ENCOUNTER_PATH, combat.enemy.display_name, combat.battle_seed])
	top_bar.set_context(_context_text())
	turn_manager = TurnManager.new(combat, combat.battle_seed)
	turn_manager.start_battle(true, DojoConfig.enemy_first)
	_drain_log()
	_refresh_ui()
	# 被袭击（敌方先手）：开场即敌方回合——敌方第一击由演出链自动打出。
	if not turn_manager.is_over() and combat.active_side == "enemy":
		sequencer.play(turn_manager, combat)

func _context_text() -> String:
	if combat == null:
		return " "
	return "演武场 · 演练"

func _exit_tree() -> void:
	if combat_log != null:
		combat_log.close()

func _on_return_to_map() -> void:
	if DojoConfig.active:
		DojoConfig.clear()
		get_tree().change_scene_to_file(SceneRoutes.DOJO)
		return
	get_tree().change_scene_to_file(SceneRoutes.TITLE)

func _refresh_ui() -> void:
	if combat == null or turn_manager == null:
		_render_log()
		return
	var over := _combat_result()
	if not over.is_empty() and not _end_message_shown:
		_end_message_shown = true
		match over:
			"player":
				log_lines.append("战斗结束：你获胜了！")
			"enemy":
				log_lines.append("战斗结束：你败北了。")
	var player_turn := combat.active_side == "player" and over.is_empty()
	var awaiting := turn_manager.awaiting_player_claims
	# 蓄力占用玩家的行动机会：充能拍自动执行（延后一帧跑，避免在刷新中递归）
	var charging_now := player_turn and not awaiting and combat.player.has_active_charge() and not sequencer.busy
	# 回合·行动方（顶栏）
	if not over.is_empty():
		var end_text := "—— 你败北了 ——"
		if over == "player":
			end_text = "—— 你获胜了 ——"
		top_bar.set_turn(end_text, BP.COLOR_TURN_END)
	elif awaiting:
		top_bar.set_turn("架势 %d 次 · 截牌窗：截，或放行" % combat.player_swap_count, Color(0.72, 0.4, 0.62))
	elif player_turn:
		top_bar.set_turn("架势 %d 次 · ▶ 你的行动" % combat.player_swap_count, BP.COLOR_GOLD)
	else:
		top_bar.set_turn("架势 %d 次 · …… 敌方行动" % combat.player_swap_count, BP.COLOR_ENEMY)
	# 对战区双面板
	_update_panel(player_panel, combat.player, false)
	_update_panel(enemy_panel, combat.enemy, true)
	# 丹田手牌层：左气海（共墙余量）、右牌河（自己的弃牌）
	hand_layer.set_piles(combat.qi_wall.size(), combat.river_of("player").size())
	hand_layer.set_meld_info(_meld_info_text(player_turn))
	hand_layer.set_hand(combat.player.hand, selected_indices, player_turn and not charging_now and not awaiting)
	# 功法层（卡位每场战斗建一次，四态随每次刷新）
	if not _techniques_built:
		tech_layer.set_techniques(_technique_entries())
		_techniques_built = true
	tech_layer.set_states(_technique_states(player_turn and not awaiting))
	# 中央操作按钮两组互换：未装配＝只显示[架势]；装配中/待确认/选弃＝只显示[确认][取消]；
	# 敌方回合、演出停顿、截牌窗、蓄力充能拍整行隐藏。
	buttons_row.visible = player_turn and not sequencer.busy and not charging_now and not awaiting
	var armed := not armed_technique.is_empty()
	var picking := swap_picking
	confirm_button.visible = armed or picking
	cancel_button.visible = armed or picking
	swap_button.visible = not armed and not picking
	if picking:
		# 架势须弃 1–4 张：未选齐至少 1 张时确认保持灰
		confirm_button.disabled = selected_indices.is_empty() or selected_indices.size() > TurnManager.SWAP_MAX
	else:
		confirm_button.disabled = not _can_player_use(armed_technique)
	cancel_button.disabled = false
	if picking:
		confirm_button.text = "架势（弃 %d）" % selected_indices.size()
	elif confirm_button.text != "确认":
		confirm_button.text = "确认"
	swap_button.disabled = false
	_render_log()
	# 截牌窗（敌方架势弃牌入河后流动挂起）：截即打或放行——主动夺取，不补满
	_maybe_offer_claims(awaiting)
	if charging_now:
		call_deferred("_auto_charge_tick")

func _update_panel(panel: FighterPanel, unit: FighterState, is_enemy: bool) -> void:
	panel.fighter_name = unit.display_name
	panel.max_hp = unit.max_hp
	panel.hp = unit.hp
	panel.guard = unit.guard
	panel.status_names = _status_names(unit)
	panel.xinfa_names = ",".join(unit.xinfa)
	if is_enemy:
		# 敌方：意图＝脑锁定的即将行动（功法名/架势/蓄力招，活读数）；
		# 应读数常驻披露它此刻能截哪些牌（实时活算：手牌搭子＋功法冷却）；手牌张数公开。
		var action := str(turn_manager.enemy_intent.get("action", ""))
		var technique := str(turn_manager.enemy_intent.get("technique", ""))
		if unit.has_active_charge():
			panel.intent_name = "%s·蓄力%d/%d" % [technique,
				int(unit.charging.get("charge", 0)), int(unit.charging.get("need", 0))]
		else:
			panel.intent_name = str(turn_manager.enemy_intent.get("label", technique))
		panel.show_intent = not action.is_empty()
		panel.set_intent_tooltip(_intent_preview())
		panel.enemy_hand = unit.hand.size()
		panel.hook_lamp_text = _threat_text()
		panel.hook_lamp_tooltip = _threat_tooltip()
	else:
		# 我方：准备槽显示装配中功法；蓄力期间改显蓄力进度
		if unit.has_active_charge():
			panel.show_intent = true
			panel.intent_name = "%s·蓄力%d/%d" % [str(unit.charging.get("technique", "")), int(unit.charging.get("charge", 0)), int(unit.charging.get("need", 0))]
		else:
			panel.show_intent = not armed_technique.is_empty()
			panel.intent_name = armed_technique
		if not armed_technique.is_empty():
			var level := int(TechniqueResolver.data_for(armed_technique).get("level", 1))
			panel.intent_art_color = BP.LEVEL_COLORS[clampi(level, 1, 5) - 1]

func _meld_info_text(player_turn: bool) -> String:
	if not player_turn:
		return "" if _combat_result() != "" else "敌方行动……"
	if turn_manager.awaiting_player_claims:
		return "截牌窗：截下河牌＝当场组型轰出（主动夺取，不补满）；放行＝窗口作废，正常行动"
	if combat.player.has_active_charge():
		var ch: Dictionary = combat.player.charging
		return "蓄力中：%s（%d/%d）——引而不发，充能拍自动执行" % [str(ch.get("technique", "")), int(ch.get("charge", 0)), int(ch.get("need", 0))]
	if swap_picking:
		return "架势选弃：点真气标记弃置（已标 %d/%d 张）——[确认] 弃入你的牌河并纳满丹田" % [
			selected_indices.size(), TurnManager.SWAP_MAX]
	if not armed_technique.is_empty():
		var armed_selected := _selected_cards()
		if _can_player_use(armed_technique):
			return "待确认：%s（%s · 数值和 %d）—— [确认] 发动，[取消] 重选" % [
				armed_technique, _cards_text(armed_selected), TechniqueResolver.value_sum(armed_selected)]
		return "装配中：%s —— 已入孔 %d/%d 张未凑成牌型，增删真气后再点功法卡重试" % [
			armed_technique, armed_selected.size(), PatternEvaluator.PATTERN_SIZE]
	var selected := _selected_cards()
	if not selected.is_empty():
		var names: Array[String] = []
		for pattern in PatternEvaluator.evaluate(selected):
			names.append(PATTERN_NAMES.get(str(pattern), str(pattern)))
		if names.is_empty():
			return "已选 %d 张真气（未成牌型）· 数值和 %d" % [selected.size(), TechniqueResolver.value_sum(selected)]
		return "凝招：%s · 数值和 %d" % ["/".join(names), TechniqueResolver.value_sum(selected)]
	return "点功法卡：带入已选真气并智能补齐（刻子三张全同／顺子同属性连三）"

# 功法层卡位数据：等级、效果摘要、镶孔槽数（固定三张）。
func _technique_entries() -> Array:
	var entries: Array = []
	for technique_id in combat.player.techniques:
		var data := TechniqueResolver.data_for(technique_id)
		entries.append({
			"id": technique_id,
			"name": technique_id,
			"effect": TechniqueResolver.effect_summary(technique_id),
			"level": int(data.get("level", 1)),
			"slot_count": PatternEvaluator.PATTERN_SIZE,
			"slot_layout": QiSlotGroup.SlotLayout.UNIFORM,
		})
	return entries

# 功法四态：PENDING 待确认填珠 / SATISFIED 当前选择满足 / UNUSABLE 压灰注原因。
func _technique_states(player_turn: bool) -> Dictionary:
	var states := {}
	for technique_id in combat.player.techniques:
		var state: int = TechniqueCard.CardState.NORMAL
		var reason := ""
		var fill: Array = []
		if armed_technique == technique_id:
			state = TechniqueCard.CardState.PENDING
			for card in _selected_cards():
				fill.append(QiOrb.color_for_attribute(str(card.attribute)))
		elif player_turn:
			if _can_player_use(technique_id):
				state = TechniqueCard.CardState.SATISFIED
			else:
				reason = _technique_block_reason(technique_id)
				if not reason.is_empty():
					state = TechniqueCard.CardState.UNUSABLE
		states[technique_id] = {"state": state, "reason": reason, "fill": fill}
	return states

# 不可用原因：蓄力占用 / 冷却中 / 手牌凑不出牌型（顺序即优先级）。
func _technique_block_reason(technique_id: String) -> String:
	if combat.player.has_active_charge():
		return "蓄力中"
	var cooldown_left := int(combat.player.technique_cooldowns.get(technique_id, 0))
	if cooldown_left > 0:
		return "冷却%d" % cooldown_left
	if TechniqueResolver.find_legal_selection(technique_id, combat.player.hand, combat.player).is_empty():
		var names: Array[String] = []
		for pattern in TechniqueResolver.data_for(technique_id).get("patterns", []):
			names.append(PATTERN_NAMES.get(str(pattern), str(pattern)))
		return "缺牌型·" + "/".join(names)
	return ""

func _can_player_use(technique_id: String) -> bool:
	return not selected_indices.is_empty() and TechniqueResolver.can_use(technique_id, _selected_cards(), combat.player)

func _confirm_pending() -> void:
	if swap_picking:
		confirm_swap()
		return
	if armed_technique.is_empty() or turn_manager.is_over():
		return
	if not _can_player_use(armed_technique):
		return
	_log_action("操作：确认发动 %s" % armed_technique)
	var used_qi := hand_layer.orb_snapshots(selected_indices)
	var enemy_hp_before := combat.enemy.hp
	var result := turn_manager.player_act(armed_technique, _selected_cards())
	if not bool(result.get("ok", false)):
		log_lines.append("未发动：" + str(result.get("reason", "未知原因")))
	else:
		armed_technique = ""
		selected_indices = []
	_drain_log(used_qi)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)
	_after_player_input()

# 取消装配/选弃：已选索引清空回自由态。
func _cancel_pending() -> void:
	if swap_picking:
		swap_picking = false
		selected_indices = []
		_refresh_ui()
		return
	armed_technique = ""
	_refresh_ui()

# 架势：进入选弃流——点真气＝标记弃置（1–4 张），确认＝弃入自己的牌河＋纳满丹田（费一拍）。
func _on_swap_pressed() -> void:
	if turn_manager.is_over() or combat.active_side != "player" or sequencer.busy:
		return
	if turn_manager.awaiting_player_claims or combat.player.has_active_charge():
		return
	armed_technique = ""
	swap_picking = true
	selected_indices = []
	_refresh_ui()

# 确认架势：弃所选入自己的牌河（公开、为对方开截牌窗），从气海纳满丹田。
func confirm_swap() -> void:
	if selected_indices.is_empty() or selected_indices.size() > TurnManager.SWAP_MAX:
		return
	swap_picking = false
	var indices := selected_indices.duplicate()
	_log_action("操作：架势（弃 %d 口：%s）" % [indices.size(), _cards_text(_selected_cards())])
	selected_indices = []
	turn_manager.player_swap(indices)
	_drain_log()
	_after_player_input()

# 玩家输入后的统一尾巴：刷新一帧，随后敌方连动逐条演出（含其截链后的流动落点）；
# 终局停一拍再弹结算浮层。
func _after_player_input() -> void:
	_refresh_ui()
	if not turn_manager.is_over() and not turn_manager.awaiting_player_claims and combat.active_side == "enemy":
		sequencer.play(turn_manager, combat)

# 敌方连动单步（内容注入 sequencer）：结算一拍 + 逐条呈现。
func _enemy_step() -> void:
	var player_hp_before := combat.player.hp
	var enemy_hp_before := combat.enemy.hp
	turn_manager.enemy_act()
	_drain_log()
	_refresh_ui()
	fx.hp_feedback(player_hp_before, combat.player.hp, player_panel)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)

# 蓄力充能拍：玩家被动获得行动权且有蓄力时自动执行。
func _auto_charge_tick() -> void:
	if combat == null or turn_manager == null or turn_manager.is_over() or sequencer.busy:
		return
	if combat.active_side != "player" or turn_manager.awaiting_player_claims or not combat.player.has_active_charge():
		return
	var enemy_hp_before := combat.enemy.hp
	var player_hp_before := combat.player.hp
	turn_manager.player_charge_tick()
	_drain_log()
	fx.hp_feedback(player_hp_before, combat.player.hp, player_panel)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)
	_after_player_input()

func _on_card_clicked(index: int) -> void:
	if turn_manager.is_over() or combat.active_side != "player" or turn_manager.awaiting_player_claims:
		return
	if swap_picking:
		# 架势选弃：点选＝标记弃置，至多 4 张
		if index in selected_indices:
			selected_indices.erase(index)
		elif selected_indices.size() >= TurnManager.SWAP_MAX:
			log_lines.append("提示：架势一次至多弃 %d 张" % TurnManager.SWAP_MAX)
			_render_log()
			return
		else:
			selected_indices.append(index)
		_refresh_ui()
		return
	if armed_technique.is_empty():
		# 未装配：自由凝招；牌型上限 3 张
		if index in selected_indices:
			selected_indices.erase(index)
		elif selected_indices.size() >= PatternEvaluator.MAX_PATTERN_SIZE:
			log_lines.append("提示：选牌上限 %d 张，请先点掉已选真气" % PatternEvaluator.MAX_PATTERN_SIZE)
			_render_log()
			return
		else:
			selected_indices.append(index)
		_refresh_ui()
		return
	# 装配中：真气逐颗入孔/出孔，三张为限
	if index in selected_indices:
		selected_indices.erase(index)
		_refresh_ui()
		return
	if selected_indices.size() >= PatternEvaluator.PATTERN_SIZE:
		log_lines.append("提示：%s 需嵌 %d 张真气，请先点掉已入孔的真气" % [armed_technique, PatternEvaluator.PATTERN_SIZE])
		_refresh_ui()
		return
	selected_indices.append(index)
	_refresh_ui()

func _on_technique_clicked(technique_id: String) -> void:
	if turn_manager.is_over() or combat.active_side != "player" or turn_manager.awaiting_player_claims:
		return
	if swap_picking:
		return  # 选弃中不装配
	# 点功法（一次）＝装配：已选真气带入镶孔，满足即待确认；还缺则智能补齐。
	armed_technique = technique_id
	if not _can_player_use(technique_id):
		var completed := TechniqueResolver.find_legal_selection_containing(
			technique_id, combat.player.hand, _selected_cards(), combat.player)
		if completed.is_empty():
			log_lines.append("提示：无法以当前已选真气凑成 %s —— %s" % [technique_id, _technique_block_reason(technique_id)])
			_refresh_ui()
			return
		_apply_selection(completed)
	_log_action("操作：装配 %s（真气：%s）" % [technique_id, _cards_text(_selected_cards())])
	_refresh_ui()

# ---------- 玩家截牌窗（敌方架势弃牌入河后流动挂起；截即打＝主动夺取不补满） ----------

func _maybe_offer_claims(awaiting: bool) -> void:
	if not awaiting or sequencer.busy or turn_manager.is_over() or _popup_kind != "":
		return
	var options := turn_manager.player_claim_options()
	if options.is_empty():
		_release_claim_window()
		return
	_open_claim_popup(options)

func _open_claim_popup(options: Array) -> void:
	_popup_kind = "claim"
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.949, 0.91, 0.835)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.169, 0.141, 0.11)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "它弃入牌河的真气，你可截下当场轰出"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.15, 0.12, 0.09))
	box.add_child(title)
	for option in options:
		var card: QiCard = option["card"]
		var kind := str(option["kind"])
		var label := "%s %s → 轰出【%s】" % [kind, card.display_name(), str(option.get("technique", ""))]
		if kind == "杠":
			label += "（升档＋它露出破绽）"
		var button := Button.new()
		button.text = label
		button.pressed.connect(_on_claim_chosen.bind(option))
		box.add_child(button)
	var skip := Button.new()
	skip.text = "放行（窗口作废，正常行动）"
	skip.pressed.connect(func():
		_close_popups())
	box.add_child(skip)
	var hint := Label.new()
	hint.text = "（截＝主动夺取，不补满丹田；可连续截——截完行动权流向敌方）"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.4, 0.36, 0.3))
	box.add_child(hint)
	_popup_host.open_centered(panel)

func _on_claim_chosen(option: Dictionary) -> void:
	var kind := str(option.get("kind", ""))
	var card: QiCard = option.get("card", null)
	_log_action("操作：截牌 %s %s → %s" % [kind, card.display_name() if card != null else "", str(option.get("technique", ""))])
	var enemy_hp_before := combat.enemy.hp
	var player_hp_before := combat.player.hp
	turn_manager.player_claim_fire(option)
	_close_popups()
	_drain_log()
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)
	fx.hp_feedback(player_hp_before, combat.player.hp, player_panel)
	_after_player_input()

# 放行（跳过/ESC 关窗同路）：窗口作废，被动获得行动权（补满）后正常行动。
func _release_claim_window() -> void:
	if turn_manager == null or not turn_manager.awaiting_player_claims:
		return
	turn_manager.player_release_flow()
	_drain_log()
	_after_player_input()

# ---------- 弹窗（设置/截牌共用宿主） ----------

func _on_settings_pressed() -> void:
	if _popup_kind == "settings":
		_close_popups()
		return
	_open_settings_popup()

func _close_popups() -> void:
	_popup_kind = ""
	_popup_host.close()

func _open_settings_popup() -> void:
	_popup_kind = "settings"
	var popup := BattleSettingsPopup.new()
	popup.setup(_pace)
	popup.pace_selected.connect(func(factor: float):
		_pace = factor
		fx.pace = factor
		_open_settings_popup())
	popup.abandon_requested.connect(_abandon_battle)
	popup.close_requested.connect(func(): _close_popups())
	_popup_host.open(top_bar, popup)

# 弃战：结束演练，回主菜单。
func _abandon_battle() -> void:
	sequencer.interrupt()
	if combat_log != null:
		combat_log.write("操作：弃战（主动结束演练）")
	DojoConfig.clear()
	get_tree().change_scene_to_file(SceneRoutes.TITLE)

# ESC：弹窗开着由 PopupHost 消费关闭；这里只管战报罩层开关。
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not end_overlay.visible:
			log_overlay.visible = not log_overlay.visible
			if log_overlay.visible:
				_render_log()

func _selected_cards() -> Array:
	var cards: Array = []
	for index in selected_indices:
		if index >= 0 and index < combat.player.hand.size():
			cards.append(combat.player.hand[index])
	return cards

func _apply_selection(selection: Array) -> void:
	selected_indices = []
	for card in selection:
		var index := combat.player.hand.find(card)
		if index >= 0:
			selected_indices.append(index)

func _on_log_button_pressed() -> void:
	log_overlay.visible = true
	_render_log()

func _on_log_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		log_overlay.visible = false

func _drain_log(used_qi: Array = []) -> void:
	var drained := turn_manager.drain_messages()
	if combat_log != null:
		for message in drained:
			combat_log.write(message)
	log_lines.append_array(drained)
	_log_snapshot()
	if not drained.is_empty():
		var hand_colors: Array = []
		for card in combat.player.hand:
			hand_colors.append(QiOrb.color_for_attribute(str(card.attribute)))
		for message in drained:
			fx.play_message(String(message), used_qi, hand_colors)

func _log_action(text: String) -> void:
	if combat_log != null:
		combat_log.write(text)

# 顶栏战报行显示最新一条（按事件类型着色）；展开罩层显示全部（同套配色）。
func _render_log() -> void:
	var colors: Array = []
	for line in log_lines:
		colors.append(_log_line_color(line))
	battle_log.set_lines(log_lines, colors)
	var latest: String = log_lines.back() if not log_lines.is_empty() else " "
	top_bar.set_log_line(latest, _log_line_color(latest))

# 双边状态快照行：气血/护境/丹田（手牌）/气海余量/我河/副露；敌方加力层与意图。
func _log_snapshot() -> void:
	if combat_log == null or combat == null:
		return
	var p := combat.player
	var e := combat.enemy
	var player_text := "你 气血%d/%d 护境%d 丹田%d 气海%d 我河%d 副露%d" % [
		p.hp, p.max_hp, p.guard, p.hand.size(), combat.qi_wall.size(),
		combat.river_of("player").size(), p.melds.size()]
	var enemy_text := "%s 气血%d/%d 护境%d 丹田%d 力%d 意图[%s]" % [
		e.display_name, e.hp, e.max_hp, e.guard, e.hand.size(), e.get_status("li"),
		str(turn_manager.enemy_intent.get("label", ""))]
	combat_log.write("快照｜%s ｜ %s" % [player_text, enemy_text])

# 战报行事件配色：我方功法金、敌方功法朱红、架势青、截牌紫红、疲劳橙黄提示。
func _log_line_color(line: String) -> Color:
	if line.begins_with("你发动") or line.begins_with("你蓄力已满") or line.begins_with("战斗结束：你获胜"):
		return BP.COLOR_GOLD
	if line.begins_with("敌方发动") or line.begins_with("敌方蓄力已满") or line.begins_with("战斗结束：你败北"):
		return BP.COLOR_ENEMY
	if line.contains("截下") or line.contains("连锅") or line.contains("当场轰出"):
		return Color(0.72, 0.4, 0.62)
	if line.begins_with("你架势") or line.begins_with("敌方架势"):
		return Color(0.38, 0.62, 0.72)
	if line.contains("反噬") or line.begins_with("提示") or line.contains("护境被击碎") or line.contains("露出破绽") or line.contains("已涸"):
		return BP.COLOR_HINT
	if line.begins_with("——") or line.begins_with("战斗结束"):
		return BP.COLOR_TURN_END
	return BP.COLOR_BODY

func _combat_result() -> String:
	if combat == null or turn_manager == null or not turn_manager.is_over():
		return ""
	if not combat.enemy.is_alive():
		return "player"
	return "enemy"

# 意图悬浮预览：即将行动的效果明码（功法走效果摘要；架势披露策略）。
func _intent_preview() -> String:
	var action := str(turn_manager.enemy_intent.get("action", ""))
	var technique := str(turn_manager.enemy_intent.get("technique", ""))
	if action == "swap":
		return "敌方下一拍：架势（弃牌入它的牌河——不喂你就好；弃置策略：%s）" % _swap_policy_text()
	if technique.is_empty():
		return "无"
	if combat.enemy.has_active_charge():
		return "蓄力中：%s——引而不发（蓄力期间它不可截牌）" % technique
	return "敌方下一拍：%s（%s）" % [technique, TechniqueResolver.effect_summary(technique)]

# 应读数（实时，取代原截牌灯）：它此刻能截哪些牌——你架势弃牌前看得见雷区；
# 悬浮披露"弃什么会被怎么截"。蓄力中全哑（蓄力锁）。
func _threat_text() -> String:
	var threats := combat.claim_threats(combat.enemy)
	if threats.is_empty():
		return "应·哑" if not combat.enemy.has_active_charge() else "应·哑（蓄力中）"
	var parts: Array[String] = []
	for threat in threats:
		parts.append("%s%s%d" % [str(threat.get("claim", "")), str(threat.get("attribute", "")), int(threat.get("value", 0))])
	return "应·" + "｜".join(parts)

func _threat_tooltip() -> String:
	var threats := combat.claim_threats(combat.enemy)
	if combat.enemy.has_active_charge():
		return "应·哑：它蓄力中（蓄力锁——起蓄不可截牌），你的弃牌暂时安全"
	if threats.is_empty():
		return "应·哑：它此刻截不了任何牌（搭子不齐或功法都在冷却）——弃牌安全窗"
	var lines: Array[String] = []
	lines.append("应（实时活算）：你架势弃入这些牌会被它截下当场轰出——")
	for threat in threats:
		var claim := str(threat.get("claim", ""))
		var spec := "%s%d" % [str(threat.get("attribute", "")), int(threat.get("value", 0))]
		match claim:
			"杠":
				lines.append("【杠 %s】它手握三张——弃出即被升档轰出，你还中一枚破绽" % spec)
			"碰":
				lines.append("【碰 %s】它手握两张——弃出即被组刻轰出" % spec)
			_:
				lines.append("【吃 %s】它手握连张——弃出即被组顺轰出" % spec)
	return "\n".join(lines)

func _swap_policy_text() -> String:
	return {
		"all": "全换", "low_value": "弃低值", "high_value": "弃高值",
		"singletons": "弃孤张",
	}.get(str(combat.enemy.enemy_def.get("swap_policy", "all")), "全换")

# 终局结算：文案在此计算，呈现交给 BattleEndOverlay。
func _show_end_overlay() -> void:
	if end_overlay.visible or combat == null or turn_manager == null or not turn_manager.is_over():
		return
	var over := _combat_result()
	if over.is_empty():
		return
	if combat_log != null:
		var verdict := "胜（敌方气绝）" if over == "player" else "负（我方气绝）"
		combat_log.write("战斗结束：%s ｜ 历经 %d 次行动、%d 次架势" % [
			verdict, combat.action_count, combat.player_swap_count])
		_log_snapshot()
	var lines: Array[String] = ["历经 %d 次行动、%d 次架势。" % [combat.action_count, combat.player_swap_count]]
	match over:
		"player":
			lines.append("你尚余 %d/%d 气血。" % [combat.player.hp, combat.player.max_hp])
		"enemy":
			lines.append("致命一击：%s" % _killing_blow_text())
	_close_popups()
	end_overlay.show_result(over, lines)

# 从战报里倒查致命一击（最后一条"敌方发动X"）。
func _killing_blow_text() -> String:
	for i in range(log_lines.size() - 1, -1, -1):
		var line := log_lines[i]
		if line.begins_with("敌方发动"):
			return "敌方「%s」打空了你最后的气血。" % line.get_slice("：", 0).trim_prefix("敌方发动")
	return "你气血耗尽，倒在了对手面前。"

# 重开一场：终态复位后走正常开战流程。
func _on_restart_pressed() -> void:
	sequencer.interrupt()
	end_overlay.visible = false
	log_overlay.visible = false
	_close_popups()
	_end_message_shown = false
	_techniques_built = false
	armed_technique = ""
	swap_picking = false
	selected_indices = []
	log_lines.clear()
	_start_demo()

# 战斗内状态（毒等）的胶囊文本。
func _status_names(unit: FighterState) -> String:
	var parts: Array[String] = []
	for status_id in unit.statuses:
		parts.append("%s×%d" % [StatusRuntime.status_name(str(status_id)), int(unit.statuses[status_id])])
	return ",".join(parts)

func _cards_text(cards: Array) -> String:
	var names: Array[String] = []
	for card in cards:
		names.append(card.display_name())
	return "、".join(names)
