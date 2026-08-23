## 真气战斗 HUD；作为旧 CardData 战斗界面的独立替代层。
extends Control
class_name BattleHud

## HUD 当前阶段：思考投入或定招结算。
enum HUD_STAGE {THINKING, RESOLVING}

var _stage: int = HUD_STAGE.THINKING
var _selected_qi_instance_uids: Array[String] = []
var _last_request: QiActionRequest = null

var _player_info: BattleSideInfo
var _enemy_info: BattleSideInfo
var _enemy_pending_zone: BattleQiZone
var _player_pending_zone: BattleQiZone
var _player_hand_zone: BattleQiZone
var _action_controls: BattleActionControls
var _resolution_panel: BattleResolutionPanel
var _stage_label: Label
var _hand_count_label: Label
var _legacy_visibility_cache: Dictionary[String, bool] = {}

## 创建 HUD 组件并监听真气战斗信号。
func _ready() -> void:
	z_index = 50
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_layout()
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.qi_zones_changed.connect(_on_qi_zones_changed)
	Signals.qi_action_ready.connect(_on_qi_action_ready)
	Signals.qi_action_completed.connect(_on_qi_action_completed)
	Signals.battle_defense_changed.connect(_on_battle_defense_changed)
	Signals.player_health_changed.connect(_on_player_stats_changed)
	# 初始状态不改动旧节点的可见性，避免影响地图和非战斗页面。

## 创建 1200×700 视口下的左右信息、中央牌区和底部手牌布局。
func _build_layout() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("#171b28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	_stage_label = _make_label("思考投入", 18)
	_place(_stage_label, Rect2(500.0, 18.0, 200.0, 30.0))
	add_child(_stage_label)

	_player_info = BattleSideInfo.new()
	_player_info.setup(BattleQiState.SIDE_PLAYER)
	_style_panel(_player_info, Color("#20283a"), Color("#5a729a"))
	_place(_player_info, Rect2(16.0, 62.0, 224.0, 470.0))
	add_child(_player_info)

	_enemy_info = BattleSideInfo.new()
	_enemy_info.setup(BattleQiState.SIDE_ENEMY)
	_style_panel(_enemy_info, Color("#2b222d"), Color("#9c6471"))
	_place(_enemy_info, Rect2(960.0, 62.0, 224.0, 470.0))
	add_child(_enemy_info)

	var enemy_title: Label = _make_label("敌方待结算区", 13)
	_place(enemy_title, Rect2(260.0, 76.0, 680.0, 24.0))
	add_child(enemy_title)
	_enemy_pending_zone = BattleQiZone.new()
	_place(_enemy_pending_zone, Rect2(260.0, 104.0, 680.0, 166.0))
	add_child(_enemy_pending_zone)

	var player_pending_title: Label = _make_label("我方待结算区", 13)
	_place(player_pending_title, Rect2(260.0, 286.0, 680.0, 24.0))
	add_child(player_pending_title)
	_player_pending_zone = BattleQiZone.new()
	_place(_player_pending_zone, Rect2(260.0, 314.0, 680.0, 166.0))
	add_child(_player_pending_zone)

	var hand_title: Label = _make_label("手牌", 13)
	_place(hand_title, Rect2(260.0, 494.0, 680.0, 24.0))
	add_child(hand_title)
	_player_hand_zone = BattleQiZone.new()
	_place(_player_hand_zone, Rect2(260.0, 520.0, 680.0, 164.0))
	add_child(_player_hand_zone)
	_player_hand_zone.card_clicked.connect(_on_hand_card_clicked)

	_hand_count_label = _make_label("0 张", 11)
	_hand_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(_hand_count_label, Rect2(850.0, 494.0, 90.0, 24.0))
	add_child(_hand_count_label)

	_action_controls = BattleActionControls.new()
	_place(_action_controls, Rect2(1060.0, 548.0, 124.0, 100.0))
	add_child(_action_controls)
	_action_controls.play_requested.connect(_on_play_requested)
	_action_controls.confirm_requested.connect(_on_confirm_requested)

	_resolution_panel = BattleResolutionPanel.new()
	_style_panel(_resolution_panel, Color("#352e3b"), Color("#d1a454"))
	_place(_resolution_panel, Rect2(340.0, 188.0, 520.0, 110.0))
	add_child(_resolution_panel)

## 真气战斗开始时显示新 HUD并隐藏旧战斗控件。
func _on_combat_started(_event_id: String) -> void:
	call_deferred("_refresh_from_state")

## 真气战斗结束时清理 HUD现场并恢复旧控件显示状态。
func _on_combat_ended() -> void:
	visible = false
	_stage = HUD_STAGE.THINKING
	_selected_qi_instance_uids.clear()
	_last_request = null
	_resolution_panel.hide_resolution()
	_set_legacy_visibility(false)

## 牌区或防御状态变化后重绘 HUD。
func _on_qi_zones_changed() -> void:
	_refresh_from_state()

## 确认后先显示全部敌方牌，再等待结算器写入识别结果。
func _on_qi_action_ready(request: QiActionRequest) -> void:
	_stage = HUD_STAGE.RESOLVING
	_last_request = request
	_selected_qi_instance_uids.clear()
	_refresh_from_state(true)

## 结算完成后显示冻结结果，并在短暂展示后进入下一行动。
func _on_qi_action_completed(request: QiActionRequest) -> void:
	_last_request = request
	_stage = HUD_STAGE.RESOLVING
	_resolution_panel.show_request(request)
	_refresh_from_state(true)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or not visible:
		return
	_stage = HUD_STAGE.THINKING
	_last_request = null
	_resolution_panel.hide_resolution()
	_refresh_from_state()

## 防御来源变化后只刷新双方摘要。
func _on_battle_defense_changed(_side: String, _kind: String) -> void:
	if visible:
		_refresh_side_info()

## 玩家生命等本局战斗显示变化后刷新信息。
func _on_player_stats_changed() -> void:
	if visible:
		_refresh_side_info()

## 切换玩家手牌的选中状态，选中顺序由数组稳定保存。
func _on_hand_card_clicked(qi_instance_uid: String) -> void:
	if _stage != HUD_STAGE.THINKING or Global.battle_qi_state == null \
			or not Global.battle_qi_state.is_side_eligible(BattleQiState.SIDE_PLAYER):
		return
	if _selected_qi_instance_uids.has(qi_instance_uid):
		_selected_qi_instance_uids.erase(qi_instance_uid)
	else:
		var pending_count: int = Global.battle_qi_state.get_zone(
			BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_PENDING).size()
		if pending_count + _selected_qi_instance_uids.size() >= BattleQiState.PENDING_LIMIT:
			return
		_selected_qi_instance_uids.append(qi_instance_uid)
	_refresh_from_state()

## 将选中的真气按点击顺序整批提交；成功后清空选择。
func _on_play_requested() -> void:
	var battle_state: BattleQiState = Global.battle_qi_state
	if battle_state == null or _selected_qi_instance_uids.is_empty() \
			or not battle_state.commit_player_selection(_selected_qi_instance_uids.duplicate()):
		return
	_selected_qi_instance_uids.clear()
	Signals.qi_zones_changed.emit()

## 冻结双方待结算区并直接进入正式真气结算。
func _on_confirm_requested() -> void:
	var battle_state: BattleQiState = Global.battle_qi_state
	if battle_state == null or _stage != HUD_STAGE.THINKING:
		return
	var request: QiActionRequest = battle_state.freeze_action()
	if request == null:
		return
	_selected_qi_instance_uids.clear()
	_stage = HUD_STAGE.RESOLVING
	_refresh_from_state(true)
	Signals.qi_action_ready.emit(request)
	if not Global.resolve_qi_action(request):
		_stage = HUD_STAGE.THINKING
		_refresh_from_state()

## 从 BattleQiState 刷新所有牌区、按钮、敌方设定和防御摘要。
func _refresh_from_state(force_enemy_reveal: bool = false) -> void:
	var battle_state: BattleQiState = Global.battle_qi_state
	if battle_state == null or battle_state.get_active_enemy_instance_id() == "":
		visible = false
		_set_legacy_visibility(false)
		return
	visible = true
	_set_legacy_visibility(true)
	var player_hand: Array[QiData] = battle_state.get_zone(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_HAND)
	var player_pending: Array[QiData] = battle_state.get_zone(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_PENDING)
	var enemy_pending: Array[QiData] = battle_state.get_zone(
		BattleQiState.SIDE_ENEMY, BattleQiState.ZONE_PENDING)
	var reveal_count: int = enemy_pending.size() if force_enemy_reveal \
		else battle_state.get_enemy_revealed_pending_count()
	var selection_order: Dictionary = {}
	for selected_index: int in _selected_qi_instance_uids.size():
		selection_order[_selected_qi_instance_uids[selected_index]] = selected_index + 1
	_player_hand_zone.render(
		player_hand, -1, _selected_qi_instance_uids, selection_order,
		_stage == HUD_STAGE.THINKING and battle_state.is_side_eligible(BattleQiState.SIDE_PLAYER))
	_player_pending_zone.render(player_pending, -1, [], {}, false)
	_enemy_pending_zone.render(enemy_pending, reveal_count, [], {}, false)
	_hand_count_label.text = "%d 张" % player_hand.size()
	_refresh_side_info()
	_action_controls.refresh(
		_selected_qi_instance_uids.size(),
		player_pending.size(),
		BattleQiState.PENDING_LIMIT,
		_stage == HUD_STAGE.THINKING \
		and battle_state.is_side_eligible(BattleQiState.SIDE_PLAYER),
		_stage == HUD_STAGE.RESOLVING or battle_state.is_action_frozen())
	if _stage == HUD_STAGE.THINKING:
		_stage_label.text = "思考投入"
	else:
		_stage_label.text = "定招结算"

## 刷新左右单方信息面板。
func _refresh_side_info() -> void:
	if Global.battle_qi_state == null:
		return
	_player_info.refresh(Global.battle_qi_state)
	_enemy_info.refresh(Global.battle_qi_state)

## 隐藏旧 UI节点，非真气战斗时恢复其原有显示状态。
func _set_legacy_visibility(hide_legacy: bool) -> void:
	var legacy_names: Array[String] = [
		"Hand", "Player", "EnemyContainer", "PlayerNeigongSlots", "EnemyNeigongSlots",
		"ArtifactContainer", "DrawPile", "DiscardPile", "ExhaustPile", "Consumables",
		"PlayerPendingQiLabel", "PlayerPendingQiContainer",
		"EnemyPendingQiLabel", "EnemyPendingQiContainer",
		"CommitQiButton", "ConfirmQiButton", "MoneyLabel", "HealthLabel",
	]
	var combat_node: Node = get_parent()
	if not hide_legacy:
		for cached_name: String in _legacy_visibility_cache.keys():
			var cached_node: CanvasItem = combat_node.get_node_or_null(cached_name) as CanvasItem
			if cached_node != null:
				cached_node.visible = _legacy_visibility_cache[cached_name]
		_legacy_visibility_cache.clear()
		return
	for legacy_name: String in legacy_names:
		var legacy_node: CanvasItem = combat_node.get_node_or_null(legacy_name) as CanvasItem
		if legacy_node != null:
			if not _legacy_visibility_cache.has(legacy_name):
				_legacy_visibility_cache[legacy_name] = legacy_node.visible
			legacy_node.visible = not hide_legacy

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _make_label(text_value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _style_panel(panel: PanelContainer, background_color: Color, border_color: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
