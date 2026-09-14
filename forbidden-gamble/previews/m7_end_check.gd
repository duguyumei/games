extends Node
# 敌方连拍演出 + 终局结算浮层验收：
# 1) 玩家换牌把行动权交给敌方后，演出链进入 busy 态（不是一帧内全结算完）
# 2) 敌方出手有节奏（浮层出现时间 ≥ 一拍停顿），期间面板/日志已更新
# 3) 玩家被击倒 → 终局浮层弹出：败北标题 + 致命一击 + 重开按钮（沙盒）
# 4) 重开一场 → 浮层收起、新战斗就绪（第 1 回合、满气血）

func _ready() -> void:
	var fails: Array[String] = []
	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main.combat == null:
		print("FAIL: 战斗未初始化")
		get_tree().quit()
		return

	# --- 1) 演出链 busy：架势让权后敌方回合应进入逐条演出态（若敌方截链同步结算，则行动权已回玩家） ---
	main.combat.player.hp = 1
	var started := Time.get_ticks_msec()
	main._on_swap_pressed()
	main._on_card_clicked(0)
	main.confirm_swap()
	await get_tree().process_frame
	if not main.sequencer.busy and main.combat.active_side == "enemy":
		fails.append("[1] 敌方回合未进入演出 busy 态")
	var banner_during: String = main.get_node("Center/Column/TopBar/Bar/TurnLabel").text
	print("[1] 架势让权后 busy=%s active=%s 顶栏回合行='%s'" % [main.sequencer.busy, main.combat.active_side, banner_during])

	# 敌方偶尔锁防御意图时不掉血：最多再试两轮，每轮前压到 1 血保证致死；
	# 玩家截牌窗开着则一律放行（窗口作废）再操作。
	for attempt in range(2):
		if main.turn_manager.is_over():
			break
		var w := 0.0
		while main.sequencer.busy and w < 6.0:
			await get_tree().create_timer(0.1).timeout
			w += 0.1
		while main.turn_manager.awaiting_player_claims and not main.turn_manager.is_over():
			main._release_claim_window()
			await get_tree().process_frame
		main.combat.player.hp = 1
		started = Time.get_ticks_msec()
		main._on_swap_pressed()
		main._on_card_clicked(0)
		main.confirm_swap()
		await get_tree().process_frame

	# --- 2)+3) 等终局浮层（演出一拍 + 终局停一拍后弹出） ---
	var overlay: Control = main.get_node("EndOverlay")
	var waited := 0.0
	while not overlay.visible and waited < 8.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if not overlay.visible:
		fails.append("[3] 终局结算浮层未弹出（等待 %.1fs）" % waited)
		_finish(fails)
		return
	var elapsed := float(Time.get_ticks_msec() - started)
	if elapsed < 1000.0:
		fails.append("[2] 浮层出现过快（%.0fms），敌方行动缺少演出节奏" % elapsed)
	var title: String = main.get_node("EndOverlay/Center/Panel/Margin/Column/Title").text
	var sub: String = main.get_node("EndOverlay/Center/Panel/Margin/Column/Sub").text
	if not title.contains("败北"):
		fails.append("[3] 应判败北（标题='%s'）" % title)
	if not sub.contains("致命一击"):
		fails.append("[3] 败北摘要缺致命一击（'%s'）" % sub)
	if not main.get_node("EndOverlay/Center/Panel/Margin/Column/BtnRow/RestartButton").visible:
		fails.append("[3] 应显示重开按钮")
	if not main.get_node("EndOverlay/Center/Panel/Margin/Column/BtnRow/ReturnButton").visible:
		fails.append("[3] 应显示回演武场按钮")
	print("[2] 演出→浮层耗时 %.0fms（含 0.6s 行动拍 + 0.8s 终局拍）" % elapsed)
	print("[3] 浮层：标题='%s'" % title)
	print("[3] 摘要：'%s'" % sub.replace("\n", " ｜ "))

	# 截图留档（headless 假渲染器无纹理，容错跳过；窗口模式可截）
	await get_tree().create_timer(0.3).timeout
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png("user://m7_end_shot.png")

	# --- 4) 重开一场 ---
	var restart: Button = main.get_node("EndOverlay/Center/Panel/Margin/Column/BtnRow/RestartButton")
	restart.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if overlay.visible:
		fails.append("[4] 重开后浮层未收起")
	if main.combat.player_swap_count != 0 or main.combat.player.hp != main.combat.player.max_hp:
		fails.append("[4] 重开未复位（气口=%d 气血=%d/%d）" % [main.combat.player_swap_count, main.combat.player.hp, main.combat.player.max_hp])
	if main.sequencer.busy:
		fails.append("[4] 重开后演出链仍在 busy")
	print("[4] 重开：气口=%d 气血=%d/%d busy=%s" % [main.combat.player_swap_count, main.combat.player.hp, main.combat.player.max_hp, main.sequencer.busy])

	_finish(fails)

func _finish(fails: Array[String]) -> void:
	if fails.is_empty():
		print("PASS: 敌方演出节奏 + 终局结算浮层全部通过")
	else:
		for f in fails:
			print("FAIL: " + f)
	get_tree().quit()
