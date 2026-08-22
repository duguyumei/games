## 真气多选界面；只负责展示候选和回传 UID，不直接修改玩家牌组。
extends Control

@onready var qi_container: GridContainer = $Panel/Margin/VBox/ScrollContainer/QiContainer
@onready var pick_label: Label = $Panel/Margin/VBox/PickLabel
@onready var confirm_button: Button = $Panel/Margin/VBox/Buttons/ConfirmButton
@onready var back_button: Button = $Panel/Margin/VBox/Buttons/BackButton

## 当前等待玩家确认的真气动作。
var current_qi_pick_action: ActionBasePickQi = null

func _ready() -> void:
	Signals.qi_pick_requested.connect(_on_qi_pick_requested)
	Signals.qi_pick_confirmed.connect(_on_qi_pick_confirmed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(_on_back_pressed)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)

## 打开界面并使用动作已经缓存的候选列表。
func _on_qi_pick_requested(qi_pick_action: ActionBasePickQi) -> void:
	if qi_pick_action == null:
		return
	current_qi_pick_action = qi_pick_action
	visible = true
	populate_qis(qi_pick_action.get_pickable_qis())
	_update_controls()

## 动作收到确认信号后关闭界面并清理旧卡片。
func _on_qi_pick_confirmed() -> void:
	visible = false
	current_qi_pick_action = null
	clear_qis()

## 生成候选真气卡；候选对象来自动作缓存，不在这里重新抽样。
func populate_qis(qis: Array[QiData]) -> void:
	clear_qis()
	for qi_data: QiData in qis:
		var qi_card: QiCard = Scenes.QI_CARD.instantiate()
		qi_container.add_child(qi_card)
		qi_card.init(qi_data)
		qi_card.qi_selected.connect(_on_qi_selected)

## 删除当前候选卡片。
func clear_qis() -> void:
	for child: Node in qi_container.get_children():
		child.queue_free()

## 切换真气选中状态并刷新确认条件。
func _on_qi_selected(qi_card: QiCard) -> void:
	if current_qi_pick_action == null or qi_card == null:
		return
	var qi_data: QiData = qi_card.qi_data
	if current_qi_pick_action.picked_qis.has(qi_data):
		current_qi_pick_action.picked_qis.erase(qi_data)
		qi_card.set_card_glow(false)
	elif current_qi_pick_action.is_qi_pickable(qi_data):
		current_qi_pick_action.picked_qis.append(qi_data)
		qi_card.set_card_glow(true)
	_update_controls()
	if current_qi_pick_action.is_quick_qi_pick():
		_on_confirm_pressed()

## 更新选择计数、确认按钮和取消按钮。
func _update_controls() -> void:
	if current_qi_pick_action == null:
		return
	pick_label.text = current_qi_pick_action.get_qi_pick_text()
	confirm_button.disabled = not current_qi_pick_action.are_enough_qis_picked()
	back_button.visible = bool(current_qi_pick_action.get_action_value("can_back_out", true))

## 确认必须满足最小和最大选择数量。
func _on_confirm_pressed() -> void:
	if current_qi_pick_action == null or not current_qi_pick_action.are_enough_qis_picked():
		return
	visible = false
	Signals.qi_pick_confirmed.emit()

## 取消时清空选择，后续 ActionPickQi 不会生成有效 UID。
func _on_back_pressed() -> void:
	if current_qi_pick_action == null:
		return
	current_qi_pick_action.picked_qis.clear()
	visible = false
	Signals.qi_pick_confirmed.emit()

## 新局开始时关闭选择界面，避免沿用旧动作。
func _on_run_started() -> void:
	visible = false
	current_qi_pick_action = null

## 本局结束时关闭界面并释放候选视图。
func _on_run_ended() -> void:
	visible = false
	current_qi_pick_action = null
	clear_qis()
