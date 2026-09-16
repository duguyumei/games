extends GutTest

# 六式（真气语法 v3 §4）：符号表、暗式检测（先刻后顺）。
# 式基本招伤害系统已随 v3.5 普攻体系退役（伤害走打出阶梯）。


func _t(suit: String, value: int) -> MJTile:
	return MJTile.make(suit, value)


func test_symbol_table() -> void:
	assert_eq(MJShiki.symbol_for(MJShiki.LIGHT, "万"), "点")
	assert_eq(MJShiki.symbol_for(MJShiki.HEAVY, "万"), "崩")
	assert_eq(MJShiki.symbol_for(MJShiki.LIGHT, "筒"), "刺")
	assert_eq(MJShiki.symbol_for(MJShiki.HEAVY, "筒"), "劈")
	assert_eq(MJShiki.symbol_for(MJShiki.LIGHT, "条"), "碾")
	assert_eq(MJShiki.symbol_for(MJShiki.HEAVY, "条"), "撼")
	assert_eq(MJShiki.suit_of("崩"), "万")
	assert_eq(MJShiki.weight_of("点"), MJShiki.LIGHT)


func test_find_groups_kezi() -> void:
	var hand: Array = [_t("万", 5), _t("万", 5), _t("万", 5), _t("条", 1)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 1)
	assert_eq(String(groups[0]["kind"]), MJShiki.HEAVY)
	assert_eq(String(groups[0]["symbol"]), "崩")


func test_find_groups_shunzi() -> void:
	var hand: Array = [_t("筒", 3), _t("筒", 5), _t("筒", 4), _t("条", 9)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 1)
	assert_eq(String(groups[0]["kind"]), MJShiki.LIGHT)
	assert_eq(String(groups[0]["symbol"]), "刺")


func test_find_groups_mixed_ke_first() -> void:
	# 万5×3（刻）＋万6、筒1筒2筒3（顺）——刻顺共存
	var hand: Array = [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 6),
		_t("筒", 1), _t("筒", 2), _t("筒", 3)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 2)
	var kinds := {}
	for g in groups:
		kinds[String(g["kind"])] = true
	assert_true(kinds.has(MJShiki.HEAVY) and kinds.has(MJShiki.LIGHT))


func test_two_copies_are_not_group() -> void:
	var hand: Array = [_t("条", 5), _t("条", 5), _t("条", 9)]
	assert_eq(MJShiki.find_groups(hand).size(), 0, "对子只是搭子")


func test_duplicate_runs_both_found() -> void:
	# 万5-6-7 ×2：同型双顺各成一组（配方 点×2 可付的前提）
	var hand: Array = [_t("万", 5), _t("万", 6), _t("万", 7), _t("万", 5), _t("万", 6), _t("万", 7)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 2, "单遍扫描不回访会吞掉第二组同顺")


func test_failed_run_leaves_no_leak() -> void:
	# 万4＋万6 无万5：失败的顺线尝试不得吞掉万6（其后 万6-7-8 仍可成顺）
	var hand: Array = [_t("万", 4), _t("万", 6), _t("万", 7), _t("万", 8)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 1)
	assert_eq(String(groups[0]["symbol"]), "点", "万6-7-8 成顺（旧实现会泄漏吞掉万6）")


func test_cross_suit_run_not_group() -> void:
	var hand: Array = [_t("万", 4), _t("筒", 5), _t("条", 6)]
	assert_eq(MJShiki.find_groups(hand).size(), 0, "异属性连三不成顺")


func test_shared_tile_cannot_double_count() -> void:
	# 万5×3 只有三个：成刻后不能同时再参与顺
	var hand: Array = [_t("万", 5), _t("万", 5), _t("万", 5), _t("万", 4), _t("万", 6)]
	var groups := MJShiki.find_groups(hand)
	assert_eq(groups.size(), 1, "五张里刻子优先，余两张不成顺")


func test_find_symbol() -> void:
	var hand: Array = [_t("条", 7), _t("条", 7), _t("条", 7), _t("万", 1)]
	var group := MJShiki.find_symbol(hand, "撼")
	assert_false(group.is_empty())
	assert_eq((group["tiles"] as Array).size(), 3)
	assert_true(MJShiki.find_symbol(hand, "点").is_empty(), "没有万顺")
