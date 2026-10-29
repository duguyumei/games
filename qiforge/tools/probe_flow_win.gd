## 全环探针：主菜单→（弃档/新开）备战→出战→（清场速胜）→胜利弹窗→第 2 场自动接续→再胜→回备战＋铜钱入账。
## 跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const ROOT := preload("res://qiforge/QiRoot.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var root_ctl: Control = ROOT.instantiate()
	root.add_child(root_ctl)
	for i in 20:
		await process_frame
	var go: Button = root_ctl.find_child("GoButton", true, false)
	if go == null:
		# 2026-10-27 存档制主菜单：优先「弃档重开」保探针确定性（有档时），无档走「新的开局」
		var menu := root_ctl.find_child("QiMenu", true, false)
		var btns: Array = []
		_collect_buttons(menu, btns)
		for b in btns:
			if String(b.text) == "弃档重开" or String(b.text) == "新的开局":
				(b as Button).pressed.emit()
				break
		for i in 20:
			await process_frame
		go = root_ctl.find_child("GoButton", true, false)
	if go == null:
		fails.append("过主菜单后仍找不到出战钮")
		_finish()
		return
	go.pressed.emit()
	for i in 15:
		await process_frame
	var copper0 := int(root_ctl.run()["copper"])

	# —— 第 1 场速胜 ——
	var screen: Control = root_ctl.find_child("QiBattleScreen", false, false)
	if screen == null:
		fails.append("第 1 场战斗屏未出现")
		_finish()
		return
	_win_battle(screen)
	await _confirm_dialog(screen)   # 胜利结算（铜钱 +30 入账）
	await _confirm_dialog(screen)   # 六类操作池奖励（跳过 → +5 铜）
	await _confirm_dialog(screen)   # 入账收尾弹窗
	for i in 30:
		await process_frame
	_eq("胜 1 场铜钱 +30+5", copper0 + 35, int(root_ctl.run()["copper"]))
	_eq("场序推进=1", 1, int(root_ctl.run()["fight"]))
	screen = root_ctl.find_child("QiBattleScreen", false, false)
	if screen == null:
		fails.append("第 2 场战斗屏应自动接续")
		_finish()
		return
	_eq("第 2 场敌数=4（战×2＋射＋辅）", 4, screen.battle.enemies.size())

	# —— 第 2 场速胜 → 第 3 场（组末 Boss 保证位场）接续 ——
	_win_battle(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	for i in 30:
		await process_frame
	_eq("两场铜钱累计 +80", copper0 + 80, int(root_ctl.run()["copper"]))
	_eq("场序推进=2", 2, int(root_ctl.run()["fight"]))
	screen = root_ctl.find_child("QiBattleScreen", false, false)
	if screen == null:
		fails.append("第 3 场战斗屏应自动接续")
		_finish()
		return
	_eq("第 3 场敌数=3（剑主＋力士＋巫祝）", 3, screen.battle.enemies.size())

	# —— 第 3 场速胜 → 组毕回备战（现仅 G1：无下一组，封已通关）——
	_win_battle(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	for i in 30:
		await process_frame
	_eq("组毕铜钱累计 +145", copper0 + 145, int(root_ctl.run()["copper"]))
	if root_ctl.find_child("QiPrepBay", false, false) == null:
		fails.append("组毕应回备战舱")
	if root_ctl.find_child("QiBattleScreen", false, false) != null:
		fails.append("组毕战斗屏应移除")
	# —— G2-G6 同构暂定（2026-10-28 用户裁定）：组毕自动切下一组第 1 场 ——
	_eq("组毕组序推进=1", 1, int(root_ctl.run()["group"]))
	_eq("组毕场序归零", 0, int(root_ctl.run()["fight"]))
	var prep := root_ctl.find_child("QiPrepBay", false, false)
	var gb := (prep.find_child("GoButton", true, false) as Button) if prep else null
	if gb == null:
		fails.append("备战舱出战钮缺失")
	else:
		_eq("组毕出战钮可再战（非已通关）", false, gb.disabled)
		gb.pressed.emit()
		for i in 15:
			await process_frame
		var sc2 := root_ctl.find_child("QiBattleScreen", false, false)
		if sc2 == null:
			fails.append("组间开战应进 G2F1")
		else:
			_eq("G2F1 敌数=2（同构缩放档）", 2, sc2.battle.enemies.size())
			_eq("G2 刀客血＝黑风×1.25=115", 115, int(sc2.battle.enemies[0]["mhp"]))

	# —— §4 终局守卫：末组组毕越界不得开战、恢复备战不叠加 ——
	root_ctl.run()["group"] = 5
	root_ctl.run()["fight"] = 99
	var preps0 := root_ctl.find_children("QiPrepBay", "", false, false).size()
	root_ctl.spawn_battle()
	for i in 15:
		await process_frame
	_eq("越界不得再开战（仍 1 个战斗屏）", 1,
		root_ctl.find_children("QiBattleScreen", "", false, false).size())
	_eq("越界守卫恢复备战舱恰一层（开战时已释放）", 1,
		root_ctl.find_children("QiPrepBay", "", false, false).size())

	_finish()

func _win_battle(screen: Control) -> void:
	# 固定队＝幽冥（攻次1）＋天丝（0攻次）：探针作弊给幽冥足量攻次逐个收割
	var b: RefCounted = screen.battle
	b.allies[0]["acts"] = 99
	for e in b.enemies:
		if e["alive"]:
			e["hp"] = 1
			b.normal_attack(b.allies[0], e)
			if b.result == "win":
				break

func _confirm_dialog(screen: Control) -> void:
	# 胜利弹窗 0.5s 延迟后才弹；等到可见再按确认（QiDialogBox 制，非 AcceptDialog）
	for i in 240:
		await process_frame
		var dlg = screen.find_child("QiDialog", true, false)
		if dlg and dlg.visible:
			dlg.get_ok_button().pressed.emit()
			return

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.push_back(node)
	for c in node.get_children():
		_collect_buttons(c, out)

func _finish() -> void:
	print("WINFLOW_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("WINFLOW_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
