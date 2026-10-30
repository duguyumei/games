## 战斗屏 UI 绑定探针：QiBattleScreen 直跑（默认局）——布局＋实况数据绑定＋一次普攻联动。
## 跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = SCREEN.instantiate()
	root.add_child(screen)
	for i in 20:
		await process_frame

	var enemy_row := screen.find_child("EnemyRow", false, false) as Container
	if enemy_row == null:
		fails.append("敌排缺失")
		_finish()
		return
	_eq("敌数=2（G1 第1场）", 2, enemy_row.get_children().size())
	var ally_row := screen.find_child("AllyRow", false, false) as Container
	_eq("我排槽＝实卡数（演示 2；空位占位已撤 2026-10-28 用户手改）", 2, ally_row.get_children().size())
	_eq("手牌=4（v0.6 出厂抽 4）", 4, screen.battle.hand.size())
	var hand_n := 0
	for c in screen.get_children():
		if String(c.name).begins_with("HandCard"):
			hand_n += 1
	_eq("手牌节点=4", 4, hand_n)

	# —— 跨卡 hover 序回归（2026-10-29 修「换牌不突出」）：引擎跨控件序＝新卡 entered 先行、
	# 旧卡 exited 后发——旧实现 exited 无条件清焦，把新卡刚设的焦点抹掉（首卡突出、第二张永不突出）
	var hws: Array = screen._hand_wraps
	if hws.size() >= 2:
		var w0: Control = hws[0]
		var w1: Control = hws[1]
		w0.emit_signal("mouse_entered")
		for i in 3:
			await process_frame
		_eq("首卡 hover 弹起", "true", str(w0.get_child(0).scale.is_equal_approx(Vector2(1.25, 1.25))))
		w1.emit_signal("mouse_entered")
		w0.emit_signal("mouse_exited")   # 复刻引擎序：exited 后发
		for i in 3:
			await process_frame
		_eq("换卡后焦点=第二张", "true", str(screen._hand_focus == w1))
		_eq("第二卡 hover 弹起", "true", str(w1.get_child(0).scale.is_equal_approx(Vector2(1.25, 1.25))))
		# 焦点卡壳层须回基位（修「选中卡停在让位残留位」：帧 Lerp 制下 wrap 收敛到 tgt_pos）
		var base_x := 1920.0 * 0.5 + (1.0 - 1.5) * 1920.0 * 0.075 - 216.0 * 0.5
		var home := false
		for i in 600:
			if absf(w1.position.x - base_x) < 1.0 and absf(w1.position.y - 1080.0 * 0.752) < 1.0:
				home = true
				break
			await process_frame
		_eq("焦点卡壳层回基位（无让位残留）", "true", str(home))
		var settled := false   # 帧 Lerp 按真实 delta 收敛，无头帧不等价真实钟——轮询至视觉到位
		for i in 600:
			if w0.get_child(0).scale.distance_to(Vector2.ONE) < 0.02:
				settled = true
				break
			await process_frame
		_eq("首卡已回落", "true", str(settled))
		w1.emit_signal("mouse_exited")   # 真离开手牌区：焦点清空
		for i in 3:
			await process_frame
		_eq("离开手牌焦点清空", "true", str(screen._hand_focus == null))
		# —— 2026-10-29 悬停卡死回归（用户报「指过的牌再指没反应/其他牌指不动」）——
		# ①复指循环：A→B→A 再进 A 仍弹起（焦点早退门不吞复指）
		w0.emit_signal("mouse_entered")
		for i in 3:
			await process_frame
		w1.emit_signal("mouse_entered")
		w0.emit_signal("mouse_exited")
		for i in 3:
			await process_frame
		w0.emit_signal("mouse_entered")
		w1.emit_signal("mouse_exited")
		for i in 3:
			await process_frame
		_eq("复指循环后 A 仍弹起（指得动）", "true",
			str(screen._hand_focus == w0 and w0.get_child(0).scale.is_equal_approx(Vector2(1.25, 1.25))))
		# ②收拖恢复不再被早退吞：_spell_drag 空时 _end_card_drag 仍恢复 filter（修「卡永久 IGNORE」）
		w0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w0.z_index = 50
		screen._end_card_drag(w0)
		for i in 2:
			await process_frame
		_eq("收拖无条件恢复 STOP（早退吞恢复已修）", "true",
			str(w0.mouse_filter == Control.MOUSE_FILTER_STOP and w0.z_index == 0))
		# ③busy 门不拦悬停：_busy 真时 hover 照样弹起（busy 只锁打出/施放）
		screen.set("_busy", true)
		w1.emit_signal("mouse_entered")
		w0.emit_signal("mouse_exited")
		for i in 3:
			await process_frame
		_eq("busy 时不拦悬停弹起", "true",
			str(screen._hand_focus == w1 and w1.get_child(0).scale.is_equal_approx(Vector2(1.25, 1.25))))
		screen.set("_busy", false)
		w1.emit_signal("mouse_exited")
		for i in 2:
			await process_frame
	else:
		fails.append("手牌不足 2 张，跨卡 hover 序无法测")
	var energy := screen.find_child("EnergyOrb", false, false)
	var enlbl: Label = (energy.get_meta("num") as Label) if energy else null
	_eq("能量数字=3（出厂上限；STS2 宝珠制）", "3", enlbl.text if enlbl else "<null>")
	if screen.find_child("EndButton", false, false) == null:
		fails.append("结束回合钮缺失")
	# —— 牌堆图案件＋结束钮位（2026-10-29 STS2 combat_piles/end_turn_button 实测制）——
	var eb: Control = screen.find_child("EndButton", false, false)
	if eb != null and not (eb.get_anchor(SIDE_TOP) > 0.77 and eb.get_anchor(SIDE_TOP) < 0.80):
		fails.append("结束钮应对齐 STS2 右下带 anchor_top≈0.783（得 %.3f）" % eb.get_anchor(SIDE_TOP))
	for pk in [["DrawPileBtn", 0.912], ["DiscardPileBtn", 0.912], ["ExhaustPileBtn", 0.741]]:
		var pw: Control = screen.find_child(String(pk[0]), false, false)
		if pw == null:
			fails.append("牌堆件缺失：%s" % String(pk[0]))
			continue
		if absf(pw.get_anchor(SIDE_TOP) - float(pk[1])) > 0.01:
			fails.append("%s 锚位 top 应 %.3f（得 %.3f）" % [String(pk[0]), float(pk[1]), pw.get_anchor(SIDE_TOP)])
		if pw.find_child("Icon", false, false) == null:
			fails.append("%s 缺叠卡图案件" % String(pk[0]))
		var pc: Label = pw.find_child("Count", true, false) as Label
		if pc == null or not String(pc.text).is_valid_int():
			fails.append("%s 计数徽章缺失/非数字（得「%s」）" % [String(pk[0]), pc.text if pc else "<null>"])
	# 消耗堆空则整件隐藏（2026-10-29 用户裁定；默认局无消耗牌）
	var exb: Control = screen.find_child("ExhaustPileBtn", false, false)
	if exb != null and exb.visible:
		fails.append("消耗堆为空应隐藏")
	var dpb: Button = screen.find_child("DrawPileBtn", false, false) as Button
	if dpb != null:
		dpb.pressed.emit()
		for i in 4:
			await process_frame
		if screen.find_child("QiScrim", false, false) == null:
			fails.append("点牌堆图案应弹牌堆视图")
		var qsc: Control = screen.find_child("QiScrim", false, false)
		if qsc != null:
			qsc.queue_free()
	var round_lbl := screen.find_child("RoundLbl", false, false) as Label
	_eq("回合标签", "回合 1", round_lbl.text if round_lbl else "")

	# 意图徽：内容随实况（部件非空）
	var chips := 0
	for rec in screen._enemy_slots:
		var chip := rec["chip"] as PanelContainer
		if chip.get_child_count() > 0:
			chips += 1
	_eq("意图徽已填=2", 2, chips)

	# 普攻联动：幽冥 26−8=18 ＋ 天丝追击 10−8=2 → 打手血条 40；幽冥攻次 1→0；杀意 +1
	bind_attack(screen, 0, 0)
	for i in 5:
		await process_frame
	# 血条引用守卫：屏层事件重绑（_rebind）是异发的，旧 rec 可能整位换新——回读现役槽位
	# （STS2 制血条＝自绘 Control 非 ProgressBar，断言走 rec["hplbl"] 文本）
	var hp_lbl: Label = null
	for i in 30:
		if screen._enemy_slots.size() > 0 and screen._enemy_slots[0].get("hplbl", null) is Label:
			hp_lbl = screen._enemy_slots[0]["hplbl"]
			break
		await process_frame
	if hp_lbl == null:
		fails.append("敌方血条标签取不到（重绑竞态）")
	else:
		_eq("普攻+追击后刀客血条=72/92", "72/92", hp_lbl.text)
	var acts0 := screen._ally_slots[0]["acts"] as Label
	_eq("攻次珠数字=0", "0", acts0.text if acts0 != null else "<null>")
	_eq("杀意获得=1（幽冥造成伤害）", 1, screen.battle.status_total(screen.battle.allies[0], "shayi"))

	# 冲弃联动（v0.6 卡组制）：回合末整手进弃牌堆（手动弃置已退役）
	var flush_n: int = screen.battle.hand.size()
	var disc_n: int = screen.battle.discard_pile.size()
	screen.battle.end_turn()
	for i in 5:
		await process_frame
	_eq("冲弃后手牌=0", 0, screen.battle.hand.size())
	_eq("冲弃后弃牌堆+%d" % flush_n, disc_n + flush_n, screen.battle.discard_pile.size())

	_finish()

func bind_attack(screen: Control, ally_i: int, enemy_i: int) -> void:
	var a: Dictionary = screen.battle.allies[ally_i]
	var e: Dictionary = screen.battle.enemies[enemy_i]
	screen.battle.normal_attack(a, e)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("BUI_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("BATTLE_UI_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
