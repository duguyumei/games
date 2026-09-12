extends GutTest

# 备战装配（C-027，ExpeditionPrep）：仓库⇄穿戴（旧件回仓库、小行囊约束）、
# 装载购物车（整堆带走、按叠上限分堆、容量约束、放回合并）、锦囊封锁类型、
# 购物车持续保存（退出重进恢复、出发消费清车）、meta 档提交与 v1~v3 旧档免迁移。

const TEST_META_PATH := "user://test_prep_meta.json"
const ArchiveScript := preload("res://core/meta/meta_archive.gd")

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

# ---------- 构造 ----------

func _archive() -> Node:
	var archive := ArchiveScript.new()
	archive.meta_path = TEST_META_PATH
	add_child_autofree(archive)
	return archive

func _prep(archive: Node, backpack_size := 5) -> ExpeditionPrep:
	var prep := ExpeditionPrep.new()
	prep.setup(archive, {"backpack_size": backpack_size})
	return prep

func _tiejian() -> Dictionary:
	return {"id": "tiejian", "name": "制式铁剑", "type": "weapon", "qty": 1, "value": 15,
		"rarity": "common", "weapon": {"school": "剑法", "level": 1, "base_dur": 3, "effects": []}}

func _zhanlu(dur := 9) -> Dictionary:
	return {"id": "zhanlu", "name": "名剑·湛卢", "type": "weapon", "qty": 1, "value": 200,
		"uid": 7, "dur": dur, "rarity": "legend",
		"weapon": {"school": "剑法", "level": 3, "base_dur": 10, "effects": []}}

func _hujia() -> Dictionary:
	return {"id": "hujia", "name": "牛皮护腕", "type": "armor", "qty": 1, "value": 35,
		"rarity": "fine", "armor": {"level": 1, "base_dur": 4, "effects": []}}

func _bag(slots := 5) -> Dictionary:
	return {"id": "cubu", "name": "粗布行囊", "type": "container", "qty": 1, "value": 10,
		"rarity": "common", "container": {"slots": slots}}

func _bao(qty := 1) -> Dictionary:
	return {"id": "bao", "name": "玉佩", "type": "valuable", "qty": qty, "value": 30,
		"max_stack": 5, "rarity": "fine"}

# n 堆互不相叠的玉佩（id 各异——容量测试要的是"堆数"不是数量）
func _piles(n: int) -> Array:
	var out: Array = []
	for i in range(n):
		out.append({"id": "bao%d" % i, "name": "玉佩·%d" % i, "type": "valuable", "qty": 1,
			"value": 30, "max_stack": 1, "rarity": "fine"})
	return out

func _yao(qty := 1) -> Dictionary:
	return {"id": "shangyao", "name": "伤药", "type": "consumable", "qty": qty, "value": 10,
		"max_stack": 5, "rarity": "common"}

# ---------- 穿戴 ----------

func test_wear_from_warehouse_issues_uid_and_dur() -> void:
	var archive := _archive()
	archive.store_items([_tiejian()])
	var prep := _prep(archive)
	assert_true(prep.wear(0))
	assert_eq(str(archive.equipped["weapon"]["id"]), "tiejian")
	assert_true(archive.equipped["weapon"].has("uid"), "裸定义穿上即取号成实例")
	assert_eq(int(archive.equipped["weapon"]["dur"]), 3, "耐久从 base_dur 起步")
	assert_true(archive.warehouse.is_empty())

func test_wear_swaps_old_back_to_warehouse() -> void:
	var archive := _archive()
	archive.store_items([_zhanlu(9), _tiejian()])
	var prep := _prep(archive)
	assert_true(prep.wear(0), "先穿湛卢")
	assert_true(prep.wear(0), "再换铁剑——旧湛卢回仓库")
	assert_eq(str(archive.equipped["weapon"]["id"]), "tiejian")
	assert_eq(archive.warehouse.size(), 1)
	assert_eq(str(archive.warehouse[0]["id"]), "zhanlu")
	assert_eq(int(archive.warehouse[0]["dur"]), 9, "磨损程度原样入库")

func test_wear_rejects_non_equipment() -> void:
	var archive := _archive()
	archive.store_items([_bao(1)])
	var prep := _prep(archive)
	assert_false(prep.wear(0))
	assert_true(prep.last_note.contains("不是能穿戴"))

func test_wear_smaller_bag_blocked_by_cart() -> void:
	var archive := _archive()
	var stock: Array = [_bag(8), _bag(5)]
	stock.append_array(_piles(6))
	archive.store_items(stock)
	var prep := _prep(archive)
	assert_true(prep.wear(0), "先穿 8 格行囊")
	# 行囊出库后：小行囊在 0，六堆玉佩从 1 起排
	for i in range(6):
		assert_true(prep.take(1), "带走 6 堆玉佩（每堆取走后后面的前移）")
	assert_false(prep.wear(0), "换 5 格小行囊装不下 6 堆")
	assert_true(prep.last_note.contains("放不进"))
	assert_eq(prep.backpack_capacity(), 8, "原行囊不动")

func test_unwear_bag_blocked_over_fallback() -> void:
	var archive := _archive()
	var stock: Array = [_bag(8)]
	stock.append_array(_piles(6))
	archive.store_items(stock)
	var prep := _prep(archive)
	assert_true(prep.wear(0))
	for i in range(6):
		assert_true(prep.take(0))
	assert_false(prep.unwear("bag"), "卸行囊后兜底 5 格装不下 6 堆")
	assert_true(prep.last_note.contains("装不下"))
	assert_eq(str(archive.equipped["bag"]["id"]), "cubu", "行囊还在身上")

func test_unwear_puts_equipment_back_to_warehouse() -> void:
	var archive := _archive()
	archive.store_items([_hujia()])
	var prep := _prep(archive)
	assert_true(prep.wear(0))
	assert_true(prep.unwear("armor"))
	assert_true(archive.equipped["armor"].is_empty())
	assert_eq(archive.warehouse.size(), 1)
	assert_true(archive.warehouse[0].has("uid"), "实例入库不丢身份")

func test_capacity_follows_equipped_bag() -> void:
	var archive := _archive()
	var prep := _prep(archive)
	assert_eq(prep.backpack_capacity(), 5, "没穿行囊走禁地兜底")
	archive.store_items([_bag(8)])
	assert_true(prep.wear(0))
	assert_eq(prep.backpack_capacity(), 8)

# ---------- 装载购物车 ----------

func test_take_whole_stack_splits_by_max_stack() -> void:
	var archive := _archive()
	archive.store_items([_yao(9)])
	var prep := _prep(archive)
	assert_true(prep.take(0))
	assert_eq(prep.backpack.size(), 2, "9 件伤药按叠上限 5 分成 5＋4 两堆")
	assert_eq(int(prep.backpack[0]["qty"]), 5)
	assert_eq(int(prep.backpack[1]["qty"]), 4)
	assert_true(archive.warehouse.is_empty(), "整堆带走清出仓库")

func test_take_partial_leaves_remainder_in_warehouse() -> void:
	var archive := _archive()
	archive.store_items([_yao(7), _bao(1)])
	var prep := _prep(archive, 1)  # 兜底 1 格
	assert_true(prep.take(0), "第一堆 5 件占满唯一一格")
	assert_eq(int(prep.backpack[0]["qty"]), 5)
	assert_eq(int(archive.warehouse[0]["qty"]), 2, "装不下的 2 件留在仓库")
	assert_false(prep.take(0), "背包满，余量带不走")
	assert_true(prep.last_note.contains("装满"))

func test_take_equipment_each_occupies_a_slot() -> void:
	var archive := _archive()
	archive.store_items([_tiejian(), _tiejian()])
	var prep := _prep(archive, 5)
	assert_true(prep.take(0))
	assert_false(prep.take_pouch(0), "兵器放不进贴身锦囊")
	assert_true(prep.take(0), "第二把进背包")
	assert_eq(prep.backpack.size(), 2, "两把铁剑各占一格（实例不叠）")
	assert_ne(int(prep.backpack[0]["uid"]), int(prep.backpack[1]["uid"]))

func test_pouch_capacity_from_archive_upgrade() -> void:
	var archive := _archive()
	archive.store_items([_bao(1), _yao(1)])
	var prep := _prep(archive)
	assert_eq(prep.pouch_capacity(), 1, "锦囊格数＝局外升级（初始 1）")
	assert_true(prep.take_pouch(0))
	assert_false(prep.take_pouch(0), "1 格已满")
	archive.set_pouch_slots(2)
	assert_true(prep.take_pouch(0))

func test_stash_merges_back_into_warehouse() -> void:
	var archive := _archive()
	archive.store_items([_bao(2)])
	var prep := _prep(archive)
	assert_true(prep.take(0))
	assert_true(prep.stash(0), "整堆放回")
	assert_true(archive.warehouse.size() == 1 and int(archive.warehouse[0]["qty"]) == 2,
		"放回与仓库同 id 叠数量")

func test_stash_pouch_roundtrip() -> void:
	var archive := _archive()
	archive.store_items([_yao(2)])
	var prep := _prep(archive)
	assert_true(prep.take_pouch(0))
	assert_eq(prep.pouch.size(), 1)
	assert_true(prep.stash_pouch(0))
	assert_eq(prep.pouch.size(), 0)
	assert_eq(int(archive.warehouse[0]["qty"]), 2)

# ---------- 购物车持续保存（退出重进不丢；C-027 丢档修复） ----------

func test_cart_survives_reload_and_new_prep_instance() -> void:
	var archive := _archive()
	archive.store_items([_yao(5), _bao(2)])
	var prep := _prep(archive)
	assert_true(prep.take(0))
	assert_true(prep.take_pouch(0))
	# 退出游戏再开＝重读同一份 meta 档；重进备战页＝新 ExpeditionPrep 实例
	var archive2 := ArchiveScript.new()
	archive2.meta_path = TEST_META_PATH
	add_child_autofree(archive2)
	archive2.load_meta()
	var prep2 := _prep(archive2)
	assert_eq(prep2.backpack.size(), 1, "背包购物车随 meta 档恢复")
	assert_eq(str(prep2.backpack[0]["id"]), "shangyao")
	assert_eq(int(prep2.backpack[0]["qty"]), 5)
	assert_eq(prep2.pouch.size(), 1, "锦囊购物车随 meta 档恢复")
	assert_eq(str(prep2.pouch[0]["id"]), "bao")

func test_restored_cart_still_works() -> void:
	var archive := _archive()
	archive.store_items([_bao(3)])
	var prep := _prep(archive)
	assert_true(prep.take(0))
	var prep2 := _prep(archive, 5)  # 重进（同档案新实例）：恢复的是同一辆车
	assert_eq(prep2.backpack.size(), 1)
	assert_true(prep2.stash(0), "恢复的车照常整堆放回")
	assert_eq(int(archive.warehouse[0]["qty"]), 3)
	assert_true((archive.prep_cart["backpack"] as Array).is_empty(), "放回后档案里的车同步清空")

func test_consume_cart_after_depart() -> void:
	var archive := _archive()
	archive.store_items([_yao(5)])
	var prep := _prep(archive)
	assert_true(prep.take(0))
	var payload := prep.payload()
	assert_eq((payload["inventory"] as Array).size(), 1, "载荷带上装配的物资")
	prep.consume_cart()
	assert_true(prep.backpack.is_empty())
	var archive2 := ArchiveScript.new()
	archive2.meta_path = TEST_META_PATH
	add_child_autofree(archive2)
	archive2.load_meta()
	assert_true((archive2.prep_cart["backpack"] as Array).is_empty(), "出发后 meta 档里车已清")

func test_v3_save_loads_with_empty_cart() -> void:
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 3, "warehouse": [], "pouch_slots": 1, "uid_next": 1, "equipped": {}}))
	file.close()
	var archive := ArchiveScript.new()
	archive.meta_path = TEST_META_PATH
	add_child_autofree(archive)
	archive.load_meta()
	assert_true((archive.prep_cart["backpack"] as Array).is_empty(), "v3 旧档免迁移直读，车为空")

# ---------- meta 档提交与旧档兼容 ----------

func test_wear_commits_to_meta_file() -> void:
	var archive := _archive()
	archive.store_items([_zhanlu(6)])
	var prep := _prep(archive)
	assert_true(prep.wear(0))
	var archive2 := ArchiveScript.new()
	archive2.meta_path = TEST_META_PATH
	add_child_autofree(archive2)
	archive2.load_meta()
	assert_eq(int(archive2.equipped["weapon"]["uid"]), 7, "穿戴随 meta 档持久（uid 原样）")
	assert_eq(int(archive2.equipped["weapon"]["dur"]), 6)

func test_payload_is_a_deep_copy() -> void:
	var archive := _archive()
	archive.store_items([_zhanlu(6)])
	var prep := _prep(archive)
	assert_true(prep.wear(0))
	var payload := prep.payload()
	(payload["equipped"]["weapon"] as Dictionary)["dur"] = 1
	(payload["inventory"] as Array).append(_bao(1))
	assert_eq(int(archive.equipped["weapon"]["dur"]), 6, "改载荷不回写角色状态")
	assert_true(prep.backpack.is_empty())
