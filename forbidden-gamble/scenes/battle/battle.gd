extends Control

const ENCOUNTER_PATH := DataRepo.SANDBOX_ENCOUNTER_PATH
const BP := preload("res://ui/battle_palette.gd")

# 牌型 → 需卡数/中文名（功法层镶孔槽数与不可用原因用；v1 属性轴，选牌上限 4）
const PATTERN_SIZES := {
	"ONE_QI": 1, "HEAVY_2": 2, "HEAVY_3": 3, "HEAVY_4": 4,
	"MIX_2": 2, "MIX_3": 3, "MIX_4": 4,
}
const PATTERN_NAMES := {
	"ONE_QI": "一气", "HEAVY_2": "二重", "HEAVY_3": "三重", "HEAVY_4": "四重",
	"MIX_2": "二合", "MIX_3": "三合", "MIX_4": "四合",
}

var combat: CombatState
var turn_manager: TurnManager
var combat_log: CombatLog
# 装配流（D-044/M7b 细化）：点功法（一次）＝装配——已选真气带入镶孔，还缺则以已选
# 为前提智能补齐，补不齐提示并保持装配态（增删真气后再点即重试）；满足条件＝待确认。
var armed_technique: String = ""
var selected_indices: Array[int] = []
# 调息选弃中（B2）：真气点击＝标记弃置（金环），确认＝弃所选纳至六口，取消＝退出。
var breathe_picking := false
var log_lines: Array[String] = []
var _end_message_shown := false
var _techniques_built := false
# 演出层（气影/横幅/飘字）与敌方连动编排（令牌/节奏）
var fx: BattleFx
var sequencer: BattleSequencer
# 演出速度档系数（设置弹窗切换，注入 fx 与 sequencer）
var _pace := 1.0
# 顶栏弹窗（设置；PopupHost 管关闭交互）
var _popup_host: PopupHost
var _popup_kind := ""  # "" / "settings"

@onready var top_bar: BattleTopBar = $Center/Column/TopBar
@onready var stage: Control = $Center/Column/Stage
@onready var player_panel: FighterPanel = $Center/Column/Stage/PlayerPanel
@onready var enemy_panel: FighterPanel = $Center/Column/Stage/EnemyPanel
@onready var confirm_button: Button = $Center/Column/Stage/CenterZone/Buttons/ConfirmButton
@onready var cancel_button: Button = $Center/Column/Stage/CenterZone/Buttons/CancelButton
@onready var breathe_button: Button = $Center/Column/Stage/CenterZone/Buttons/BreatheButton
@onready var buttons_row: Control = $Center/Column/Stage/CenterZone/Buttons
@onready var hand_layer: HandBar = $Center/Column/HandLayer
@onready var tech_layer: TechniqueBar = $Center/Column/TechLayer
@onready var log_overlay: Control = $LogOverlay
@onready var battle_log = $LogOverlay/Panel
# 终局结算浮层（胜/败/平摘要 + 战报/重开/返回）
@onready var end_overlay: BattleEndOverlay = $EndOverlay

func _ready() -> void:
	confirm_button.pressed.connect(_confirm_pending)
	cancel_button.pressed.connect(_cancel_pending)
	breathe_button.pressed.connect(_on_breathe_pressed)
	end_overlay.report_requested.connect(func(): log_overlay.visible = true)
	end_overlay.restart_requested.connect(_on_restart_pressed)
	end_overlay.return_requested.connect(_on_return_to_map)
	top_bar.report_pressed.connect(_on_log_button_pressed)
	top_bar.settings_pressed.connect(_on_settings_pressed)
	# 演出挂载层：全屏、忽略鼠标，横幅/幽灵/飘字都进这层——绝不进 Column（VBox 会把
	# 演出节点当布局孩子排位，撑破 720 定高）。压在舞台之上、弹窗之下。
	var fx_layer := Control.new()
	fx_layer.name = "FxLayer"
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	_popup_host = PopupHost.new()
	_popup_host.closed.connect(func(): _popup_kind = "")
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
	# 点面板本体也要能关：面板/滚动容器各自 STOP，未接受的事件不冒泡到罩层——
	# 把关闭 handler 直接挂到点击实际落点的两层上。
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
			combat.player.draw_pile.clear()
			combat.player.hand.clear()
			combat.player.discard_pile.clear()
			for i in range(DojoConfig.deck.size()):
				var dc: Dictionary = DojoConfig.deck[i]
				combat.player.draw_pile.append(QiCard.new(
					str(dc.get("id", "")), str(dc.get("attribute", "")), int(dc.get("grade", 1))))
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
	# 被袭击（敌方先手）：开场即敌方回合——敌方第一击必须由演出链自动打出，
	# 否则场景停在"敌方行动"却无人推进（按钮全隐、手牌锁死，玩家无法操作）。
	if not turn_manager.is_over() and combat.active_side == "enemy":
		sequencer.play(turn_manager, combat)

# 顶栏遭遇名：标注演练（C-017 口径延续，演武场唯一入口）。
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
	# 蓄力占用玩家的行动机会：充能拍自动执行（延后一帧跑，避免在刷新中递归）
	var charging_now := player_turn and combat.player.has_active_charge() and not sequencer.busy
	# 回合·行动方（顶栏）：演出时按钮全隐，这是全场唯一的"轮到谁"指示
	if not over.is_empty():
		var end_text := "—— 你败北了 ——"
		if over == "player":
			end_text = "—— 你获胜了 ——"
		top_bar.set_turn(end_text, BP.COLOR_TURN_END)
	elif player_turn:
		top_bar.set_turn("第 %d 口气 · ▶ 你的行动" % (combat.player_breath_count + 1), BP.COLOR_GOLD)
	else:
		top_bar.set_turn("第 %d 口气 · …… 敌方行动" % (combat.player_breath_count + 1), BP.COLOR_ENEMY)
	# 对战区双面板
	_update_panel(player_panel, combat.player, false)
	_update_panel(enemy_panel, combat.enemy, true)
	# 经脉手牌层（蓄力充能拍期间手牌不可操作——这一拍没有选择）
	hand_layer.set_piles(combat.player.draw_pile.size(), combat.player.discard_pile.size())
	hand_layer.set_meld_info(_meld_info_text(player_turn))
	hand_layer.set_hand(combat.player.hand, selected_indices, player_turn and not charging_now)
	# 功法层（卡位每场战斗建一次，四态随每次刷新）
	if not _techniques_built:
		tech_layer.set_techniques(_technique_entries())
		_techniques_built = true
	tech_layer.set_states(_technique_states(player_turn))
	# 中央操作按钮两组互换：未装配＝只显示[调息]（B2：调息进选弃流）；装配中/待确认/
	# 调息选弃＝只显示[确认][取消]；敌方回合与演出停顿整行隐藏；蓄力充能拍无按钮。
	buttons_row.visible = player_turn and not sequencer.busy and not charging_now
	var armed := not armed_technique.is_empty()
	var picking := breathe_picking
	confirm_button.visible = armed or picking
	cancel_button.visible = armed or picking
	breathe_button.visible = not armed and not picking
	# 可用性：确认需牌型齐（装配不完整保持灰，原因在功法卡与信息行）；
	# 调息选弃的确认恒可用（弃 0 张＝只补不弃）。
	if picking:
		confirm_button.disabled = false
	else:
		confirm_button.disabled = not _can_player_use(armed_technique)
	cancel_button.disabled = false
	if picking:
		confirm_button.text = "调息（弃 %d）" % selected_indices.size()
	elif confirm_button.text != "确认":
		confirm_button.text = "确认"
	breathe_button.disabled = false
	_render_log()
	if charging_now:
		call_deferred("_auto_charge_tick")

func _update_panel(panel: FighterPanel, unit: FighterState, is_enemy: bool) -> void:
	panel.fighter_name = unit.display_name
	panel.max_hp = unit.max_hp
	panel.hp = unit.hp
	panel.guard = unit.guard
	panel.status_names = _status_names(unit)
	# 心法胶囊（D-060）：敌我装备心法都竖排披露，悬浮显示效果文本
	panel.xinfa_names = ",".join(unit.xinfa)
	if is_enemy:
		# 敌方（敌方系统 v2）：意图＝脑锁定的即将行动（功法名/调息/蓄力招，活读数——
		# 钩子翻牌时实时变化，翻转即演出）；应手灯常驻披露绊线状态（明码：悬浮看配置）；
		# 手牌张数公开（内容不透明——罚行不罚藏）。
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
		panel.hook_lamp_text = _hook_lamp_text()
		panel.hook_lamp_tooltip = _hook_lamp_tooltip()
	else:
		# 我方：准备槽显示装配中功法（C-011）；蓄力期间改显蓄力进度
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
	if combat.player.has_active_charge():
		var ch: Dictionary = combat.player.charging
		return "蓄力中：%s（%d/%d）——引而不发，充能拍自动执行" % [str(ch.get("technique", "")), int(ch.get("charge", 0)), int(ch.get("need", 0))]
	if breathe_picking:
		return "调息选弃：点真气标记弃置（已标 %d 张）——[确认] 弃所选并纳至 %d 口，弃 0 张＝只补不弃" % [
			selected_indices.size(), TurnManager.HAND_SIZE]
	if not armed_technique.is_empty():
		var armed_selected := _selected_cards()
		if _can_player_use(armed_technique):
			return "待确认：%s（%s · 真气量 %d）—— [确认] 发动，[取消] 重选" % [
				armed_technique, _cards_text(armed_selected), _qi_amount_for(armed_technique, armed_selected)]
		var slot_total := _slot_count_for(armed_technique)
		return "装配中：%s —— 已入孔 %d/%d 张未凑成条件，增删真气后再点功法卡重试" % [
			armed_technique, armed_selected.size(), slot_total]
	var selected := _selected_cards()
	if not selected.is_empty():
		var names: Array[String] = []
		for pattern in PatternEvaluator.evaluate(selected):
			names.append(PATTERN_NAMES.get(str(pattern), str(pattern)))
		if names.is_empty():
			return "已选 %d 张真气（未成牌型）· 品级合计 %d" % [selected.size(), _grade_sum(selected)]
		return "凝招：%s · 品级合计 %d" % ["/".join(names), _grade_sum(selected)]
	if not combat.player.has_legal_action():
		return "手牌凑不成功法：可【调息】弃掉不要的、纳至满手（弃 0 张＝只补不弃）"
	return "点功法卡：带入已选真气并智能补齐，凑成即待确认"

# 功法层卡位数据：等级、效果摘要、镶孔槽数与排布（按所需牌型最大张数）。
func _technique_entries() -> Array:
	var entries: Array = []
	for technique_id in combat.player.techniques:
		var data := TechniqueResolver.data_for(technique_id)
		var slot_count := _slot_count_for(technique_id)
		var layout: int = QiSlotGroup.SlotLayout.UNIFORM
		if slot_count == 4:
			layout = QiSlotGroup.SlotLayout.ARCH
		entries.append({
			"id": technique_id,
			"name": technique_id,
			"effect": TechniqueResolver.effect_summary(technique_id),
			"level": int(data.get("level", 1)),
			"slot_count": slot_count,
			"slot_layout": layout,
		})
	return entries

# 功法四态（D-044）：PENDING 待确认填珠 / SATISFIED 当前选择满足 / UNUSABLE 压灰注原因。
func _technique_states(player_turn: bool) -> Dictionary:
	var states := {}
	for technique_id in combat.player.techniques:
		var state: int = TechniqueCard.CardState.NORMAL
		var reason := ""
		var fill: Array = []
		if armed_technique == technique_id:
			# 装配中（含待确认）：金边加粗，已入孔真气按选择顺序填色
			state = TechniqueCard.CardState.PENDING
			for card in _selected_cards():
				fill.append(QiOrb.color_for_attribute(str(card.attribute)))
		elif player_turn:
			# 其余卡照常按当前手牌+选择计算四态（装配中也要保持压灰与原因，不因选中功法而"解锁"）
			if _can_player_use(technique_id):
				state = TechniqueCard.CardState.SATISFIED
			else:
				reason = _technique_block_reason(technique_id)
				if not reason.is_empty():
					state = TechniqueCard.CardState.UNUSABLE
		states[technique_id] = {"state": state, "reason": reason, "fill": fill}
	return states

# 不可用原因：蓄力占用行动机会 / 冷却中 / 手牌凑不出牌型（顺序即优先级）。
# 牌型可达性直接问 TechniqueResolver（find_legal_selection 位掩码枚举），不再手抄一份。
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
	if breathe_picking:
		confirm_breathe()
		return
	if armed_technique.is_empty() or turn_manager.is_over():
		return
	if not _can_player_use(armed_technique):
		return
	_log_action("操作：确认发动 %s" % armed_technique)
	# 先快照已选珠的台上位置（发动后珠即离手，幽灵丹珠从原位起飞）
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

# 取消装配：功法出槽，已选真气保留（可继续微调后再装配）。
func _cancel_pending() -> void:
	if breathe_picking:
		breathe_picking = false
		selected_indices = []
		_refresh_ui()
		return
	armed_technique = ""
	_refresh_ui()

# 调息（B2）：进入选弃流——点真气＝标记弃置，确认＝弃所选＋纳至六口（费一拍）。
func _on_breathe_pressed() -> void:
	if turn_manager.is_over() or combat.active_side != "player" or sequencer.busy:
		return
	if combat.player.has_active_charge():
		return
	armed_technique = ""
	breathe_picking = true
	selected_indices = []
	_refresh_ui()

# 确认调息：弃所选（可为 0 张＝只补不弃）入气海，纳至六口。
func confirm_breathe() -> void:
	breathe_picking = false
	var indices := selected_indices.duplicate()
	_log_action("操作：调息（弃 %d 口：%s）" % [indices.size(), _cards_text(_selected_cards())])
	selected_indices = []
	turn_manager.player_breathe(indices)
	_drain_log()
	_after_player_input()

# 玩家输入后的统一尾巴：刷新一帧，随后敌方连动逐条演出；终局停一拍再弹结算浮层。
func _after_player_input() -> void:
	_refresh_ui()
	sequencer.play(turn_manager, combat)

# 敌方连动单步（内容注入 sequencer）：结算一拍 + 逐条呈现（日志窄条/血条/飘字）。
func _enemy_step() -> void:
	var player_hp_before := combat.player.hp
	var enemy_hp_before := combat.enemy.hp
	turn_manager.enemy_act()
	_drain_log()
	_refresh_ui()
	fx.hp_feedback(player_hp_before, combat.player.hp, player_panel)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)

# 蓄力充能拍（26 号 §5）：玩家持有行动权且有蓄力时自动执行——+1 充能或满值发动。
# 由 _refresh_ui 延后一帧调度（避免刷新内递归）；执行后走统一尾巴（敌方连动演出）。
func _auto_charge_tick() -> void:
	if combat == null or turn_manager == null or turn_manager.is_over() or sequencer.busy:
		return
	if combat.active_side != "player" or not combat.player.has_active_charge():
		return
	var enemy_hp_before := combat.enemy.hp
	var player_hp_before := combat.player.hp
	turn_manager.player_charge_tick()
	_drain_log()
	fx.hp_feedback(player_hp_before, combat.player.hp, player_panel)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)
	_after_player_input()

func _on_card_clicked(index: int) -> void:
	if turn_manager.is_over() or combat.active_side != "player":
		return
	if breathe_picking:
		# 调息选弃：点选＝标记弃置（金环），无张数上限（弃 0～全部皆合法）
		if index in selected_indices:
			selected_indices.erase(index)
		else:
			selected_indices.append(index)
		_refresh_ui()
		return
	if armed_technique.is_empty():
		# 未装配：自由凝招（点功法后带入）；牌型上限 4 张，超过先点掉已选
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
	# 装配中：真气逐颗入孔/出孔，超过功法孔数上限时拦截
	if index in selected_indices:
		selected_indices.erase(index)
		_refresh_ui()
		return
	if selected_indices.size() >= _slot_count_for(armed_technique):
		log_lines.append("提示：%s 最多嵌 %d 张真气，请先点掉已入孔的真气" % [armed_technique, _slot_count_for(armed_technique)])
		_render_log()
		return
	selected_indices.append(index)
	_refresh_ui()

func _on_technique_clicked(technique_id: String) -> void:
	if turn_manager.is_over() or combat.active_side != "player":
		return
	if breathe_picking:
		return  # 选弃中不装配：先取消调息再点功法
	# 点功法（一次）＝装配：已选真气带入镶孔，满足即待确认；还缺则智能补齐（以已选为
	# 前提补最少张数）；补不齐提示原因并保持装配态，增删真气后再点功法即重试。
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

# 把一组真气设为当前选择（金环+镶孔按此顺序填色）。
func _apply_selection(selection: Array) -> void:
	selected_indices = []
	for card in selection:
		var index := combat.player.hand.find(card)
		if index >= 0:
			selected_indices.append(index)

# 功法镶孔数（按所需牌型最大张数）。
func _slot_count_for(technique_id: String) -> int:
	var slot_count := 1
	for pattern in TechniqueResolver.data_for(technique_id).get("patterns", []):
		slot_count = maxi(slot_count, int(PATTERN_SIZES.get(str(pattern), 1)))
	return slot_count

func _on_log_button_pressed() -> void:
	log_overlay.visible = true
	_render_log()

func _on_log_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		log_overlay.visible = false

# ---- 顶栏弹窗（设置，PopupHost 管定位/点外关闭/ESC） ----

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
		_open_settings_popup())  # 重开面板＝刷新当前档禁用态，弹窗保持打开
	popup.abandon_requested.connect(_abandon_battle)
	popup.close_requested.connect(func(): _close_popups())
	_popup_host.open(top_bar, popup)

# 弃战（C-017 定案）：结束演练，回主菜单。"逃跑"另立项为道具（随物资系统，已随远征下架）。
func _abandon_battle() -> void:
	sequencer.interrupt()
	if combat_log != null:
		combat_log.write("操作：弃战（主动结束演练）")
	DojoConfig.clear()
	get_tree().change_scene_to_file(SceneRoutes.TITLE)

# ESC：弹窗开着由 PopupHost 消费关闭；这里只管战报罩层开关；终局结算浮层不响应（出口须明确点选）。
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

func _drain_log(used_qi: Array = []) -> void:
	var drained := turn_manager.drain_messages()
	if combat_log != null:
		for message in drained:
			combat_log.write(message)
	# 日志保留完整历史，窄条显示最新一条，展开罩层滚动回看全场。
	log_lines.append_array(drained)
	# 每拍末快照（试玩复盘口径）：一行读全双边状态，免去事后手工推血。
	_log_snapshot()
	# 消息驱动的演出在刷新 UI 前播（见 BattleFx.play_message 注释）
	if not drained.is_empty():
		var hand_colors: Array = []
		for card in combat.player.hand:
			hand_colors.append(QiOrb.color_for_attribute(str(card.attribute)))
		for message in drained:
			fx.play_message(String(message), used_qi, hand_colors)

func _log_action(text: String) -> void:
	if combat_log != null:
		combat_log.write(text)

# 双边状态快照行：气血/护境/手牌与牌堆；敌方加力层与意图（对手卡同核，牌堆口径与玩家一致）。
func _log_snapshot() -> void:
	if combat_log == null or combat == null:
		return
	var p := combat.player
	var e := combat.enemy
	var player_text := "你 气血%d/%d 护境%d 手牌%d 丹田%d 气海%d" % [
		p.hp, p.max_hp, p.guard, p.hand.size(), p.draw_pile.size(), p.discard_pile.size()]
	var enemy_text := "%s 气血%d/%d 护境%d 手牌%d 丹田%d 气海%d 力%d 意图[%s]" % [
		e.display_name, e.hp, e.max_hp, e.guard, e.hand.size(), e.draw_pile.size(),
		e.discard_pile.size(), e.get_status("li"),
		str(turn_manager.enemy_intent.get("label", ""))]
	combat_log.write("快照｜%s ｜ %s" % [player_text, enemy_text])

# 顶栏战报行显示最新一条（按事件类型着色）；展开罩层显示全部（同套配色）。
func _render_log() -> void:
	var colors: Array = []
	for line in log_lines:
		colors.append(_log_line_color(line))
	battle_log.set_lines(log_lines, colors)
	var latest: String = log_lines.back() if not log_lines.is_empty() else " "
	top_bar.set_log_line(latest, _log_line_color(latest))

# 战报行事件配色：我方功法金、敌方功法朱红、提示黄、回合/终态分隔灰蓝。
func _log_line_color(line: String) -> Color:
	if line.begins_with("你发动") or line.begins_with("你蓄力已满") or line.begins_with("战斗结束：你获胜"):
		return BP.COLOR_GOLD
	if line.begins_with("敌方发动") or line.begins_with("敌方蓄力已满") or line.begins_with("敌方调息") or line.begins_with("战斗结束：你败北"):
		return BP.COLOR_ENEMY
	if line.begins_with("提示") or line.contains("护境被击碎") or line.contains("露出破绽") or line.contains("改招") or line.contains("改出"):
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

# 意图悬浮预览（敌方系统 v2）：即将行动的效果明码（功法走效果摘要；调息披露策略）。
func _intent_preview() -> String:
	var action := str(turn_manager.enemy_intent.get("action", ""))
	var technique := str(turn_manager.enemy_intent.get("technique", ""))
	if action == "breathe":
		return "敌方下一拍：调息（回填手牌，弃置策略：%s）" % _breathe_policy_text()
	if technique.is_empty():
		return "无"
	if combat.enemy.has_active_charge():
		return "蓄力中：%s——引而不发（蓄力期间它的钩子全部下线）" % technique
	return "敌方下一拍：%s（%s）" % [technique, TechniqueResolver.effect_summary(technique)]

func _hook_lamp_text() -> String:
	var parts: Array[String] = []
	for lamp in combat.enemy_brain.hook_lamps(combat.enemy):
		var short := str(lamp.get("technique", ""))
		match str(lamp.get("state", "")):
			"ready":
				short += "·亮"
			"cooldown":
				short += "·歇%d" % int(lamp.get("cooldown", 0))
			_:
				short += "·哑"
		parts.append(short)
	return "，".join(parts)

func _hook_lamp_tooltip() -> String:
	var parts: Array[String] = []
	for lamp in combat.enemy_brain.hook_lamps(combat.enemy):
		parts.append(str(lamp.get("tooltip", "")))
	return "\n".join(parts)

func _breathe_policy_text() -> String:
	return {
		"all": "全换", "low_grade": "只换下品", "high_grade": "弃上品",
		"singletons": "弃孤张",
	}.get(str(combat.enemy.enemy_def.get("breathe_policy", "all")), "全换")

# 终局结算：文案在此计算，呈现交给 BattleEndOverlay（重开一场 / 回演武场两个出口）。
func _show_end_overlay() -> void:
	if end_overlay.visible or combat == null or turn_manager == null or not turn_manager.is_over():
		return
	var over := _combat_result()
	if over.is_empty():
		return
	# 结局先行落盘：用户可能在结算浮层直接关窗（_exit_tree 不保证走到），
	# 胜负与终局快照必须在浮层弹出这一刻就写进日志。
	if combat_log != null:
		var verdict := "胜（敌方气绝）" if over == "player" else "负（我方气绝）"
		combat_log.write("战斗结束：%s ｜ 历经 %d 次行动、%d 口气" % [
			verdict, combat.action_count, combat.player_breath_count])
		_log_snapshot()
	var lines: Array[String] = ["历经 %d 次行动、%d 口气。" % [combat.action_count, combat.player_breath_count]]
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
	breathe_picking = false
	selected_indices = []
	log_lines.clear()
	_start_demo()

# 战斗内状态（毒等）的胶囊文本，逗号分隔（fighter_panel 拆分）；无状态返回空串。
func _status_names(unit: FighterState) -> String:
	var parts: Array[String] = []
	for status_id in unit.statuses:
		parts.append("%s×%d" % [StatusRuntime.status_name(str(status_id)), int(unit.statuses[status_id])])
	return ",".join(parts)

# 品级合计（自由凝招时的浏览值；真气量以功法等级为锚，见 _qi_amount_for）
func _grade_sum(cards: Array) -> int:
	var total := 0
	for card in cards:
		total += int(card.grade)
	return total

# 当前选择喂给某门功法的真气量（装配态信息行用）
func _qi_amount_for(technique_id: String, cards: Array) -> int:
	var level := int(TechniqueResolver.data_for(technique_id).get("level", 1))
	return QiAmountCalculator.qi_amount(cards, level)

func _cards_text(cards: Array) -> String:
	var names: Array[String] = []
	for card in cards:
		names.append(card.display_name())
	return "、".join(names)
