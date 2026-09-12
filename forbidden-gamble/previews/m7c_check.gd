extends Node
# M7c/d 收官验收：
# 1) 镶孔结构：QiSlot 为环+孔双层（含 Hole，且 Hole 不吞鼠标）
# 2) 演出时按钮隐藏：敌方演出 busy 期间中央按钮行不可见、玩家回合恢复
# 3) 功法横幅：敌方发动功法时横幅出现
# 4) 真气流动：推进到第 2 回合期间观察到幽灵丹珠（抽牌流入/回收回流）
# 5) 日志窄条着色：敌方发动行显示朱红

func _ready() -> void:
	var fails: Array[String] = []

	# --- 1) 镶孔双层结构 ---
	var slot: Control = load("res://ui/qi_slot.tscn").instantiate()
	add_child(slot)
	await get_tree().process_frame
	var hole := slot.get_node_or_null("Hole")
	if hole == null:
		fails.append("[1] QiSlot 缺 Hole 孔层")
	elif hole.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		fails.append("[1] Hole 应忽略鼠标（当前 %d）" % hole.mouse_filter)
	else:
		print("[1] QiSlot 环+孔双层 OK，Hole 不吞鼠标")
	slot.queue_free()

	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 2) 按钮行可见性 ---
	var buttons: Control = main.get_node("Center/Column/Stage/CenterZone/Buttons")
	if not buttons.visible:
		fails.append("[2] 初始（玩家回合）按钮行应可见")
	print("[2] 初始按钮行可见=%s" % buttons.visible)

	var saw_banner := false
	var ghost_peak := 0
	main._on_breathe_pressed()
	await get_tree().process_frame
	if buttons.visible:
		fails.append("[2] 敌方演出期间按钮行应隐藏")
	print("[2] 敌方演出期间按钮行可见=%s busy=%s" % [buttons.visible, main.sequencer.busy])
	# 收链后必须自行恢复按钮行（不依赖玩家再点一下触发重绘）
	var waited := 0.0
	while main.sequencer.busy and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(0.2).timeout
	if not buttons.visible:
		fails.append("[2] 敌方演出结束后按钮行未自行恢复（缺收链重绘）")
	print("[2] 收链后按钮行恢复=%s（无额外交互）" % buttons.visible)

	# --- 3)+4) 轮询横幅与幽灵珠，暂让推进直到第 2 回合 ---
	var banner_shot_taken := false
	for i in range(60):
		await get_tree().create_timer(0.1).timeout
		if main.fx.banner_visible():
			saw_banner = true
			if not banner_shot_taken:
				banner_shot_taken = true
				var banner_image := get_viewport().get_texture().get_image()
				if banner_image != null:
					banner_image.save_png("user://m7c_banner_shot.png")
		ghost_peak = maxi(ghost_peak, get_tree().get_nodes_in_group("qi_ghost").size())
		if main.combat.player_breath_count >= 1 and not main.sequencer.busy:
			break
		if not main.sequencer.busy and main.combat.active_side == "player" \
				and main.combat.player_breath_count < 1 and not main.turn_manager.is_over():
			main._on_breathe_pressed()
	if not saw_banner:
		fails.append("[3] 未观察到功法横幅（沙盒种子下敌方第1回合应发动功法）")
	if ghost_peak < 3:
		fails.append("[4] 真气流动幽灵珠过少（峰值 %d）" % ghost_peak)
	print("[3] 功法横幅出现=%s" % saw_banner)
	print("[4] 幽灵丹珠峰值=%d（抽牌流入+回收回流）" % ghost_peak)

	# --- 5) 日志着色（顶栏战报行） ---
	var log_line: Label = main.get_node("Center/Column/TopBar/Bar/LogLine")
	if String(log_line.text).begins_with("敌方发动"):
		var c: Color = log_line.get_theme_color("font_color")
		if absf(c.r - 0.8) > 0.05 or absf(c.g - 0.38) > 0.05:
			fails.append("[5] 敌方发动行未着朱红（%s）" % c)
		print("[5] 日志行='%s' 色=(%.2f,%.2f,%.2f)" % [log_line.text, c.r, c.g, c.b])
	else:
		print("[5] 最新行非敌方发动（'%s'），跳过着色断言" % log_line.text)

	# 截图留档（headless 假渲染无纹理时跳过）
	await get_tree().create_timer(0.3).timeout
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://m7c_shot.png")

	if fails.is_empty():
		print("PASS: M7 收官（流动/横幅/按钮隐藏/镶孔/日志着色）全部通过")
	else:
		for f in fails:
			print("FAIL: " + f)
	get_tree().quit()
