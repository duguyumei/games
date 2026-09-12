class_name TurnManager
extends RefCounted

# 行动权模型（26 号 §11 定稿块，D-063 换轴）：行动权是唯一时序令牌——无先手/后手、
# 无大回合、无收势，只有"现在谁持有行动权"。原子行动（发动功法/用道具/调息/提气；
# 截劲随拆招系统后置）全部默认结束即转让；例外只能来自词条（压制），且必须公开
# 标记（宪法第 6 条——initiative_release 的 PRE 钩子置 retain 即压制；调息/提气后
# 不可保留：调息永远是链条终点，提气让了又不让是矛盾表述）。
# 调息＝吐故纳新：弃全部手牌入气海、从丹田纳 HAND_SIZE 张（气持有即保留，不再自动
# 回收——C-015 口径承接）；世界钟（D-058 未实现）将来挂 breath 点位，每次调息 −1。
# 提气（原暂让）：这一拍不动、交权、从丹田提 1 张；每口气限 1 次，调息时重置（敌我同限）。
# 僵局保险：连续无功法动作（提气＋调息）累计到上限 → 平局，视同败北。
# 词条族（26 号 §5）：蓄力 N＝占自身行动机会充能、满值自动发（起手喂气 v1 自动取
# 品级最高）；压制＝行动权不转让（引擎 retain 钩子，冷却定价重复）；冷却 N＝后续
# N 次自己的原子行动内不可再发动（行动开始时递减）。

const HAND_SIZE := 6           # §9 拍板 #7：测试起点 6（配置化，数值进《10》再调）
const MAX_IDLE_ACTIONS := 12   # 僵局保险上限（双方暂让/调息合计，占位进《10》）

var combat: CombatState
var rng := RandomNumberGenerator.new()
var enemy_intent: Dictionary = {}
var battle_stalled := false
var messages: Array[String] = []

var _idle_actions := 0

func _init(new_combat: CombatState, new_seed: int = 12345) -> void:
	combat = new_combat
	rng.seed = new_seed
	combat.pipeline.register_hook({
		"carrier": "engine:retain",
		"on": "initiative_transfer",
		"phase": "pre",
		"priority": -100,
		"handler": _retain_hook,
	})

# 引擎压制钩子：功法带"压制"词条时，移交动作在 PRE 被引擎取消（行动权保留）。
# 与心法类保留词条同一条通路（PRE 取消 initiative_transfer），宪法第 6 条的公开标记
# 由意图/战报文案承担（"压制·行动权未让"）。
func _retain_hook(action: GameAction) -> void:
	if bool(action.context.get("retain", false)):
		action.cancelled = true

# 开战：洗牌 → 双方起手各纳 HAND_SIZE 口（调息口径的免费首纳，不占行动）→
# 定第一次行动权归属（默认玩家；被袭击＝敌方，C-028 语义改述）→ battle_start 与
# initiative_gain 两个时点 → 锁定敌方意图（§11.6：战斗开始即锁）。
func start_battle(shuffle_decks := true, enemy_first := false) -> void:
	if shuffle_decks:
		combat.shuffle_draw_pile(combat.player, rng)
		combat.shuffle_draw_pile(combat.enemy, rng)
	combat.draw_cards(combat.player, HAND_SIZE, rng)
	combat.draw_cards(combat.enemy, HAND_SIZE, rng)
	messages.append("战斗开始。")
	var initial_side := "enemy" if enemy_first else "player"
	combat.active_side = initial_side
	combat.pipeline.acting_side = initial_side
	if enemy_first:
		messages.append("遭遇偷袭——敌方抢得行动权！")
	_submit_point("battle_start", null)
	# battle_start 钩子里可能有夺取（先机诀）：夺取结算器已给夺取方发过 gain，
	# 只对"未被夺走"的初始持有方补发，避免双发。
	if combat.active_side == initial_side:
		_submit_point("initiative_gain", combat.unit_for(combat.active_side))
	_drain_pipeline()
	_lock_enemy_intent()

func is_over() -> bool:
	return battle_stalled or not combat.player.is_alive() or not combat.enemy.is_alive()

# ---------- 玩家原子行动 ----------

func player_act(technique_id: String, cards: Array) -> Dictionary:
	if is_over() or combat.active_side != "player":
		return {"ok": false, "reason": "现在不是你的行动机会"}
	combat.player.tick_cooldowns()
	var tech_data := TechniqueResolver.data_for(technique_id)
	# 蓄力起手（26 号 §5）：不立即结算——选入真气（＋自动喂气）移入凝招蓄力，
	# 蓄力期间行动机会自动让权充能，满值自动发动。曝光＝对方获得 N 次自由行动。
	if int(tech_data.get("charge", 0)) > 0:
		if not TechniqueResolver.can_use(technique_id, cards, combat.player):
			return {"ok": false, "reason": "功法条件不满足"}
		_start_charge(combat.player, technique_id, cards)
		messages.append("你发动%s起手，蓄力 0/%d——蓄力期间行动权让出。" % [technique_id, int(tech_data.get("charge", 0))])
		_finish_action("player", true)
		_drain_pipeline()
		return {"ok": true, "action": "charge_started", "technique": technique_id}
	var result := TechniqueResolver.resolve(technique_id, cards, combat.player, combat.enemy, combat.pipeline, rng)
	if not bool(result.get("ok", false)):
		return result
	_consume_cards(combat.player, cards, result)
	messages.append("你发动%s：%s" % [technique_id, result.get("effect", "")])
	_apply_cooldown(combat.player, technique_id)
	_finish_action("player", true, _has_tag(tech_data, "压制"))
	_drain_pipeline()
	return result

# 蓄力充能拍：玩家持有行动权且有蓄力时由 UI 触发（自动执行，无选择）。
func player_charge_tick() -> Dictionary:
	if is_over() or combat.active_side != "player" or not combat.player.has_active_charge():
		return {}
	combat.player.tick_cooldowns()
	return _advance_charge("player")

# 调息（吐故纳新）：弃全部手牌入气海，从丹田纳 HAND_SIZE 口。立即转让行动权。
func player_breathe() -> void:
	if is_over() or combat.active_side != "player":
		return
	combat.player.tick_cooldowns()
	var action := GameAction.new("breath", combat.player, HAND_SIZE, combat.player)
	action.context["rng"] = rng
	combat.pipeline.submit(action)
	messages.append("你调匀气息，吐故纳新。")
	_finish_action("player", false)
	_drain_pipeline()

# 提气（原暂让）：这一拍不动、交权、从丹田提 1 张；每口气限 1 次＋心法加成，调息时重置。
# 提交后再计数——lift_qi 的 PRE 钩子（长息诀"首次提气提 2"）要读到本口气已提 0 次。
func player_lift() -> void:
	if is_over() or combat.active_side != "player":
		return
	if combat.player.lifts_this_breath >= 1 + combat.player.lift_allowance:
		return
	combat.player.tick_cooldowns()
	var action := GameAction.new("lift_qi", combat.player, 1, combat.player)
	action.context["rng"] = rng
	combat.pipeline.submit(action)
	combat.player.lifts_this_breath += 1
	messages.append("你提气一口，让出行动权。")
	_finish_action("player", false)
	_drain_pipeline()

# ---------- 敌方行动（已锁定的意图） ----------

# 执行一次敌方行动。意图因故失效时按暂让处理，避免卡死。
func enemy_act() -> Dictionary:
	if is_over() or combat.active_side != "enemy":
		return {}
	combat.enemy.tick_cooldowns()
	# 蓄力占用敌方的行动机会：充能拍/满值自动发动，不走意图选择
	if combat.enemy.has_active_charge():
		return _advance_charge("enemy")
	var intent_action := str(enemy_intent.get("action", ""))
	var technique_id := str(enemy_intent.get("technique", ""))
	var cards: Array = enemy_intent.get("cards", [])
	if intent_action == "breathe":
		var breathe := GameAction.new("breath", combat.enemy, HAND_SIZE, combat.enemy)
		breathe.context["rng"] = rng
		combat.pipeline.submit(breathe)
		messages.append("敌方调匀气息。")
		_finish_action("enemy", false)
		_drain_pipeline()
		return {"ok": true, "action": "breathe"}
	if intent_action == "lift_qi":
		return _lift_for_enemy()
	if technique_id == "" or technique_id == "PASS" or cards.is_empty():
		_idle_for_enemy()
		return {"ok": true, "action": "pass"}
	var tech_data := TechniqueResolver.data_for(technique_id)
	# 敌方蓄力起手：同玩家规则（D-006 敌我共用底层）——蓄力态全公开（意图显示 X/N）
	if int(tech_data.get("charge", 0)) > 0:
		_start_charge(combat.enemy, technique_id, cards)
		messages.append("敌方发动%s起手，蓄力 0/%d！" % [technique_id, int(tech_data.get("charge", 0))])
		_finish_action("enemy", true)
		_drain_pipeline()
		return {"ok": true, "action": "charge_started", "technique": technique_id}
	var result := TechniqueResolver.resolve(technique_id, cards, combat.enemy, combat.player, combat.pipeline, rng)
	if not bool(result.get("ok", false)):
		messages.append("敌方意图失效，改为提气。")
		_idle_for_enemy()
		return result
	_consume_cards(combat.enemy, cards, result)
	messages.append("敌方发动%s：%s" % [technique_id, result.get("effect", "")])
	_apply_cooldown(combat.enemy, technique_id)
	_finish_action("enemy", true, _has_tag(tech_data, "压制"))
	_drain_pipeline()
	return result

# 敌方执行提气意图（已在锁定时确认可提；此处再防一手限次）。
func _lift_for_enemy() -> Dictionary:
	if combat.enemy.lifts_this_breath >= 1 + combat.enemy.lift_allowance:
		_idle_for_enemy()
		return {"ok": true, "action": "pass"}
	var action := GameAction.new("lift_qi", combat.enemy, 1, combat.enemy)
	action.context["rng"] = rng
	combat.pipeline.submit(action)
	combat.enemy.lifts_this_breath += 1
	messages.append("敌方提气一口，让出行动权。")
	_finish_action("enemy", false)
	_drain_pipeline()
	return {"ok": true, "action": "lift_qi"}

# 敌方无功法可用的兜底拍：可提则提气，有牌可循环则调息，三堆全空才纯过牌（防卡死）。
func _idle_for_enemy() -> void:
	if combat.enemy.lifts_this_breath < 1 + combat.enemy.lift_allowance \
			and not (combat.enemy.draw_pile.is_empty() and combat.enemy.discard_pile.is_empty()):
		_lift_for_enemy()
		return
	if not (combat.enemy.draw_pile.is_empty() and combat.enemy.discard_pile.is_empty() and combat.enemy.hand.is_empty()):
		var breathe := GameAction.new("breath", combat.enemy, HAND_SIZE, combat.enemy)
		breathe.context["rng"] = rng
		combat.pipeline.submit(breathe)
		messages.append("敌方调匀气息。")
		_finish_action("enemy", false)
		_drain_pipeline()
		return
	messages.append("敌方暂让。")
	_finish_action("enemy", false)
	_drain_pipeline()

# ---------- 蓄力（26 号 §5 词条） ----------

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

# 充能拍：+1；未满 → 让权；满 → 立即发动（随后照常让权）。
func _advance_charge(side: String) -> Dictionary:
	var unit := combat.unit_for(side)
	var who := "你" if side == "player" else "敌方"
	var need := int(unit.charging.get("need", 0))
	var charge := int(unit.charging.get("charge", 0)) + 1
	unit.charging["charge"] = charge
	var technique_id := str(unit.charging.get("technique", ""))
	if charge < need:
		messages.append("%s的%s蓄力 %d/%d，引而不发。" % [who, technique_id, charge, need])
		_finish_action(side, false)
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
		_finish_action(side, false)
		_drain_pipeline()
		return result
	unit.discard_pile.append_array(result.discarded)
	_apply_cooldown(unit, technique_id)
	result["action"] = "technique"
	messages.append("%s蓄力已满，轰然发动%s：%s" % [who, technique_id, result.get("effect", "")])
	_finish_action(side, true)
	_drain_pipeline()
	return result

# ---------- 冷却（26 号 §3.2） ----------

# 发动后写入剩余次数；递减在各原子行动开始（tick_cooldowns）。
func _apply_cooldown(unit: FighterState, technique_id: String) -> void:
	var cd := int(TechniqueResolver.data_for(technique_id).get("cooldown", 0))
	if cd > 0:
		unit.technique_cooldowns[technique_id] = cd

func _has_tag(tech_data: Dictionary, tag: String) -> bool:
	return (tech_data.get("tags", []) as Array).has(tag)

# ---------- 行动权流转 ----------

# 原子行动收尾：僵局判定 → idle 计数 → 行动权移交（D-064：移交是实际动作 initiative_transfer，
# PRE 钩子取消它＝压制保留，仅功法类行动有效；调息/提气后引擎强制移交——铁律"调息永远是
# 链条终点"）。敌方行动结算后重新锁定意图（§11.6）。
# retain＝本次功法带"压制"词条：移交动作带 retain 标记，引擎 PRE 钩子取消＝行动权保留。
func _finish_action(side: String, used_technique: bool, retain := false) -> void:
	combat.action_count += 1
	if used_technique:
		_idle_actions = 0
	else:
		_idle_actions += 1
		if _idle_actions >= MAX_IDLE_ACTIONS:
			battle_stalled = true
			messages.append("双方僵持不下，各自收手（平局）。")
			return
	if is_over():
		return
	if side == "enemy":
		_lock_enemy_intent()
	if not _transfer_initiative(side, used_technique, retain):
		# 压制：移交动作被取消，持有方再动一拍。敌方意图不受玩家行动影响（D-025），不重锁。
		messages.append("%s压制得手，行动权未让。" % ("你" if side == "player" else "敌方"))
		return

# 行动权移交＝提交 initiative_transfer 动作（结算器按 target 指派并给新持有方发 gain；
# PRE 可取消＝保留、可改写 target＝改道）。取消仅在功法类行动后有效；调息/提气后的取消
# 被引擎驳回并强制移交。返回 false＝行动权被保留（压制）。
func _transfer_initiative(from_side: String, used_technique: bool, retain := false) -> bool:
	var next_unit := combat.opponent_for(from_side)
	var transfer := GameAction.new("initiative_transfer", next_unit, 0, combat.unit_for(from_side))
	transfer.context["kind"] = "technique" if used_technique else "idle"
	transfer.context["retain"] = retain and used_technique
	transfer.context["rng"] = rng
	combat.pipeline.submit(transfer)
	if not transfer.cancelled:
		return true
	if str(transfer.context.get("kind", "technique")) == "technique":
		return false
	# 铁律覆盖：调息/提气后的移交不可被取消——结算器被拦就手动强制指派
	combat.active_side = "enemy" if from_side == "player" else "player"
	combat.pipeline.acting_side = combat.active_side
	messages.append("调息与提气之后，行动权必让。")
	_submit_point("initiative_gain", combat.unit_for(combat.active_side))
	return true

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

# 管线事件（毒发、心法词条等）并入战斗消息流。
func _drain_pipeline() -> void:
	messages.append_array(combat.pipeline.drain_events())

# 意图＝敌方下一次主动行动。蓄力期间意图固定为蓄力态（X/N 倒计时，26 号 §11.4）。
func _lock_enemy_intent() -> void:
	if combat.enemy.has_active_charge():
		enemy_intent = {
			"action": "charging",
			"technique": str(combat.enemy.charging.get("technique", "")),
			"charge": int(combat.enemy.charging.get("charge", 0)),
			"need": int(combat.enemy.charging.get("need", 0)),
		}
		return
	enemy_intent = EnemyPolicy.choose_action(combat.enemy)

func _consume_cards(unit: FighterState, cards: Array, result: Dictionary) -> void:
	for card in cards:
		unit.hand.erase(card)
	unit.discard_pile.append_array(result.discarded)
