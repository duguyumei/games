extends GutTest

# 功法解释器（真气语法 v2）：固定三输入牌型门控＋威力＝基值＋系数×数值和＋一键补齐。

func _card(attr: String, value := 3) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, value, randi()], attr, value)

func test_technique_table_loads_entries() -> void:
	# 通用七门（含压制载体缠丝劲）＋剑法四门（共享同一功法池）
	assert_eq(TechniqueResolver.technique_ids().size(), 11, "通用七门＋剑法四门")

func test_unknown_technique_is_illegal() -> void:
	assert_false(TechniqueResolver.can_use("不存在的功法", [_card("风")]))

func test_empty_selection_is_illegal() -> void:
	assert_false(TechniqueResolver.can_use("点星式", []))

# 牌型门控：顺子技守顺、刻子技守刻
func test_dianxing_takes_shunzi_only() -> void:
	assert_true(TechniqueResolver.can_use("点星式", [_card("风", 3), _card("风", 4), _card("风", 5)]), "风345 顺子")
	assert_false(TechniqueResolver.can_use("点星式", [_card("风", 3), _card("风", 4), _card("风", 6)]), "跳档不成")
	assert_false(TechniqueResolver.can_use("点星式", [_card("山", 4), _card("山", 4), _card("山", 4)]), "刻子喂不顺子技")

func test_bengshan_takes_kezi_only() -> void:
	assert_true(TechniqueResolver.can_use("崩山式", [_card("山", 4), _card("山", 4), _card("山", 4)]), "山4 刻子")
	assert_false(TechniqueResolver.can_use("崩山式", [_card("山", 3), _card("山", 4), _card("山", 5)]), "顺子喂不进刻子技")
	assert_false(TechniqueResolver.can_use("崩山式", [_card("山", 4), _card("山", 4)]), "两张不够")

# 子集搜索：乱手里能捞出成型三张
func test_find_legal_selection_finds_shunzi_in_mixed_hand() -> void:
	var hand: Array = [
		_card("风", 3), _card("火", 6), _card("风", 5),
		_card("山", 4), _card("风", 4),
	]
	var selection := TechniqueResolver.find_legal_selection("点星式", hand)
	assert_eq(selection.size(), 3, "应找到风345 顺子")
	if selection.size() == 3:
		for card in selection:
			assert_eq(card.attribute, "风", "顺子必须同属性")

func test_find_legal_selection_returns_empty_when_impossible() -> void:
	# 全异属性：任何三张都接不成顺子，也无同数值三张
	var hand: Array = [
		_card("风", 2), _card("山", 3), _card("火", 4), _card("山", 5),
	]
	assert_eq(TechniqueResolver.find_legal_selection("点星式", hand).size(), 0, "全异属性凑不出顺子")

# 一键补齐（装配流）：以已选真气为前提搜索合法三张组
func test_containing_keeps_picked_and_completes() -> void:
	var hand: Array = [
		_card("风", 3), _card("火", 6), _card("风", 5),
		_card("山", 4), _card("风", 4),
	]
	# 已选 风3：点星式（顺子）应补 风4＋风5
	var selection := TechniqueResolver.find_legal_selection_containing("点星式", hand, [hand[0]])
	assert_eq(selection.size(), 3, "应在已选基础上补成顺子")
	assert_true(selection.has(hand[0]), "已选真气必须保留")

func test_containing_returns_empty_when_picked_breaks_pattern() -> void:
	var hand: Array = [
		_card("风", 3), _card("火", 6), _card("火", 5),
		_card("山", 4), _card("风", 4),
	]
	# 已选 火6（孤张异属性）：顺子永远凑不出
	assert_eq(TechniqueResolver.find_legal_selection_containing("点星式", hand, [hand[1]]).size(), 0, "已选孤张时顺子不可能")

# ---------- 结算 ----------

func test_dianxing_resolve_scales_with_value_sum() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	# 点星式＝2＋1×数值和；风345 数值和 12 → 14 点伤害
	var result := TechniqueResolver.resolve("点星式", [_card("风", 3), _card("风", 4), _card("风", 5)], user, target)
	assert_true(bool(result.get("ok", false)))
	assert_eq(target.hp, 99 - 14, "2＋1×12＝14 点伤害")
	assert_eq(int(result.get("qi_amount", -1)), 12, "战报上下文应携带数值和")

func test_kezi_value_sum_is_triple_value() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	# 崩山式＝2＋1×数值和；山4×3 数值和 12 → 14 点伤害（与顺子345同和同伤——力度只看和）
	var result := TechniqueResolver.resolve("崩山式", [_card("山", 4), _card("山", 4), _card("山", 4)], user, target)
	assert_true(bool(result.get("ok", false)))
	assert_eq(target.hp, 99 - 14, "刻子数值和＝3×4＝12，同 2＋12")

func test_illegal_resolve_is_rejected() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	var result := TechniqueResolver.resolve("点星式", [_card("火", 4), _card("火", 4)], user, target)
	assert_false(bool(result.get("ok", false)))
	assert_eq(target.hp, 99, "非法发动不应造成伤害")

# 高低顺的力度差：风678（和21）明显重于风234（和9）
func test_high_shunzi_hits_harder_than_low() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target_low := FighterState.new("t1", "靶甲", 99)
	var target_high := FighterState.new("t2", "靶乙", 99)
	TechniqueResolver.resolve("点星式", [_card("风", 2), _card("风", 3), _card("风", 4)], user, target_low)
	TechniqueResolver.resolve("点星式", [_card("风", 6), _card("风", 7), _card("风", 8)], user, target_high)
	assert_eq(target_low.hp, 99 - 11, "风234＝2＋9")
	assert_eq(target_high.hp, 99 - 23, "风678＝2＋21")
