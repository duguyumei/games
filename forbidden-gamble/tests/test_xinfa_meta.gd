extends GutTest

# MetaArchive v5（D-060）：已学清单、构筑配置、研读秘籍（参悟即蚀）、存档往返与旧档迁移。

const TEST_META_PATH := "user://test_xinfa_meta.json"

func after_each() -> void:
	if FileAccess.file_exists(TEST_META_PATH):
		DirAccess.remove_absolute(TEST_META_PATH)

func _archive() -> Node:
	var archive: Node = preload("res://core/meta/meta_archive.gd").new()
	archive.meta_path = TEST_META_PATH
	add_child_autofree(archive)
	return archive

# ---------- 默认构筑与清单 ----------

func test_fresh_archive_defaults_from_player_def() -> void:
	var archive := _archive()
	assert_eq(archive.learned_techniques.size(), 6, "默认已学功法来自 player.json")
	assert_eq(archive.learned_xinfa.size(), 3, "默认已学心法来自 player.json")
	assert_eq(archive.loadout["xinfa"].size(), 3, "默认构筑镜像初始清单")
	assert_true(archive.knows_xinfa("调息诀"))
	assert_true(archive.knows_technique("纵横式"))

func test_set_loadout_validates() -> void:
	var archive := _archive()
	archive.learn_xinfa("龟息功")
	# 未学的心法被忽略、重复被去重、超槽被截断（传入 6 项，合法唯一者 4 项）
	archive.set_loadout("xinfa", ["调息诀", "不存在的心法", "调息诀", "先纳功", "养木功", "龟息功"])
	assert_eq(archive.loadout["xinfa"].size(), 4)
	assert_false(archive.loadout["xinfa"].has("不存在的心法"), "未学心法进不了构筑")
	assert_eq((archive.loadout["xinfa"] as Array).count("调息诀"), 1, "同名心法唯一")
	var six: Array = []
	for id in ["调息诀", "先纳功", "养木功", "龟息功", "先机诀", "长息诀"]:
		archive.learn_xinfa(id)
		six.append(id)
	archive.set_loadout("xinfa", six)
	assert_eq(archive.loadout["xinfa"].size(), 5, "心法槽上限 5（第 6 门截断）")
	archive.set_loadout("techniques", ["点星式", "连风式"])
	assert_eq(archive.loadout["techniques"].size(), 2)
	archive.set_loadout("bad_slot", [])
	assert_false(archive.loadout.has("bad_slot"), "未知槽类型拒绝")

# ---------- 研读（参悟即蚀） ----------

func test_study_manual_learns_and_consumes() -> void:
	var archive := _archive()
	archive.store_items([{"id": "guixigupian", "name": "龟息古篇", "qty": 2, "value": 45, "rarity": "fine"}])
	assert_false(archive.knows_xinfa("龟息功"), "初始清单外的心法")
	var result: Dictionary = archive.study_manual("guixigupian")
	assert_true(bool(result.get("ok", false)))
	assert_eq(str(result.get("kind", "")), "xinfa")
	assert_true(archive.knows_xinfa("龟息功"))
	assert_eq(int(archive.warehouse[0]["qty"]), 1, "研读销毁一本（qty 2→1）")

func test_study_manual_white_scroll_rejected() -> void:
	var archive := _archive()
	archive.learned_xinfa.erase("调息诀")
	archive.store_items([{"id": "diaoxiyaoshu", "name": "调息要术", "qty": 2, "value": 20, "rarity": "common"}])
	assert_true(bool(archive.study_manual("diaoxiyaoshu").get("ok", false)))
	var again: Dictionary = archive.study_manual("diaoxiyaoshu")
	assert_false(bool(again.get("ok", false)), "已参悟过的再读是白卷")
	assert_string_contains(str(again.get("reason", "")), "白卷")
	assert_eq(int(archive.warehouse[0]["qty"]), 1, "白卷不销毁")

func test_study_technique_manual() -> void:
	var archive := _archive()
	archive.store_items([{"id": "jianpu", "name": "残破剑谱", "qty": 1, "value": 60, "rarity": "rare"}])
	var result: Dictionary = archive.study_manual("jianpu")
	assert_true(bool(result.get("ok", false)))
	assert_eq(str(result.get("kind", "")), "technique")
	assert_true(archive.knows_technique("一气·引"), "残破剑谱传授一气·引")
	assert_true(archive.warehouse.is_empty(), "最后一本研读后清出仓库")

func test_study_manual_unknown_item() -> void:
	var archive := _archive()
	var result: Dictionary = archive.study_manual("buchunzai")
	assert_false(bool(result.get("ok", false)))

# ---------- 存档往返与旧档迁移 ----------

func test_v5_round_trip() -> void:
	var archive := _archive()
	archive.learn_xinfa("龟息功")
	archive.set_loadout("xinfa", ["调息诀", "先纳功", "养木功", "龟息功"])
	archive.save_meta()
	var revived := _archive()
	assert_true(revived.knows_xinfa("龟息功"))
	assert_eq(revived.loadout["xinfa"].size(), 4, "构筑配置跨档往返")
	assert_eq(str(revived.loadout["xinfa"][3]), "龟息功")

# ---------- 账面资产（v6，D-062） ----------

func test_experience_accrues_from_win_extract_and_study() -> void:
	var archive := _archive()
	assert_eq(archive.experience, 0, "新档历练从 0 起")
	# 胜仗（ExpeditionSession.report_battle_result → gain EXP_PER_BATTLE_WIN）
	var session: Node = preload("res://core/expedition/expedition_session.gd").new()
	session.archive = archive
	add_child_autofree(session)
	session.report_battle_result("win", 20)
	assert_eq(archive.experience, archive.EXP_PER_BATTLE_WIN, "胜仗入账历练")
	var before: int = archive.experience
	session.report_battle_result("lose", 0)
	assert_eq(archive.experience, before, "败北不计历练")
	# 研读 +1
	archive.store_items([{"id": "guixigupian", "name": "龟息古篇", "qty": 1, "value": 45, "rarity": "fine"}])
	archive.study_manual("guixigupian")
	assert_eq(archive.experience, before + archive.EXP_PER_STUDY, "研读入账历练")

func test_experience_accrues_on_extraction_not_death() -> void:
	var archive := _archive()
	var session: Node = preload("res://core/expedition/expedition_session.gd").new()
	session.archive = archive
	add_child_autofree(session)
	var board := BoardState.new()
	board.outcome = "extracted"
	session.board_state = board
	session.settle_and_end_run()
	assert_eq(archive.experience, archive.EXP_PER_EXTRACTION, "撤离成功入账历练")

func test_silver_and_experience_round_trip_and_old_save() -> void:
	var archive := _archive()
	archive.gain_silver(120)
	archive.gain_experience(7)
	archive.save_meta()
	var revived := _archive()
	assert_eq(revived.silver, 120, "银两跨档往返")
	assert_eq(revived.experience, 7, "历练跨档往返")
	# 旧 v5 档免迁移：资产从 0 起
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 5, "warehouse": []}))
	file.close()
	var old_reader := _archive()
	assert_eq(old_reader.silver, 0)
	assert_eq(old_reader.experience, 0, "旧 v5 档历练从 0 起")

func test_v4_old_save_falls_back_to_defaults() -> void:
	var file := FileAccess.open(TEST_META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 4, "warehouse": [], "pouch_slots": 1, "uid_next": 1}))
	file.close()
	var archive := _archive()
	assert_eq(archive.learned_xinfa.size(), 3, "旧 v4 档免迁移，默认取 player.json 初始心法")
	assert_eq(archive.learned_techniques.size(), 6)
	assert_eq(int(JSON.parse_string(FileAccess.get_file_as_string(TEST_META_PATH))["version"]), 4,
		"读旧档不写回（版本升级发生在下一次显式 save_meta）")
