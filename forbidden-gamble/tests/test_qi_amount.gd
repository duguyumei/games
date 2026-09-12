extends GutTest

# v1 真气量与数值语法（《战斗系统底层_v1》§3/§6）：
# 真气量 ＝ Σ(品级值 − 功法等级)；效果 ＝ 基值 ＋ 系数 × 真气量（＋每张上品加成），下限 0。

func _card(attr: String, grade: int) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, grade, randi()], attr, grade)

# ---------- 量行 ----------

func test_level1_amount_row() -> void:
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 1)], 1), 0, "等级1下品＝0")
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 2)], 1), 1, "等级1中品＝1")
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 3)], 1), 2, "等级1上品＝2")

func test_level2_amount_row() -> void:
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 1)], 2), -1, "等级2下品＝−1（负贡献允许）")
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 2)], 2), 0, "等级2中品＝0")
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 3)], 2), 1, "等级2上品＝1")

func test_amount_sums_and_modifier() -> void:
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 3), _card("风", 1)], 1), 2)
	assert_eq(QiAmountCalculator.qi_amount([_card("风", 1), _card("火", 1)], 2, 5), 3, "修正并入合计")

# ---------- 效果值（基值＋系数×量，钳 0）----------

func test_effect_value_formula() -> void:
	var effect := {"type": "damage", "base": 6, "scale": 3}
	assert_eq(TechniqueResolver.effect_value(effect, 1, []), 9)
	assert_eq(TechniqueResolver.effect_value(effect, 0, []), 6)

func test_effect_value_clamps_at_zero() -> void:
	var effect := {"type": "damage", "base": 10, "scale": 5}
	assert_eq(TechniqueResolver.effect_value(effect, -2, []), 0, "负真气量把效果压到 0，不倒扣")

func test_effect_value_per_supreme() -> void:
	var effect := {"type": "damage", "base": 4, "scale": 1, "per_supreme": 1}
	var two_supremes: Array = [_card("火", 3), _card("火", 3)]
	assert_eq(TechniqueResolver.effect_value(effect, 4, two_supremes), 10, "量4＋两张上品＝4+4+2")
	var no_supremes: Array = [_card("火", 1), _card("火", 1)]
	assert_eq(TechniqueResolver.effect_value(effect, 0, no_supremes), 4)

# ---------- 九门数值表（逐门钉住）----------

func _resolve(tech_id: String, cards: Array) -> Dictionary:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	return TechniqueResolver.resolve(tech_id, cards, user, target)

func test_dianxing_damage_table() -> void:
	assert_eq(int(_resolve("点星式", [_card("风", 1)]).get("damage", -1)), 6)
	assert_eq(int(_resolve("点星式", [_card("风", 2)]).get("damage", -1)), 9)
	assert_eq(int(_resolve("点星式", [_card("风", 3)]).get("damage", -1)), 12)

func test_lianfeng_two_segments_table() -> void:
	# 双段：总伤按靶子气血核验（result.damage 只记最后一段）
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	TechniqueResolver.resolve("连风式", [_card("火", 1), _card("火", 1)], user, target)
	assert_eq(target.hp, 91, "下下：每段 4，双段 8")
	target = FighterState.new("t2", "靶子", 99)
	TechniqueResolver.resolve("连风式", [_card("火", 2), _card("火", 2)], user, target)
	assert_eq(target.hp, 87, "中中：量2 每段 6，双段 12")
	target = FighterState.new("t3", "靶子", 99)
	TechniqueResolver.resolve("连风式", [_card("火", 3), _card("火", 3)], user, target)
	assert_eq(target.hp, 79, "上上：量4＋上品加成 每段 10，双段 20")

func test_zongheng_soft_gate_table() -> void:
	assert_eq(int(_resolve("纵横式", [_card("风", 1), _card("火", 1)]).get("damage", -1)), 0, "下下＝软门槛空转")
	assert_eq(int(_resolve("纵横式", [_card("风", 2), _card("火", 2)]).get("damage", -1)), 10)
	assert_eq(int(_resolve("纵横式", [_card("风", 2), _card("火", 3)]).get("damage", -1)), 15)
	assert_eq(int(_resolve("纵横式", [_card("风", 3), _card("火", 3)]).get("damage", -1)), 20)

func test_ju_guard_table() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	var result := TechniqueResolver.resolve("一气·拒", [_card("风", 1)], user, target)
	assert_true(bool(result.get("ok", false)))
	# 护境值打在使用者身上：一气·拒 下5/中8/上11
	user.guard = 0
	TechniqueResolver.resolve("一气·拒", [_card("风", 3)], user, target)
	assert_eq(user.guard, 11)

func test_bi_guard_table() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	TechniqueResolver.resolve("二重·壁", [_card("山", 1), _card("山", 1)], user, target)
	assert_eq(user.guard, 7)
	user.guard = 0
	TechniqueResolver.resolve("二重·壁", [_card("山", 2), _card("山", 2)], user, target)
	assert_eq(user.guard, 11)
	user.guard = 0
	TechniqueResolver.resolve("二重·壁", [_card("山", 3), _card("山", 3)], user, target)
	assert_eq(user.guard, 15)

func test_ping_guard_uses_mix_pair() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	TechniqueResolver.resolve("二合·屏", [_card("风", 3), _card("火", 3)], user, target)
	assert_eq(user.guard, 15, "二合两张上品量4：7+2×4＝15")

func test_yin_draws_scaled() -> void:
	# 引＝提 1＋量 张（净牌口径按行动计：纯函数调用不散牌，这里只验提牌数）。
	# draw 效果需管线 draw 结算器与 rng——用 CombatState 的管线。
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var target := FighterState.new("t", "靶子", 99)
	for grade in range(1, 4):
		var user := FighterState.new("u%d" % grade, "测试者", 99)
		for i in range(20):
			user.draw_pile.append(_card("风", 1))
		var qi := _card("火", grade)
		user.hand.append(qi)
		var combat := CombatState.new(user, target)
		TechniqueResolver.resolve("一气·引", [qi], user, target, combat.pipeline, rng)
		assert_eq(user.hand.size(), 1 + grade, "品级%d 应提 %d 张" % [grade, grade])

func test_huan_draws_three() -> void:
	# 换＝另提 3 张（纯函数调用不散牌；净+1 口径由行动层结算）
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var user := FighterState.new("u", "测试者", 99)
	for i in range(20):
		user.draw_pile.append(_card("风", 1))
	var target := FighterState.new("t", "靶子", 99)
	user.hand.append_array([_card("火", 1), _card("火", 1)])
	var combat := CombatState.new(user, target)
	TechniqueResolver.resolve("二重·换", [user.hand[0], user.hand[1]], user, target, combat.pipeline, rng)
	assert_eq(user.hand.size(), 5, "原2张＋提3张")
