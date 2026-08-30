# Player UI element
extends BaseCombatant
class_name Player

@onready var incoming_damage: Control = $Visible/IncomingDamage
@onready var incoming_damage_amount_text: Label = $Visible/IncomingDamage/IncomingDamageAmount

const INTENT_UPDATES_LAZILY: bool = true	# batches intent updates
var _intent_is_updating: bool = false

func _ready():
	super()
	Signals.enemy_intent_changed.connect(_on_enemy_intent_changed)
	Signals.enemy_death_animation_finished.connect(_on_enemy_death_animation_finished)
	Signals.player_health_changed.connect(_on_player_health_changed)
	Signals.artifact_proc.connect(_on_artifact_proc)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	
	Signals.player_artifact_added.connect(_on_artifact_added)
	Signals.player_artifact_removed.connect(_on_artifact_removed)
	Signals.player_neigong_loadout_changed.connect(_on_neigong_loadout_changed)

func reset_player() -> void:
	var character_data: CharacterData = Global.get_player_character_data()
	animated_sprite_2d.sprite_frames = get_animation_sprite_frames()
	animated_sprite_2d.play(AnimationData.ANIMATION_IDLE)
	
	reset_block()
	clear_all_status_effects()
	unregister_all_custom_ui()
	
	# reinitialize healthbar
	var player_data: PlayerData = Global.player_data
	layered_health_bar.init(player_data.player_health, player_data.player_health_max)
	update_health_bar(false)
	
	update_incoming_damage_amount(true)
	# run modifiers
	register_run_modifier_interceptors()
	# artifact interceptors
	register_artifact_interceptors()
	# 只有当前已装备的内功注册拦截器。
	register_neigong_interceptors()
	
	# reset animation and state
	var location_data: LocationData = Global.get_player_location_data()
	if location_data.location_type == LocationData.LOCATION_TYPES.STARTING:
		animation_player.play("Player/run_start")

func get_animation_data() -> AnimationData:
	var character_data: CharacterData = Global.get_player_character_data()
	var animation_data: AnimationData = Global.get_animation_data(character_data.character_animation_id)
	return animation_data

## 通过统一伤害结算器处理玩家受到的真气战斗伤害。
func damage(
		_damage: int,
		damage_type: String,
		source_side: String = "",
		source_instance_id: String = "",
		source_effect_id: String = "",
		source_kind: String = "") -> Array[int]:
	var request: CombatDamageRequest = CombatDamageRequest.new()
	request.amount = _damage
	request.damage_type = damage_type
	request.source_side = source_side
	request.source_instance_id = source_instance_id
	request.source_effect_id = source_effect_id
	request.source_kind = source_kind
	var result: CombatDamageResult = CombatDamageResolver.resolve(
		self, request, Global.battle_qi_state)
	return [result.health_damage, result.health_damage, result.overkill_damage]

## 直接应用已经完成格挡、化解和护盾结算的生命伤害。
func apply_health_damage(amount: int) -> Array[int]:
	var player_data: PlayerData = Global.player_data
	if amount <= 0 or player_data.player_health <= 0:
		return [0, 0, 0]
	var overkill_damage: int = max(0, amount - player_data.player_health)
	var capped_damage: int = amount - overkill_damage
	create_damage_text(amount)
	player_data.add_health(-amount)
	Signals.combatant_damaged.emit(self, amount, capped_damage, overkill_damage)
	return [amount, capped_damage, overkill_damage]

func set_block(amount: int) -> void:
	if Global.battle_qi_state == null:
		return
	Global.battle_qi_state.clear_defense_kind(
		BattleQiState.SIDE_PLAYER, BattleDefenseEntry.KIND_SHIELD)
	if amount > 0:
		Global.battle_qi_state.add_shield(
			BattleQiState.SIDE_PLAYER, amount, "action", "set_shield")
	update_shield_display()

func get_block() -> int:
	return get_shield()

func add_block(amount: int) -> void:
	add_shield(amount)

## 返回玩家当前护盾。
func get_shield() -> int:
	return Global.battle_qi_state.get_shield(BattleQiState.SIDE_PLAYER) \
		if Global.battle_qi_state != null else 0

## 添加玩家护盾来源。
func add_shield(
		amount: int,
		source_kind: String = "action",
		source_instance_id: String = "",
		duration_scope: String = "battle",
		remaining_rounds: int = -1,
		remaining_hits: int = -1,
		decay_policy: String = "halve") -> void:
	if Global.battle_qi_state == null or amount <= 0:
		return
	var entry_uid: String = Global.battle_qi_state.add_shield(
		BattleQiState.SIDE_PLAYER,
		amount,
		source_kind,
		source_instance_id,
		duration_scope,
		remaining_rounds,
		remaining_hits,
		decay_policy)
	if entry_uid == "":
		return
	create_block_fade()
	Signals.combatant_block_added.emit(self)
	update_shield_display()

## 更新护盾显示；场景节点名称保留但数值来自 BattleQiState。
func update_shield_display() -> void:
	var shield_value: int = get_shield()
	block.visible = shield_value > 0
	block_amount.text = str(shield_value)

#region Health
## Adds health and max health to the combatant
func add_health(health_amount: int, health_amount_max: int) -> void:
	Global.player_data.add_health(health_amount, health_amount_max)

## Heals the combatant by a given percentage between 0.0 and 1.0.
func heal_percentage(health_percent: float):
	Global.player_data.heal_percentage(health_percent)

func set_health(health_amount: int, health_amount_max: int = Global.player_data.player_health_max) -> void:
	Global.player_data.set_health(health_amount, health_amount_max)

func update_health_bar(as_damage: bool = false) -> void:
	var player_data: PlayerData = Global.player_data
	if as_damage:
		layered_health_bar.apply_damage(player_data.player_health, player_data.player_health_max, status_id_to_status_effects)
	else:
		layered_health_bar.update_health_layers(player_data.player_health, player_data.player_health_max, status_id_to_status_effects)

func get_combatant_health() -> int:
	return Global.player_data.player_health

func get_combatant_health_max() -> int:
	return Global.player_data.player_health_max

func update_player_display(_player_data: PlayerData):
	update_health_bar(false)

#endregion

func update_incoming_damage_amount(recalculate_enemy_intent: bool = true) -> void:
	# updates the damage preview above the player's head
	# flag to force recalculation of all enemy intents as well
	
	# optional lazy updating
	if _intent_is_updating:
		return
	if INTENT_UPDATES_LAZILY:
		_intent_is_updating = true
		await get_tree().process_frame
		_intent_is_updating = false
	
	var incoming_damage_amount = 0 # totaled value
	for en in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = en # typecast
		
		if recalculate_enemy_intent:
			enemy.update_enemy_intent()
		
		incoming_damage_amount += enemy.enemy_intent_attack_damage * enemy.enemy_intent_number_of_attacks

	incoming_damage_amount_text.text = str(incoming_damage_amount)
	incoming_damage.visible = incoming_damage_amount > 0

func is_alive() -> bool:
	return Global.player_data.player_health > 0

func create_artifact_fade(artifact_id: String) -> void:
	var artifact_fade: ArtifactFade = Scenes.ARTIFACT_FADE.instantiate()
	fade_container.add_child(artifact_fade)
	artifact_fade.init(artifact_id)

#region Run Modifiers and Interceptors

func register_run_modifier_interceptors() -> void:
	# attaches intercepotors from modifiers to the player
	for run_modifier_object_id in Global.player_data.player_run_modifier_object_ids:
		var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if run_modifier_data == null:
			DebugLogger.log_error("Player.register_run_modifier_interceptors(): No RunData with id of \"{0}".format([run_modifier_object_id]))
		else:
			for interceptor_id: String in run_modifier_data.run_modifier_interceptor_ids:
				ActionHandler.register_action_interceptor(self, interceptor_id)

## Attaches interceptors from artifacts the player has
func register_artifact_interceptors() -> void:
	# 重新建立奇物来源注册，避免读档或重置后保留旧实例引用。
	ActionHandler.unregister_action_interceptors_by_source_kind(self, "artifact")
	var artifact_order: int = 0
	for artifact_uid: String in Global.player_data.player_artifact_uid_to_artifact_data:
		var artifact_data: ArtifactData = Global.player_data.player_artifact_uid_to_artifact_data[artifact_uid]
		for interceptor_id: String in artifact_data.artifact_interceptor_ids:
			ActionHandler.register_action_interceptor(
				self, interceptor_id, "artifact", artifact_data.object_uid, artifact_order)
		artifact_order += 1

## 只按当前内功装备顺序注册来源实例拦截器。
func register_neigong_interceptors() -> void:
	ActionHandler.unregister_action_interceptors_by_source_kind(self, "neigong")
	ActionHandler.qi_interceptors.unregister_by_source_kind(self, "neigong")
	for source_order: int in Global.player_data.player_equipped_neigong_uids.size():
		var neigong_instance_uid: String = Global.player_data.player_equipped_neigong_uids[
			source_order]
		var neigong_data: NeigongData = Global.player_data.get_owned_neigong(
			neigong_instance_uid)
		if neigong_data == null:
			continue
		for interceptor_id: String in neigong_data.neigong_interceptor_ids:
			# 同一份 ID 列表送进两套体系；各自查不到配置就跳过，因此并存不冲突。
			ActionHandler.register_action_interceptor(
				self, interceptor_id, "neigong", neigong_instance_uid, source_order)
			ActionHandler.qi_interceptors.register(
				self, interceptor_id, "neigong", neigong_instance_uid, source_order)

func _on_artifact_added(artifact_data: ArtifactData) -> void:
	for action_interceptor_id: String in artifact_data.artifact_interceptor_ids:
		ActionHandler.register_action_interceptor(
			self,
			action_interceptor_id,
			"artifact",
			artifact_data.object_uid,
			Global.player_data.player_artifact_uid_to_artifact_data.size() - 1)

func _on_artifact_removed(artifact_data: ArtifactData) -> void:
	ActionHandler.unregister_action_interceptors_from_source(self, artifact_data.object_uid)

## 内功配装发生变化后整体重建来源注册，保证装备顺序稳定。
func _on_neigong_loadout_changed() -> void:
	register_neigong_interceptors()

#endregion


func _on_run_started():
	reset_player()

func _on_run_ended():
	reset_block()
	if Global.battle_qi_state == null:
		block.visible = false
		block_amount.text = "0"
	clear_all_status_effects()
	unregister_all_custom_ui()

func _on_combat_started(_event_id: String):
	clear_all_status_effects()
	update_shield_display()
	
func _on_combat_ended():
	clear_all_status_effects()
	reset_block()
	if Global.battle_qi_state == null:
		block.visible = false
		block_amount.text = "0"
	update_incoming_damage_amount()

func _on_enemy_intent_changed():
	update_incoming_damage_amount(true)

func _on_enemy_death_animation_finished(_enemy: Enemy):
	update_incoming_damage_amount()

func _on_player_health_changed():
	if Global.player_data.player_health <= 0:
		# generate an interceptable action and intercept it to possibly change health
		ActionGenerator.generate_combatant_death(self)
	if Global.player_data.player_health <= 0:
		play_death_animation()
	update_health_bar(true)

func _on_artifact_proc(artifact_data: ArtifactData):
	create_artifact_fade(artifact_data.object_id)


func _on_death_animtation_finished():
	# called from animation player
	Signals.player_death_animation_finished.emit(self)

func play_attack_animation() -> void:
	animation_player.play("Player/attack")

func play_death_animation() -> void:
	if Global.battle_qi_state != null \
		and Global.battle_qi_state.is_death_resolution_deferred():
		return
	if not animation_player.is_playing():
		animated_sprite_2d.play(AnimationData.ANIMATION_DEATH)
		animation_player.play("Player/death")
		Signals.player_killed.emit(self)

## 原子组结束后统一提交玩家死亡；存活时不产生任何效果。
func finalize_deferred_qi_death() -> void:
	if Global.player_data.player_health <= 0:
		play_death_animation()
