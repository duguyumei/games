## UI component that serves as a container for Card objects and provides card playing interface.
## See HandManager for globally accessible interface.
extends Control
class_name Hand

# Controls the movement speed (time) of cards, making them tween faster or slower around the hand
const CARD_TWEEN_TIME: float = 0.2

## During hand related card pick actions, invalid cards will appear transparent.
const INVALID_CARD_ALPHA: float = 0.3

# General Nodes
@onready var player: BaseCombatant = $%Player
@onready var combat = $%Combat
@onready var card_container: Control = %CardContainer

# a debugging component for displaying hand's physical size
# should be the same size and position of Hand
@onready var hand_size_exceeded_rect: ColorRect = %HandSizeExceededRect
const HAND_EXCEEDED_COLOR: Color = Color.RED
const HAND_NOT_EXCEEDED_COLOR: Color = Color.LIGHT_GREEN

# Card Picking
@onready var card_picking: Control = $%CardPicking
@onready var card_picking_label: Label = $%CardPicking/CardPickLabel
@onready var confirm_pick_button: Button = $%CardPicking/ConfirmPickButton

var current_card_pick_action: ActionBasePickCards = null	# an action currently requesting cards from the player to select. If null clicking cards plays them

# Targeting
@onready var background_button: TextureButton = $%BackgroundButton
@onready var select_target_label: Label = $%SelectTargetLabel
var current_selected_card: Card = null	# used for cards with targeting

# Card Play Queue
var hand_disabled: bool = false	# the player cannot play additional cards manually
var performing_card_right_click: bool = false	# flag used to lock card plays while a right click action happens

## 真气战斗中按点击顺序保存的本批手牌选择。
var selected_qi_instance_uids: Array[String] = []

## 真气实例 UID 到当前手牌 UI 的映射。
var qi_uid_to_hand_card: Dictionary[String, QiCard] = {}

## 玩家已经提交且不可撤回的待结算区容器。
@onready var player_pending_qi_container: HBoxContainer = $%PlayerPendingQiContainer

## 敌方已经确定但只显示牌背的待结算区容器。
@onready var enemy_pending_qi_container: HBoxContainer = $%EnemyPendingQiContainer

## 将当前选择整批提交到待结算区的按钮。
@onready var commit_qi_button: Button = $%CommitQiButton

## 冻结敌我待结算区并交给结算器的按钮。
@onready var confirm_qi_button: Button = $%ConfirmQiButton

## 玩家待结算区标题。
@onready var player_pending_qi_label: Label = $%PlayerPendingQiLabel

## 敌方待结算区标题。
@onready var enemy_pending_qi_label: Label = $%EnemyPendingQiLabel


# Mapping
## Maps a CardData object to the actual Card represented by it in hand.
## This is usually mapped in create_cards_in_hand() and unmapped in HandManager.move_card_to_limbo()
var card_data_to_hand_card: Dictionary[CardData, Card] = {}

# Card Positions and Rotations
## Curve controlling card index in hand to its rotation
@export var hand_card_rotation_curve: Curve = preload("res://misc/curves/hand_rotation_curve.tres")
const HAND_CARD_ROTATION_CURVE_MULTIPLIER: float = 6.0 # multiplies the curve sampling

## Curve controlling card index in hand to its y offset
@export var hand_card_y_offset_curve: Curve = preload("res://misc/curves/hand_y_curve.tres")
const HAND_CARD_Y_OFFSET_CURVE_MULTIPLIER: float = -20.0 # multiplies the curve sampling

const CARD_WIDTH: float = 144.0 # how big the Card asset is. NOTE: Update this if you update Card's size at all
const CARD_SEPERATION_WIDTH: float = CARD_WIDTH * .75 # how far apart each card should be from one another. Generally between .5 to 1X the card width

const MIDDLE_OFFSET: float = CARD_WIDTH / 2
var middle: float = (size[0] / 2) - MIDDLE_OFFSET # calculate middle X position of hand container, with optional offset for fine tuning

# y offsets for when the player hovers over a card
const CARD_UNHOVERED_HEIGHT = 0.0
const CARD_HOVERED_HEIGHT = -30

const CARD_PICK_POSITIONS: Array = [
	[0.0],
	[-0.5, 0.5],
	[-1, 0.0, 1],
	[-1.5 ,-0.75, 0.75 ,1.5],
	[-1.5, -0.75, 0.0, 0.75 ,1.5],
	[-2.25, -1.5, -0.75, 0.75 ,1.5, 2.25],
	[-2.25, -1.5, -0.75, 0.0, 0.75 ,1.5, 2.25],
	[-2.75, -2.25, -1.5, -0.75, 0.75 ,1.5, 2.25, 2.75],
	[-2.75, -2.25, -1.5, -0.75, 0.0, 0.75 ,1.5, 2.25, 2.75],
	[-3.25, -2.75, -2.25, -1.5, -0.75, 0.75 ,1.5, 2.25, 2.75, 3.25],
]
const CARD_PICK_Y_OFFSET = -300 # Where picked cards in hand appear relative to the Hand container


func _ready():
	HandManager.hand = self
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)
	
	Signals.card_pick_requested.connect(_on_card_pick_requested)
	Signals.card_pick_confirmed.connect(_on_card_pick_confirmed)
	
	Signals.enemy_clicked.connect(_on_enemy_clicked)
	Signals.enemy_hovered.connect(_on_enemy_hovered)
	
	confirm_pick_button.button_up.connect(_on_confirm_pick_button_up)
	
	background_button.button_up.connect(_on_background_button_up)
	commit_qi_button.button_up.connect(_on_commit_qi_button_up)
	confirm_qi_button.button_up.connect(_on_confirm_qi_button_up)
	Signals.qi_zones_changed.connect(refresh_qi_battle_ui)
	_set_qi_controls_visible(false)
	
## Recalculates the transforms of Card objects in hand and tweens them to their new positions.
func tween_hand():
	var cards_in_hand: Array[Card] = get_player_hand_cards()
	
	### Figure out the number of cards in hand for figuring out offsets. Picking cards will adjust this number
	var hand_card_count: int = len(cards_in_hand)
	var picked_card_count: int = 0
	if current_card_pick_action != null:
		picked_card_count = len(current_card_pick_action.picked_cards)
		hand_card_count -= picked_card_count
	
	### Calculate dimensions of all the cards in player hand and a modified card seperation value
	var all_cards_width := CARD_SEPERATION_WIDTH * hand_card_count
	var card_x_seperation: float = CARD_SEPERATION_WIDTH
	hand_size_exceeded_rect.color = HAND_NOT_EXCEEDED_COLOR # used for debugging

	# throttle seperation width of cards if it begins to exceed the size of the Hand container
	var hand_width: float = size.x
	if all_cards_width > hand_width:
		card_x_seperation *= (size.x / all_cards_width) # make the seperation a proportion of the exceeded size and the size of the Hand container
		hand_size_exceeded_rect.color = HAND_EXCEEDED_COLOR
	
	### Recalculate new positions/rotations for each card and tween them
	var hand_index: int = 0	# counter for number of cards in hand
	var pick_index: int = 0 # counter for number of cards picked
	var z_index_counter: int = 0
	
	for card_data: CardData in HandManager.player_hand:
		var card: Card = card_data_to_hand_card.get(card_data)
		if card == null:
			breakpoint
			DebugLogger.log_error("Card missing from Hand")
			continue
		
		# values of rotation and position after calculations
		var new_position: Vector2 = Vector2()
		var new_rot: float = 0.0
		
		# figure out if the card is in hand or picked
		var is_card_in_hand: bool = true
		if current_card_pick_action != null:
			if current_card_pick_action.picked_cards.has(card_data):
				is_card_in_hand = false
		
		# calculate new transforms
		if is_card_in_hand:
			card.z_index = z_index_counter
			z_index_counter += 1
			
			if hand_card_count == 1:
				# a single card in hand is made to be in middle with an offset, looks weird otherwise
				new_rot = 0
				new_position = Vector2(middle + (CARD_WIDTH / 2), 0)
			else:
				# rotation
				new_rot = 0
				var rotation_multiplier: float = hand_card_rotation_curve.sample(1.0 / (hand_card_count - 1) * hand_index)
				new_rot = HAND_CARD_ROTATION_CURVE_MULTIPLIER * rotation_multiplier
				# y position
				var card_y_offset: float = hand_card_y_offset_curve.sample(1.0 / (hand_card_count - 1) * hand_index)
				card_y_offset *= HAND_CARD_Y_OFFSET_CURVE_MULTIPLIER
				# x position
				var card_index_offset: float = float(hand_index) - (float(hand_card_count) / 2.0) + 1.0
				var card_x_offset: float = middle + (card_x_seperation * card_index_offset)
				# final position
				new_position = Vector2(card_x_offset, card_y_offset)
			
			hand_index += 1
		else:
			# card not in hand
			new_position = Vector2(middle + CARD_SEPERATION_WIDTH * CARD_PICK_POSITIONS[picked_card_count - 1][pick_index], CARD_PICK_Y_OFFSET)
			new_rot = 0
			pick_index += 1
		
		# interpolate card to new position and rotation
		var tween: Tween = create_tween()
		tween.tween_property(card.pivot, "position", new_position, CARD_TWEEN_TIME)
		var tween_2: Tween = create_tween()
		tween_2.tween_property(card.pivot, "rotation_degrees", new_rot, CARD_TWEEN_TIME)


func _on_card_hovered(card: Card):
	update_hand_card_hover(card)
		

func _on_card_unhovered(_card: Card):
	update_hand_card_hover(null)

func update_hand_card_hover(hovered_card: Card = null) -> void:
	var z_index_counter: int = 0
	for card_data: CardData in HandManager.player_hand:
		var card_in_hand: Card = card_data_to_hand_card.get(card_data)
		if card_in_hand == null:
			continue
		
		if hovered_card == card_in_hand:
			# hovered card
			card_in_hand.position.y = CARD_HOVERED_HEIGHT
			card_in_hand.z_index = 50
		else:
			# unhovered cards
			card_in_hand.position.y = CARD_UNHOVERED_HEIGHT
			card_in_hand.z_index = z_index_counter
			z_index_counter += 1

func _on_card_selected(card: Card):
	# card clicked, attempt to do something with it
	# check if playing or picking cards
	if current_card_pick_action == null:
		### playing
		# cannot play cards with a disabled hand
		if hand_disabled:
			return
		# cannot play while right click actions happening
		if performing_card_right_click:
			return
		# check if card is generally playable
		if not card.can_play_card():
			return
		# cannot play cards already queued
		for card_play_request in HandManager.card_play_queue:
			if card_play_request.card_data == card.card_data:
				return
		
		# check if autoplaying card based on targeting type
		if card.card_data.card_requires_target:
			current_selected_card = card
			_prompt_target(card)
		else:
			# generate the card play request and enqueue it
			var card_data: CardData = card.card_data
			var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, true, true)
			card_play_request.card_destination_pile = card_data.card_play_destination
			card_play_request.card_destination_strategy = card_data.card_play_destination_strategy
			
			HandManager.add_card_to_play_queue(card_play_request, true, false)
			current_selected_card = null
			_unprompt_target()
	else:
		### picking
		attempt_pick_card(card)

## 切换一张玩家手牌的本批选择；新增选择严格记录点击顺序。
func _on_qi_hand_card_selected(qi_card: QiCard) -> void:
	if hand_disabled or Global.battle_qi_state == null \
		or Global.battle_qi_state.is_action_frozen() or qi_card.qi_data == null:
		return
	var qi_instance_uid: String = qi_card.qi_data.object_uid
	if selected_qi_instance_uids.has(qi_instance_uid):
		selected_qi_instance_uids.erase(qi_instance_uid)
	else:
		var pending_count: int = Global.battle_qi_state.get_zone(
			BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_PENDING).size()
		if pending_count + selected_qi_instance_uids.size() >= BattleQiState.PENDING_LIMIT:
			return
		selected_qi_instance_uids.append(qi_instance_uid)
	_update_qi_selection_display()

## 将当前批次整批提交；失败时手牌和选择顺序都保持不变。
func _on_commit_qi_button_up() -> void:
	if Global.battle_qi_state == null or selected_qi_instance_uids.is_empty():
		return
	if not Global.battle_qi_state.commit_player_selection(
		selected_qi_instance_uids.duplicate()):
		return
	selected_qi_instance_uids.clear()
	Signals.qi_zones_changed.emit()

## 冻结敌我待结算区；确认后禁止继续选择和提交。
func _on_confirm_qi_button_up() -> void:
	if Global.battle_qi_state == null:
		return
	var request: QiActionRequest = Global.battle_qi_state.freeze_action()
	if request == null:
		return
	hand_disabled = true
	selected_qi_instance_uids.clear()
	refresh_qi_battle_ui()
	Signals.qi_action_ready.emit(request)

## 从 BattleQiState 重新绘制玩家手牌和敌我待结算区。
func refresh_qi_battle_ui() -> void:
	var battle_state: BattleQiState = Global.battle_qi_state
	if battle_state == null or battle_state.get_active_enemy_instance_id() == "":
		clear_qi_battle_cards()
		_set_qi_controls_visible(false)
		return
	_set_qi_controls_visible(true)
	_clear_control_children(card_container)
	_clear_control_children(player_pending_qi_container)
	_clear_control_children(enemy_pending_qi_container)
	qi_uid_to_hand_card.clear()
	var player_hand: Array[QiData] = battle_state.get_zone(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_HAND)
	var player_hand_uids: Array[String] = battle_state.get_zone_uids(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_HAND)
	# 牌区效果可能在重绘前移动手牌，失效的旧选择不能继续阻塞本批提交。
	for selection_index: int in range(selected_qi_instance_uids.size() - 1, -1, -1):
		if not player_hand_uids.has(selected_qi_instance_uids[selection_index]):
			selected_qi_instance_uids.remove_at(selection_index)
	for qi_data: QiData in player_hand:
		var qi_card: QiCard = Scenes.QI_CARD.instantiate()
		card_container.add_child(qi_card)
		qi_card.init(qi_data, true, battle_state)
		qi_card.qi_selected.connect(_on_qi_hand_card_selected)
		qi_uid_to_hand_card[qi_data.object_uid] = qi_card
	_layout_qi_hand_cards()
	for qi_data: QiData in battle_state.get_zone(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_PENDING):
		var qi_card: QiCard = Scenes.QI_CARD.instantiate()
		player_pending_qi_container.add_child(qi_card)
		qi_card.init(qi_data, false, battle_state)
		qi_card.disabled = true
	for qi_data: QiData in battle_state.get_zone(
		BattleQiState.SIDE_ENEMY, BattleQiState.ZONE_PENDING):
		var qi_card: QiCard = Scenes.QI_CARD.instantiate()
		enemy_pending_qi_container.add_child(qi_card)
		qi_card.init(qi_data, false, battle_state)
		qi_card.set_face_down(true)
	_update_qi_selection_display()

## 清空战斗真气 UI，不修改任何牌区数据。
func clear_qi_battle_cards() -> void:
	selected_qi_instance_uids.clear()
	qi_uid_to_hand_card.clear()
	_clear_control_children(card_container)
	_clear_control_children(player_pending_qi_container)
	_clear_control_children(enemy_pending_qi_container)

## 根据当前点击顺序更新选中序号和按钮状态。
func _update_qi_selection_display() -> void:
	var battle_state: BattleQiState = Global.battle_qi_state
	var pending_count: int = 0
	var action_frozen: bool = false
	if battle_state != null:
		pending_count = battle_state.get_zone(
			BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_PENDING).size()
		action_frozen = battle_state.is_action_frozen()
	for qi_instance_uid: String in qi_uid_to_hand_card:
		var qi_card: QiCard = qi_uid_to_hand_card[qi_instance_uid]
		var selection_order: int = selected_qi_instance_uids.find(qi_instance_uid) + 1
		qi_card.set_selection_order(selection_order)
		qi_card.disabled = hand_disabled or action_frozen
	commit_qi_button.disabled = hand_disabled or action_frozen \
		or selected_qi_instance_uids.is_empty() \
		or pending_count + selected_qi_instance_uids.size() > BattleQiState.PENDING_LIMIT
	confirm_qi_button.disabled = hand_disabled or action_frozen \
		or pending_count < 1 or pending_count > BattleQiState.PENDING_LIMIT

## 将真气手牌按现有扇形区域的宽度横向排列。
func _layout_qi_hand_cards() -> void:
	var qi_cards: Array[QiCard] = []
	for qi_data: QiData in Global.battle_qi_state.get_zone(
		BattleQiState.SIDE_PLAYER, BattleQiState.ZONE_HAND):
		var qi_card: QiCard = qi_uid_to_hand_card.get(qi_data.object_uid, null)
		if qi_card != null:
			qi_cards.append(qi_card)
	if qi_cards.is_empty():
		return
	var card_width: float = 112.0
	var available_width: float = max(card_container.size.x, 880.0)
	var separation: float = min(card_width, available_width / qi_cards.size())
	var total_width: float = separation * float(qi_cards.size() - 1) + card_width
	var start_x: float = (available_width - total_width) / 2.0
	for qi_index: int in qi_cards.size():
		var qi_card: QiCard = qi_cards[qi_index]
		qi_card.scale = Vector2(0.78, 0.78)
		qi_card.position = Vector2(start_x + separation * qi_index, -112.0)

## 显示或隐藏真气待结算区及操作按钮。
func _set_qi_controls_visible(visible_state: bool) -> void:
	player_pending_qi_container.visible = visible_state
	enemy_pending_qi_container.visible = visible_state
	player_pending_qi_label.visible = visible_state
	enemy_pending_qi_label.visible = visible_state
	commit_qi_button.visible = visible_state
	confirm_qi_button.visible = visible_state

## 立即移除容器中的旧视图，避免同一帧刷新时暂时重复显示。
func _clear_control_children(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
		
func _on_card_right_clicked(card: Card):
	current_selected_card = null
	_unprompt_target()
	if ActionHandler.actions_being_performed:
		return # cannot right click while actions happening
	if hand_disabled:
		return # cannot right click cards with a disabled hand
	if len(HandManager.card_play_queue) > 0:
		return # cannot right click cards while cards queued
	_perform_card_right_click_actions(card)

### Targeting

func _on_background_button_up():
	current_selected_card = null
	_unprompt_target()

func _on_enemy_clicked(enemy: Enemy):
	if current_selected_card != null:
		_unprompt_target()
		
		# generate the card play request and enqueue it
		var card_data: CardData = current_selected_card.card_data
		var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, enemy, true, true)
		card_play_request.card_destination_pile = card_data.card_play_destination
		card_play_request.card_destination_strategy = card_data.card_play_destination_strategy
		
		HandManager.add_card_to_play_queue(card_play_request, true, false)
		current_selected_card = null

func _on_enemy_hovered(enemy: Enemy):
	if current_selected_card != null:
		current_selected_card.update_card_display(enemy)

func _prompt_target(_card: Card):
	select_target_label.visible = true

func _unprompt_target():
	select_target_label.visible = false

func _perform_card_right_click_actions(card: Card) -> void:
	# locks further card actions and performs a right click on a card
	if len(card.card_data.card_right_click_actions) > 0:
		performing_card_right_click = true # locks further card actions
		# generate fake card request
		var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card.card_data, null, true, true)

		# generate card actions
		var card_right_click_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card.card_data.card_right_click_actions, null)
		ActionHandler.add_actions(card_right_click_actions)
		
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
			
		performing_card_right_click = false

#region Card Picking
func update_card_pick_ui():
	# update ui
	confirm_pick_button.disabled = true
	if current_card_pick_action != null:
		var not_enough_cards_picked: bool = not current_card_pick_action.are_enough_cards_picked()
		confirm_pick_button.disabled = not_enough_cards_picked
		card_picking_label.text = current_card_pick_action.get_card_pick_text() 
	

## User selected a card while a pick request is made.
## The card will be picked or unpicked.
func attempt_pick_card(card: Card):
	if current_card_pick_action != null:
		# check if card already picked or not
		if current_card_pick_action.picked_cards.has(card.card_data):
			# card already picked; unpick card
			current_card_pick_action.picked_cards.erase(card.card_data)
		
		else:
			# card not already picked; try to pick card
			if current_card_pick_action.is_card_pickable(card.card_data, false):
				var picked_card_amount: int = len(current_card_pick_action.picked_cards)
				var max_card_amount: int = min(current_card_pick_action.get_card_pick_max_amount(), HandManager.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX)
				if picked_card_amount < max_card_amount:
					# pick the card
					current_card_pick_action.picked_cards.append(card.card_data)
				elif max_card_amount == 1:
					# if max 1 card, it will swap them out
					current_card_pick_action.picked_cards.clear()
					current_card_pick_action.picked_cards.append(card.card_data)
		
		update_card_pick_ui()
		tween_hand()

func unpick_card(card: Card):
	if current_card_pick_action != null:
		current_card_pick_action.picked_cards.erase(card)

func _on_confirm_pick_button_up():
	# user has confirmed the selected cards
	Signals.card_pick_confirmed.emit()
	tween_hand()
	
func _on_card_pick_requested(card_selection_action: ActionBasePickCards):
	if card_selection_action.get_card_pick_type() == HandManager.HAND_PILE:
		card_picking.visible = true
		current_card_pick_action = card_selection_action
		update_card_pick_ui()
		set_hand_invalid_card_pick_visibility(true)

func _on_card_pick_confirmed():
	card_picking.visible = false
	current_card_pick_action = null
	set_hand_invalid_card_pick_visibility(true)

# used for hand card picking. All invalid cards will be temporarily hidden or transparent based on the requested action
func set_hand_invalid_card_pick_visibility(invalid_cards_visible: bool) -> void:
	var invisble_alpha: float = INVALID_CARD_ALPHA
	if not invalid_cards_visible:
		invisble_alpha = 0.0
	
	for card: Card in card_data_to_hand_card.values():
		card.modulate.a = 1.0
		card.visible = true
		if current_card_pick_action != null:
			if not current_card_pick_action.is_card_pickable(card.card_data):
				card.visible = invalid_cards_visible
				card.modulate.a = invisble_alpha
#endregion

#region Card Management

## Factory method for making Card ui components.
## Automatically registers the card to the hand as well.
func create_cards_in_hand(cards: Array[CardData]) -> Array[Card]:
	var created_cards: Array[Card] = []

	for card_data: CardData in cards:
		# check for duplicates
		if card_data_to_hand_card.has(card_data):
			DebugLogger.log_error("Hand cannot create an existing hand card")
			breakpoint
			continue
		
		var card: Card = Scenes.CARD.instantiate()
		card_container.add_child(card)
		card.init(card_data, 0, true, true)
		
		card.card_hovered.connect(_on_card_hovered)
		card.card_unhovered.connect(_on_card_unhovered)
		card.card_selected.connect(_on_card_selected)
		card.card_right_clicked.connect(_on_card_right_clicked)
		
		card_data_to_hand_card[card_data] = card
		
		created_cards.append(card)
	
	return created_cards

## Removes the Card UI elements from the hand
## NOTE: Typeically called from HandManager.
func clear_hand_cards() -> void:
	for child in card_container.get_children():
		child.queue_free()
	card_data_to_hand_card.clear()
	qi_uid_to_hand_card.clear()

func disable_hand(_disabled: bool = true):
	hand_disabled = _disabled
	if hand_disabled:
		current_selected_card = null
		_unprompt_target()
	_update_qi_selection_display()

#endregion

### Combat/Turns

func _on_combat_started(_event_id: String):
	_unprompt_target()
	
func _on_combat_ended():
	_unprompt_target()
	clear_hand_cards()
	clear_qi_battle_cards()
	_set_qi_controls_visible(false)

func _on_run_ended():
	_unprompt_target()
	clear_hand_cards()
	clear_qi_battle_cards()
	_set_qi_controls_visible(false)

#region Card Trails
func create_card_trail_from_card(card: Card, card_destination_pile: String, is_combat: bool) -> void:
	var starting_position: Vector2 = card.pivot.global_position # center of card
	var destination_ui_element: Control = HandManager.card_destination_to_ui_elements.get(card_destination_pile, null)
	if destination_ui_element == null:
		# DebugLogger.log_error("No ui element mapped to \"{0}\" found for CardTrail destination".format([card_destination_pile]))
		return
	var destination_position: Vector2 = destination_ui_element.global_position + (destination_ui_element.size / 2)
	
	var card_trail_color_id: String = card.card_data.card_color_id
	var card_trail_color: Color = Color.WHITE
	if card_trail_color_id != "":
		var color_data: ColorData = Global.get_color_data(card_trail_color_id)
		card_trail_color = color_data.color
	
	# create card trail
	var card_trail: CardTrail = Scenes.CARD_TRAIL.instantiate()
	add_child(card_trail)
	
	card_trail.init(
		starting_position,
		destination_position,
		card_trail_color,
		destination_ui_element,
		is_combat
	)
#endregion
#region Helpers

## Gets ui cards in player hand.
## Maintains ordering of hand.
func get_player_hand_cards() -> Array[Card]:
	var hand_cards: Array[Card] = []
	for card_data: CardData in HandManager.player_hand:
		if card_data_to_hand_card.has(card_data):
			var card: Card = card_data_to_hand_card[card_data]
			hand_cards.append(card)
	return hand_cards

func update_hand_card_display() -> void:
	# forces updates of all cards in player's hand
	for cd in card_data_to_hand_card.values():
		var card: Card = cd # typecast iterator
		card.update_card_display()
#endregion
