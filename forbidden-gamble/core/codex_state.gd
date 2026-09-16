class_name CodexState
extends RefCounted

# 图鉴·发现制收藏（组挑战·代码设计 v1.4 §4.9，参考我地麻 Illustration）：
# 账号级收藏档 user://mj_meta.json（与 run 档分离——跨局存活，对应其 HadXiaoChouList 位）。
# 发现触发：获得武学/牌灵、与对手交战（场景各一行调用）；未发现条目图鉴显示剪影。
# 真气牌面 27 种全量展示不参与发现。修为解锁/成就解锁/搜索/稀有度分组＝后置。
# 写穿＋坏档改名 .bad（同 RunSaver 规）。


const META_VERSION := 1
const DEFAULT_PATH := "user://mj_meta.json"

static var meta_path := DEFAULT_PATH
static var _discovered: Array[String] = []
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_discovered = []
	if not FileAccess.file_exists(meta_path):
		return
	var parser := JSON.new()
	var ok := parser.parse(FileAccess.open(meta_path, FileAccess.READ).get_as_text()) == OK
	var parsed: Variant = parser.data
	if ok and parsed is Dictionary and int((parsed as Dictionary).get("version", -1)) == META_VERSION:
		for id_str in (parsed as Dictionary).get("discovered", []):
			_discovered.append(str(id_str))
	else:
		_rename_bad()


static func _save() -> void:
	var file := FileAccess.open(meta_path, FileAccess.WRITE)
	if file == null:
		push_error("[CodexState] 无法写收藏档: " + meta_path)
		return
	file.store_string(JSON.stringify({"version": META_VERSION, "discovered": _discovered}, "\t"))


static func _rename_bad() -> void:
	var dir := DirAccess.open(meta_path.get_base_dir())
	if dir != null and dir.rename(meta_path.get_file(), meta_path.get_file().replace(".json", ".bad.json")) != OK:
		push_warning("[CodexState] 坏档改名失败: " + meta_path)


# 发现（幂等）：新发现返回 true 并写穿。
static func discover(id_str: String) -> bool:
	_ensure_loaded()
	if _discovered.has(id_str):
		return false
	_discovered.append(id_str)
	_save()
	return true


static func is_discovered(id_str: String) -> bool:
	_ensure_loaded()
	return _discovered.has(id_str)


static func discovered_count() -> int:
	_ensure_loaded()
	return _discovered.size()


# 内容全集（武学〔库＋货架池〕＋牌灵＋对手）：图鉴完成度与测试共用。
static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_str in MJTechniqueLibrary.attack_roster():
		ids.append(id_str)
	for id_str in MJTechniqueLibrary.defense_roster():
		ids.append(id_str)
	for id_str in MJTechniqueLibrary.xinfa_roster():
		ids.append(id_str)
	var shop: Dictionary = DataRepo.mj_shop()
	for entry in shop.get("wuxue_pool", []):
		var id_str := str((entry as Dictionary).get("id", ""))
		if not id_str.is_empty() and not ids.has(id_str):
			ids.append(id_str)
	for entry in shop.get("pailing_pool", []):
		ids.append(str((entry as Dictionary).get("id", "")))
	for id_str in DataRepo.mj_opponents().keys():
		ids.append(str(id_str))
	return ids


static func discovered_ratio() -> float:
	_ensure_loaded()
	var total := all_ids().size()
	if total == 0:
		return 0.0
	return float(discovered_count()) / float(total)


# 测试隔离：换路径＋清内存态。
static func reset_for_tests(path := "user://test_mj_meta.json") -> void:
	meta_path = path
	_discovered = []
	_loaded = false
