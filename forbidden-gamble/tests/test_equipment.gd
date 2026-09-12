extends GutTest

# 穿戴栏（M4，25 号 §1；C-027 改跨局角色状态）：装备实例（uid 不叠堆）、穿戴换装、
# 背包容量随行囊、每战耐久磨损与折断、战斗载荷（系别增幅/减伤）、死亡散失与撤离
# 原样带回（耐久照旧）、备战载荷 start_run(prep)、存档 v6 往返。
# 备战页装配规则见 test_prep；战斗侧增幅/减伤规则见 test_technique_resolver。

const TEST_META_PATH := "user://test_equipment_meta.json"
const SessionScript := preload("res://core/expedition/expedition_session.gd")
const ArchiveScript := preload("res://core/meta/meta_archive.gd")

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

# ---------- 构造 ----------

func _items() -> Dictionary:
	return {
		"bao": {"id": "bao", "name": "玉佩", "type": "valuable", "rarity": "fine",
			"value": 30, "max_stack": 1},
		"tiejian": {"id": "tiejian", "name": "制式铁剑", "type": "weapon", "rarity": "common",
			"value": 15, "weapon": {"school": "剑法", "level": 1, "base_dur": 3, "effects": []}},
		"zhanlu": {"id": "zhanlu", "name": "名剑·湛卢", "type": "weapon", "rarity": "legend",
			"value": 200, "weapon": {"school": "剑法", "level": 3, "base_dur": 10, "effects": []}},
		"daogao": {"id": "daogao", "name": "雁翎刀", "type": "weapon", "rarity": "fine",
			"value": 45, "weapon": {"school": "刀法", "level": 2, "base_dur": 5, "effects": []}},
		"hujia": {"id": "hujia", "name": "牛皮护腕", "type": "armor", "rarity": "fine",
			"value": 35, "armor": {"level": 1, "base_dur": 4, "effects": []}},
		"cubu": {"id": "cubu", "name": "粗布行囊", "type": "container", "rarity": "common",
			"value": 10, "container": {"slots": 5}},
		"dashang": {"id": "dashang", "name": "大座行囊", "type": "container", "rarity": "rare",
			"value": 120, "container": {"slots": 12}},
	}

func _enemies() -> Dictionary:
	return {"shandafei": {"tier": "normal", "loot_chest": "loot"}}

func _board(extra: Dictionary = {}) -> BoardState:
	var cfg := {
		"name": "测试禁地", "entrance_type": "entrance", "backpack_size": 12,
		"ap": {"start": 40, "travel": 1},
		"alert": {"cap": 10, "near1": 2, "near2": 1, "decay": 1, "combat_ap": 2},
		"alert_levels": [], "pursuer_table": [], "scatter_table": [], "npcs": {},
		"chests": {"loot": {"name": "行囊", "ap_cost": 1, "draws": 1, "table": []}},
		"hunt": {"first": 1000, "step": 1000, "avatar": "shandafei", "true_body": "shandafei",
			"avatar_life": 10, "avatar_interval": 2, "true_interval_min": 1,
			"true_interval_max": 1, "teleport_distance": 3},
		"continent": {},
		"site_types": {"entrance": {"name": "入口", "cards": [], "bottom": []}},
	}
	for key in extra:
		cfg[key] = extra[key]
	var board := BoardState.new()
	board.config = cfg
	board.items = _items()
	board.enemies = _enemies()
	# 测试自备 uid 取号器（正式链路走 MetaArchive.next_uid；字典捕获让闭包可变）
	var uid_state := {"next": 1}
	board.issue_uid = func() -> int:
		uid_state["next"] += 1
		return uid_state["next"] - 1
	board.generate(7)
	return board

func _loot(board: BoardState, item_id: String, n: int = 1) -> void:
	for i in range(n):
		assert_true(board._add_to_inventory(board._item(item_id)),
			"预置 %s 第 %d 件应入包" % [item_id, i + 1])

func _events_text(board: BoardState) -> String:
	return " ".join(board.drain_events())

func _session() -> Array:
	var session: Node = SessionScript.new()
	session.save_path = "user://test_equipment_save.json"
	var archive := ArchiveScript.new()
	archive.meta_path = TEST_META_PATH
	session.archive = archive
	add_child_autofree(session)
	add_child_autofree(archive)
	return [session, archive]

# ---------- 实例形态 ----------

func test_equipment_instances_do_not_stack() -> void:
	var board := _board()
	_loot(board, "daogao", 2)
	assert_eq(board.inventory.size(), 2, "两把同名刀各占一格")
	assert_ne(int(board.inventory[0]["uid"]), int(board.inventory[1]["uid"]), "uid 各不相同")
	assert_eq(int(board.inventory[0]["dur"]), 5, "入包即带初始耐久")

func test_uid_comes_from_archive_counter() -> void:
	var board := _board()
	var inst: Dictionary = board._instance_of(board._item("zhanlu"))
	assert_eq(int(inst["uid"]), 1)
	assert_eq(int(inst["dur"]), 10, "兵器实例带初始耐久")
	var bag: Dictionary = board._instance_of(board._item("cubu"))
	assert_false(bag.has("dur"), "行囊实例没有耐久字段")

# ---------- 穿戴与换装 ----------

func test_equip_and_unequip_roundtrip() -> void:
	var board := _board()
	_loot(board, "tiejian")
	assert_true(board.equip_from_inventory(0))
	assert_eq(board.inventory.size(), 0)
	assert_eq(str(board.equipped["weapon"]["id"]), "tiejian")
	assert_eq(board.equipped_weapon_school(), "剑法")
	assert_eq(board.equipped_weapon_level(), 1)
	assert_true(board.unequip_to_inventory("weapon"))
	assert_eq(str(board.inventory[0]["id"]), "tiejian", "卸下回背包")
	assert_true(board.equipped["weapon"].is_empty())

func test_equip_rejects_non_wearable() -> void:
	var board := _board()
	_loot(board, "bao")
	assert_false(board.equip_from_inventory(0), "宝物穿不上身")
	assert_true(_events_text(board).contains("不是能穿戴"))

func test_equip_swaps_old_back_to_bag() -> void:
	var board := _board()
	_loot(board, "tiejian")
	_loot(board, "zhanlu")
	assert_true(board.equip_from_inventory(0))
	assert_true(board.equip_from_inventory(0), "换穿湛卢")
	assert_eq(str(board.equipped["weapon"]["id"]), "zhanlu")
	assert_eq(board.inventory.size(), 1, "旧铁剑回背包")
	assert_eq(str(board.inventory[0]["id"]), "tiejian")

func test_equip_blocked_when_bag_full_and_slot_occupied() -> void:
	var board := _board({"backpack_size": 2})
	_loot(board, "tiejian")
	_loot(board, "bao")
	assert_true(board.equip_from_inventory(0), "铁剑上身，背包腾出 1 格")
	_loot(board, "daogao")
	# 换穿需要把旧铁剑放回背包，但背包已满（bao+daogao=2）
	assert_false(board.equip_from_inventory(1))
	assert_true(_events_text(board).contains("腾不出来"))
	assert_eq(str(board.equipped["weapon"]["id"]), "tiejian", "原穿戴不动")

func test_wear_actions_blocked_at_terminal_or_intercept() -> void:
	var board := _board()
	_loot(board, "tiejian")
	board.outcome = "dead"
	assert_false(board.equip_from_inventory(0), "终态不能整理")
	assert_false(board.unequip_to_inventory("weapon"))
	board.outcome = ""
	board.current_site()["grid"].insert(0, {"kind": "pursuer", "enemy_id": "shandafei", "alert": 0})
	assert_false(board.equip_from_inventory(0), "追兵压顶不能整理")

# ---------- 行囊与容量 ----------

func test_bag_capacity_from_equipped_container() -> void:
	var board := _board()
	assert_eq(board.backpack_capacity(), 12, "没穿行囊兜底 config.backpack_size")
	_loot(board, "cubu")
	assert_true(board.equip_from_inventory(0))
	assert_eq(board.backpack_capacity(), 5, "粗布行囊 5 格")
	_loot(board, "bao", 5)
	assert_eq(board.inventory.size(), 5)
	assert_false(board._add_to_inventory(board._item("bao")), "5 格装满拒收")

func test_upgrade_bag_keeps_contents_and_downgrade_blocked() -> void:
	var board := _board()
	_loot(board, "cubu")
	board.equip_from_inventory(0)
	_loot(board, "bao", 4)
	_loot(board, "dashang")
	assert_true(board.equip_from_inventory(4), "换大行囊")
	assert_eq(board.backpack_capacity(), 12)
	assert_eq(board.inventory.size(), 5, "原物不散落（4 玉佩＋换下的粗布行囊）")
	_loot(board, "bao")
	# 再换回小行囊：背包 6 件 > 5 格，应被拒（换下的行囊也要占一格）
	assert_false(board.equip_from_inventory(4), "换下的粗布行囊在 4 号位")
	assert_true(_events_text(board).contains("放不进"))

func test_unequip_bag_blocked_when_over_fallback_capacity() -> void:
	var board := _board({"backpack_size": 2})
	_loot(board, "cubu")
	board.equip_from_inventory(0)
	_loot(board, "bao", 5)
	assert_false(board.unequip_to_inventory("bag"), "卸行囊后兜底 2 格装不下 6 件")

# ---------- 每战磨损 ----------

func _fight_and_win(board: BoardState) -> void:
	board.current_site()["grid"].insert(0, {"kind": "enemy", "enemy_id": "shandafei", "alert": 0})
	board.engage_cell(0)
	board.resolve_battle_result("win")

func test_battle_wears_weapon_and_armor_by_one() -> void:
	var board := _board()
	_loot(board, "tiejian")
	_loot(board, "hujia")
	board.equip_from_inventory(0)
	board.equip_from_inventory(0)
	_fight_and_win(board)
	assert_eq(int(board.equipped["weapon"]["dur"]), 2, "铁剑 3→2")
	assert_eq(int(board.equipped["armor"]["dur"]), 3, "护腕 4→3")
	assert_true(_events_text(board).contains("磨损"))

func test_equipment_breaks_at_zero_durability() -> void:
	var board := _board()
	_loot(board, "tiejian")
	board.equip_from_inventory(0)
	board.equipped["weapon"]["dur"] = 1
	_fight_and_win(board)
	assert_true(board.equipped["weapon"].is_empty(), "耐久归零兵器折断")
	assert_true(_events_text(board).contains("彻底损毁"))
	assert_eq(board.equipped_weapon_school(), "", "折断后空手（无增幅）")

func test_losing_battle_does_not_wear_but_clears_equipped() -> void:
	var board := _board()
	_loot(board, "tiejian")
	board.equip_from_inventory(0)
	board.current_site()["grid"].insert(0, {"kind": "enemy", "enemy_id": "shandafei", "alert": 0})
	board.engage_cell(0)
	board.resolve_battle_result("lose")
	assert_true(board.equipped["weapon"].is_empty(), "败局装备全丢，谈不上磨损")

# ---------- 战斗载荷 ----------

func test_battle_context_carries_equipment() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var board := _board()
	_loot(board, "zhanlu")
	_loot(board, "hujia")
	board.equip_from_inventory(0)
	board.equip_from_inventory(0)
	session.board_state = board
	board.current_site()["grid"].insert(0, {"kind": "enemy", "enemy_id": "shandafei", "alert": 0})
	session.prepare_battle("shandafei")
	var ctx: Dictionary = session.take_battle_context()
	assert_eq(str(ctx["weapon_school"]), "剑法")
	assert_eq(int(ctx["weapon_level"]), 3, "湛卢等级 3＝同系功法伤害+3")
	assert_eq(int(ctx["armor_defend"]), 1, "护腕等级 1＝减伤 1")

# ---------- 死亡/撤离与价值口径（C-027：穿戴是角色状态） ----------

func test_settle_extract_banks_loot_but_equipped_stays_on_you() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var archive: Node = pair[1] as Node
	var board := _board()
	_loot(board, "zhanlu")
	board.equip_from_inventory(0)
	_loot(board, "bao")
	board.current_site()["extract"] = true
	assert_true(board.extract())
	session.board_state = board
	var stored: int = session.settle_and_end_run()
	assert_eq(stored, 1, "只有背包 1 堆入库（穿戴不入库）")
	assert_eq(archive.warehouse.size(), 1)
	assert_eq(str(archive.warehouse[0]["id"]), "bao")
	assert_eq(str(archive.equipped["weapon"]["id"]), "zhanlu", "湛卢跟人走")
	assert_true(archive.equipped["weapon"].has("uid"), "实例 uid 原样带回")
	assert_true(FileAccess.file_exists(TEST_META_PATH), "结算必写 meta（穿戴持久化）")

func test_settle_death_clears_equipped_and_banks_pouch_only() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var archive: Node = pair[1] as Node
	var board := _board()
	_loot(board, "zhanlu")
	board.equip_from_inventory(0)
	_loot(board, "bao")
	board.move_to_pouch(0)
	board.current_site()["grid"].insert(0, {"kind": "enemy", "enemy_id": "shandafei", "alert": 0})
	board.engage_cell(0)
	board.resolve_battle_result("lose")
	session.board_state = board
	var stored: int = session.settle_and_end_run()
	assert_eq(stored, 1, "死亡只保锦囊 1 堆")
	assert_eq(str(archive.warehouse[0]["id"]), "bao")
	assert_true(archive.equipped["weapon"].is_empty(), "倒下即散失——角色穿戴清空")
	assert_true(archive.equipped["bag"].is_empty())

func test_banked_value_excludes_equipped() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var board := _board()
	_loot(board, "zhanlu")
	board.equip_from_inventory(0)
	_loot(board, "bao")
	session.board_state = board
	assert_eq(session.carried_value(), 230, "随身口径含穿戴湛卢 200＋玉佩 30")
	assert_eq(session.banked_value(), 30, "入库口径只算背包＋锦囊")
	assert_eq(session.pouch_value(), 0, "死亡保底口径只看锦囊")

func test_warehouse_keeps_two_same_id_weapons_separate() -> void:
	var pair := _session()
	var archive: Node = pair[1] as Node
	archive.store_items([
		{"id": "daogao", "name": "雁翎刀", "qty": 1, "value": 45, "uid": 1, "dur": 5},
		{"id": "daogao", "name": "雁翎刀", "qty": 1, "value": 45, "uid": 2, "dur": 1},
	])
	assert_eq(archive.warehouse.size(), 2, "装备实例永不叠堆")
	assert_eq(archive.warehouse_value(), 90, "价值按件计")

func test_carried_value_includes_equipped_but_pouch_value_not() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var board := _board()
	_loot(board, "zhanlu")
	board.equip_from_inventory(0)
	_loot(board, "bao")
	session.board_state = board
	assert_eq(session.carried_value(), 230, "穿戴湛卢 200＋背包玉佩 30")
	assert_eq(session.pouch_value(), 0, "死亡保底口径只看锦囊")

func test_archive_uid_counter_roundtrip() -> void:
	var pair := _session()
	var archive: Node = pair[1] as Node
	assert_eq(archive.next_uid(), 1)
	assert_eq(archive.next_uid(), 2)
	archive.save_meta()
	var archive2 := ArchiveScript.new()
	archive2.meta_path = TEST_META_PATH
	add_child_autofree(archive2)
	archive2.load_meta()
	assert_eq(archive2.next_uid(), 3, "uid 计数器随 meta 档往返，跨局不撞号")

# ---------- 存档 v6 往返 ----------

func test_save_v6_roundtrip_keeps_equipped_and_instances() -> void:
	var board := _board()
	_loot(board, "zhanlu")
	_loot(board, "daogao")  # 背包里留一件没穿的实例
	assert_true(board.equip_from_inventory(0))
	var restored := BoardState.new()
	restored.config = board.config
	restored.items = board.items
	restored.enemies = board.enemies
	restored.pouch_slots = board.pouch_slots
	restored.from_dict(JSON.parse_string(JSON.stringify(board.to_dict())))
	assert_eq(str(restored.equipped["weapon"]["id"]), "zhanlu", "穿戴栏往返")
	assert_eq(int(restored.equipped["weapon"]["dur"]), 10)
	assert_eq(int(restored.equipped["weapon"]["uid"]), 1)
	assert_eq(str(restored.inventory[0]["id"]), "daogao", "背包里的装备实例往返")
	assert_eq(int(restored.inventory[0]["uid"]), 2)
	assert_eq(int(restored.inventory[0]["dur"]), 5)
	assert_eq(restored.backpack_capacity(), 12, "没穿行囊读兜底容量")

# ---------- 备战载荷（C-027：开局穿什么带什么全凭备战页） ----------

func test_start_run_without_prep_starts_bare_handed() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	session.start_run(7)
	var board: BoardState = session.board_state
	assert_true(board.equipped["weapon"].is_empty(), "没有保底配发——空手开局")
	assert_true(board.equipped["bag"].is_empty())
	assert_true(board.inventory.is_empty())
	assert_true(board.pouch.is_empty())
	assert_eq(board.backpack_capacity(), 5, "无行囊走兜底格数（config.backpack_size）")

# 仓库里备好行头与物资，走一遍完整备战→出发
func test_full_prep_to_run_roundtrip() -> void:
	var pair := _session()
	var session: Node = pair[0] as Node
	var archive: Node = pair[1] as Node
	archive.store_items([
		{"id": "zhanlu", "name": "名剑·湛卢", "type": "weapon", "qty": 1, "value": 200,
			"uid": 7, "dur": 9, "rarity": "legend",
			"weapon": {"school": "剑法", "level": 3, "base_dur": 10, "effects": []}},
		{"id": "bao", "name": "玉佩", "type": "valuable", "qty": 3, "value": 30, "max_stack": 5, "rarity": "fine"},
		{"id": "shangyao", "name": "伤药", "type": "consumable", "qty": 2, "value": 10, "max_stack": 5, "rarity": "common"},
	])
	var prep := ExpeditionPrep.new()
	prep.setup(archive, {"backpack_size": 5})
	assert_true(prep.wear(0), "穿上仓库里的湛卢")
	assert_true(prep.take(0), "整堆带走玉佩")
	assert_true(prep.take_pouch(0), "伤药贴身")
	assert_true(archive.warehouse.is_empty(), "全部带走后仓库清空")
	var payload := prep.payload()
	session.start_run(11, payload)
	var board: BoardState = session.board_state
	assert_eq(str(board.equipped["weapon"]["id"]), "zhanlu")
	assert_eq(int(board.equipped["weapon"]["dur"]), 9, "磨损程度原样带出")
	assert_eq(board.inventory.size(), 1)
	assert_eq(int(board.inventory[0]["qty"]), 3, "玉佩整堆 3 件")
	assert_eq(board.pouch.size(), 1)
	assert_eq(int(board.pouch[0]["qty"]), 2)
	# 局内磨损不回写：payload 与仓库是独立拷贝
	board.equipped["weapon"]["dur"] = 1
	assert_ne(int(prep.payload()["equipped"]["weapon"]["dur"]), 1)
