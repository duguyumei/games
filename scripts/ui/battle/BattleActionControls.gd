## 真气战斗 HUD 的两个主操作按钮。
extends VBoxContainer
class_name BattleActionControls

## 玩家点击出牌按钮。
signal play_requested

## 玩家点击确认按钮。
signal confirm_requested

var play_button: Button
var confirm_button: Button

## 创建出牌和确认按钮，不提供撤回按钮。
func _ready() -> void:
	add_theme_constant_override("separation", 8)
	play_button = Button.new()
	play_button.text = "出牌"
	play_button.custom_minimum_size = Vector2(112.0, 42.0)
	play_button.button_up.connect(func() -> void: play_requested.emit())
	add_child(play_button)
	confirm_button = Button.new()
	confirm_button.text = "确认"
	confirm_button.custom_minimum_size = Vector2(112.0, 42.0)
	confirm_button.button_up.connect(func() -> void: confirm_requested.emit())
	add_child(confirm_button)

## 按当前选择和待结算区数量更新两个按钮状态。
func refresh(
		selected_count: int,
		pending_count: int,
		pending_limit: int,
		can_player_act: bool,
		is_frozen: bool) -> void:
	play_button.disabled = is_frozen or not can_player_act \
		or selected_count <= 0 \
		or pending_count + selected_count > pending_limit
	confirm_button.disabled = is_frozen or not can_player_act \
		or pending_count < 1 or pending_count > pending_limit
