class_name EnemyBrain
extends RefCounted

# 敌方脑（敌方系统 v2 × 真气语法 v2.2）：行为链梯＋架势策略＋双刻度冷却。敌人＝对手卡，脑是哑执行器。
#
# - ladder：行为链梯（带记忆 Selector）。每次它行动后锁定意图：「自况条件 → 账面可付
#   （三张刻/顺成型）→ 行为冷却（最后一层）」，全过才锁；末位无条件链＝架势地板。
# - **截牌改同构必截**（2026-09-15 定案，authored 钩子/灯三态/武装门退役）：敌方用与玩家
#   同一条规则（真实手牌判定窗口），能截必截、按序截（杠＞碰＞吃）——判断在
#   CombatState.claim_options/TurnManager._enemy_claim_chain，脑不再持钩子。
#   敌方人格由手牌构成＋气海配比表达（FighterState.techniques 由梯级声明序填充）。
# - 换手策略（数据谓词）：全换／弃低值／弃高值／弃孤张，至多弃 4。
#
# 时序契约：意图锁定只在它行动后；截牌不翻意图（牌当场轰出，不占它的计划位）。

const FLOOR := "架势"

var def: Dictionary
var ladder: Array = []
# 锁定的意图：{action: "technique"/"swap"/"charge", technique, label, source, rule_index}
var intent: Dictionary = {}
# 行为冷却（机会钟）：梯级下标 -> 剩余可行之机的拦截次数
var rule_cooldowns := {}
var _source := {"type": "", "index": -1}


func _init(enemy_def: Dictionary) -> void:
	def = enemy_def
	ladder.assign(enemy_def.get("ladder", []))


# ---------- 意图锁定（它行动后调用；蓄力期间显示蓄力招） ----------

func lock_intent(enemy: FighterState) -> Dictionary:
	if enemy.has_active_charge():
		var charging_tech := str(enemy.charging.get("technique", ""))
		intent = {
			"action": "charge",
			"technique": charging_tech,
			"label": "%s·蓄势" % charging_tech,
			"source": "charge",
		}
		return intent
	for index in range(ladder.size()):
		var rule: Dictionary = ladder[index]
		var technique := str(rule.get("technique", ""))
		if technique == FLOOR:
			intent = _swap_intent(index)
			_source = {"type": "ladder", "index": index}
			return intent
		if not _conditions_met(rule.get("when", {}), enemy):
			continue
		if TechniqueResolver.find_legal_selection(technique, enemy.hand, enemy).is_empty():
			continue  # 账面不可付（三张不成型）：落链（冷却不发言）
		var left := int(rule_cooldowns.get(index, 0))
		if left > 0:
			rule_cooldowns[index] = left - 1
			continue
		intent = {
			"action": "technique",
			"technique": technique,
			"label": technique,
			"source": "ladder",
			"rule_index": index,
		}
		_source = {"type": "ladder", "index": index}
		return intent
	intent = _swap_intent(ladder.size() - 1)
	_source = {"type": "ladder", "index": ladder.size() - 1}
	return intent


func _swap_intent(rule_index: int) -> Dictionary:
	return {
		"action": "swap",
		"technique": FLOOR,
		"label": FLOOR,
		"source": "ladder",
		"rule_index": rule_index,
	}


# ---------- 执行（TurnManager 驱动；打出的牌由 TurnManager 沉入副露区） ----------

func execute(enemy: FighterState, target: FighterState, pipe: EffectPipeline, randomizer: RandomNumberGenerator, dantian_size: int) -> Dictionary:
	if intent.is_empty():
		lock_intent(enemy)
	for _attempt in range(2):
		match str(intent.get("action", "")):
			"swap":
				return _execute_swap(enemy, pipe, randomizer, dantian_size)
			"charge":
				return {"ok": true, "action": "charge_active"}
			_:
				var technique := str(intent.get("technique", ""))
				var cards := TechniqueResolver.find_legal_selection(technique, enemy.hand, enemy)
				if cards.is_empty():
					lock_intent(enemy)
					continue
				if int(TechniqueResolver.data_for(technique).get("charge", 0)) > 0:
					return {"ok": true, "action": "charge_start", "technique": technique, "cards": cards}
				var result := TechniqueResolver.resolve(technique, cards, enemy, target, pipe, randomizer)
				if not bool(result.get("ok", false)):
					lock_intent(enemy)
					continue
				result["action"] = "technique"
				return result
	intent = _swap_intent(ladder.size() - 1)
	_source = {"type": "ladder", "index": ladder.size() - 1}
	return _execute_swap(enemy, pipe, randomizer, dantian_size)


func _execute_swap(enemy: FighterState, pipe: EffectPipeline, randomizer: RandomNumberGenerator, dantian_size: int) -> Dictionary:
	var action := GameAction.new("swap", enemy, dantian_size, enemy)
	action.context["rng"] = randomizer
	action.context["discard_indices"] = _policy_discard_indices(enemy)
	pipe.submit(action)
	return {
		"ok": true,
		"action": "swap",
		"discarded": int(action.context.get("discarded_count", 0)),
		"drawn": int(action.context.get("drawn_count", 0)),
	}


# 行动后收尾：按来源置冷却（执行时置满）。
func after_execute(enemy: FighterState) -> void:
	if _source.type == "ladder" and int(_source.index) >= 0:
		var cd := int((ladder[_source.index] as Dictionary).get("cooldown", 0))
		if cd > 0:
			rule_cooldowns[_source.index] = cd
	_source = {"type": "", "index": -1}


# ---------- 换手策略（谓词数据：决定弃哪些，无评估；至多弃 4 张） ----------

func _policy_discard_indices(enemy: FighterState) -> Array:
	var policy := str(def.get("swap_policy", "all"))
	var indices: Array = []
	match policy:
		"low_value":
			for index in range(enemy.hand.size()):
				if (enemy.hand[index] as QiCard).value <= 4:
					indices.append(index)
		"high_value":
			for index in range(enemy.hand.size()):
				if (enemy.hand[index] as QiCard).value >= 6:
					indices.append(index)
		"singletons":
			var counts := {}
			for card in enemy.hand:
				var attribute := str((card as QiCard).attribute)
				counts[attribute] = int(counts.get(attribute, 0)) + 1
			for index in range(enemy.hand.size()):
				if int(counts.get(str((enemy.hand[index] as QiCard).attribute), 0)) == 1:
					indices.append(index)
		_:
			indices.assign(range(enemy.hand.size()))  # 全换
	# 上限 4 张：超出时保数值最低的四张（弃差留好）
	if indices.size() > 4:
		indices.sort_custom(func(a, b) -> bool:
			return (enemy.hand[a] as QiCard).value < (enemy.hand[b] as QiCard).value)
		indices = indices.slice(0, 4)
	return indices


# ---------- 条件与文案 ----------

func _conditions_met(conditions: Dictionary, enemy: FighterState) -> bool:
	return ConditionEvaluator.evaluate(conditions, {"unit": enemy})


# 梯概览（演武场敌情面板用）：每级「条件→功法（隔N）」串联。
func ladder_overview() -> String:
	var parts: Array[String] = []
	for rule in ladder:
		var technique := str((rule as Dictionary).get("technique", ""))
		var text := technique
		var cond := _when_text((rule as Dictionary).get("when", {}))
		if not cond.is_empty():
			text = "%s→%s" % [cond, technique]
		if int((rule as Dictionary).get("cooldown", 0)) > 0:
			text += "（隔%d）" % int((rule as Dictionary).get("cooldown", 0))
		parts.append(text)
	return " → ".join(parts)


func _when_text(conditions: Dictionary) -> String:
	if conditions.is_empty():
		return ""
	var parts: Array[String] = []
	if conditions.has("guard_lt"):
		parts.append("盾<%d" % int(conditions["guard_lt"]))
	if conditions.has("guard_gt"):
		parts.append("盾>%d" % int(conditions["guard_gt"]))
	if conditions.has("hp_lte"):
		parts.append("血≤%d" % int(conditions["hp_lte"]))
	if conditions.has("status_gte"):
		var spec: Dictionary = conditions["status_gte"]
		for status_id in spec:
			parts.append("%s≥%d" % [StatusRuntime.status_name(str(status_id)), int(spec[status_id])])
	return "且".join(parts)
