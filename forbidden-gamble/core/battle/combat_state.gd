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
# 心法运行时（D-060）：装配双方装备心法的词条钩子，敌我同规则。
var xinfa_runtime: XinfaRuntime

func _init(new_player: FighterState, new_enemy: FighterState) -> void:
	player = new_player
	enemy = new_enemy
	pipeline = EffectPipeline.new()
	pipeline.register_resolver("damage", _resolve_damage)
	pipeline.register_resolver("hp_loss", _resolve_hp_loss)
	pipeline.register_resolver("heal", _resolve_heal)
	pipeline.register_resolver("status_apply", _resolve_status_apply)
	pipeline.register_resolver("draw", _resolve_draw)
	pipeline.register_resolver("breath", _resolve_breathe)
	pipeline.register_resolver("lift_qi", _resolve_lift_qi)
	pipeline.register_resolver("initiative_transfer", _resolve_initiative_transfer)
	pipeline.register_resolver("initiative_seize", _resolve_initiative_seize)
	pipeline.register_resolver("guard_set", _resolve_guard_set)
	pipeline.register_resolver("guard_remove", _resolve_guard_remove)
	pipeline.register_resolver("guard_gain", _resolve_guard_gain)
	# 抽象点位（纯时点，无默认结算）
	pipeline.register_point("battle_start")
	pipeline.register_point("technique_use")
	pipeline.register_point("technique_prepare")
	pipeline.register_point("initiative_gain")
	status_runtime = StatusRuntime.new(pipeline)
	xinfa_runtime = XinfaRuntime.new(pipeline)
	xinfa_runtime.wire_sides(player, enemy)
	xinfa_runtime.setup(player)
	xinfa_runtime.setup(enemy)

func opponent_for(side: String) -> FighterState:
	return enemy if side == "player" else player

func unit_for(side: String) -> FighterState:
	return player if side == "player" else enemy

# ---------- 管线默认结算（RESOLVE 层） ----------

func _resolve_damage(action: GameAction) -> void:
	var unit: FighterState = action.target
	action.context["damage_result"] = unit.take_damage(maxi(action.amount, 0))

# 失去气血：绕开护境直接扣减（毒发等侵蚀效果走这里，与"受到伤害"是两个点位）。
func _resolve_hp_loss(action: GameAction) -> void:
	var unit: FighterState = action.target
	unit.hp = maxi(unit.hp - maxi(action.amount, 0), 0)

# 回气：气血回复，不超上限。
func _resolve_heal(action: GameAction) -> void:
	var unit: FighterState = action.target
	unit.hp = mini(unit.hp + maxi(action.amount, 0), unit.max_hp)

func _resolve_status_apply(action: GameAction) -> void:
	var unit: FighterState = action.target
	var status_id := str(action.context.get("status", ""))
	unit.add_status(status_id, action.amount)
	status_runtime.ensure_hooks(unit, status_id)
	pipeline.events.append("%s 身中 %s ×%d。" % [unit.display_name, StatusRuntime.status_name(status_id), unit.get_status(status_id)])

func _resolve_draw(action: GameAction) -> void:
	_draw_into(action.target, action.amount, action.context.get("rng"))

# 调息（吐故纳新，D-063）：手牌全部入气海，再从丹田纳 action.amount 口。
# PRE 钩子可改 amount（心法调息词条的挂点）；气海无涯类词条置 context.keep_hand
# 跳过弃牌；毒发等 breath 时点状态在 POST 结算。
# 调息同时重置本口气的提气记账（次数与心法加成都换界；加成由 breath POST 词条重新授予）。
func _resolve_breathe(action: GameAction) -> void:
	var unit: FighterState = action.target
	if not bool(action.context.get("keep_hand", false)):
		unit.discard_pile.append_array(unit.hand)
		unit.hand.clear()
	unit.lifts_this_breath = 0
	unit.lift_allowance = 0
	if unit == player:
		player_breath_count += 1
	_draw_into(unit, action.amount, action.context.get("rng"))

# 提气（原暂让）：不动手，从丹田提 action.amount 张（限次记账在 TurnManager）。
func _resolve_lift_qi(action: GameAction) -> void:
	_draw_into(action.target, action.amount, action.context.get("rng"))

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

# ---------- 行动权动作（D-064：移交/夺取都是实际动作，PRE 可取消=保留/免疫，可改写=改道） ----------

# 行动权移交：target＝新持有方（PRE 钩子可改写 target＝改道）。结算后向最终持有方发 gain 时点。
func _resolve_initiative_transfer(action: GameAction) -> void:
	active_side = _side_of(action.target)
	pipeline.acting_side = active_side
	var gain := GameAction.new("initiative_gain", action.target, 0, action.target)
	gain.context["rng"] = action.context.get("rng")
	pipeline.submit(gain)

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

# ---------- 护境动作（D-064：覆盖/移除/增减走管线，可被 PRE 拦截） ----------

# 护境覆盖（D-020：新值直接覆盖旧值，即使更低）。
func _resolve_guard_set(action: GameAction) -> void:
	var unit: FighterState = action.target
	unit.guard = maxi(action.amount, 0)

# 护境移除（封顶于当前值）。
func _resolve_guard_remove(action: GameAction) -> void:
	var unit: FighterState = action.target
	unit.guard = maxi(unit.guard - maxi(action.amount, 0), 0)

# 护境增减（心法护境词条）。
func _resolve_guard_gain(action: GameAction) -> void:
	var unit: FighterState = action.target
	unit.guard = maxi(unit.guard + action.amount, 0)

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
