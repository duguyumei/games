extends GutTest

# 被动存档测试（C-028 网格版）：序列化往返全等、战前检查点可重试、终态不续玩、
# 无存档正常新开。

const TEST_SAVE_PATH := "user://test_expedition_save.json"

func after_each() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(TEST_SAVE_PATH)

# ---------- 构造工具（与 test_board_state.gd 同款受控配置） ----------

func _test_items() -> Dictionary:
	return {
		"ganliang": {"id": "ganliang", "name": "干粮", "rarity": "common", "value": 5},
		"yinzi": {"id": "yinzi", "name": "散碎银两", "rarity": "common", "value": 12},
		"jiansui": {"id": "jiansui", "name": "剑穗", "rarity": "fine", "value": 25},
		"yaoshi": {"id": "yaoshi", "name": "铜钥匙", "rarity": "common", "value": 6},
		"hujia": {"id": "hujia", "name": "牛皮护腕", "type": "armor", "rarity": "fine",
			"value": 35, "armor": {"level": 1, "base_dur": 4, "effects": []}},
	}

func _test_enemies() -> Dictionary:
	return {
		"落魄拳师": {"tier": "normal", "loot_chest": "pockets_test"},
		"山匪刀客": {"tier": "normal", "loot_chest": "pockets_test"},
	}

func _base_config() -> Dictionary:
	return {
		"name": "测试地点",
		"entrance_type": "entrance",
		"ap": {"start": 40, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [],
		"pursuer_table": ["山匪刀客"],
		"scatter_table": ["ganliang"],
		"chests": {
			"wood": {"name": "木箱", "ap_cost": 1, "draws": 3, "weights": {"common": 1}},
			"pockets_test": {"name": "行囊", "ap_cost": 1, "draws": 2, "table": ["yinzi", "ganliang"]},
		},
		"continent": {},
		"location_cards": {
			"room_card": {"name": "房间", "site_type": "room"},
		},
		"site_types": {
			"entrance": {"name": "入口", "cards": [], "bottom": []},
			"room": {"name": "房间", "cards": [{"kind": "scatter"}], "bottom": []},
		},
	}

func _board_with(cards: Array) -> BoardState:
	var cfg := _base_config()
	cfg["site_types"]["entrance"]["cards"] = cards
	var board := BoardState.new()
	board.config = cfg
	board.items = _test_items()
	board.enemies = _test_enemies()
	board.generate(7)
	return board

# 串一串动作制造丰富状态：背包叠放、开过的箱壳与遗体、锦囊、丢弃物、静音窗、
# 警戒中的敌牌、两地点连通、穿戴上身。
func _rich_board() -> BoardState:
	var board := _board_with([])
	# 直接铺网格，绕开洗牌拿到确定布局：
	# 0 散物 1 木箱 2 敌人 3 地点卡
	board.current_site()["grid"] = [
		{"kind": "scatter", "item_id": "ganliang"},
		board._make_card({"kind": "chest", "chest": "wood"}),
		board._make_card({"kind": "enemy", "table": ["落魄拳师"]}),
		{"kind": "location", "location": "room_card"},
	]
	board.pickup_cell(0)               # 入包（免费，留洞）
	board.open_cell(1)                 # 1 点开箱：内容物留在牌上（弹窗翻牌，D-028）
	board.flip_cell_content(1, 0)      # 翻一张 1 点
	board.take_cell_content(1, 0)      # 拿一张免费（翻/拿状态进档）
	board.move_to_pouch(0)             # 干粮收进贴身锦囊（免费）
	board.engage_cell(2)
	board.resolve_battle_result("win") # 0 行动力（C-028），敌人原地变遗体
	board.open_cell(2)                 # 1 点开盖搜遗体（东西还盖着）
	board.flip_cell_content(2, 0)      # 翻一半就走：剩一张暗牌在遗体里
	board.drop_item(0)                 # 丢一件进网格（免费）
	board.sneak_ap = 2                 # 迷踪香静音窗余量
	board.current_site()["grid"].append({"kind": "enemy", "enemy_id": "山匪刀客", "alert": 7, "primed": true})
	board.open_location_cell(3)        # 打开地点卡，长出新地块并抵达（免费）
	# 新地块里留一只警戒中的敌牌（别处衰减的序列化覆盖）
	board.travel_to(Vector2i(0, 0))    # 1 点，走回入口
	board._add_to_inventory(board._item("hujia"))  # 护具入包（装备实例）
	board.equip_from_inventory(0)      # 护具上身（免费）
	return board

# 走真实存档路径：to_dict → JSON 文本 → 解析 → from_dict。
func _roundtrip(board: BoardState) -> BoardState:
	var json_text := JSON.stringify(board.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	var restored := BoardState.new()
	restored.config = board.config
	restored.items = board.items
	restored.enemies = board.enemies
	restored.from_dict(parsed)
	return restored

func _run_state() -> Node:
	var rs: Node = preload("res://core/expedition/expedition_session.gd").new()
	rs.save_path = TEST_SAVE_PATH
	add_child_autofree(rs)
	return rs

# ---------- BoardState 序列化 ----------

func test_serialize_roundtrip_full_state() -> void:
	var board := _rich_board()
	var restored := _roundtrip(board)
	assert_eq(restored.seed, board.seed)
	assert_eq(restored.ap, board.ap)
	assert_eq(restored.ap_spent, board.ap_spent)
	assert_eq(restored.alert_level, board.alert_level, "警戒等级全等")
	assert_eq(restored.pursuers_spawned, board.pursuers_spawned)
	assert_eq(restored.outcome, board.outcome)
	assert_eq(restored.hero_site, board.hero_site)
	assert_eq(restored.sneak_ap, board.sneak_ap, "静音窗余量全等")
	assert_eq(restored.inventory, board.inventory, "背包全等")
	assert_eq(restored.pouch, board.pouch, "锦囊全等")
	assert_eq(restored.equipped, board.equipped, "穿戴栏全等")
	assert_eq(restored.sites, board.sites, "版图（网格/警戒值/准备标记）全等")
	assert_eq(restored.rng.state, board.rng.state, "rng state 全等")
	assert_eq(restored.rng.randi(), board.rng.randi(), "rng 可从中断处继续（测试辅助）")
	assert_eq(restored.to_dict(), board.to_dict(), "再序列化结果一致")
	var alerted := 0
	for pos in restored.sites:
		for entry in restored.sites[pos]["grid"]:
			var card: Dictionary = entry
			if not card.is_empty() and int(card.get("alert", 0)) == 7 and bool(card.get("primed", false)):
				alerted += 1
	assert_eq(alerted, 1, "警戒值/准备标记经 JSON 往返保真")
	var flipped_left := 0
	for pos in restored.sites:
		for entry in restored.sites[pos]["grid"]:
			var card: Dictionary = entry
			if not card.is_empty() and str(card.get("kind", "")) == "body":
				for content in card.get("contents", []):
					if bool((content as Dictionary).get("flipped", false)):
						flipped_left += 1
	assert_eq(flipped_left, 1, "容器内翻开的牌经 JSON 往返保真（回来接着翻）")

func test_restored_board_can_continue() -> void:
	var board := _rich_board()
	var restored := _roundtrip(board)
	var cell := -1
	for i in range((restored.current_site()["grid"] as Array).size()):
		if str((restored.current_site()["grid"][i] as Dictionary).get("kind", "")) == "scatter":
			cell = i
			break
	assert_true(cell >= 0, "恢复后网格里还有可捡的东西")
	assert_true(restored.pickup_cell(cell), "恢复后规则照常运转")
	assert_eq(restored.ap, board.ap, "拾取免费")
	var far := Vector2i(9, 9)
	for pos in restored.sites:
		if pos != restored.hero_site:
			far = pos
			break
	assert_true(restored.travel_to(far), "恢复后可移动")
	assert_eq(restored.ap, board.ap - 1, "移动 1 点")

func test_battle_checkpoint_resume_can_retry() -> void:
	# 战斗开始检查点 = 进战斗前的牌阵：敌人仍在网格里，远征未结束。
	var board := _board_with([{"kind": "enemy", "table": ["落魄拳师"]}])
	board.engage_cell(0)
	var restored := _roundtrip(board)
	assert_eq(restored.outcome, "", "战前检查点不是终态")
	assert_eq(restored.battle_cell, 0, "待战的网格位随档恢复")
	assert_eq(restored.engage_cell(0), "落魄拳师", "恢复后可重新迎战（合法 SL）")

# ---------- RunState 存档读写 ----------

func test_runstate_save_and_resume_roundtrip() -> void:
	var rs: Node = _run_state()
	rs.start_run(123)
	for pos in rs.board_state.sites:
		if pos != rs.board_state.hero_site:
			rs.board_state.travel_to(pos)  # 制造一点进度（移动 1 点）
			break
	rs.report_battle_result("win", 17)  # 模拟战斗结束写回
	rs.save_game()
	assert_true(rs.has_save(), "存档应存在且非终态")

	var rs2: Node = _run_state()
	assert_true(rs2.resume_from_save(), "启动应能续档")
	assert_true(rs2.is_in_expedition())
	assert_eq(rs2.carried_hp(), 17, "玩家气血随档恢复")
	assert_eq(rs2.carried_max_hp(), rs.carried_max_hp())
	assert_eq(rs2.board_state.to_dict(), rs.board_state.to_dict(), "牌阵状态全等")

func test_terminal_save_not_resumed() -> void:
	var rs: Node = _run_state()
	rs.start_run(123)
	rs.board_state.resolve_battle_result("lose")  # 死亡 → 终态（败北不走战斗位）
	rs.save_game()
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.READ)
	var saved: Variant = JSON.parse_string(file.get_as_text())
	assert_true(bool(saved.get("terminal", false)), "死亡存档应标记为终态")

	var rs2: Node = _run_state()
	assert_false(rs2.has_save(), "终态存档不可续玩")
	assert_false(rs2.resume_from_save())
	assert_false(rs2.is_in_expedition())

	# 开新局覆盖终态存档，之后可正常续玩
	rs2.start_run(456)
	rs2.save_game()
	var rs3: Node = _run_state()
	assert_true(rs3.resume_from_save(), "新局覆盖后可续玩")
	assert_eq(rs3.board_state.seed, 456)

func test_no_save_starts_fresh() -> void:
	var rs: Node = _run_state()
	assert_false(rs.has_save(), "无存档")
	assert_false(rs.resume_from_save(), "续档失败走新开")
	rs.start_run(1)
	assert_true(rs.is_in_expedition(), "无存档时正常新开")
	rs.save_game()
	assert_true(rs.has_save(), "探索开始落档")
