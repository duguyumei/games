extends GutTest

# 组挑战·RunShop 修习（代码设计 v1.4 §4.2）：货架确定性/去重/重掷涨价与重置/
# 购买扣款与槽位校验回滚/疗伤丹限购回血钳值/开槽价递增/三选一空位过滤＋牌灵补位/池尽明码。


func _shop() -> Dictionary:
	return DataRepo.mj_shop()


func _state(wins := 1) -> RunState:
	var state := RunState.new()
	state.start(DataRepo.mj_decks()["basic"], 42)
	for _i in range(wins):
		state.apply_result("player", 6000, 10)
	state.lianli = 500  # 测试预算
	return state


func test_shelf_deterministic_and_dedup() -> void:
	var a := _state()
	var b := _state()
	RunShop.roll_shelf(a, _shop())
	RunShop.roll_shelf(b, _shop())
	assert_eq(a.shelf.size(), b.shelf.size())
	for i in range(a.shelf.size()):
		assert_eq((a.shelf[i] as Dictionary)["id"], (b.shelf[i] as Dictionary)["id"], "同键同货架")
	var ids: Array = []
	for item in a.shelf:
		ids.append((item as Dictionary)["id"])
	assert_eq(ids.size(), (ids as Array).size(), "无重复占位")
	# 结构：武学×2＋牌灵×1（不按槽位过滤——购买时校验）
	var wuxue_count := 0
	var pailing_count := 0
	for item in a.shelf:
		if String((item as Dictionary)["cat"]) == "wuxue":
			wuxue_count += 1
		else:
			pailing_count += 1
	assert_eq(wuxue_count, 2)
	assert_eq(pailing_count, 1)


func test_reroll_escalates_and_resets() -> void:
	var state := _state()
	RunShop.roll_shelf(state, _shop())
	assert_eq(RunShop.reroll_cost(state, _shop()), 10)
	assert_true(RunShop.reroll(state, _shop()))
	assert_eq(RunShop.reroll_cost(state, _shop()), 15)
	assert_true(RunShop.reroll(state, _shop()))
	assert_eq(RunShop.reroll_cost(state, _shop()), 20)
	state.begin_visit()
	assert_eq(RunShop.reroll_cost(state, _shop()), 10, "每次修习重置")


func test_buy_deducts_and_marks() -> void:
	var state := _state()
	RunShop.roll_shelf(state, _shop())
	# 找一件武学：先开对应轨槽再买（购买时校验槽位）
	for i in range(state.shelf.size()):
		var item: Dictionary = state.shelf[i]
		if item["cat"] == "wuxue":
			RunShop.unlock_slot(state, _shop(), String(item["kind"]))
			var before := state.lianli
			assert_eq(RunShop.buy(state, _shop(), i), "wuxue")
			assert_eq(state.lianli, before - int(item["price"]))
			assert_true(bool(item["bought"]))
			assert_eq(RunShop.buy(state, _shop(), i), "", "已购不可再买")
			return
	fail_test("货架上应有武学")


func test_buy_wuxue_rolls_back_when_slot_full() -> void:
	var state := _state()  # 三槽全满（起始件占位）
	RunShop.roll_shelf(state, _shop())
	# 找一件武学（不按槽过滤，货架必有）——槽满时应回滚
	for i in range(state.shelf.size()):
		var item: Dictionary = state.shelf[i]
		if item["cat"] == "wuxue":
			var before := state.lianli
			assert_eq(RunShop.buy(state, _shop(), i), "", "槽满购买失败")
			assert_eq(state.lianli, before, "扣款回滚")
			assert_false(bool(item["bought"]))
			RunShop.unlock_slot(state, _shop(), String(item["kind"]))
			assert_eq(RunShop.buy(state, _shop(), i), "wuxue", "开槽后可买")
			return
	fail_test("货架上应有武学")


func test_heal_once_per_visit_and_clamped() -> void:
	var state := _state()
	state.hp_fp = 9500
	assert_eq(RunShop.buy_heal(state, _shop()), 500, "即买即用钳于上限")
	assert_eq(RunShop.buy_heal(state, _shop()), -1, "每修习限购一枚")
	state.begin_visit()
	state.hp_fp = 1000
	assert_eq(RunShop.buy_heal(state, _shop()), 6000)


func test_slot_unlock_cost_escalates() -> void:
	var state := _state()
	assert_eq(RunShop.slot_unlock_cost(state, _shop()), 20)
	assert_true(RunShop.unlock_slot(state, _shop(), "gongfa"))
	assert_eq(RunShop.slot_unlock_cost(state, _shop()), 35, "已解锁+1 → 涨")
	assert_true(RunShop.unlock_slot(state, _shop(), "xinfa"))
	assert_eq(RunShop.slot_unlock_cost(state, _shop()), 50)
	state.lianli = 2000  # 推满预算（12 枚总解锁价 20×12＋15×66＝1230）
	for kind in ["gongfa", "xinfa", "hushen"]:
		while int(state.slot_caps[kind]) < 5:
			assert_true(RunShop.unlock_slot(state, _shop(), kind))
	assert_eq(int(state.slot_caps["gongfa"]), 5)
	assert_eq(int(state.slot_caps["xinfa"]), 5)
	assert_eq(int(state.slot_caps["hushen"]), 5)
	for kind in ["gongfa", "xinfa", "hushen"]:
		assert_false(RunShop.unlock_slot(state, _shop(), kind), "达上限 5 拒绝")


func test_pick3_filters_full_slots_and_fills_pailing() -> void:
	var state := _state()  # 战①胜后：三槽全满
	var picks := RunShop.roll_pick3(state, _shop())
	assert_eq(picks.size(), 3, "永远给满三")
	for item in picks:
		assert_eq(String((item as Dictionary)["cat"]), "pailing", "槽满时全为牌灵补位")
	# 开槽后武学进入三选一
	RunShop.unlock_slot(state, _shop(), "gongfa")
	picks = RunShop.roll_pick3(state, _shop())
	var wuxue_seen := false
	for item in picks:
		if String((item as Dictionary)["cat"]) == "wuxue":
			wuxue_seen = true
	assert_true(wuxue_seen, "有空位类型后武学入选项")


func test_take_pick_wuxue_and_pailing() -> void:
	var state := _state()
	RunShop.unlock_slot(state, _shop(), "xinfa")
	assert_true(RunShop.take_pick(state, "xi_lian_jue", "wuxue", "xinfa"))
	assert_false(RunShop.take_pick(state, "yun_zhou_jue", "wuxue", "xinfa"), "槽位只开了一个")
	assert_true(RunShop.take_pick(state, "ling_gang", "pailing", "", "万5"))
	assert_eq(state.pailing["万5"], "ling_gang")


func test_pool_exhaustion_shows_empty() -> void:
	var state := _state()
	# 买空牌灵池（4 枚）
	for id_str in ["ling_gang", "ling_zhong", "ling_bian", "ling_jia"]:
		state.acquire_pailing(id_str, "万%d" % (1 + ["ling_gang", "ling_zhong", "ling_bian", "ling_jia"].find(id_str)))
	RunShop.roll_shelf(state, _shop())
	var pailing_on_shelf := 0
	for item in state.shelf:
		if String((item as Dictionary)["cat"]) == "pailing":
			pailing_on_shelf += 1
	assert_eq(pailing_on_shelf, 0, "牌灵池尽→缺位（UI 明码宝山已空）")
