## 真气战斗 HUD 的单方信息面板。
extends PanelContainer
class_name BattleSideInfo

## 当前组件所属阵营。
var side: String = BattleQiState.SIDE_PLAYER

var _title_label: Label
var _health_label: Label
var _combo_label: Label
var _deck_label: Label
var _defense_panel: BattleDefensePanel
var _neigong_panel: BattleNeigongPanel
var _gongfa_panel: BattleGongfaPanel

## 创建生命、连击、防御、内功和功法区域。
func _ready() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	_title_label = _make_label(16)
	_health_label = _make_label(13)
	_combo_label = _make_label(12)
	_deck_label = _make_label(11)
	content.add_child(_title_label)
	content.add_child(_health_label)
	content.add_child(_combo_label)
	content.add_child(_deck_label)
	_defense_panel = BattleDefensePanel.new()
	content.add_child(_defense_panel)
	_neigong_panel = BattleNeigongPanel.new()
	_neigong_panel.setup(side)
	content.add_child(_neigong_panel)
	_gongfa_panel = BattleGongfaPanel.new()
	_gongfa_panel.setup(side)
	content.add_child(_gongfa_panel)
	setup(side)

## 设置阵营并刷新标题。
func setup(_side: String) -> void:
	side = _side
	if _title_label != null:
		_title_label.text = "我方" if side == BattleQiState.SIDE_PLAYER else "敌方"
	if _defense_panel != null:
		_defense_panel.side = side
	if _neigong_panel != null:
		_neigong_panel.setup(side)
	if _gongfa_panel != null:
		_gongfa_panel.setup(side)

## 从战斗现场刷新当前单方数据。
func refresh(battle_state: BattleQiState) -> void:
	if battle_state == null:
		return
	var health: int = 0
	var max_health: int = 0
	if side == BattleQiState.SIDE_PLAYER and Global.player_data != null:
		health = Global.player_data.player_health
		max_health = Global.player_data.player_health_max
	else:
		var enemies: Array[Enemy] = Global.get_alive_enemies()
		if not enemies.is_empty():
			health = enemies[0].enemy_data.enemy_health
			max_health = enemies[0].enemy_data.enemy_health_max
	_health_label.text = "生命  %d/%d" % [health, max_health]
	_combo_label.text = "连击槽  %d/%d" % [
		battle_state.get_combo_value(side), battle_state.get_combo_capacity()]
	_deck_label.text = "牌库 %d  手牌 %d  弃牌 %d  消耗 %d" % [
		battle_state.get_zone(side, BattleQiState.ZONE_DRAW).size(),
		battle_state.get_zone(side, BattleQiState.ZONE_HAND).size(),
		battle_state.get_zone(side, BattleQiState.ZONE_DISCARD).size(),
		battle_state.get_zone(side, BattleQiState.ZONE_EXHAUST).size()]
	_defense_panel.refresh(battle_state)
	_neigong_panel.refresh(battle_state)
	_gongfa_panel.refresh(battle_state)

func _make_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.clip_text = true
	return label
