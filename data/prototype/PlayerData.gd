## Prototyped data; maintains mutable data about a run.
## See player_character_object_id and CharacterData for read only portion.
extends PrototypeData
class_name PlayerData

## CharacterData object_id. Provides additional read only data about the character this player represents. 
@export var player_character_object_id: String = ""
@export var player_health: int = 50
@export var player_health_max: int = 50

@export var player_money: int = 0

var player_energy: int = 3 # in combat energy. Not saved.
## The energy the player gains each turn. This can be modified.
@export var player_energy_max: int = 3

## The time the player has been playing the current run, in milliseconds.
## See: RunTimer.
@export var player_run_time: float = 0.0

## A json friendly dictionary containing values that can be embedded onto the player
## for extensibility, custom UI, and general mod support purposes.
## These values appear last in the action value hierarchy.
@export var player_values: Dictionary[String, Variant] = {}

### Acts and Location Data
@export var player_act: int = 1	# the act count the player is currently on
@export var player_act_max: int = 3	# the number of acts before a victory is considered. -1 means endless run
@export var player_act_id: String = "act_1"	# the ActData object_id of the act the player is currently on

## LocationData id corresponding to the location in location_id_to_location_data of where the player
## is currently located in the act.
@export var player_location_id: String = "location_0"
## 当前节点已经完整结算，玩家正在地图上等待选择下一个节点。
@export var player_waiting_for_node_selection: bool = false
## Stores locations for the current act in the run
@export var location_id_to_location_data: Dictionary[String, LocationData] = {}

## Stores the shop at the player's current location, if one exists. Does not determine if there is
## a shop accessible, that is determined by the location type at player_location_id
## NOTE: This isn't usually saved because shop data is populated when you press the shop button
## for the first time at a location and autosaves happen when you reach a location.
## Consider removing the @export flag unless you want to save the game while at a shop.
@export var player_shop_data: ShopData = null

#region RNG
@export var player_run_seed: int = 0

## Maps rng names to a random number generator "track". This allows seperate tracks of RNG to function
## independently. Whenever an rng is requested but does not yet exist, a new one will be instantiated
## using the run seed and then used. A list of "official" hardcoded rngs used or suggested by the
## framework is listed here, though they are generated ad hoc during a run. Additionally, most
## Actions can be supplied an rng_name action value to override the type of rng used.
@export var player_rng: Dictionary = {
	#"rng_general": RandomNumberGenerator.new(), # used for things that are not important if they intersect
	#"rng_world_generation": RandomNumberGenerator.new(), # used for act generation actions
	#"rng_events": RandomNumberGenerator.new(), # Used for events and run start options
	#"rng_event_pool": RandomNumberGenerator.new(), # controls randomization of event pools
	#"rng_targeting": RandomNumberGenerator.new(), # See BaseAction.TARGET_OVERRIDES.RANDOM_ENEMY
	#"rng_attack_damage": RandomNumberGenerator.new(), # See ActionAttackGenerator
	#"rng_card_picking": RandomNumberGenerator.new(), # See ActionBasePickCards
	#"rng_non_reward_card_drafting": RandomNumberGenerator.new(),
	#"rng_card_drafting": RandomNumberGenerator.new(),
	#"rng_shuffle": RandomNumberGenerator.new(), # whenever the player's deck is shuffled or reshuffled
	#"rng_pile_insert": RandomNumberGenerator.new(), # whenever the a card is randomly inserted into a pile
	#"rng_card_decoration": RandomNumberGenerator.new(), # whenever a card has a random decorator applied. See: ActionDecorateCards
	#"rng_reward_card_drafts": RandomNumberGenerator.new(), # cards rewards at the end of a fight. See: Random.get_location_card_rewards()
	#"rng_reward_money": RandomNumberGenerator.new(), # money rewards at the end of a fight. See: Random.get_location_money_reward()
	#"rng_card_transforming": RandomNumberGenerator.new(), See ActionTransformCards
	#"rng_enemy_spawning": RandomNumberGenerator.new(), # See ActionSummonEnemies
	#"rng_enemy_health": RandomNumberGenerator.new(), # How much max hp an enemy gets. See EnemyData.randomize_health()
	#"rng_enemy_attack_patterns": RandomNumberGenerator.new(),
	#"rng_shops": RandomNumberGenerator.new(), # used to populate shop items
	#"rng_artifact_rewards": RandomNumberGenerator.new(), # used to populate artifacts on run start, and decide artifact rarity selections
	#"rng_run_start_options": RandomNumberGenerator.new(), # controls which run start options are seen
	#"rng_enemy_spawning": RandomNumberGenerator.new(), # controls spawning weights
}

#endregion

## Maintains a copy of the event ids from a given EventPoolData, used when going to a new LocationData
## with an undefined event id and defined event pool.
## Like RNG tracks, these are populated when an event from a given event pool id is requested.
## Once a pool is emptied (or no events with passing validators/blacklisted), it is reset, or a fallback event ID defined in the ascociated pool is used. 
@export var player_event_pools: Dictionary = {
	#"event_pool_object_id_1": [],
	#"event_pool_object_id_2": [],
}

## Event IDs that are permanently removed from appearing in any event pool for the remainder
## of the run.
@export var player_event_blacklisted_ids: Array[String] = []


## Keeps track of everything that happened across the run
@export var player_run_stats: RunStatsData = null

## Current run's difficulty. Starts at 0
@export var player_run_difficulty_level: int = 0
## All modifiers, both standard difficulty and custom, applied to this run
@export var player_run_modifier_object_ids: Array[String] = []
## The types of rest actions populated at rest sites for this run.
## See: ActionUpdateRestActions
@export var player_available_rest_action_object_ids: Array[String] = [
	"rest_action_rest",
	"rest_action_upgrade_card",
	"rest_action_remove_cards",
	"rest_action_add_random_consumable",
	"rest_action_enchant_cards"
	]

#region Card Rewards

## The number of cards in a combat reward draft. Changing this will affect future card rewards.
@export var reward_cards_per_draft: int = 3
## The number of drafts in a combat reward. Almost always 1, but can be changed.
@export var reward_drafts: int = 1

## A generated and cached CardFilter containing all draftable cards available to the player. This is
## recompiled every time the player is made to have access to different card packs or cards via calling
## regenerate_card_draft_card_filter()
var player_reward_card_filter_cache: CardFilter = null
## All the card object ids available to the player, sorted into rarity buckets and cached. Used for weighted card drafts.
var player_reward_card_rarity_cache: Dictionary[int, Array] = {}
## The card pack ids of cards that can be drafted. Does not take effect until cache regenerated
@export var reward_draft_card_pack_ids: Array[String] = []
## Cards that can never be included in card drafts. Does not take effect until cache regenerated
@export var player_reward_draft_card_id_blacklist: Array[String] = []
## Cards that will always be included in card drafts.  Does not take effect until cache regenerated.
@export var player_reward_draft_card_id_whitelist: Array[String] = []

# pity system for drafting, to improve chances of rare cards over time. Stored as floats for precision, but converted into integers
@export var player_rare_card_modifier_current: float = 0.0	# the current modifier applied to improve rare card chances
@export var player_rare_card_modifier_base: float = 0.0: set = set_player_rare_card_modifier_base	# the value the rarity modifier is reset to after a rare card is seen
@export var player_rare_card_increment_rate: float = 1.5	# every time a card is drafted that isn't rare, increase the modifier by this amount
#endregion

#region Artifact Rewards

## Maps ArtifactData object_uids to prototype instances of ArtifactData owned by the player. 
@export var player_artifact_uid_to_artifact_data: Dictionary[String, ArtifactData] = {}

## Artifact ordering for all artifacts object ids the player can see.
## Each time an artifact is seen it is popped off. Populated in initialize_artifact_pool().
## NOTE: This includes ALL artifacts, even ones from different characters that cannot be
## normally obtained in a run, and different filters will pop some while ignoring others. Doing it
## this way ensures that modifying what artifacts the player can see preserves the ordering.
## NOTE: Shops will search this in reverse order.
@export var player_artifact_pool: Array[String] = []

## A list of ArtifactPackData object ids that represent what artifacts a player is allowed to see in a run.
## Typically will be their color, and white(non specific) artifacts. This is used to 
## generate player_artifact_available_artifact_id_cache. Whenever this value is modified you
## should regenerate the cache.
@export var player_artifact_pack_ids: Array[String] = []

## A generated cache of all artifact object ids that the player is *capable* of seeing,
## derived from player_artifact_pack_ids. This behaves like a Set, only using the keys for
## efficient .has() checks, with null for values. If player_artifact_pack_ids is modified, call
## regenerate_artifact_available_id_cache().
## NOTE: This differs from player_artifact_pool in that the artifact pool maintains ordering of all possible
## artifacts, while player_artifact_available_artifact_id_cache acts as a filter.
var player_artifact_available_artifact_id_cache: Dictionary[String, Variant] = {
	#"<artifact_object_id>": null
}
#endregion

#region Consumable Rewards
## Works same as player_artifact_pack_ids. Determines what consumables a player can see in rewards.
@export var player_consumable_pack_ids: Array[String] = []

## Consumables that can never be included in consumable drafts. Does not take effect until cache regenerated
@export var player_reward_draft_consumable_id_blacklist: Array[String] = []
## Consumables that will always be included in consumable drafts.  Does not take effect until cache regenerated.
@export var player_reward_draft_consumable_id_whitelist: Array[String] = []

var player_reward_consumable_filter_cache: ConsumableFilter = null

## Works same as player_artifact_available_artifact_id_cache. A Set structure that defines
## what consumables can be seen by the player.
var player_consumable_available_consumable_id_cache: Dictionary[String, Variant] = {
	#"<consumable_object_id>": null
}

## All the consumable object ids available to the player, sorted into rarity buckets and cached. Used for consumable rewards.
var player_reward_consumable_rarity_cache: Dictionary[int, Array] = {}

#endregion


# Cards

## The player's permanent deck, persisting between combat. Changes to cards here will be
## permanent.
@export var player_deck: Array[CardData] = []

#region Taiwu Collection and Loadout
## 本局拥有的全部真气实例；与旧 CardData 牌组互不转换、互不镜像。
@export var player_qi_deck: Array[QiData] = []

## 本局功法实例库，以实例 UID 为键；同一固定功法 ID 只允许一个实例。
@export var player_gongfa_uid_to_gongfa_data: Dictionary[String, GongfaData] = {}

## 本局内功实例库，以实例 UID 为键；特殊效果可以允许同定义多实例。
@export var player_neigong_uid_to_neigong_data: Dictionary[String, NeigongData] = {}

## 八种牌型各自的功法槽容量；旧存档缺失的牌型在初始化时补为一。
@export var player_gongfa_hand_slot_counts: Dictionary[String, int] = {}

## 八种牌型各自的有序功法实例 UID 序列。
@export var player_gongfa_hand_sequences: Dictionary[String, Array] = {}

## 有序内功装备实例 UID；数组顺序也是同优先级效果的处理顺序。
@export var player_equipped_neigong_uids: Array[String] = []

## 内功基础装备容量；动态容量以后可通过独立查询钩子扩展。
@export var player_neigong_slot_count: int = 6
#endregion


# Statuses

## Maps status effect id to Array[BaseStatusEffect], allowing for potential duplicate status types.
var player_status_effects: Dictionary[String, Array] = {}

#region Consumables
@export var player_consumable_slot_count: int = 3	# max number of slots available
@export var player_consumable_slot_to_consumable_object_id: Dictionary[String, String] = {}	# maps a numerical slot index to a consumable id. 0 indexed

## Used as a general post-processing instantiation method after creating a
## new PlayerData instance or loading the game.
## Not the same as _init()
func init():
	normalize_taiwu_loadout_defaults()
	for qi_data: QiData in player_qi_deck:
		if qi_data != null:
			qi_data.normalize_after_load()
	generate_cache()
	# 旧版位置商店在读档后只做数据迁移，不触发任何购买或刷新效果。
	if player_shop_data != null:
		player_shop_data.normalize_after_load()

## Forces a regeneration of all internal cached data structures.
func generate_cache() -> void:
	regenerate_card_draft_card_filter()
	regenerate_artifact_available_id_cache()
	regenerate_consumable_available_id_cache()

## Adds or subtracts money from the player
## If goes into negative amounts, the proper delta will be calculated 
func add_money(amount: int) -> void:
	var old_player_money_amount: int = player_money
	player_money = max(player_money + amount, 0)
	var delta: int = player_money - old_player_money_amount
	Signals.player_money_changed.emit(delta)

## Gets an rng track for the run. If it does not exist create one.
func get_player_rng(rng_name: String) -> RandomNumberGenerator:
	if player_rng.has(rng_name):
		return player_rng[rng_name]
	
	# create and store new track
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = player_run_seed
	player_rng[rng_name] = rng
	return rng

func set_player_value(value_name: String, value: Variant) -> void:
	player_values[value_name] = value

## 为旧存档补齐八种牌型的容量和序列，不修改已有配装内容。
func normalize_taiwu_loadout_defaults() -> void:
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		if not player_gongfa_hand_slot_counts.has(hand_type_id):
			player_gongfa_hand_slot_counts[hand_type_id] = 1
		else:
			player_gongfa_hand_slot_counts[hand_type_id] = max(
				int(player_gongfa_hand_slot_counts[hand_type_id]), 1)
		if not player_gongfa_hand_sequences.has(hand_type_id):
			player_gongfa_hand_sequences[hand_type_id] = []
	player_neigong_slot_count = max(player_neigong_slot_count, 0)

## 将真气实例加入新真气牌组；固定定义对象不得直接传入。
func add_qi_instance(qi_data: QiData) -> bool:
	if qi_data == null or qi_data.object_uid == "" or not qi_data.is_valid_qi():
		return false
	for owned_qi_data: QiData in player_qi_deck:
		if owned_qi_data.object_uid == qi_data.object_uid:
			return false
	player_qi_deck.append(qi_data)
	Signals.player_qi_changed.emit()
	return true

## 将完整的 52 张标准扑克牌实例加入本局；重复调用只保留尚未拥有的牌。
func add_standard_qi_deck() -> int:
	var added_count: int = 0
	for qi_data: QiData in Global.get_standard_qi_deck_from_prototypes():
		if add_qi_instance(qi_data):
			added_count += 1
	return added_count

## 按固定内容 ID查找本局拥有的所有真气实例；同一固定牌面未来允许出现多份。
func get_owned_qi_by_definition_id(qi_object_id: String) -> Array[QiData]:
	var result: Array[QiData] = []
	for qi_data: QiData in player_qi_deck:
		if qi_data != null and qi_data.object_id == qi_object_id:
			result.append(qi_data)
	return result

## 按实例 UID 移除一张真气。
func remove_qi_instance(qi_instance_uid: String) -> bool:
	for qi_index: int in player_qi_deck.size():
		if player_qi_deck[qi_index].object_uid == qi_instance_uid:
			player_qi_deck.remove_at(qi_index)
			Signals.player_qi_changed.emit()
			return true
	return false

## 按本局实例 UID 读取一张真气；不存在时返回 null。
func get_owned_qi(qi_instance_uid: String) -> QiData:
	for qi_data: QiData in player_qi_deck:
		if qi_data.object_uid == qi_instance_uid:
			return qi_data
	return null

## 根据固定功法 ID 查找本局唯一实例。
func get_owned_gongfa_by_definition_id(gongfa_object_id: String) -> GongfaData:
	for gongfa_data: GongfaData in player_gongfa_uid_to_gongfa_data.values():
		if gongfa_data.object_id == gongfa_object_id:
			return gongfa_data
	return null

## 按实例 UID 读取已拥有功法。
func get_owned_gongfa(gongfa_instance_uid: String) -> GongfaData:
	return player_gongfa_uid_to_gongfa_data.get(gongfa_instance_uid, null)

## 加入一个此前未拥有的功法实例。
func add_gongfa_instance(gongfa_data: GongfaData) -> bool:
	if gongfa_data == null or gongfa_data.object_uid == "" or not gongfa_data.is_valid_gongfa():
		return false
	if get_owned_gongfa_by_definition_id(gongfa_data.object_id) != null:
		return false
	player_gongfa_uid_to_gongfa_data[gongfa_data.object_uid] = gongfa_data
	Signals.player_gongfa_changed.emit()
	return true

## 移除一个功法实例，并清理所有引用该实例的牌型槽。
func remove_gongfa_instance(gongfa_instance_uid: String) -> bool:
	if not player_gongfa_uid_to_gongfa_data.has(gongfa_instance_uid):
		return false
	player_gongfa_uid_to_gongfa_data.erase(gongfa_instance_uid)
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var current_sequence: Array = player_gongfa_hand_sequences.get(hand_type_id, [])
		while current_sequence.has(gongfa_instance_uid):
			current_sequence.erase(gongfa_instance_uid)
		player_gongfa_hand_sequences[hand_type_id] = current_sequence
	Signals.player_gongfa_changed.emit()
	Signals.player_gongfa_loadout_changed.emit()
	return true

## 通过预览拦截器纯查询功法当前有效可配置次数。
func get_effective_gongfa_equip_count(gongfa_instance_uid: String) -> int:
	var gongfa_data: GongfaData = get_owned_gongfa(gongfa_instance_uid)
	if gongfa_data == null:
		return 0
	var query_action: ActionQueryGongfaEquipCount = ActionQueryGongfaEquipCount.new()
	query_action.init(Global.get_player(), null, [], {
		"gongfa_data": gongfa_data,
		"gongfa_equip_count": gongfa_data.gongfa_owned_count,
	}, null)
	return query_action.query_effective_count()

## 通过纯预览查询指定牌型当前有效的功法槽容量。
func get_effective_gongfa_slot_count(hand_type_id: String) -> int:
	if not GongfaData.HAND_TYPE_IDS.has(hand_type_id):
		return 1
	var query_action: ActionQueryGongfaSlotCount = ActionQueryGongfaSlotCount.new()
	query_action.init(Global.get_player(), null, [], {
		"hand_type_id": hand_type_id,
		"gongfa_slot_count": int(player_gongfa_hand_slot_counts.get(hand_type_id, 1)),
	}, null)
	return query_action.query_effective_count()

## 通过纯预览查询当前有效的内功槽容量。
func get_effective_neigong_slot_count() -> int:
	var query_action: ActionQueryNeigongSlotCount = ActionQueryNeigongSlotCount.new()
	query_action.init(Global.get_player(), null, [], {
		"neigong_slot_count": player_neigong_slot_count,
	}, null)
	return query_action.query_effective_count()

## 校验一份完整功法配装；该方法只读取状态，不修改本局。
func validate_gongfa_loadout(candidate_sequences: Dictionary) -> bool:
	for candidate_hand_type: Variant in candidate_sequences.keys():
		if not candidate_hand_type is String \
			or not GongfaData.HAND_TYPE_IDS.has(candidate_hand_type):
			return false
	var use_count_by_gongfa_uid: Dictionary[String, int] = {}
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var sequence_value: Variant = candidate_sequences.get(hand_type_id, [])
		if not sequence_value is Array:
			return false
		var sequence: Array = sequence_value
		if sequence.size() > get_effective_gongfa_slot_count(hand_type_id):
			return false
		for gongfa_instance_uid_value: Variant in sequence:
			if not gongfa_instance_uid_value is String:
				return false
			var gongfa_instance_uid: String = gongfa_instance_uid_value
			var gongfa_data: GongfaData = get_owned_gongfa(gongfa_instance_uid)
			if gongfa_data == null or not gongfa_data.supports_hand_type(hand_type_id):
				return false
			use_count_by_gongfa_uid[gongfa_instance_uid] = \
				use_count_by_gongfa_uid.get(gongfa_instance_uid, 0) + 1
	for gongfa_instance_uid: String in use_count_by_gongfa_uid:
		if use_count_by_gongfa_uid[gongfa_instance_uid] \
				> get_effective_gongfa_equip_count(gongfa_instance_uid):
			return false
	return true

## 一次性替换全部功法序列；任一规则失败时不修改原配装。
func set_gongfa_loadout(candidate_sequences: Dictionary) -> bool:
	if not validate_gongfa_loadout(candidate_sequences):
		return false
	var normalized_sequences: Dictionary[String, Array] = {}
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		normalized_sequences[hand_type_id] = candidate_sequences.get(hand_type_id, []).duplicate()
	player_gongfa_hand_sequences = normalized_sequences
	Signals.player_gongfa_loadout_changed.emit()
	return true

## 返回当前功法配装是否仍满足动态有效次数等全部规则。
func is_current_gongfa_loadout_valid() -> bool:
	return validate_gongfa_loadout(player_gongfa_hand_sequences)

## 根据固定内功 ID 返回本局所有对应实例。
func get_owned_neigong_by_definition_id(neigong_object_id: String) -> Array[NeigongData]:
	var result: Array[NeigongData] = []
	for neigong_data: NeigongData in player_neigong_uid_to_neigong_data.values():
		if neigong_data.object_id == neigong_object_id:
			result.append(neigong_data)
	return result

## 按实例 UID 读取已拥有内功。
func get_owned_neigong(neigong_instance_uid: String) -> NeigongData:
	return player_neigong_uid_to_neigong_data.get(neigong_instance_uid, null)

## 加入一个内功实例。
func add_neigong_instance(neigong_data: NeigongData) -> bool:
	if neigong_data == null or neigong_data.object_uid == "" or not neigong_data.is_valid_neigong():
		return false
	if player_neigong_uid_to_neigong_data.has(neigong_data.object_uid):
		return false
	player_neigong_uid_to_neigong_data[neigong_data.object_uid] = neigong_data
	Signals.player_neigong_changed.emit()
	return true

## 移除一个内功实例，并从装备序列中清理该实例。
func remove_neigong_instance(neigong_instance_uid: String) -> bool:
	if not player_neigong_uid_to_neigong_data.has(neigong_instance_uid):
		return false
	player_neigong_uid_to_neigong_data.erase(neigong_instance_uid)
	player_equipped_neigong_uids.erase(neigong_instance_uid)
	Signals.player_neigong_changed.emit()
	Signals.player_neigong_loadout_changed.emit()
	return true

## 校验一份完整内功配装；该方法只读取状态，不修改本局。
func validate_neigong_loadout(candidate_uids: Array[String]) -> bool:
	if candidate_uids.size() > get_effective_neigong_slot_count():
		return false
	var seen_uids: Dictionary[String, bool] = {}
	for neigong_instance_uid: String in candidate_uids:
		if seen_uids.has(neigong_instance_uid) \
				or not player_neigong_uid_to_neigong_data.has(neigong_instance_uid):
			return false
		seen_uids[neigong_instance_uid] = true
	return true

## 一次性替换完整内功装备；任一规则失败时不修改原配装。
func set_neigong_loadout(candidate_uids: Array[String]) -> bool:
	if not validate_neigong_loadout(candidate_uids):
		return false
	player_equipped_neigong_uids.assign(candidate_uids)
	Signals.player_neigong_loadout_changed.emit()
	return true

## 返回指定内功实例当前是否处于装备状态。
func is_neigong_equipped(neigong_instance_uid: String) -> bool:
	return player_equipped_neigong_uids.has(neigong_instance_uid)

#endregion
#region Rest actions

func enable_rest_action(rest_action_object_id: String) -> void:
	# enables a rest action to populate at future rest sites
	if not player_available_rest_action_object_ids.has(rest_action_object_id):
		player_available_rest_action_object_ids.append(rest_action_object_id)

func disable_rest_action(rest_action_object_id: String) -> void:
	# disables a rest action from being populated at future rest sites
	player_available_rest_action_object_ids.erase(rest_action_object_id)

#endregion
#region Event Pools

## Obtains the next valid event from a given EventPoolData ID. If it does not exist, it will populate
## A copy of the pool into the player's event pools
func get_next_event_object_id_from_pool(event_pool_object_id: String) -> String:
	var next_event_object_id: String = "" # the returned event
	
	var event_pool_data: EventPoolData = Global.get_event_pool_data(event_pool_object_id)
	assert(event_pool_data != null)
	
	# get events in pool if they exist
	var event_pool_event_object_ids: Array[String] = []
	event_pool_event_object_ids.assign(player_event_pools.get(event_pool_object_id, []))
	
	# populate the event pool if it doesn't exist or is empty
	if len(event_pool_event_object_ids) == 0:
		var message: String = "Event Pool Empty; Populating {0}...".format([event_pool_object_id])
		DebugLogger.log_line(message, Color.YELLOW)
		# copy event ids from corresponding event pool
		for event_object_id: String in event_pool_data.event_pool_event_object_ids:
			if not event_pool_event_object_ids.has(event_object_id):
				event_pool_event_object_ids.append(event_object_id)
			
		# randomize the order and assign to the player event pools
		var rng_event_pool: RandomNumberGenerator = get_player_rng("rng_event_pool")
		event_pool_event_object_ids = Random.shuffle_array(rng_event_pool, event_pool_event_object_ids)
		player_event_pools[event_pool_object_id] = event_pool_event_object_ids
		
		message = "Event Pool Repopulated: {0}".format([str(event_pool_event_object_ids)])
		DebugLogger.log_line(message, Color.WEB_GREEN)
	
	# find the first event that passes validators and store events that don't pass
	var failed_event_object_ids: Array[String] = [] # events that fail their validators and must be handled
	for event_object_id: String in event_pool_event_object_ids:
		var event_data: EventData = Global.get_event_data(event_object_id)
		if event_data == null:
			DebugLogger.log_error("No event with ID \"{0}\" found".format(event_object_id))
			continue
		
		var validators_passed: bool = event_data.validate_event()
		if validators_passed:
			next_event_object_id = event_data.object_id
			break # valid event found, no need to keep looking
		
	# handle each failed event according to its strategy for how it should be put back into the
	# event pool.
	for failed_event_object_id: String in failed_event_object_ids:
		var event_data: EventData = Global.get_event_data(failed_event_object_id)
		if event_data == null:
			DebugLogger.log_error("No event with ID \"{0}\" found".format(failed_event_object_id))
			continue
		#TODO
		var validator_failed_strategy = event_data.location_event_pool_validator_failed_strategy
		# if not keeping, remove it
		if not validator_failed_strategy == EventData.FailedEventPoolStrategies.KEEP:
			event_pool_event_object_ids.erase(failed_event_object_id)
		
		match validator_failed_strategy:
			EventData.FailedEventPoolStrategies.APPEND:
				event_pool_event_object_ids.append(failed_event_object_id)
			EventData.FailedEventPoolStrategies.REMOVE:
				pass # do nothing
			EventData.FailedEventPoolStrategies.REINSERT:
				# randomly insert the event somewhere along the pool
				var rng_event_pool: RandomNumberGenerator = get_player_rng("rng_event_pool")
				var random_index: int = rng_event_pool.randi_range(0, len(event_pool_event_object_ids))
				event_pool_event_object_ids.insert(random_index, failed_event_object_id)
			EventData.FailedEventPoolStrategies.BLACKLIST:
				player_event_blacklisted_ids.append(failed_event_object_id)
	
	# attempt fallback of empty/invalid pool
	if next_event_object_id == "":
		next_event_object_id = event_pool_data.event_pool_fallback_event_object_id
		
	assert(next_event_object_id != "")
	
	# remove the event from the pool
	event_pool_event_object_ids.erase(next_event_object_id)
	player_event_pools[event_pool_object_id] = event_pool_event_object_ids
	
	# display the event
	var message: String = "Event Pool: {0} popped from {1}".format([next_event_object_id, event_pool_object_id])
	DebugLogger.log_line(message)
	
	return next_event_object_id

#endregion
#endregion Consumables

## Gets ids of all consumables from non empty slots.
## Allows duplicates.
func get_available_consumable_ids() -> Array[String]:
	var available_consumable_ids: Array[String] = []
	for consumable_slot: String in player_consumable_slot_to_consumable_object_id:
		available_consumable_ids.append(player_consumable_slot_to_consumable_object_id[consumable_slot])
	
	return available_consumable_ids

func are_consumable_slots_full() -> bool:
	return len(player_consumable_slot_to_consumable_object_id.keys()) >= player_consumable_slot_count

func get_consumable_in_slot(consumable_slot: int) -> ConsumableData:
	if player_consumable_slot_to_consumable_object_id.has(str(consumable_slot)):
		var consumable_object_id: String = player_consumable_slot_to_consumable_object_id[str(consumable_slot)]
		return Global.get_consumable_data(consumable_object_id)
	return null
	
func get_empty_consumable_slot_count() -> int:
	return player_consumable_slot_count - len(player_consumable_slot_to_consumable_object_id.keys())

#endregion
#region Health

func heal_percentage(percent: float):
	var percentage_health: int = int(ceil(float(Global.player_data.player_health_max) * percent))
	add_health(percentage_health, 0)

func add_health(health_amount: int, health_amount_max: int = 0) -> void:
	# wrapper method
	# adds or removes relative health
	set_health(player_health + health_amount, player_health_max + health_amount_max)

func set_health(health_amount: int, health_amount_max: int = player_health_max) -> void:
	player_health_max = max(1, health_amount_max)
	player_health = clamp(0, health_amount, player_health_max)
	Signals.player_health_changed.emit()

#endregion
#region Deck
func add_card_to_deck(card_data: CardData) -> void:
	player_deck.append(card_data)
	
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, false, false)
	var player: Player = Global.get_player()
	var card_add_to_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_add_to_deck_actions, null)
	ActionHandler.add_actions(card_add_to_deck_actions)
	
	Signals.card_added_to_deck.emit(card_data)

func remove_card_from_deck(card_data: CardData) -> void:
	player_deck.erase(card_data)
	
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, false, false)
	var player: Player = Global.get_player()
	var card_remove_from_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_remove_from_deck_actions, null)
	ActionHandler.add_actions(card_remove_from_deck_actions)
	
	Signals.card_removed_from_deck.emit(card_data)

func transform_card_in_deck(card_data: CardData, new_card_object_id: String) -> void:
	# perform transform actions on old card
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(card_data, null, false, false)
	var player: Player = Global.get_player()
	var card_transform_in_deck_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_transform_in_deck_actions, null)
	ActionHandler.add_actions(card_transform_in_deck_actions)
	
	# remove the card, transform it, and re-add it to player's deck, triggering all relevant card actions
	remove_card_from_deck(card_data)
	card_data.transform_card(new_card_object_id)
	add_card_to_deck(card_data)
	
	Signals.card_transformed_in_deck.emit(card_data)

#endregion
#region Run Artifacts

## Generates a list of all artifacts the player can theoretically encounter in a run. Should only be called
## on run start from Global.start_run().
func initialize_artifact_pool() -> void:
	var artifact_ids: Array = Global._id_to_artifact_data.keys().duplicate(true) # get all artifacts
	var artifact_rng: RandomNumberGenerator = get_player_rng("rng_artifact_rewards")
	Random.shuffle_array(artifact_rng, artifact_ids)
	player_artifact_pool.assign(artifact_ids)

## Wrapper method for get_next_artifacts_from_pool() that gets the next standard artifacts for a shop.
## Pulls from the back of the artifact list.
func get_next_shop_standard_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, ArtifactData.STANDARD_ARTIFACT_RARITIES, false, true, mutate_artifact_pool)
## Wrapper method for get_next_artifacts_from_pool() that gets the next artifacts that can ONLY be obtained from the shop.
## Pulls from the back of the list
func get_next_shop_specific_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, [ArtifactData.ARTIFACT_RARITIES.SHOP], false, true, mutate_artifact_pool)
func get_next_boss_artifacts_from_pool(artifact_count: int, mutate_artifact_pool: bool = true) -> Array[String]:
	return get_next_artifacts_from_pool(artifact_count, [ArtifactData.ARTIFACT_RARITIES.BOSS], false, false, mutate_artifact_pool)

## General use method for returning the next artifacts available to the player, from the list of
## all artifacts.
## use_rarity_ordering = true means that the method will exhaustively search all available artifacts
## to ensure that rarity is used up. Failing to find any remaining artifacts of that rarity, it will
## fall back to other rarities. If false, it will use the first artifact that matches any of the
## given rarities provided.
## mutate_artifact_pool = false will ensure the artifacts are not removed from the list, allowing you to simply
## get the next results without modifying it.
func get_next_artifacts_from_pool(artifact_count: int, artifact_rarities: Array[int], use_rarity_ordering: bool = false, from_back: bool = false, mutate_artifact_pool: bool = true) -> Array[String]:
	# pops standard artifacts from the artifact pool and returns them
	var returned_artifact_ids: Array[String] = []
	if len(artifact_rarities) == 0:
		DebugLogger.log_warning("PlayerData.get_next_artifacts_from_pool() called with empty rarities")
		return []
	
	var artifact_pool: Array[String] = player_artifact_pool.duplicate()
	if from_back:
		artifact_pool.reverse()
	
	var rarity_to_artifact_ids: Dictionary[int, Array] = {}
	
	for artifact_id: String in artifact_pool:
		if not player_artifact_available_artifact_id_cache.has(artifact_id):
			continue # must be something the player can get
		if returned_artifact_ids.has(artifact_id):
			continue # must not already be drafted
		var artifact_data: ArtifactData = Global.get_artifact_data(artifact_id)
		if artifact_data == null:
			continue # must exist
		if not artifact_rarities.has(artifact_data.artifact_rarity):
			continue # must be of matching rarity

		if not use_rarity_ordering:
			# greedily get artifacts as they appear
			returned_artifact_ids.append(artifact_id)
			if len(returned_artifact_ids) >= artifact_count:
				break
		else:
			# assign the artifact to a buckets for processing later
			var rarity_bucket: Array = rarity_to_artifact_ids.get(artifact_data.artifact_rarity, [])
			rarity_bucket.append(artifact_id)
			rarity_to_artifact_ids[artifact_data.artifact_rarity] = rarity_bucket
	
	if use_rarity_ordering:
		# convert rarity buckets to a single list, in order of rarity priority
		var rarity_ordered_artifact_ids: Array = []
		for artifact_rarity: int in artifact_rarities:
			var rarity_bucket: Array = rarity_to_artifact_ids.get(artifact_rarity, [])
			rarity_ordered_artifact_ids.append_array(rarity_bucket)
		
		for artifact_id: String in rarity_ordered_artifact_ids:
			returned_artifact_ids.append(artifact_id)
			if len(returned_artifact_ids) >= artifact_count:
				break
		
	# remove entries from pool
	if mutate_artifact_pool:
		for artifact_id: String in returned_artifact_ids:
			remove_artifact_from_pool(artifact_id)
	
	return returned_artifact_ids


func remove_artifact_from_pool(artifact_object_id: String) -> void:
	player_artifact_pool.erase(artifact_object_id)

#endregion
#region Player Artifacts

func add_artifact(artifact_id: String) -> void:
	# adds an artifact to the player as if they obtained it
	if get_player_artifacts_with_artifact_id(artifact_id).is_empty():
		var artifact_data: ArtifactData = Global.get_artifact_data_from_prototype(artifact_id)
		
		if artifact_data == null:
			DebugLogger.log_error("Player.add_artifact(): No artifact of id \"{0}\"".format([artifact_id]))
		else:
			player_artifact_uid_to_artifact_data[artifact_data.object_uid] = artifact_data
		
			# use a temp artifact script to perform any logic if the artifact has effect when added
			var artifact_script_asset: Resource = load(artifact_data.artifact_script_path)
			var artifact_script: BaseArtifact = artifact_script_asset.new(artifact_data)
			artifact_script.add_artifact()
			Signals.player_artifacts_changed.emit()
			Signals.player_artifact_added.emit(artifact_data)
			
			# remove artifact from spawn pool in case it wasn't already
			remove_artifact_from_pool(artifact_data.object_id)

## Removes an artifact of a given type from player. If remove_multiples = true all instances of
## a given type will be removed.
func remove_artifact(artifact_id: String, remove_multiples: bool = true) -> void:
	var artifacts: Array[ArtifactData] = get_player_artifacts_with_artifact_id(artifact_id)
	for artifact_data: ArtifactData in artifacts:
		# use a temp artifact script to perform any logic if the artifact has effect when removed
		var artifact_script_asset: Resource = load(artifact_data.artifact_script_path)
		var artifact_script: BaseArtifact = artifact_script_asset.new(artifact_data)
		artifact_script.remove_artifact()
		
		player_artifact_uid_to_artifact_data.erase(artifact_data.object_uid)
		Signals.player_artifacts_changed.emit()
		Signals.player_artifact_removed.emit(artifact_data)
		
		# prevents multiple of an artifact from being removed
		if not remove_multiples:
			return

func get_player_artifacts() -> Array:
	return player_artifact_uid_to_artifact_data.values()

## Gets all artifact data prototypes, if any, with the given artifact id in player's possession
func get_player_artifacts_with_artifact_id(artifact_object_id: String) -> Array[ArtifactData]:
	var returned_artifacts: Array[ArtifactData] = []
	for artifact_data: ArtifactData in player_artifact_uid_to_artifact_data.values():
		if artifact_data.object_id == artifact_object_id:
			returned_artifacts.append(artifact_data)
	
	return returned_artifacts
#endregion

## 修复 PlayerData 原型复制后仍引用旧功法、内功实例 UID 的配装字段。
func _repair_internal_uids(old_uid_to_new_uid: Dictionary[String, String]) -> void:
	for hand_type_id: String in GongfaData.HAND_TYPE_IDS:
		var sequence: Array = player_gongfa_hand_sequences.get(hand_type_id, [])
		for sequence_index: int in sequence.size():
			sequence[sequence_index] = old_uid_to_new_uid.get(
				sequence[sequence_index], sequence[sequence_index])
		player_gongfa_hand_sequences[hand_type_id] = sequence
	for equipped_index: int in player_equipped_neigong_uids.size():
		player_equipped_neigong_uids[equipped_index] = old_uid_to_new_uid.get(
			player_equipped_neigong_uids[equipped_index],
			player_equipped_neigong_uids[equipped_index])

## Gets the texture corresponding to the color for this player.
func get_player_character_color_texture_path() -> String:
	if player_character_object_id == "":
		return ""
	var character_data: CharacterData = Global.get_character_data(player_character_object_id)
	if character_data == null:
		return ""
	if character_data.character_color_id == "":
		return ""
	var color_data: ColorData = Global.get_color_data(character_data.character_color_id)
	if color_data != null:
		return color_data.color_energy_icon_texture_path
	
	return ""

#region Misc

func set_player_rare_card_modifier_base(value: float) -> void:
	# adjusting the base also adjusts the current rarity value
	player_rare_card_modifier_base = value
	player_rare_card_modifier_current = max(player_rare_card_modifier_current, value)

## Forces PlayerData to regenerate the card filter used to determine card drafts by combining a list
## of card packs and other lists/flags. This should be called after mutating anything that should
## affect the pool of cards available to the player.
## NOTE: This implementation may not be the most efficienct, consider revision.
func regenerate_card_draft_card_filter() -> void:
	# merge all the card pack card ids together
	var card_unique_object_ids: Dictionary[String, Variant] = {}
	for reward_draft_card_pack_id: String in reward_draft_card_pack_ids:
		var card_pack_card_filter: CardFilter = Global.get_cached_card_filter(reward_draft_card_pack_id) # cache uses same id as card packs
		card_unique_object_ids.merge(card_pack_card_filter.filtered_card_unique_object_ids)
	
	# whitelisted and blacklisted card ids
	for card_object_id: String in player_reward_draft_card_id_blacklist:
		card_unique_object_ids.erase(card_object_id)
	for card_object_id: String in player_reward_draft_card_id_whitelist:
		card_unique_object_ids[card_object_id] = null
	
	# create a new filter using the read only card object ids provided
	var card_filter: CardFilter = CardFilter.new([], card_unique_object_ids.keys())
	
	# cache results
	player_reward_card_filter_cache = card_filter
	
	# sort cards into buckets by rarity
	var reward_card_rarity_buckets: Dictionary[int, Array] = {}
	for card_data: CardData in card_filter.filtered_cards:
		var bucket: Array = reward_card_rarity_buckets.get(card_data.card_rarity, [])
		bucket.append(card_data.object_id)
		reward_card_rarity_buckets[card_data.card_rarity] = bucket
	
	# cache results
	player_reward_card_rarity_cache = reward_card_rarity_buckets

## Forces PlayerData to regenerate the artifact filter used to determine artifact drafts by combining a list
## of artifact packs and other lists/flags. This should be called after mutating anything that should
## affect the pool of artifacts available to the player.
## NOTE: This implementation may not be the most efficienct, consider revision.
func regenerate_artifact_available_id_cache() -> void:
	# merge all the artifact pack artifact ids together
	var artifact_unique_object_ids: Dictionary[String, Variant] = {}
	for player_artifact_pack_id: String in player_artifact_pack_ids:
		var artifact_pack_artifact_filter: ArtifactFilter = Global.get_cached_artifact_filter(player_artifact_pack_id) # cache uses same id as artifact packs
		artifact_unique_object_ids.merge(artifact_pack_artifact_filter.filtered_artifact_unique_object_ids)
	
	# cache results
	player_artifact_available_artifact_id_cache = artifact_unique_object_ids

## Gets all consumables the player can potentially obtain via packs, whitelists, and blacklists
## merges the results and caches them.
func regenerate_consumable_available_id_cache() -> void:
	# merge all the consumable pack consumable ids together
	var consumable_unique_object_ids: Dictionary[String, Variant] = {}
	for player_consumable_pack_id: String in player_consumable_pack_ids:
		var consumable_pack_consumable_filter: ConsumableFilter = Global.get_cached_consumable_filter(player_consumable_pack_id) # cache uses same id as consumable packs
		consumable_unique_object_ids.merge(consumable_pack_consumable_filter.filtered_consumable_unique_object_ids)
	
	# whitelisted and blacklisted consumable ids
	for consumable_object_id: String in player_reward_draft_consumable_id_blacklist:
		consumable_unique_object_ids.erase(consumable_object_id)
	for consumable_object_id: String in player_reward_draft_consumable_id_whitelist:
		consumable_unique_object_ids[consumable_object_id] = null
	
	# create a new filter using the read only card object ids provided
	var consumable_filter: ConsumableFilter = ConsumableFilter.new([], consumable_unique_object_ids.keys())
	
	# cache results
	player_consumable_available_consumable_id_cache = consumable_unique_object_ids
	player_reward_consumable_filter_cache = consumable_filter
	
	# sort consumables into buckets by rarity and cache
	var reward_consumable_rarity_buckets: Dictionary[int, Array] = {}
	for consumable_data: ConsumableData in consumable_filter.filtered_consumables:
		var bucket: Array = reward_consumable_rarity_buckets.get(consumable_data.consumable_rarity, [])
		bucket.append(consumable_data.object_id)
		reward_consumable_rarity_buckets[consumable_data.consumable_rarity] = bucket
	
	# cache rarity buckets
	player_reward_consumable_rarity_cache = reward_consumable_rarity_buckets
#endregion

func _get_native_properties() -> Dictionary:
	return {
		"player_rng": RandomNumberGenerator.new(),
	}
