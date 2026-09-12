extends GutTest

# 心法系统（D-060/D-061）测试：词表词条逐类验证、once 记账、系别计数条件、
# 敌我同规则、schema 校验。v1 阶段二：九门名册落齐（先纳功/调息诀/长息诀/气海无涯/
# 化浊诀为新版），事件锚心法全部带方向条件（只随本人的调息/出招/提气触发）。
# 旧心法（传输类词条/顺子锚）已按用户决定删除，重做时从文档从零录入。
# 牌堆从尾部抽牌；所有测试 start_battle(false) 关洗牌保证确定性。

func _fighter(id: String, xinfa_list: Array = [], techniques: Array = ["点星式", "二重·壁"]) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	fighter.xinfa.assign(xinfa_list)
	fighter.ai_priority.assign(techniques)
	return fighter

func _cards(specs: Array, prefix: String) -> Array:
	var cards: Array = []
	var index := 0
	for spec in specs:
		index += 1
		cards.append(QiCard.new("%s%d" % [prefix, index], str(spec[0]), int(spec[1])))
	return cards

func _combat(player: FighterState, enemy: FighterState) -> CombatState:
	return CombatState.new(player, enemy)

# ---------- battle_start 词条 ----------

func test_tunasi_draws_extra_card_on_battle_start() -> void:
	var player := _fighter("p", ["先纳功"])
	player.draw_pile = _cards([["风", 2], ["火", 2], ["林", 1], ["山", 3], ["火", 1], ["风", 3], ["山", 1], ["林", 2]], "p")
	var tm := TurnManager.new(_combat(player, _fighter("e")))
	tm.start_battle(false)
	assert_eq(player.hand.size(), 7, "先纳功：战斗开始应额外提 1 张（6+1）")

func test_enemy_xinfa_same_rules() -> void:
	# D-055：敌我同一条心法规则（敌方龟息功受伤同样减损）
	var enemy := _fighter("e", ["龟息功"], ["点星式"])
	var player := _fighter("p")
	var combat := _combat(player, enemy)
	combat.pipeline.submit(GameAction.new("damage", enemy, 7, player))
	assert_eq(enemy.hp, 24, "敌方龟息功：受伤 7 实扣 6")

# ---------- damage 词条 ----------

func test_guixi_resists_every_hit() -> void:
	var player := _fighter("p", ["龟息功"])
	var combat := _combat(player, _fighter("e"))
	combat.pipeline.submit(GameAction.new("damage", player, 7, combat.enemy))
	assert_eq(player.hp, 24, "龟息功：每次受到的伤害 −1（30-6）")
	combat.pipeline.submit(GameAction.new("damage", player, 7, combat.enemy))
	assert_eq(player.hp, 18, "龟息功非 once 类，第二次同样减伤")

# ---------- breath 词条 ----------

func _breathe_action(combat: CombatState, unit: FighterState) -> void:
	# 直接提交 breath 动作（amount 0＝只吐故不纳新），驱动调息时点结算且不扰动手牌
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var action := GameAction.new("breath", unit, 0, unit)
	action.context["rng"] = rng
	combat.pipeline.submit(action)

func test_pangen_guards_each_breath() -> void:
	var player := _fighter("p", ["盘根诀"])
	var combat := _combat(player, _fighter("e"))
	assert_eq(player.guard, 0, "盘根诀是调息词条，战斗开始不触发")
	_breathe_action(combat, player)
	assert_eq(player.guard, 2, "调息时护境 +2")
	_breathe_action(combat, player)
	assert_eq(player.guard, 4, "再调息再 +2")

func test_yangmu_heals_each_breath() -> void:
	var player := _fighter("p", ["养木功"])
	var combat := _combat(player, _fighter("e"))
	player.hp = 20
	_breathe_action(combat, player)
	assert_eq(player.hp, 21, "养木功：调息回 1 气血")
	_breathe_action(combat, player)
	assert_eq(player.hp, 22, "再调息再回 1")

# 方向回归：调息锚心法只随本人调息触发（阶段二修复的旧隐患）
func test_breath_xinfa_not_fired_by_enemy_breath() -> void:
	var player := _fighter("p", ["盘根诀", "养木功"])
	var enemy := _fighter("e", [], ["点星式"])
	var combat := _combat(player, enemy)
	player.hp = 20
	_breathe_action(combat, enemy)
	assert_eq(player.guard, 0, "敌方调息不触发我方盘根诀")
	assert_eq(player.hp, 20, "敌方调息不触发我方养木功")
	_breathe_action(combat, player)
	assert_eq(player.guard, 2, "本人调息照常触发盘根诀")
	assert_eq(player.hp, 21, "本人调息照常触发养木功")

func test_tiaoxi_washes_back_highest_grade() -> void:
	# 调息诀：调息时手牌中随机一张最高品真气不入气海，改为洗入丹田（好气快回）
	var player := _fighter("p", ["调息诀"])
	# 从尾抽：起手＝尾 6（含两张上品 山3、林3；最高品＝上品，随机取其一）
	player.draw_pile = _cards([
		["山", 2], ["火", 2], ["火", 2], ["山", 2], ["火", 2], ["风", 2],
		["山", 3], ["火", 3], ["风", 2], ["山", 2], ["火", 2], ["林", 2],
		["风", 2], ["山", 3], ["火", 2], ["林", 3], ["火", 2], ["风", 2]], "p")
	var enemy := _fighter("e", [], ["点星式"])
	enemy.draw_pile = _cards([["火", 2], ["山", 2], ["林", 2], ["风", 2], ["火", 2], ["火", 2]], "e")
	var tm := TurnManager.new(_combat(player, enemy))
	tm.start_battle(false)
	var supremes: Array = []
	for card in player.hand:
		if card.grade == 3:
			supremes.append(card)
	assert_eq(supremes.size(), 2, "起手应含两张上品")
	tm.player_breathe()
	assert_eq(player.hand.size(), 6, "调息纳新 6 张")
	# 不变量：随机救回一张上品（丹田或被再抽回手），另一张照常入气海——
	# 气海里的上品至多 1 张
	var supremes_in_circulation := 0
	for card in player.hand + player.draw_pile:
		if card in supremes:
			supremes_in_circulation += 1
	assert_eq(supremes_in_circulation, 1, "两张上品恰有一张被洗回")
	var supremes_in_discard := 0
	for card in player.discard_pile:
		if card in supremes:
			supremes_in_discard += 1
	assert_eq(supremes_in_discard, 1, "另一张上品照常入气海")
	assert_eq(player.discard_pile.size(), 5, "只弃了另外 5 张")

# ---------- 气海无涯（调息行为改写） ----------

func test_qihaiwuyai_keeps_hand_and_draws_three() -> void:
	var player := _fighter("p", ["气海无涯"])
	player.draw_pile = _cards([
		["山", 2], ["火", 2], ["火", 2], ["山", 2], ["火", 2], ["风", 2],
		["风", 2], ["火", 2], ["山", 2], ["林", 2], ["火", 2], ["风", 2]], "p")
	var enemy := _fighter("e", [], ["点星式"])
	enemy.draw_pile = _cards([["火", 2], ["山", 2], ["林", 2], ["风", 2], ["火", 2], ["火", 2]], "e")
	var tm := TurnManager.new(_combat(player, enemy))
	tm.start_battle(false)
	var held = player.hand[0]
	var hand_before := player.hand.size()
	tm.player_breathe()
	assert_eq(player.hand.size(), hand_before + 3, "不弃手牌＋提 3 张（手牌净涨）")
	assert_true(player.hand.has(held), "捏着的真气不散")
	assert_eq(player.discard_pile.size(), 0, "气海无涯：一口都没弃")
	assert_eq(tm.combat.active_side, "enemy", "调息仍是链条终点")

# ---------- 化浊诀（触发冷却） ----------

func test_huazhuojue_bonus_and_cooldown() -> void:
	# 出招含下品：真气量+1；随后冷却 2 次自己的原子行动内不再触发
	var player := _fighter("p", ["化浊诀"], ["点星式"])
	var combat := _combat(player, _fighter("e"))
	combat.enemy.max_hp = 99
	combat.enemy.hp = 99
	var result := TechniqueResolver.resolve("点星式", [QiCard.new("l1", "风", 1)], player, combat.enemy, combat.pipeline)
	assert_eq(int(result.get("qi_amount", -1)), 1, "下品量0＋化浊诀+1")
	assert_eq(int(result.get("damage", 0)), 9, "伤 6+3×1")
	# 冷却 2：紧接着再出招不触发（纯函数结算不 tick 冷却，模拟行动开始手动推进前）
	var result2 := TechniqueResolver.resolve("点星式", [QiCard.new("l2", "风", 1)], player, combat.enemy, combat.pipeline)
	assert_eq(int(result2.get("qi_amount", -1)), 0, "冷却中不再加值")
	player.tick_cooldowns()
	var result3 := TechniqueResolver.resolve("点星式", [QiCard.new("l3", "风", 1)], player, combat.enemy, combat.pipeline)
	assert_eq(int(result3.get("qi_amount", -1)), 0, "冷却剩 1 次仍不触发")
	player.tick_cooldowns()
	var result4 := TechniqueResolver.resolve("点星式", [QiCard.new("l4", "风", 1)], player, combat.enemy, combat.pipeline)
	assert_eq(int(result4.get("qi_amount", -1)), 1, "冷却归零后再触发")
	# 无下品不触发（条件门控）
	var result5 := TechniqueResolver.resolve("点星式", [QiCard.new("m1", "火", 2)], player, combat.enemy, combat.pipeline)
	assert_eq(int(result5.get("qi_amount", -1)), 1, "中品量1，条件不满足不加值")

# ---------- 面板助手与 schema ----------

func test_effect_text_generated_from_data() -> void:
	var text := XinfaRuntime.effect_text("龟息功")
	assert_string_contains(text, "伤害结算时")
	assert_string_contains(text, "受到的伤害−1")
	var text2 := XinfaRuntime.effect_text("盘根诀")
	assert_string_contains(text2, "每次调息时")
	assert_string_contains(text2, "护境+2")
	var text3 := XinfaRuntime.effect_text("气海无涯")
	assert_string_contains(text3, "调息不再弃置手牌")
	assert_string_contains(text3, "从丹田提3张")
	var text4 := XinfaRuntime.effect_text("化浊诀")
	assert_string_contains(text4, "选入≥1张品级≤1的真气时")
	assert_string_contains(text4, "本次真气量+1")

func test_equipped_school_count() -> void:
	var v1_schools := ["先机诀", "养木功", "盘根诀"]
	assert_eq(XinfaRuntime.equipped_school_count(v1_schools, "风"), 1, "先机诀计风系")
	assert_eq(XinfaRuntime.equipped_school_count(v1_schools, "林"), 2, "养木功/盘根诀计林系")
	assert_eq(XinfaRuntime.equipped_school_count(["调息诀"], "风"), 0, "通用系不计入风系")

func test_validate_pack_rejects_bad_xinfa() -> void:
	var pack := {
		"items.json": DataRepo.items(),
		"enemies.json": DataRepo.enemies(),
		"techniques.json": DataRepo.techniques(),
		"statuses.json": DataRepo.statuses(),
		"xinfa.json": {
			"坏心法": {
				"tier": 9, "school": "雷", "desc": "",
				"effects": [{ "on": "不存在的时机", "do": { "type": "乱来" } }]
			}
		},
	}
	var errs := DataRepo.validate_pack(pack)
	var joined := "；".join(errs)
	assert_string_contains(joined, "tier")
	assert_string_contains(joined, "未知系别")
	assert_string_contains(joined, "desc")
	assert_string_contains(joined, "未知时机")
	assert_string_contains(joined, "未知动作类型")

func test_player_def_carries_xinfa() -> void:
	var player := EncounterLoader.load_player("res://data/player.json")
	assert_eq(player.xinfa.size(), 3, "玩家定义应带 3 门初始心法")
	for xf_id in player.xinfa:
		assert_false(XinfaRuntime.xinfa_data(xf_id).is_empty(), "初始心法应在 xinfa.json 中存在: " + xf_id)
