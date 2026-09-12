extends GutTest

# 行动权模型（26 号 §11，D-063 换轴）：行动权是唯一时序令牌——无大回合、无收势。
# 原子行动（功法/调息/提气）结束即转让；调息＝弃全部手牌入气海再纳 HAND_SIZE 口；
# 提气＝交权从丹田提 1 张、每口气限 1 次（调息重置）；僵局保险＝连续无功法动作
# （提气＋调息）累计到上限判平局（视同败北）。牌堆从尾部抽牌；start_battle(false) 关洗牌。

func _fighter(id: String, techniques: Array, priority: Array = []) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	fighter.ai_priority.assign(priority)
	return fighter

# specs：["风2","火3",...]＝属性＋品级数字
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

func _start(player_deck: Array, enemy_deck: Array, enemy_first := false) -> TurnManager:
	var player := _fighter("p", ["点星式", "二重·壁"])
	player.draw_pile = player_deck
	var enemy := _fighter("e", ["连风式", "点星式"], ["连风式", "点星式"])
	enemy.draw_pile = enemy_deck
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false, enemy_first)
	return tm

# ---------- 开战与第一次行动权 ----------

func test_start_battle_draws_six_and_player_holds_right() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	assert_eq(tm.combat.player.hand.size(), 6, "起手各纳 6 口（HAND_SIZE=6）")
	assert_eq(tm.combat.enemy.hand.size(), 6)
	assert_eq(tm.combat.active_side, "player", "默认玩家持有第一次行动权")
	assert_eq(str(tm.enemy_intent.get("technique", "PASS")), "连风式", "开战即锁敌方意图")

func test_ambush_gives_enemy_first_right() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"), true)
	assert_eq(tm.combat.active_side, "enemy", "被袭击＝敌方获得第一次行动权")

# ---------- 原子行动与行动权流转 ----------

func test_player_act_transfers_right() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	var selection := TechniqueResolver.find_legal_selection("二重·壁", tm.combat.player.hand)
	assert_false(selection.is_empty(), "手牌应含同属性对")
	var result := tm.player_act("二重·壁", selection)
	assert_true(bool(result.get("ok", false)))
	assert_eq(tm.combat.player.guard, 11, "两张中品量2：7+2×2")
	assert_eq(tm.combat.player.hand.size(), 4, "用过的真气离开手牌")
	assert_eq(tm.combat.player.discard_pile.size(), 2, "选入真气散入气海")
	assert_eq(tm.combat.active_side, "enemy", "行动结束即转让行动权")

func test_enemy_act_executes_locked_intent() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.player_lift()
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()
	# 连风式两张中品：量2、每段 4+2=6、双段 12
	assert_eq(tm.combat.player.hp, 18, "敌方连风式双段共 12 点伤害")
	assert_eq(tm.combat.active_side, "player", "敌方行动后行动权回到玩家")

func test_player_act_when_not_holder_rejected() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"), true)
	var result := tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_false(bool(result.get("ok", false)), "不持有行动权不能行动")

# ---------- 调息（吐故纳新） ----------

func test_breathe_discards_hand_and_draws_six() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	var used := tm.combat.player.hand.duplicate()
	tm.player_breathe()
	assert_eq(tm.combat.player.hand.size(), 6, "调息后纳满 6 口")
	assert_eq(tm.combat.player.discard_pile.size(), 6, "旧手牌全部吐入气海")
	for card in used:
		assert_false(tm.combat.player.hand.has(card), "吐故之气不应还在手上")
	assert_eq(tm.combat.player_breath_count, 1, "玩家气口计数 +1")
	assert_eq(tm.combat.active_side, "enemy", "调息立即转让行动权（链条终点）")

func test_breathe_reshuffles_discard_when_draw_pile_empty() -> void:
	# 10 张牌：起手 6 张用 2 张后调息——丹田剩 2 张不够纳 6，洗气海续
	var tm := _start(_wind(10, 2, "p"), _wind(12, 2, "e"))
	var selection := TechniqueResolver.find_legal_selection("二重·壁", tm.combat.player.hand)
	tm.player_act("二重·壁", selection)
	tm.enemy_act()
	tm.player_breathe()
	assert_eq(tm.combat.player.hand.size(), 6, "丹田不足洗气海续纳")

# ---------- 提气（原暂让） ----------

func test_lift_draws_one_and_transfers() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	var before := tm.combat.player.hand.size()
	tm.player_lift()
	assert_eq(tm.combat.player.hand.size(), before + 1, "提气从丹田提 1 张（不弃手牌）")
	assert_eq(tm.combat.active_side, "enemy")
	assert_eq(tm.combat.player.draw_pile.size(), 12 - 6 - 1)

func test_lift_limited_once_per_breath() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.player_lift()
	var before := tm.combat.player.hand.size()
	assert_eq(tm.combat.player.lifts_this_breath, 1, "本口气已提过")
	tm.player_lift()
	assert_eq(tm.combat.player.hand.size(), before, "同一口气第二次提气无效")
	assert_eq(tm.combat.active_side, "enemy", "无效提气不产生新行动")

func test_lift_reset_by_breathe() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.player_lift()
	assert_eq(tm.combat.player.lifts_this_breath, 1)
	tm.enemy_act()
	tm.player_breathe()
	assert_eq(tm.combat.player.lifts_this_breath, 0, "调息重置提气次数")
	tm.enemy_act()
	var size_after_breath := tm.combat.player.hand.size()
	tm.player_lift()
	assert_eq(tm.combat.player.hand.size(), size_after_breath + 1, "新一口气可再提气")

# ---------- 气持有即保留（无回合末自动回收） ----------

func test_cards_held_across_actions() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.player_lift()
	var held = tm.combat.player.hand[0]
	tm.enemy_act()
	assert_true(tm.combat.player.hand.has(held), "捏着的气不散（无自动回收）")
	assert_eq(tm.combat.player.hand.size(), 7, "提气 +1 后手牌保持")

# ---------- 僵局保险 ----------

func _stuck_start() -> TurnManager:
	# 双方都无力法可用：玩家提气/调息空转；敌方无任何功法（提一次后只剩调息）
	var player := _fighter("p", [])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", [])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false)
	return tm

func test_idle_actions_end_in_draw() -> void:
	var tm := _stuck_start()
	var rounds := 0
	while not tm.is_over() and rounds < 30:
		if tm.combat.player.lifts_this_breath >= 1:
			tm.player_breathe()
		else:
			tm.player_lift()
		if tm.is_over():
			break
		tm.enemy_act()
		rounds += 1
	assert_true(tm.battle_stalled, "双方僵持应触发平局保险")
	assert_true(tm.is_over())

func test_technique_action_resets_idle_counter() -> void:
	var player := _fighter("p", ["点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", [])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false)
	for _step in range(5):
		if tm.combat.player.lifts_this_breath >= 1:
			tm.player_breathe()
		else:
			tm.player_lift()
		if tm.is_over():
			break
		tm.enemy_act()
	assert_false(tm.is_over(), "互让远未到僵局上限")
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	# 功法发动重置 idle 计数——之后再让几轮也不该立即僵局
	for _step in range(5):
		if tm.combat.player.lifts_this_breath >= 1:
			tm.player_breathe()
		else:
			tm.player_lift()
		if tm.is_over():
			break
		tm.enemy_act()
	assert_false(tm.is_over(), "功法行动重置僵局计数")

# ---------- 敌方空转 ----------

func test_enemy_breathes_when_no_legal_technique() -> void:
	# 意图直接注入"调息"：验证敌方调息吐故纳新并交权
	var tm := _stuck_start()
	tm.enemy_intent = {"action": "breathe"}
	tm.combat.active_side = "enemy"
	var before := tm.combat.enemy.discard_pile.size()
	tm.enemy_act()
	assert_eq(tm.combat.enemy.discard_pile.size(), before + 6, "敌方调息吐故 6 口入气海")
	assert_eq(tm.combat.enemy.hand.size(), 6, "敌方纳新 6 口")
	assert_eq(tm.combat.active_side, "player")

func test_enemy_intent_locks_lift_then_breathe_when_stuck() -> void:
	var tm := _stuck_start()
	tm.player_breathe()
	assert_eq(str(tm.enemy_intent.get("action", "")), "lift_qi", "敌方无合法功法应先锁提气意图")
	# 敌方提气一次后，下一口气内只剩调息
	tm.enemy_act()
	assert_eq(str(tm.enemy_intent.get("action", "")), "breathe", "已提过气则锁定调息意图")

# ---------- 行动权点位与压制引擎钩子 ----------

func test_initiative_points_fire_on_transfer() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	var gained: Array = []
	tm.combat.pipeline.register_hook({"carrier": "test", "on": "initiative_gain", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void: gained.append((action.target as FighterState).fighter_id)})
	tm.player_lift()
	assert_eq(gained, ["e"], "行动权移交后新持有方收到 initiative_gain")

func test_transfer_cancel_keeps_right() -> void:
	# 压制引擎钩子（D-064）：PRE 取消移交动作（仅功法类行动有效）→ 行动权保留
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.combat.pipeline.register_hook({"carrier": "test", "on": "initiative_transfer", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.cancelled = true})
	tm.player_act("点星式", [tm.combat.player.hand[0]])
	assert_eq(tm.combat.active_side, "player", "取消移交＝压制：行动权保留")
	tm.drain_messages()
	# 调息后不可保留：调息永远是链条终点（引擎铁律覆盖取消）
	tm.player_breathe()
	assert_eq(tm.combat.active_side, "enemy", "调息后取消被驳回（链条终点）")

# ---------- 度量计数 ----------

func test_action_and_breath_counters() -> void:
	var tm := _start(_wind(12, 2, "p"), _wind(12, 2, "e"))
	tm.player_lift()         # 行动1
	tm.enemy_act()           # 行动2（功法）
	tm.player_breathe()      # 行动3、玩家气口1
	assert_eq(tm.combat.action_count, 3)
	assert_eq(tm.combat.player_breath_count, 1)
