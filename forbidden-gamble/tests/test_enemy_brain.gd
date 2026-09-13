extends GutTest

# 敌方脑（敌方系统 v2）：行为链梯（条件→账面→隔）、调息地板与策略、
# 钩子两族（乱＝自况事件翻牌＋后坐破绽；应＝你的事件翻牌＋你得破绽）、
# 应手武装门、钩子行动钟冷却、蓄力锁（起蓄后钩子全灭）、力状态走同一管线。

const QINGFENG_DEF := {
	"breathe_policy": "singletons",
	"hand": [
		{"id": "e1", "attribute": "山", "grade": "下品"},
		{"id": "e2", "attribute": "山", "grade": "下品"},
		{"id": "e3", "attribute": "风", "grade": "下品"},
	],
	"deck": [],
	"ladder": [
		{"technique": "重盾式", "when": {"guard_lt": 3}},
		{"technique": "磨刃式", "cooldown": 1},
		{"technique": "调息"},
	],
	"hooks": [],
}

const LADDER_ONLY_DEF := {
	"breathe_policy": "all",
	"hand": [{"id": "e1", "attribute": "山", "grade": "下品"}],
	"deck": [],
	"ladder": [{"technique": "重盾式", "when": {"guard_lt": 3}}, {"technique": "调息"}],
	"hooks": [],
}

const LUAN_DEF := {
	"breathe_policy": "all",
	"hand": [
		{"id": "e1", "attribute": "山", "grade": "下品"},
		{"id": "e2", "attribute": "山", "grade": "下品"},
		{"id": "e3", "attribute": "山", "grade": "下品"},
	],
	"deck": [
		{"id": "e4", "attribute": "山", "grade": "下品"},
		{"id": "e5", "attribute": "山", "grade": "下品"},
	],
	"ladder": [{"technique": "磨刃式"}, {"technique": "调息"}],
	"hooks": [
		{"kind": "乱", "on": "guard_broken", "technique": "重盾式", "cooldown": 2},
	],
}

const YING_DEF := {
	"breathe_policy": "all",
	"hand": [{"id": "e1", "attribute": "风", "grade": "下品"}],
	"deck": [{"id": "e2", "attribute": "风", "grade": "下品"}],
	"ladder": [{"technique": "磨刃式"}, {"technique": "调息"}],
	"hooks": [
		{"kind": "应", "on": "player_breathed", "technique": "窥隙脚", "arm": {"guard_gte": 3}, "cooldown": 3},
	],
}

const CHARGE_DEF := {
	"breathe_policy": "all",
	"hand": [
		{"id": "e1", "attribute": "山", "grade": "下品"},
		{"id": "e2", "attribute": "山", "grade": "下品"},
		{"id": "e3", "attribute": "山", "grade": "下品"},
	],
	"deck": [
		{"id": "e4", "attribute": "山", "grade": "下品"},
		{"id": "e5", "attribute": "山", "grade": "下品"},
	],
	"ladder": [
		{"technique": "重盾式", "when": {"guard_lt": 3}},
		{"technique": "蓄势斩", "when": {"guard_gt": 8}},
		{"technique": "调息"},
	],
	"hooks": [
		{"kind": "应", "on": "player_breathed", "technique": "窥隙脚", "arm": {"guard_gte": 3}, "cooldown": 3},
	],
}

func _cards(specs: Array, prefix: String) -> Array:
	var cards: Array = []
	var index := 0
	for spec in specs:
		index += 1
		cards.append(QiCard.new("%s%d" % [prefix, index], str(spec).left(1), int(str(spec).right(1))))
	return cards

func _wind(count: int, grade: int, prefix: String) -> Array:
	var specs: Array = []
	for _i in range(count):
		specs.append("风%d" % grade)
	return _cards(specs, prefix)

func _player(deck: Array) -> FighterState:
	var fighter := FighterState.new("p", "你", 30)
	fighter.techniques.assign(["点星式"])
	fighter.draw_pile = deck
	return fighter

func _enemy(def: Dictionary, hp := 26) -> FighterState:
	var fighter := FighterState.new("e", "敌方", hp)
	fighter.enemy_def = def
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func _start(player: FighterState, enemy: FighterState, enemy_first := false) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false, enemy_first)
	return tm

func _enemy_beat(tm: TurnManager) -> Dictionary:
	tm.combat.active_side = "enemy"
	tm.combat.pipeline.acting_side = "enemy"
	return tm.enemy_act()

func _player_beat(tm: TurnManager) -> void:
	tm.combat.active_side = "player"
	tm.combat.pipeline.acting_side = "player"

# ---------- 行为链梯：条件 → 账面 → 隔（最后一层） ----------

func test_ladder_walks_conditions_then_payability() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(QINGFENG_DEF))
	assert_eq(str(tm.enemy_intent.get("technique", "")), "重盾式", "盾<3：梯顶锁重盾式")
	_enemy_beat(tm)  # 重盾式（山下品量0）→ 盾 10
	assert_eq(tm.combat.enemy.guard, 10, "重盾式走 guard_set（基值10）")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式", "盾10：规则一不满足 → 磨刃式")

func test_rule_cooldown_intercepts_and_decrements() -> void:
	# 磨刃式 隔1：执行后，下一次「条件全过」的判断被拦（-1）落链到调息，再下一次可用
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(QINGFENG_DEF))
	_enemy_beat(tm)  # 重盾式 → 盾10
	_enemy_beat(tm)  # 磨刃式 → 力+1（隔1 置满）
	assert_eq(tm.combat.enemy.get_status("li"), 1, "磨刃式施加力+1")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "调息", "隔1 拦截：本次可行却不采取，落链到地板")
	_enemy_beat(tm)  # 调息（弃孤张）
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式", "拦截一次后隔归零：磨刃式恢复可用")

func test_floor_breathes_with_policy_and_reshuffles() -> void:
	# 弃孤张策略：手中山×2风×1 → 只弃风；气海洗回续纳
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(QINGFENG_DEF))
	_enemy_beat(tm)  # 重盾式（耗一山）
	_enemy_beat(tm)  # 磨刃式（再耗一山）
	_enemy_beat(tm)  # 调息：手上只剩风×1＝孤张 → 弃之，洗气海纳回
	assert_eq(tm.combat.enemy.hand.size(), 3, "气海三张（山山风）洗回全数纳回")
	assert_eq(tm.combat.enemy.discard_pile.size(), 0, "气海被洗走")

func test_payability_failure_falls_through_without_touching_cooldown() -> void:
	# 蓄势斩（二重）：手上没有同属性对 → 账面不过 → 落链且隔不递减（条件没过冷却不发言）
	var enemy := _enemy(CHARGE_DEF)
	enemy.hand.clear()  # 只留一张山：二重凑不出
	var tm := _start(_player(_wind(12, 2, "p")), enemy)
	enemy.guard = 10
	tm.combat.enemy_brain.lock_intent(enemy)
	assert_eq(str(tm.enemy_intent.get("technique", "")), "调息", "蓄势斩凑不齐 → 落链到调息")

# ---------- 乱钩：破盾 → 翻牌重盾式 → 执行完入账破绽 ----------

func test_luan_hook_flips_intent_then_deferred_flaw() -> void:
	var tm := _start(_player(_wind(12, 3, "p")), _enemy(LUAN_DEF))
	tm.combat.enemy.guard = 10
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式")
	_player_beat(tm)
	tm.player_act("点星式", [tm.combat.player.hand[0]])  # 12 击碎 10 盾
	assert_eq(tm.combat.enemy.guard, 0, "护境被击碎")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "重盾式", "乱钩翻牌：意图当场变成重盾式")
	assert_false(tm.combat.enemy.flawed, "后坐破绽未入账：先落子后踉跄")
	_enemy_beat(tm)  # 它的拍：重盾式照常执行
	assert_eq(tm.combat.enemy.guard, 10, "翻牌的招当拍执行（这一拍不跳）")
	assert_true(tm.combat.enemy.flawed, "执行完入账：下一拍踉跄")
	_player_beat(tm)
	tm.player_act("点星式", [tm.combat.player.hand[0]])  # 玩家连动（敌方未跳，判定给玩家）
	assert_eq(tm.combat.active_side, "player", "敌方破绽生效：玩家再连动一拍（偷到一拍）")

func test_luan_hook_skips_when_intent_already_matches() -> void:
	# 与当前意图相同：无转换、无代价
	var tm := _start(_player(_wind(12, 3, "p")), _enemy(LUAN_DEF))
	tm.combat.enemy.guard = 10
	tm.combat.enemy_brain.intent = {"action": "technique", "technique": "重盾式", "label": "重盾式"}
	_player_beat(tm)
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_false(tm.combat.enemy.flawed, "意图本就是重盾式：不翻不罚")
	assert_false(tm.combat.enemy_brain.pending_flaw)

func test_luan_hook_respects_action_clock_cooldown() -> void:
	# 歇2（行动钟）：翻牌执行后，它接下来两次行动内再破盾不再触发
	var tm := _start(_player(_wind(12, 3, "p")), _enemy(LUAN_DEF))
	tm.combat.enemy.guard = 10
	tm.combat.enemy_brain.lock_intent(tm.combat.enemy)
	_player_beat(tm)
	tm.player_act("点星式", [tm.combat.player.hand[0]])  # 碎盾 → 翻牌
	_enemy_beat(tm)  # 重盾式执行 → 钩子冷却置 2 → 破绽入账 → 行动前钟已减 1（置2在行动后）
	assert_eq(int(tm.combat.enemy_brain.hook_cooldowns.get(0, 0)), 2, "歇2 执行时置满")
	# 再碎一次盾：冷却中（≥1）不触发
	tm.combat.enemy.guard = 10
	_player_beat(tm)
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式", "冷却中乱钩不翻牌")

# ---------- 应钩：你调息 → 翻牌窥隙脚 → 你得破绽 ----------

func test_ying_hook_pins_player_on_breathe() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(YING_DEF))
	tm.combat.enemy.guard = 10  # 武装条件：盾≥3
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	assert_true(bool(tm.combat.enemy_brain.armed.get(0, false)), "盾≥3 且可付：灯亮")
	_player_beat(tm)
	var hp_before := tm.combat.player.hp
	tm.player_breathe([])  # 你调息：应钩在事件瞬间翻牌
	assert_eq(str(tm.enemy_intent.get("technique", "")), "窥隙脚", "应钩翻牌：改出窥隙脚")
	assert_true(tm.combat.player.flawed, "被抓住的是你：当场得破绽")
	_enemy_beat(tm)  # 它的拍：窥隙脚当拍执行（风下品量0：2 点伤）
	assert_eq(tm.combat.player.hp, hp_before - 2, "窥隙脚走同一伤害管线")
	assert_eq(tm.combat.active_side, "enemy", "你的破绽被跳过：敌方连动（钉住一拍）")

func test_ying_hook_dark_when_guard_low() -> void:
	# 武装门：盾<3 灯不亮——你调息安全过站
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(YING_DEF))
	tm.combat.enemy.guard = 0
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	assert_false(bool(tm.combat.enemy_brain.armed.get(0, false)), "盾<3：灯灭")
	_player_beat(tm)
	tm.player_breathe([])
	assert_eq(str(tm.enemy_intent.get("technique", "")), "磨刃式", "灯灭不触发：意图不变")
	assert_false(tm.combat.player.flawed, "无破绽")

func test_ying_hook_unpayable_means_dark() -> void:
	# 付不起＝无法监控：封死它的风 → 灯哑，你调息白过
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(YING_DEF))
	tm.combat.enemy.guard = 10
	tm.combat.enemy.hand.clear()  # 无风可付窥隙脚
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	assert_false(bool(tm.combat.enemy_brain.armed.get(0, false)), "付不起：灯哑")
	_player_beat(tm)
	tm.player_breathe([])
	assert_false(tm.combat.player.flawed, "哑灯不触发")

# ---------- 蓄力：跨拍承诺、期间钩子全灭 ----------

func test_charge_intent_locks_and_fires() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(CHARGE_DEF))
	_enemy_beat(tm)  # 盾<3 → 重盾式 → 盾 10
	assert_eq(str(tm.enemy_intent.get("technique", "")), "蓄势斩", "盾>8：锁蓄势斩")
	var hp_before := tm.combat.player.hp
	_enemy_beat(tm)  # 起手（蓄力 0/1）
	assert_true(tm.combat.enemy.has_active_charge(), "起手建蓄力态")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "蓄势斩", "蓄力期间意图＝蓄力招")
	_enemy_beat(tm)  # 充能拍：1/1 满值自动发动（山下品对量0：8 点）
	assert_false(tm.combat.enemy.has_active_charge(), "发动后蓄力清空")
	assert_eq(tm.combat.player.hp, hp_before - 8, "蓄势斩落地")

func test_charge_lock_silences_hooks() -> void:
	# 蓄力期间钩子全灭：敌方起蓄后你调息，应手不触发
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(CHARGE_DEF))
	_enemy_beat(tm)  # 重盾式 → 盾 10
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	assert_true(bool(tm.combat.enemy_brain.armed.get(0, false)))
	_enemy_beat(tm)  # 蓄势斩起手
	assert_false(bool(tm.combat.enemy_brain.armed.get(0, false)), "蓄力锁：武装下线")
	_player_beat(tm)
	tm.player_breathe([])
	assert_false(tm.combat.player.flawed, "它蓄力时你随便调息（安全窗）")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "蓄势斩")

# ---------- 力状态走同一管线（attacker 方向修正） ----------

func test_li_status_boosts_enemy_damage() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(YING_DEF))
	tm.combat.enemy.guard = 10  # 满足武装门：应钩可用
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	tm.combat.enemy.add_status("li", 2)
	tm.combat.status_runtime.ensure_hooks(tm.combat.enemy, "li")
	var hp_before := tm.combat.player.hp
	_player_beat(tm)
	tm.player_breathe([])  # 触发应钩 → 窥隙脚（量0 基2 + 力2 = 4）
	_enemy_beat(tm)
	assert_eq(tm.combat.player.hp, hp_before - 4, "力×2 修正敌方伤害（伤害 PRE＋层数）")

# ---------- 钩子灯（UI 披露口径） ----------

func test_hook_lamps_expose_three_states() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(YING_DEF))
	tm.combat.enemy.guard = 10
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	var lamps := tm.combat.enemy_brain.hook_lamps(tm.combat.enemy)
	assert_eq(lamps.size(), 1, "只有应手亮灯（乱无灯）")
	assert_eq(str(lamps[0].get("state", "")), "ready", "武装＝就绪")
	assert_string_contains(str(lamps[0].get("tooltip", "")), "你调息", "灯的明码披露触发条件")
	tm.combat.enemy.guard = 0
	tm.combat.enemy_brain.evaluate_arms(tm.combat.enemy)
	lamps = tm.combat.enemy_brain.hook_lamps(tm.combat.enemy)
	assert_eq(str(lamps[0].get("state", "")), "dark", "条件不满足＝哑")
