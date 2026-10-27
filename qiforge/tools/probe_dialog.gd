## 无头功能探针：QiDialog v2（STS2 制 QiDialogBox：双键/警告件/确认流）。dev 件，验证后可删。
## 2026-10-27 弹窗改制后按 Control 盒 API 重写（旧 AcceptDialog 断言全废）。
extends SceneTree

const QIDIALOG := preload("res://qiforge/QiDialog.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)

	# 1) 警告件：创建即弹，双键（取消键存在）
	var confirmed_flag := {"v": false}
	var arr: Array = QIDIALOG.warning(holder, "测试警告", "确认删除该词条？此操作不可撤销。", func() -> void: confirmed_flag["v"] = true)
	var dialog: Control = arr[1]
	for i in 10:
		await process_frame
	if dialog == null or not dialog.visible:
		fails.append("警告件应已弹出")
	elif dialog.get_cancel_button() == null:
		fails.append("双键模式：取消键应存在")

	# 2) 确认流：confirmed → 回调 + 自动关释放
	dialog.confirmed.emit()
	for i in 5:
		await process_frame
	if not confirmed_flag["v"]:
		fails.append("confirmed 回调未触发")
	if is_instance_valid(dialog) and dialog.visible:
		fails.append("确认后应关闭释放")

	# 3) 常规 create：旧四参调用兼容（无取消键）
	var arr2: Array = QIDIALOG.create(holder, "旧式调用", Vector2(400, 300), "确定")
	var d2: Control = arr2[1]
	if d2 == null:
		fails.append("常规 create 被互斥拒绝（应已释放）")
	elif d2.get_cancel_button() != null:
		fails.append("默认无取消键（旧调用兼容）")
	if d2 != null:
		d2.queue_free()

	print("DIALOG_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DIALOG_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
