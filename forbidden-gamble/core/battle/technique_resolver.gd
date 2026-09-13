class_name TechniqueResolver
extends RefCounted

# 通用功法解释器：功法条件是数据（data/techniques.json），本类只做解释执行。
# 新增加法 = 新增一行数据；数据表达不了的效果 = 新增一个 effect type。
# 功法数据经 DataRepo 统一加载（缓存可失效）。
# v1 数值语法（《战斗系统底层_v1》§3/§6）：效果 ＝ 基值 ＋ 系数 × 真气量；
# 真气量 ＝ Σ(品级值 − 功法等级)（见 QiAmountCalculator），效果值下限 0。
# 内力/传输/劲道概念已退役（2026-09-11 定案）。

static func technique_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(DataRepo.techniques().keys())
	return ids

static func data_for(technique_id: String) -> Dictionary:
	return DataRepo.techniques().get(technique_id, {})

# 精确判断"这一组选中的真气"是否满足功法条件（玩家确认和 UI 提示用）。
# 条件只剩牌型与词条门控——冷却中的功法不可发动；蓄力占用行动机会，
# 蓄力期间任何功法都不可发起（充能拍由引擎自动执行）。
static func can_use(technique_id: String, cards: Array, fighter: FighterState = null) -> bool:
	var data := data_for(technique_id)
	if data.is_empty():
		return false
	if cards.is_empty():
		return false
	if fighter != null:
		if fighter.has_active_charge():
			return false
		if int(fighter.technique_cooldowns.get(technique_id, 0)) > 0:
			return false
	var required_patterns: Array = data.get("patterns", [])
	if not required_patterns.is_empty():
		var owned_patterns: Array[String] = PatternEvaluator.evaluate(cards)
		var matched := false
		for pattern in required_patterns:
			if pattern in owned_patterns:
				matched = true
				break
		if not matched:
			return false
	return true

# 在手牌中搜索一组满足条件的真气（AI 和"是否有合法行动"用）。
# 牌型只判断明确选择的真气，所以这里枚举手牌子集；手牌约6张，位掩码枚举开销可忽略。
static func find_legal_selection(technique_id: String, hand: Array, fighter: FighterState = null) -> Array:
	var hand_size := hand.size()
	for mask in range(1, 1 << hand_size):
		var selection: Array = []
		for index in range(hand_size):
			if mask & (1 << index):
				selection.append(hand[index])
		if can_use(technique_id, selection, fighter):
			return selection
	return []

# 一键补齐（M7b 装配流）：在包含 must_include 全部真气的前提下，搜索满足功法条件的最小子集。
# 找不到返回空数组（调用方提示"当前选中真气无法凑成条件"）。
static func find_legal_selection_containing(technique_id: String, hand: Array, must_include: Array = [], fighter: FighterState = null) -> Array:
	var hand_size := hand.size()
	var must_mask := 0
	for card in must_include:
		var index := hand.find(card)
		if index < 0:
			return []
		must_mask |= (1 << index)
	# 枚举所有包含 must_include 的子集，取满足条件的张数最少者（"补齐"＝在已选基础上补最少的牌）
	var best: Array = []
	var best_size := hand_size + 1
	for mask in range(1, 1 << hand_size):
		if (mask & must_mask) != must_mask:
			continue
		if _popcount(mask) >= best_size:
			continue
		var selection: Array = []
		for index in range(hand_size):
			if mask & (1 << index):
				selection.append(hand[index])
		if can_use(technique_id, selection, fighter):
			best = selection
			best_size = selection.size()
	return best

static func _popcount(value: int) -> int:
	var count := 0
	var rest := value
	while rest != 0:
		count += rest & 1
		rest >>= 1
	return count

# pre_validated：蓄力满值发动用——选入真气（含喂气）在起手时已验过合法性，复检会被
# 喂气多出的牌破坏牌型判断；此路径只保留数据存在性检查。
static func resolve(technique_id: String, cards: Array, user: FighterState, target: FighterState, pipeline: EffectPipeline = null, randomizer: RandomNumberGenerator = null, pre_validated := false) -> Dictionary:
	var tech_data := data_for(technique_id)
	if tech_data.is_empty():
		return {"ok": false, "reason": "功法条件不满足"}
	if not pre_validated and not can_use(technique_id, cards, user):
		return {"ok": false, "reason": "功法条件不满足"}
	# 效果经动作管线结算；无管线（纯函数式调用）时用临时管线，行为等价。
	var pipe := pipeline
	if pipe == null:
		pipe = _transient_pipeline()
	var level := int(tech_data.get("level", 1))
	# technique_prepare：真气量计算前的唯一改写窗口——心法词条（化浊诀类）在 PRE 改
	# amount_modifier，这里读回后结算。
	var prep := GameAction.new("technique_prepare", target, 0, user)
	prep.context["technique"] = technique_id
	prep.context["cards"] = cards
	prep.context["level"] = level
	prep.context["amount_modifier"] = 0
	pipe.submit(prep)
	var amount := QiAmountCalculator.qi_amount(cards, level, int(prep.context["amount_modifier"]))
	var result: Dictionary = {
		"ok": true,
		"technique": technique_id,
		"qi_amount": amount,
		"discarded": cards.duplicate(),
	}
	var effect_texts: Array[String] = []
	for effect in tech_data.get("effects", []):
		if not ConditionEvaluator.evaluate(effect.get("when", {}), {"cards": cards}):
			continue
		_apply_effect(effect, amount, user, target, effect_texts, result, pipe, cards, randomizer)
	# 压制词条（敌方系统 v1 §2.4 重定义）：该招给对方施加破绽（跳过下次获得行动权；
	# 不再是"行动权不转让"的特权——统一货币，判定制函数保持纯净）。
	if (tech_data.get("tags", []) as Array).has("压制"):
		target.flawed = true
		effect_texts.append("压制：对方露出破绽")
	result["effect"] = "；".join(effect_texts)
	# technique_use（结算成功后的时点）：功法完整生命周期 prepare→效果→use 统一在 resolve 内
	# 提交——无论入口是 TurnManager 还是纯函数式调用，心法 use 词条行为一致。
	var use_action := GameAction.new("technique_use", target, 0, user)
	use_action.context["technique"] = technique_id
	use_action.context["cards"] = cards
	use_action.context["qi_amount"] = amount
	if randomizer != null:
		use_action.context["rng"] = randomizer
	pipe.submit(use_action)
	return result

# 效果数值＝基值＋系数×真气量（＋每张上品的额外加成），下限 0（负真气量可把效果压到 0，不倒扣）。
static func effect_value(effect: Dictionary, amount: int, cards: Array) -> int:
	var value := int(effect.get("base", 0)) + int(effect.get("scale", 0)) * amount
	if int(effect.get("per_supreme", 0)) > 0:
		var supremes := 0
		for card in cards:
			if card.grade >= 3:
				supremes += 1
		value += int(effect["per_supreme"]) * supremes
	return maxi(value, 0)

# 公式透明（2026-09-13 定案）：效果文本附带算式，玩家每拍看得见构筑在哪起作用。
# 系数参与才披露（纯基值无信息量）；返回带前导空格的注记，无信息时为空串。
static func _formula_note(effect: Dictionary, amount: int, cards: Array) -> String:
	var scale := int(effect.get("scale", 0))
	if scale == 0:
		return ""
	var parts: Array[String] = ["基值%d" % int(effect.get("base", 0))]
	parts.append("系数%d×真气%d" % [scale, amount])
	if int(effect.get("per_supreme", 0)) > 0:
		var supremes := 0
		for card in cards:
			if card.grade >= 3:
				supremes += 1
		if supremes > 0:
			parts.append("上品%d×%d" % [int(effect["per_supreme"]), supremes])
	return "（%s）" % "＋".join(parts)

# 直接函数式调用时的临时管线：纯机体结算共用 ResolverTable（与 CombatState 同源不漂移），
# 伤害/上状态/蓄前时点为本层特化（无事件文案、无词表注册——纯函数语义）。
static func _transient_pipeline() -> EffectPipeline:
	var pipe := EffectPipeline.new()
	ResolverTable.register(pipe)
	pipe.register_resolver("damage", func(action: GameAction) -> void:
		action.context["damage_result"] = (action.target as FighterState).take_damage(maxi(action.amount, 0)))
	pipe.register_resolver("status_apply", func(action: GameAction) -> void:
		(action.target as FighterState).add_status(str(action.context.get("status", "")), action.amount))
	pipe.register_point("technique_prepare")
	return pipe

static func _apply_effect(effect: Dictionary, amount: int, user: FighterState, target: FighterState, texts: Array[String], result: Dictionary, pipe: EffectPipeline, used_cards: Array = [], randomizer: RandomNumberGenerator = null) -> void:
	match str(effect.get("type", "")):
		"damage":
			var dmg := effect_value(effect, amount, used_cards)
			var action := GameAction.new("damage", target, dmg, user)
			action.context["technique"] = str(result.get("technique", ""))
			# 出招真气随伤害动作流转：心法按属性/系计数词条在 damage PRE 可读
			action.context["cards"] = used_cards
			pipe.submit(action)
			if action.cancelled:
				result["damage"] = 0
				texts.append("伤害被抵消")
			else:
				result["damage"] = action.amount
				result["damage_result"] = action.context.get("damage_result", {})
				texts.append("造成%d点伤害%s" % [action.amount, _formula_note(effect, amount, used_cards)])
		"guard_cover":
			# D-064：护境覆盖走管线（guard_set 实际动作，PRE 可拦截＝"护境被压"类词条）
			var cover := effect_value(effect, amount, used_cards)
			var set_action := GameAction.new("guard_set", user, cover, user)
			pipe.submit(set_action)
			if set_action.cancelled:
				texts.append("护境被拦，未能布气")
			else:
				texts.append("护境覆盖为%d%s" % [user.guard, _formula_note(effect, amount, used_cards)])
		"remove_guard":
			# D-064：护境移除走管线（guard_remove 实际动作，可被拦截＝"护境不破"类词条）
			var guard_before := target.guard
			var remove_action := GameAction.new("guard_remove", target, int(effect.get("value", 0)), user)
			remove_action.context["cards"] = used_cards
			pipe.submit(remove_action)
			if remove_action.cancelled:
				texts.append("对方护境未被撼动")
			else:
				texts.append("移除目标%d点护境" % (guard_before - target.guard))
		"apply_status":
			var stacks := effect_value(effect, amount, used_cards)
			var status_id := str(effect.get("status", ""))
			# to:self＝施加给自己（自我增益；默认打在出招目标身上）
			var status_target := user if str(effect.get("to", "")) == "self" else target
			var action := GameAction.new("status_apply", status_target, stacks, user)
			action.context["status"] = status_id
			action.context["cards"] = used_cards
			pipe.submit(action)
			texts.append("施加%s×%d" % [StatusRuntime.status_name(status_id), stacks])
		"heal":
			var healed := mini(int(effect.get("value", 0)), maxi(user.max_hp - user.hp, 0))
			var heal_action := GameAction.new("heal", user, int(effect.get("value", 0)), user)
			pipe.submit(heal_action)
			texts.append("回气%d" % healed)
		"draw":
			# 提气需要 rng（TurnManager 注入）；纯函数式调用无 rng 时跳过并告警
			if randomizer == null:
				push_warning("TechniqueResolver: draw 效果缺少 rng，跳过")
				texts.append("提气失败（无随机源）")
			else:
				var draw_count := effect_value(effect, amount, used_cards)
				var draw_action := GameAction.new("draw", user, draw_count, user)
				draw_action.context["rng"] = randomizer
				pipe.submit(draw_action)
				texts.append("提%d个真气" % draw_count)
		"self_hp_loss":
			var cost := GameAction.new("hp_loss", user, int(effect.get("value", 0)), user)
			pipe.submit(cost)
			texts.append("自损%d点气血" % int(effect.get("value", 0)))
		_:
			push_warning("未知功法效果类型: " + str(effect.get("type", "")))

# 意图展示用的效果摘要（按公开信息口径，由数据计算，不写死文案）。
# 词条级信息（蓄力/压制/冷却）前置标注——行动权流向是公开信息（宪法第 6 条）。
static func effect_summary(technique_id: String) -> String:
	var data := data_for(technique_id)
	var parts: Array[String] = []
	if int(data.get("charge", 0)) > 0:
		parts.append("蓄力%d" % int(data.get("charge", 0)))
	if (data.get("tags", []) as Array).has("压制"):
		parts.append("压制·对方露出破绽")
	if int(data.get("cooldown", 0)) > 0:
		parts.append("冷却%d" % int(data.get("cooldown", 0)))
	for effect in data.get("effects", []):
		match str(effect.get("type", "")):
			"damage":
				parts.append("伤%s" % _amount_text(effect))
			"guard_cover":
				parts.append("盾%s" % _amount_text(effect))
			"remove_guard":
				parts.append("移除护境%d" % int(effect.get("value", 0)))
			"apply_status":
				var to := "（己）" if str(effect.get("to", "")) == "self" else ""
				parts.append("施%s%s" % [StatusRuntime.status_name(str(effect.get("status", ""))), to])
			"heal":
				parts.append("回气%d" % int(effect.get("value", 0)))
			"draw":
				parts.append("提%s" % _amount_text(effect))
			"self_hp_loss":
				parts.append("自损%d" % int(effect.get("value", 0)))
	return "，".join(parts)

# 数值段文案：基值＋系数×量（系数为 0 只写基值；每张上品加成单独标注）
static func _amount_text(effect: Dictionary) -> String:
	var text := "%d" % int(effect.get("base", 0))
	if int(effect.get("scale", 0)) != 0:
		text += "+%d×量" % int(effect.get("scale", 0))
	if int(effect.get("per_supreme", 0)) > 0:
		text += "+%d/上品" % int(effect.get("per_supreme", 0))
	return text
