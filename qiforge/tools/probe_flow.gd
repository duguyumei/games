## 主流程探针（⑤）：QiRoot 演示环——出战切战斗屏→返回键回备战舱；跑法＝非无头。
extends SceneTree

const ROOT := preload("res://qiforge/QiRoot.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var root_ctl: Control = ROOT.instantiate()
	root.add_child(root_ctl)
	for i in 20:
		await process_frame
	if root_ctl.find_child("QiPrepBay", false, false) == null:
		fails.append("启动应进入备战舱")
	var go: Button = root_ctl.find_child("GoButton", true, false)
	if go == null:
		fails.append("出战钮缺失")
		_finish()
		return
	go.pressed.emit()
	for i in 15:
		await process_frame
	if root_ctl.find_child("QiBattleScreen", false, false) == null:
		fails.append("出战后应切入战斗屏")
	if root_ctl.find_child("BackToPrep", false, false) == null:
		fails.append("战斗期应出现返回浮钮")
	else:
		var back: Button = root_ctl.find_child("BackToPrep", false, false)
		back.pressed.emit()
		for i in 15:
			await process_frame
		if root_ctl.find_child("QiPrepBay", false, false) == null:
			fails.append("返回后应回到备战舱")
		if root_ctl.find_child("QiBattleScreen", false, false) != null:
			fails.append("返回后战斗屏应已移除")
	_finish()

func _finish() -> void:
	print("FLOW_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("FLOW_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
