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
var log_lines: Array[String] = []
var _end_message_shown := false
var _techniques_built := false
# 演出层（气影/横幅/飘字）与敌方连动编排（令牌/节奏）
var fx: BattleFx
var sequencer: BattleSequencer
# 演出速度档系数（设置弹窗切换，注入 fx 与 sequencer）
var _pace := 1.0
# 顶栏弹窗（设置/背包，互斥；PopupHost 管关闭交互）
var _popup_host: PopupHost
var _popup_kind := ""  # "" / "settings" / "bag"

@onready var top_bar: BattleTopBar = $Center/Column/TopBar
@onready var stage: Control = $Center/Column/Stage
@onready var player_panel: FighterPanel = $Center/Column/Stage/PlayerPanel
@onready var enemy_panel: FighterPanel = $Center/Column/Stage/EnemyPanel
@onready var confirm_button: Button = $Center/Column/Stage/CenterZone/Buttons/ConfirmButton
@onready var cancel_button: Button = $Center/Column/Stage/CenterZone/Buttons/CancelButton
@onready var pass_button: Button = $Center/Column/Stage/CenterZone/Buttons/PassButton
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
	pass_button.pressed.connect(_on_lift_pressed)
	breathe_button.pressed.connect(_on_breathe_pressed)
	end_overlay.report_requested.connect(func(): log_overlay.visible = true)
	end_overlay.restart_requested.connect(_on_restart_pressed)
	end_overlay.return_requested.connect(_on_return_to_map)
	top_bar.report_pressed.connect(_on_log_button_pressed)
	top_bar.bag_pressed.connect(_on_bag_pressed)
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
	fx.setup(stage, hand_layer, player_panel, fx_layer)
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
	var ctx := ExpeditionSession.take_battle_context()
	if DojoConfig.active:
		# 演武场：敌人来自 enemies.json，构筑/兵器来自 DojoConfig（选敌→选构筑→对战）
		var dplayer := EncounterLoader.load_player(ExpeditionSession.PLAYER_CONFIG_PATH)
		var denemy := EncounterLoader.load_enemy(ExpeditionSession.ENEMIES_PATH, DojoConfig.enemy_id)
		if dplayer == null or denemy == null:
			log_lines.append("演武场配置加载失败：" + DojoConfig.enemy_id)
			_refresh_ui()
			return
		combat = CombatState.new(dplayer, denemy)
		combat.battle_seed = randi()
		combat.player.weapon_school = DojoConfig.weapon_school
		combat.player.weapon_level = DojoConfig.weapon_level
		combat.player.armor_defend = DojoConfig.armor_defend
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
	elif ExpeditionSession.is_in_expedition() and not str(ctx["enemy_id"]).is_empty():
		# 远征模式：玩家配置 + 敌人表中由地图掷出的敌人
		var player := EncounterLoader.load_player(ExpeditionSession.PLAYER_CONFIG_PATH)
		var enemy := EncounterLoader.load_enemy(ExpeditionSession.ENEMIES_PATH, str(ctx["enemy_id"]))
		if player == null or enemy == null:
			log_lines.append("战斗配置加载失败：" + str(ctx["enemy_id"]))
			_refresh_ui()
			return
		combat = CombatState.new(player, enemy)
		combat.battle_seed = int(ctx["seed"])
		# 气血贯通：以上一场战斗结束时的气血开局
		combat.player.hp = clampi(int(ctx["player_hp"]), 1, combat.player.max_hp)
		# 穿戴载荷（M4）：兵器系别增幅 + 护具减伤，来自版图穿戴栏
		combat.player.weapon_school = str(ctx.get("weapon_school", ""))
		combat.player.weapon_level = int(ctx.get("weapon_level", 0))
		combat.player.armor_defend = int(ctx.get("armor_defend", 0))
		# 构筑载荷（D-060）：据点构筑面板配置的功法 4 位与心法 5 槽压过默认定义
		var loadout_techniques: Array = ctx.get("loadout_techniques", [])
		if not loadout_techniques.is_empty():
			combat.player.techniques.assign(loadout_techniques)
		var loadout_xinfa: Array = ctx.get("loadout_xinfa", [])
		if not loadout_xinfa.is_empty():
			combat.player.xinfa.assign(loadout_xinfa)
	else:
		combat = EncounterLoader.load(ENCOUNTER_PATH)
	if combat == null:
		log_lines.append("遭遇战配置加载失败：" + ENCOUNTER_PATH)
		_refresh_ui()
		return
	combat_log = CombatLog.new()
	print("战斗日志：", combat_log.absolute_path())
	combat_log.write("遭遇战：%s ｜ 敌人：%s ｜ 随机种子：%d" % [_encounter_desc(), combat.enemy.display_name, combat.battle_seed])
	top_bar.set_context(_context_text())
	turn_manager = TurnManager.new(combat, combat.battle_seed)
	turn_manager.start_battle(true, bool(ctx.get("enemy_first", false)) if ExpeditionSession.is_in_expedition() else false)
	_drain_log()
	_refresh_ui()
	# 被袭击（敌方先手）：开场即敌方回合——敌方第一击必须由演出链自动打出，
	# 否则场景停在"敌方行动"却无人推进（按钮全隐、手牌锁死，玩家无法操作）。
	if not turn_manager.is_over() and combat.active_side == "enemy":
		sequencer.play(turn_manager, combat)

func _encounter_desc() -> String:
	if ExpeditionSession.is_in_expedition():
		return "远征战斗"
	return ENCOUNTER_PATH

# 顶栏遭遇名：远征显示对手，沙盒标注演练（C-017）。
func _context_text() -> String:
	if combat == null:
		return " "
	if _in_expedition():
		return "远征遭遇 · %s" % combat.enemy.display_name
	return "演武场 · 演练"

func _exit_tree() -> void:
	if combat_log != null:
		combat_log.close()

func _in_expedition() -> bool:
	return ExpeditionSession.is_in_expedition()

func _report_result_to_expedition(over: String) -> void:
	if not _in_expedition():
		return
	# 气血贯通：战斗结果写回，带入下一场战斗
	ExpeditionSession.report_battle_result(
		"win" if over == "player" else "lose", combat.player.hp)

func _on_return_to_map() -> void:
	if DojoConfig.active:
		DojoConfig.clear()
		get_tree().change_scene_to_file(SceneRoutes.DOJO)
		return
	get_tree().change_scene_to_file(SceneRoutes.BOARD)

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
			"draw":
				log_lines.append("战斗结束：平局。")
		_report_result_to_expedition(over)
	var player_turn := combat.active_side == "player" and over.is_empty()
	# 蓄力占用玩家的行动机会：充能拍自动执行（延后一帧跑，避免在刷新中递归）
	var charging_now := player_turn and combat.player.has_active_charge() and not sequencer.busy
	# 回合·行动方（顶栏）：演出时按钮全隐，这是全场唯一的"轮到谁"指示
	if not over.is_empty():
		var end_text := "—— 平局 ——"
		if over == "player":
			end_text = "—— 你获胜了 ——"
		elif over == "enemy":
			end_text = "—— 你败北了 ——"
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
	# 中央操作按钮两组互换（C-018 口径延续，D-063 换轴）：未装配＝只显示[调息][提气]；
	# 装配中/待确认＝只显示[确认][取消]；敌方回合与演出停顿整行隐藏；蓄力充能拍无按钮。
	buttons_row.visible = player_turn and not sequencer.busy and not charging_now
	var armed := not armed_technique.is_empty()
	confirm_button.visible = armed
	cancel_button.visible = armed
	pass_button.visible = not armed
	breathe_button.visible = not armed
	# 可用性：确认需牌型齐（装配不完整保持灰，原因在功法卡与信息行）；提气每口气限
	# 1 次＋心法加成（长息诀），丹田/气海无牌可提时不可用；其余可见即可用。
	# 提气余量随按钮文本披露（v1 UI 标记）。
	confirm_button.disabled = armed_technique.is_empty() or not _can_player_use(armed_technique)
	cancel_button.disabled = false
	var lift_left := maxi(1 + combat.player.lift_allowance - combat.player.lifts_this_breath, 0)
	pass_button.text = "提气（余%d）" % lift_left if lift_left > 0 else "提气（已尽）"
	pass_button.disabled = lift_left == 0 \
		or (combat.player.draw_pile.is_empty() and combat.player.discard_pile.is_empty())
	breathe_button.disabled = false
	_render_log()
	if charging_now:
		call_deferred("_auto_charge_tick")

func _update_panel(panel: FighterPanel, unit: FighterState, is_enemy: bool) -> void:
	panel.fighter_name = unit.display_name
	panel.max_hp = unit.max_hp
	panel.hp = unit.hp
	panel.guard = unit.guard
	panel.armor_defend = unit.armor_defend
	panel.status_names = _status_names(unit)
	# 心法胶囊（D-060）：敌我装备心法都竖排披露，悬浮显示效果文本
	panel.xinfa_names = ",".join(unit.xinfa)
	if is_enemy:
		# 敌方：意图锁定展示 + 手牌仅计数（D-025：牌面隐藏）。行动权模型下意图
		# 可以是功法，也可以是"调息"（敌方换气的公开暴露，26 号 §6）或"蓄力"
		# （X/N 倒计时——引而不发的公开读招窗口，26 号 §5/§11.4）。
		panel.enemy_hand = unit.hand.size()
		var intent_action := str(turn_manager.enemy_intent.get("action", ""))
		var technique := str(turn_manager.enemy_intent.get("technique", "PASS"))
		if intent_action == "charging":
			panel.show_intent = true
			panel.intent_name = "%s·蓄力%d/%d" % [technique, int(turn_manager.enemy_intent.get("charge", 0)), int(turn_manager.enemy_intent.get("need", 0))]
		elif intent_action == "breathe":
			panel.show_intent = true
			panel.intent_name = "调息"
		elif intent_action == "lift_qi":
			panel.show_intent = true
			panel.intent_name = "提气"
		else:
			panel.show_intent = technique != "PASS"
			panel.intent_name = technique
		panel.set_intent_tooltip(_intent_preview())
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
		return "手牌凑不成功法：可【调息】吐故纳新换一手，或【提气】让一拍"
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
# v1 全通用功法无属性锁，内力门槛已随传输概念退役。
func _technique_block_reason(technique_id: String) -> String:
	if combat.player.has_active_charge():
		return "蓄力中"
	var cooldown_left := int(combat.player.technique_cooldowns.get(technique_id, 0))
	if cooldown_left > 0:
		return "冷却%d" % cooldown_left
	var data := TechniqueResolver.data_for(technique_id)
	var patterns: Array = data.get("patterns", [])
	var hand := combat.player.hand
	var has_pattern := false
	for mask in range(1, 1 << hand.size()):
		var subset: Array = []
		for index in range(hand.size()):
			if mask & (1 << index):
				subset.append(hand[index])
		var owned: Array[String] = PatternEvaluator.evaluate(subset)
		for pattern in patterns:
			if pattern in owned:
				has_pattern = true
				break
		if has_pattern:
			break
	if not has_pattern:
		var names: Array[String] = []
		for pattern in patterns:
			names.append(PATTERN_NAMES.get(str(pattern), str(pattern)))
		return "缺牌型·" + "/".join(names)
	return ""

func _can_player_use(technique_id: String) -> bool:
	return not selected_indices.is_empty() and TechniqueResolver.can_use(technique_id, _selected_cards(), combat.player)

func _confirm_pending() -> void:
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
	armed_technique = ""
	_refresh_ui()

func _on_lift_pressed() -> void:
	_cancel_pending()
	_log_action("操作：提气")
	turn_manager.player_lift()
	_drain_log()
	_after_player_input()

func _on_breathe_pressed() -> void:
	_cancel_pending()
	selected_indices = []  # 调息换手后旧索引全部失效
	_log_action("操作：调息")
	turn_manager.player_breathe()
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

# ---- 顶栏弹窗（设置/背包，互斥；PopupHost 管定位/点外关闭/ESC） ----

func _on_settings_pressed() -> void:
	if _popup_kind == "settings":
		_close_popups()
		return
	_open_settings_popup()

func _on_bag_pressed() -> void:
	if _popup_kind == "bag":
		_close_popups()
		return
	_open_bag_popup()

func _close_popups() -> void:
	_popup_kind = ""
	_popup_host.close()

func _open_settings_popup() -> void:
	_popup_kind = "settings"
	var popup := BattleSettingsPopup.new()
	popup.setup(_pace, _in_expedition())
	popup.pace_selected.connect(func(factor: float):
		_pace = factor
		fx.pace = factor
		_open_settings_popup())  # 重开面板＝刷新当前档禁用态，弹窗保持打开
	popup.abandon_requested.connect(_abandon_battle)
	popup.close_requested.connect(func(): _close_popups())
	_popup_host.open(top_bar, popup)

func _open_bag_popup() -> void:
	_popup_kind = "bag"
	var popup := BattleBagPopup.new()
	popup.setup(_bag_items(), _in_expedition())
	popup.use_requested.connect(_on_bag_item_used)
	_popup_host.open(top_bar, popup)

func _bag_items() -> Array:
	if ExpeditionSession.board_state == null:
		return []
	return ExpeditionSession.board_state.inventory

# 使用一件战斗域道具：效果结算 + 消耗背包一件，占用本回合主动行动（与发动功法互斥）。
# 敌方回合/演出中/终局不可用；装配中先自动取消装配。
func _on_bag_item_used(item_id: String) -> void:
	if not _in_expedition() or combat == null or turn_manager == null:
		return
	if turn_manager.is_over() or combat.active_side != "player" or sequencer.busy:
		return
	var board := ExpeditionSession.board_state
	if board == null:
		return
	var entry := {}
	for stack in board.inventory:
		if str(stack.get("id", "")) == item_id:
			entry = stack
			break
	if entry.is_empty():
		return
	var use: Dictionary = entry.get("use", {})
	if use.is_empty() or not (use.get("scopes", []) as Array).has("battle"):
		return
	_cancel_pending()
	_log_action("操作：使用 %s" % str(entry.get("name", item_id)))
	var enemy_hp_before := combat.enemy.hp
	var player_hp_before := combat.player.hp
	var lines := ItemEffects.apply(use, combat.player, combat.enemy)
	board.consume_item(item_id)
	log_lines.append("你使用了%s。" % str(entry.get("name", item_id)))
	log_lines.append_array(lines)
	fx.hp_feedback(enemy_hp_before, combat.enemy.hp, enemy_panel)
	fx.heal_feedback(player_hp_before, combat.player.hp, player_panel)
	_close_popups()
	_after_player_input()

# 弃战＝阵亡口径（C-017 定案）：远征写回败北（board 清空物资并给阵亡终态罩层），沙盒回主菜单。
# "逃跑"不在此列——用户定案设计成道具（随物资系统另行立项）。
func _abandon_battle() -> void:
	sequencer.interrupt()
	if combat_log != null:
		combat_log.write("操作：弃战（主动放弃，按阵亡结算）")
	if _in_expedition():
		ExpeditionSession.report_battle_result("lose", 0)
		get_tree().change_scene_to_file(SceneRoutes.BOARD)
	else:
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
	if line.begins_with("敌方发动") or line.begins_with("敌方蓄力已满") or line.begins_with("战斗结束：你败北"):
		return BP.COLOR_ENEMY
	if line.begins_with("提示"):
		return BP.COLOR_HINT
	if line.begins_with("——") or line.begins_with("战斗结束"):
		return BP.COLOR_TURN_END
	return BP.COLOR_BODY

func _combat_result() -> String:
	if combat == null or turn_manager == null or not turn_manager.is_over():
		return ""
	if turn_manager.battle_stalled:
		return "draw"
	if not combat.enemy.is_alive():
		return "player"
	return "enemy"

func _intent_preview() -> String:
	var intent_action := str(turn_manager.enemy_intent.get("action", ""))
	if intent_action == "charging":
		var tech := str(turn_manager.enemy_intent.get("technique", ""))
		return "%s（蓄力 %d/%d——引而不发，蓄满自动发动：%s）" % [
			tech, int(turn_manager.enemy_intent.get("charge", 0)),
			int(turn_manager.enemy_intent.get("need", 0)),
			TechniqueResolver.effect_summary(tech)]
	if intent_action == "breathe":
		return "调息（弃全部手牌，纳新 6 口——它要换气）"
	if intent_action == "lift_qi":
		return "提气（让一拍，从丹田提 1 张）"
	var technique_id := str(turn_manager.enemy_intent.get("technique", "PASS"))
	if technique_id == "PASS":
		return "无（暂让）"
	var summary := TechniqueResolver.effect_summary(technique_id)
	var suffix := ""
	if (TechniqueResolver.data_for(technique_id).get("tags", []) as Array).has("压制"):
		suffix = "（压制·行动权未让）"
	if summary.is_empty():
		return technique_id + suffix
	return "%s（%s）%s" % [technique_id, summary, suffix]

# 终局结算：文案在此计算，呈现交给 BattleEndOverlay。
# 败北文案与 board 终态结算衔接：返回地图后接"—— 阵亡 ——"（物资全丢）。
func _show_end_overlay() -> void:
	if end_overlay.visible or combat == null or turn_manager == null or not turn_manager.is_over():
		return
	var over := _combat_result()
	if over.is_empty():
		return
	var lines: Array[String] = ["历经 %d 次行动、%d 口气。" % [combat.action_count, combat.player_breath_count]]
	match over:
		"player":
			lines.append("你尚余 %d/%d 气血，将带入之后的战斗。" % [combat.player.hp, combat.player.max_hp])
			if _in_expedition():
				lines.append("敌人已倒下，遗体留在牌堆顶，可搜刮或无视。")
		"enemy":
			lines.append("致命一击：%s" % _killing_blow_text())
			if _in_expedition():
				lines.append("本次探索到此为止，携带的物资将全部丢失。")
		"draw":
			lines.append("双方僵持不下，各自收手。")
			if _in_expedition():
				lines.append("当前规则下平局按探索失败处理（口径待设计定案）。")
	var return_text := "返回地图（继续探索）" if over == "player" else "返回地图（探索结束）"
	_close_popups()
	if DojoConfig.active:
		return_text = "回演武场"
	end_overlay.show_result(over, lines, _in_expedition(), return_text)
	if DojoConfig.active:
		end_overlay.return_button.visible = true

# 从战报里倒查致命一击（最后一条"敌方发动X"）。
func _killing_blow_text() -> String:
	for i in range(log_lines.size() - 1, -1, -1):
		var line := log_lines[i]
		if line.begins_with("敌方发动"):
			return "敌方「%s」打空了你最后的气血。" % line.get_slice("：", 0).trim_prefix("敌方发动")
	return "你气血耗尽，倒在了对手面前。"

# 沙盒重开一场：终态复位后走正常开战流程（远征模式不显示此按钮）。
func _on_restart_pressed() -> void:
	sequencer.interrupt()
	end_overlay.visible = false
	log_overlay.visible = false
	_close_popups()
	_end_message_shown = false
	_techniques_built = false
	armed_technique = ""
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
