## 真气扑克牌的独立 UI；不依赖旧 CardData 或 HandManager。
extends Button
class_name QiCard

## 当前显示的本局真气实例。
var qi_data: QiData = null

## 当前战斗现场；为空时只显示本局永久状态。
var battle_state: BattleQiState = null

## 当前是否只显示不泄露信息的牌背。
var face_down: bool = false

## 真气卡被点击时发出，选择界面或战斗手牌据此切换选中状态。
signal qi_selected(qi_card: QiCard)

@onready var title_label: Label = $Margin/VBox/Title
@onready var suit_label: Label = $Margin/VBox/Suit
@onready var value_label: Label = $Margin/VBox/Value
@onready var state_label: Label = $Margin/VBox/State

## 手牌选择时显示玩家的点击顺序。
@onready var selection_order_label: Label = $SelectionOrder

## 敌方待结算区使用的牌背遮罩。
@onready var card_back: ColorRect = $CardBack

## 初始化真气卡的显示数据和点击信号。
func init(
		_qi_data: QiData,
		connect_ui_signal: bool = true,
		_battle_state: BattleQiState = null) -> void:
	qi_data = _qi_data
	battle_state = _battle_state
	if connect_ui_signal and not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	update_display()

## 根据真气当前有效属性、牌阶、真气值和状态刷新显示。
func update_display() -> void:
	if qi_data == null:
		return
	title_label.text = qi_data.qi_name
	var attribute_names: Array[String] = _get_attribute_names()
	suit_label.text = "%s %s" % [
		"/".join(attribute_names), qi_data.get_effective_rank_name(battle_state)]
	value_label.text = "真气值：%d" % qi_data.get_qi_value(battle_state)
	state_label.text = _get_state_text()
	tooltip_text = "" if face_down else qi_data.qi_description

## 切换选中高亮；不改变真气数据。
func set_card_glow(enabled: bool) -> void:
	$Selected.visible = enabled
	if not enabled:
		selection_order_label.visible = false

## 显示或清除玩家当前批次的选择序号。
func set_selection_order(selection_order: int) -> void:
	var is_selected: bool = selection_order > 0
	$Selected.visible = is_selected and not face_down
	selection_order_label.visible = is_selected and not face_down
	selection_order_label.text = str(selection_order) if is_selected else ""

## 切换牌背显示；牌背模式不会暴露任何真气字段或提示文本。
func set_face_down(enabled: bool) -> void:
	face_down = enabled
	card_back.visible = enabled
	$Margin.visible = not enabled
	$Selected.visible = false if enabled else $Selected.visible
	selection_order_label.visible = false if enabled else selection_order_label.visible
	disabled = enabled
	update_display()

## 返回当前是否处于选中状态。
func is_card_glowing() -> bool:
	return $Selected.visible

## 拼接本局重塑和持久异状的简短状态文本。
func _get_state_text() -> String:
	var state_names: Array[String] = []
	for reshape_state: QiReshapeState in qi_data.qi_reshape_states:
		var state_name: String = _get_reshape_slot_name(reshape_state.reshape_slot)
		if not state_names.has(state_name):
			state_names.append(state_name)
	if battle_state != null:
		for reshape_state: QiReshapeState in battle_state.get_reshape_states(qi_data.object_uid):
			var state_name: String = _get_reshape_slot_name(reshape_state.reshape_slot)
			if not state_names.has(state_name):
				state_names.append(state_name)
	for anomaly_state: QiAnomalyState in qi_data.qi_persistent_anomaly_states:
		if anomaly_state.stacks > 0:
			state_names.append("异状×%d" % anomaly_state.stacks)
	if battle_state != null:
		for anomaly_state: QiAnomalyState in battle_state.get_anomaly_states(qi_data.object_uid):
			if anomaly_state.stacks > 0:
				state_names.append("战斗异状×%d" % anomaly_state.stacks)
	return "、".join(state_names) if not state_names.is_empty() else "无状态"

## 将有效属性 ID 映射为界面使用的花色名称。
func _get_attribute_names() -> Array[String]:
	var names: Array[String] = []
	var suit_names: Array[String] = ["黑桃", "梅花", "红桃", "方块"]
	for attribute_id: String in qi_data.get_effective_attribute_ids(battle_state):
		var attribute_index: int = QiData.ATTRIBUTE_IDS.find(attribute_id)
		if attribute_index >= 0 and attribute_index < suit_names.size():
			names.append(suit_names[attribute_index])
	return names

## 将重塑槽位映射为简短状态名称。
func _get_reshape_slot_name(reshape_slot: String) -> String:
	match reshape_slot:
		QiReshapeData.SLOT_ORIGIN:
			return "本源"
		QiReshapeData.SLOT_ENHANCEMENT:
			return "强化"
		QiReshapeData.SLOT_MARK:
			return "印记"
		QiReshapeData.SLOT_OTHER:
			return "其他重塑"
	return "临时重塑"

func _on_pressed() -> void:
	if not face_down:
		qi_selected.emit(self)
