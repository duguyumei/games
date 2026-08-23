## Menu for starting a new run
extends BaseMenu

@onready var deck_name_label = %CharacterNameLabel
@onready var deck_health_label = %CharacterHealthLabel
@onready var deck_money_label = %CharacterMoneyLabel
@onready var deck_description_label = %CharacterDescriptionLabel

@onready var deck_texture_rect = %CharacterArtifactTextureRect
@onready var deck_content_name_label = %CharacterArtifactNameLabel
@onready var deck_content_description_label = %CharacterArtifactDescriptionLabel

@onready var decrease_difficulty_button: Button = %DecreaseDifficultyButton
@onready var difficulty_label: LabelAutoSizer = %DifficultyLabel
@onready var increase_difficulty_button: Button = %IncreaseDifficultyButton

@onready var custom_run_modifier_button_container: VBoxContainer = %CustomRunModifierButtonContainer

@onready var deck_button_container: GridContainer = %CharacterButtonContainer

@onready var seed_visibility_toggle: Button = %SeedVisibilityToggle
@onready var seed_input: LineEdit = %SeedInput
@onready var start_run_button: Button = %StartRunButton

## 当前选择的初始真气卡组固定 ID。
var selected_starting_qi_deck_object_id: String = ""
var selected_difficulty_level: int = 0: set = set_selected_difficulty_level

var _run_modifier_object_id_to_checkbox: Dictionary = {}
var selected_custom_run_modififers: Array[String] = []

func _ready():
	super()
	start_run_button.pressed.connect(_on_start_run_button_presssed)
	
	seed_visibility_toggle.toggled.connect(_on_seed_visibility_toggled)
	decrease_difficulty_button.pressed.connect(_on_decrease_difficulty_button_pressed)
	increase_difficulty_button.pressed.connect(_on_increase_difficulty_button_pressed)
	
	seed_input.text_changed.connect(_on_seed_input_text_changed)
	
	Signals.run_ended.connect(_on_run_ended)
	
	set_selected_difficulty_level(0)

func populate_menu() -> void:
	super()
	populate_starting_qi_deck_buttons()
	populate_custom_run_modifiers()

func clear_menu() -> void:
	super()
	clear_starting_qi_deck_buttons()
	clear_custom_run_modifiers()

#region Starting Qi Deck Selection
## 创建全部固定初始真气卡组按钮；玩家看到的是卡组而不是底层角色。
func populate_starting_qi_deck_buttons() -> void:
	clear_starting_qi_deck_buttons()
	
	var deck_object_ids: Array = Global._id_to_starting_qi_deck_data.keys()
	deck_object_ids.sort()
	
	var first_button: TextureButton = null
	
	for deck_object_id: String in deck_object_ids:
		var deck_selection_button: StartingQiDeckSelectionButton = Scenes.STARTING_QI_DECK_SELECTION_BUTTON.instantiate()
		deck_button_container.add_child(deck_selection_button)
		deck_selection_button.init(deck_object_id)
		deck_selection_button.starting_qi_deck_selected.connect(_on_starting_qi_deck_selected)
		
		if first_button == null:
			first_button = deck_selection_button
	
	# auto press the first button
	if first_button != null:
		first_button.button_pressed = true
		first_button.button_up.emit()
	
## 清理初始真气卡组按钮。
func clear_starting_qi_deck_buttons() -> void:
	for child in deck_button_container.get_children():
		child.queue_free()

## 显示固定卡组内容和其底层开局生命、金币信息。
func populate_starting_qi_deck_info(deck_object_id: String) -> void:
	var deck_data: StartingQiDeckData = Global.get_starting_qi_deck_data(deck_object_id)
	if deck_data == null:
		return
	var character_data: CharacterData = Global.get_character_data(deck_data.deck_character_object_id)
	deck_name_label.text = deck_data.deck_name
	deck_description_label.text = deck_data.deck_description
	deck_content_name_label.text = "真气牌组"
	deck_content_description_label.text = "共 {0} 张固定真气".format([deck_data.deck_qi_object_ids.size()])
	deck_texture_rect.visible = deck_data.deck_icon_texture_path != ""
	if deck_texture_rect.visible:
		deck_texture_rect.texture = FileLoader.load_texture(deck_data.deck_icon_texture_path)
	if character_data != null:
		deck_health_label.text = "生命：{0}".format([character_data.character_starting_health])
		deck_money_label.text = "金币：{0}".format([character_data.character_starting_money])
		if character_data.character_selection_audio_path != "":
			ActionGenerator.generate_sound_action(character_data.character_selection_audio_path, false)

func _on_starting_qi_deck_selected(deck_object_id: String) -> void:
	selected_starting_qi_deck_object_id = deck_object_id
	populate_starting_qi_deck_info(selected_starting_qi_deck_object_id)
	set_selected_difficulty_level(selected_difficulty_level)

#endregion

#region Seed
func _on_seed_visibility_toggled(toggle: bool) -> void:
	seed_input.visible = toggle

func _on_seed_input_text_changed(new_text: String):
	# validate the input of the line edit
	var caret_column: int = seed_input.caret_column	# store cursor position as changing text resets it
	seed_input.text = str(new_text.to_int()) # validate inputs to only int
	seed_input.caret_column = min(caret_column, len(seed_input.text)) # reset the cursor position

#endregion

#region Difficulty
func set_selected_difficulty_level(value: int) -> void:
	# set difficulty label
	if selected_starting_qi_deck_object_id != "":
		var deck_data: StartingQiDeckData = Global.get_starting_qi_deck_data(selected_starting_qi_deck_object_id)
		var character_object_id: String = deck_data.deck_character_object_id if deck_data != null else ""
		var character_highest_difficulty_win: int = Global.profile_data.profile_character_id_to_highest_difficulty.get(character_object_id, 0)
		if ProfileData.ENABLE_ALL_DIFFICULTIES:
			selected_difficulty_level = value
		else:
			selected_difficulty_level = min(selected_difficulty_level, character_highest_difficulty_win)
	
	# update text label
	var run_modifier_id: String = Global.STANDARD_DIFFICULTY_RUN_MODIFIER_IDS[selected_difficulty_level]
	var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_id)
	
	if run_modifier_data != null:
		difficulty_label.text = run_modifier_data.run_modifier_name

func _on_decrease_difficulty_button_pressed():
	selected_difficulty_level = max(0, selected_difficulty_level - 1)
func _on_increase_difficulty_button_pressed():
	selected_difficulty_level = min(selected_difficulty_level + 1, len(Global.STANDARD_DIFFICULTY_RUN_MODIFIER_IDS) - 1)
#endregion

#region Custom Run Modifiers
func populate_custom_run_modifiers() -> void:
	clear_custom_run_modifiers()
	
	var run_modifier_object_ids: Array = Global._id_to_run_modifier_data.keys()
	
	for run_modifier_object_id in run_modifier_object_ids:
		var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if run_modifier_data.run_modifier_is_custom:
			var custom_run_modifier_checkbox: CheckBox = Scenes.CUSTOM_RUN_MODIFIER_CHECKBOX.instantiate()
			custom_run_modifier_button_container.add_child(custom_run_modifier_checkbox)
			custom_run_modifier_checkbox.init(run_modifier_object_id)
			custom_run_modifier_checkbox.toggled.connect(_on_custom_run_modifier_toggled.bind(run_modifier_data))
			_run_modifier_object_id_to_checkbox[run_modifier_object_id] = custom_run_modifier_checkbox

func clear_custom_run_modifiers() -> void:
	_run_modifier_object_id_to_checkbox.clear()
	selected_custom_run_modififers.clear()
	for child in custom_run_modifier_button_container.get_children():
		child.queue_free()

func _on_custom_run_modifier_toggled(toggle: bool, run_modifier_data: RunModifierData):
	if toggle:
		selected_custom_run_modififers.append(run_modifier_data.object_id)
		# uncheck any exclusive boxes
		for exclusive_run_modifier_object_id in run_modifier_data.run_modifier_exclusive_to_modifier_ids:
			selected_custom_run_modififers.erase(exclusive_run_modifier_object_id)
			var custom_run_modifier_checkbox: CheckBox = _run_modifier_object_id_to_checkbox.get(exclusive_run_modifier_object_id, null)
			if custom_run_modifier_checkbox != null:
				custom_run_modifier_checkbox.set_pressed_no_signal(false)
	else:
		selected_custom_run_modififers.erase(run_modifier_data.object_id)

#endregion

#region Run Start/End
func _on_start_run_button_presssed():
	# get the seed and start the run
	var run_seed: int = seed_input.text.to_int()
	Global.start_run(selected_starting_qi_deck_object_id, run_seed, selected_difficulty_level, selected_custom_run_modififers)

func _on_run_ended():
	# go back to tile screen on failed run (save deleted), but not abandoned run (save kept)
	var has_save_file: bool = FileLoader.has_save_file()
	if not has_save_file:
		populate_menu()
	else:
		clear_menu()

#endregion
