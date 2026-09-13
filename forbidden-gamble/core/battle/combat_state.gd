class_name CombatState
extends RefCounted

var player: FighterState
var enemy: FighterState
var battle_seed: int = 12345
var active_side: String = "player"
# 战斗度量（D-063 行动权模型，§11.7 战报口径）：原子行动总数与玩家调息次数
# （后者＝世界钟代理——D-058 落地后的喘气计数）。
var action_count: int = 0
var player_breath_count: int = 0
# 动作管线：伤害/上状态/抽牌/调息等结算都经它流转，状态效果（毒）、心法都挂成它的钩子。
var pipeline: EffectPipeline
var status_runtime: StatusRuntime
# 心法运行时（D-060）：装配玩家装备心法的词条钩子（敌方系统 v2 后敌方无系统可改，不装）。
var xinfa_runtime: XinfaRuntime
# 敌方脑（敌方系统 v2）：行为链梯＋钩子管道；TurnManager 驱动。
var enemy_brain: EnemyBrain

func _init(new_player: FighterState, new_enemy: FighterState) -> void:
	player = new_player
	enemy = new_enemy
	pipeline = EffectPipeline.new()
	# 纯机体结算共用一份表（hp_loss/heal/guard 三件——与临时管线同源不漂移）
	ResolverTable.register(pipeline)
	# 带状态/计数/钩子通知的结算由本类注册（damage 破盾、status_apply 词表、气循环、夺取）
	pipeline.register_resolver("damage", _resolve_damage)
	pipeline.register_resolver("status_apply", _resolve_status_apply)
	pipeline.register_resolver("draw", _resolve_draw)
	pipeline.register_resolver("breath", _resolve_breathe)
	pipeline.register_resolver("initiative_seize", _resolve_initiative_seize)
	# 抽象点位（纯时点，无默认结算；guard_broken＝破盾事件——脑的乱钩订阅此点）
	pipeline.register_point("battle_start")
	pipeline.register_point("technique_use")
	pipeline.register_point("technique_prepare")
	pipeline.register_point("initiative_gain")
	pipeline.register_point("guard_broken")
	status_runtime = StatusRuntime.new(pipeline)
	xinfa_runtime = XinfaRuntime.new(pipeline)
	xinfa_runtime.wire_sides(player, enemy)
	xinfa_runtime.setup(player)
	enemy_brain = EnemyBrain.new(new_enemy.enemy_def)
	# 脑的钩子挂上事件总线（与心法/状态同款 carrier；本类不再直呼脑）
	enemy_brain.wire(pipeline, enemy, player)

func opponent_for(side: String) -> FighterState:
	return enemy if side == "player" else player

func unit_for(side: String) -> FighterState:
	return player if side == "player" else enemy

# ---------- 管线默认结算（RESOLVE 层） ----------

func _resolve_damage(action: GameAction) -> void:
	var unit: FighterState = action.target
	var guard_before := unit.guard
	action.context["damage_result"] = unit.take_damage(maxi(action.amount, 0))
	# 破盾事件（敌方系统 v2 修订）：护境＞0 被伤害打到归零——段破段触发（每段独立结算），
	# 只认伤害不认拆除。破盾＝纯物理（漏血），不给破绽、不断蓄力；
	# 乱钩在事件瞬间被唤醒（EnemyBrain 订阅，翻牌即演出）。
	if guard_before > 0 and unit.guard == 0:
		_on_guard_shattered(unit)

# 破盾＝纯物理：只发事件文案＋提交 guard_broken 点位（乱钩经事件总线被唤醒，翻牌即演出）。
func _on_guard_shattered(unit: FighterState) -> void:
	pipeline.events.append("%s护境被击碎！" % unit.display_name)
	var point := GameAction.new("guard_broken", unit, 0, null)
	pipeline.submit(point)

func _resolve_status_apply(action: GameAction) -> void:
	var unit: FighterState = action.target
	var status_id := str(action.context.get("status", ""))
	unit.add_status(status_id, action.amount)
	status_runtime.ensure_hooks(unit, status_id)
	pipeline.events.append("%s 身中 %s ×%d。" % [unit.display_name, StatusRuntime.status_name(status_id), unit.get_status(status_id)])

func _resolve_draw(action: GameAction) -> void:
	_draw_into(action.target, action.amount, action.context.get("rng"))

# 调息（B2，v1.4 §4）：弃 context.discard_indices 所指手牌入气海（键缺省＝弃全部，
# 兼容旧调用方；空数组＝只补不弃），再从丹田纳至 action.amount 口（手牌不足上限才补）。
# PRE 钩子可改 amount（心法调息词条挂点）；keep_hand 跳过弃牌（气海无涯类词条的旧通道，
# B2 下待重设计）。弃/纳数写回 context 供战报披露。
func _resolve_breathe(action: GameAction) -> void:
	var unit: FighterState = action.target
	if bool(action.context.get("keep_hand", false)):
		action.context["discarded_count"] = 0
	else:
		var discarded_cards: Array = []
		if action.context.has("discard_indices"):
			var indices: Array = action.context["discard_indices"]
			indices.sort()
			indices.reverse()  # 从大索引往小删，避免位移
			for raw in indices:
				var index := int(raw)
				if index >= 0 and index < unit.hand.size():
					discarded_cards.append(unit.hand[index])
					unit.hand.remove_at(index)
		else:
			discarded_cards = unit.hand.duplicate()
			unit.hand.clear()
		unit.discard_pile.append_array(discarded_cards)
		action.context["discarded_count"] = discarded_cards.size()
	if unit == player:
		player_breath_count += 1
		# 应钩经事件总线被唤醒：breath 动作 post 时点上脑自己过滤"你的调息"
	var before := unit.hand.size()
	# 常规＝纳至上限（补差额）；keep_hand（气海无涯旧行为改写）＝净提 amount 张
	var draw_amount := maxi(action.amount - unit.hand.size(), 0)
	if bool(action.context.get("keep_hand", false)):
		draw_amount = maxi(action.amount, 0)
	_draw_into(unit, draw_amount, action.context.get("rng"))
	action.context["drawn_count"] = unit.hand.size() - before

# 从丹田抽气入手的共享实现：丹田抽尽洗气海再续（既有循环不变）。
func _draw_into(unit: FighterState, amount: int, randomizer: RandomNumberGenerator) -> void:
	for _index in range(maxi(amount, 0)):
		if unit.draw_pile.is_empty() and not unit.discard_pile.is_empty():
			unit.draw_pile = unit.discard_pile.duplicate()
			unit.discard_pile.clear()
			_randomize_cards(unit.draw_pile, randomizer)
		if unit.draw_pile.is_empty():
			return
		unit.hand.append(unit.draw_pile.pop_back())

# ---------- 行动权（敌方系统 v1 §2.1 判定制） ----------

# 夺取行动权（"获得行动权"的特殊情况）：target＝夺取方。结算后同样发 gain。
func _resolve_initiative_seize(action: GameAction) -> void:
	active_side = _side_of(action.target)
	pipeline.acting_side = active_side
	pipeline.events.append("【%s】抢先夺得行动权！" % str(action.context.get("xinfa", "")))
	var gain := GameAction.new("initiative_gain", action.target, 0, action.target)
	gain.context["rng"] = action.context.get("rng")
	pipeline.submit(gain)

func _side_of(unit) -> String:
	return "player" if unit == player else "enemy"

# ---------- 抽牌（经管线流转，PRE 可改张数、POST 可触发） ----------

func draw_cards(unit: FighterState, amount: int, randomizer: RandomNumberGenerator) -> void:
	var action := GameAction.new("draw", unit, amount)
	action.context["rng"] = randomizer
	pipeline.submit(action)

func shuffle_draw_pile(unit: FighterState, randomizer: RandomNumberGenerator) -> void:
	_randomize_cards(unit.draw_pile, randomizer)

func _randomize_cards(cards: Array, randomizer: RandomNumberGenerator) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := randomizer.randi_range(0, index)
		var temporary = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = temporary
