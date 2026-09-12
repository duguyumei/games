extends GutTest

# 词条族生命周期（26 号 §5/§3.2/§11.4，TurnManager 层，v1 九门承载）：
# 压制＝行动权不转让（引擎 retain 钩子，二合·吐纳承载）；冷却 N＝后续 N 次自己的
# 原子行动内不可再发动（行动开始递减，二重·换承载）；蓄力 N＝起手占行动权、蓄力期
# 自动让权充能、满值自动发动（纵横式承载，v1 无自动喂气）；敌方蓄力意图＝X/N 倒计时。

func _fighter(id: String, techniques: Array, priority: Array = []) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	fighter.ai_priority.assign(priority)
	return fighter

func _wind(count: int, grade: int, prefix: String, attribute := "风") -> Array:
	var cards: Array = []
	for index in range(count):
		cards.append(QiCard.new("%s%d" % [prefix, index], attribute, grade))
	return cards

func _start(player: FighterState, enemy: FighterState) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false)
	return tm

# ---------- 压制与冷却 ----------

func test_tuna_suppression_keeps_initiative() -> void:
	# 吐纳＝二合·压制：发动后行动权不转让，且无冷却定价
	var player := _fighter("p", ["二合·吐纳", "点星式"], ["二合·吐纳", "点星式"])
	player.draw_pile = _cards_mixed_pair_rich("p")
	var enemy := _fighter("e", ["点星式"], ["点星式"])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := _start(player, enemy)
	var mix := TechniqueResolver.find_legal_selection("二合·吐纳", player.hand, player)
	assert_false(mix.is_empty(), "手牌应能凑二合")
	var hand_before := player.hand.size()
	var result := tm.player_act("二合·吐纳", mix)
	assert_true(bool(result.get("ok", false)))
	assert_eq(tm.combat.active_side, "player", "压制：行动权不转让")
	assert_eq(int(player.technique_cooldowns.get("二合·吐纳", 0)), 0, "吐纳无冷却")
	assert_eq(player.hand.size(), hand_before - 2 + 1, "两张散气＋提 1 张")

# 组 12 张：风火交替各 6 张中品——任意起手 6 张必含异属性对（二合）
func _cards_mixed_pair_rich(prefix: String) -> Array:
	var cards: Array = []
	for index in range(6):
		cards.append(QiCard.new("%sw%d" % [prefix, index], "风", 2))
		cards.append(QiCard.new("%sh%d" % [prefix, index], "火", 2))
	return cards

func test_huan_cooldown_gates_next_action() -> void:
	# 换＝二重·冷却1：发动后下一次自己的原子行动内不可再发动
	var player := _fighter("p", ["二重·换", "点星式"], ["二重·换", "点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", ["点星式"], ["点星式"])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := _start(player, enemy)
	var pair := TechniqueResolver.find_legal_selection("二重·换", player.hand, player)
	assert_false(pair.is_empty(), "全风手牌必含二重")
	tm.player_act("二重·换", pair)
	assert_eq(int(player.technique_cooldowns.get("二重·换", 0)), 1, "冷却 1 自此刻起算")
	# 冷却中不可再发动
	assert_false(TechniqueResolver.can_use("二重·换", pair, player), "冷却中门控生效")
	# 冷却 1＝下一次自己的原子行动内不可再发动，之后解锁：
	# 敌方动 → 玩家提气（行动开始 tick 冷却 1→0）→ 可再发动
	tm.enemy_act()
	tm.player_lift()
	assert_eq(int(player.technique_cooldowns.get("二重·换", 0)), 0, "一次行动后冷却归零")
	assert_true(TechniqueResolver.can_use("二重·换", pair, player), "冷却归零后可再发")

func test_enemy_suppression_keeps_enemy_initiative() -> void:
	var player := _fighter("p", ["点星式"], ["点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", ["二合·吐纳", "点星式"], ["二合·吐纳", "点星式"])
	enemy.draw_pile = _cards_mixed_pair_rich("e")
	var tm := _start(player, enemy)
	tm.player_lift()
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()
	assert_eq(tm.combat.active_side, "enemy", "敌方压制：行动权留在敌方")
	# 敌方非压制功法（点星式）发动后正常交权：手动锁定点星式意图排除手牌偶然性
	tm.enemy_intent = {"technique": "点星式", "cards": [enemy.hand[0]]}
	tm.enemy_act()
	assert_eq(tm.combat.active_side, "player", "敌方点星式发动后行动权回玩家")

# ---------- 蓄力生命周期（纵横式＝二合·等级2·蓄力1） ----------

func test_zongheng_charge_lifecycle() -> void:
	var player := _fighter("p", ["纵横式", "点星式"], ["纵横式", "点星式"])
	player.draw_pile = _cards_mixed_pair_rich("p")
	var enemy := FighterState.new("e", "e", 60)
	enemy.techniques.assign(["点星式"])
	enemy.ai_priority.assign(["点星式"])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := _start(player, enemy)
	var mix := TechniqueResolver.find_legal_selection("纵横式", player.hand, player)
	assert_false(mix.is_empty(), "手牌应含异属性对")
	# 选中中品对（量0）：把起手对换成两张中品——直接找包含两张中品的二合
	var mid_pair: Array = []
	for card in player.hand:
		if card.attribute == "风":
			mid_pair.append(card)
			break
	for card in player.hand:
		if card.attribute == "火":
			mid_pair.append(card)
			break
	var started := tm.player_act("纵横式", mid_pair)
	assert_true(bool(started.get("ok", false)))
	assert_eq(str(started.get("action", "")), "charge_started", "蓄力起手不立即结算")
	assert_true(player.has_active_charge(), "蓄力态建立")
	assert_eq((player.charging.get("cards", []) as Array).size(), 2, "选入真气入招（无自动喂气）")
	assert_eq(tm.combat.active_side, "enemy", "起手让权——曝光开始")
	# 蓄力 0/1：敌方动 → 玩家充能拍（+1 即满，自动发动）
	tm.enemy_act()
	var fired := tm.player_charge_tick()
	assert_eq(str(fired.get("action", "")), "technique", "满值自动发动（走功法结算）")
	assert_false(player.has_active_charge(), "蓄力态清空")
	assert_eq(int(fired.get("damage", 0)), 10, "两张中品量0：10+5×0")
	assert_eq(tm.combat.enemy.hp, 50, "60 血敌方余 50")
	assert_eq(tm.combat.active_side, "enemy", "发动后照常让权")

func test_charge1_enemy_countdown_intent() -> void:
	var player := _fighter("p", ["点星式"], ["点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", ["纵横式"], ["纵横式"])
	enemy.draw_pile = _cards_mixed_pair_rich("e")
	var tm := _start(player, enemy)
	tm.player_lift()
	var r := tm.enemy_act()
	assert_eq(str(r.get("action", "")), "charge_started", "敌方起手蓄力")
	assert_eq(str(tm.enemy_intent.get("action", "")), "charging", "意图＝蓄力态")
	assert_eq(int(tm.enemy_intent.get("need", 0)), 1)
	# 蓄力期间任何功法都不可发起（can_use 门控）
	assert_false(TechniqueResolver.can_use("纵横式", [enemy.hand[0], enemy.hand[1]], enemy))
	tm.player_breathe()
	tm.enemy_act()
	assert_ne(str(tm.enemy_intent.get("action", "")), "charging", "蓄满发动后意图不再是蓄力态")
	assert_eq(tm.combat.active_side, "player")

# ---------- 蓄力失效兜底 ----------

func test_charge_fizzle_discards_cards() -> void:
	# 直接改写 charging 模拟结算失效兜底路径
	var player := _fighter("p", ["点星式"], ["点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var enemy := _fighter("e", ["点星式"], ["点星式"])
	enemy.draw_pile = _wind(12, 2, "e")
	var tm := _start(player, enemy)
	player.charging = {"technique": "不存在的功法", "charge": 1, "need": 2, "cards": [QiCard.new("x1", "风", 2)]}
	var r := tm.player_charge_tick()
	assert_false(bool(r.get("ok", false)), "不存在的功法结算失败")
	assert_false(player.has_active_charge(), "蓄力态已清")
	assert_eq(player.discard_pile.size(), 1, "落空的真气散入气海")
