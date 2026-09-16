extends GutTest

# 组挑战·RunSaver 主档（代码设计 v1.4 §4.4）：写读往返/坏档改名不覆盖/版本不符/
# clear/终态不入档。测试重定向到临时路径。


func before_each() -> void:
	RunSaver.save_path = "user://test_mj_run_save.json"
	RunSaver.clear()


func after_each() -> void:
	RunSaver.clear()
	RunSaver.save_path = RunSaver.DEFAULT_PATH


func _state() -> RunState:
	var state := RunState.new()
	state.start(DataRepo.mj_decks()["basic"], 99)
	state.apply_result("player", 7300, 12)
	state.grant_lianli(DataRepo.mj_shop().get("reward_lianli", []))
	return state


func test_roundtrip() -> void:
	var state := _state()
	state.acquire_pailing("ling_bian", "条2")
	assert_true(RunSaver.save_state(state))
	var loaded := RunSaver.load_state()
	assert_not_null(loaded)
	assert_eq(loaded.phase, "settlement")
	assert_eq(loaded.hp_fp, 7300)
	assert_eq(loaded.lianli, 60)
	assert_eq(loaded.pailing, {"条2": "ling_bian"})
	assert_eq(loaded.battle_seed(), state.battle_seed())


func test_no_save_returns_null() -> void:
	RunSaver.clear()
	assert_null(RunSaver.load_state())
	assert_false(RunSaver.has_save())


func test_corrupt_file_renamed_not_deleted() -> void:
	var file := FileAccess.open(RunSaver.save_path, FileAccess.WRITE)
	file.store_string("{ 这个不是合法 JSON")
	file.close()
	assert_null(RunSaver.load_state())
	var bad_path := "user://mj_run_save.bad.json"
	# 重定向路径的坏档名：test_mj_run_save.bad.json
	var test_bad := "user://test_mj_run_save.bad.json"
	assert_true(FileAccess.file_exists(test_bad), "坏档改名留证")
	assert_false(FileAccess.file_exists(RunSaver.save_path), "原位不再有坏档")


func test_version_mismatch_rejected() -> void:
	var state := _state()
	assert_true(RunSaver.save_state(state))
	var file := FileAccess.open(RunSaver.save_path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var parsed: Dictionary = JSON.parse_string(text)
	parsed["version"] = RunSaver.SAVE_VERSION + 1
	var w := FileAccess.open(RunSaver.save_path, FileAccess.WRITE)
	w.store_string(JSON.stringify(parsed))
	w.close()
	assert_null(RunSaver.load_state(), "版本不符→null（原档改名）")


func test_terminal_phase_never_saved() -> void:
	var state := _state()
	state.apply_result("player", 7000, 9)  # 第二胜
	state.apply_result("player", 1000, 9)  # 第三胜 → victory
	RunSaver.save_state(state)  # 场景在 victory 后应调 clear 而非 save——防御性：load 挡终态
	assert_null(RunSaver.load_state(), "终态不入档")
	var loser := RunState.new()
	loser.start(DataRepo.mj_decks()["basic"], 5)
	loser.apply_result("enemy", 0, 6)
	RunSaver.save_state(loser)
	assert_null(RunSaver.load_state())


func test_clear_removes_file() -> void:
	assert_true(RunSaver.save_state(_state()))
	RunSaver.clear()
	assert_false(FileAccess.file_exists(RunSaver.save_path))
