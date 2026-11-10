## 战斗屏拖源门＋追击画面回归探针（2026-10-28）。跑法＝非无头：
## godot --path . --script res://qiforge/tools/probe_battle_gate.gd
## §1 零攻次（天丝 acts=0）不可拖＝「拖不动」反馈；§2 可普攻者（幽冥剑）拖敌卡＝普攻；
## §3 追击画面：pursuit_fired 信号＋追击者突进位移＋「追击」飘字＋回位＋总伤 20（18＋2）。
## 注意：合成 motion 必须带 relative（引擎按 relative 累积过阈值才启动拖拽）。
extends SceneTree

const SCR := preload("res://qiforge/QiBattleScreen.tscn")
const QICARD := preload("res://qiforge/QiCardStyle.gd")

var fails: Array = []
var pursuit_hits := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var screen: Control = SCR.instantiate()
	root.add_child(screen)
	for i in 30:
		await process_frame
	var battle = screen.get("battle")
	battle.pursuit_fired.connect(func(_a, _t, _d): pursuit_hits += 1)
	var slots: Array = screen.get("_ally_slots")
	var a0: Dictionary = slots[0]["unit"]
	var a1: Dictionary = slots[1]["unit"]
	var w0: Control = slots[0]["wrap"]
	var w1: Control = slots[1]["wrap"]
	var erec: Dictionary = (screen.get("_enemy_slots") as Array)[0]
	var ew: Control = erec["wrap"]
	var e0: Dictionary = erec["enemy"]
	var hp0 := int(e0["hp"])
	print("TEAM ", a0["name"], " acts=", a0["acts"], " / ", a1["name"], " acts=", a1["acts"])

	## —— §1 零攻者拖不动 ——
	if not (w1.get("card_data") as Dictionary).is_empty():
		fails.append("§1 零攻者拖源应收空（card_data 仍非空）")
	var c1 := w1.global_position + w1.size * 0.5
	_press(c1)
	await process_frame
	await process_frame
	for i in 6:
		_move(c1 + Vector2(22.0 * float(i + 1), 8.0))
		await process_frame
	if root.gui_is_dragging():
		fails.append("§1 零攻者竟然起了拖拽（应拖不动）")
	_release(c1 + Vector2(140.0, 48.0))
	for i in 3:
		await process_frame

	## —— §2+§3 幽冥剑拖敌0＝普攻＋追击 ——
	if not (w0.get("card_data") as Dictionary).has("atk_uid"):
		fails.append("§2 可攻者拖源应有 atk_uid")
	var c0 := w0.global_position + w0.size * 0.5
	var ec := ew.global_position + ew.size * 0.5
	_press(c0)
	await process_frame
	await process_frame
	var dragged := false
	var line_pts_max := 0
	var prev := c0
	for i in 16:
		var t := float(i + 1) / 16.0
		var p := c0.lerp(ec, t)
		_move(p)
		await process_frame
		if root.gui_is_dragging():
			dragged = true
		var ln: Line2D = screen.get("_line")
		if ln != null and ln.visible:
			line_pts_max = maxi(line_pts_max, ln.points.size())
	if not dragged:
		fails.append("§2 可攻者未起拖")
	if line_pts_max < 10:
		fails.append("§2 拖攻连线非贝塞尔（点数 %d < 10）" % line_pts_max)
	var pos_before := w1.position
	_release(ec)
	# 追击表现＝1s 时间窗轮询（帧率无关）：位移取峰值、飘字窗口内出现即计
	var moved := 0.0
	var cap := false
	for i in 40:
		await create_timer(0.025).timeout
		moved = maxf(moved, w1.position.distance_to(pos_before))
		if not cap:
			for c in screen.get_children():
				if c is Label and String(c.text) == "追击":
					cap = true
		if i == 16:
			root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_pursuit.png")
	if moved <= 30.0:
		fails.append("§3 追击者无突进位移（峰值 %.1f）" % moved)
	if not cap:
		fails.append("§3 未见「追击」飘字")
	await create_timer(0.8).timeout
	if w1.position.distance_to(pos_before) >= 4.0:
		fails.append("§3 追击者未回位")
	if pursuit_hits < 1:
		fails.append("§3 pursuit_fired 未触发")
	var dmg := hp0 - int(e0["hp"])
	if dmg != 20:
		fails.append("§3 总伤应 20（18 普攻＋2 追击），实测 %d" % dmg)
	if not (w1.get("card_data") as Dictionary).is_empty():
		fails.append("§3 追击后零攻者拖源仍应收空")

	## —— §4 阵亡收拢＋居中（2026-10-28 裁定：战斗无空槽件/居中/死后整槽收拢）——
	var slots_arr: Array = screen.get("_ally_slots")
	var arow: Control = screen.get_node("AllyRow")
	var vis_n := 0
	for c in arow.get_children():
		if c.visible:
			vis_n += 1
	_eq(vis_n, battle.allies.size(), "§4 初始行内槽数＝器灵数（无空槽件）")
	var s0: Control = slots_arr[0]["slot"]
	var s1: Control = slots_arr[1]["slot"]
	_near((s0.global_position.x + s0.size.x * 0.5 + s1.global_position.x + s1.size.x * 0.5) * 0.5,
		960.0, 4.0, "§4 双卡中点＝屏心（偶数）")
	a1["alive"] = false
	a1["hp"] = 0
	battle.changed.emit()
	for i in 5:
		await process_frame
	if s1.visible:
		fails.append("§4 死者槽未隐")
	_near(s0.global_position.x + s0.size.x * 0.5, 960.0, 4.0, "§4 单卡居中（奇数）")
	var erecs: Array = screen.get("_enemy_slots")
	if erecs.size() >= 2:
		(erecs[0]["enemy"] as Dictionary)["alive"] = false
		battle.changed.emit()
		for i in 5:
			await process_frame
		if (erecs[0]["slot"] as Control).visible:
			fails.append("§4 死敌槽未隐")
		var es1: Control = erecs[1]["slot"]
		_near(es1.global_position.x + es1.size.x * 0.5, 960.0, 4.0, "§4 余敌居中")
	root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_closeup.png")

	## —— §5 STS2 制敌方血条（卡外下方/宽+24/居中/盾徽/中毒段/三态色）——
	var CW := QICARD.size_of("field").x
	var arec: Dictionary = erecs[1]
	var aew: Control = arec["wrap"]
	var box5: Control = arec["hpbox"]
	_expect(box5.global_position.y >= aew.global_position.y + aew.size.y - 1.0, true, "§5 血条在卡外下方")
	_near(box5.size.x, CW + 24.0, 3.0, "§5 条宽＝卡宽+24")
	_near((box5.global_position.x + box5.size.x * 0.5) - (aew.global_position.x + aew.size.x * 0.5), 0.0, 3.0, "§5 条与卡中心对齐")
	var ae: Dictionary = arec["enemy"]
	var inner_w := CW + 24.0 - 10.0
	_near((arec["hpfill"] as Control).size.x, float(int(ae["hp"])) / float(int(ae["mhp"])) * inner_w, 2.0, "§5 红段宽＝hp/mhp")
	battle.apply_status(ae, "hudun", 1, 10)
	battle.apply_status(ae, "zhongdu", 5, 0, -1, true, {})
	battle.changed.emit()
	for i in 3:
		await process_frame
	_expect((arec["hpblk"] as Control).visible, true, "§5 盾徽可见")
	_expect(String((arec["hpblkl"] as Label).text) == "10", true, "§5 盾值 10")
	_expect((arec["hppois"] as Control).visible, true, "§5 中毒段可见")
	_expect(((arec["hpfill"] as Panel).get_theme_stylebox("panel") as StyleBoxFlat).bg_color.is_equal_approx(Color("3B6FA3")), true, "§5 有盾填充变蓝")
	print("BAR_RECT ", Rect2(box5.global_position, box5.size))
	## —— §5b 图标制（2026-10-28 game-icons.net）：盾徽真盾线稿＋状态列贴图化 ——
	var blk_tex := false
	for c in (arec["hpblk"] as Control).get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			blk_tex = true
	_expect(blk_tex, true, "§5b 盾徽缺盾形线稿贴图")
	var stat_tex := 0
	var st_stack: Array = [arec["statcol"]]
	while not st_stack.is_empty():
		var sn: Node = st_stack.pop_back()
		if sn is TextureRect and (sn as TextureRect).texture != null:
			stat_tex += 1
		for k in sn.get_children():
			st_stack.push_back(k)
	_expect(stat_tex > 0, true, "§5b 状态列无贴图图标")
	root.get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/.qi_sts2bar.png")

	## —— §6 STS2 制：能量宝珠＋攻次宝珠＋手牌可打性 ——
	var eorb: Control = null
	for i in 10:
		eorb = screen.find_child("EnergyOrb", true, false)
		if eorb != null:
			break
		await create_timer(0.05).timeout
	if eorb == null:
		fails.append("§6 未找到能量宝珠")
	else:
		var enum_: Label = eorb.get_meta("num")
		if String(enum_.text) != str(int(battle.energy)):
			fails.append("§6 能量珠数字错（%s ≠ %d）" % [String(enum_.text), int(battle.energy)])
	for pr_i in [0, 1]:
		var arec2: Dictionary = (slots_arr as Array)[pr_i]
		var aorb: Control = arec2.get("actsorb")
		if aorb == null or not is_instance_valid(aorb):
			fails.append("§6 器灵%d 无攻次珠" % pr_i)
		elif String((aorb.get_meta("num") as Label).text) != str(int(arec2["unit"]["acts"])):
			fails.append("§6 器灵%d 攻次珠数字错（%s ≠ %d）" % [pr_i,
				String((aorb.get_meta("num") as Label).text), int(arec2["unit"]["acts"])])
	# 可打性：能量清零 → 手牌压灰＋费用徽红；恢复 → 回亮
	var e_backup: int = battle.energy
	battle.energy = 0
	battle.changed.emit()
	for i in 5:
		await process_frame
	var gray_n := 0
	var red_n := 0
	for w in (screen.get("_hand_wraps") as Array):
		if w.get_child_count() == 0:
			continue
		var vis: Control = w.get_child(0)
		if absf(vis.modulate.r - 0.52) < 0.05:
			gray_n += 1
		var pip := vis.find_child("CostPip", false, false)
		if pip is Panel and ((pip as Panel).get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(Color("e05545")):
			red_n += 1
	if gray_n == 0:
		fails.append("§6 能量清零后手牌未压灰")
	if red_n == 0:
		fails.append("§6 能量清零后费用徽未变红")
	battle.energy = e_backup
	battle.changed.emit()
	for i in 5:
		await process_frame
	var back_white := 0
	for w in (screen.get("_hand_wraps") as Array):
		if w.get_child_count() > 0 and (w.get_child(0) as Control).modulate.r > 0.95:
			back_white += 1
	if back_white == 0:
		fails.append("§6 能量恢复后手牌未回亮")

	print("BATTLE_GATE_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("BATTLE_GATE_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

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
	ev.relative = Vector2(20.0, 6.0)
	Input.parse_input_event(ev)

func _release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	Input.parse_input_event(ev)

func _eq(got, want, tag: String) -> void:
	if got != want:
		fails.append("%s：期望 %s，实测 %s" % [tag, str(want), str(got)])

func _near(got: float, want: float, tol: float, tag: String) -> void:
	if abs(got - want) > tol:
		fails.append("%s：期望 %.1f±%.1f，实测 %.1f" % [tag, want, tol, got])

func _expect(got: bool, want: bool, tag: String) -> void:
	if got != want:
		fails.append("%s：期望%s，实测%s" % [tag, "是" if want else "否", "是" if got else "否"])
