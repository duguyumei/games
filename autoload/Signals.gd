# Singleton defining global signals
extends Node

var _id_to_custom_signal: Dictionary[String, CustomSignal] = {}

#region Custom Signals

## Gets a CustomSignal, generating it if it does not exist
func get_custom_signal(custom_signal_object_id: String) -> CustomSignal:
	assert(custom_signal_object_id != "")
	if _id_to_custom_signal.has(custom_signal_object_id):
		return _id_to_custom_signal[custom_signal_object_id]
	else:
		var custom_signal: CustomSignal = CustomSignal.new(custom_signal_object_id)
		_id_to_custom_signal[custom_signal_object_id] = custom_signal
		return custom_signal

func emit_custom_signal(custom_signal_object_id: String, values: Dictionary[String, Variant]) -> void:
	var custom_signal: CustomSignal = get_custom_signal(custom_signal_object_id)
	custom_signal.custom_signal.emit(custom_signal_object_id, values)

## Automatically registers all custom signals
## This should be done after Global and FileLoader have finished loading/generating data objects
func register_all_custom_signals() -> void:
	for custom_signal_object_id in Global._id_to_custom_signal_data.keys():
		var _custom_signal: CustomSignal = get_custom_signal(custom_signal_object_id)
		

#endregion

#region Hand related
# cards
## player has finished playing a card and all its actions, emitted by special CardPlayEnded action as the last action of a card play payload
signal card_played(card_play_request: CardPlayRequest)
## player is about to play a card, before actions have been applied. Used mainly for UI purposes like in Card, but you can listen to it
## and perform actions
signal card_play_started(card_play_request: CardPlayRequest)	
signal card_drawn(card: CardData)
signal card_deck_shuffled(is_reshuffle: bool)
signal card_discarded(card: CardData, is_manual_discard: bool)
signal card_exhausted(card: CardData)
signal card_banished(card: CardData, in_limbo: bool) # card removed from play. in_limbo used for cards that aren't really banished, merely removed from play to be re-added by another action
signal card_added_to_draw(card_data: CardData)
signal card_added_to_hand(card_data: CardData)
signal card_retained(card: CardData)
signal card_upgraded(card: CardData) # whenever a card is successfully upgraded
signal card_created(card: CardData) # whenever a card is created either from nothing or duplication
signal card_properties_changed(card: CardData)	# general signal for when a card's card_values or other properties have been altered, usually requiring a rerender of Card object
signal card_turn_energy_changed(card: CardData)	# special signal for when a card's per turn energy property has been changed, which requires tracking
signal card_transformed(card: CardData)	# general signal for when a card is transformed. See also: card_transformed_in_deck
signal card_decorators_changed(card: CardData)	# when the decorators in a card have been modified
signal card_hand_limit_reached	# hand is full
signal card_queue_refunded

# card picking
signal card_pick_requested(card_pick_action: ActionBasePickCards)	# an action has requested cards from the player. Action's card_pick_type affects the ui used for selection
signal card_pick_confirmed	# the card pick is finished
## 一个真气选择动作请求打开独立选择界面。
signal qi_pick_requested(qi_pick_action: ActionBasePickQi)
## 真气选择界面已经确认或取消当前选择。
signal qi_pick_confirmed

signal card_added_to_deck(card_data: CardData) # card was added to player's permanent deck
signal card_removed_from_deck(card_data: CardData) # card was removed from player's permanent deck
signal card_transformed_in_deck(card_data: CardData) # card was transformed player's permanent deck (card_data will be in updated state)
signal card_draft_skipped(card_pick_action)
signal card_purchased(card_data: CardData)
#endregion

signal game_paused
signal game_unpaused

#region Run
signal run_started # player has started or continued a run
signal run_ended # player has ended a run (does not necessarily mean victory/defeat)
signal run_victory # player has won a run
signal player_killed(player: Player)
signal player_death_animation_finished(player: Player)

# rewards
signal reward_grant_requested(reward_group: int, money_amount: int, card_drafts: Array[Array], artifact_ids: Array[String], custom_action_data: Array[Array])
signal reward_clear_requested(reward_group: int) # -1 for clear all rewards

# player stats
signal player_money_changed(money_delta: int)
signal player_health_changed
signal player_artifacts_changed # used for updating the ui
signal player_artifact_added(artifact_data: ArtifactData)
signal player_artifact_removed(artifact_data: ArtifactData)
## 本局真气牌组发生变化。
signal player_qi_changed
## 本局或战斗中的真气重塑状态发生变化。
signal qi_reshape_changed(qi_instance_uid: String, scope: String)
## 本局或战斗中的真气异状状态发生变化。
signal qi_anomaly_changed(qi_instance_uid: String, scope: String)
## 本局拥有的功法或其获得次数发生变化。
signal player_gongfa_changed
## 八种牌型的功法配装发生变化。
signal player_gongfa_loadout_changed
## 本局拥有的内功发生变化。
signal player_neigong_changed
## 内功装备顺序发生变化。
signal player_neigong_loadout_changed
signal combat_stat_changed(stat_enum: int)	# can be used to hook into certain stats
#endregion

#region Overworld
signal map_location_selected(location_data: LocationData)	# the player clicked on a location that can be traveled to
## 读档恢复到节点已结算的地图待选阶段，不重新进入当前节点。
signal map_waiting_restored
signal chest_opened	# player has opened a chest
signal shop_opened	# player has opened a shop
## 地图待选阶段打开功法与内功搭配界面。
signal loadout_opened
signal shop_visited_first_time # player has visited a shop for the first time
## 商店候选、价格或空槽发生变化，界面应只重绘而不重新生成。
signal shop_inventory_changed
## 一次购买或冥想已经提交，等待行为队列结束后可以保存本局。
signal shop_transaction_committed
## 当前节点及其奖励已经全部完成；相同 completion_token 只能刷新一次商店。
signal node_completed(location_data: LocationData, completion_token: String)
signal dialogue_started
signal dialogue_ended
signal rest_action_ended(rest_action_id: String) # a rest action has finished
#endregion

#region Combat
# turns
signal combat_started(event_id: String) # invokes combat when emitted. If empty string for event_id, will use the location's combat event
signal combat_ended
## 敌我任一真气牌区已经提交变化，战斗界面应重新读取当前牌区。
signal qi_zones_changed

## 一张真气完成了牌区运转。
##
## 这是所有牌区移动的统一事件 —— 抽取、调度、弃置、洗回都发这一个信号，
## 监听方通过 from_zone 与 to_zone 的组合判断具体方向。例如「每当凝气运转为行气」：
##     if from_zone == QiEnums.ZONES.DRAW and to_zone == QiEnums.ZONES.HAND
##
## is_auto 区分自动运转（流程驱动：抽取、回合末收尾、洗回）与主动运转（功法驱动），
## 因为部分内容只统计主动运转。
signal qi_circulated(qi: QiData, from_zone: int, to_zone: int, is_auto: bool, source_uid: String)

## 一张真气从牌库中被移除；耗散与消耗型功法触发。
## 被移除的真气仍记录在战斗容器中，供「每消耗 N 张真气」这类效果读取。
signal qi_removed_from_deck(qi: QiData, from_zone: int, is_auto: bool, source_uid: String)

## 一张真气发生了毒发。
signal qi_poison_burst(qi: QiData, poison_amount: int, source_uid: String)
## 玩家确认双方待结算区后发出的冻结行动请求。
signal qi_action_ready(request: QiActionRequest)
## 结算器完成冻结行动并将真气移入后续牌区。
signal qi_action_completed(request: QiActionRequest)
signal player_turn_started
signal player_turn_ended
signal enemy_turn_started
signal enemy_turn_ended
signal end_turn_requested(end_turn_immediacy_level: int)	# requests to end the turn. See CombatEndTurn

# custom ui
signal custom_ui_requested

# block
signal combatant_block_added(base_combatant: BaseCombatant)
signal combatant_block_broken(base_combatant: BaseCombatant)	# 目标护盾被本次可吸收伤害完全耗尽
signal combatant_blocked(base_combatant: BaseCombatant, damage_blocked: int)	# combatant fully blocked an attack
signal combatant_damaged(base_combatant: BaseCombatant, unblocked_damage: int, zero_capped_damage: int, overkill_damage: int)	# a combatant has taken health damage. Cannot be 0
## 战斗护盾、格挡、化解、反震或穿透来源发生变化。
signal battle_defense_changed(side: String, defense_kind: String)
## 一次统一伤害结算完成；结果包含伤害类型、来源和护盾吸收量。
signal combat_damage_resolved(target: BaseCombatant, result: CombatDamageResult)
## 护盾吸收直接伤害后立即触发的反震事件。
signal combat_reflect_triggered(source: BaseCombatant, target: BaseCombatant, amount: int)

signal energy_changed	# when the player gains energy not at start of turn

# enemies
signal enemy_intent_changed
signal enemy_killed(enemy: Enemy)
signal enemy_death_animation_finished(enemy: Enemy)
signal enemy_clicked(enemy: Enemy)
signal enemy_hovered(enemy: Enemy)
signal enemy_spawn_requested(enemy_object_id: String, slot_id: int)	# requests spawning an enemy in a slot

# artifacts
signal artifact_proc(artifact_data: ArtifactData)	# an artifact's effect has been triggered
signal artifact_counter_changed(artifact_data: ArtifactData)
signal artifact_purchased(artifact_data: ArtifactData)
## 玩家从商店购买了一张真气定义。
signal qi_purchased(qi_object_id: String)
## 玩家从商店购买了一门功法定义。
signal gongfa_purchased(gongfa_object_id: String)
## 玩家从商店购买了一门内功定义。
signal neigong_purchased(neigong_object_id: String)

# consumables
signal consumable_discarded(consumable_index: int, consumable_object_id: String)	# player got rid of a consumable
signal consumable_used(consumable_index: int, consumable_object_id: String)
signal consumable_added(consumable_index: int, consumable_object_id: String)
signal consumable_purchased(consumable_object_id: String)

signal add_consumable_requested(consumable_object_id: String)
#endregion
