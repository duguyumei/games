extends GutTest

# 贴身锦囊（M3/C-024，25 号 §6）：换入换出/格数/大类封锁/叠堆/使用/丢弃/
# 死亡与力竭保囊/地点条件跨囊/气息合并入堆计息回归（C-024 修复）。

const TEST_META_PATH := "user://test_pouch_meta.json"

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

# ---------- 构造 ----------

func _items() -> Dictionary:
	return {
		"bao": {"id": "bao", "name": "玉佩", "type": "valuable", "rarity": "rare",
			"value": 30, "max_stack": 99},
		"dan": {"id": "dan", "name": "辟谷丹", "type": "consumable", "subtype": "provision",
			"rarity": "common", "value": 12, "max_stack": 1,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "restore_ap", "amount": 4}]}},
		"yao": {"id": "yao", "name": "伤药", "type": "consumable", "subtype": "medicine",
			"rarity": "common", "value": 10, "max_stack": 2,
			"use": {"scopes": ["explore"], "target": "self", "effects": [{"kind": "heal", "amount": 10}]}},
		"ling": {"id": "ling", "name": "剑令", "type": "consumable", "subtype": "credential",
			"rarity": "fine", "value": 80, "max_stack": 99},
		"jian": {"id": "jian", "name": "湛卢", "type": "weapon", "rarity": "legend", "value": 200},
		"hujia": {"id": "hujia", "name": "护腕", "type": "armor", "rarity": "fine", "value": 35},
		"nang": {"id": "nang", "name": "行囊", "type": "container", "rarity": "common", "value": 10,
			"container": {"slots": 5}},
		"pu": {"id": "pu", "name": "残谱", "type": "manual", "rarity": "rare", "value": 60},
	}

func _enemies() -> Dictionary:
	return {
		"守冢剑影": {"tier": "veteran", "loot_chest": "loot"},
		"守冢剑灵": {"tier": "master", "loot_chest": "loot"},
	}

func _board(extra: Dictionary = {}) -> BoardState:
	var cfg := {
		"name": "测试禁地", "entrance_type": "entrance",
		"ap": {"start": 40, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [], "pursuer_table": [], "scatter_table": [], "npcs": {},
		"chests": {"loot": {"name": "行囊", "ap_cost": 1, "draws": 1, "table": []}},
		"hunt": {"first": 1000, "step": 1000, "avatar": "守冢剑影", "true_body": "守冢剑灵",
			"avatar_life": 10, "avatar_interval": 2, "true_interval_min": 1,
			"true_interval_max": 1, "teleport_distance": 3},
		"location_cards": {
			"vault": {"name": "剑冢秘库", "site_type": "room", "require_item": "ling", "consume": true},
		},
		"continent": {},
		"site_types": {
			"entrance": {"name": "入口", "cards": [], "bottom": []},
			"room": {"name": "密室", "cards": [], "bottom": []},
		},
	}
	for key in extra:
		cfg[key] = extra[key]
	var board := BoardState.new()
	board.config = cfg
	board.items = _items()
	board.enemies = _enemies()
	board.generate(7)
	return board

# 背包塞入 n 件 item_id（用拾取链路，走叠堆规则）。
func _loot(board: BoardState, item_id: String, n: int = 1) -> void:
	for i in range(n):
		assert_true(board._add_to_inventory(board._item(item_id)),
			"预置 %s 第 %d 件应入包" % [item_id, i + 1])

func _events_text(board: BoardState) -> String:
	var drained := board.drain_events()
	return " ".join(drained)

# ---------- 换入换出 ----------

func test_move_to_pouch_and_back_roundtrip() -> void:
	var board := _board()
	_loot(board, "bao")
	assert_true(board.move_to_pouch(0))
	assert_eq(board.inventory.size(), 0, "入囊后背包空")
	assert_eq(board.pouch.size(), 1)
	assert_eq(int(board.pouch[0]["qty"]), 1)
	assert_true(board.move_to_bag(0))
	assert_eq(board.inventory.size(), 1, "回包还原")
	assert_true(board.pouch.is_empty())

func test_pouch_slots_limit_and_upgrade() -> void:
	var board := _board()
	_loot(board, "dan", 2)  # max_stack 1 → 不可合并的两堆
	_loot(board, "bao")
	assert_true(board.move_to_pouch(0))
	assert_false(board.move_to_pouch(0), "默认 1 格已满（同名不可合并）")
	assert_true(_events_text(board).contains("锦囊已满"), "满囊有播报")
	board.pouch_slots = 3
	assert_true(board.move_to_pouch(0), "局外升级后可入第 2 格")

func test_move_is_per_unit() -> void:
	var board := _board()
	_loot(board, "yao", 3)  # max_stack 2 → 背包两堆：yao×2 + yao×1
	assert_eq(board.inventory.size(), 2)
	assert_true(board.move_to_pouch(0))
	assert_eq(int(board.inventory[0]["qty"]), 1, "一次只挪一件")
	assert_eq(int(board.pouch[0]["qty"]), 1)

func test_pouch_stacks_same_id() -> void:
	var board := _board()
	_loot(board, "yao", 2)
	board.move_to_pouch(0)
	assert_true(board.move_to_pouch(0), "同名第二件叠进同一囊格")
	assert_eq(board.pouch.size(), 1)
	assert_eq(int(board.pouch[0]["qty"]), 2)

func test_weapon_armor_and_container_blocked() -> void:
	var board := _board()
	_loot(board, "jian")
	_loot(board, "hujia")
	_loot(board, "nang")
	assert_false(board.move_to_pouch(0), "兵器放不进锦囊")
	assert_false(board.move_to_pouch(0), "护具放不进锦囊")
	assert_false(board.move_to_pouch(0), "行囊放不进锦囊")
	assert_true(_events_text(board).contains("放不进贴身锦囊"))
	assert_eq(board.inventory.size(), 3, "原堆不动")

func test_manual_can_enter_pouch() -> void:
	var board := _board()
	_loot(board, "pu")
	assert_true(board.move_to_pouch(0), "秘籍可入——死里逃生捎回一卷残谱")

func test_pouch_transfer_does_not_add_qixi() -> void:
	var board := _board()
	_loot(board, "bao", 2)
	var qixi_before := board.qixi
	board.move_to_pouch(0)
	board.move_to_bag(0)
	assert_eq(board.qixi, qixi_before, "内部腾挪不计气息（拾取时已计）")

# ---------- C-024 回归：合并入堆同样计息 ----------

func test_stacking_onto_existing_pile_counts_qixi() -> void:
	var board := _board({"hunt": {"first": 24, "step": 1000, "avatar": "守冢剑影",
		"true_body": "守冢剑灵", "avatar_life": 10, "avatar_interval": 2,
		"true_interval_min": 1, "true_interval_max": 1, "teleport_distance": 3}})
	board.items["bao"]["value"] = 12
	board._add_to_inventory(board._item("bao"))  # 新开堆：qixi 12
	assert_eq(board.qixi, 12)
	board._add_to_inventory(board._item("bao"))  # 合并入堆：也应计 12 → 过线 24
	assert_eq(board.qixi, 24, "合并入堆的物资同样涨气息")
	assert_false(board.hunter.is_empty(), "合并入堆的计息应能触发追杀线")

# ---------- 使用与条件 ----------

func test_use_pouch_item() -> void:
	var board := _board()
	_loot(board, "dan")
	board.move_to_pouch(0)
	board.ap = 10
	assert_true(board.use_pouch_item(0))
	assert_eq(board.ap, 14, "囊中辟谷丹照常生效")
	assert_true(board.pouch.is_empty(), "消耗落在锦囊")

func test_use_pouch_consumes_pouch_copy_not_bag() -> void:
	var board := _board()
	_loot(board, "dan", 2)  # max_stack 1 → 背包两堆
	board.move_to_pouch(0)
	assert_true(board.use_pouch_item(0), "用囊中那份")
	assert_eq(board.inventory.size(), 1, "背包剩下的那堆原封不动")

func test_battle_scope_item_unusable_from_pouch() -> void:
	var board := _board()
	board.items["biao"] = {"id": "biao", "name": "淬毒飞镖", "type": "consumable",
		"subtype": "hidden_weapon", "rarity": "rare", "value": 55,
		"use": {"scopes": ["battle"], "target": "enemy", "effects": [{"kind": "damage", "amount": 10}]}}
	_loot(board, "biao")
	board.move_to_pouch(0)
	assert_false(board.use_pouch_item(0), "战斗域道具探索中不可用")
	assert_false(board.pouch_item_usable_in_explore(0))

func test_consume_item_prefers_bag_then_pouch() -> void:
	var board := _board()
	_loot(board, "dan", 2)  # max_stack 1 → 背包两堆
	board.move_to_pouch(0)  # 背包剩一堆、锦囊一堆
	board.consume_item("dan")
	assert_eq(board.inventory.size(), 0, "先消耗背包那份")
	assert_eq(board.pouch.size(), 1, "囊里那份不动")
	board.consume_item("dan")
	assert_true(board.pouch.is_empty(), "背包没有时落到锦囊")

func test_location_requirement_counts_pouch() -> void:
	var board := _board()
	_loot(board, "ling")
	board.move_to_pouch(0)
	var card := {"kind": "location", "location": "vault"}
	assert_true(board.can_open_location(card), "凭证在锦囊也算在身上")
	board.current_site()["grid"].append(card)
	assert_true(board.open_location_cell(0))
	assert_true(board.pouch.is_empty(), "开启消耗落在锦囊那份凭证")

func test_drop_pouch_item() -> void:
	var board := _board()
	_loot(board, "bao")
	board.move_to_pouch(0)
	assert_true(board.drop_pouch_item(0))
	assert_true(board.pouch.is_empty())
	var grid: Array = board.current_site()["grid"]
	assert_eq(str((grid[grid.size() - 1] as Dictionary).get("item_id", "")), "bao", "丢进网格可捡回")

# ---------- 死亡保底 ----------

func test_defeat_keeps_only_pouch() -> void:
	var board := _board()
	_loot(board, "bao", 2)
	_loot(board, "dan")
	board.move_to_pouch(0)
	board.current_site()["grid"].append({"kind": "enemy", "enemy_id": "守冢剑影", "alert": 0})
	board.engage_cell(0)
	board.resolve_battle_result("lose")
	assert_eq(board.outcome, "dead")
	assert_true(board.inventory.is_empty(), "背包当场清空")
	assert_eq(board.pouch.size(), 1, "锦囊原样保留")
	assert_true(_events_text(board).contains("贴身锦囊"), "播报点出保底")

func test_exhausted_keeps_pouch() -> void:
	var board := _board()
	_loot(board, "bao")
	board.move_to_pouch(0)
	board.ap = 1
	board._spend_ap(1)
	assert_eq(board.outcome, "exhausted")
	assert_true(board.inventory.is_empty())
	assert_eq(board.pouch.size(), 1, "力竭同样只保锦囊")

func test_blocked_when_run_over_or_intercept() -> void:
	var board := _board()
	_loot(board, "bao")
	board.outcome = "dead"
	assert_false(board.move_to_pouch(0), "终态不能整理")
	board.outcome = ""
	board.current_site()["grid"].append({"kind": "pursuer", "enemy_id": "守冢剑影", "alert": 0})
	assert_false(board.move_to_pouch(0), "追兵在场不能整理")
	assert_false(board.move_to_bag(0))

# ---------- 存档往返 ----------

func test_pouch_survives_save_roundtrip() -> void:
	var board := _board()
	_loot(board, "bao", 2)
	_loot(board, "dan")
	board.move_to_pouch(0)
	board.move_to_pouch(0)
	var restored := BoardState.new()
	restored.config = board.config
	restored.items = board.items
	restored.enemies = board.enemies
	restored.pouch_slots = board.pouch_slots
	restored.from_dict(JSON.parse_string(JSON.stringify(board.to_dict())))
	# JSON 往返会把 max_stack 等整数字段变 float，全等比较只对语义字段（id/数量）。
	assert_eq(restored.pouch.size(), 1)
	assert_eq(str(restored.pouch[0]["id"]), "bao")
	assert_eq(int(restored.pouch[0]["qty"]), 2, "锦囊内容往返不丢")
	assert_true(restored.move_to_bag(0), "还原后仍可正常腾挪")

# ---------- 结算（会话＋仓库） ----------

func _session_with_archive() -> Array:
	var session: Node = preload("res://core/expedition/expedition_session.gd").new()
	session.save_path = "user://test_pouch_save.json"
	var archive := preload("res://core/meta/meta_archive.gd").new()
	archive.meta_path = TEST_META_PATH
	session.archive = archive
	add_child_autofree(session)
	add_child_autofree(archive)
	return [session, archive]

func test_settle_death_stores_pouch_only() -> void:
	var pair := _session_with_archive()
	var session: Node = pair[0] as Node
	var archive: Node = pair[1] as Node
	var board := _board()
	_loot(board, "bao")
	_loot(board, "dan")
	board.move_to_pouch(0)
	board.resolve_battle_result("lose")
	session.board_state = board
	var stored: int = session.settle_and_end_run()
	assert_eq(stored, 1, "死亡只入锦囊那堆")
	assert_eq(archive.warehouse.size(), 1)
	assert_eq(str(archive.warehouse[0]["id"]), "bao")

func test_settle_extract_stores_bag_and_pouch() -> void:
	var pair := _session_with_archive()
	var session: Node = pair[0] as Node
	var archive: Node = pair[1] as Node
	var board := _board()
	_loot(board, "bao", 2)
	_loot(board, "dan")
	board.move_to_pouch(0)
	board.current_site()["extract"] = true
	assert_true(board.extract())
	session.board_state = board
	var stored: int = session.settle_and_end_run()
	assert_eq(stored, 3, "撤离背包 2 堆＋锦囊 1 堆全入库")
	assert_eq(archive.warehouse.size(), 2, "同 id 跨囊合并")

func test_carried_value_counts_units_and_pouch() -> void:
	var pair := _session_with_archive()
	var session: Node = pair[0] as Node
	var board := _board()
	_loot(board, "bao", 2)  # 30×2
	_loot(board, "dan")     # 12
	board.move_to_pouch(0)
	session.board_state = board
	assert_eq(session.carried_value(), 72, "按件计（价值×数量），含锦囊")

func test_archive_pouch_slots_default_upgrade_and_roundtrip() -> void:
	var pair := _session_with_archive()
	var archive: Node = pair[1] as Node
	assert_eq(archive.pouch_slots, 1, "初始 1 格（M4：局外升级 1→3）")
	archive.set_pouch_slots(9)
	assert_eq(archive.pouch_slots, 3, "封顶 3")
	archive.set_pouch_slots(0)
	assert_eq(archive.pouch_slots, 1, "下限 1")
	archive.set_pouch_slots(2)
	archive.save_meta()
	var archive2 := preload("res://core/meta/meta_archive.gd").new()
	archive2.meta_path = TEST_META_PATH
	add_child_autofree(archive2)
	archive2.load_meta()
	assert_eq(archive2.pouch_slots, 2, "升级数随 meta 档往返")
	var archive3 := preload("res://core/meta/meta_archive.gd").new()
	archive3.meta_path = TEST_META_PATH
	add_child_autofree(archive3)
	archive3.set_pouch_slots(3)
	archive3.save_meta()
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "warehouse": []}))
	file.close()
	archive3.load_meta()
	assert_eq(archive3.pouch_slots, 1, "旧档无此字段读新默认 1（免迁移）")
