class_name TurnManager
extends RefCounted

# 行动权判定制：行动权是标记，每次原子行动结束后重新判定归属——首拍玩家优先
# （被袭击反转；先机诀经 seize 抢先），后续非前一个行动者优先；逐候选查破绽
# （有则消耗、跳过、查下一位），循环直到落定。
# 破绽唯一效果＝跳过下次获得行动权（不叠加、即查即耗）；铸币厂仅两处——钩子转换
# （敌方脑 乱/应）与压制动词。破盾＝纯物理（敌方系统 v2 修订）。
# 敌方＝对手卡（同核身体＋EnemyBrain 行为链梯与钩子）：行动只有发动功法与调息，
# 与玩家同构（玩家将来多一种道具）。意图＝即将进行的行动，锁意图只在敌方行动后；
# 玩家行动不重锁（只能经钩子翻牌，翻牌即演出）。

const HAND_SIZE := 6           # §9 拍板 #7：测试起点 6（配置化，数值进《10》再调）

var combat: CombatState
var rng := RandomNumberGenerator.new()
var messages: Array[String] = []
# 破绽停拍（演出侧信号）：判定每消耗一个破绽＋1；BattleSequencer 据此在把控制权
# 还给玩家前多停一拍，让"对方踉跄错失"被看清。核心判定不读它——纯表现层计数。
var pending_skip_beats := 0

# 意图＝敌方脑当前锁定的行动（活读数：钩子翻牌时实时变化，展示层永不滞后）。
var enemy_intent: Dictionary:
	get:
		return combat.enemy_brain.intent

var _last_actor_side := ""

func _init(new_combat: CombatState, new_seed: int = 12345) -> void:
	combat = new_combat
	rng.seed = new_seed

# 开战：洗双方牌库 → 玩家纳 HAND_SIZE 口（敌方起手手牌 authored，不重抽）→
# battle_start 时点（先机诀夺取可能直接设定 active_side）→ 首拍判定 →
# 锁定敌方意图＋应手武装初评。
func start_battle(shuffle_decks := true, enemy_first := false) -> void:
	pending_skip_beats = 0
	if shuffle_decks:
		combat.shuffle_draw_pile(combat.player, rng)
		combat.shuffle_draw_pile(combat.enemy, rng)
	combat.draw_cards(combat.player, HAND_SIZE, rng)
	messages.append("战斗开始。")
	var initial_side := "enemy" if enemy_first else "player"
	if enemy_first:
		messages.append("遭遇偷袭——敌方抢得行动权！")
	combat.active_side = ""
	combat.pipeline.acting_side = ""
	_submit_point("battle_start", null)
	# battle_start 钩子里可能有夺取（先机诀）：夺取结算器已给夺取方发过 gain，
	# 只在未被夺取时做首拍判定，避免双发。
	if combat.active_side == "":
		_determine_initiative(initial_side)
	_drain_pipeline()
	_lock_enemy_intent()
	combat.enemy_brain.evaluate_arms(combat.enemy)

func is_over() -> bool:
	return not combat.player.is_alive() or not combat.enemy.is_alive()

# ---------- 玩家原子行动 ----------

func player_act(technique_id: String, cards: Array) -> Dictionary:
	if is_over() or combat.active_side != "player":
		return {"ok": false, "reason": "现在不是你的行动机会"}
	combat.player.tick_cooldowns()
	var tech_data := TechniqueResolver.data_for(technique_id)
	# 蓄力起手（跨拍动作）：不立即结算——选入真气（＋自动喂气）移入凝招蓄力，
	# 蓄力期间行动机会自动让权充能，满值自动发动。蓄势期间护盾被击碎＝蓄力整体销毁。
	if int(tech_data.get("charge", 0)) > 0:
		if not TechniqueResolver.can_use(technique_id, cards, combat.player):
			return {"ok": false, "reason": "功法条件不满足"}
		_start_charge(combat.player, technique_id, cards)
		messages.append("你发动%s起手，蓄力 0/%d——蓄力期间行动权让出。" % [technique_id, int(tech_data.get("charge", 0))])
		_finish_action("player")
		_drain_pipeline()
		return {"ok": true, "action": "charge_started", "technique": technique_id}
	var result := TechniqueResolver.resolve(technique_id, cards, combat.player, combat.enemy, combat.pipeline, rng)
	if not bool(result.get("ok", false)):
		return result
	_consume_cards(combat.player, cards, result)
	messages.append("你发动%s：%s" % [technique_id, result.get("effect", "")])
	_apply_cooldown(combat.player, technique_id)
	_finish_action("player")
	_drain_pipeline()
	return result

# 蓄力充能拍：玩家持有行动权且有蓄力时由 UI 触发（自动执行，无选择）。
func player_charge_tick() -> Dictionary:
	if is_over() or combat.active_side != "player" or not combat.player.has_active_charge():
		return {}
	combat.player.tick_cooldowns()
	return _advance_charge("player")

# 调息（B2，v1.4 §4）：弃所选任意张（0～全部）入气海，从丹田纳至 HAND_SIZE 口；
# 费一拍、不限次——限速器＝让权代价（敌方走一步剧本＋力量软钟），不用次数条定价。
# discard_indices：null（缺省）＝弃全部（旧语义兼容）；数组（含空）＝按索引弃，空数组＝只补不弃。
func player_breathe(discard_indices = null) -> void:
	if is_over() or combat.active_side != "player":
		return
	combat.player.tick_cooldowns()
	var action := GameAction.new("breath", combat.player, HAND_SIZE, combat.player)
	action.context["rng"] = rng
	if discard_indices != null:
		action.context["discard_indices"] = (discard_indices as Array).duplicate()
	combat.pipeline.submit(action)
	messages.append("你调匀气息：弃 %d 口，纳 %d 口。" % [
		int(action.context.get("discarded_count", 0)), int(action.context.get("drawn_count", 0))])
	_finish_action("player")
	_drain_pipeline()

# ---------- 敌方行动（对手卡执行：发动功法 / 调息，与玩家同构） ----------

# 执行一次敌方行动：行动钟结算（功法/心法冷却＋钩子冷却）→ 蓄力占用则充能/发动 →
# 否则执行脑锁定的意图（功法走同一管线、调息走策略弃牌）→ 收尾记账（冷却置满、
# 乱的后坐破绽入账、应手武装重估）→ 判定 → 重锁意图。
func enemy_act() -> Dictionary:
	if is_over() or combat.active_side != "enemy":
		return {}
	combat.enemy.tick_cooldowns()
	combat.enemy_brain.tick_action_clocks()
	var result := {}
	if combat.enemy.has_active_charge():
		result = _advance_charge("enemy")
		_drain_pipeline()
		return result
	result = combat.enemy_brain.execute(combat.enemy, combat.player, combat.pipeline, rng, HAND_SIZE)
	match str(result.get("action", "")):
		"breathe":
			messages.append("敌方调息：弃 %d 口，纳 %d 口。" % [
				int(result.get("discarded", 0)), int(result.get("drawn", 0))])
			combat.enemy_brain.after_execute(combat.enemy)
		"charge_start":
			_start_charge(combat.enemy, str(result.get("technique", "")), result.get("cards", []))
			messages.append("敌方发动%s起手，蓄力 0/%d——蓄力期间引而不发。" % [
				str(result.get("technique", "")), int(TechniqueResolver.data_for(str(result.get("technique", ""))).get("charge", 0))])
			combat.enemy_brain.after_execute(combat.enemy)
		"technique":
			_apply_cooldown(combat.enemy, str(result.get("technique", "")))
			messages.append("敌方发动%s：%s" % [str(result.get("technique", "")), result.get("effect", "")])
			combat.enemy_brain.after_execute(combat.enemy)
		_:
			messages.append("敌方招式落空，暂让一拍。")
			combat.enemy_brain.after_execute(combat.enemy)
	_finish_action("enemy")
	_drain_pipeline()
	return result

# ---------- 蓄力（跨拍动作，敌方系统 v1 §2.5） ----------

# 起手：选入真气移入凝招；charge_feed 个品级最高的真气自动喂入（v1 自动化口径）。
func _start_charge(unit: FighterState, technique_id: String, cards: Array) -> void:
	var data := TechniqueResolver.data_for(technique_id)
	var stored: Array = cards.duplicate()
	for card in cards:
		unit.hand.erase(card)
	var feed := int(data.get("charge_feed", 0))
	if feed > 0 and not unit.hand.is_empty():
		var rest: Array = unit.hand.duplicate()
		rest.sort_custom(func(a, b): return a.grade > b.grade)
		for index in range(mini(feed, rest.size())):
			unit.hand.erase(rest[index])
			stored.append(rest[index])
	unit.charging = {
		"technique": technique_id,
		"charge": 0,
		"need": int(data.get("charge", 0)),
		"cards": stored,
	}

# 充能拍：+1；未满 → 判定（让权）；满 → 立即发动（随后照常判定）。
func _advance_charge(side: String) -> Dictionary:
	var unit := combat.unit_for(side)
	var who := "你" if side == "player" else "敌方"
	var need := int(unit.charging.get("need", 0))
	var charge := int(unit.charging.get("charge", 0)) + 1
	unit.charging["charge"] = charge
	var technique_id := str(unit.charging.get("technique", ""))
	if charge < need:
		messages.append("%s的%s蓄力 %d/%d，引而不发。" % [who, technique_id, charge, need])
		_finish_action(side)
		_drain_pipeline()
		return {"ok": true, "action": "charge_tick", "technique": technique_id}
	return _fire_charge(side)

# 蓄力满值发动：清空蓄力态再结算（can_use 门控拦蓄力态），真气散入气海，冷却自此刻起算。
func _fire_charge(side: String) -> Dictionary:
	var unit := combat.unit_for(side)
	var who := "你" if side == "player" else "敌方"
	var technique_id := str(unit.charging.get("technique", ""))
	var cards: Array = unit.charging.get("cards", [])
	unit.charging = {}
	var result := TechniqueResolver.resolve(technique_id, cards, unit, combat.opponent_for(side), combat.pipeline, rng, true)
	if not bool(result.get("ok", false)):
		unit.discard_pile.append_array(cards)
		messages.append("%s的蓄力落空（条件失效），真气尽散。" % who)
		_finish_action(side)
		_drain_pipeline()
		return result
	unit.discard_pile.append_array(result.discarded)
	_apply_cooldown(unit, technique_id)
	result["action"] = "technique"
	messages.append("%s蓄力已满，轰然发动%s：%s" % [who, technique_id, result.get("effect", "")])
	_finish_action(side)
	_drain_pipeline()
	return result

# ---------- 冷却 ----------

# 发动后写入剩余次数；递减在各原子行动开始（tick_cooldowns）。
func _apply_cooldown(unit: FighterState, technique_id: String) -> void:
	var cd := int(TechniqueResolver.data_for(technique_id).get("cooldown", 0))
	if cd > 0:
		unit.technique_cooldowns[technique_id] = cd

# ---------- 行动权判定 ----------

# 原子行动收尾：记录前手 → 判定行动权（非前手优先、逐候选查破绽）。
# 意图重锁只在敌方行动后（锁意图＝它行动之后的时点）；玩家行动不重锁——
# 意图是活读数，玩家行动只能经钩子翻牌（翻牌即演出），不存在静默不一致。
func _finish_action(side: String) -> void:
	combat.action_count += 1
	if is_over():
		return
	_last_actor_side = side
	_determine_initiative(_other_side(side))
	if side == "enemy":
		_lock_enemy_intent()

# 判定行动权归属：候选按优先级排列（first_candidate 优先），逐候选查破绽
# （消耗＋跳过查下一位），循环直到落定——双破绽时两候选各烧一个后回到队首，
# 必然终止、结果唯一。落定后向持有方发 initiative_gain 时点。
func _determine_initiative(first_candidate: String) -> void:
	var assigned := ""
	while assigned.is_empty():
		for side in [first_candidate, _other_side(first_candidate)]:
			var unit: FighterState = combat.unit_for(side)
			if unit.flawed:
				unit.flawed = false
				messages.append("%s露出破绽，错失一拍。" % unit.display_name)
				pending_skip_beats += 1
				continue
			assigned = side
			break
	combat.active_side = assigned
	combat.pipeline.acting_side = assigned
	_submit_point("initiative_gain", combat.unit_for(assigned))

func _other_side(side: String) -> String:
	return "enemy" if side == "player" else "player"

func _submit_point(action_type: String, target) -> void:
	var action := GameAction.new(action_type, target, 0, target)
	action.context["rng"] = rng
	combat.pipeline.submit(action)

# UI 取走自上次以来的全部事件文本。
func drain_messages() -> Array[String]:
	var drained: Array[String] = []
	drained.assign(messages)
	messages.clear()
	return drained

# 管线事件（毒发、心法词条、破盾等）并入战斗消息流。
func _drain_pipeline() -> void:
	messages.append_array(combat.pipeline.drain_events())

# 意图＝脑锁定的即将行动（敌方系统 v2：功法或调息；蓄力期间显示蓄力招）。
func _lock_enemy_intent() -> void:
	combat.enemy_brain.lock_intent(combat.enemy)

func _consume_cards(unit: FighterState, cards: Array, result: Dictionary) -> void:
	for card in cards:
		unit.hand.erase(card)
	unit.discard_pile.append_array(result.discarded)
