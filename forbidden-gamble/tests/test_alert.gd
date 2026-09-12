extends GutTest

# C-028 三态警戒专场：曼哈顿传播（1 格×2、2 格×1）、0 费互动最小动静、满表准备态、
# 逃生窗与袭击（敌方先手）、别处衰减、迷踪香静音窗、开战动静、遗体消失、迫近袭击。

func _items() -> Dictionary:
	return {
		"ganliang": {"id": "ganliang", "name": "干粮", "rarity": "common", "value": 5},
		"bao": {"id": "bao", "name": "宝物", "type": "valuable", "rarity": "rare", "value": 100},
	}

func _enemies() -> Dictionary:
	return {
		"山匪刀客": {"tier": "normal", "loot_chest": "pockets"},
		"剑冢石仆": {"tier": "normal", "loot_chest": "pockets"},
		"守冢剑影": {"tier": "veteran", "loot_chest": "pockets"},
		"守冢剑灵": {"tier": "master", "loot_chest": "remains"},
	}

func _chest(chest_id := "wood") -> Dictionary:
	return {"kind": "chest", "chest": chest_id, "opened": false,
		"contents": [{"item_id": "ganliang"}]}

func _enemy(enemy_id: String) -> Dictionary:
	return {"kind": "enemy", "enemy_id": enemy_id, "alert": 0}

func _scatter() -> Dictionary:
	return {"kind": "scatter", "item_id": "ganliang"}

# 网格 3 列：0(0,0) 1(1,0) 2(2,0) 3(0,1) 4(1,1) 5(2,1) 6(0,2) ...
func _alert_board(grid: Array, extra: Dictionary = {}) -> BoardState:
	var cfg := {
		"name": "测试禁地", "entrance_type": "entrance",
		"ap": {"start": 100, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [], "pursuer_table": [], "scatter_table": [],
		"npcs": {"npc1": {"name": "行脚商人", "lines": ["……"]}},
		"chests": {
			"wood": {"name": "木箱", "ap_cost": 1, "draws": 1, "table": ["ganliang"]},
			"gold": {"name": "金箱", "ap_cost": 3, "draws": 1, "table": ["ganliang"]},
			"pockets": {"name": "行囊", "ap_cost": 1, "draws": 1, "table": ["ganliang"]},
			"remains": {"name": "遗骸", "ap_cost": 1, "draws": 1, "table": ["bao"]},
		},
		"hunt": {"first": 50, "step": 100, "avatar": "守冢剑影", "true_body": "守冢剑灵",
			"avatar_life": 10, "avatar_interval": 2, "true_interval_min": 1,
			"true_interval_max": 1, "teleport_distance": 3, "proximity_cap": 3},
		"continent": {"normal_sites": 1, "type_pool": ["room"], "hide_cards": []},
		"site_types": {
			"entrance": {"name": "入口", "cards": [], "bottom": []},
			"room": {"name": "房间", "cards": [], "bottom": []},
		},
	}
	for key in extra:
		cfg[key] = extra[key]
	var board := BoardState.new()
	board.config = cfg
	board.items = _items()
	board.enemies = _enemies()
	board.generate(7)
	board.current_site()["grid"] = grid
	return board

func _second_site(board: BoardState) -> Vector2i:
	for pos in board.sites:
		if pos != board.hero_site:
			return pos
	return Vector2i(9, 9)

func _alert_of(board: BoardState, cell: int) -> int:
	return int(board.cell_card(board.hero_site, cell).get("alert", 0))

func _alert_at(board: BoardState, pos: Vector2i, cell: int) -> int:
	return int(board.cell_card(pos, cell).get("alert", 0))

func _events_text(board: BoardState) -> String:
	var text := ""
	for event in board.drain_events():
		text += event
	return text

func _refresh_chest(board: BoardState, cell: int) -> void:
	board.current_site()["grid"][cell] = _chest()

# ---------- 传播：曼哈顿距离 × 行动花费 ----------

func test_noise_spread_by_distance() -> void:
	# 木箱在 0(0,0)；敌人在 3(0,1) 距离 1、4(1,1) 距离 2、6(0,2) 距离 2、5(2,1) 距离 3
	var board := _alert_board([_chest(), {}, {}, _enemy("山匪刀客"),
		_enemy("山匪刀客"), _enemy("山匪刀客"), _enemy("山匪刀客")])
	assert_true(board.open_cell(0))  # 开箱 1 点
	assert_eq(_alert_of(board, 3), 2, "1 格内 +2×1")
	assert_eq(_alert_of(board, 4), 1, "2 格内 +1×1")
	assert_eq(_alert_of(board, 6), 1, "2 格（竖向）+1×1")
	assert_eq(_alert_of(board, 5), 0, "3 格外听不见")

func test_noise_scales_with_ap_cost() -> void:
	# 金箱 3 点：单位＝行动花费
	var board := _alert_board([_chest("gold"), _enemy("山匪刀客")])
	assert_true(board.open_cell(0))
	assert_eq(_alert_of(board, 1), 6, "1 格内 +2×3（金箱 3 点）")
	assert_eq(board.ap, 97, "金箱扣 3 点")

func test_zero_cost_pickup_still_makes_min_noise() -> void:
	# 拾取免费但有最小动静 1 点：1 格内敌人 +2
	var board := _alert_board([_scatter(), _enemy("山匪刀客")])
	assert_true(board.pickup_cell(0))
	assert_eq(_alert_of(board, 1), 2, "0 费互动至少算 1 点动静")

func test_noise_clamps_at_cap() -> void:
	var board := _alert_board([_chest(), {}, {}, _enemy("山匪刀客")])
	for i in range(6):
		_refresh_chest(board, 0)
		board.open_cell(0)  # 每次 +2
	assert_eq(_alert_of(board, 3), 10, "警戒封顶在上限（6×2 截在 10）")
	var badge: Dictionary = board.alert_badge(board.cell_card(board.hero_site, 3))
	assert_eq(str(badge["state"]), "ready", "满表＝准备态")
	var text := _events_text(board)
	assert_true(text.contains("盯死"), "满表有播报")

func test_per_enemy_cap_override() -> void:
	var board := _alert_board([_chest(), _enemy("山匪刀客")])
	board.enemies["山匪刀客"]["alert_cap"] = 4
	_refresh_chest(board, 0)
	board.open_cell(0)  # +2
	_refresh_chest(board, 0)
	board.open_cell(0)  # +2 → 4 满（个体上限 4）
	assert_eq(_alert_of(board, 1), 4, "个别敌人可覆写警戒上限")
	assert_eq(str(board.alert_badge(board.cell_card(board.hero_site, 1))["state"]), "ready")

# ---------- 准备态、逃生窗与袭击 ----------

func test_ready_enemy_ambushes_after_next_action() -> void:
	var board := _alert_board([_scatter(), _enemy("山匪刀客")])
	board.enemies["山匪刀客"]["alert_cap"] = 2
	assert_true(board.pickup_cell(0))  # +2 → 满（准备态）
	assert_eq(board.check_ambush(), "", "刚满表的这一次行动不挨咬（逃生窗）")
	board.current_site()["grid"].append(_scatter())
	assert_true(board.pickup_cell(2), "再做一次动作")
	assert_eq(board.check_ambush(), "山匪刀客", "准备态敌人在下一次行动后袭击")
	assert_true(board.battle_enemy_first, "被袭击＝敌方先手")
	assert_eq(board.battle_cell, 1, "战斗位指向那只敌人")
	var text := _events_text(board)
	assert_true(text.contains("发难"), "袭击有播报")

func test_ready_enemy_does_not_bite_if_you_leave() -> void:
	var board := _alert_board([_scatter(), _enemy("山匪刀客")])
	board.enemies["山匪刀客"]["alert_cap"] = 2
	board.pickup_cell(0)  # 满（准备态）
	board.check_ambush()  # 挂上 primed
	var far := _second_site(board)
	assert_true(board.travel_to(far), "用逃生窗离开")
	assert_eq(board.check_ambush(), "", "人已离开地块，袭不到")
	# 离开本身就在消警戒（这 1 点行动力让老家 −1）：准备态随之解除
	assert_eq(_alert_at(board, Vector2i(0, 0), 1), 1, "离开的那步就在消警戒")

func test_ready_two_enemies_ambush_one_at_a_time() -> void:
	# 两敌在 1(1,0) 与 3(0,1)：互相隔 2 格不连坐，但都在箱子（0 号位）1 格内
	var board := _alert_board([_chest(), _enemy("山匪刀客"), {}, _enemy("剑冢石仆")])
	board.enemies["山匪刀客"]["alert_cap"] = 2
	board.enemies["剑冢石仆"]["alert_cap"] = 2
	board.open_cell(0)  # 两只同满
	board.check_ambush()  # 逃生窗：挂 primed
	board.current_site()["grid"].append(_scatter())
	assert_true(board.pickup_cell(4), "再动一次")
	var first := board.check_ambush()
	assert_eq(first, "山匪刀客", "多只满表逐只来（低位先）")
	board.engage_cell(board.battle_cell)
	board.resolve_battle_result("win")
	board.current_site()["grid"].append(_scatter())
	board.pickup_cell(5)
	assert_eq(board.check_ambush(), "剑冢石仆", "第二只随后到位")

# ---------- 衰减 ----------

func test_alert_decays_only_elsewhere() -> void:
	var board := _alert_board([_scatter(), _enemy("山匪刀客")])
	board.pickup_cell(0)  # +2
	var far := _second_site(board)
	assert_true(board.travel_to(far))  # 离开（这 1 点让老家 −1）
	assert_eq(_alert_at(board, Vector2i(0, 0), 1), 1, "别处每花 1 点行动力，老家全场 −1")
	assert_true(board.travel_to(Vector2i(0, 0)))  # 回来（这 1 点衰减的是另一块地）
	assert_eq(_alert_at(board, Vector2i(0, 0), 1), 1, "你在的地块不衰减")
	assert_true(board.travel_to(far))
	assert_eq(_alert_at(board, Vector2i(0, 0), 1), 0, "再离开继续衰减到底")

# ---------- 迷踪香静音窗 ----------

func test_sneak_window_silences_noise() -> void:
	var items := _items()
	items["xiang"] = {"id": "xiang", "name": "迷踪香", "type": "consumable", "subtype": "tool",
		"rarity": "rare", "value": 35, "max_stack": 3,
		"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "sneak_window", "amount": 3}]}}
	var board := _alert_board([_chest(), _enemy("山匪刀客")])
	board.items = items
	board.inventory.append(items["xiang"].duplicate())
	assert_true(board.use_item(0), "用了迷踪香")
	assert_eq(board.sneak_ap, 3, "静音窗 3 点行动力")
	_refresh_chest(board, 0)
	board.open_cell(0)  # 花 1 点，窗内无声
	assert_eq(_alert_of(board, 1), 0, "窗内动牌不产噪")
	assert_eq(board.sneak_ap, 2, "窗随行动力消耗倒数")
	_refresh_chest(board, 0)
	board.open_cell(0)
	_refresh_chest(board, 0)
	board.open_cell(0)  # 窗耗尽
	assert_eq(board.sneak_ap, 0)
	_refresh_chest(board, 0)
	board.open_cell(0)
	assert_eq(_alert_of(board, 1), 2, "关窗后动静照常")

func test_combat_noise_ignores_sneak_window() -> void:
	var board := _alert_board([_enemy("山匪刀客"), _enemy("剑冢石仆")])
	board.sneak_ap = 9  # 满窗
	board.engage_cell(0)
	board.resolve_battle_result("win")
	assert_eq(_alert_of(board, 1), 4, "开战很吵：1 格 +2×combat_ap，静音窗遮不住打斗")
	assert_eq(board.check_ambush(), "", "4/10 没满表不挨咬")

# ---------- 遗体与消失 ----------

func test_guardian_and_avatar_vanish_on_death() -> void:
	var board := _alert_board([_enemy("剑冢石仆"),
		{"kind": "zhenwu", "enemy_id": "守冢剑影", "avatar": true, "alert": 0}])
	board.hunter = {"enemy_id": "守冢剑影", "avatar": true, "site": board.hero_site,
		"move_in": 2, "life": 5, "prox": 0, "primed": false, "cell": 1}
	board.engage_cell(1)
	board.resolve_battle_result("win")
	assert_true((board.current_site()["grid"][1] as Dictionary).is_empty(), "分身被打死直接消失，无遗体无掉落")
	assert_true(board.hunter.is_empty(), "追杀者被杀")

	var board2 := _alert_board([_enemy("剑冢石仆")], {"guardian_minor": "剑冢石仆"})
	board2.engage_cell(0)
	board2.resolve_battle_result("win")
	assert_true((board2.current_site()["grid"][0] as Dictionary).is_empty(), "小镇物被打死直接消失，无遗体无掉落")

# ---------- 镇物迫近 ----------

func _find_zhenwu(board: BoardState) -> int:
	var grid: Array = board.current_site()["grid"]
	for i in range(grid.size()):
		if str((grid[i] as Dictionary).get("kind", "")) == "zhenwu":
			return i
	return -1

func test_hunter_proximity_ambush() -> void:
	var board := _alert_board([_chest()])
	# 气息过线 → 分身出生压顶
	assert_true(board._add_to_inventory(board._item("bao")))
	var zhenwu_cell := _find_zhenwu(board)
	assert_true(zhenwu_cell >= 0, "分身压进网格")
	assert_eq(board.check_ambush(), "")
	# 在它眼皮底下花 3 点行动力（反复开箱）
	for i in range(3):
		_refresh_chest(board, 0)
		board.open_cell(0)
	assert_eq(board.hunter_proximity(), 3, "迫近积满 3 层")
	assert_eq(board.check_ambush(), "", "刚积满的这一轮不咬（逃生窗）")
	board.current_site()["grid"].append(_scatter())
	assert_true(board.pickup_cell(board.current_site()["grid"].size() - 1))
	assert_eq(board.check_ambush(), "守冢剑影", "迫近满＝镇物扑上来")
	assert_true(board.battle_enemy_first, "被袭击＝敌方先手")

func test_proximity_resets_when_you_leave() -> void:
	var board := _alert_board([_chest()])
	assert_true(board._add_to_inventory(board._item("bao")))
	board.hunter["prox"] = 2  # 直接拨表，隔离验证离开归零
	var far := _second_site(board)
	assert_true(board.travel_to(far), "离开压顶地块")
	assert_eq(int(board.hunter.get("prox", -1)), 0, "离开压顶地块迫近归零重积")
