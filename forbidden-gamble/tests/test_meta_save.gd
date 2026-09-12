extends GutTest

# 据点 meta 存档（MetaArchive）：撤离入库（同 id 叠加）、死亡/力竭不入库、
# 读写往返、坏版本忽略。会话注入裸 MetaArchive，隔离真仓库。

const TEST_META_PATH := "user://test_meta_save.json"

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

func _session() -> Node:
	var s: Node = preload("res://core/expedition/expedition_session.gd").new()
	s.save_path = "user://test_expedition_save.json"  # 不碰真远征档
	var archive := preload("res://core/meta/meta_archive.gd").new()
	archive.meta_path = TEST_META_PATH
	s.archive = archive  # 先注入再入树：_ready 不覆盖已设的仓库
	add_child_autofree(s)
	add_child_autofree(archive)
	return s

func _fake_board(outcome: String, inventory: Array) -> BoardState:
	var board := BoardState.new()
	board.outcome = outcome
	board.inventory = inventory
	return board

func _item(id: String, qty: int, value: int = 10) -> Dictionary:
	return {"id": id, "name": id, "qty": qty, "value": value, "rarity": "common"}

# ---------- 入库结算 ----------

func test_extract_stores_inventory() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("extracted", [_item("jianSui", 2, 25), _item("ganliang", 1, 5)])
	var stored: int = rs.settle_and_end_run()
	assert_eq(stored, 2, "两堆入库")
	assert_eq(rs.archive.warehouse.size(), 2)
	assert_false(rs.is_in_expedition(), "结算后本局结束")
	assert_null(rs.board_state)
	assert_true(FileAccess.file_exists(TEST_META_PATH), "入库后写 meta 档")

func test_store_stacks_by_id() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("extracted", [_item("jianSui", 2), _item("jianSui", 3)])
	rs.settle_and_end_run()
	assert_eq(rs.archive.warehouse.size(), 1, "同 id 合并")
	assert_eq(int(rs.archive.warehouse[0]["qty"]), 5, "数量叠加")

func test_dead_stores_nothing() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("dead", [_item("jianSui", 2)])
	rs.settle_and_end_run()
	assert_true(rs.archive.warehouse.is_empty(), "死亡物资全丢")
	assert_true(rs.archive.equipped["weapon"].is_empty(), "穿戴散失；结算仍写 meta（清角色状态）")

func test_exhausted_stores_nothing() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("exhausted", [_item("jianSui", 2)])
	rs.settle_and_end_run()
	assert_true(rs.archive.warehouse.is_empty(), "力竭物资全丢")

func test_settle_across_runs_accumulates() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("extracted", [_item("jianSui", 2)])
	rs.settle_and_end_run()
	rs.board_state = _fake_board("extracted", [_item("jianSui", 1), _item("yinzi", 4)])
	rs.settle_and_end_run()
	assert_eq(rs.archive.warehouse.size(), 2)
	assert_eq(int(rs.archive.warehouse[0]["qty"]), 3, "跨局累计")

# ---------- 读写往返 ----------

func test_meta_roundtrip() -> void:
	var rs: Node = _session()
	rs.board_state = _fake_board("extracted", [_item("jianSui", 2, 25)])
	rs.settle_and_end_run()
	var rs2: Node = _session()
	rs2.archive.load_meta()
	assert_eq(rs2.archive.warehouse.size(), 1)
	assert_eq(int(rs2.archive.warehouse[0]["qty"]), 2)
	assert_eq(rs2.archive.warehouse_value(), 50, "总价值按件计（价值×数量）")

func test_load_meta_ignores_bad_version() -> void:
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "warehouse": [_item("jianSui", 1)]}))
	file.close()
	var rs: Node = _session()
	rs.archive.load_meta()
	assert_true(rs.archive.warehouse.is_empty(), "版本不符不读取")

func test_load_meta_missing_file() -> void:
	var rs: Node = _session()
	rs.archive.load_meta()
	assert_true(rs.archive.warehouse.is_empty())

# ---------- 穿戴持久化（C-027，meta v3） ----------

func test_equipped_roundtrip_v3() -> void:
	var rs: Node = _session()
	rs.archive.set_equipped({
		"weapon": {"id": "zhanlu", "name": "名剑·湛卢", "qty": 1, "value": 200,
			"uid": 7.0, "dur": 6.0, "rarity": "legend",
			"weapon": {"school": "剑法", "level": 3, "base_dur": 10.0, "effects": []}},
	})
	rs.archive.save_meta()
	var rs2: Node = _session()
	rs2.archive.load_meta()
	assert_eq(int(rs2.archive.equipped["weapon"]["uid"]), 7, "uid/dur 归一成 int 持久")
	assert_eq(int(rs2.archive.equipped["weapon"]["dur"]), 6)
	assert_true(rs2.archive.equipped["armor"].is_empty())

func test_load_meta_v2_file_starts_with_empty_equipped() -> void:
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "warehouse": [_item("jianSui", 1)], "pouch_slots": 1}))
	file.close()
	var rs: Node = _session()
	rs.archive.load_meta()
	assert_eq(int(rs.archive.warehouse[0]["qty"]), 1, "v2 仓库照读（免迁移）")
	assert_true(rs.archive.equipped["weapon"].is_empty(), "旧档没有穿戴栏＝空")

# ---------- 终态开机结算与弃局 ----------

func test_boot_settles_terminal_save() -> void:
	var rs: Node = _session()
	rs.start_run(5)
	rs.board_state.outcome = "extracted"
	rs.board_state.inventory = [_item("jianSui", 2, 25)]
	rs.board_state.equipped["weapon"] = {"id": "tiejian", "name": "铁剑", "qty": 1,
		"value": 15, "uid": 9, "dur": 2, "rarity": "common"}
	rs.save_game()
	rs.end_run()
	assert_true(FileAccess.file_exists(rs.save_path), "撤离后直接退游戏——终态档还在")
	var rs2: Node = _session()
	rs2._settle_terminal_save_at_boot()
	assert_eq(int(rs2.archive.warehouse[0]["qty"]), 2, "开机补结算：背包入库")
	assert_eq(int(rs2.archive.equipped["weapon"]["uid"]), 9, "穿戴跟人走（uid 原样）")
	assert_eq(int(rs2.archive.equipped["weapon"]["dur"]), 2)
	assert_false(FileAccess.file_exists(rs.save_path), "结算完清档，防下次重复入库")

func test_boot_settle_death_clears_equipped() -> void:
	var rs: Node = _session()
	rs.start_run(5)
	rs.board_state.outcome = "dead"
	rs.board_state.equipped["weapon"] = {"id": "tiejian", "name": "铁剑", "qty": 1,
		"value": 15, "uid": 9, "dur": 2, "rarity": "common"}
	rs.board_state.inventory = []
	rs.board_state.pouch = [_item("yinzi", 3, 12)]
	rs.save_game()
	rs.end_run()
	var rs2: Node = _session()
	rs2._settle_terminal_save_at_boot()
	assert_eq(str(rs2.archive.warehouse[0]["id"]), "yinzi", "死亡只保锦囊")
	assert_true(rs2.archive.equipped["weapon"].is_empty(), "开机补结算同样散失穿戴")

func test_abandon_clears_equipped_and_save() -> void:
	var rs: Node = _session()
	rs.archive.set_equipped({
		"weapon": {"id": "tiejian", "name": "铁剑", "qty": 1, "value": 15, "uid": 9, "dur": 2},
	})
	rs.archive.save_meta()
	var file := FileAccess.open(rs.save_path, FileAccess.WRITE)
	file.store_string("{}")
	file.close()
	rs.abandon_run()
	assert_true(rs.archive.equipped["weapon"].is_empty(), "弃局＝穿戴散失")
	assert_false(FileAccess.file_exists(rs.save_path), "弃局＝弃档")
	assert_false(rs.is_in_expedition())
