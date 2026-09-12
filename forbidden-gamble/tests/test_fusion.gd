extends GutTest

# 融合规则（《战斗系统底层_v1》§1）：同属性同品级 2→1、品级＋1；上品封顶；牌库下限 12。
# v1 免费、手动（演武场"凝"按钮）——数量换质量是构筑决策，不自动化。

func test_two_of_same_grade_can_fuse() -> void:
	assert_true(bool(FusionRules.can_fuse(2, 1, 14).get("ok")), "两张下品可凝成一张中品")
	assert_true(bool(FusionRules.can_fuse(5, 2, 20).get("ok")), "多张也可凝（一次净减 1）")

func test_supreme_is_capped() -> void:
	var verdict: Dictionary = FusionRules.can_fuse(4, 3, 20)
	assert_false(bool(verdict.get("ok")), "上品封顶")
	assert_string_contains(str(verdict.get("reason", "")), "封顶")

func test_needs_at_least_two() -> void:
	var verdict: Dictionary = FusionRules.can_fuse(1, 1, 20)
	assert_false(bool(verdict.get("ok")), "单张不可凝")
	assert_string_contains(str(verdict.get("reason", "")), "2 张")

func test_deck_floor_blocks_fusion() -> void:
	assert_false(bool(FusionRules.can_fuse(3, 1, 12).get("ok")), "总数 12 时再凝会破下限")
	assert_true(bool(FusionRules.can_fuse(3, 1, 13).get("ok")), "总数 13 可凝到 12（恰好贴住下限）")

# 计数格"凝"按钮显隐：下/中品且 ≥2 张才出现（上品封顶，单张无从凝起）
func test_fuse_button_visibility() -> void:
	var cell: QiCountCell = preload("res://ui/qi_count_cell.tscn").instantiate()
	add_child_autofree(cell)
	cell.setup(1, 2)
	assert_true((cell.get_node("FuseButton") as Button).visible, "下品×2 应显示凝按钮")
	cell.setup(2, 2)
	assert_true((cell.get_node("FuseButton") as Button).visible, "中品×2 应显示凝按钮")
	cell.setup(3, 5)
	assert_false((cell.get_node("FuseButton") as Button).visible, "上品封顶不显示")
	cell.setup(1, 1)
	assert_false((cell.get_node("FuseButton") as Button).visible, "不足 2 张不显示")

# set_count 外部改数后计数与通知链保持
func test_set_count_updates_and_notifies() -> void:
	var cell: QiCountCell = preload("res://ui/qi_count_cell.tscn").instantiate()
	add_child_autofree(cell)
	cell.setup(1, 4)
	var notified := [0]
	cell.count_changed.connect(func(): notified[0] += 1)
	cell.set_count(2)
	assert_eq(cell.count, 2)
	assert_eq((cell.get_node("CountLabel") as Label).text, "×2")
	assert_eq(notified[0], 1, "外部改数也走通知链（合计行刷新）")
