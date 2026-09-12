extends GutTest

# BoardState 规则测试（C-028 明牌网格版）：构造配置精确控制网格，真实配置验证
# 种子确定性与整局重放。

const LOCATION_PATH := "res://data/location_qingfeng.json"
const ITEMS_PATH := "res://data/items.json"
const ENEMIES_PATH := "res://data/enemies.json"

# ---------- 构造工具 ----------

func _test_items() -> Dictionary:
	return {
		"ganliang": {"id": "ganliang", "name": "干粮", "rarity": "common", "value": 5},
		"yinzi": {"id": "yinzi", "name": "散碎银两", "rarity": "common", "value": 12},
		"jiansui": {"id": "jiansui", "name": "剑穗", "rarity": "fine", "value": 25},
		"yaoshi": {"id": "yaoshi", "name": "铜钥匙", "rarity": "common", "value": 6},
	}

func _test_enemies() -> Dictionary:
	return {
		"落魄拳师": {"tier": "normal", "loot_chest": "pockets_test"},
		"山匪刀客": {"tier": "normal", "loot_chest": "pockets_test"},
		"青锋剑徒": {"tier": "veteran", "loot_chest": "pockets_test"},
		"执法长老": {"tier": "elite", "loot_chest": "pockets_test"},
		"青锋宗主": {"tier": "master", "loot_chest": "pockets_test"},
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
		"npcs": {
			"test_npc": {"name": "行脚商人", "lines": ["前面的路可不太平。"]},
		},
		"chests": {
			"wood": {"name": "木箱", "ap_cost": 1, "draws": 3, "weights": {"common": 1}},
			"pockets_test": {"name": "行囊", "ap_cost": 1, "draws": 2, "table": ["yinzi", "ganliang"]},
		},
		"continent": {},
		"location_cards": {
			"room_card": {"name": "房间", "site_type": "room"},
			"shortcut_card": {"name": "捷径", "effect": "shortcut"},
			"locked_card": {"name": "上锁的房间", "site_type": "locked", "require_item": "yaoshi"},
			"cheli_card": {"name": "撤离点", "site_type": "duanya"},
		},
		"site_types": {
			"entrance": {"name": "入口", "cards": [], "bottom": []},
			"room": {"name": "房间", "cards": [{"kind": "scatter"}], "bottom": []},
			"locked": {"name": "上锁的房间", "cards": [{"kind": "chest", "chest": "wood"}], "bottom": []},
			"duanya": {"name": "后山·断崖", "extract": true, "cards": [], "bottom": []},
		},
	}

# 构造一个 BoardState：入口网格为 cards，extra 覆盖配置顶层键。
func _board_with(cards: Array, extra: Dictionary = {}, start_ap: int = 40) -> BoardState:
	var cfg := _base_config()
	cfg["site_types"]["entrance"]["cards"] = cards
	for key in extra:
		cfg[key] = extra[key]
	cfg["ap"]["start"] = start_ap
	var board := BoardState.new()
	board.config = cfg
	board.items = _test_items()
	board.enemies = _test_enemies()
	board.generate(7)
	return board

func _real_board(new_seed: int) -> BoardState:
	var board := BoardState.new()
	assert_true(board.load(LOCATION_PATH, ITEMS_PATH, ENEMIES_PATH), "真实配置应加载成功")
	board.generate(new_seed)
	return board

func _entrance() -> Vector2i:
	return Vector2i(0, 0)

func _events_text(board: BoardState) -> String:
	var text := ""
	for event in board.drain_events():
		text += event
	return text

# 网格里第一张指定类别的牌位（-1＝没有）。
func _find_cell(board: BoardState, kind: String) -> int:
	var grid: Array = board.current_site()["grid"]
	for i in range(grid.size()):
		var card: Dictionary = grid[i]
		if not card.is_empty() and str(card.get("kind", "")) == kind:
			return i
	return -1

# 网格里第一张指定类别＋enemy_id 的牌位。
func _find_enemy_cell(board: BoardState, enemy_id: String) -> int:
	var grid: Array = board.current_site()["grid"]
	for i in range(grid.size()):
		var card: Dictionary = grid[i]
		if not card.is_empty() and str(card.get("enemy_id", "")) == enemy_id:
			return i
	return -1

func _grid_count(board: BoardState) -> int:
	return board.card_count(board.hero_site)

# ---------- 真实配置：确定性与重放 ----------

func test_real_config_loads() -> void:
	var board := _real_board(1)
	assert_eq(board.ap, 40, "起始行动力应来自配置")
	# D-059 节点制：真配置走锚点图纸建图（data/qingfeng_map.json，49 节点）
	assert_true(board.map_mode, "真配置应进入节点制")
	assert_eq(board.sites.size(), 49, "锚点图纸：49 节点")
	assert_true(bool(board.current_site().get("explored", false)), "出生点开局已探索")
	assert_true(board.card_count(board.hero_site) > 0, "出生点网格应有牌")
	assert_eq(str(board.current_site().get("band", "")), "浅", "出生点在浅带（加权距离 0）")
	assert_eq(int(board.sites[board.hero_site]["links"].size()) > 0, true, "出生点有通道")

func test_continent_preplaced_connected_unexplored() -> void:
	var board := _real_board(1)
	# 除出生点外全部未探索；全图连通（BFS，入口＝出生锚点而非 (0,0)）
	var seen := {board.hero_site: true}
	var queue: Array[Vector2i] = [board.hero_site]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		for link in board.sites[pos]["links"]:
			if not seen.has(link):
				seen[link] = true
				queue.append(link)
	assert_eq(seen.size(), board.sites.size(), "大陆全图连通")
	for pos in board.sites:
		if pos == board.hero_site:
			continue
		assert_false(bool(board.sites[pos].get("explored", true)), "常规地点开局未探索")

func test_travel_explores_site() -> void:
	var continent := {"normal_sites": 1, "type_pool": ["room"], "hide_cards": []}
	var board := _board_with([], {"continent": continent})
	assert_eq(board.sites.size(), 2, "预置：入口 + 1 房间")
	var room_pos := Vector2i.ZERO
	for pos in board.sites:
		if pos != _entrance():
			room_pos = pos
	assert_false(bool(board.sites[room_pos].get("explored", true)), "房间未探索")
	assert_true(board.can_travel_to(room_pos), "通道已连通可直接走")
	assert_true(board.travel_to(room_pos))
	assert_true(bool(board.sites[room_pos].get("explored", false)), "走到即翻开")
	assert_eq(board.ap, 39, "移动 1 点")
	var text := _events_text(board)
	assert_true(text.contains("翻开了这片地块"), "首次抵达有翻开播报")

func test_same_seed_same_layout() -> void:
	var a := _real_board(42)
	var b := _real_board(42)
	assert_eq(a.sites, b.sites, "同种子大陆布局（含网格与内容物）应一致")

# 用固定策略自动打完整局，同种子两局结果应完全一致。
func test_full_run_replay_deterministic() -> void:
	var a := _real_board(99)
	var b := _real_board(99)
	_auto_play(a, 400)
	_auto_play(b, 400)
	assert_eq(a.outcome, b.outcome, "重放结局应一致")
	assert_eq(a.ap, b.ap, "重放剩余行动力应一致")
	assert_eq(a.inventory, b.inventory, "重放背包应一致")
	assert_eq(a.sites, b.sites, "重放版图应一致")

func _auto_play(board: BoardState, max_steps: int) -> void:
	var steps := 0
	while not board.is_run_over() and steps < max_steps:
		steps += 1
		if board.pending_intercept():
			board.resolve_battle_result("win")
			continue
		var acted := false
		var grid: Array = board.current_site()["grid"]
		for cell in range(grid.size()):
			var card: Dictionary = grid[cell]
			if card.is_empty():
				continue
			match str(card.get("kind", "")):
				"scatter":
					acted = board.pickup_cell(cell)
				"enemy", "pursuer", "zhenwu":
					var enemy_id := board.engage_cell(cell)
					if not enemy_id.is_empty():
						board.resolve_battle_result("win")
						while not board.chain_queue.is_empty() and not board.is_run_over():
							var next_id := board.next_chain()
							if next_id.is_empty():
								break
							board.resolve_battle_result("win")
						acted = true
				"body", "chest":
					if board.open_cell(cell):
						# 弹窗容器：翻完拿空（拿不走＝背包满，跳过去别死循环）
						var contents: Array = grid[cell].get("contents", [])
						var did := false
						for i in range(contents.size()):
							if board.flip_cell_content(cell, i):
								did = true
						while not contents.is_empty() and board.take_cell_content(cell, 0):
							did = true
						acted = did
				"npc":
					acted = board.talk_cell(cell)
				"location":
					acted = board.open_location_cell(cell)
			if acted or board.is_run_over():
				break
		if acted or board.is_run_over():
			continue
		if board.is_extract_site(board.hero_site):
			board.extract()
		else:
			# 网格处理完：沿通道继续探索
			var moved := false
			for pos in board.sites:
				if not moved and board.can_travel_to(pos):
					moved = board.travel_to(pos)
			if not moved:
				return

# ---------- 明牌网格规则（C-028 核心：无顺序限制） ----------

func test_any_card_interactable_in_any_order() -> void:
	# 散物在 0 号位、箱子在 3 号位：不开前面的散物也能直接开箱子（旧顶牌铁律废止）
	var board := _board_with([{"kind": "scatter"}, {"kind": "scatter"}, {"kind": "scatter"},
		{"kind": "chest", "chest": "wood"}])
	var chest_cell := _find_cell(board, "chest")
	assert_eq(board.ap, 40)
	assert_true(board.open_cell(chest_cell), "隔着散物也能直接开箱")
	assert_eq(board.ap, 39, "开木箱 1 点")

func test_chest_open_keeps_contents_for_flipping() -> void:
	# D-028 弹窗容器（C-028 网格化后照旧）：开启费开盖，内容物留在牌上逐张翻、拿空留壳
	var board := _board_with([{"kind": "chest", "chest": "wood"}])
	var before := _grid_count(board)
	assert_true(board.open_cell(0))
	assert_eq(board.ap, 39, "开木箱 1 点")
	assert_eq(_grid_count(board), before, "内容物不散进网格——留在牌上")
	var chest: Dictionary = board.current_site()["grid"][0]
	assert_true(bool(chest.get("opened", false)), "箱子已开盖")
	var contents: Array = chest.get("contents", [])
	assert_eq(contents.size(), 3, "3 件东西还盖着")
	for entry in contents:
		assert_false(bool((entry as Dictionary).get("flipped", false)), "开局全暗牌")
	# 翻牌收费、逐张翻：翻两张停手（可翻一半走了再续）
	assert_true(board.flip_cell_content(0, 0))
	assert_true(board.flip_cell_content(0, 1))
	assert_eq(board.ap, 37, "翻两张 2 点")
	assert_true(bool((contents[0] as Dictionary).get("flipped", false)))
	assert_false(bool((contents[2] as Dictionary).get("flipped", false)), "没翻的还盖着")
	# 已开过的箱子再点＝免费续翻视图（状态保留在牌上）
	assert_true(board.open_cell(0))
	assert_eq(board.ap, 37, "续开不收费")
	# 拿取免费：只拿已翻开的
	assert_false(board.take_cell_content(0, 2), "没翻开的拿不走")
	assert_true(board.take_cell_content(0, 0))
	assert_eq(board.ap, 37, "拿取免费")
	assert_eq(contents.size(), 2, "拿走一件少一件（后面的序号前移）")
	assert_true(board.flip_cell_content(0, 1), "把剩下那张也翻了")
	assert_true(board.take_cell_content(0, 1))
	assert_true(board.take_cell_content(0, 0), "再拿走最后一件")
	# 全拿空：箱子变空壳留场，不可再开
	assert_true((chest.get("contents", []) as Array).is_empty())
	assert_eq(str(chest.get("kind", "")), "chest", "空壳留场")
	assert_eq(_grid_count(board), 1, "网格里只剩空箱壳")
	assert_false(board.open_cell(0), "空壳没得开")
	var qty_sum := 0
	for stack in board.inventory:
		qty_sum += int(stack.get("qty", 1))
	assert_eq(qty_sum, 3, "三件全入包（同名叠堆算件数）")

func test_flip_and_take_make_noise() -> void:
	# 惊动制下的弹窗操作：翻 1 行动力＝1 单位动静，拿取 0 费＝最小动静 1
	var board := _board_with([{"kind": "chest", "chest": "wood"},
		{"kind": "enemy", "table": ["落魄拳师"]}])
	board.open_cell(0)  # 1 点 → 1 格内敌人 +2
	assert_eq(int(board.cell_card(board.hero_site, 1).get("alert", 0)), 2)
	board.flip_cell_content(0, 0)  # 1 点 → +2
	assert_eq(int(board.cell_card(board.hero_site, 1).get("alert", 0)), 4)
	board.take_cell_content(0, 0)  # 0 费最小动静 → +2
	assert_eq(int(board.cell_card(board.hero_site, 1).get("alert", 0)), 6)

func test_container_take_rejected_when_backpack_full() -> void:
	var board := _board_with([{"kind": "chest", "chest": "wood"}], {"backpack_size": 1})
	board.open_cell(0)
	board.flip_cell_content(0, 0)
	board._add_to_inventory(board._item("jiansui"))  # 占满唯一一格
	assert_false(board.take_cell_content(0, 0), "满格拿取被拒")
	assert_eq((board.cell_card(board.hero_site, 0).get("contents", []) as Array).size(), 3,
		"东西留在容器里")

func test_pickup_leaves_hole() -> void:
	var board := _board_with([{"kind": "scatter"}, {"kind": "enemy", "table": ["落魄拳师"]}])
	assert_true(board.pickup_cell(0))
	var grid: Array = board.current_site()["grid"]
	assert_true((grid[0] as Dictionary).is_empty(), "拿走留洞不回填")
	assert_false((grid[1] as Dictionary).is_empty(), "别的牌不挪位")
	assert_false(board.pickup_cell(0), "洞里没东西可拿")

func test_full_backpack_rejects_pickup_keeps_card() -> void:
	var board := _board_with([{"kind": "scatter", "table": ["ganliang"]}], {"backpack_size": 1})
	board._add_to_inventory(board._item("yinzi"))
	assert_false(board.pickup_cell(0), "满格拾取被拒")
	assert_eq(str(board.cell_card(board.hero_site, 0).get("kind", "")), "scatter", "牌留在原地")
	assert_eq(board.inventory.size(), 1)

func test_drop_places_scatter_card_in_grid() -> void:
	var board := _board_with([{"kind": "scatter"}])
	board.pickup_cell(0)
	assert_eq(board.inventory.size(), 1)
	assert_true(board.drop_item(0))
	assert_eq(board.inventory.size(), 0, "丢弃后出包")
	assert_eq(_grid_count(board), 1, "丢出的一件变网格里的零散牌")
	assert_true(board.pickup_cell(_find_cell(board, "scatter")), "可捡回")

func test_talk_npc_stays_in_place() -> void:
	var board := _board_with([{"kind": "npc", "table": ["test_npc"]}, {"kind": "scatter"}])
	assert_true(board.talk_cell(0), "可与 NPC 交谈")
	assert_eq(board.ap, 40, "交谈免费")
	assert_eq(_grid_count(board), 2, "NPC 留在原地")
	assert_true(board.talk_cell(0), "可再谈")
	var text := _events_text(board)
	assert_true(text.contains("行脚商人"), "对话内容进事件日志")

# ---------- 战斗与遗体 ----------

func test_battle_win_zero_ap_body_in_place() -> void:
	var board := _board_with([{"kind": "enemy", "table": ["落魄拳师"]}, {"kind": "chest", "chest": "wood"}])
	var cell := _find_enemy_cell(board, "落魄拳师")
	assert_eq(board.engage_cell(cell), "落魄拳师")
	board.resolve_battle_result("win")
	assert_eq(board.ap, 40, "战斗 0 行动力（C-028：代价是血与装备磨损）")
	var body: Dictionary = board.current_site()["grid"][cell]
	assert_eq(str(body.get("kind", "")), "body", "敌人原地变遗体")
	assert_eq(str(body.get("enemy_id", "")), "落魄拳师")
	assert_eq((board.current_site()["grid"] as Array).size(), 2, "网格不变薄")

func test_body_looted_stays_forever() -> void:
	var board := _board_with([{"kind": "enemy", "table": ["落魄拳师"]}])
	board.engage_cell(0)
	board.resolve_battle_result("win")
	assert_true(board.open_cell(0), "遗体可搜（弹窗翻牌）")
	var contents: Array = board.cell_card(board.hero_site, 0).get("contents", [])
	while not contents.is_empty() and (board.flip_cell_content(0, 0) or board.take_cell_content(0, 0)):
		pass
	assert_true(contents.is_empty(), "翻完拿空")
	var body: Dictionary = board.current_site()["grid"][0]
	assert_eq(str(body.get("kind", "")), "body", "搜空的遗体不消失（C-028）")
	assert_false(board.open_cell(0), "已搜空的遗体没得再开")

func test_chain_linked_enemies_fight_sequentially() -> void:
	# 连坐＝上下左右连通组：0-1 相邻成组；5 号位（2,1）与组不连通，孤军
	var grid := [{"kind": "enemy", "enemy_id": "落魄拳师", "alert": 0},
		{"kind": "enemy", "enemy_id": "山匪刀客", "alert": 0},
		{},
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [{"item_id": "ganliang"}]},
		{},
		{"kind": "enemy", "enemy_id": "青锋剑徒", "alert": 0}]
	var board := _board_with([])
	board.current_site()["grid"] = grid
	assert_eq(board.engage_cell(0), "落魄拳师")
	assert_eq(board.chain_queue, [1], "连通敌牌连坐排队（C-029 前逐场 1v1）")
	board.resolve_battle_result("win")
	assert_eq(str(board.current_site()["grid"][0].get("kind", "")), "body")
	assert_eq(board.next_chain(), "山匪刀客", "第二场连战")
	assert_eq(board.battle_cell, 1)
	board.resolve_battle_result("win")
	assert_eq(str(board.current_site()["grid"][1].get("kind", "")), "body")
	assert_true(board.chain_queue.is_empty())
	# 不连通的青锋剑徒不连坐，还活着
	assert_eq(str(board.current_site()["grid"][5].get("kind", "")), "enemy")

func test_battle_lose_ends_run() -> void:
	var board := _board_with([{"kind": "enemy", "table": ["落魄拳师"]}, {"kind": "scatter"}])
	board.engage_cell(0)
	board.resolve_battle_result("lose")
	assert_eq(board.outcome, "dead")
	assert_true(board.is_run_over())
	assert_false(board.pickup_cell(1), "失败后拾取锁定")
	assert_false(board.open_cell(0), "失败后开箱锁定")

# ---------- 地点卡与移动 ----------

func test_location_card_open_grows_site_and_moves() -> void:
	var board := _board_with([])
	board.current_site()["grid"].append({"kind": "location", "location": "room_card"})
	assert_true(board.open_location_cell(0), "地点卡可打开")
	assert_eq(board.ap, 40, "打开地点卡免费")
	assert_eq(board.sites.size(), 2, "长出新地块")
	assert_ne(board.hero_site, _entrance(), "侠客抵达新地块")
	assert_true(bool(board.current_site().get("explored", false)), "抵达即探索")
	assert_true(board.can_travel_to(_entrance()), "通道双向连通")
	assert_false(board.can_travel_to(Vector2i(5, 5)), "未连通地块不能移动")
	assert_true(board.travel_to(_entrance()))
	assert_eq(board.ap, 39, "走回头路 1 点")

func test_location_card_require_item() -> void:
	var board := _board_with([])
	board.current_site()["grid"].append({"kind": "location", "location": "locked_card"})
	assert_false(board.can_open_location(board.cell_card(board.hero_site, 0)), "缺钥匙不可开")
	assert_false(board.open_location_cell(0), "缺钥匙打开被拒")
	assert_eq(board.sites.size(), 1, "未长新地块")
	var text := _events_text(board)
	assert_true(text.contains("铜钥匙"), "受阻原因写明需要什么")
	board._add_to_inventory(board._item("yaoshi"))
	assert_true(board.can_open_location(board.cell_card(board.hero_site, 0)))
	assert_true(board.open_location_cell(0))
	assert_eq(board.inventory.size(), 0, "钥匙被消耗")
	assert_eq(str(board.current_site().get("name", "")), "上锁的房间")

func test_shortcut_links_far_site() -> void:
	var board := _board_with([])
	var a := Vector2i(1, 0)
	var b := Vector2i(2, 0)
	board.sites[a] = board._make_site("room", a)
	board.sites[b] = board._make_site("room", b)
	board.current_site()["links"].append(a)
	board.sites[a]["links"].append(_entrance())
	# b 与入口不连通：捷径应接通到 b
	board.current_site()["grid"].append({"kind": "location", "location": "shortcut_card"})
	assert_true(board.open_location_cell(0))
	assert_true(b in (board.current_site()["links"] as Array), "捷径接通未连通地块")
	assert_true(_entrance() in (board.sites[b]["links"] as Array), "通道双向")
	assert_eq(board.hero_site, _entrance(), "捷径不移动侠客")

func test_extract_location_card_opens_extract_site() -> void:
	var board := _board_with([])
	board.current_site()["grid"].append({"kind": "location", "location": "cheli_card"})
	assert_true(board.open_location_cell(0))
	assert_true(board.is_extract_site(board.hero_site), "抵达撤离点地块")
	assert_true(board.extract())
	assert_eq(board.outcome, "extracted")

# ---------- 禁地状态与拦截 ----------

func _count_guardians(board: BoardState) -> int:
	var count := 0
	for pos in board.sites:
		for entry in board.sites[pos]["grid"]:
			var card: Dictionary = entry
			if not card.is_empty() and str(card.get("kind", "")) == "enemy" \
					and str(card.get("enemy_id", "")) == "剑冢石仆":
				count += 1
	return count

func test_alert_marks_minor_guardians() -> void:
	var levels := [{"at": 1, "name": "骚动"}]
	var board := _board_with([{"kind": "chest", "chest": "wood"}], {"alert_levels": levels,
		"guardian_minor": "剑冢石仆", "guardian_mark_ratio": 0.3})
	board.enemies["剑冢石仆"] = {"tier": "normal", "loot_chest": "pockets_test"}
	assert_eq(board.alert_level, 0)
	board.open_cell(0)  # 花 1 点 → 禁地状态 Lv1
	assert_eq(board.alert_level, 1, "到达阈值禁地状态升级")
	assert_eq(_count_guardians(board), 1, "状态升级应标记地点、落一张小镇物")
	var info := board.alert_info()
	assert_eq(str(info["name"]), "骚动")
	var text := _events_text(board)
	assert_true(text.contains("石仆"), "事件日志应有石仆播报")

func test_alert_does_not_intercept() -> void:
	var levels := [{"at": 1, "name": "骚动"}]
	var board := _board_with([{"kind": "chest", "chest": "wood"}], {"alert_levels": levels})
	board.open_cell(0)
	assert_false(board.pending_intercept(), "禁地状态升级不触发强制拦截")

func test_pursuer_intercept_still_supported() -> void:
	var board := _board_with([{"kind": "chest", "chest": "wood"}])
	board.current_site()["grid"].append({"kind": "pursuer", "enemy_id": "山匪刀客", "alert": 0})
	var pursuer_cell := _find_cell(board, "pursuer")
	assert_true(board.pending_intercept(), "追兵在场触发拦截")
	assert_false(board.open_cell(_find_cell(board, "chest")), "拦截时不能开箱")
	assert_eq(board.engage_cell(pursuer_cell), "山匪刀客", "只能迎战")
	board.resolve_battle_result("win")
	assert_false(board.pending_intercept(), "打赢后拦截解除")
	assert_eq(str(board.cell_card(board.hero_site, pursuer_cell).get("kind", "")), "body", "追兵也变遗体（C-019）")

# ---------- 力竭与撤离 ----------

func test_exhaustion_when_ap_runs_out() -> void:
	var board := _board_with([{"kind": "chest", "chest": "wood"}], {}, 1)
	board.open_cell(0)  # 花 1 点 → 剩 0 → 力竭
	assert_eq(board.outcome, "exhausted")
	var scatter_cell := _find_cell(board, "scatter")
	assert_false(board.pickup_cell(scatter_cell) if scatter_cell >= 0 else false, "力竭后动作锁定")

func test_zero_ap_at_extract_site_is_safe() -> void:
	var board := _board_with([], {"site_types": {"entrance": {"name": "入口", "extract": true,
		"cards": [{"kind": "chest", "chest": "wood"}], "bottom": []}}}, 1)
	board.open_cell(0)  # 剩 0，但在撤离点
	assert_eq(board.outcome, "", "撤离点上行动力归 0 不判负")
	assert_true(board.extract())
	assert_eq(board.outcome, "extracted")

# ---------- 背包：堆叠与容量 ----------

func test_backpack_stacking_and_capacity() -> void:
	var board := _board_with([], {"backpack_size": 2})
	assert_true(board._add_to_inventory(board._item("ganliang")))
	assert_true(board._add_to_inventory(board._item("ganliang")))
	assert_eq(board.inventory.size(), 1, "同名叠放占一格")
	assert_eq(int(board.inventory[0].get("qty", 0)), 2, "叠放数量累加")
	assert_true(board._add_to_inventory(board._item("yinzi")))
	assert_eq(board.inventory.size(), 2, "新物品占新格")
	assert_false(board._add_to_inventory(board._item("jiansui")), "满格拒收新物品")
	assert_eq(board.inventory.size(), 2)

func test_drop_one_from_stack() -> void:
	var board := _board_with([{"kind": "scatter", "table": ["ganliang"]}, {"kind": "scatter", "table": ["ganliang"]}])
	board.pickup_cell(0)
	board.pickup_cell(1)
	assert_eq(int(board.inventory[0].get("qty", 0)), 2)
	assert_true(board.drop_item(0))
	assert_eq(int(board.inventory[0].get("qty", 0)), 1, "丢弃只减一件")
	assert_eq(board.inventory.size(), 1, "堆叠未空不移出")
	assert_eq(_grid_count(board), 1, "丢出的一件变网格里的零散牌")
	assert_true(board.drop_item(0))
	assert_eq(board.inventory.size(), 0, "减空移出")
