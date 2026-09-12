extends GutTest

# 背包条（背包＋穿戴＋锦囊三节）的布局回归钉子（C-025 返修补）：
# 1) 重复刷新尺寸必须稳定——旧槽位 queue_free 未死透时，新旧两代同列会让
#    get_combined_minimum_size() 按双倍行数算高（"操作后面板突然变大"的元凶）；
# 2) 所有节必须在面板内（锦囊行不得被裁）；
# 3) 穿戴区三槽（兵器/护具/行囊）随 M4 落地，重复刷新同样稳定。

func _bar() -> Panel:
	var bar: Panel = load("res://ui/backpack_bar.tscn").instantiate()
	add_child_autofree(bar)
	return bar

func _bag_entry(id: String) -> Dictionary:
	return {"id": id, "name": id, "rarity": "common", "value": 10, "qty": 1}

func _equipped() -> Dictionary:
	return {
		"weapon": {"id": "zhanlu", "name": "湛卢", "rarity": "legend", "value": 200, "qty": 1, "uid": 1, "dur": 8},
		"armor": {},
		"bag": {"id": "cubu", "name": "粗布行囊", "rarity": "common", "value": 10, "qty": 1, "uid": 2},
	}

func test_repeated_refresh_keeps_stable_size() -> void:
	var bar := _bar()
	bar.refresh([_bag_entry("a")], 12, -1, false, false, [], 2, -1, false)
	var first: Vector2 = bar.size
	for i in range(3):
		bar.refresh([_bag_entry("a"), _bag_entry("b")], 12, i, false, false,
			[_bag_entry("c")], 2, -1, false)
		assert_eq(bar.size, first, "第 %d 次刷新后面板尺寸应保持稳定" % (i + 1))

func test_wear_row_rebuilds_stably() -> void:
	var bar := _bar()
	bar.refresh([], 5, -1, false, false, [], 1, -1, false, _equipped(), "weapon")
	var first: Vector2 = bar.size
	assert_eq((bar.get_node("Box/WearRow") as HBoxContainer).get_children().size(), 3, "穿戴三槽")
	for i in range(3):
		bar.refresh([_bag_entry("a")], 5, 0, false, false, [], 1, -1, false,
			_equipped(), "" if i % 2 == 0 else "armor", true)
		assert_eq(bar.size, first, "第 %d 次刷新后尺寸稳定" % (i + 1))
	var wear_row: Control = bar.get_node("Box/WearRow")
	assert_true(wear_row.get_rect().end.y + 2.0 <= bar.size.y, "穿戴行不得超出面板")
	assert_true(bar.size.y < 300.0, "面板高 %.0f 异常膨胀" % bar.size.y)

func test_pouch_grid_fits_inside_panel() -> void:
	var bar := _bar()
	bar.refresh([_bag_entry("a")], 12, 0, false, false,
		[_bag_entry("c"), _bag_entry("d")], 2, 1, false)
	var pgrid: Control = bar.get_node("Box/PouchGrid")
	assert_true(pgrid.get_rect().end.y + 2.0 <= bar.size.y,
		"锦囊格底缘 (%.0f) 不得超出面板高 (%.0f)" % [pgrid.get_rect().end.y, bar.size.y])
	assert_true(bar.size.y < 300.0, "面板高 %.0f 异常膨胀" % bar.size.y)

func test_capacity_change_rebuilds_slots() -> void:
	var bar := _bar()
	bar.refresh([], 12, -1, false, false, [], 2, -1, false)
	assert_eq((bar.get_node("Box/Grid") as GridContainer).get_children().size(), 12, "背包 12 格")
	bar.refresh([], 12, -1, false, false, [], 4, -1, false)
	assert_eq((bar.get_node("Box/PouchGrid") as GridContainer).get_children().size(), 4, "锦囊升 4 格")
	assert_true(bar.size.y < 300.0, "扩格后高度仍单行")
