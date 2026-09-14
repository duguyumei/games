extends GutTest

# 敌方脑（真气语法 v2.2）：行为链梯（条件→账面三张成型→隔N）、架势地板与策略、
# 意图锁定时序、应读数（实时活算：手牌搭子＋功法冷却；蓄力中全哑）。
# 截牌钩子系统已退役（2026-09-15）——同构必截的行为验证在 test_turn_manager。

const LADDER_DEF := {
	"swap_policy": "all",
	"hand": [
		{"attribute": "山", "value": 4}, {"attribute": "山", "value": 4}, {"attribute": "山", "value": 4},
	],
	"deck": {"风": {"3": 2, "4": 2}},
	"ladder": [
		{"technique": "重盾式", "when": {"guard_lt": 3}},
		{"technique": "磨刃式", "cooldown": 1},
		{"technique": "架势"},
	],
}

const BROKE_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "风", "value": 3}, {"attribute": "火", "value": 6}],
	"deck": {"风": {"3": 2, "4": 2}},
	"ladder": [{"technique": "重盾式", "when": {"guard_lt": 3}}, {"technique": "架势"}],
}

# 应读数卡：崩山式＋起手两张山4 → "碰山4" 是明码雷区
const THREAT_DEF := {
	"swap_policy": "all",
	"hand": [
		{"attribute": "山", "value": 4}, {"attribute": "山", "value": 4},
		{"attribute": "风", "value": 3}, {"attribute": "风", "value": 5},
	],
	"deck": {"风": {"3": 2}},
	"ladder": [{"technique": "崩山式"}, {"technique": "点星式"}, {"technique": "架势"}],
}

func _card(attr: String, value := 3) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, value, randi()], attr, value)

func _player() -> FighterState:
	var fighter := FighterState.new("p", "独行武者", 40)
	fighter.techniques.assign(["崩山式", "点星式"])
	# 倒序写（尾部先抽入丹田）：丹田前三是山4 刻子
	fighter.destiny_pile = [
		_card("火", 2), _card("山", 2), _card("风", 5), _card("风", 4),
		_card("风", 3), _card("山", 4), _card("山", 4), _card("山", 4),
	]
	return fighter

func _enemy(def: Dictionary) -> FighterState:
	var fighter := FighterState.new("e", "青锋剑徒", 40)
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func _start(def: Dictionary) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(_player(), _enemy(def)))
	tm.start_battle(false)
	return tm

# ---------- 行为链梯 ----------

func test_ladder_walks_condition_then_payable() -> void:
	var tm := _start(LADDER_DEF)
	# 盾 0（<3）且手里山4 刻子可付 → 锁重盾式
	assert_eq(str(tm.enemy_intent.get("technique", "")), "重盾式")
	tm.combat.enemy.guard = 10  # 条件不过 → 落到磨刃式（刻子可付）
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式")

# 账面不可付（三张不成型）：落链到地板
func test_unpayable_falls_to_swap_floor() -> void:
	var tm := _start(BROKE_DEF)
	assert_eq(str(tm.enemy_intent.get("action", "")), "swap", "手里无成型三张 → 架势地板")
	assert_eq(str(tm.enemy_intent.get("label", "")), "架势")

# 隔1：可行却被拦 → 跳过并递减；下一轮放行
func test_opportunity_cooldown_intercepts_then_releases() -> void:
	var tm := _start(LADDER_DEF)
	tm.combat.enemy.guard = 10  # 重盾式条件不过
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)  # 磨刃式放行锁定
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式")
	tm.combat.enemy_brain.after_execute(tm.combat.enemy)  # 执行磨刃式 → 隔1 置满
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)  # 隔1 拦截 → 落地板
	assert_eq(str(tm.enemy_intent.get("action", "")), "swap", "隔1 拦截 → 落地板")
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)  # 递减后第二轮放行
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式", "递减归零后放行")

# 敌方功法表由梯级声明序填充（截牌选功法＝声明序第一个可付的）
func test_techniques_filled_from_ladder_order() -> void:
	var enemy := _enemy(LADDER_DEF)
	assert_eq(enemy.techniques, ["重盾式", "磨刃式"] as Array[String], "架势地板不入功法表")

# 换手策略：弃低值，至多 4 张
func test_swap_policy_low_value_discards_low() -> void:
	var def := THREAT_DEF.duplicate(true)
	def["swap_policy"] = "low_value"
	def["hand"] = [
		{"attribute": "山", "value": 2}, {"attribute": "山", "value": 2},
		{"attribute": "火", "value": 7}, {"attribute": "风", "value": 8},
	]
	var tm := _start(def)
	var result := tm.combat.enemy_brain.execute(tm.combat.enemy, tm.combat.player, tm.combat.pipeline, tm.rng, 4)
	assert_eq(str(result.get("action", "")), "swap")
	assert_eq(int(result.get("discarded", 0)), 2, "只弃两张低值（≤4）")
	# 低值牌全部进它自己的牌河
	assert_eq(tm.combat.river_of("enemy").size(), 2)
	for entry in tm.combat.river_of("enemy"):
		assert_true((entry as Dictionary)["card"].value <= 4)

# ---------- 力状态走同一管线 ----------

func test_li_status_boosts_enemy_damage() -> void:
	var tm := _start(BROKE_DEF)
	# 上力走管线（status_apply 注册状态钩子），与实战同路
	var apply := GameAction.new("status_apply", tm.combat.enemy, 2)
	apply.context["status"] = "li"
	tm.combat.pipeline.submit(apply)
	assert_eq(tm.combat.enemy.get_status("li"), 2)
	var player_hp_before := tm.combat.player.hp
	var result := TechniqueResolver.resolve("点星式",
		[_card("风", 6), _card("风", 7), _card("风", 8)],
		tm.combat.enemy, tm.combat.player, tm.combat.pipeline, tm.rng)
	assert_true(bool(result.get("ok", false)))
	assert_eq(tm.combat.player.hp, player_hp_before - (2 + 21 + 2), "2＋21＋力2")

# ---------- 应读数（实时活算） ----------

func test_claim_threats_from_real_hand() -> void:
	var tm := _start(THREAT_DEF)
	var threats := tm.combat.claim_threats(tm.combat.enemy)
	var texts: Array[String] = []
	for threat in threats:
		texts.append("%s%s%d" % [str(threat.get("claim", "")), str(threat.get("attribute", "")), int(threat.get("value", 0))])
	assert_true(texts.has("碰山4"), "两张山4 在手＋崩山式待发 → 弃山4 是明码雷区（%s）" % "、".join(texts))
	assert_true(texts.has("吃风4"), "风3+风5 在手＋点星式待发 → 弃风4 可被吃")

func test_claim_threats_dumb_while_charging() -> void:
	var tm := _start(THREAT_DEF)
	tm.combat.enemy.charging = {"technique": "蓄势斩", "charge": 0, "need": 1, "cards": []}
	assert_eq(tm.combat.claim_threats(tm.combat.enemy).size(), 0, "蓄力锁：应读数全哑")

func test_claim_threats_need_ready_kezi_technique() -> void:
	var tm := _start(THREAT_DEF)
	tm.combat.enemy.technique_cooldowns["崩山式"] = 1  # 唯一刻子功法进冷却
	var threats := tm.combat.claim_threats(tm.combat.enemy)
	for threat in threats:
		assert_ne(str(threat.get("claim", "")), "碰", "碰威胁随刻子功法冷却消失")
		assert_ne(str(threat.get("claim", "")), "杠", "杠威胁随刻子功法冷却消失")
