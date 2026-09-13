class_name XinfaRuntime
extends RefCounted

# 心法载体运行时（D-060/D-061，词表契约见《27》§3）：战斗装配时把双方装备心法的
# effects 词条注册成管线钩子。心法=小丑牌式被动规则修改器：时机(on)×条件(when)×动作(do)，
# 全部数据驱动——数据表达不了的规则在词表加类型，不向数据塞脚本（D-034 同一原则）。
# 敌我同一条规则（D-055 敌人搭配）。选择型效果 v1 一律自动化（如调息诀换最低内力那口）。
#
# 战报克制（01 号"规则透明"由构筑面板承担完整披露，战报只留关键行）：
# 纯数值修正（传输/加伤/减伤）不弹行——终值走既有伤害/战报；其余效果一行【心法名】短文案。

# 各时点的默认相位：technique_prepare 必须是 pre（改本次传输的唯一窗口），其余默认 post
const PHASE_DEFAULTS := {"technique_prepare": "pre"}

var _pipeline: EffectPipeline
# 双方引用（D-064）：夺取的互抵判断与方向条件需要看对手；side 映射供持有方优先排序
var _player: FighterState
var _enemy: FighterState
# 呼吸钟（D-063）：每名战斗单位的调息计数——once_per_breath 换界与 breath_gte 的基准
var _breaths := {}
# once 记账：battle 级 "unit|xf|idx"；breath 级 "unit|xf|idx|b<N>"（键含该单位调息数，换气自动失效）
var _used := {}

func _init(pipeline: EffectPipeline) -> void:
	_pipeline = pipeline
	# 内部钟：调息动作（TurnManager 提交，target＝喘气者）。优先级 -10 抢在所有心法
	# 之前计数——否则本次调息触发的词条会拿旧的 key，误判"本口气已用过"。
	_pipeline.register_hook({
		"carrier": "xinfa_runtime:clock",
		"on": "breath",
		"phase": "post",
		"priority": -10,
		"handler": func(action: GameAction) -> void:
			var unit: FighterState = action.target
			if unit != null:
				_breaths[unit.fighter_id] = int(_breaths.get(unit.fighter_id, 0)) + 1,
	})

# 接线双方（CombatState 装配时先调）：方向条件与互抵判断的前提。
func wire_sides(new_player: FighterState, new_enemy: FighterState) -> void:
	_player = new_player
	_enemy = new_enemy

func _opponent_of(unit: FighterState) -> FighterState:
	if unit == _player:
		return _enemy
	return _player

func _side_of(unit: FighterState) -> String:
	return "player" if unit == _player else "enemy"

# 把一名战斗单位装备的心法注册成钩子（CombatState 装配时对双方各调一次）。
func setup(unit: FighterState) -> void:
	for xf_id in unit.xinfa:
		var data := xinfa_data(xf_id)
		if data.is_empty():
			push_warning("XinfaRuntime: 未知心法 " + str(xf_id))
			continue
		var effects: Array = data.get("effects", [])
		for index in effects.size():
			_register_effect(unit, str(xf_id), index, effects[index])

func _register_effect(unit: FighterState, xf_id: String, effect_index: int, effect: Dictionary) -> void:
	var on := str(effect.get("on", ""))
	var phase := str(effect.get("phase", PHASE_DEFAULTS.get(on, "post")))
	# handler 经弱引用拿回运行时：pipeline→hook→lambda→runtime→pipeline 会成环泄漏
	var runtime_ref: WeakRef = weakref(self)
	_pipeline.register_hook({
		"carrier": "xinfa:%s:%s" % [xf_id, unit.fighter_id],
		"on": on,
		"phase": phase,
		"side": _side_of(unit),
		"priority": 0,
		"is_alive": func() -> bool: return unit.is_alive(),
		"handler": func(action: GameAction) -> void:
			var runtime: XinfaRuntime = runtime_ref.get_ref()
			if runtime != null:
				runtime._fire(unit, xf_id, effect_index, effect, action),
	})

func _fire(unit: FighterState, xf_id: String, effect_index: int, effect: Dictionary, action: GameAction) -> void:
	# 词条级触发冷却（化浊诀）：冷却中本词条不触发，归零后可再触发
	var cd_key := "%s|%d" % [xf_id, effect_index]
	if int(unit.xinfa_cooldowns.get(cd_key, 0)) > 0:
		return
	var when: Dictionary = effect.get("when", {})
	if not _conditions_met(when, unit, action):
		return
	if when.get("once_per_battle", false) and _used.has(_key(unit, xf_id, effect_index, "")):
		return
	if when.get("once_per_breath", false) and _used.has(_key(unit, xf_id, effect_index, "|b%d" % _breath_count(unit))):
		return
	if when.get("once_per_battle", false):
		_used[_key(unit, xf_id, effect_index, "")] = true
	if when.get("once_per_breath", false):
		_used[_key(unit, xf_id, effect_index, "|b%d" % _breath_count(unit))] = true
	_apply_do(effect.get("do", {}), unit, xf_id, action)
	# 触发后写冷却（与自己原子行动同钟递减；"每次行动至多一次"由此保证）
	if int(effect.get("cooldown", 0)) > 0:
		unit.xinfa_cooldowns[cd_key] = int(effect["cooldown"])

func _key(unit: FighterState, xf_id: String, effect_index: int, suffix: String) -> String:
	return "%s|%s|%d%s" % [unit.fighter_id, xf_id, effect_index, suffix]

# ---------- 条件（when，全满足才触发） ----------

func _conditions_met(when: Dictionary, unit: FighterState, action: GameAction) -> bool:
	if when.has("attribute_gte"):
		var spec: Dictionary = when["attribute_gte"]
		if _attribute_count(action, str(spec.get("attribute", ""))) < int(spec.get("count", 1)):
			return false
	# grade_lte：选入真气中品级 ≤ grade 的张数 ≥ count（化浊诀"含下品"）
	if when.has("grade_lte"):
		var grade_spec: Dictionary = when["grade_lte"]
		var owned_low := 0
		for card in action.context.get("cards", []):
			if card.grade <= int(grade_spec.get("grade", 1)):
				owned_low += 1
		if owned_low < int(grade_spec.get("count", 1)):
			return false
	if when.has("xinfa_school_gte"):
		var spec: Dictionary = when["xinfa_school_gte"]
		if equipped_school_count(unit.xinfa, str(spec.get("school", ""))) < int(spec.get("count", 1)):
			return false
	if when.has("pattern"):
		var cards: Array = action.context.get("cards", [])
		if cards.is_empty() or not PatternEvaluator.evaluate(cards).has(str(when["pattern"])):
			return false
	if when.has("transfer_gte") and int(action.context.get("transfer", 0)) < int(when["transfer_gte"]):
		return false
	if when.has("breath_gte") and _breath_count(unit) < int(when["breath_gte"]):
		return false
	if when.get("as_attacker", false) and action.source != unit:
		return false
	if when.get("as_target", false) and action.target != unit:
		return false
	# 方向条件（D-064）：事件归属——"敌方获得行动权时"这类监控的过滤词
	if when.get("target_is_enemy", false) and action.target != _opponent_of(unit):
		return false
	if when.get("source_is_enemy", false) and action.source != _opponent_of(unit):
		return false
	return true

func _breath_count(unit: FighterState) -> int:
	return int(_breaths.get(unit.fighter_id, 0))

func _attribute_count(action: GameAction, attribute: String) -> int:
	var count := 0
	for card in action.context.get("cards", []):
		if str(card.attribute) == attribute:
			count += 1
	return count

# ---------- 动作（do） ----------

func _apply_do(do_dict: Dictionary, unit: FighterState, xf_id: String, action: GameAction) -> void:
	match str(do_dict.get("type", "")):
		"transfer_bonus":
			# technique_prepare 的 PRE 阶段改 transfer_modifier，resolve 读回后结算
			var bonus := int(do_dict.get("value", 0))
			if do_dict.has("per_attribute"):
				bonus = int(do_dict.get("value", 0)) * _attribute_count(action, str(do_dict["per_attribute"]))
			action.context["transfer_modifier"] = int(action.context.get("transfer_modifier", 0)) + bonus
		"damage_bonus":
			action.amount += int(do_dict.get("value", 0))
		"damage_resist":
			action.amount = maxi(action.amount - int(do_dict.get("value", 0)), 0)
		"reflect":
			# 反震不再反震（tag 防 ping-pong；另有 once_per_round 记账兜底）
			if action.tags.has("reflect") or not (action.source is FighterState) or not action.source.is_alive():
				return
			var echo := GameAction.new("damage", action.source, int(do_dict.get("value", 0)), unit)
			echo.tags = ["reflect"]
			_pipeline.submit(echo)
			_emit("【%s】反震%d点。" % [xf_id, int(do_dict.get("value", 0))])
		"guard_bonus":
			var gain := GameAction.new("guard_gain", unit, int(do_dict.get("value", 0)), unit)
			_pipeline.submit(gain)
			_emit("【%s】护境+%d。" % [xf_id, int(do_dict.get("value", 0))])
		"seize_initiative":
			# 互抵写在本词条的执行方法里（用户模型：方法内判断，通过才执行动作）——
			# 敌方也装备本门心法则两家都夺不成，不提交夺取动作（也就无从免疫）。
			var opponent := _opponent_of(unit)
			if opponent != null and opponent.xinfa.has(xf_id):
				_emit("【%s】对方亦同修此诀，气机相抵，夺取无功。" % xf_id)
				return
			var seize := GameAction.new("initiative_seize", unit, 0, unit)
			seize.context["xinfa"] = xf_id
			seize.context["rng"] = action.context.get("rng")
			_pipeline.submit(seize)
		"cancel":
			# 通用免疫：取消本动作（仅 pre 相位合法，DataRepo 校验）。取消的是
			# 移交＝保留行动权；取消的是夺取/伤害/护境变更＝对那件事免疫。
			action.cancelled = true
		"amount_bonus":
			# 通用数值改写（仅 pre）：如调息纳气量 +1（长息诀）。
			action.amount += int(do_dict.get("value", 0))
		"heal":
			var heal := GameAction.new("heal", unit, int(do_dict.get("value", 0)), unit)
			_pipeline.submit(heal)
			_emit("【%s】回气%d。" % [xf_id, int(do_dict.get("value", 0))])
		"draw":
			_submit_draw(unit, int(do_dict.get("value", 0)), action)
			_emit("【%s】纳入%d口气。" % [xf_id, int(do_dict.get("value", 0))])
		"wash_back":
			# 调息诀：调息时手牌中随机一张最高品级真气不入气海，改为洗入丹田（好气快回）。
			# 必须 PRE：RESOLVE 才弃牌，晚了牌已进气海。
			if unit.hand.is_empty():
				return
			var best_grade := -1
			for card in unit.hand:
				best_grade = maxi(best_grade, card.grade)
			var candidates: Array = []
			for card in unit.hand:
				if card.grade == best_grade:
					candidates.append(card)
			var randomizer: RandomNumberGenerator = action.context.get("rng")
			var rescued = candidates[0]
			if randomizer != null and candidates.size() > 1:
				rescued = candidates[randomizer.randi_range(0, candidates.size() - 1)]
			unit.hand.erase(rescued)
			if randomizer != null and not unit.draw_pile.is_empty():
				unit.draw_pile.insert(randomizer.randi_range(0, unit.draw_pile.size()), rescued)
			else:
				unit.draw_pile.push_front(rescued)
			_emit("【%s】%s不入气海，洗回丹田。" % [xf_id, rescued.display_name()])
		"breath_transform":
			# 气海无涯：调息行为改写——不弃手牌，改为从丹田提 draws 张（手牌净涨）
			action.amount = int(do_dict.get("draws", action.amount))
			if bool(do_dict.get("keep_hand", false)):
				action.context["keep_hand"] = true
			_emit("【%s】气海无涯，真气不散。" % xf_id)
		"lift_bonus":
			pass  # 已退役（长息诀随提气删除，2026-09-13）；分支保留空壳防旧档数据报错
		"qi_amount_bonus":
			# 化浊诀：technique_prepare 的 PRE 改写本次真气量（amount_modifier 通道）
			action.context["amount_modifier"] = int(action.context.get("amount_modifier", 0)) + int(do_dict.get("value", 0))
		"apply_status":
			var target: FighterState = action.target if str(do_dict.get("to", "opponent")) == "opponent" else unit
			if not (target is FighterState):
				return
			var apply := GameAction.new("status_apply", target, int(do_dict.get("value", 0)), unit)
			apply.context["status"] = str(do_dict.get("status", ""))
			_pipeline.submit(apply)
			_emit("【%s】施%s×%d。" % [xf_id, StatusRuntime.status_name(str(do_dict.get("status", ""))), int(do_dict.get("value", 0))])
		"self_hp_loss":
			var cost := GameAction.new("hp_loss", unit, int(do_dict.get("value", 0)), unit)
			_pipeline.submit(cost)
			_emit("【%s】强行催劲，失去%d点气血。" % [xf_id, int(do_dict.get("value", 0))])
		_:
			push_warning("XinfaRuntime: 未知心法动作类型 " + str(do_dict.get("type", "")))

func _submit_draw(unit: FighterState, amount: int, source_action: GameAction) -> void:
	# 抽气需要 rng：battle_start / round_start / technique_use 的动作上下文由 TurnManager 注入
	var randomizer: RandomNumberGenerator = source_action.context.get("rng")
	if randomizer == null:
		push_warning("XinfaRuntime: 动作上下文缺少 rng，抽气效果跳过")
		return
	var draw := GameAction.new("draw", unit, amount, unit)
	draw.context["rng"] = randomizer
	_pipeline.submit(draw)

func _emit(text: String) -> void:
	_pipeline.events.append(text)

# ---------- 面板/图鉴静态助手（构筑面板规则汇总用，不进战斗） ----------

static func xinfa_data(xf_id: String) -> Dictionary:
	return DataRepo.xinfa().get(xf_id, {})

# 装备列表中某系心法门数（xinfa_school_gte 条件与面板显示同口径，含通用系查询）
static func equipped_school_count(xinfa_list: Array, school: String) -> int:
	var count := 0
	for xf_id in xinfa_list:
		if str(xinfa_data(str(xf_id)).get("school", "")) == school:
			count += 1
	return count

# 由数据生成人读规则文本（构筑面板/图鉴披露；不手写文案，数据即真相）
static func effect_text(xf_id: String) -> String:
	var data := xinfa_data(xf_id)
	if data.is_empty():
		return ""
	var parts: Array[String] = []
	for effect in data.get("effects", []):
		var text := _on_text(str(effect.get("on", "")), str(effect.get("phase", ""))) \
			+ _when_text(effect.get("when", {})) + _do_text(effect.get("do", {}))
		if not text.is_empty():
			parts.append(text)
	return "；".join(parts)

static func _on_text(on: String, phase: String) -> String:
	var prefix = {
		"battle_start": "战斗开始时",
		"breath": "每次调息时" if phase != "pre" else "调息纳气之际",
		"technique_prepare": "出招凝劲时",
		"technique_use": "出招之后",
		"damage": "伤害结算时",
		"initiative_gain": "获得行动权时",
		"initiative_transfer": "行动权将移交时",
		"initiative_seize": "有人夺取行动权时",
	}.get(on, "")
	var prefix_text := str(prefix)
	return prefix_text + "，" if not prefix_text.is_empty() else ""

static func _when_text(when: Dictionary) -> String:
	var parts: Array[String] = []
	if when.has("attribute_gte"):
		var spec: Dictionary = when["attribute_gte"]
		parts.append("出招含≥%d张%s气时" % [int(spec.get("count", 1)), str(spec.get("attribute", ""))])
	if when.has("grade_lte"):
		var spec: Dictionary = when["grade_lte"]
		parts.append("选入≥%d张品级≤%d的真气时" % [int(spec.get("count", 1)), int(spec.get("grade", 1))])
	if when.has("xinfa_school_gte"):
		var spec: Dictionary = when["xinfa_school_gte"]
		parts.append("装备≥%d门%s系心法时" % [int(spec.get("count", 1)), str(spec.get("school", ""))])
	if when.has("pattern"):
		parts.append("以%s出招时" % PatternEvaluator.pattern_name(str(when["pattern"])))
	if when.has("transfer_gte"):
		parts.append("传输内力≥%d时" % int(when["transfer_gte"]))
	if when.has("breath_gte"):
		parts.append("第%d次调息起" % int(when["breath_gte"]))
	if when.get("as_attacker", false):
		parts.append("自己出手时")
	if when.get("as_target", false):
		parts.append("自己受击时")
	if when.get("target_is_enemy", false):
		parts.append("事涉敌方时")
	if when.get("source_is_enemy", false):
		parts.append("事出敌方时")
	if when.get("once_per_breath", false):
		parts.append("每口气一次")
	if when.get("once_per_battle", false):
		parts.append("每场一次")
	if parts.is_empty():
		return ""
	return "，".join(parts) + "："

static func _do_text(do_dict: Dictionary) -> String:
	match str(do_dict.get("type", "")):
		"transfer_bonus":
			if do_dict.has("per_attribute"):
				return "每张%s系真气使传输内力+%d" % [str(do_dict["per_attribute"]), int(do_dict.get("value", 0))]
			return "本次传输内力+%d" % int(do_dict.get("value", 0))
		"damage_bonus":
			return "伤害+%d" % int(do_dict.get("value", 0))
		"damage_resist":
			return "受到的伤害−%d" % int(do_dict.get("value", 0))
		"reflect":
			return "反震攻击者%d点伤害" % int(do_dict.get("value", 0))
		"guard_bonus":
			return "护境+%d" % int(do_dict.get("value", 0))
		"heal":
			return "回气%d" % int(do_dict.get("value", 0))
		"draw":
			return "额外抽%d口气" % int(do_dict.get("value", 0))
		"wash_back":
			return "调息时手牌中随机一张最高品真气不入气海，改为洗入丹田"
		"breath_transform":
			var draws := int(do_dict.get("draws", 3))
			return "调息不再弃置手牌，改为从丹田提%d张（手牌净涨）" % draws
		"lift_bonus":
			return "（已退役）本口气提气次数+%d" % int(do_dict.get("value", 1))
		"qi_amount_bonus":
			return "本次真气量+%d" % int(do_dict.get("value", 0))
		"apply_status":
			var to := "予出招目标" if str(do_dict.get("to", "opponent")) == "opponent" else "予自身"
			return "施%s×%d（%s）" % [StatusRuntime.status_name(str(do_dict.get("status", ""))), int(do_dict.get("value", 0)), to]
		"self_hp_loss":
			return "失去%d点气血" % int(do_dict.get("value", 0))
		"seize_initiative":
			return "夺取行动权（对方同修本诀则相抵无效）"
		"cancel":
			return "取消此动作"
		"amount_bonus":
			return "此动作数值%+d" % int(do_dict.get("value", 0))
	return ""
