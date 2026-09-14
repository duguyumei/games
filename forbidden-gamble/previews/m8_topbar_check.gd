extends Node
# M8 顶栏验收（C-017）：
# 1) 结构：TopBar 在列首、旧 LogStrip/TurnInfo 已删、总高恰好 720（36+350+110+224）
# 2) 沙盒上下文 + 回合·行动方（金色"你的行动"）
# 3) 顶栏战报行随换牌更新
# 4) 设置弹窗：演出速度三档切换 _pace、当前档禁用
# 5) 点弹窗外任意处关闭设置弹窗（不与顶栏重叠）
# 6) ESC 收弹窗
# 7) 结束演练两段确认 → 切回主菜单（放最后：切场景会释放本脚本）

func _ready() -> void:
	var fails: Array[String] = []

	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- 1) 结构与总高 ---
	if main.get_node_or_null("Center/Column/TopBar") == null:
		fails.append("[1] 缺顶栏 TopBar")
	if main.get_node_or_null("Center/Column/LogStrip") != null:
		fails.append("[1] 旧底部日志窄条 LogStrip 未删除")
	if main.get_node_or_null("Center/Column/Stage/CenterZone/TurnInfo") != null:
		fails.append("[1] 旧中央回合条 TurnInfo 未删除")
	var column: Control = main.get_node("Center/Column")
	if absf(column.size.y - 720.0) > 1.0:
		fails.append("[1] 列总高 %.0f（应为 720：36 顶栏+350 演武区+110 手牌+224 功法）" % column.size.y)
	print("[1] 列总高=%.0f TopBar=%s LogStrip=%s TurnInfo=%s" % [
		column.size.y,
		main.get_node_or_null("Center/Column/TopBar") != null,
		main.get_node_or_null("Center/Column/LogStrip") != null,
		main.get_node_or_null("Center/Column/Stage/CenterZone/TurnInfo") != null])

	# --- 2) 上下文与回合行 ---
	var context: Label = main.get_node("Center/Column/TopBar/Bar/ContextLabel")
	var turn: Label = main.get_node("Center/Column/TopBar/Bar/TurnLabel")
	if context.text != "演武场 · 演练":
		fails.append("[2] 沙盒遭遇名='%s'（应为 演武场 · 演练）" % context.text)
	if not turn.text.contains("架势 0 次") or not turn.text.contains("你的行动"):
		fails.append("[2] 回合行='%s'（应含 架势 0 次 与 你的行动）" % turn.text)
	var turn_color: Color = turn.get_theme_color("font_color")
	if absf(turn_color.r - 0.85) > 0.05 or absf(turn_color.g - 0.68) > 0.05:
		fails.append("[2] 你的行动未着金（%s）" % turn_color)
	print("[2] 遭遇名='%s' 回合行='%s'" % [context.text, turn.text])

	# --- 3) 战报行随事件更新 ---
	var log_line: Label = main.get_node("Center/Column/TopBar/Bar/LogLine")
	var log_before := log_line.text
	main._on_swap_pressed()
	main._on_card_clicked(0)
	main.confirm_swap()
	await get_tree().process_frame
	await get_tree().process_frame
	if log_line.text == log_before or log_line.text.strip_edges().is_empty():
		fails.append("[3] 架势后顶栏战报行未更新（'%s'）" % log_line.text)
	print("[3] 战报行 '%s' → '%s'" % [log_before, log_line.text])
	while main.sequencer.busy:
		await get_tree().process_frame
	while main.turn_manager.awaiting_player_claims and not main.turn_manager.is_over():
		main._release_claim_window()
		await get_tree().process_frame

	# --- 4) 设置弹窗与演出速度 ---
	main.get_node("Center/Column/TopBar/Bar/GearButton").pressed.emit()
	await get_tree().process_frame
	var settings_panel: Control = main._popup_host.current_content()
	if settings_panel == null or main._popup_kind != "settings":
		fails.append("[4] ⚙ 未弹出设置面板（kind=%s）" % main._popup_kind)
	else:
		var find_pace_btn := func(text_prefix: String) -> Button:
			var panel_now: Control = main._popup_host.current_content()
			if panel_now == null:
				return null
			for node in panel_now.get_children():
				for child in node.get_children():
					if child is HBoxContainer:
						for b in child.get_children():
							if b is Button and (b as Button).text.begins_with(text_prefix):
								return b
			return null
		if find_pace_btn.call("慢") == null or find_pace_btn.call("快") == null or find_pace_btn.call("标准") == null:
			fails.append("[4] 速度档按钮不全（慢/快/标准）")
		var saw_disabled := false
		for prefix in ["快", "标准", "慢"]:
			var b := find_pace_btn.call(prefix) as Button
			if b != null and b.disabled:
				saw_disabled = true
		if not saw_disabled:
			fails.append("[4] 当前速度档未禁用标示")
		var slow: Button = find_pace_btn.call("慢")
		if slow != null and not slow.disabled:
			slow.pressed.emit()
			if absf(main._pace - 1.6) > 0.01:
				fails.append("[4] 点慢后 _pace=%.2f（应 1.60）" % main._pace)
			var fast: Button = find_pace_btn.call("快")
			if fast != null:
				fast.pressed.emit()
				if absf(main._pace - 0.6) > 0.01:
					fails.append("[4] 点快后 _pace=%.2f（应 0.60）" % main._pace)
			var normal: Button = find_pace_btn.call("标准")
			if normal != null:
				normal.pressed.emit()
				if absf(main._pace - 1.0) > 0.01:
					fails.append("[4] 点标准后 _pace=%.2f（应 1.00）" % main._pace)
		print("[4] 速度档切换 OK，当前 _pace=%.2f（弹窗开着=%s）" % [main._pace, main._popup_kind == "settings"])

	# --- 5) 点弹窗外任意处关闭（全屏背板捕获；设置弹窗开着） ---
	get_window().size = Vector2i(1280, 800)  # 非 16:9 窗口：expand 下画布变高，验证弹窗贴顶栏而非贴屏幕角
	await get_tree().process_frame
	var popup_panel: Control = main._popup_host.current_content()
	var bar_rect: Rect2 = (main.get_node("Center/Column/TopBar") as Control).get_global_rect()
	if popup_panel != null and popup_panel.get_global_rect().intersects(bar_rect):
		fails.append("[5] 设置弹窗与顶栏重叠（bar=%s panel=%s）" % [bar_rect, popup_panel.get_global_rect()])
	var click_out := InputEventMouseButton.new()
	click_out.button_index = MOUSE_BUTTON_LEFT
	click_out.pressed = true
	click_out.position = Vector2(640, 400)
	get_viewport().push_input(click_out)
	await get_tree().process_frame
	if main._popup_kind != "" or main._popup_host.is_open():
		fails.append("[5] 点弹窗外未关闭设置弹窗（kind=%s）" % main._popup_kind)
	else:
		print("[5] 点外关闭设置弹窗 OK（kind='%s'）" % main._popup_kind)

	# --- 6) ESC 收弹窗（重开设置后按 ESC） ---
	main._on_settings_pressed()
	await get_tree().process_frame
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	get_viewport().push_input(esc)
	await get_tree().process_frame
	if main._popup_kind != "" or main._popup_host.is_open():
		fails.append("[6] ESC 未收起设置弹窗（kind=%s）" % main._popup_kind)
	print("[6] ESC 收弹窗 OK（kind='%s'）" % main._popup_kind)

	# --- 6.7) 战报罩层：点面板本体可关（滚动容器不得吞点击）、ESC 可开关 ---
	main.get_node("Center/Column/TopBar/Bar/ReportButton").pressed.emit()
	await get_tree().process_frame
	var overlay: Control = main.get_node("LogOverlay")
	if not overlay.visible:
		fails.append("[6.7] 战报按钮未打开罩层")
	var click_panel := InputEventMouseButton.new()
	click_panel.button_index = MOUSE_BUTTON_LEFT
	click_panel.pressed = true
	click_panel.position = Vector2(640, 200)
	get_viewport().push_input(click_panel)
	await get_tree().process_frame
	if overlay.visible:
		fails.append("[6.7] 点击战报面板未关闭（滚动容器吞点击）")
	print("[6.7] 战报面板点击关闭=%s" % (not overlay.visible))
	main.get_node("Center/Column/TopBar/Bar/ReportButton").pressed.emit()
	await get_tree().process_frame
	get_viewport().push_input(esc)
	await get_tree().process_frame
	if overlay.visible:
		fails.append("[6.7] ESC 未关闭战报罩层")
	print("[6.7] ESC 关闭战报=%s" % (not overlay.visible))

	# --- 8) 演出节点不挤占 Column 布局（M3 返修：横幅/幽灵/飘字挂 FxLayer） ---
	# 横幅若是 VBox 直接子节点，其 52px 最小高会把列撑到 772：顶栏被切、功法层沉底。
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	main.fx.technique_banner("enemy", "点星式")
	await get_tree().process_frame
	var column8: Control = main.get_node("Center/Column")
	if absf(column8.get_combined_minimum_size().y - 720.0) > 1.0:
		fails.append("[8] 播放横幅后 Column 最小高 %.0f（应 720，演出节点混进布局）" % column8.get_combined_minimum_size().y)
	if absf(column8.size.y - 720.0) > 1.0:
		fails.append("[8] 播放横幅后 Column 实际高 %.0f（应 720）" % column8.size.y)
	if main.fx._banner != null and main.fx._banner.get_parent() == column8:
		fails.append("[8] 横幅挂进了 Column（应挂 FxLayer）")
	if main.fx._banner != null and str(main.fx._banner.get_parent().name) != "FxLayer":
		fails.append("[8] 横幅挂载层='%s'（应 FxLayer）" % main.fx._banner.get_parent().name)
	var tech8: Control = main.get_node("Center/Column/TechLayer")
	if tech8.get_global_rect().end.y > 720.5:
		fails.append("[8] 功法层底缘 %.0f 超出画布 720（沉底）" % tech8.get_global_rect().end.y)
	print("[8] 横幅回归：Column=%.0f 功法层底=%.0f 横幅挂载=%s" % [
		column8.size.y, tech8.get_global_rect().end.y,
		main.fx._banner.get_parent().name if main.fx._banner != null else "?"])

	# 截图留档（headless 假渲染无纹理，跳过）
	if DisplayServer.get_name() != "headless":
		var image := get_viewport().get_texture().get_image()
		if image != null:
			image.save_png("user://m8_topbar_shot.png")
			print("截图：user://m8_topbar_shot.png")

	var earlier_failed := not fails.is_empty()
	if earlier_failed:
		for f in fails:
			push_error("M8 CHECK FAIL: " + f)
	# --- 7) 沙盒弃战 → 回主菜单 ---
	# change_scene 会立即释放当前场景（含本脚本），普通 lambda/方法回调随实例一起失效——
	# 看门狗必须自主存活：运行时生成脚本、挂到 /root（随场景切换存活）再触发弃战。
	main._on_settings_pressed()
	await get_tree().process_frame
	var abandon_btn: Button = null
	var panel_now: Control = main._popup_host.current_content()
	if panel_now != null:
		for node in panel_now.get_children():
			for child in node.get_children():
				if child is ConfirmButton:
					abandon_btn = child
	if abandon_btn == null:
		push_error("M8 CHECK FAIL: [7] 未找到弃战按钮")
		get_tree().quit(1)
		return
	abandon_btn.pressed.emit()  # 第一段：武装（换确认文案）
	if not abandon_btn.text.begins_with("确定"):
		push_error("M8 CHECK FAIL: [7] 弃战两段确认未生效（'%s'）" % abandon_btn.text)
		get_tree().quit(1)
		return
	var watchdog := Node.new()
	var ws := GDScript.new()
	ws.source_code = "extends Node\n" \
		+ "func _ready() -> void:\n" \
		+ "\tawait get_tree().create_timer(0.8).timeout\n" \
		+ "\tvar path: String = get_tree().current_scene.scene_file_path\n" \
		+ "\tif path != \"res://scenes/title/title.tscn\":\n" \
		+ "\t\tpush_error(\"M8 CHECK FAIL: [7] 弃战后未回主菜单（当前=\" + path + \"）\")\n" \
		+ "\t\tget_tree().quit(1)\n" \
		+ "\telif %s:\n" % ("true" if earlier_failed else "false") \
		+ "\t\tget_tree().quit(1)\n" \
		+ "\telse:\n" \
		+ "\t\tprint(\"PASS: M8 顶栏（结构/上下文/战报行/速度档/点外关闭/ESC/结束演练出口）全部通过\")\n" \
		+ "\t\tget_tree().quit(0)\n"
	if ws.reload() != OK:
		push_error("M8 CHECK FAIL: [7] 看门狗脚本编译失败")
		get_tree().quit(1)
		return
	watchdog.set_script(ws)
	get_tree().root.add_child(watchdog)
	abandon_btn.pressed.emit()
