extends GutTest

# 真气语法 v2 牌型判定：刻子（三张全同）／顺子（同属性数值连三）＋吃碰杠搭子检测。

func _card(attr: String, value := 3) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, value, randi()], attr, value)

func test_kezi() -> void:
	assert_has(PatternEvaluator.evaluate([_card("山", 4), _card("山", 4), _card("山", 4)]), PatternEvaluator.KEZI)

func test_shunzi() -> void:
	assert_has(PatternEvaluator.evaluate([_card("风", 3), _card("风", 5), _card("风", 4)]), PatternEvaluator.SHUNZI)

# 刻子要求三张全同：数值不同即非刻子
func test_same_attr_diff_value_not_kezi() -> void:
	assert_eq(PatternEvaluator.evaluate([_card("山", 3), _card("山", 4), _card("山", 5)]).size(), 1, "山345 是顺子不是刻子")
	assert_eq(PatternEvaluator.evaluate([_card("山", 3), _card("山", 3), _card("山", 4)]).size(), 0, "山3山3山4 不成牌型")

# 顺子要求同属性：异属性连三不成
func test_shunzi_needs_same_attribute() -> void:
	assert_eq(PatternEvaluator.evaluate([_card("风", 3), _card("火", 4), _card("山", 5)]).size(), 0, "异属性连三不成顺子")

# 顺子要求连续：跳档不成
func test_shunzi_needs_consecutive() -> void:
	assert_eq(PatternEvaluator.evaluate([_card("风", 3), _card("风", 4), _card("风", 6)]).size(), 0, "3-4-6 不成顺子")

# 边界窗：2-3-4 与 6-7-8 都成
func test_shunzi_boundary_windows() -> void:
	assert_has(PatternEvaluator.evaluate([_card("火", 2), _card("火", 3), _card("火", 4)]), PatternEvaluator.SHUNZI)
	assert_has(PatternEvaluator.evaluate([_card("火", 6), _card("火", 7), _card("火", 8)]), PatternEvaluator.SHUNZI)

# 张数不是三张不成牌型（一两张只是搭子、四张超出输入）
func test_wrong_size_no_pattern() -> void:
	assert_eq(PatternEvaluator.evaluate([_card("风", 3)]).size(), 0)
	assert_eq(PatternEvaluator.evaluate([_card("风", 3), _card("风", 3)]).size(), 0, "两张＝搭子不是输入")
	assert_eq(PatternEvaluator.evaluate([_card("风", 3), _card("风", 3), _card("风", 3), _card("风", 3)]).size(), 0, "四张超出固定三输入")

func test_empty_is_no_pattern() -> void:
	assert_eq(PatternEvaluator.evaluate([]).size(), 0)

func test_pattern_names() -> void:
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.KEZI), "刻子")
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.SHUNZI), "顺子")

# ---------- 吃碰杠搭子检测 ----------

func test_can_pon_with_two_copies() -> void:
	var river_card := _card("山", 5)
	var hand: Array = [_card("山", 5), _card("山", 5), _card("风", 3)]
	assert_true(PatternEvaluator.can_pon(hand, river_card), "手里两张山5 可碰")
	assert_false(PatternEvaluator.can_kan(hand, river_card), "两张不够杠")

func test_can_kan_with_three_copies() -> void:
	var river_card := _card("山", 5)
	var hand: Array = [_card("山", 5), _card("山", 5), _card("山", 5)]
	assert_true(PatternEvaluator.can_kan(hand, river_card), "手里三张山5 可杠")
	assert_true(PatternEvaluator.can_pon(hand, river_card), "三张当然也可碰")

func test_pon_needs_same_value() -> void:
	var river_card := _card("山", 5)
	var hand: Array = [_card("山", 4), _card("山", 4)]
	assert_false(PatternEvaluator.can_pon(hand, river_card), "山4 山4 截不动河里的山5")

func test_chi_melds() -> void:
	var river_card := _card("风", 4)
	var hand: Array = [_card("风", 3), _card("风", 5), _card("山", 4)]
	var melds := PatternEvaluator.chi_melds(hand, river_card)
	assert_eq(melds.size(), 1, "风3＋风5 可吃风4")
	assert_true(PatternEvaluator.same_tile(melds[0][0], hand[0]) or PatternEvaluator.same_tile(melds[0][0], hand[1]))
	# 同属性但接不上：吃不动
	var hand2: Array = [_card("风", 3), _card("风", 6), _card("山", 4)]
	assert_eq(PatternEvaluator.chi_melds(hand2, river_card).size(), 0, "风3＋风6 接不上风4")
