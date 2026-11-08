## VC 制局外档（2026-11-07 属性轮）：跨 run 持久——局外金币＋属性养成。
## 对应原版 MetaProgression/ProgressionData（花金币永久升级，GetStartingX 的 progression 层）。
## 存储＝user://qi_vc_meta.json（JSON 持久；探针/调试可用 meta_path 覆写路径隔离）。
extends RefCounted

const DATA := preload("res://qiforge/QiVcData.gd")

var data := {"gold": 0, "upgrades": {}}   # upgrades: {axis: level}
var _path := "user://qi_vc_meta.json"

func setup(path: String = "") -> void:
	if path != "":
		_path = path
	_load()

func _load() -> void:
	var f := FileAccess.open(_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		data["gold"] = int(parsed.get("gold", 0))
		var ups: Dictionary = {}
		for k in (parsed.get("upgrades", {}) as Dictionary):
			ups[String(k)] = int(parsed["upgrades"][k])
		data["upgrades"] = ups

func save() -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_error("局外档写失败：" + _path)
		return
	f.store_string(JSON.stringify(data))
	f.close()

## 快照（注入 run._meta → QiVcBattle.setup 三层合成的 progression 层）
func meta_snapshot() -> Dictionary:
	return {"gold": int(data["gold"]),
		"upgrades": (data["upgrades"] as Dictionary).duplicate()}

func add_gold(amount: int) -> void:
	data["gold"] = maxi(0, int(data["gold"]) + amount)
	save()

func upgrade_level(axis: String) -> int:
	return int((data["upgrades"] as Dictionary).get(axis, 0))

func upgrade_cost(axis: String) -> int:
	return DATA.upgrade_cost(axis, upgrade_level(axis))

func max_level(axis: String) -> int:
	return int(DATA.PROGRESSION_TABLE.get(axis, {}).get("max_lv", 5))

## 升一级（扣金币写档）；成功返回 true
func try_upgrade(axis: String) -> bool:
	if upgrade_level(axis) >= max_level(axis):
		return false
	var cost := upgrade_cost(axis)
	if int(data["gold"]) < cost:
		return false
	data["gold"] = int(data["gold"]) - cost
	(data["upgrades"] as Dictionary)[axis] = upgrade_level(axis) + 1
	save()
	return true
