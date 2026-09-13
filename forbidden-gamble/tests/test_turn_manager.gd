extends GutTest

# 行动权判定制：行动权是标记，每次原子行动后重新判定——首拍玩家优先（被袭击反转），
# 后续非前手优先；逐候选查破绽（有则消耗＋跳过）。敌方＝同核对手卡（敌方系统 v2：
# 发动功法与调息，行为链梯驱动）。破盾＝纯物理不给破绽（钩子与压制动词是仅有的
# 破绽铸币厂）。牌堆从尾部抽牌；start_battle(false) 关洗牌保证确定性。

const LOOP_DEF := {
	"breathe_policy": "all",
	"hand": [
		{"id": "e1", "attribute": "山", "grade": "下品"},
		{"id": "e2", "attribute": "山", "grade": "下品"},
	],
	"deck": [
		{"id": "e3", "attribute": "山", "grade": "下品"},
		{"id": "e4", "attribute": "山", "grade": "下品"},
	],
	"ladder": [
		{"technique": "重盾式", "when": {"guard_lt": 3}},
		{"technique": "调息"},
	],
	"hooks": [],
}

const FLURRY_DEF := {
	"breathe_policy": "all",
	"hand": [
		{"id": "e1", "attribute": "风", "grade": "下品"},
		{"id": "e2", "attribute": "风", "grade": "下品"},
	],
	"deck": [
		{"id": "e3", "attribute": "风", "grade": "下品"},
		{"id": "e4", "attribute": "风", "grade": "下品"},
	],
	"ladder": [{"technique": "连风式"}, {"technique": "调息"}],
	"hooks": [],
}

const SMASH_DEF := {
	"breathe_policy": "all",
	"hand": [{"id": "e1", "attribute": "风", "grade": "上品"}],
	"deck": [
		{"id": "e2", "attribute": "风", "grade": "上品"},
		{"id": "e3", "attribute": "风", "grade": "上品"},
	],
	"ladder": [{"technique": "点星式"}, {"technique": "调息"}],
	"hooks": [],
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
	var fighter := FighterState.new("p", "p", 30)
	fighter.techniques.assign(["点星式", "二重·壁"])
	fighter.draw_pile = deck
	return fighter

func _enemy(def: Dictionary, hp := 26) -> FighterState:
	var fighter := FighterState.new("e", "e", hp)
	fighter.enemy_def = def
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func _start(player: FighterState, enemy: FighterState, enemy_first := false) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false, enemy_first)
	return tm

# ---------- 开战与第一次行动权 ----------

func test_start_battle_draws_six_and_player_holds_right() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	assert_eq(tm.combat.player.hand.size(), 6, "起手纳 6 口（HAND_SIZE=6）")
	assert_eq(tm.combat.enemy.hand.size(), 2, "敌方起手手牌 authored（本卡 2 口）")
	assert_eq(tm.combat.active_side, "player", "默认玩家持有第一次行动权")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "重盾式", "开战即锁敌方意图（梯顶）")
	assert_eq(str(tm.enemy_intent.get("label", "")), "重盾式")

func test_ambush_gives_enemy_first_right() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF), true)
	assert_eq(tm.combat.active_side, "enemy", "被袭击＝敌方获得第一次行动权")

# ---------- 原子行动与判定 ----------

func test_player_act_transfers_to_non_previous() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	var selection := TechniqueResolver.find_legal_selection("二重·壁", tm.combat.player.hand)
	assert_false(selection.is_empty(), "手牌应含同属性对")
	var result := tm.player_act("二重·壁", selection)
	assert_true(bool(result.get("ok", false)))
	assert_eq(tm.combat.player.guard, 11, "两张中品量2：7+2×2")
	assert_eq(tm.combat.player.hand.size(), 4, "用过的真气离开手牌")
	assert_eq(tm.combat.player.discard_pile.size(), 2, "选入真气散入气海")
	assert_eq(tm.combat.active_side, "enemy", "行动结束判定给非前手")

func test_enemy_act_executes_locked_intent() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.player_breathe()
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()
	assert_eq(tm.combat.enemy.guard, 10, "敌方第一招＝盾 10")
	assert_eq(tm.combat.active_side, "player", "敌方行动后判定给玩家")

func test_player_act_when_not_holder_rejected() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF), true)
	var result := tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_false(bool(result.get("ok", false)), "不持有行动权不能行动")

# ---------- 调息（B2：弃任意张，纳至六口） ----------

func test_breathe_discards_hand_and_draws_six() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	var used := tm.combat.player.hand.duplicate()
	tm.player_breathe()
	assert_eq(tm.combat.player.hand.size(), 6, "无参调息＝弃全部，纳满 6 口")
	assert_eq(tm.combat.player.discard_pile.size(), 6, "旧手牌全部吐入气海")
	for card in used:
		assert_false(tm.combat.player.hand.has(card), "吐故之气不应还在手上")
	assert_eq(tm.combat.player_breath_count, 1, "玩家气口计数 +1")
	assert_eq(tm.combat.active_side, "enemy", "调息后判定给敌方（喘气也是花）")

func test_breathe_reshuffles_discard_when_draw_pile_empty() -> void:
	# 10 张牌：起手 6 张用 2 张后调息——丹田剩 2 张不够纳 6，洗气海续
	var tm := _start(_player(_wind(10, 2, "p")), _enemy(LOOP_DEF))
	var selection := TechniqueResolver.find_legal_selection("二重·壁", tm.combat.player.hand)
	tm.player_act("二重·壁", selection)
	tm.enemy_act()
	tm.player_breathe()
	assert_eq(tm.combat.player.hand.size(), 6, "丹田不足洗气海续纳")

func test_breathe_partial_discard_keeps_unselected() -> void:
	# B2 核心：弃 2 保 4——留下要攒的半成品，洗掉废牌，纳回 6 口
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	var kept: Array = [tm.combat.player.hand[1], tm.combat.player.hand[3], tm.combat.player.hand[4], tm.combat.player.hand[5]]
	tm.player_breathe([0, 2])
	assert_eq(tm.combat.player.discard_pile.size(), 2, "只有所选两口入气海")
	assert_eq(tm.combat.player.hand.size(), 6, "纳至六口")
	for card in kept:
		assert_true(tm.combat.player.hand.has(card), "未选真气留在手上")
	assert_eq(tm.combat.active_side, "enemy", "调息让权")

func test_breathe_zero_discard_only_refills() -> void:
	# 弃 0 张＝只补不弃（原提气用途）：打完功法手牌 4，补回 6，一张不弃
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	var selection := TechniqueResolver.find_legal_selection("二重·壁", tm.combat.player.hand)
	tm.player_act("二重·壁", selection)
	tm.enemy_act()
	var kept := tm.combat.player.hand.duplicate()
	var qi_hai_before := tm.combat.player.discard_pile.size()
	tm.player_breathe([])
	assert_eq(tm.combat.player.hand.size(), 6, "补至六口")
	for card in kept:
		assert_true(tm.combat.player.hand.has(card), "一口没弃，全数在手")
	assert_eq(tm.combat.player.discard_pile.size(), qi_hai_before, "弃 0 张不进气海")
	assert_eq(tm.combat.active_side, "enemy", "让权照常")

func test_breathe_unlimited_no_per_breath_gate() -> void:
	# 不限次：连续调息每拍都成立（限速器＝让权代价，不是次数条）
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.player_breathe([])
	tm.enemy_act()
	tm.player_breathe([])
	assert_eq(tm.combat.active_side, "enemy", "第二次调息同样成立并让权")

# ---------- 气持有即保留 ----------

func test_cards_held_across_actions() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.player_breathe([])  # 弃 0 张让权：手牌原样
	var held = tm.combat.player.hand[0]
	tm.enemy_act()
	assert_true(tm.combat.player.hand.has(held), "捏着的气不散（无自动回收）")
	assert_eq(tm.combat.player.hand.size(), 6, "弃 0 调息后手牌保持六口")

# ---------- 破绽与判定制 ----------

func test_flaw_skips_and_consumes() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.combat.enemy.flawed = true
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(tm.combat.active_side, "player", "敌方破绽：跳过一次获得行动权，玩家连动")
	assert_false(tm.combat.enemy.flawed, "破绽即查即耗")
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(tm.combat.active_side, "enemy", "破绽只跳一拍——下一次判定照常轮流")

func test_guard_shatter_is_pure_physics_no_flaw() -> void:
	# 敌方系统 v2 修订：破盾＝纯物理（漏血），不给破绽——敌方 12 点砸穿玩家 11 盾后
	# 行动权照常轮流回玩家（破绽铸币厂只剩钩子与压制动词）。
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(SMASH_DEF))
	tm.combat.player.guard = 11
	tm.player_breathe([])
	tm.enemy_act()
	assert_eq(tm.combat.player.guard, 0, "护盾被击碎")
	assert_eq(tm.combat.player.hp, 29, "溢出 1 点扣气血")
	assert_false(tm.combat.player.flawed, "破盾不给破绽")
	assert_eq(tm.combat.active_side, "player", "判定照常轮流")

func test_guard_shatter_via_player_attack_grants_no_flaw() -> void:
	# 玩家用上品点星（6+3×2=12）击碎敌方 10 盾：纯物理——无钩子的卡不吃破绽
	var tm := _start(_player(_wind(12, 3, "p")), _enemy(LOOP_DEF))
	tm.player_breathe([])
	tm.enemy_act()  # 梯顶：重盾式 → 盾 10
	assert_eq(tm.combat.enemy.guard, 10)
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(tm.combat.enemy.guard, 0, "敌方护盾被击碎")
	assert_eq(tm.combat.enemy.hp, 24, "溢出 2 点扣气血")
	assert_false(tm.combat.enemy.flawed, "无乱钩的卡：破盾不产生破绽")
	assert_eq(tm.combat.active_side, "enemy", "判定照常轮流")

func test_no_shatter_when_guard_already_zero() -> void:
	# 护境已归零再挨打＝无盾可碎，不触发破绽
	var tm := _start(_player(_wind(12, 3, "p")), _enemy(LOOP_DEF))
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_false(tm.combat.enemy.flawed, "无护盾可破：不产生破绽")
	assert_eq(tm.combat.active_side, "enemy", "判定照常轮流")

func test_guard_remove_is_not_shatter() -> void:
	# 拆除（guard_remove）是拆不是碎——不触发破绽
	var player := _player([])
	var enemy := _enemy(LOOP_DEF)
	enemy.guard = 5
	var combat := CombatState.new(player, enemy)
	combat.pipeline.submit(GameAction.new("guard_remove", enemy, 5, player))
	assert_eq(enemy.guard, 0, "护境被拆除")
	assert_false(enemy.flawed, "拆除不触发破绽")

func test_multi_hit_shatters_on_breaking_segment() -> void:
	# 段破段触发：玩家 3 盾挨连风式双段——第一段打碎护盾那一刻触发破盾事件（纯物理，
	# 无钩子不生破绽），第二段直落气血
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(FLURRY_DEF))
	tm.combat.player.guard = 3
	tm.player_breathe([])
	tm.enemy_act()
	assert_eq(tm.combat.player.guard, 0)
	assert_eq(tm.combat.player.hp, 25, "两段各 4（风下品对量0）：碎 3 盾后 1+4 落气血")
	assert_eq(tm.combat.active_side, "player", "无破绽：判定照常轮流")

func test_both_flawed_burns_both() -> void:
	# 双破绽（将来机制可能造成）：两候选各烧一个，回到队首非前手获得
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.combat.player.flawed = true
	tm.combat.enemy.flawed = true
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(tm.combat.active_side, "enemy", "双方各烧一个破绽后，非前手（敌方）获得")
	assert_false(tm.combat.player.flawed)
	assert_false(tm.combat.enemy.flawed)

# ---------- 行动权点位 ----------

func test_initiative_points_fire_on_gain() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	var gained: Array = []
	tm.combat.pipeline.register_hook({"carrier": "test", "on": "initiative_gain", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void: gained.append((action.target as FighterState).fighter_id)})
	tm.player_breathe([])
	assert_eq(gained, ["e"], "判定落定后新持有方收到 initiative_gain")

# ---------- 度量计数 ----------

func test_action_and_breath_counters() -> void:
	var tm := _start(_player(_wind(12, 2, "p")), _enemy(LOOP_DEF))
	tm.player_breathe([])     # 行动1（弃 0 张也是调息）
	tm.enemy_act()            # 行动2
	tm.player_breathe()       # 行动3
	assert_eq(tm.combat.action_count, 3)
	assert_eq(tm.combat.player_breath_count, 2, "两次调息两口气的计数")
