## Menu for starting a new run
extends BaseMenu

@onready var character_name_label = %CharacterNameLabel
@onready var character_health_label = %CharacterHealthLabel
@onready var character_money_label = %CharacterMoneyLabel
@onready var character_description_label = %CharacterDescriptionLabel

@onready var character_artifact_texture_rect = %CharacterArtifactTextureRect
@onready var character_artifact_name_label = %CharacterArtifactNameLabel
@onready var character_artifact_description_label = %CharacterArtifactDescriptionLabel

@onready var decrease_difficulty_button: Button = %DecreaseDifficultyButton
@onready var difficulty_label: LabelAutoSizer = %DifficultyLabel
@onready var increase_difficulty_button: Button = %IncreaseDifficultyButton

@onready var custom_run_modifier_button_container: Container = %CustomRunModifierButtonContainer

@onready var character_button_container: GridContainer = %CharacterButtonContainer

@onready var seed_visibility_toggle: Button = %SeedVisibilityToggle
@onready var seed_input: LineEdit = %SeedInput
@onready var start_run_button: Button = %StartRunButton

var selected_character_object_id: String = ""
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
	populate_character_buttons()
	populate_custom_run_modifiers()

func clear_menu() -> void:
	super()
	clear_character_buttons()
	clear_custom_run_modifiers()

#region Character Selection
func populate_character_buttons() -> void:
	clear_character_buttons()
	
	var character_object_ids: Array = Global._id_to_character_data.keys()
	
	var first_button: TextureButton = null
	
	for character_object_id in character_object_ids:
		# create character button
		var character_selection_button: CharacterSelectionButton = Scenes.CHARACTER_SELECTION_BUTTON.instantiate()
		character_button_container.add_child(character_selection_button)
		character_selection_button.init(character_object_id)
		# connect signal
		character_selection_button.character_selected.connect(_on_character_selected)
		
		if first_button == null:
			first_button = character_selection_button
	
	# auto press the first button
	if first_button != null:
		first_button.button_pressed = true
		first_button.button_up.emit()
	
func clear_character_buttons() -> void:
	for child in character_button_container.get_children():
		child.queue_free()

func populate_character_info(character_object_id: String) -> void:
	var character_data: CharacterData = Global.get_character_data(character_object_id)
	if character_data != null:
		character_name_label.text = character_data.character_name
		# qi-forge：四维与三命中分行短句显示（历练不在开局面板显示；短句防固定槽换行叠字）
		character_health_label.text = "生命 {0}".format([character_data.character_starting_health])
		if character_data.character_starting_speed > 0:
			character_money_label.text = "攻 {0} ｜ 防 {1} ｜ 速 {2}".format([
				character_data.character_starting_attack,
				character_data.character_starting_defense,
				character_data.character_starting_speed,
			])
		if not character_data.character_starting_hits.is_empty():
			character_description_label.text = "力道 {0} ｜ 迅疾 {1} ｜ 精妙 {2}\n{3}".format([
				character_data.character_starting_hits.get("力道", 0),
				character_data.character_starting_hits.get("迅疾", 0),
				character_data.character_starting_hits.get("精妙", 0),
				character_data.character_description,
			])
		else:
			character_description_label.text = character_data.character_description

		# 无初始遗物时隐藏遗物展示位（qi-forge：武者饰品走开局下拉，不走此位）
		var has_starting_artifact: bool = len(character_data.character_starting_artifact_ids) > 0
		character_artifact_texture_rect.visible = has_starting_artifact
		character_artifact_name_label.visible = has_starting_artifact
		character_artifact_description_label.visible = has_starting_artifact
		# TODO potentially update ui to support multiple starter artifacts displayed
		if has_starting_artifact:
			var artifact_data: ArtifactData = Global.get_artifact_data(character_data.character_starting_artifact_ids[0])
			if artifact_data != null:
				character_artifact_texture_rect.texture = FileLoader.load_texture(artifact_data.artifact_texture_path)
				character_artifact_name_label.text = artifact_data.artifact_name
				character_artifact_description_label.text = artifact_data.artifact_description
		
		# play character selection audio if it exists
		if character_data.character_selection_audio_path != "":
			ActionGenerator.generate_sound_action(character_data.character_selection_audio_path, false)

func _on_character_selected(character_object_id: String):
	selected_character_object_id = character_object_id
	populate_character_info(selected_character_object_id)

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
	if selected_character_object_id != "":
		var character_highest_difficulty_win: int = Global.profile_data.profile_character_id_to_highest_difficulty.get(selected_character_object_id, 0)
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

	# 分组词条：每组一列（列名 Label ＋ 下拉 OptionButton，单选紧凑）；
	# 未分组词条：走原勾选框路径，保持 StR 通用性。
	var group_name_to_dropdown: Dictionary = {}
	var group_name_to_ids: Dictionary = {}
	var group_name_to_description_label: Dictionary = {}

	for run_modifier_object_id in run_modifier_object_ids:
		var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if not run_modifier_data.run_modifier_is_custom:
			continue
		var group_name: String = run_modifier_data.run_modifier_group_name
		if group_name == "":
			var custom_run_modifier_checkbox: CheckBox = Scenes.CUSTOM_RUN_MODIFIER_CHECKBOX.instantiate()
			custom_run_modifier_button_container.add_child(custom_run_modifier_checkbox)
			custom_run_modifier_checkbox.init(run_modifier_object_id)
			custom_run_modifier_checkbox.toggled.connect(_on_custom_run_modifier_toggled.bind(run_modifier_data))
			_run_modifier_object_id_to_checkbox[run_modifier_object_id] = custom_run_modifier_checkbox
			continue

		# 每组一块（qi-forge: 开局饰品）：第一行＝组名＋下拉按钮，第二行＝效果说明整行，
		# 块尾留间距再进下一组。ScrollContainer 按最小宽排布，说明行必须自带最小宽。
		if not group_name_to_dropdown.has(group_name):
			var group_block: VBoxContainer = VBoxContainer.new()
			var group_row: HBoxContainer = HBoxContainer.new()
			var group_header: Label = Label.new()
			group_header.text = group_name
			group_header.custom_minimum_size = Vector2(48, 0)
			group_row.add_child(group_header)
			var group_dropdown: OptionButton = OptionButton.new()
			group_dropdown.custom_minimum_size = Vector2(200, 0)
			group_row.add_child(group_dropdown)
			group_block.add_child(group_row)
			var group_description_label: Label = Label.new()
			group_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			group_description_label.custom_minimum_size = Vector2(520, 48)
			group_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			group_block.add_child(group_description_label)
			var group_spacer: Control = Control.new()
			group_spacer.custom_minimum_size = Vector2(0, 16)
			group_block.add_child(group_spacer)
			custom_run_modifier_button_container.add_child(group_block)
			group_name_to_dropdown[group_name] = group_dropdown
			group_name_to_ids[group_name] = [] as Array[String]
			group_name_to_description_label[group_name] = group_description_label

		var group_ids: Array[String] = group_name_to_ids[group_name]
		var dropdown: OptionButton = group_name_to_dropdown[group_name]
		var description_label: Label = group_name_to_description_label[group_name]
		dropdown.add_item(run_modifier_data.run_modifier_name)
		var item_index: int = dropdown.item_count - 1
		dropdown.set_item_tooltip(item_index, run_modifier_data.run_modifier_description)
		group_ids.append(run_modifier_object_id)
		if run_modifier_data.run_modifier_is_default_enabled:
			dropdown.select(item_index)
			description_label.text = run_modifier_data.run_modifier_description
			selected_custom_run_modififers.append(run_modifier_object_id)
		if not dropdown.item_selected.is_connected(_on_group_dropdown_item_selected):
			dropdown.item_selected.connect(_on_group_dropdown_item_selected.bind(group_ids, description_label))

	# default-enable flagged ungrouped modifiers
	for run_modifier_object_id in _run_modifier_object_id_to_checkbox.keys():
		var default_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if default_modifier_data != null and default_modifier_data.run_modifier_is_default_enabled:
			var default_checkbox: CheckBox = _run_modifier_object_id_to_checkbox[run_modifier_object_id]
			default_checkbox.set_pressed_no_signal(true)
			selected_custom_run_modififers.append(run_modifier_object_id)

	_refresh_accessory_summary()

## 把当前选中的 qi-forge 饰品镜像到角色面板原遗物位：名称一行、悬停悬浮窗看全部效果。
func _refresh_accessory_summary() -> void:
	var accessory_names: Array[String] = []
	var tooltip_lines: Array[String] = []
	for modifier_id: String in selected_custom_run_modififers:
		if not modifier_id.begins_with("qif_acc_"):
			continue
		var modifier_data: RunModifierData = Global.get_run_modifier_data(modifier_id)
		if modifier_data == null:
			continue
		accessory_names.append(modifier_data.run_modifier_name)
		tooltip_lines.append("{0}：{1}".format([modifier_data.run_modifier_name, modifier_data.run_modifier_description]))
	var has_accessories: bool = not accessory_names.is_empty()
	character_artifact_name_label.visible = has_accessories
	character_artifact_description_label.visible = has_accessories
	if has_accessories:
		var tooltip_text: String = "\n".join(tooltip_lines)
		character_artifact_name_label.text = " ／ ".join(accessory_names)
		character_artifact_name_label.tooltip_text = tooltip_text
		character_artifact_description_label.text = "（悬停名称查看效果）"
		character_artifact_description_label.tooltip_text = tooltip_text

func _on_group_dropdown_item_selected(index: int, group_ids: Array[String], description_label: Label) -> void:
	# 组内单选：整组清除后只留当前选择；同时刷新常驻效果说明
	for group_id: String in group_ids:
		selected_custom_run_modififers.erase(group_id)
	selected_custom_run_modififers.append(group_ids[index])
	var selected_modifier_data: RunModifierData = Global.get_run_modifier_data(group_ids[index])
	if selected_modifier_data != null:
		description_label.text = selected_modifier_data.run_modifier_description
	_refresh_accessory_summary()

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
	Global.start_run(selected_character_object_id, run_seed, selected_difficulty_level, selected_custom_run_modififers)

func _on_run_ended():
	# go back to tile screen on failed run (save deleted), but not abandoned run (save kept)
	var has_save_file: bool = FileLoader.has_save_file()
	if not has_save_file:
		populate_menu()
	else:
		clear_menu()

#endregion
