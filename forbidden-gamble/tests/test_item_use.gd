extends GutTest

# 消耗品使用系统：探索域执行器（BoardState.use_item）+ 战斗域执行器（ItemEffects）
# + 气血回调（ExpeditionSession.recover_hp）+ 叠堆上限分流。

var _healed := 0

func before_each() -> void:
	_healed = 0

# ---------- 构造（同 test_board_state 的夹具风格） ----------

func _test_items() -> Dictionary:
	return {
		"bigu": {"id": "bigu", "name": "辟谷丹", "type": "consumable", "subtype": "provision",
			"rarity": "common", "value": 12, "max_stack": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "restore_ap", "amount": 4}]}},
		"shangyao": {"id": "shangyao", "name": "伤药", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 10, "max_stack": 2,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "heal", "amount": 10}]}},
		"yaoshi": {"id": "yaoshi", "name": "铜钥匙", "type": "consumable", "subtype": "credential",
			"rarity": "common", "value": 6},
		"baixi": {"id": "baixi", "name": "百匣钥", "type": "consumable", "subtype": "tool",
			"rarity": "rare", "value": 40, "max_stack": 3,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "open_all_chests"}]}},
		"xiang": {"id": "xiang", "name": "迷踪香", "type": "consumable", "subtype": "tool",
			"rarity": "rare", "value": 35, "max_stack": 3,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "sneak_window", "amount": 3}]}},
		"feibiao": {"id": "feibiao", "name": "淬毒飞镖", "type": "consumable", "subtype": "hidden_weapon",
			"rarity": "rare", "value": 55, "max_stack": 3,
			"use": {"scopes": ["battle"], "target": "enemy", "effects": [
				{"kind": "damage", "amount": 10},
				{"kind": "apply_status", "status": "poison", "stacks": 2}]}},
	}

func _test_enemies() -> Dictionary:
	return {
		"落魄拳师": {"tier": "normal", "loot_chest": "pockets"},
	}

func _board() -> BoardState:
	var cfg := {
		"name": "测试地点", "entrance_type": "entrance",
		"ap": {"start": 40, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [], "pursuer_table": [], "scatter_table": [],
		"npcs": {},
		"chests": {"wood": {"name": "木箱", "ap_cost": 1, "draws": 1, "table": []}},
		"continent": {}, "location_cards": {},
		"site_types": {"entrance": {"name": "入口", "cards": [], "bottom": []}},
	}
	var board := BoardState.new()
	board.config = cfg
	board.items = _test_items()
	board.enemies = _test_enemies()
	board.generate(7)
	return board

func _record_heal(amount: int) -> void:
	_healed += amount

# ---------- 探索域 ----------

func test_use_provision_restores_ap_and_consumes() -> void:
	var board := _board()
	assert_true(board._add_to_inventory(board._item("bigu")))
	board.ap = 10
	assert_true(board.use_item(0))
	assert_eq(board.ap, 14, "辟谷丹应回 4 点行动力")
	assert_true(board.inventory.is_empty(), "用后应消耗")

func test_battle_only_item_rejected_in_explore() -> void:
	var board := _board()
	assert_true(board._add_to_inventory(board._item("feibiao")))
	assert_false(board.use_item(0), "战斗域道具在探索中不可用")
	assert_eq(board.inventory.size(), 1, "失败不消耗")

func test_credential_without_use_rejected() -> void:
	var board := _board()
	assert_true(board._add_to_inventory(board._item("yaoshi")))
	assert_false(board.use_item(0), "无 use 的凭证不能点用")
	assert_false(board.item_usable_in_explore(0))

func test_heal_effect_routes_to_callback() -> void:
	var board := _board()
	board.heal_player = _record_heal
	assert_true(board._add_to_inventory(board._item("shangyao")))
	assert_true(board.use_item(0))
	assert_eq(_healed, 10, "heal 效果应经回调落地")

func test_baixiyao_opens_all_chests_without_ap() -> void:
	var board := _board()
	var site := board.current_site()
	site["grid"] = [
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [{"item_id": "yaoshi", "flipped": false}]},
		{"kind": "enemy", "enemy_id": "落魄拳师", "alert": 0},
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [{"item_id": "yaoshi", "flipped": false}]},
	]
	assert_true(board._add_to_inventory(board._item("baixi")))
	var ap_before := board.ap
	assert_true(board.use_item(0))
	assert_eq(board.ap, ap_before, "百匣钥开箱不收行动力")
	assert_eq(board.card_count(board.hero_site), 3, "东西不散出——留在箱里等翻")
	for entry in site["grid"]:
		var card: Dictionary = entry
		if not card.is_empty() and str(card.get("kind", "")) == "chest":
			assert_true(bool(card.get("opened", false)), "箱子应被打开（免开启费）")
			for content in card.get("contents", []):
				assert_false(bool((content as Dictionary).get("flipped", false)), "东西还盖着——翻牌照常收费")
	assert_true(board.flip_cell_content(0, 0), "崩开后照常逐张翻")
	assert_eq(board.ap, ap_before - 1, "翻牌仍 1 点")

func test_baixiyao_blocked_without_chests() -> void:
	var board := _board()
	assert_true(board._add_to_inventory(board._item("baixi")))
	assert_false(board.use_item(0), "没有箱子时百匣钥应被拒绝")
	assert_eq(board.inventory.size(), 1, "拒绝不消耗")

func test_sneak_window_usable_anywhere() -> void:
	# 迷踪香改静音窗（C-028）：任何地方都能点（详细动静覆盖见 test_alert）
	var board := _board()
	assert_true(board._add_to_inventory(board._item("xiang")))
	assert_true(board.use_item(0))
	assert_eq(board.sneak_ap, 3, "静音窗 3 点行动力")
	assert_true(board.inventory.is_empty(), "用后消耗")

func test_max_stack_splits_into_slots() -> void:
	var board := _board()  # 伤药 max_stack=2
	assert_true(board._add_to_inventory(board._item("shangyao")))
	assert_true(board._add_to_inventory(board._item("shangyao")))
	assert_true(board._add_to_inventory(board._item("shangyao")))
	assert_eq(board.inventory.size(), 2, "第三件应另占一格")
	assert_eq(int(board.inventory[0]["qty"]), 2)
	assert_eq(int(board.inventory[1]["qty"]), 1)

# ---------- 战斗域（ItemEffects 纯函数） ----------

func _fighter(tier: String) -> FighterState:
	var f := FighterState.new("e", "敌人", 30)
	f.tier = tier
	return f

func test_item_damage_reduced_by_tier() -> void:
	assert_eq(ItemEffects.reduced_damage(10, _fighter("normal")), 10)
	assert_eq(ItemEffects.reduced_damage(10, _fighter("veteran")), 8)
	assert_eq(ItemEffects.reduced_damage(10, _fighter("elite")), 6)
	assert_eq(ItemEffects.reduced_damage(10, _fighter("master")), 5)

func test_item_damage_override_beats_tier_table() -> void:
	var f := _fighter("normal")
	f.item_damage_reduction = 0.5
	assert_eq(ItemEffects.reduced_damage(10, f), 5, "敌人定义覆写优先于档次表")

func test_apply_feibiao_damage_and_poison() -> void:
	var player := FighterState.new("p", "你", 50)
	var enemy := _fighter("normal")
	var use: Dictionary = _test_items()["feibiao"]["use"]
	var lines := ItemEffects.apply(use, player, enemy)
	assert_eq(enemy.hp, 20, "10 点直伤应打在气血上")
	assert_eq(enemy.get_status("poison"), 2, "应挂 2 层毒")
	assert_eq(lines.size(), 2, "两条效果各一行日志")

func test_apply_heal_clamps_at_max() -> void:
	var player := FighterState.new("p", "你", 50)
	player.hp = 45
	var enemy := _fighter("normal")
	var use := {"scopes": ["battle"], "target": "self", "effects": [{"kind": "heal", "amount": 40}]}
	ItemEffects.apply(use, player, enemy)
	assert_eq(player.hp, 50, "回血应截断在上限")
	assert_eq(_healed, 0, "战斗域回血不经探索侧回调")

func test_apply_damage_bypasses_guard() -> void:
	var enemy := _fighter("normal")
	enemy.guard = 10
	var use := {"scopes": ["battle"], "target": "enemy", "effects": [{"kind": "damage", "amount": 10}]}
	ItemEffects.apply(use, FighterState.new("p", "你", 50), enemy)
	assert_eq(enemy.hp, 20, "暗器直伤应绕过护体真气")
	assert_eq(enemy.guard, 10, "护体不应被消耗")

# ---------- 掉落黑名单 ----------

func test_no_drop_items_never_in_loot_pool() -> void:
	# 辟谷丹三品是门派垄断物（no_drop），任何稀有度的掉落池都不该抽到它们
	var board := BoardState.new()
	assert_true(board.load("res://data/location_qingfeng.json", "res://data/items.json", "res://data/enemies.json"))
	board.generate(11)
	for rarity in ["common", "fine", "rare"]:
		for item in board._gen._items_of_rarity(rarity):
			assert_false(bool((item as Dictionary).get("no_drop", false)),
				"no_drop 物（%s 档）不应进掉落池" % rarity)

# ---------- 气血回调属主 ----------

func test_session_recover_hp_clamps() -> void:
	var keep_hp := ExpeditionSession._player_hp
	var keep_max := ExpeditionSession._player_max_hp
	ExpeditionSession._player_max_hp = 50
	ExpeditionSession._player_hp = 45
	ExpeditionSession.recover_hp(10)
	assert_eq(ExpeditionSession.carried_hp(), 50, "会话回血应截断在上限")
	ExpeditionSession._player_hp = keep_hp
	ExpeditionSession._player_max_hp = keep_max
