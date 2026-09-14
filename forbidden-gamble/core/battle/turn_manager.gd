class_name TurnManager
extends RefCounted

# 行动权流动制（真气语法 v2.2 §5，《真气语法_v2》）：**敌我轮流**——每次原子行动结束后
# 行动权被动流向对面；**被动获得＝补满丹田**（含疲劳路径），**主动夺取＝截牌半路抢回**、
# 不补满、可连链（链内只有截即打，无普通行动）。破绽＝下一次被动获得时跳过该次行动
# （补满照常；主动夺取不受影响）。气竭判负退役：无气可动＝让过一拍，疲劳真伤兜底终局。
# 真气行动两枚：**打出功法**（三张刻/顺成型，沉入副露区）与**架势**（弃 1–4 入自己的
# 牌河＋纳至丹田容量，费一拍不限次）。破绽铸币厂 v3：杠（被杠者）＋压制动词。

const DANTIAN_SIZE := 8         # 玩家丹田容量（占位，待拍板；敌方＝起手张数）
const SWAP_MAX := 4             # 架势一次至多弃 4 张

var combat: CombatState
var rng := RandomNumberGenerator.new()
var messages: Array[String] = []
# 流动挂起：敌方架势后玩家截牌窗开着（弹窗期；普通行动被锁，放行才被动获得）
var awaiting_player_claims := false
# 截牌链冷却钟：链首走一次，链内各段不重复走
var _claim_chain_ticked := false

var enemy_intent: Dictionary:
	get:
		return combat.enemy_brain.intent

func _init(new_combat: CombatState, new_seed: int = 12345) -> void:
	combat = new_combat
	rng.seed = new_seed

# 开战：洗本命与气海 → 玩家从本命洗抽 DANTIAN_SIZE 入丹田（敌方起手 authored）→
# battle_start 时点（先纳功从气海多纳/先机诀被袭击时夺取先手）→ 首拍流动 → 锁敌方意图。
func start_battle(shuffle_decks := true, enemy_first := false) -> void:
	if shuffle_decks:
		_randomize(combat.player.destiny_pile)
		combat.shuffle_wall(rng)
	combat.player.dantian_capacity = DANTIAN_SIZE
	for _index in range(mini(DANTIAN_SIZE, combat.player.destiny_pile.size())):
		combat.player.hand.append(combat.player.destiny_pile.pop_back())
	messages.append("战斗开始。")
	var initial_side := "enemy" if enemy_first else "player"
	if enemy_first:
		messages.append("遭遇偷袭——敌方抢得行动权！")
	combat.active_side = ""
	combat.pipeline.acting_side = ""
	_submit_point("battle_start", null)
	if combat.active_side != "":
		initial_side = combat.active_side  # 先机诀：被袭击时夺取先手
	_flow_to(initial_side)
	_drain_pipeline()
	_lock_enemy_intent()

func is_over() -> bool:
	return not combat.player.is_alive() or not combat.enemy.is_alive()

# ---------- 玩家原子行动（被动拍上；截牌窗挂着时锁普通行动） ----------

func player_act(technique_id: String, cards: Array) -> Dictionary:
	if is_over() or combat.active_side != "player" or awaiting_player_claims:
		return {"ok": false, "reason": "现在不是你的行动机会"}
	combat.player.tick_cooldowns()
	var tech_data := TechniqueResolver.data_for(technique_id)
	# 蓄力起手（跨拍动作）：选入真气移入凝招蓄力，蓄力期间行动权让出充能。
	if int(tech_data.get("charge", 0)) > 0:
		if not TechniqueResolver.can_use(technique_id, cards, combat.player):
			return {"ok": false, "reason": "功法条件不满足"}
		_start_charge(combat.player, technique_id, cards)
		messages.append("你发动%s起手，蓄力 0/%d——蓄力期间行动权让出。" % [technique_id, int(tech_data.get("charge", 0))])
		_end_atomic_action("player", false)
		return {"ok": true, "action": "charge_started", "technique": technique_id}
	var result := TechniqueResolver.resolve(technique_id, cards, combat.player, combat.enemy, combat.pipeline, rng)
	if not bool(result.get("ok", false)):
		return result
	_to_melds(combat.player, cards)
	messages.append("你发动%s：%s" % [technique_id, result.get("effect", "")])
	_apply_cooldown(combat.player, technique_id)
	_end_atomic_action("player", false)
	return result

# 蓄力充能拍：玩家被动获得行动权且有蓄力时由 UI 触发（自动执行，无选择）。
func player_charge_tick() -> Dictionary:
	if is_over() or combat.active_side != "player" or awaiting_player_claims or not combat.player.has_active_charge():
		return {}
	combat.player.tick_cooldowns()
	return _advance_charge("player")

# 架势（真气语法 v2.2 §5）：弃 1–4 张入自己的牌河（公开、为对方开截牌窗）＋纳至丹田容量；
# 费一拍、不限次——限速器＝让权代价＋喂牌风险。
func player_swap(discard_indices: Array) -> Dictionary:
	if is_over() or combat.active_side != "player" or awaiting_player_claims:
		return {"ok": false, "reason": "现在不是你的行动机会"}
	var indices := (discard_indices as Array).duplicate()
	indices.sort()
	var unique: Array = []
	for raw in indices:
		var index := int(raw)
		if index >= 0 and index < combat.player.hand.size() and not unique.has(index):
			unique.append(index)
	if unique.is_empty() or unique.size() > SWAP_MAX:
		return {"ok": false, "reason": "架势须弃 1–%d 张" % SWAP_MAX}
	combat.player.tick_cooldowns()
	var action := GameAction.new("swap", combat.player, combat.player.dantian_capacity, combat.player)
	action.context["rng"] = rng
	action.context["discard_indices"] = unique
	combat.pipeline.submit(action)
	messages.append("你架势：弃 %d 口，纳 %d 口。" % [
		int(action.context.get("discarded_count", 0)), int(action.context.get("drawn_count", 0))])
	_end_atomic_action("player", true)
	return {"ok": true}

# ---------- 玩家截牌（主动夺取：截即打、不补满、可连链） ----------

func player_claim_options() -> Array:
	return combat.claim_options(combat.player)

# 截一张：截完若窗口仍有可截项，UI 继续弹窗（链）；否则流动去敌方。
func player_claim_fire(option: Dictionary) -> Dictionary:
	if not awaiting_player_claims or is_over():
		return {"ok": false, "reason": "现在没有截牌窗"}
	if not _claim_chain_ticked:
		combat.player.tick_cooldowns()
		_claim_chain_ticked = true
	combat.apply_claim_fire(option, rng)
	combat.action_count += 1
	var chain_continues := false
	if not is_over() and not player_claim_options().is_empty():
		chain_continues = true
	else:
		awaiting_player_claims = false
		combat.close_window()
		_flow_to("enemy")
	_drain_pipeline()
	return {"ok": true, "chain_continues": chain_continues}

# 放行：窗口作废（过水不追），被动获得行动权（补满）后正常行动。
func player_release_flow() -> void:
	if not awaiting_player_claims:
		return
	awaiting_player_claims = false
	combat.close_window()
	_flow_to("player")
	_drain_pipeline()

# ---------- 敌方行动（被动拍上执行锁定意图；截牌＝必炸链，主动夺取不补满） ----------

func enemy_act() -> Dictionary:
	if is_over() or combat.active_side != "enemy":
		return {}
	combat.enemy.tick_cooldowns()
	if combat.enemy.has_active_charge():
		return _advance_charge("enemy")
	var result := combat.enemy_brain.execute(combat.enemy, combat.player, combat.pipeline, rng, combat.enemy.dantian_capacity)
	var was_swap := false
	match str(result.get("action", "")):
		"swap":
			was_swap = true
			messages.append("敌方架势：弃 %d 口，纳 %d 口。" % [
				int(result.get("discarded", 0)), int(result.get("drawn", 0))])
		"charge_start":
			_start_charge(combat.enemy, str(result.get("technique", "")), result.get("cards", []))
			messages.append("敌方发动%s起手，蓄力 0/%d——蓄力期间引而不发。" % [
				str(result.get("technique", "")), int(TechniqueResolver.data_for(str(result.get("technique", ""))).get("charge", 0))])
		"technique":
			_to_melds(combat.enemy, result.get("discarded", []))
			_apply_cooldown(combat.enemy, str(result.get("technique", "")))
			messages.append("敌方发动%s：%s" % [str(result.get("technique", "")), result.get("effect", "")])
		_:
			messages.append("敌方招式落空，暂让一拍。")
	_end_atomic_action("enemy", was_swap)
	return result

# 敌方同构必截（其主动夺取：不补满；杠＞碰＞吃、入河序；能截必截零评估）。
# 玩家架势后流动挂着时同步执行；返回是否截过（截过＝敌方以此链占掉它的拍）。
func _enemy_claim_chain() -> bool:
	var claimed := false
	while not is_over():
		var option := combat.first_claim_for(combat.enemy)
		if option.is_empty():
			break
		if not _claim_chain_ticked:
			combat.enemy.tick_cooldowns()
			_claim_chain_ticked = true
		combat.apply_claim_fire(option, rng)
		combat.action_count += 1
		claimed = true
	return claimed

# ---------- 原子行动收尾（流动制的枢纽） ----------

# 行动权流向：玩家行动后 → 敌方截链（若其架势喂了窗）→ 敌方被动获得（或玩家被截链
# 反客为主后继续）；敌方行动后 → 玩家截牌窗（弹窗挂起）或直接被动获得。
func _end_atomic_action(side: String, was_swap: bool) -> void:
	combat.action_count += 1
	if is_over():
		return
	if side == "player":
		if was_swap:
			var enemy_claimed := _enemy_claim_chain()
			if is_over():
				return
			combat.close_window()  # 敌方过水即死（能截必截，剩余批不可再截）
			if enemy_claimed:
				_lock_enemy_intent()
				_flow_to("player")  # 敌方以截链占拍：流动回到玩家
			else:
				_flow_to("enemy")
		else:
			_flow_to("enemy")
	else:
		combat.enemy_brain.after_execute(combat.enemy)
		_lock_enemy_intent()
		if was_swap and not player_claim_options().is_empty():
			# 玩家截牌窗：流动挂起——截（主动，不补满）或放行（被动，补满后行动）
			awaiting_player_claims = true
			combat.active_side = "player"
			combat.pipeline.acting_side = "player"
		else:
			if was_swap:
				combat.close_window()
			_flow_to("player")
	_drain_pipeline()

# 行动权流动（被动获得，§5）：破绽跳拍（补满照常）→ 补满（含疲劳路径）→ 落定为行动方；
# 无气可动＝让过一拍继续流（疲劳兜底，死局不可能）。
func _flow_to(target_side: String) -> void:
	var side := target_side
	while not is_over():
		var unit := combat.unit_for(side)
		if unit.flawed:
			unit.flawed = false
			messages.append("%s露出破绽，错失一拍。" % unit.display_name)
			_refill(unit)
			side = combat.other_side(side)
			continue
		_refill(unit)
		combat.active_side = side
		combat.pipeline.acting_side = side
		_submit_point("initiative_gain", combat.unit_for(side))
		if not unit.has_legal_action():
			messages.append("%s无气可动，让过一拍。" % unit.display_name)
			side = combat.other_side(side)
			continue
		break
	_claim_chain_ticked = false

# 补满＝吐纳气海至丹田容量（气海干涸时走牌河＋疲劳路径）。
func _refill(unit: FighterState) -> void:
	var deficit := maxi(unit.dantian_capacity - unit.hand.size(), 0)
	if deficit > 0:
		combat.draw_cards(unit, deficit, rng)

# ---------- 蓄力（跨拍动作；轮到蓄力方＝自动充能一拍） ----------

# 起手：选入真气移入凝招（沉入副露延迟到发动；蓄力锁＝起蓄不可换功法/截牌，双方同规）。
func _start_charge(unit: FighterState, technique_id: String, cards: Array) -> void:
	var data := TechniqueResolver.data_for(technique_id)
	for card in cards:
		unit.hand.erase(card)
	unit.charging = {
		"technique": technique_id,
		"charge": 0,
		"need": int(data.get("charge", 0)),
		"cards": cards.duplicate(),
	}

# 充能拍：+1；未满 → 流动让权；满 → 立即发动（随后照常流动）。
func _advance_charge(side: String) -> Dictionary:
	var unit := combat.unit_for(side)
	var who := "你" if side == "player" else "敌方"
	var need := int(unit.charging.get("need", 0))
	var charge := int(unit.charging.get("charge", 0)) + 1
	unit.charging["charge"] = charge
	var technique_id := str(unit.charging.get("technique", ""))
	if charge < need:
		messages.append("%s的%s蓄力 %d/%d，引而不发。" % [who, technique_id, charge, need])
		_end_atomic_action(side, false)
		_drain_pipeline()
		return {"ok": true, "action": "charge_tick", "technique": technique_id}
	return _fire_charge(side)

# 蓄力满值发动：清空蓄力态再结算（can_use 门控拦蓄力态），真气沉入副露，冷却自此刻起算。
func _fire_charge(side: String) -> Dictionary:
	var unit := combat.unit_for(side)
	var who := "你" if side == "player" else "敌方"
	var technique_id := str(unit.charging.get("technique", ""))
	var cards: Array = unit.charging.get("cards", [])
	unit.charging = {}
	var result := TechniqueResolver.resolve(technique_id, cards, unit, combat.opponent_for(side), combat.pipeline, rng, true)
	if not bool(result.get("ok", false)):
		messages.append("%s的蓄力落空（条件失效），真气尽散。" % who)
		_end_atomic_action(side, false)
		_drain_pipeline()
		return result
	_to_melds(unit, cards)
	_apply_cooldown(unit, technique_id)
	result["action"] = "technique"
	messages.append("%s蓄力已满，轰然发动%s：%s" % [who, technique_id, result.get("effect", "")])
	_end_atomic_action(side, false)
	_drain_pipeline()
	return result

# ---------- 冷却 ----------

func _apply_cooldown(unit: FighterState, technique_id: String) -> void:
	var cd := int(TechniqueResolver.data_for(technique_id).get("cooldown", 0))
	if cd > 0:
		unit.technique_cooldowns[technique_id] = cd

# ---------- 杂项 ----------

func _other_side(side: String) -> String:
	return combat.other_side(side)

func _submit_point(action_type: String, target) -> void:
	var action := GameAction.new(action_type, target, 0, target)
	action.context["rng"] = rng
	combat.pipeline.submit(action)

func _randomize(cards: Array) -> void:
	for index in range(cards.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary = cards[index]
		cards[index] = cards[swap_index]
		cards[swap_index] = temporary

func drain_messages() -> Array[String]:
	var drained: Array[String] = []
	drained.assign(messages)
	messages.clear()
	return drained

func _drain_pipeline() -> void:
	messages.append_array(combat.pipeline.drain_events())

func _lock_enemy_intent() -> void:
	combat.enemy_brain.lock_intent(combat.enemy)

# 功法打出的牌沉入副露区（公开、锁死、不可截）。
func _to_melds(unit: FighterState, cards: Array) -> void:
	for card in cards:
		unit.hand.erase(card)
	if not cards.is_empty():
		unit.melds.append(cards)
