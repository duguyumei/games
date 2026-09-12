extends GutTest

# v1 牌型判定（属性轴）：一气／重族（同属性 N）／合族（异属性 N），选牌上限 4。

func _card(attr: String, grade := 2) -> QiCard:
	return QiCard.new("%s%d" % [attr, randi()], attr, grade)

func test_one_qi() -> void:
	assert_has(PatternEvaluator.evaluate([_card("风")]), PatternEvaluator.ONE_QI)

func test_heavy_2() -> void:
	assert_has(PatternEvaluator.evaluate([_card("火"), _card("火")]), PatternEvaluator.HEAVY_2)

func test_heavy_3() -> void:
	assert_has(PatternEvaluator.evaluate([_card("山", 1), _card("山", 2), _card("山", 3)]), PatternEvaluator.HEAVY_3)

func test_heavy_4() -> void:
	var cards: Array = []
	for i in range(4):
		cards.append(_card("风", 1 + i % 3))
	assert_has(PatternEvaluator.evaluate(cards), PatternEvaluator.HEAVY_4)

func test_mix_2() -> void:
	assert_has(PatternEvaluator.evaluate([_card("风"), _card("火")]), PatternEvaluator.MIX_2)

func test_mix_3() -> void:
	assert_has(PatternEvaluator.evaluate([_card("风"), _card("林"), _card("火")]), PatternEvaluator.MIX_3)

func test_mix_4() -> void:
	assert_has(PatternEvaluator.evaluate([_card("风"), _card("林"), _card("火"), _card("山")]), PatternEvaluator.MIX_4)

# 品级不参与牌型：同属性不同品级照样构成重族
func test_grade_does_not_matter_for_heavy() -> void:
	assert_has(PatternEvaluator.evaluate([_card("林", 1), _card("林", 3)]), PatternEvaluator.HEAVY_2)

# 混合构成（两同一异）既非重也非合
func test_two_same_one_diff_is_no_pattern() -> void:
	var cards: Array = [_card("风"), _card("风"), _card("火")]
	assert_eq(PatternEvaluator.evaluate(cards).size(), 0, "风风火不成任何牌型")

func test_two_same_two_diff_is_no_pattern() -> void:
	var cards: Array = [_card("风"), _card("风"), _card("火"), _card("山")]
	assert_eq(PatternEvaluator.evaluate(cards).size(), 0, "风风火山不成任何牌型")

# 选牌上限 4：第 5 张不构成任何牌型
func test_five_cards_form_no_pattern() -> void:
	var cards: Array = [_card("风"), _card("林"), _card("火"), _card("山"), _card("风")]
	assert_eq(PatternEvaluator.evaluate(cards).size(), 0, "5 张超出选牌上限")

func test_empty_is_no_pattern() -> void:
	assert_eq(PatternEvaluator.evaluate([]).size(), 0)

func test_pattern_names() -> void:
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.ONE_QI), "一气")
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.HEAVY_2), "二重")
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.HEAVY_4), "四重")
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.MIX_2), "二合")
	assert_eq(PatternEvaluator.pattern_name(PatternEvaluator.MIX_4), "四合")
