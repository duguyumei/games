extends GutTest

# 镇物追杀系统（C-028 改 AP 钟）：气息过线出生 / 追逐节拍（每点行动力一拍）/
# 瞬移条款 / 压顶占格 / 分身寿命 / 真身按次判 / 杀真身清场 / 状态标记 /
# 分身与小镇物消失 / 迫近 / 存档往返。

func _items() -> Dictionary:
	return {
		"bao": {"id": "bao", "name": "宝物", "type": "valuable", "rarity": "rare", "value": 100},
	}

func _enemies() -> Dictionary:
	return {
		"守冢剑影": {"tier": "veteran"},
		"守冢剑灵": {"tier": "master", "loot_chest": "remains"},
		"剑冢石仆": {"tier": "normal"},
	}

func _hunt_board(extra: Dictionary = {}) -> BoardState:
	var cfg := {
		"name": "测试禁地", "entrance_type": "entrance",
		"ap": {"start": 100, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [{"at": 1000, "name": "远"}],
		"pursuer_table": [], "scatter_table": [], "npcs": {},
		"chests": {"remains": {"name": "遗骸", "ap_cost": 1, "draws": 1, "table": ["bao"]}},
		"hunt": {"first": 100, "step": 100, "avatar": "守冢剑影", "true_body": "守冢剑灵",
			"avatar_life": 10, "avatar_interval": 2, "true_interval_min": 1,
			"true_interval_max": 1, "teleport_distance": 3, "proximity_cap": 3},
		"continent": {}, "location_cards": {},
		"site_types": {"entrance": {"name": "入口", "cards": [], "bottom": []}},
	}
	for key in extra:
		cfg[key] = extra[key]
	var board := BoardState.new()
	board.config = cfg
	board.items = _items()
	board.enemies = _enemies()
	board.generate(7)
	return board

# 线性大陆：(0,0)-(1,0)-(2,0)-(3,0)-(4,0)
func _chain_board(extra: Dictionary = {}) -> BoardState:
	var board := _hunt_board(extra)
	var prev := Vector2i(0, 0)
	for x in range(1, 5):
		var pos := Vector2i(x, 0)
		board.sites[pos] = {"pos": pos, "name": "地%d" % x, "links": [prev],
			"grid": [], "explored": false}
		(board.sites[prev]["links"] as Array).append(pos)
		prev = pos
	return board

func _shipu_in_grid(board: BoardState, pos: Vector2i) -> bool:
	for entry in board.sites[pos]["grid"]:
		var card: Dictionary = entry
		if not card.is_empty() and str(card.get("kind", "")) == "enemy" \
				and str(card.get("enemy_id", "")) == "剑冢石仆":
			return true
	return false

func _zhenwu_cell(board: BoardState, pos: Vector2i) -> int:
	var grid: Array = board.sites[pos]["grid"]
	for i in range(grid.size()):
		if str((grid[i] as Dictionary).get("kind", "")) == "zhenwu":
			return i
	return -1

# ---------- 出生与排队 ----------

func test_loot_crossing_line_spawns_avatar_in_grid() -> void:
	var board := _hunt_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_false(board.hunter.is_empty(), "气息过线应出生追杀者")
	assert_true(bool(board.hunter["avatar"]), "状态<3 级应是分身")
	assert_true(_zhenwu_cell(board, board.hero_site) >= 0, "分身卡压进当前地块网格")
	assert_eq(board.qixi, 100)
	assert_eq(board.hunt_count, 1)

func test_two_lines_at_once_queue_second_hunter() -> void:
	var board := _hunt_board()
	board.items["bao"]["value"] = 250
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_eq(board.hunt_count, 2, "一件 250 连过两线（100/200）")
	assert_eq(board.hunt_queue, 1, "同屏只一只，第二只排队")
	board.engage_cell(_zhenwu_cell(board, board.hero_site))
	board.resolve_battle_result("win")
	assert_true(board.hunter.is_empty(), "分身被杀后追杀暂停")
	assert_true(_zhenwu_cell(board, board.hero_site) < 0, "分身不留遗体（C-028）")
	board._spend_ap(1)  # 下一拍
	assert_false(board.hunter.is_empty(), "排队的追杀者在下一拍上岗")
	assert_eq(board.hunt_queue, 0)

# ---------- 节拍与移动（每点行动力一拍） ----------

func test_avatar_moves_every_two_ap() -> void:
	var board := _chain_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_true(board.travel_to(Vector2i(1, 0)), "玩家走开（镇物卡撤下；这一步也推了一拍）")
	assert_eq(board.hunter["site"], Vector2i(0, 0))
	board._spend_ap(1)  # 行动拍：距离 1，走向玩家并压顶
	assert_eq(board.hunter["site"], Vector2i(1, 0))
	assert_true(_zhenwu_cell(board, Vector2i(1, 0)) >= 0, "追至玩家地块应压顶")

func test_teleport_when_far() -> void:
	var board := _chain_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	board.hero_site = Vector2i(4, 0)  # 直接放到远端（图距离 4 > 3）
	board._spend_ap(1)
	board._spend_ap(1)  # 行动拍：距离过远 → 瞬移落顶
	assert_eq(board.hunter["site"], Vector2i(4, 0), "距离>3 应瞬移到玩家地块")
	assert_true(_zhenwu_cell(board, Vector2i(4, 0)) >= 0)

func test_player_walks_into_lurking_hunter_rises() -> void:
	var board := _chain_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_true(board.travel_to(Vector2i(1, 0)))  # 走开 1 点：节拍未到，镇物驻留原地
	assert_true(_zhenwu_cell(board, Vector2i(0, 0)) < 0, "玩家离开后镇物只驻留不占网格")
	assert_true(board.travel_to(Vector2i(0, 0)))
	assert_true(_zhenwu_cell(board, Vector2i(0, 0)) >= 0, "玩家撞入驻留地 → 压顶")

# ---------- 寿命与真身 ----------

func test_avatar_dissipates_after_life() -> void:
	var board := _hunt_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	for i in range(10):
		board._spend_ap(1)
	assert_true(board.hunter.is_empty(), "寿命（10 点行动力）尽应自散")
	assert_true(_zhenwu_cell(board, board.hero_site) < 0, "散场卡撤下")
	assert_eq(board.hunt_count, 1, "已过线数不因消散重置")

func test_true_body_when_state_level_3_and_never_fades() -> void:
	var board := _hunt_board()
	board.alert_level = 3
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_false(bool(board.hunter["avatar"]), "状态 3 级触发应出真身")
	assert_eq(int(board.hunter["life"]), -1)
	for i in range(50):
		board._spend_ap(1)
	assert_false(board.hunter.is_empty(), "真身永不消散")

# ---------- 击杀结算 ----------

func test_slaying_true_body_clears_guardians() -> void:
	var board := _chain_board({"guardian_minor": "剑冢石仆"})
	(board.sites[Vector2i(2, 0)]["grid"] as Array).append({"kind": "enemy", "enemy_id": "剑冢石仆", "alert": 0})
	board.alert_level = 3
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_false(bool(board.hunter["avatar"]))
	var zhenwu_cell := _zhenwu_cell(board, board.hero_site)
	board.engage_cell(zhenwu_cell)
	board.resolve_battle_result("win")
	assert_true(board.guardians_off, "杀真身应关机守卫系统")
	assert_eq(board.alert_level, 0, "禁地状态清零")
	assert_eq(board.hunt_queue, 0)
	var body: Dictionary = board.cell_card(board.hero_site, zhenwu_cell)
	assert_eq(str(body.get("kind", "")), "body", "真身尸体留场")
	assert_eq(str(body.get("enemy_id", "")), "守冢剑灵")
	assert_false(_shipu_in_grid(board, Vector2i(2, 0)), "场上现存小镇物卡应消失")
	assert_true(board._add_to_inventory(board._item("bao")), "守卫关机后照常搜刮")
	assert_true(board.hunter.is_empty(), "关机后气息过线不再追杀")

# ---------- 禁地状态标记 ----------

func test_state_level_marks_thirty_percent_sites() -> void:
	var board := _chain_board({"alert_levels": [{"at": 2, "name": "骚动"}],
		"guardian_minor": "剑冢石仆", "guardian_mark_ratio": 0.6})
	assert_true(board.travel_to(Vector2i(1, 0)))
	assert_true(board.travel_to(Vector2i(2, 0)))  # 累计 2 → Lv1
	assert_eq(board.alert_level, 1)
	var marked := 0
	for pos in board.sites:
		if _shipu_in_grid(board, pos):
			marked += 1
	assert_eq(marked, 3, "5 地 × 0.6 = 3 处标记（不重复计同地）")

# ---------- 存档往返 ----------

func test_hunter_state_roundtrip() -> void:
	var board := _chain_board()
	assert_true(board._add_to_inventory(board._item("bao")))
	assert_true(board.travel_to(Vector2i(1, 0)))
	var parsed: Variant = JSON.parse_string(JSON.stringify(board.to_dict()))
	var restored := BoardState.new()
	restored.config = board.config
	restored.items = board.items
	restored.enemies = board.enemies
	restored.from_dict(parsed)
	assert_eq(restored.qixi, board.qixi)
	assert_eq(restored.hunt_count, board.hunt_count)
	assert_eq(restored.hunter["site"], Vector2i(0, 0), "追杀者位置应还原为 Vector2i")
	assert_eq(int(restored.hunter["life"]), int(board.hunter["life"]))
	assert_true(bool(restored.hunter["avatar"]))
	assert_eq(restored.guardians_off, board.guardians_off)
	assert_eq(restored.sites, board.sites, "版图（含网格）全等")
