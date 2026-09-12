class_name CombatLog
extends RefCounted

# 战斗日志：把玩家操作和系统记录写到文件，方便事后查问题。
# 默认写到 user://logs/ 下，每场战斗一个文件。

var file_path := ""
var _file: FileAccess

func _init(custom_path := "") -> void:
	if custom_path.is_empty():
		var dir := "user://logs"
		DirAccess.make_dir_recursive_absolute(dir)
		var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
		file_path = "%s/combat_%s.log" % [dir, stamp]
	else:
		file_path = custom_path
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	if _file == null:
		push_error("无法创建战斗日志: " + file_path)
		return
	write("日志开始")

func write(text: String) -> void:
	if _file == null:
		return
	_file.store_line("[%s] %s" % [Time.get_time_string_from_system(), text])
	_file.flush()

func close() -> void:
	if _file == null:
		return
	write("日志结束")
	_file.close()
	_file = null

func absolute_path() -> String:
	return ProjectSettings.globalize_path(file_path)
