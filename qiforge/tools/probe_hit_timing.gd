## 动画/扣血时序探针 v2（2026-10-28：模型血量→血条「显示」全链路时序）。
## 跑法＝非无头：godot --path . --script res://qiforge/tools/probe_hit_timing.gd
## §1 玩家普攻：敌模型扣血与敌血条文字都应落命中帧 ≈295ms（动画全长 ≈590ms）；
## §2 敌方回合（结束回合触发）：我方模型扣血→我方血条文字 ≤120ms（修前＝冻到 finish_round 才刷）。
extends SceneTree

const SCR := preload("res://qiforge/QiBattleScreen.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _find_btn(n: Node, txt: String) -> BaseButton:
	var stack: Array = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		if c is BaseButton and String((c as BaseButton).text) == txt:
			return c
		for k in c.get_children():
			stack.push_back(k)
	return null

func _run() -> void:
	var screen: Control = SCR.instantiate()
	root.add_child(screen)
	for i in 30:
		await process_frame
	var battle = screen.get("battle")
	var slots: Array = screen.get("_ally_slots")
	var w0: Control = slots[0]["wrap"]
	var erec: Dictionary = (screen.get("_enemy_slots") as Array)[0]
	var ew: Control = erec["wrap"]
	var e0: Dictionary = erec["enemy"]
	var e_lbl: Label = erec["hplbl"]
	var c0 := w0.global_position + w0.size * 0.5
	var ec := ew.global_position + ew.size * 0.5

	## —— §1 玩家普攻 ——
	var hit_holder := {"ms": -1}
	battle.hit_landed.connect(func(_t, _a, _k): hit_holder["ms"] = Time.get_ticks_msec())
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = c0
	press.global_position = c0
	Input.parse_input_event(press)
	await process_frame
	var prev := c0
	for i in 12:
		var t := float(i + 1) / 12.0
		var p := c0.lerp(ec, t)
		var m := InputEventMouseMotion.new()
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.position = p
		m.global_position = p
		m.relative = p - prev
		prev = p
		Input.parse_input_event(m)
		await process_frame
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_LEFT
	rel.pressed = false
	rel.position = ec
	rel.global_position = ec
	Input.parse_input_event(rel)

	var t0 := Time.get_ticks_msec()
	var hp := int(e0["hp"])
	var model_ms := -1
	var label_ms := -1
	var e_txt := String(e_lbl.text)
	var busy_end := -1
	var busy := true
	for i in 150:
		await process_frame
		if model_ms < 0 and int(e0["hp"]) != hp:
			model_ms = Time.get_ticks_msec() - t0
			hp = int(e0["hp"])
		if label_ms < 0 and String(e_lbl.text) != e_txt:
			label_ms = Time.get_ticks_msec() - t0
		if busy and not bool(screen.get("_busy")):
			busy = false
			busy_end = Time.get_ticks_msec() - t0
		if model_ms >= 0 and label_ms >= 0 and not busy:
			break
	print("S1 enemy model_ms=%d label_ms=%d busy_end=%d" % [model_ms, label_ms, busy_end])
	if model_ms < 0 or model_ms > 480:
		fails.append("§1 敌模型扣血不在命中帧（%d ms）" % model_ms)
	if label_ms < 0 or label_ms > model_ms + 120 or label_ms > 480:
		fails.append("§1 敌血条文字迟于命中帧（label=%d model=%d）" % [label_ms, model_ms])

	## —— §2 敌方回合：结束回合 → 敌动 → 我方扣血与血条同帧降 ——
	await create_timer(0.6).timeout
	var a0: Dictionary = slots[0]["unit"]
	var a_lbl: Label = slots[0]["hplbl"]
	var a_hp := int(a0["hp"])
	var a_txt := String(a_lbl.text)
	var btn := _find_btn(screen, "结束回合")
	if btn == null:
		fails.append("§2 未找到结束回合钮")
	else:
		var t1 := Time.get_ticks_msec()
		var a_model := -1
		var a_label := -1
		var seq_end := -1
		var seq_busy := true
		btn.pressed.emit()
		for i in 400:
			await process_frame
			if a_model < 0 and int(a0["hp"]) != a_hp:
				a_model = Time.get_ticks_msec() - t1
			if a_label < 0 and String(a_lbl.text) != a_txt:
				a_label = Time.get_ticks_msec() - t1
			if seq_busy and not bool(screen.get("_busy")):
				seq_busy = false
				seq_end = Time.get_ticks_msec() - t1
			if (a_model >= 0 and a_label >= 0 and not seq_busy) or i == 399:
				break
		print("S2 ally model_ms=%d label_ms=%d enemy_seq_end=%d" % [a_model, a_label, seq_end])
		if a_model >= 0 and a_label >= 0:
			if a_label > a_model + 120:
				fails.append("§2 我方血条迟于模型扣血（label=%d model=%d）——漏发 changed 病" % [a_label, a_model])
			if seq_end >= 0 and a_model > seq_end:
				fails.append("§2 我方扣血落在敌方回合结束之后（%d > %d）" % [a_model, seq_end])
		elif a_model < 0 and a_label < 0:
			print("S2 敌方未打我方（意图非攻击？）——跳过断言")

	print("TIMING_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("HIT_TIMING_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
