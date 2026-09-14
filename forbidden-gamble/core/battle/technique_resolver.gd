class_name TechniqueResolver
extends RefCounted

# 通用功法解释器：功法条件是数据（data/techniques.json），本类只做解释执行。
# 真气语法 v2（《真气语法_v2》§2）：**功法输入固定三张（刻子或顺子，功法声明）**；
# **威力 ＝ 基值 ＋ 系数 × 数值和**（数值和＝选入真气数值之和，占位）。
# 品级/真气量公式（Σ(品级值−等级)）已退役（2026-09-14 定案）。

static func technique_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(DataRepo.techniques().keys())
	return ids

static func data_for(technique_id: String) -> Dictionary:
	return DataRepo.techniques().get(technique_id, {})

# 数值和：本次选入真气的数值合计（力度的唯一计量）
static func value_sum(cards: Array) -> int:
	var total := 0
	for card in cards:
		total += int(card.value)
	return total

# 精确判断"这一组选中的真气"是否满足功法条件（玩家确认和 UI 提示用）。
# 条件＝三张成 型（刻子/顺子）＋词条门控（冷却/蓄力占用）。
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
# 输入固定三张——只枚举三元组，开销可忽略。
static func find_legal_selection(technique_id: String, hand: Array, fighter: FighterState = null) -> Array:
	var hand_size := hand.size()
	for i in range(hand_size):
		for j in range(i + 1, hand_size):
			for k in range(j + 1, hand_size):
				var selection: Array = [hand[i], hand[j], hand[k]]
				if can_use(technique_id, selection, fighter):
					return selection
	return []

# 一键补齐（装配流）：在包含 must_include 全部真气的前提下，搜索满足功法条件的三张组。
# 找不到返回空数组（调用方提示"当前选中真气无法凑成条件"）。
static func find_legal_selection_containing(technique_id: String, hand: Array, must_include: Array = [], fighter: FighterState = null) -> Array:
	if must_include.size() > PatternEvaluator.PATTERN_SIZE:
		return []
	var base: Array = []
	for card in must_include:
		if not hand.has(card):
			return []
		base.append(card)
	if base.size() == PatternEvaluator.PATTERN_SIZE:
		return base if can_use(technique_id, base, fighter) else []
	var rest: Array = []
	for card in hand:
		if not base.has(card):
			rest.append(card)
	if base.size() == 2:
		for c1 in rest:
			var selection: Array = base + [c1]
			if can_use(technique_id, selection, fighter):
				return selection
	elif base.size() == 1:
		for i in range(rest.size()):
			for j in range(i + 1, rest.size()):
				var selection: Array = base + [rest[i], rest[j]]
				if can_use(technique_id, selection, fighter):
					return selection
	elif base.is_empty():
		return find_legal_selection(technique_id, hand, fighter)
	return []

# pre_validated：蓄力满值/杠升档发动用——选入真气在起手时已验过合法性，
# 杠的四张组合不满足三张牌型判断；此路径只保留数据存在性检查。
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
	# technique_prepare：数值计算前的唯一改写窗口（将来估值型丹田改造挂这里）。
	var prep := GameAction.new("technique_prepare", target, 0, user)
	prep.context["technique"] = technique_id
	prep.context["cards"] = cards
	prep.context["level"] = level
	prep.context["amount_modifier"] = 0
	pipe.submit(prep)
	var amount := value_sum(cards) + int(prep.context["amount_modifier"])
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
	# 压制词条：该招给对方施加破绽（跳过下次获得行动权；统一货币）。
	if (tech_data.get("tags", []) as Array).has("压制"):
		target.flawed = true
		effect_texts.append("压制：对方露出破绽")
	result["effect"] = "；".join(effect_texts)
	var use_action := GameAction.new("technique_use", target, 0, user)
	use_action.context["technique"] = technique_id
	use_action.context["cards"] = cards
	use_action.context["qi_amount"] = amount
	if randomizer != null:
		use_action.context["rng"] = randomizer
	pipe.submit(use_action)
	return result

# 效果数值＝基值＋系数×数值和，下限 0。
static func effect_value(effect: Dictionary, amount: int, cards: Array) -> int:
	var value := int(effect.get("base", 0)) + int(effect.get("scale", 0)) * amount
	return maxi(value, 0)

# 伤害算式注记：基值＋系数×数值和（公式透明）＋力修正（管线 PRE 生效，实结数含它——
# 显示数必须等于实结数）。力为 0 时不添段。
static func _damage_note(effect: Dictionary, amount: int, cards: Array, user: FighterState) -> String:
	var note := _formula_note(effect, amount, cards)
	var li := user.get_status("li")
	if li <= 0:
		return note
	if note.is_empty():
		return "（＋力%d）" % li
	return note.left(note.length() - 1) + "＋力%d）" % li

# 公式透明：效果文本附带算式，玩家每拍看得见构筑在哪起作用。
# 系数参与才披露（纯基值无信息量）；返回带前导空格的注记，无信息时为空串。
static func _formula_note(effect: Dictionary, amount: int, cards: Array) -> String:
	var scale := int(effect.get("scale", 0))
	if scale == 0:
		return ""
	var parts: Array[String] = ["基值%d" % int(effect.get("base", 0))]
	parts.append("系数%d×数值和%d" % [scale, amount])
	return "（%s）" % "＋".join(parts)

# 直接函数式调用时的临时管线：纯机体结算共用 ResolverTable（与 CombatState 同源不漂移）。
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
			action.context["cards"] = used_cards
			pipe.submit(action)
			if action.cancelled:
				result["damage"] = 0
				texts.append("伤害被抵消")
			else:
				result["damage"] = action.amount
				result["damage_result"] = action.context.get("damage_result", {})
				texts.append("造成%d点伤害%s" % [action.amount, _damage_note(effect, amount, used_cards, user)])
		"guard_cover":
			var cover := effect_value(effect, amount, used_cards)
			var set_action := GameAction.new("guard_set", user, cover, user)
			pipe.submit(set_action)
			if set_action.cancelled:
				texts.append("护境被拦，未能布气")
			else:
				texts.append("护境覆盖为%d%s" % [user.guard, _formula_note(effect, amount, used_cards)])
		"remove_guard":
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

# 数值段文案：基值＋系数×数值和（系数为 0 只写基值）
static func _amount_text(effect: Dictionary) -> String:
	var text := "%d" % int(effect.get("base", 0))
	if int(effect.get("scale", 0)) != 0:
		text += "+%d×和" % int(effect.get("scale", 0))
	return text
