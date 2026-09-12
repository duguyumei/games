extends GutTest

func test_combat_log_writes_file() -> void:
	var path := "user://test_combat_log.log"
	var log := CombatLog.new(path)
	log.write("测试记录")
	log.close()
	assert_true(FileAccess.file_exists(path), "日志文件应被创建")
	var content := FileAccess.get_file_as_string(path)
	assert_string_contains(content, "测试记录")
	DirAccess.remove_absolute(path)

func test_combat_log_default_path_under_logs_dir() -> void:
	var log := CombatLog.new()
	assert_string_contains(log.file_path, "user://logs/")
	log.close()
	DirAccess.remove_absolute(log.file_path)
