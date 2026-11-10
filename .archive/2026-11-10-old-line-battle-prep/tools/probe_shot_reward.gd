## 奖励弹窗截图件：Boss 胜局 → 奖励弹窗（三选项位＋刷新）亮起时截图退出。
extends SceneTree

const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var screen: Control = SCREEN.instantiate()
	screen.run_data = {"copper": 100,
		"team": [{"id": "youming", "equips": ["", "", ""], "pdir": 0},
			{"id": "tiansi", "equips": ["", "", ""], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 1, "seed": 20261026}
	screen.run_data["deck"] = QI_DATA.build_deck(screen.run_data["team"])
	root.add_child(screen)
	for i in 20:
		await process_frame
	var b: RefCounted = screen.battle
	b.allies[0]["acts"] = 99
	for e in b.enemies:
		if e["alive"]:
			e["hp"] = 1
			b.normal_attack(b.allies[0], e)
	for i in 240:
		await process_frame
		if screen.find_child("QiDialog", true, false):
			break
	var dlg = screen.find_child("QiDialog", true, false)
	if dlg:
		dlg.get_ok_button().pressed.emit()
	for i in 240:
		await process_frame
		if screen.find_child("QiDialog", true, false) and screen.find_child("QiDialog", true, false).visible:
			break
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_reward_preview.png")
	quit()
