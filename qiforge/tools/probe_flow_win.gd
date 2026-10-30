## 全环探针（2026-10-29 新战间制）：每场胜→回备战舱（不再组内连场），点出战进下一场；
## 组末＝整队回血 50%＋阵亡复活（group_heal）＋组间推进。跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const ROOT := preload("res://qiforge/QiRoot.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

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

	# —— 第 1 场速胜 → 回备战（2026-10-29 裁定：一场打完一律回备战，不再连场）——
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
	if root_ctl.find_child("QiPrepBay", false, false) == null:
		fails.append("第 1 场胜后应回备战舱（新战间制）")
	if root_ctl.find_child("QiBattleScreen", false, false) != null:
		fails.append("胜后战斗屏应移除（新战间制）")

	# —— 备战点出战 → 第 2 场 → 胜回备战 ——
	go = root_ctl.find_child("GoButton", true, false)
	if go == null:
		fails.append("备战舱出战钮缺失（第 2 场前）")
		_finish()
		return
	go.pressed.emit()
	for i in 15:
		await process_frame
	screen = root_ctl.find_child("QiBattleScreen", false, false)
	if screen == null:
		fails.append("第 2 场战斗屏未出现")
		_finish()
		return
	_eq("第 2 场敌数=4（战×2＋射＋辅）", 4, screen.battle.enemies.size())
	_win_battle(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	for i in 30:
		await process_frame
	_eq("两场铜钱累计 +80", copper0 + 80, int(root_ctl.run()["copper"]))
	_eq("场序推进=2", 2, int(root_ctl.run()["fight"]))

	# —— 第 3 场（组末 Boss 保证位场）：带伤＋阵亡打完 → 组末整队回血＋复活＋组间推进 ——
	go = root_ctl.find_child("GoButton", true, false)
	if go == null:
		fails.append("备战舱出战钮缺失（第 3 场前）")
		_finish()
		return
	go.pressed.emit()
	for i in 15:
		await process_frame
	screen = root_ctl.find_child("QiBattleScreen", false, false)
	if screen == null:
		fails.append("第 3 场战斗屏未出现")
		_finish()
		return
	_eq("第 3 场敌数=3（剑主＋力士＋巫祝）", 3, screen.battle.enemies.size())
	screen.battle.allies[0]["hp"] = 5      # 带伤（幽冥 5/34）
	screen.battle.allies[1]["hp"] = 0      # 阵亡（天丝 0/48——胜后自动入未上场池）
	_win_battle(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	await _confirm_dialog(screen)
	for i in 30:
		await process_frame
	_eq("组毕铜钱累计 +145", copper0 + 145, int(root_ctl.run()["copper"]))
	_eq("组毕组序推进=1", 1, int(root_ctl.run()["group"]))
	_eq("组毕场序归零", 0, int(root_ctl.run()["fight"]))
	var run_d: Dictionary = root_ctl.run()
	var ym: Dictionary = QI_DATA.find_member(run_d, "youming")
	var ts: Dictionary = QI_DATA.find_member(run_d, "tiansi")
	_eq("组末回血：幽冥 5+17=22", 22, int(ym.get("hp", -1)))
	if String(ts.get("id", "")) != "tiansi":
		fails.append("天丝胜后应自动入未上场池")
	else:
		_eq("组末复活回血：天丝 0→(tick+12)+(组末+24)=36", 36, int(ts["hp"]))
	var prep := root_ctl.find_child("QiPrepBay", false, false)
	if prep == null:
		fails.append("组毕应回备战舱")
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
