## qi-forge 存档（2026-10-27 接入，STS2 制单槽）：
## user://qi_run.save＋.backup（旧档转备、tmp 原子落盘）；JSON schema_version；
## 内容＝{run: 最新稳定局（上场结算后）, snap: 最近一场的战前快照（重战源）}。
## 读档：主档坏→备档；JSON 数字回读为 float——整数值全量还原 int（组/场/层数索引敏感）。
## qiforge 禁 class_name；纯静态工具。
extends RefCounted

const PATH := "user://qi_run.save"
const PATH_BAK := "user://qi_run.save.backup"
const PATH_TMP := "user://qi_run.save.tmp"
const SCHEMA := 1

static func write(run: Dictionary, snap: Dictionary) -> bool:
	var payload := {"schema_version": SCHEMA, "run": run, "snap": snap}
	var f := FileAccess.open(PATH_TMP, FileAccess.WRITE)
	if f == null:
		push_warning("QiSave：临时档打不开，放弃写档")
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH_BAK))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH_BAK))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH_TMP), ProjectSettings.globalize_path(PATH))
	return true

## 全档不可读/不存在 → 空字典（调用方走新局）
static func read() -> Dictionary:
	for p in [PATH, PATH_BAK]:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Dictionary and int(parsed.get("schema_version", 0)) == SCHEMA:
			var d: Dictionary = parsed
			return {"run": _ints_deep(d.get("run", {})), "snap": _ints_deep(d.get("snap", {}))}
	return {}

static func clear() -> void:
	for p in [PATH, PATH_BAK, PATH_TMP]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## JSON 数字→float 还原：整数值 float 转回 int（递归）
static func _ints_deep(v: Variant) -> Variant:
	match typeof(v):
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _ints_deep(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for e in v:
				arr.push_back(_ints_deep(e))
			return arr
		TYPE_FLOAT:
			if is_equal_approx(float(v), float(int(v))):
				return int(v)
			return v
		_:
			return v
