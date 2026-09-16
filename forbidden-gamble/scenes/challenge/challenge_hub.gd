extends Control

## 挑战总览（挑战层 M2）：三对手卡横列（当前高亮/已过打勾）＋状态栏＋迎战；
## 胜利态＝战绩总览（D14 小丑牌对齐）；失败态＝战报。恢复锚路由 deck_select 完成。


func _ready() -> void:
	if not RunSession.active or RunSession.state == null:
		# 场景切换须延迟：_ready 期内场景树仍在挂节点，立即切会撞
		# "Parent node is busy adding/removing children"（2026-09-17 运行时闸抓出）
		get_tree().change_scene_to_file.call_deferred(SceneRoutes.DECK_SELECT)
		return
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var state := RunSession.state
	if state.phase == "victory" or state.phase == "over":
		root.add_child(_end_panel(state))
		await PreviewCapture.maybe_capture(self)
		return

	var title := Label.new()
	title.text = "组挑战·第 %d 战" % (state.battle_index + 1)
	title.add_theme_font_size_override("font_size", 24)
	root.add_child(title)
	root.add_child(_status_panel(state))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)
	var ids: Array = DataRepo.mj_opponents().keys()
	for i in range(ids.size()):
		row.add_child(_opponent_card(DataRepo.mj_opponents()[ids[i]], i, state.battle_index))

	var fight := Button.new()
	fight.text = "迎战 %s" % str(DataRepo.mj_opponents()[ids[mini(state.battle_index, ids.size() - 1)]].get("name", ""))
	fight.custom_minimum_size = Vector2(280, 46)
	fight.pressed.connect(func() -> void:
		state.phase = "battle"
		RunSaver.save_state(state)
		get_tree().change_scene_to_file(SceneRoutes.MJ_BATTLE))
	root.add_child(fight)

	var back := Button.new()
	back.text = "‹ 回主菜单（进度已存档）"
	back.pressed.connect(func(): get_tree().change_scene_to_file(SceneRoutes.TITLE))
	root.add_child(back)
	await PreviewCapture.maybe_capture(self)


func _status_panel(state: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = "气血 %d/%d｜历练 %d｜内力 劲%d·骨%d·气%d（共%d）｜槽 功%d·心%d·护%d" % [
		state.hp_fp / 100, int(state.deck.get("base_max_hp", 100)),
		state.lianli, state.neili["jin"], state.neili["gu"], state.neili["qi"], state.neili_points,
		state.slot_caps["gongfa"], state.slot_caps["xinfa"], state.slot_caps["hushen"]]
	var arms: Array[String] = []
	for kind in ["gongfa", "xinfa", "hushen"]:
		for wid in state.loadout[kind]:
			var t := MJTechniqueLibrary.make(str(wid))
			arms.append(t.display_name if t != null else str(wid))
	label.text += "\n武学：%s" % ("、".join(arms) if not arms.is_empty() else "—")
	var lings: Array[String] = []
	for tile_key in state.pailing:
		lings.append("%s·%s" % [
			(MJPaiLing.make(str(state.pailing[tile_key]), "", 0).display_name if MJPaiLing.make(str(state.pailing[tile_key]), "", 0) != null else str(state.pailing[tile_key])),
			tile_key])
	label.text += "\n牌灵：%s" % ("、".join(lings) if not lings.is_empty() else "—")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	return panel


func _opponent_card(opp: Dictionary, index: int, current: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var n: Dictionary = opp.get("neili", {})
	var tier := "【首领】" if str(opp.get("tier", "")) == "boss" else "【喽啰】"
	var status := "✔ 已过" if index < current else ("▶ 当前" if index == current else "· 待战")
	var head := Label.new()
	head.text = "%s %s %s" % [status, opp.get("name", ""), tier]
	head.add_theme_font_size_override("font_size", 18)
	v.add_child(head)
	var body := Label.new()
	body.text = "气血 %d｜面板 攻 %d·防 %d·架势 %d\n功法 %s" % [
		int(opp.get("base_max_hp", 100)),
		int(opp.get("base_attack", 10)) + 2 * int(n.get("jin", 1)),
		int(opp.get("base_defense", 0)) + int(n.get("gu", 1)),
		int(opp.get("base_jing", 1)) + 2,
		"、".join(_tech_names(opp.get("techniques", [])))]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	panel.modulate = Color(1, 1, 1) if index <= current else Color(0.6, 0.6, 0.6)
	return panel


func _tech_names(ids: Array) -> Array[String]:
	var names: Array[String] = []
	for wid in ids:
		var t := MJTechniqueLibrary.make(str(wid))
		names.append(t.display_name if t != null else str(wid))
	return names


func _end_panel(state: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := Label.new()
	head.text = "⚔ 组挑战告捷" if state.phase == "victory" else "✖ 挑战失利"
	head.add_theme_font_size_override("font_size", 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var body := Label.new()
	body.text = "战绩：胜 %d/3｜累计拍数 %d｜剩余气血 %d\n历练所得 %d｜内力成长至 %d 点" % [
		state.wins, state.total_beats, state.hp_fp / 100,
		state.lianli, state.neili_points]
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	v.add_child(_status_panel(state))
	var again := Button.new()
	again.text = "再战一组"
	again.custom_minimum_size = Vector2(240, 44)
	again.pressed.connect(func() -> void:
		RunSession.end()
		get_tree().change_scene_to_file(SceneRoutes.DECK_SELECT))
	v.add_child(again)
	var home := Button.new()
	home.text = "回主菜单"
	home.custom_minimum_size = Vector2(240, 40)
	home.pressed.connect(func() -> void:
		RunSession.end()
		get_tree().change_scene_to_file(SceneRoutes.TITLE))
	v.add_child(home)
	return panel
