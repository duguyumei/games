## 存档系统探针（2026-10-27 接入轮·v2 主菜单制）：QiSave 读写/int 还原/坏档回退备档；
## QiRoot 主菜单（无档＝只有新的开局／有档＝继续游戏＋弃档重开）、战前快照、重战恢复。
## 跑法＝无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const QISAVE := preload("res://qiforge/QiSave.gd")
const QIROOT := preload("res://qiforge/QiRoot.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	# —— 1) 读写往返＋int 还原 ——
	QISAVE.clear()
	var run := {"copper": 130, "sys_lv": 2, "group": 0, "fight": 1, "seed": 20261026,
		"team": [{"id": "youming", "equips": ["p6", "", ""], "pdir": 1}],
		"deck": [{"wid": "youming", "sid": "miehun", "dir": 2}]}
	QISAVE.write(run, {"copper": 99})
	var data: Dictionary = QISAVE.read()
	_eq("读档非空", false, data.is_empty())
	if not data.is_empty():
		_eq("run.copper=130", 130, int(data["run"].get("copper", 0)))
		_eq("copper 还原为 int", TYPE_INT, typeof(data["run"].get("copper", 0.0)))
		_eq("team.pdir 还原为 int", TYPE_INT, typeof(data["run"]["team"][0].get("pdir", 0.0)))
		_eq("deck.dir=2", 2, int(data["run"]["deck"][0].get("dir", 0)))
		_eq("snap.copper=99", 99, int(data["snap"].get("copper", 0)))

	# —— 2) 坏主档回退 .backup（先写第二版让备档存在）——
	run["copper"] = 131
	QISAVE.write(run, {"copper": 99})
	var f := FileAccess.open("user://qi_run.save", FileAccess.WRITE)
	if f != null:
		f.store_string("{corrupted!!")
		f.close()
	var data2: Dictionary = QISAVE.read()
	_eq("坏主档回退备档（copper=130）", 130, int(data2.get("run", {}).get("copper", -1)) if not data2.is_empty() else -1)

	# —— 3) 无档主菜单→新的开局→战前快照→重战 ——
	QISAVE.clear()
	var root1: Control = QIROOT.instantiate()
	root.add_child(root1)
	for i in 15:
		await process_frame
	_eq("无档显示主菜单", true, root1.find_child("QiMenu", false, false) != null)
	_eq("无档无「继续游戏」", false, _btn_with_text(root1, "继续游戏") != null)
	var newb: Button = _btn_with_text(root1, "新的开局")
	_eq("无档有「新的开局」", true, newb != null)
	if newb != null:
		newb.pressed.emit()
		for i in 10:
			await process_frame
	_eq("新开后进备战舱", true, root1.find_child("QiPrepBay", false, false) != null)
	root1._run["copper"] = 77
	root1.spawn_battle()
	for i in 10:
		await process_frame
	_eq("战前快照 copper=77", 77, int(root1._snap.get("copper", -1)))
	_eq("战斗屏在场", true, root1.find_child("QiBattleScreen", false, false) != null)
	var data3: Dictionary = QISAVE.read()
	_eq("档内 run.copper=77", 77, int(data3.get("run", {}).get("copper", -1)))
	_eq("档内 snap.copper=77", 77, int(data3.get("snap", {}).get("copper", -1)))
	root1._run["copper"] = 120   # 模拟战果偏移
	root1._rewind_battle()
	for i in 12:
		await process_frame
	_eq("重战后 run.copper 回 77", 77, int(root1._run.get("copper", -1)))
	_eq("重战重开战斗屏", true, root1.find_child("QiBattleScreen", false, false) != null)
	root1.queue_free()
	await process_frame

	# —— 4) 有档主菜单：「继续游戏」接管；「弃档重开」另验 ——
	QISAVE.write({"copper": 55, "sys_lv": 3, "group": 1, "fight": 0, "seed": 7,
		"team": [], "deck": []}, {})
	var root2: Control = QIROOT.instantiate()
	root.add_child(root2)
	for i in 30:
		await process_frame
	_eq("有档显示主菜单", true, root2.find_child("QiMenu", false, false) != null)
	var cont2: Button = _btn_with_text(root2, "继续游戏")
	if cont2 == null:
		fails.append("有档应显示「继续游戏」")
	else:
		cont2.pressed.emit()
		for i in 15:
			await process_frame
		_eq("接管后 copper=55", 55, int(root2._run.get("copper", -1)))
		_eq("接管后 sys_lv 还原为 int", TYPE_INT, typeof(root2._run.get("sys_lv", 0.0)))
		_eq("继续后进备战舱", true, root2.find_child("QiPrepBay", false, false) != null)
		_eq("菜单已收起", false, root2.find_child("QiMenu", false, false) != null)
		# 备战舱「退出」＝存档回主菜单（直接调宿主法）
		root2._exit_to_menu()
		for i in 10:
			await process_frame
		_eq("退出回主菜单", true, root2.find_child("QiMenu", false, false) != null)
		# 弃档重开
		var ff: Button = _btn_with_text(root2, "弃档重开")
		_eq("有档显示「弃档重开」", true, ff != null)
		if ff != null:
			ff.pressed.emit()
			for i in 10:
				await process_frame
			_eq("弃档后进备战舱（新局 copper=130）", 130, int(root2._run.get("copper", -1)))
			_eq("弃档后档已清（快照空）", true, root2._snap.is_empty())
	root2.queue_free()
	QISAVE.clear()
	_finish()

func _btn_with_text(node: Node, txt: String) -> Button:
	for c in node.get_children():
		if c is Button and txt in String(c.text):
			return c
		var hit: Button = _btn_with_text(c, txt)
		if hit != null:
			return hit
	return null

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("SAVE_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("SAVE_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
