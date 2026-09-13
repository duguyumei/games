class_name EnemyBrain
extends RefCounted

# 敌方脑（敌方系统 v2）：行为链梯＋钩子管道＋双刻度冷却。敌人＝对手卡，脑是哑执行器。
#
# 结构（全部是数据，无评估无权重）：
# - ladder：行为链梯（带记忆 Selector）。每次它行动后锁定意图：从上到下
#   「自况条件 → 账面可付 → 行为冷却（最后一层）」，全过才锁；凑不齐＝Failure 落链。
#   末位无条件链＝调息地板（调息也是意图——意图＝即将进行的行动）。
# - hooks：钩子＝事件→（四查）→意图翻牌→当拍执行。两族同一管道：
#   乱（源＝它的自况事件，无预置灯，翻牌即演出，被抓住的是它——翻牌的招执行完
#   入账破绽）；应（源＝你的公开事件，预置灯＋武装门，被抓住的是你——触发即得破绽）。
#   蓄力期间钩子全灭（蓄力锁：起蓄不可换功法，双方同规）。
# - 冷却两刻度：行为冷却（机会钟，歇N……此处按「隔N」语义：可行却被拦的机会里递减，
#   执行时置满）；钩子冷却（行动钟，它每次行动前递减，执行时置满）。
#
# 时序契约（意图永不静默错位）：
# - 意图锁定只在它行动之后；玩家行动不重锁（只能经钩子翻牌）。
# - 钩子在事件瞬间唤醒（事件钟订阅，演出贴事件原位）。

const FLOOR := "调息"

var def: Dictionary
var ladder: Array = []
var hooks: Array = []
# 锁定的意图：{action: "technique"/"breathe"/"charge", technique, label, source, rule_index}
var intent: Dictionary = {}
# 行为冷却（机会钟）：梯级下标 -> 剩余可行之机的拦截次数
var rule_cooldowns := {}
# 钩子冷却（行动钟）：钩子下标 -> 剩余行动数
var hook_cooldowns := {}
# 应手武装态（灯）：钩子下标 -> 是否武装
var armed := {}
# 乱的后坐破绽：翻牌的招执行完才入账（它先补盾，下一拍才踉跄）
var pending_flaw := false
# 本次意图的来源记账（after_execute 据此置冷却）
var _source := {"type": "", "index": -1}


func _init(enemy_def: Dictionary) -> void:
	def = enemy_def
	ladder.assign(enemy_def.get("ladder", []))
	hooks.assign(enemy_def.get("hooks", []))


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
			intent = _breathe_intent(index)
			_source = {"type": "ladder", "index": index}
			return intent
		if not _conditions_met(rule.get("when", {}), enemy):
			continue
		if TechniqueResolver.find_legal_selection(technique, enemy.hand, enemy).is_empty():
			continue  # 账面不可付：落链（冷却不发言）
		# 行为冷却＝判断的最后一层：可行却被拦 → 跳过并递减
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
	# 梯走穿（无地板规则的数据是坏卡）——安全地板
	intent = _breathe_intent(ladder.size() - 1)
	_source = {"type": "ladder", "index": ladder.size() - 1}
	return intent


func _breathe_intent(rule_index: int) -> Dictionary:
	return {
		"action": "breathe",
		"technique": FLOOR,
		"label": FLOOR,
		"source": "ladder",
		"rule_index": rule_index,
	}


# ---------- 执行（TurnManager 驱动；返回计划，机械结算由调用方/本方法经管线完成） ----------

# 执行锁定的意图：功法走 TechniqueResolver（敌我同一管线）；调息走 breath 管线动作
# （策略谓词决定弃哪些）；蓄力功法返回 charge_start 由 TurnManager 起手。
# 锁定招当场付不起（落链）→ 现场重走梯执行下一条，重走仍失败 → 调息（付不起就回填）。
func execute(enemy: FighterState, target: FighterState, pipe: EffectPipeline, randomizer: RandomNumberGenerator, hand_size: int) -> Dictionary:
	if intent.is_empty():
		lock_intent(enemy)
	for _attempt in range(2):
		match str(intent.get("action", "")):
			"breathe":
				return _execute_breathe(enemy, pipe, randomizer, hand_size)
			"charge":
				return {"ok": true, "action": "charge_active"}
			_:
				var technique := str(intent.get("technique", ""))
				var cards := TechniqueResolver.find_legal_selection(technique, enemy.hand, enemy)
				if cards.is_empty():
					lock_intent(enemy)  # 落链：现场重走（含地板）
					continue
				if int(TechniqueResolver.data_for(technique).get("charge", 0)) > 0:
					return {"ok": true, "action": "charge_start", "technique": technique, "cards": cards}
				var result := TechniqueResolver.resolve(technique, cards, enemy, target, pipe, randomizer)
				if not bool(result.get("ok", false)):
					lock_intent(enemy)
					continue
				for card in cards:
					enemy.hand.erase(card)
				enemy.discard_pile.append_array(result.discarded)
				result["action"] = "technique"
				return result
	intent = _breathe_intent(ladder.size() - 1)
	_source = {"type": "ladder", "index": ladder.size() - 1}
	return _execute_breathe(enemy, pipe, randomizer, hand_size)


func _execute_breathe(enemy: FighterState, pipe: EffectPipeline, randomizer: RandomNumberGenerator, hand_size: int) -> Dictionary:
	var action := GameAction.new("breath", enemy, hand_size, enemy)
	action.context["rng"] = randomizer
	action.context["discard_indices"] = _policy_discard_indices(enemy)
	pipe.submit(action)
	return {
		"ok": true,
		"action": "breathe",
		"discarded": int(action.context.get("discarded_count", 0)),
		"drawn": int(action.context.get("drawn_count", 0)),
	}


# 行动后收尾：按来源置冷却（执行时置满）→ 乱的后坐破绽入账 → 应手武装重估。
func after_execute(enemy: FighterState) -> void:
	if _source.type == "ladder" and int(_source.index) >= 0:
		var cd := int((ladder[_source.index] as Dictionary).get("cooldown", 0))
		if cd > 0:
			rule_cooldowns[_source.index] = cd
	elif _source.type == "hook" and int(_source.index) >= 0:
		var cd := int((hooks[_source.index] as Dictionary).get("cooldown", 0))
		if cd > 0:
			hook_cooldowns[_source.index] = cd
	_source = {"type": "", "index": -1}
	if pending_flaw:
		enemy.flawed = true
		pending_flaw = false
	evaluate_arms(enemy)


# 行动钟：它每次行动前递减（钩子冷却；功法/心法冷却走 FighterState.tick_cooldowns 同拍结算）。
func tick_action_clocks() -> void:
	for index in hook_cooldowns.keys():
		var left := int(hook_cooldowns[index]) - 1
		if left <= 0:
			hook_cooldowns.erase(index)
		else:
			hook_cooldowns[index] = left


# ---------- 钩子（事件瞬间唤醒；翻牌即演出） ----------

# 挂上管线事件总线（架构收口：脑像心法/状态一样以 carrier 身份订阅事件，
# CombatState 不再直呼脑——新事件＝管线注册一个点位，全体可订）。
# 订阅映射：guard_broken＝破盾点位（只认自己的盾碎）；player_breathed＝breath 动作
# 的 post 时点（只认你的调息——敌方的调息动作 target 是它自己，被过滤）。
func wire(pipe: EffectPipeline, enemy: FighterState, player: FighterState) -> void:
	var brain := self
	pipe.register_hook({
		"carrier": "enemy_brain:guard_broken",
		"on": "guard_broken",
		"phase": "post",
		"priority": 50,
		"is_alive": func() -> bool: return enemy.is_alive(),
		"handler": func(action: GameAction) -> void:
			if action.target == enemy:
				brain._trigger_event("guard_broken", enemy, player, pipe.events),
	})
	pipe.register_hook({
		"carrier": "enemy_brain:player_breathed",
		"on": "breath",
		"phase": "post",
		"priority": 50,
		"is_alive": func() -> bool: return enemy.is_alive(),
		"handler": func(action: GameAction) -> void:
			if action.target == player:
				brain._trigger_event("player_breathed", enemy, player, pipe.events),
	})


# 按事件名扫描钩子（族与定价按钩子自带数据判定）：乱＝翻牌的招执行完入账破绽
# （它被抓）；应＝你当场得破绽（你被抓）。四查：冷却／武装（仅应）／可付／≠当前意图。
func _trigger_event(event: String, enemy: FighterState, player: FighterState, events: Array) -> void:
	if enemy.has_active_charge():
		return  # 蓄力锁：起蓄不可换功法，钩子全灭
	for index in range(hooks.size()):
		var hook: Dictionary = hooks[index]
		if str(hook.get("on", "")) != event:
			continue
		var kind := str(hook.get("kind", ""))
		if int(hook_cooldowns.get(index, 0)) > 0:
			continue
		if kind == "应" and not bool(armed.get(index, false)):
			continue  # 灯不亮不触发（武装门在它行动后离散评估）
		var technique := str(hook.get("technique", ""))
		if TechniqueResolver.find_legal_selection(technique, enemy.hand, enemy).is_empty():
			continue  # 付不起＝没这个应手（无法使用功法的时候无法监控）
		if str(intent.get("technique", "")) == technique:
			continue  # 与当前意图相同：无转换、无代价
		intent = {
			"action": "technique",
			"technique": technique,
			"label": technique,
			"source": "hook",
			"hook_index": index,
		}
		_source = {"type": "hook", "index": index}
		if kind == "乱":
			pending_flaw = true
			events.append("%s护境被击碎，改招【%s】！" % [enemy.display_name, technique])
		else:
			player.flawed = true
			events.append("%s窥见你的空隙，改出【%s】——你露出破绽！" % [enemy.display_name, technique])
		return  # 一个事件最多翻一次牌


# 应手武装评估（它每次行动后三问：要不要开/能不能开/冷却好了没）。
# 武装态锁定到下次评估；玩家侧只看到灯的亮灭，条件与配置进图鉴（明码）。
func evaluate_arms(enemy: FighterState) -> void:
	for index in range(hooks.size()):
		var hook: Dictionary = hooks[index]
		if str(hook.get("kind", "")) != "应":
			continue
		var ok := int(hook_cooldowns.get(index, 0)) <= 0
		ok = ok and not enemy.has_active_charge()
		ok = ok and ConditionEvaluator.evaluate(hook.get("arm", {}), {"unit": enemy})
		ok = ok and not TechniqueResolver.find_legal_selection(
			str(hook.get("technique", "")), enemy.hand, enemy).is_empty()
		armed[index] = ok


# 应手灯（UI 披露）：就绪/歇N/哑 三态＋明码 tooltip。
func hook_lamps(enemy: FighterState) -> Array[Dictionary]:
	var lamps: Array[Dictionary] = []
	for index in range(hooks.size()):
		var hook: Dictionary = hooks[index]
		if str(hook.get("kind", "")) != "应":
			continue
		var technique := str(hook.get("technique", ""))
		var state := "ready"
		var cd := int(hook_cooldowns.get(index, 0))
		if cd > 0:
			state = "cooldown"
		elif not bool(armed.get(index, false)):
			state = "dark"
		lamps.append({
			"technique": technique,
			"state": state,
			"cooldown": cd,
			"tooltip": "应手【%s】：%s → 它改出此招，你露出破绽 ｜ %s ｜ 武装：%s" % [
				technique,
				_event_text(str(hook.get("on", ""))),
				("歇%d" % int(hook.get("cooldown", 0))) if int(hook.get("cooldown", 0)) > 0 else "无歇",
				_arm_text(hook.get("arm", {})),
			],
		})
	return lamps


# ---------- 调息策略（谓词数据：决定弃哪些，无评估） ----------

func _policy_discard_indices(enemy: FighterState) -> Array:
	var policy := str(def.get("breathe_policy", "all"))
	var indices: Array = []
	match policy:
		"low_grade":
			for index in range(enemy.hand.size()):
				if (enemy.hand[index] as QiCard).grade <= 1:
					indices.append(index)
		"high_grade":
			for index in range(enemy.hand.size()):
				if (enemy.hand[index] as QiCard).grade >= 3:
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
	return indices


# ---------- 条件与文案 ----------

# 梯级自况条件与应手武装门：共用条件层求值（键表见 ConditionEvaluator/DataRepo）。
func _conditions_met(conditions: Dictionary, enemy: FighterState) -> bool:
	return ConditionEvaluator.evaluate(conditions, {"unit": enemy})


func _event_text(event: String) -> String:
	return {"player_breathed": "你调息", "guard_broken": "它护境被击碎"}.get(event, event)


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


func _arm_text(arm: Dictionary) -> String:
	if arm.is_empty():
		return "无条件常驻"
	var parts: Array[String] = []
	if arm.has("guard_gte"):
		parts.append("护境≥%d" % int(arm["guard_gte"]))
	if arm.has("hp_gte"):
		parts.append("气血≥%d" % int(arm["hp_gte"]))
	return "且".join(parts)
