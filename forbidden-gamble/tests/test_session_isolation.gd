extends GutTest

# GUT 测试环境隔离（autoload 会话，17 号测试策略）：
# - 命令行带 GUT 运行器 → autoload 置测试态：存档指向 user://test_expedition_save.json
# - 测试态读档一律扑空：board 场景续不到任何磁盘残留档（上一轮 GUT/试玩留下的局面）
# - save_game 只写测试路径，真档 user://expedition_save.json 内容不被 GUT 改动
# - reset_for_tests：场景类测试用例间复位
# 反向验证：测试自管的裸实例（test_save_load 风格）不受测试态影响，照常读写自设路径。

const REAL_SAVE := "user://expedition_save.json"
const SESSION_SCRIPT := preload("res://core/expedition/expedition_session.gd")

func after_each() -> void:
	ExpeditionSession.reset_for_tests()

func test_gut_mode_redirects_save_path() -> void:
	assert_true(ExpeditionSession._test_mode, "GUT 环境应识别为测试态")
	assert_eq(ExpeditionSession.save_path, "user://test_expedition_save.json",
		"autoload 存档应指向测试路径")
	assert_ne(ExpeditionSession.save_path, REAL_SAVE, "真档路径不得被使用")

func test_resume_never_picks_disk_leftover() -> void:
	# 往测试路径塞一份"可续玩"的伪档——autoload 也不得续到它
	var fake := {"version": 7, "terminal": false, "player_hp": 1, "player_max_hp": 30,
		"board": {"seed": 1, "hero_site": [0, 0], "sites": {}}}
	var file := FileAccess.open(ExpeditionSession.save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(fake))
		file.close()  # 句柄不关，裸实例读回来是空的
	assert_false(ExpeditionSession.has_save(), "测试态读档扑空——磁盘伪档不可见")
	assert_false(ExpeditionSession.resume_from_save(), "board 场景不会续到残留档")

	# 反向验证：裸实例（自设路径、非 autoload）照常能续这份伪档——
	# 隔离收在 autoload 本尊，测试自管的会话不受牵连
	var bare: Node = SESSION_SCRIPT.new()
	add_child_autofree(bare)
	bare.save_path = ExpeditionSession.save_path
	assert_true(bare.resume_from_save(), "裸实例读档不受测试态影响")
	assert_true(bare.is_in_expedition())
	bare.end_run()

func test_save_game_never_touches_real_save() -> void:
	var before := _real_save_bytes()
	ExpeditionSession.start_run(11)
	ExpeditionSession.save_game()
	assert_true(FileAccess.file_exists(ExpeditionSession.save_path), "进度写进测试路径")
	assert_eq(_real_save_bytes(), before, "真档内容不被 GUT 改动")

func test_reset_for_tests_clears_session() -> void:
	ExpeditionSession.start_run(3)
	ExpeditionSession.report_battle_result("win", 5)
	ExpeditionSession.prepare_battle("山匪刀客")
	ExpeditionSession.reset_for_tests()
	assert_false(ExpeditionSession.is_in_expedition(), "会话清空")
	assert_eq(ExpeditionSession.consume_battle_result(), "", "战报一并清空")
	assert_false(FileAccess.file_exists(ExpeditionSession.save_path), "测试档一并清掉")

func _real_save_bytes() -> PackedByteArray:
	if not FileAccess.file_exists(REAL_SAVE):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(REAL_SAVE)
