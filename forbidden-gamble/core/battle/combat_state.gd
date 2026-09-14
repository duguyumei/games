class_name CombatState
extends RefCounted

# 战斗级状态（真气语法 v2.2，《真气语法_v2》§3/§6/§7）：
# - **气海（qi_wall）**＝共墙，单向耗尽、永不回流；干涸后抽牌改抽**自己的牌河**并吃
#   **递增疲劳真伤**（每次抽牌动作一跳、按方累计、河空照跳）——疲劳是唯一兜底。
# - **牌河（rivers）**＝个人弃牌区（各弃各的）：条目 {card, batch, source}；架势弃牌
#   （source=swap）开截牌窗；功法弃牌将来入河不开窗（心法扩展位）。
# - **副露区（FighterState.melds）**＝功法打出的牌（主动打出＋截牌打出），锁死不可截。
# - **截即打**：吃/碰截来当场与手中搭子组型轰出；杠＝四张升档＋被杠者破绽，无补牌。
# - **截牌窗口**：只认对方最近一批架势弃牌（window_state），第一次放行即死。

const CLAIM_PRIORITY := ["杠", "碰", "吃"]
const ATTRIBUTES := ["风", "火", "山"]

var player: FighterState
var enemy: FighterState
var battle_seed: int = 12345
var active_side: String = "player"
# 战斗度量：原子行动总数与玩家架势次数
var action_count: int = 0
var player_swap_count: int = 0
# 共墙（气海）与个人牌河
var qi_wall: Array = []                    # QiCard 数组
var rivers := {"player": [], "enemy": []}  # 各自牌河：{card, batch, source} 数组
var river_batch := 0                       # 批次号：每次架势弃牌自增（窗口只认最新批）
var window_state := {"owner": "", "batch": -1}  # 截牌窗口：owner＝可截方
# 疲劳计数（按方递增）：气海干涸后每次抽牌动作的的反噬序号
var fatigue_count := {"player": 0, "enemy": 0}
# 动作管线：伤害/上状态/抽牌/架势等结算都经它流转，状态效果（毒）、心法都挂成它的钩子。
var pipeline: EffectPipeline
var status_runtime: StatusRuntime
var xinfa_runtime: XinfaRuntime
# 敌方脑（敌方系统 v2 ×真气语法 v2.2）：行为链梯＋架势策略；截牌改同构必截（无钩子）。
var enemy_brain: EnemyBrain

func _init(new_player: FighterState, new_enemy: FighterState) -> void:
	player = new_player
	enemy = new_enemy
	qi_wall = EncounterLoader.qi_sea_cards(new_enemy.enemy_def)
	pipeline = EffectPipeline.new()
	# 纯机体结算共用一份表（hp_loss/heal/guard 三件——与临时管线同源不漂移）
	ResolverTable.register(pipeline)
	# 带状态/计数/钩子通知的结算由本类注册（damage 破盾、status_apply 词表、气循环、先手夺取）
	pipeline.register_resolver("damage", _resolve_damage)
	pipeline.register_resolver("status_apply", _resolve_status_apply)
	pipeline.register_resolver("draw", _resolve_draw)
	pipeline.register_resolver("swap", _resolve_swap)
	pipeline.register_resolver("initiative_seize", _resolve_initiative_seize)
	# 抽象点位（纯时点，无默认结算）
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

func opponent_for(side: String) -> FighterState:
	return enemy if side == "player" else player

func unit_for(side: String) -> FighterState:
	return player if side == "player" else enemy

func side_of(unit: FighterState) -> String:
	return "player" if unit == player else "enemy"

func other_side(side: String) -> String:
	return "enemy" if side == "player" else "player"

func river_of(side: String) -> Array:
	return rivers[side]

# ---------- 管线默认结算（RESOLVE 层） ----------

func _resolve_damage(action: GameAction) -> void:
	var unit: FighterState = action.target
	var guard_before := unit.guard
	action.context["damage_result"] = unit.take_damage(maxi(action.amount, 0))
	# 破盾＝纯物理：护境＞0 被伤害打到归零——只发事件文案＋点位（乱族已退役，
	# 点位保留给未来敌方心法位/演出）。
	if guard_before > 0 and unit.guard == 0:
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
	_draw_from_wall(action.target, action.amount, action.context.get("rng"))

# 架势（真气语法 v2.2 §5）：弃 context.discard_indices（1–4 张）入**自己的牌河**（新批次，
# 为对方开截牌窗），再纳至 action.amount（丹田容量）。弃/纳数写回 context 供战报披露。
func _resolve_swap(action: GameAction) -> void:
	var unit: FighterState = action.target
	var discarded: Array = []
	if action.context.has("discard_indices"):
		var indices: Array = action.context["discard_indices"]
		indices.sort()
		indices.reverse()  # 从大索引往小删，避免位移
		for raw in indices:
			var index := int(raw)
			if index >= 0 and index < unit.hand.size():
				discarded.append(unit.hand[index])
				unit.hand.remove_at(index)
	else:
		discarded = unit.hand.duplicate()
		unit.hand.clear()
	action.context["discarded_count"] = discarded.size()
	# 弃牌入自己的牌河（新批次）＋为对方开窗（窗口只认这批；source=swap）
	var discard_side := side_of(unit)
	river_batch += 1
	action.context["batch"] = river_batch
	for card in discarded:
		rivers[discard_side].append({"card": card, "batch": river_batch, "source": "swap"})
	window_state = {"owner": other_side(discard_side), "batch": river_batch}
	if unit == player:
		player_swap_count += 1
	var before := unit.hand.size()
	_draw_from_wall(unit, maxi(action.amount - unit.hand.size(), 0), action.context.get("rng"))
	action.context["drawn_count"] = unit.hand.size() - before

# 从气海抽气入丹田（§7 单向耗尽）：气海有牌先抽墙；缺口碰**自己的牌河**随机抽，
# 每次抽牌动作只要碰到河＝一次疲劳真伤（按方递增；河空照样跳、照样伤——直接砍气血，
# 不过护境、不受任何效果影响）。
func _draw_from_wall(unit: FighterState, amount: int, randomizer: RandomNumberGenerator) -> void:
	var drawn := 0
	while drawn < amount and not qi_wall.is_empty():
		unit.hand.append(qi_wall.pop_back())
		drawn += 1
	var deficit := amount - drawn
	if deficit <= 0:
		return
	var side := side_of(unit)
	fatigue_count[side] = int(fatigue_count[side]) + 1
	var dmg := int(fatigue_count[side])
	unit.hp = maxi(unit.hp - dmg, 0)
	var own_river: Array = rivers[side]
	var got := 0
	while got < deficit and not own_river.is_empty():
		var index := 0 if randomizer == null else randomizer.randi_range(0, own_river.size() - 1)
		var card = (own_river[index] as Dictionary)["card"]
		own_river.remove_at(index)
		unit.hand.append(card)
		got += 1
	if got > 0:
		pipeline.events.append("气海已涸——%s强纳河中浊气 %d 口，真气反噬 %d 点！（疲劳第 %d 次）" % [
			unit.display_name, got, dmg, dmg])
	else:
		pipeline.events.append("气海与河皆涸——%s无气可纳，真气反噬 %d 点！（疲劳第 %d 次）" % [
			unit.display_name, dmg, dmg])

# ---------- 截即打（吃碰杠，《真气语法_v2》§6；敌我同一条路） ----------

# 窗口开关
func close_window() -> void:
	window_state = {"owner": "", "batch": -1}

func window_open_for(side: String) -> bool:
	return str(window_state.get("owner", "")) == side

# 某方视角可截的选项（截即打：截来当场组型轰出，须有冷却好的对应功法；蓄力锁在核心层）。
# 选项：{kind: 杠/碰/吃, river_side, river_index, card, technique, unit, pair?(吃)}。
func claim_options(unit: FighterState) -> Array:
	var options: Array = []
	var owner_side := side_of(unit)
	if not window_open_for(owner_side) or unit.has_active_charge():
		return options
	var river_side := other_side(owner_side)
	var batch := int(window_state.get("batch", -1))
	var entries: Array = rivers[river_side]
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if int(entry.get("batch", -1)) != batch or str(entry.get("source", "")) != "swap":
			continue
		var card: QiCard = entry["card"]
		if PatternEvaluator.can_kan(unit.hand, card):
			for technique_id in _claimable_techniques(unit, PatternEvaluator.KEZI):
				options.append({"kind": "杠", "river_side": river_side, "river_index": index,
					"card": card, "technique": technique_id, "unit": unit})
		if PatternEvaluator.can_pon(unit.hand, card):
			for technique_id in _claimable_techniques(unit, PatternEvaluator.KEZI):
				options.append({"kind": "碰", "river_side": river_side, "river_index": index,
					"card": card, "technique": technique_id, "unit": unit})
		var melds := PatternEvaluator.chi_melds(unit.hand, card)
		if not melds.is_empty():
			for technique_id in _claimable_techniques(unit, PatternEvaluator.SHUNZI):
				options.append({"kind": "吃", "river_side": river_side, "river_index": index,
					"card": card, "technique": technique_id, "unit": unit, "pair": melds[0]})
	return options

# 冷却好且非蓄力、匹配牌型的功法表（声明序）。
func _claimable_techniques(unit: FighterState, pattern: String) -> Array:
	return _static_claimable_techniques(unit, pattern)

static func _static_claimable_techniques(unit: FighterState, pattern: String) -> Array:
	var out: Array = []
	for technique_id in unit.techniques:
		var data := TechniqueResolver.data_for(str(technique_id))
		if not (data.get("patterns", []) as Array).has(pattern):
			continue
		if int(data.get("charge", 0)) > 0:
			continue
		if int(unit.technique_cooldowns.get(str(technique_id), 0)) > 0:
			continue
		out.append(technique_id)
	return out

# 应用截即打：河牌＋手中搭子组成刻/顺（杠＝四张）当场发动；牌沉入副露区；杠＝被杠者破绽（无补牌）。
func apply_claim_fire(option: Dictionary, randomizer: RandomNumberGenerator) -> Dictionary:
	var unit: FighterState = option["unit"]
	var river_side := str(option["river_side"])
	var index := int(option["river_index"])
	var card: QiCard = (rivers[river_side][index] as Dictionary)["card"]
	rivers[river_side].remove_at(index)
	var kind := str(option["kind"])
	var cards: Array = [card]
	var grabbed := 0
	if kind == "吃":
		for pair_card in option["pair"]:
			unit.hand.erase(pair_card)
			cards.append(pair_card)
	else:
		var need := 2 if kind == "碰" else 3
		for hand_card in unit.hand.duplicate():
			if grabbed < need and PatternEvaluator.same_tile(hand_card, card):
				unit.hand.erase(hand_card)
				cards.append(hand_card)
				grabbed += 1
	var technique_id := str(option["technique"])
	var victim := opponent_for(side_of(unit))
	var pre_validated := kind == "杠"  # 四张组合不经三张牌型判定
	var result := TechniqueResolver.resolve(technique_id, cards, unit, victim, pipeline, randomizer, pre_validated)
	unit.melds.append(cards)  # 副露区：锁死、公开、不可截
	var cd := int(TechniqueResolver.data_for(technique_id).get("cooldown", 0))
	if cd > 0:
		unit.technique_cooldowns[technique_id] = cd
	if kind == "杠":
		victim.flawed = true
		pipeline.events.append("%s连锅截下【%s】——【%s】升档轰出！%s露出破绽！" % [
			unit.display_name, card.display_name(), technique_id, victim.display_name])
	else:
		pipeline.events.append("%s%s下【%s】，当场轰出【%s】！" % [
			unit.display_name, kind, card.display_name(), technique_id])
	return result

# 应读数（实时，§6）：该单位**此刻**能截哪些牌（手牌搭子＋冷却好的功法活算；蓄力中全哑）。
# 你架势弃牌前看得见雷区；顺带泄露其手牌结构（"它能碰山4"＝它有两张山4）——读牌层本身。
func claim_threats(unit: FighterState) -> Array[Dictionary]:
	return claim_threats_for(unit)

# 静态入口（演武场敌情面板等无战斗实例处共用）。
static func claim_threats_for(unit: FighterState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit.has_active_charge():
		return out
	for attribute in ATTRIBUTES:
		for value in range(QiCard.VALUE_MIN, QiCard.VALUE_MAX + 1):
			var probe := QiCard.new("probe", attribute, value)
			if PatternEvaluator.can_kan(unit.hand, probe):
				if not _static_claimable_techniques(unit, PatternEvaluator.KEZI).is_empty():
					out.append({"claim": "杠", "attribute": attribute, "value": value})
			elif PatternEvaluator.can_pon(unit.hand, probe):
				if not _static_claimable_techniques(unit, PatternEvaluator.KEZI).is_empty():
					out.append({"claim": "碰", "attribute": attribute, "value": value})
			if not PatternEvaluator.chi_melds(unit.hand, probe).is_empty():
				if not _static_claimable_techniques(unit, PatternEvaluator.SHUNZI).is_empty():
					out.append({"claim": "吃", "attribute": attribute, "value": value})
	return out

# 敌方必截首选（杠＞碰＞吃，同优先按选项序＝入河序）。
func first_claim_for(unit: FighterState) -> Dictionary:
	var options := claim_options(unit)
	for kind in CLAIM_PRIORITY:
		for option in options:
			if str(option.get("kind", "")) == kind:
				return option
	return {}

# ---------- 先手（开战时点；先机诀＝被袭击时夺取先手） ----------

func _resolve_initiative_seize(action: GameAction) -> void:
	active_side = _side_of(action.target)
	pipeline.acting_side = active_side
	pipeline.events.append("【%s】抢先夺得先手！" % str(action.context.get("xinfa", "")))

func _side_of(unit) -> String:
	return "player" if unit == player else "enemy"

# ---------- 抽牌（经管线流转，PRE 可改张数、POST 可触发） ----------

func draw_cards(unit: FighterState, amount: int, randomizer: RandomNumberGenerator) -> void:
	var action := GameAction.new("draw", unit, amount)
	action.context["rng"] = randomizer
	pipeline.submit(action)

func shuffle_wall(randomizer: RandomNumberGenerator) -> void:
	var cards: Array = qi_wall
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := randomizer.randi_range(0, index)
		var temporary = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = temporary
