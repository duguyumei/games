class_name RunSaver
extends RefCounted

# Saver 主档（组挑战·代码设计 v1.4 §4.4）：run 级持久档 user://mj_run_save.json。
# 写穿式——场景在每次状态变更/phase 变更后调 save_state（KB 级同步写）。
# 我地麻三诀：存锚不存局（牌局不落盘，battle 锚重打同墙）；坏档不自动覆盖
# （解析失败/版本不符→改名 .bad 留证、按无档开局）；版本号起步（结构变更从这里长迁移）。
# 测试用 save_path 重定向到临时文件。


const SAVE_VERSION := 1
const DEFAULT_PATH := "user://mj_run_save.json"

static var save_path := DEFAULT_PATH


static func save_state(state: RunState) -> bool:
	var payload := {"version": SAVE_VERSION}
	payload.merge(state.to_dict(), true)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[RunSaver] 无法写档: " + save_path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true


# 无档/坏档/版本不符 → null；坏档改名 mj_run_save.bad.json 留证（绝不静默覆盖）。
static func load_state() -> RunState:
	if not FileAccess.file_exists(save_path):
		return null
	var text := FileAccess.open(save_path, FileAccess.READ).get_as_text()
	var parser := JSON.new()
	var bad := parser.parse(text) != OK
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		bad = true
	else:
		var d := parsed as Dictionary
		if int(d.get("version", -1)) != SAVE_VERSION or str(d.get("phase", "")) == "":
			bad = true
		else:
			var state := RunState.from_dict(d)
			# 终态不入档（victory/over 由调用方在 clear 前就位，防御性再挡一层）
			if state.phase == "victory" or state.phase == "over":
				return null
			return state
	if bad:
		_rename_bad()
	return null


static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


static func has_save() -> bool:
	return load_state() != null


static func _rename_bad() -> void:
	var bad_path := save_path.get_base_dir().path_join(save_path.get_file().replace(".json", ".bad.json"))
	var dir := DirAccess.open(save_path.get_base_dir())
	if dir != null and dir.rename(save_path.get_file(), bad_path.get_file()) != OK:
		push_warning("[RunSaver] 坏档改名失败: " + save_path)
