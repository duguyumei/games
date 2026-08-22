## Singleton for generating actions.
## Provides wrappers for common actions used across by the UI and framework.
extends Node

## General use factory method for creating actions.
## Creates and initializes actions from a script path and values.
## Action data is [{"script_path": {values}}].
## NOTE: Not automatically added to the stack and performed; do so with ActionHandler.add_actions()
func create_actions(_parent_combatant: BaseCombatant, _card_play_request: CardPlayRequest, _targets: Array[BaseCombatant], actions_data: Array[Dictionary], _parent_action: BaseAction) -> Array[BaseAction]:
	
	var actions: Array[BaseAction] = []
	
	for action_data in actions_data:
		for action_path in action_data:
			var action_asset = load(action_path)
			var action: BaseAction = action_asset.new()
			
			var action_values: Dictionary[String, Variant] = {}
			action_values.assign(action_data[action_path]) # # assign to force typed dict
			
			action.init(_parent_combatant, _card_play_request, _targets, action_values, _parent_action)
			actions.append(action)
	
	return actions

## Makes a CardPlay action. These are used in Card and Hand for interception purposes.
func generate_card_play(card_play_request: CardPlayRequest) -> BaseAction:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_CARD_PLAY: {}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), card_play_request, [], action_data, null)[0]
	
	return generated_action

## Makes a CardPlayEnded action, used in Hand. This is used to signify that all actions in a card play are finished.
func generate_card_play_finished(card_play_request: CardPlayRequest) -> BaseAction:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_CARD_PLAY_END: {}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), card_play_request, [], action_data, null)[0]
	
	return generated_action

## Used in Hand to draw cards at the start of a turn.
func generate_start_of_turn_draw_actions(number_of_cards: int = HandManager.PLAYER_CARD_DRAW_PER_TURN) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_DRAW_GENERATOR: {
			"draw_count": number_of_cards,
			"is_start_of_turn_draw": true # use interceptors checking this flag to adjust number_of_cards
		}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Used in Combat to reset the player's energy and add energy
func generate_start_of_turn_energy_actions() -> void:
	var action_data: Array[Dictionary] = [
		{Scripts.ACTION_ADD_ENERGY: {"energy_amount": Global.player_data.player_energy_max, "time_delay": 0}},
		{Scripts.ACTION_RESET_ENERGY: {}}
		]
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)
	
	var add_energy_action: BaseAction = generated_actions[0]
	var reset_energy_action: BaseAction = generated_actions[1]
	
	# immediately process this action without ActionHandler
	reset_energy_action.perform_action()
	add_energy_action.perform_action()


## Makes a special rest action end action
func generate_rest_action_end(rest_action_id: String) -> BaseAction:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_REST_ACTION_END: {
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER,
			"rest_action_id": rest_action_id
		}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	return generated_action


## Generates the map for an act using an action, given an act to use.
func generate_act(act_id: String, act_number: int = 1) -> void:
	var act_data: ActData = Global.get_act_data(act_id)
	var action_data: Array[Dictionary] = [{
		act_data.act_action_script_path: {
			"act_id": act_id,
			"act_number": act_number,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Given the player's current act, randomly selects and generates the next act.
func generate_next_act() -> void:
	var act_number: int = Global.player_data.player_act
	var act_data: ActData = Global.get_act_data(Global.player_data.player_act_id)
	
	var rng_act_selection: RandomNumberGenerator = Global.player_data.get_player_rng("rng_act_selection")
	
	if len(act_data.act_next_act_ids) > 0:
		# randomly select the next act type
		var act_next_act_ids: Array[String] = Random.shuffle_array(rng_act_selection, act_data.act_next_act_ids.duplicate())
		var next_act_id: String = act_next_act_ids[0]
		# generate the next act
		generate_act(next_act_id, act_number + 1)
	else:
		DebugLogger.log_error("ActionGenerator.generate_next_act(): No next acts defined in act \"{0}\"".format([act_data.object_id]))

## Forces a visit to a given location id using action system.
## Used by Map when selecting a location.
func generate_visition_location(location_id: String, autosave_before_visit = true) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_VISIT_LOCATION: {
			"location_id": location_id,
			"autosave_before_visit": autosave_before_visit
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

func generate_chest_open() -> void:
	# generate a reward payload, which can be intercepted
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_OPEN_CHEST: {
			"chest_has_money": true,
			"chest_has_artifacts": true,
			"chest_has_consumables": true,
			"chest_has_cards": true,
			
			"chest_generates_money": true,
			"chest_generates_artifacts": true,
			"chest_generates_consumables": true,
			"chest_generates_cards": true,

			"chest_money_amount": 25,
			"chest_artifact_count": 1,
			"chest_consumable_count": 1,
			"chest_card_amount_draft": Global.player_data.reward_drafts,
			"chest_cards_per_draft": Global.player_data.reward_cards_per_draft,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Adds rewards from the location to the end of combat rewards
func generate_add_location_rewards() -> void:
	var player: Player = Global.get_player()
	var action_data: Array[Dictionary] = [{
	Scripts.ACTION_GRANT_REWARDS: {
		"reward_group": 0,
		"money_amount": Random.get_location_money_reward(),
		"card_drafts": Random.get_location_card_rewards(),
		"artifact_ids": Random.get_location_artifact_rewards(),
		}
	}]
	var grant_reward_action: BaseAction = ActionGenerator.create_actions(player, null, [player], action_data, null)[0]
	grant_reward_action.perform_action()

## 生成并立即执行一次可拦截的商店分栏刷新。
func generate_populate_shop_items(
		normal_offers: Dictionary[String, ShopOfferData],
		pack_offers: Dictionary[String, ShopOfferData],
		artifact_offers: Dictionary[String, ShopOfferData],
		replace_normal: bool,
		replace_pack: bool,
		replace_artifact: bool,
		refresh_token: String) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_SHOP_POPULATE_ITEMS: {
			"normal_offers": normal_offers,
			"pack_offers": pack_offers,
			"artifact_offers": artifact_offers,
			"replace_normal": replace_normal,
			"replace_pack": replace_pack,
			"replace_artifact": replace_artifact,
			"refresh_token": refresh_token,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## 将冥想行为加入统一行为队列，使费用和候选都可以被拦截。
func generate_shop_meditation() -> void:
	var shop_data: ShopData = Global.get_shop_data()
	if shop_data == null:
		return
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_SHOP_MEDITATE: {
			"money_amount": shop_data.next_meditation_cost,
		}
	}]
	var generated_action: BaseAction = ActionGenerator.create_actions(
		Global.get_player(), null, [], action_data, null)[0]
	ActionHandler.add_action(generated_action)

## 将一个太吾领域行为加入统一行为队列。
func generate_taiwu_data_action(
		action_script_path: String,
		action_values: Dictionary[String, Variant]) -> void:
	var action_data: Array[Dictionary] = [{action_script_path: action_values}]
	var generated_action: BaseAction = ActionGenerator.create_actions(
		Global.get_player(), null, [], action_data, null)[0]
	ActionHandler.add_action(generated_action)

## 经过行为管线获得一张真气。
func generate_add_qi(qi_object_id: String) -> void:
	generate_taiwu_data_action(Scripts.ACTION_ADD_QI, {
		"qi_object_id": qi_object_id,
	})

## 经过行为管线移除一张真气实例。
func generate_remove_qi(qi_instance_uid: String) -> void:
	generate_taiwu_data_action(Scripts.ACTION_REMOVE_QI, {
		"qi_instance_uid": qi_instance_uid,
	})

## 经过行为管线给一张真气应用重塑；scope=run 写入本局，scope=battle 写入战斗现场。
func generate_apply_qi_reshape(
		qi_instance_uid: String,
		reshape_definition_id: String,
		result_values: Dictionary[String, Variant],
		scope: String = QiReshapeData.SCOPE_RUN) -> void:
	generate_taiwu_data_action(Scripts.ACTION_APPLY_QI_RESHAPE, {
		"qi_instance_uid": qi_instance_uid,
		"reshape_definition_id": reshape_definition_id,
		"result_values": result_values,
		"scope": scope,
	})

## 经过行为管线移除一张真气的本局重塑槽。
func generate_remove_qi_reshape(
		qi_instance_uid: String,
		reshape_slot: String,
		scope: String = QiReshapeData.SCOPE_RUN,
		reshape_state_uid: String = "") -> void:
	generate_taiwu_data_action(Scripts.ACTION_REMOVE_QI_RESHAPE, {
		"qi_instance_uid": qi_instance_uid,
		"reshape_slot": reshape_slot,
		"reshape_state_uid": reshape_state_uid,
		"scope": scope,
	})

## 经过行为管线给一张真气应用异状；scope=run 写入本局，scope=battle 写入战斗现场。
func generate_apply_qi_anomaly(
		qi_instance_uid: String,
		anomaly_definition_id: String,
		stacks: int = 1,
		secondary_stacks: int = 0,
		scope: String = QiAnomalyData.SCOPE_BATTLE) -> void:
	generate_taiwu_data_action(Scripts.ACTION_APPLY_QI_ANOMALY, {
		"qi_instance_uid": qi_instance_uid,
		"anomaly_definition_id": anomaly_definition_id,
		"stacks": stacks,
		"secondary_stacks": secondary_stacks,
		"scope": scope,
	})

## 经过行为管线移除一张真气的本局异状。
func generate_remove_qi_anomaly(
		qi_instance_uid: String,
		anomaly_definition_id: String,
		scope: String = QiAnomalyData.SCOPE_BATTLE) -> void:
	generate_taiwu_data_action(Scripts.ACTION_REMOVE_QI_ANOMALY, {
		"qi_instance_uid": qi_instance_uid,
		"anomaly_definition_id": anomaly_definition_id,
		"scope": scope,
	})

## 经过行为管线获得功法；默认不允许重复获得。
func generate_add_gongfa(gongfa_object_id: String) -> void:
	generate_taiwu_data_action(Scripts.ACTION_ADD_GONGFA, {
		"gongfa_object_id": gongfa_object_id,
	})

## 经过行为管线遗忘功法实例的一定次数。
func generate_remove_gongfa(gongfa_instance_uid: String, remove_count: int = 1) -> void:
	generate_taiwu_data_action(Scripts.ACTION_REMOVE_GONGFA, {
		"gongfa_instance_uid": gongfa_instance_uid,
		"gongfa_remove_count": remove_count,
	})

## 经过行为管线一次性替换八种牌型的功法序列。
func generate_set_gongfa_loadout(gongfa_hand_sequences: Dictionary) -> void:
	generate_taiwu_data_action(Scripts.ACTION_SET_GONGFA_LOADOUT, {
		"gongfa_hand_sequences": gongfa_hand_sequences,
	})

## 经过行为管线获得内功；默认不允许同定义重复获得。
func generate_add_neigong(neigong_object_id: String) -> void:
	generate_taiwu_data_action(Scripts.ACTION_ADD_NEIGONG, {
		"neigong_object_id": neigong_object_id,
	})

## 经过行为管线移除一个内功实例。
func generate_remove_neigong(neigong_instance_uid: String) -> void:
	generate_taiwu_data_action(Scripts.ACTION_REMOVE_NEIGONG, {
		"neigong_instance_uid": neigong_instance_uid,
	})

## 经过行为管线一次性替换内功装备顺序。
func generate_set_neigong_loadout(equipped_neigong_uids: Array[String]) -> void:
	generate_taiwu_data_action(Scripts.ACTION_SET_NEIGONG_LOADOUT, {
		"equipped_neigong_uids": equipped_neigong_uids,
	})

## Generates and instantly performs an action to give the player an artifact
func generate_add_artifact(artifact_id: String) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_ADD_ARTIFACT: {
			"target_overrides": BaseAction.TARGET_OVERRIDES.PLAYER,
			"artifact_id": artifact_id
		}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	generated_action.perform_action()

## Forces a combat start that can be intercepted.
## If event_object_id is empty, uses current location's event.
func generate_combat_start(event_object_id: String) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_START_COMBAT: {
			"event_object_id": event_object_id
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Makes a CardPlay action. These are used in Card and Hand for interception purposes.
func generate_consumable(card_play_request: CardPlayRequest) -> BaseAction:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_CONSUMABLE: {}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), card_play_request, [], action_data, null)[0]
	
	return generated_action


## Generates and instantly performs an action to use a consumable in a given slot.
func generate_use_consumable(selected_target: BaseCombatant, consumable_slot_index: int, perform_comsumable_actions_instantly: bool = false) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_USE_CONSUMABLE: {
			"consumable_slot_index": consumable_slot_index,
			"perform_comsumable_actions_instantly": perform_comsumable_actions_instantly,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [selected_target], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates an instant death action which is interceptable.
## Not the same as killing the target.
func generate_combatant_death(combatant: BaseCombatant) -> void:
	var action_data: Array[Dictionary] = [{Scripts.ACTION_DEATH: {}}]
	var generated_action: BaseAction = ActionGenerator.create_actions(combatant, null, [combatant], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates an instant interceptable action to decay a status. Used by BaseCombatant.
func generate_decay_status_effect(selected_target: BaseCombatant, status_effect_object_id: String, decay_amount: int) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_DECAY_STATUS: {
			"status_effect_object_id": status_effect_object_id,
			"status_charge_amount": decay_amount
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [selected_target], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()
	
## Creates an interceptable artifact increment action which is added to the action stack.
## This provides an alternate way of changing the counter in a way that can be manipulated and
## consistent with the stack, compared to increment_artifact_counter()
func generate_artifact_counter_increment_action(artifact_data: ArtifactData, increment_amount: int) -> void:
	var player: Player = Global.get_player()
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true) # dummy card play request
	var action_data: Array[Dictionary] = [{Scripts.ACTION_INCREASE_ARTIFACT_CHARGE: {}}]
	# You can use custom_key_names in the artifact's action payloads to convert
	# artifact_counter into a parameter of the action
	card_play_request.card_values = {
		"artifact_data": artifact_data,
		"artifact_charge_increase": increment_amount
	}
	
	var actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], action_data, null)
	ActionHandler.add_actions(actions, true)
	
## Creates card decorator actions specific to when you add decorators to a card, and adds them to the stack.
func generate_decorator_actions(card_data: CardData, card_decorator_id: String) -> void:
	var player: Player = Global.get_player()
	var card_play_request: CardPlayRequest = HandManager.create_card_play_request(null, null, false, true) # dummy card play request
	var card_decorator_data: CardDecoratorData = Global.get_card_decorator_data(card_decorator_id)
	var action_data: Array[Dictionary] = card_decorator_data.card_decorator_add_to_card_actions
	
	var actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], action_data, null)
	ActionHandler.add_actions(actions, true)

## Generates an instant message of the player saying they don't have enough energy to play a card.
func generate_insufficient_energy_speech_bubble() -> void:
	var player: Player = Global.get_player()
	var action_data: Array[Dictionary] = [{Scripts.ACTION_TALK: {"message_bbcode": "I don't have enough energy!"}}]
	
	var generated_action: BaseAction = ActionGenerator.create_actions(player, null, [player], action_data, null)[0]
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates and instantly plays a sound file
func generate_sound_action(audio_path: String, audio_path_is_absolute: bool = false):
	var player: Player = Global.get_player()
	var action_data: Array[Dictionary] = [{Scripts.ACTION_PLAY_SOUND: {"audio_path": audio_path, "audio_path_is_absolute": audio_path_is_absolute}}]

	var generated_action: BaseAction = ActionGenerator.create_actions(player, null, [], action_data, null)[0]
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates and instantly plays a music track
func generate_music_action(audio_path: String, audio_crossfade_duration: float = 3.0):
	var player: Player = Global.get_player()
	var action_data: Array[Dictionary] = [{Scripts.ACTION_PLAY_MUSIC: {"audio_path": audio_path, "audio_crossfade_duration": audio_crossfade_duration}}]

	var generated_action: BaseAction = ActionGenerator.create_actions(player, null, [], action_data, null)[0]
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates and instantly plays music relevant to the location
## NOTE: If no music path is specified for each type it will be silent.
func generate_location_music_action() -> void:
	var act_data: ActData = Global.get_act_data(Global.player_data.player_act_id)
	var location_data: LocationData = Global.get_player_location_data()
	if location_data == null:
		breakpoint
		DebugLogger.log_error("No player location")
		return
	var location_event_id: String = location_data.get_location_event_object_id()
	# attempt to get music for event
	if location_event_id != "":
		var event_data: EventData = Global.get_event_data(location_event_id)
		if event_data == null:
			breakpoint
			DebugLogger.log_error("No event at current location")
			return
		else:
			if event_data.event_music_file_path != "":
				ActionGenerator.generate_music_action(act_data.event_music_file_path)
				return
	# otherwise use location type
	match location_data.location_type:
		LocationData.LOCATION_TYPES.STARTING, LocationData.LOCATION_TYPES.TREASURE:
			ActionGenerator.generate_music_action(FileLoader.MUSIC_DEFAULT_AMBIENT_AUDIO_PATH)
		LocationData.LOCATION_TYPES.REST_SITE:
			ActionGenerator.generate_music_action(FileLoader.MUSIC_REST_SITE_AUDIO_PATH)
		LocationData.LOCATION_TYPES.EVENT:
			if act_data.act_music_ambient_file_path != "":
				ActionGenerator.generate_music_action(act_data.act_music_ambient_file_path)
			else:
				ActionGenerator.generate_music_action(FileLoader.MUSIC_DEFAULT_AMBIENT_AUDIO_PATH)
		LocationData.LOCATION_TYPES.SHOP:
			ActionGenerator.generate_music_action(FileLoader.MUSIC_SHOP_AUDIO_PATH)
		LocationData.LOCATION_TYPES.COMBAT:
			if act_data.act_music_combat_file_path != "":
				ActionGenerator.generate_music_action(act_data.act_music_combat_file_path)
			else:
				ActionGenerator.generate_music_action(FileLoader.MUSIC_DEFAULT_COMBAT_AUDIO_PATH)
		LocationData.LOCATION_TYPES.MINIBOSS:
			if act_data.act_music_miniboss_file_path != "":
				ActionGenerator.generate_music_action(act_data.act_music_miniboss_file_path)
			else:
				ActionGenerator.generate_music_action(FileLoader.MUSIC_DEFAULT_MINIBOSS_AUDIO_PATH)
		LocationData.LOCATION_TYPES.BOSS:
			if act_data.act_music_boss_file_path != "":
				ActionGenerator.generate_music_action(act_data.act_music_boss_file_path)
			else:
				ActionGenerator.generate_music_action(FileLoader.MUSIC_DEFAULT_BOSS_AUDIO_PATH)
