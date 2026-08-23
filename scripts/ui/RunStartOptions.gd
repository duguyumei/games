# Displays run start options
extends Control

var _option_type_to_option_ids: Dictionary = {}
const MIXED_OPTION_COUNT: int = 3	# number of options to populate that have both an upside and downside
const COMPLETE_OPTION_COUNT: int = 1	# number of unique options to populate

@onready var starting_option_container = $StartingOptionContainer
@onready var map = $%Map

func _ready():
	_aggregate_run_start_options()
	Signals.run_started.connect(_on_run_started)
	Signals.player_killed.connect(_on_player_killed)
	Signals.run_ended.connect(_on_run_ended)
	Signals.map_location_selected.connect(_on_map_location_selected)

func _aggregate_run_start_options() -> void:
	# sorts the various options into boxes based on type
	for option_type in RunStartOptionData.RUN_START_OPTION_TYPES.values():
		_option_type_to_option_ids[option_type] = [] as Array[String]
	for run_start_option_data in Global._id_to_run_start_option_data.values() as Array[RunStartOptionData]:
		_option_type_to_option_ids[run_start_option_data.run_start_option_type].append(run_start_option_data.object_id)

func populate_run_start_options() -> void:
	clear_run_start_options()
	var option_bbcode: String = "获得一件随机标准奇物、基础招式、基础防卫、基础内功与基础强化"
	var option_actions: Array[Dictionary] = [
		{Scripts.ACTION_ADD_ARTIFACTS_FROM_POOL: {
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER,
			"artifact_count": 1,
			"artifact_rarities": ArtifactData.STANDARD_ARTIFACT_RARITIES,
		}},
		{Scripts.ACTION_ADD_GONGFA: {"gongfa_object_id": "gongfa_basic_attack"}},
		{Scripts.ACTION_ADD_GONGFA: {"gongfa_object_id": "gongfa_basic_defense"}},
		{Scripts.ACTION_ADD_NEIGONG: {"neigong_object_id": "neigong_basic_draw"}},
		{Scripts.ACTION_ADD_NEIGONG: {"neigong_object_id": "neigong_basic_enhancement"}},
	]
	var run_start_option_button: DialogueOption = Scenes.DIALOGUE_OPTION.instantiate()
	starting_option_container.add_child(run_start_option_button)
	run_start_option_button.init("", option_bbcode, option_bbcode, option_actions, [])
	run_start_option_button.dialogue_option_clicked.connect(_on_dialogue_option_clicked)
	
func clear_run_start_options() -> void:
	for child in starting_option_container.get_children():
		child.queue_free()
	
func _on_dialogue_option_clicked(dialogue_option: DialogueOption):
	var player: Player = Global.get_player()
	# generate fake card play request
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, player, false, false)
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [player], dialogue_option.action_data, null)
	ActionHandler.add_actions(generated_actions)
	clear_run_start_options()
	visible = false
	
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# 初始选择完成后才进入正式地图待选阶段，并立即保存该阶段。
	Global.player_data.player_waiting_for_node_selection = true
	FileLoader.autosave()
	map.can_travel = true
	map.show_map()
	
func _on_run_started():
	visible = false
	clear_run_start_options()
	
func _on_run_ended():
	visible = false
	clear_run_start_options()

func _on_player_killed(_player: Player) -> void:
	visible = false
	clear_run_start_options()

func _on_map_location_selected(location_data: LocationData):
	# determine what to do when the player visits a new location
	var location_type: int = location_data.location_type

	visible = false
	match location_type:
		LocationData.LOCATION_TYPES.STARTING:
			populate_run_start_options()
			visible = true
