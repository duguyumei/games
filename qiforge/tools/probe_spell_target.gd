## 功法目标校验/照明回归探针（2026-10-28 尸姬 CheckCardUse+MarkTarget 制）。跑法＝非无头：
## godot --path . --script res://qiforge/tools/probe_spell_target.gd
## §A 悬停手牌＝归属器灵亮琥珀环，移开熄灭；§B 拖「引丝诀」到归属者天丝＝放不下（原生取消）：
## 手牌数不变、无「须指定其他器灵」事件、卡回位不卡死；拖中幽冥剑亮玉环（有效）天丝亮琥珀（归属）；
## §C 拖到幽冥剑＝施放成功：手牌 −1、幽冥剑攻次 +1。
extends SceneTree

const SCR := preload("res://qiforge/QiBattleScreen.tscn")
const QIDATA := preload("res://qiforge/QiData.gd")

var fails: Array = []
var evts: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var screen: Control = SCR.instantiate()
	root.add_child(screen)
	for i in 30:
		await process_frame
	var battle = screen.get("battle")
	battle.event.connect(func(t: String) -> void: evts.push_back(t))
	# 注入引丝诀（若无）——确定性
	var has_yinsi := false
	for c in battle.hand:
		if String(c.get("sid", "")) == "yinsi":
			has_yinsi = true
	if not has_yinsi:
		var spell: Dictionary = QIDATA.spell_of("tiansi", "yinsi", 0)
		battle.hand.push_back({"uid": 901, "wid": "tiansi", "sid": "yinsi", "dir": 0,
			"spell": spell, "reuse_left": int(spell.get("reuse", 0)), "retain": false})
		battle.changed.emit()
		for i in 5:
			await process_frame
	var hw: Control = screen.find_child("HandCard901", false, false)
	if hw == null:
		for c in battle.hand:
			if String(c.get("sid", "")) == "yinsi":
				hw = screen.find_child("HandCard%d" % int(c["uid"]), false, false)
				break
	if hw == null:
		print("FAIL: 未找到引丝诀手牌件")
		_finish()
		return
	var slots: Array = screen.get("_ally_slots")
	var w0: Control = slots[0]["wrap"]
	var w1: Control = slots[1]["wrap"]
	var ring0: Panel = slots[0]["mark"]["ring"]
	var ring1: Panel = slots[1]["mark"]["ring"]

	## —— §A 悬停归属 ——
	var hc := hw.global_position + hw.size * 0.5
	_hover(hc)
	for i in 4:
		await process_frame
	if not ring1.visible:
		fails.append("§A 悬停时归属者天丝未亮环")
	elif not (ring1.get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(Color("ffd766")):
		fails.append("§A 归属环应为琥珀色")
	_hover(Vector2(960, 300))
	for i in 4:
		await process_frame
	print("DBG after-exit lights=%d ring1_vis=%s" % [(screen.get("_spell_lights") as Array).size(), ring1.visible])
	if ring1.visible:
		fails.append("§A 移开后归属环未熄")

	## —— §B 拖到归属者＝放不下 ——
	var hand_n: int = battle.hand.size()
	var w1c := w1.global_position + w1.size * 0.5
	var before_pos := hw.position
	await _drag(hc, w1c)
	for i in 8:
		await process_frame
	if battle.hand.size() != hand_n:
		fails.append("§B 无效目标竟被消耗（手牌数 %d→%d）" % [hand_n, battle.hand.size()])
	for t in evts:
		if "须指定其他器灵" in String(t):
			fails.append("§B 走到了结算拒绝（应在落点即被挡）")
	if hw.position.distance_to(before_pos) > 2.0:
		fails.append("§B 手牌未回位（卡死表现，位移 %.1f）" % hw.position.distance_to(before_pos))

	## —— §B2 拖中照明：起拖即亮有效（玉）＋归属（琥珀）——
	# （§B 的拖动已验证过流程；§C 再验照明与成功路径）
	var acts0 := int(slots[0]["unit"]["acts"])
	await _drag_lit(hc, w0.global_position + w0.size * 0.5, ring0, ring1)
	await create_timer(0.8).timeout
	if battle.hand.size() != hand_n - 1:
		fails.append("§C 有效目标未消耗手牌（%d→%d）" % [hand_n, battle.hand.size()])
	if int(slots[0]["unit"]["acts"]) != acts0 + 1:
		fails.append("§C 幽冥剑攻次未 +1（%d→%d）" % [acts0, int(slots[0]["unit"]["acts"])])
	var played := false
	for t in evts:
		if "引丝诀" in String(t) and "施放" in String(t):
			played = true
	if not played:
		fails.append("§C 未见施放事件")
	_finish()

func _drag_lit(from: Vector2, to: Vector2, ring0: Panel, ring1: Panel) -> void:
	_press(from)
	await process_frame
	await process_frame
	var prev := from
	var engaged := false
	for i in 14:
		var t := float(i + 1) / 14.0
		var p := from.lerp(to, t)
		_move(p)
		await process_frame
		if not engaged and root.gui_is_dragging():
			engaged = true
			# 起拖即应亮：幽冥剑（有效·玉绿）＋天丝（归属·琥珀）
			await process_frame
			if not ring0.visible:
				fails.append("§B2 起拖未亮有效目标幽冥剑")
			elif not (ring0.get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(Color("8fd8b0")):
				fails.append("§B2 有效环应为玉绿色")
			if not ring1.visible:
				fails.append("§B2 起拖未亮归属者天丝")
			root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_target_lights.png")
			# 闪灭回归：继续拖 5 步，双环必须仍亮（mouse_exited 在拖拽中不得清灯）
			for h in 5:
				_move(from.lerp(to, 0.6 + 0.06 * float(h)))
				await process_frame
			if not ring0.visible or not ring1.visible:
				fails.append("§B2 继续拖动后高亮熄灭（闪灭 bug 回归）")
	if not engaged:
		fails.append("§B2 未起拖")
	_release(to)
	await process_frame

func _drag(from: Vector2, to: Vector2) -> void:
	_press(from)
	await process_frame
	await process_frame
	var prev := from
	for i in 14:
		var t := float(i + 1) / 14.0
		var p := from.lerp(to, t)
		_move(p)
		await process_frame
	_release(to)
	for i in 3:
		await process_frame

func _hover(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	Input.parse_input_event(m)

func _press(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.relative = Vector2(40.0, 12.0)
	Input.parse_input_event(ev)

func _release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _finish() -> void:
	print("SPELL_TARGET_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("SPELL_TARGET_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
