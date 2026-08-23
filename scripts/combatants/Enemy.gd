extends BaseCombatant
class_name Enemy

@onready var enemy_intent: HBoxContainer = $Visible/Intent

# icons used for displaying specific intent types
@onready var attacking_intent: TextureRect = $Visible/Intent/AttackingIntent
@onready var blocking_intent: TextureRect = $Visible/Intent/BlockingIntent
@onready var debuffing_intent: TextureRect = $Visible/Intent/DebuffingIntent
@onready var buffing_intent: TextureRect = $Visible/Intent/BuffingIntent
@onready var summoning_intent: TextureRect = $Visible/Intent/SummoningIntent

# maps the EnemyIntentData.enemy_intent_display_type to the texture to display
@onready var INTENT_DISPLAY_TYPE_TO_INTENT: Dictionary[int, TextureRect] = {
	EnemyIntentData.INTENT_DISPLAY_TYPES.ATTACKING: attacking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BLOCKING: blocking_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.DEBUFFING: debuffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.BUFFING: buffing_intent,
	EnemyIntentData.INTENT_DISPLAY_TYPES.SUMMONING: summoning_intent,
}

@onready var enemy_intent_amount_label: Label = $Visible/Intent/IntentAmount

@onready var name_label = %NameLabel
@onready var death_animation_player: AnimationPlayer = $DeathAnimationPlayer

var enemy_data: EnemyData = null
var enemy_slot: int = 0 # the spawn slot the enemy is in

var enemy_intent_attack_damage: int = 0
var enemy_intent_number_of_attacks: int = 0

func init(_enemy_data: EnemyData):
	enemy_data = _enemy_data
	
	selection_button.mouse_entered.connect(_on_mouse_entered)
	selection_button.mouse_exited.connect(_on_mouse_exited)
	
	animated_sprite_2d.sprite_frames = get_animation_sprite_frames()
	animated_sprite_2d.play(AnimationData.ANIMATION_IDLE)
	
	# apply initial effects
	for status_effect_object_id in enemy_data.enemy_initial_status_effects.keys():
		var charge_amount: int = enemy_data.enemy_initial_status_effects[status_effect_object_id]
		add_status_effect_charges(status_effect_object_id, charge_amount)
	
	name_label.text = enemy_data.enemy_name
	
	# update_health_bar()
	layered_health_bar.init(enemy_data.enemy_health, enemy_data.enemy_health_max)
	
func get_animation_data() -> AnimationData:
	var animation_data: AnimationData = Global.get_animation_data(enemy_data.enemy_animation_id)
	return animation_data

## 通过统一伤害结算器处理敌方受到的真气战斗伤害。
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
	if amount <= 0 or enemy_data.enemy_health <= 0:
		return [0, 0, 0]
	var overkill_damage: int = max(0, amount - enemy_data.enemy_health)
	var capped_damage: int = amount - overkill_damage
	create_damage_text(amount)
	enemy_data.enemy_health = max(0, enemy_data.enemy_health - amount)
	Signals.combatant_damaged.emit(self, amount, capped_damage, overkill_damage)
	update_health_bar(true)
	if enemy_data.enemy_health <= 0 and not _is_qi_death_deferred():
		finalize_deferred_qi_death()
	return [amount, capped_damage, overkill_damage]

## 原子组结束后统一播放敌方死亡并发送一次死亡信号。
func finalize_deferred_qi_death() -> void:
	if enemy_data.enemy_health > 0 or death_animation_player.is_playing() \
		or not is_in_group("enemies"):
		return
	ActionGenerator.generate_combatant_death(self)
	animated_sprite_2d.play(AnimationData.ANIMATION_DEATH)
	death_animation_player.play("Enemy/death")
	remove_from_group("enemies")
	Signals.enemy_killed.emit(self)

## 返回当前真气原子组是否延迟死亡表现。
func _is_qi_death_deferred() -> bool:
	return Global.battle_qi_state != null \
		and Global.battle_qi_state.is_death_resolution_deferred()

func set_block(amount: int) -> void:
	if Global.battle_qi_state == null:
		return
	Global.battle_qi_state.clear_defense_kind(
		BattleQiState.SIDE_ENEMY, BattleDefenseEntry.KIND_SHIELD)
	if amount > 0:
		Global.battle_qi_state.add_shield(
			BattleQiState.SIDE_ENEMY, amount, "action", enemy_data.object_uid)
	update_shield_display()

func get_block() -> int:
	return get_shield()

func add_block(amount: int) -> void:
	add_shield(amount)

## 返回敌方当前护盾。
func get_shield() -> int:
	return Global.battle_qi_state.get_shield(BattleQiState.SIDE_ENEMY) \
		if Global.battle_qi_state != null else 0

## 添加敌方护盾来源。
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
		BattleQiState.SIDE_ENEMY,
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

## 更新护盾显示。
func update_shield_display() -> void:
	var shield_value: int = get_shield()
	block.visible = shield_value > 0
	block_amount.text = str(shield_value)

#region Health
func heal_percentage(percent: float):
	var percentage_health: int = int(ceil(float(enemy_data.enemy_health_max) * percent))
	add_health(percentage_health, 0)

func add_health(health_amount: int, health_amount_max: int = 0) -> void:
	set_health(enemy_data.enemy_health + health_amount, enemy_data.enemy_health_max + health_amount_max)

func set_health(health_amount: int, health_amount_max: int = enemy_data.enemy_health_max) -> void:
	var is_damaged: bool = health_amount < enemy_data.enemy_health
	
	enemy_data.enemy_health_max = max(1, enemy_data.enemy_health_max)
	enemy_data.enemy_health = clamp(0, health_amount, enemy_data.enemy_health_max)
	
	update_health_bar(is_damaged)

func update_health_bar(as_damage: bool = false) -> void:
	if as_damage:
		layered_health_bar.apply_damage(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)
	else:
		layered_health_bar.update_health_layers(enemy_data.enemy_health, enemy_data.enemy_health_max, status_id_to_status_effects)

func get_combatant_health() -> int:
	return enemy_data.enemy_health

func get_combatant_health_max() -> int:
	return enemy_data.enemy_health_max

#endregion

## Changes the enemy's intent to the next intent in the random walk.
func cycle_enemy_intent():
	enemy_data.cycle_next_intent_state()
	update_enemy_intent()
	Signals.enemy_intent_changed.emit()

## Displays the enemy's intentions above them based on their current intent.
func update_enemy_intent():
	# get current intent's attack
	var current_enemy_intent: EnemyIntentData = enemy_data.get_current_intent()
	var attack_damage: int = 0
	var number_of_attacks: int = 0
	if current_enemy_intent == null:
		breakpoint
	else:
		attack_damage = current_enemy_intent.enemy_intent_attack_damage
		number_of_attacks = current_enemy_intent.enemy_intent_number_of_attacks
	
	# reset intent icon visibility
	for intent_icon: TextureRect in INTENT_DISPLAY_TYPE_TO_INTENT.values():
		intent_icon.hide()
	
	# show intent icons based on intent
	for display_intent_type: int in current_enemy_intent.enemy_intent_display_types:
		var intent_icon: TextureRect = INTENT_DISPLAY_TYPE_TO_INTENT.get(display_intent_type, null)
		if intent_icon == null:
			breakpoint
			DebugLogger.log_error("Enemey: No intent icon mapped to EnemyIntentData.INTENT_DISPLAY_TYPES of value {0}".format([display_intent_type]))
			continue
		else:
			intent_icon.show()
	
	var player: Player = Global.get_player()
	
	### damage
	# intercept an attack action in preview mode
	var action_data: Array[Dictionary] = [{
			Scripts.ACTION_ATTACK: 
				{
				"damage": attack_damage,
				"damage_type": CombatDamageRequest.DAMAGE_NORMAL,
				"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
				}}]
	var generated_action: BaseAction = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	var action_interceptor_processors: Array[ActionInterceptorProcessor] = generated_action._intercept_action([player], true)
	
	if len(action_interceptor_processors) == 1:
		var action_interceptor_processor: ActionInterceptorProcessor = action_interceptor_processors[0]
		# get intercepted attack values
		enemy_intent_attack_damage = max(0, action_interceptor_processor.get_shadowed_action_values("damage", 0))

	
	### number of attacks
	# intercept an attack action generator in preview mode
	action_data = [{
		Scripts.ACTION_ATTACK_GENERATOR: 
			{
				"damage": attack_damage,
				"damage_type": CombatDamageRequest.DAMAGE_NORMAL,
				"number_of_attacks": number_of_attacks,
			"target_override": BaseAction.TARGET_OVERRIDES.PLAYER
			}}]
	generated_action = ActionGenerator.create_actions(self, null, [player], action_data, null)[0]
	action_interceptor_processors = generated_action._intercept_action([player], true)
	
	if len(action_interceptor_processors) == 1:
		var action_interceptor_processor: ActionInterceptorProcessor = action_interceptor_processors[0]
		# get intercepted attack values
		enemy_intent_number_of_attacks = max(0, action_interceptor_processor.get_shadowed_action_values("number_of_attacks", 0))
	
	### Display intent
	enemy_intent_amount_label.visible = false
	if enemy_intent_attack_damage * enemy_intent_number_of_attacks > 0:
		enemy_intent_amount_label.visible = true
		enemy_intent_amount_label.text = str(enemy_intent_attack_damage)
		if enemy_intent_number_of_attacks > 1:
			enemy_intent_amount_label.text += " x " + str(enemy_intent_number_of_attacks)

func is_alive() -> bool:
	return enemy_data.enemy_health > 0

func is_attacking() -> bool:
	return enemy_intent_number_of_attacks > 0

func _on_combat_started(_event_id: String):
	pass

func _on_combat_ended():
	queue_free()

func _on_player_turn_started():
	# 真气战斗的敌方行动由待结算区统一表示，不再轮换旧意图。
	if Global.battle_qi_state != null \
		and Global.battle_qi_state.get_active_enemy_instance_id() != "":
		enemy_intent.hide()
		return
	cycle_enemy_intent()

## 进入真气战斗后隐藏旧的伤害、格挡和减益意图图标。
func enable_qi_battle_display() -> void:
	enemy_intent.hide()

func _on_selection_button_up():
	if is_alive():
		Signals.enemy_clicked.emit(self)

func _on_mouse_entered():
	Signals.enemy_hovered.emit(self)
	name_label.visible = true

func _on_mouse_exited():
	Signals.enemy_hovered.emit(null)
	name_label.visible = false

func _on_death_animtation_finished():
	# called from animation player
	Signals.enemy_death_animation_finished.emit(self)
