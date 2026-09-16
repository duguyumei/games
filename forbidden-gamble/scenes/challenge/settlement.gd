extends Control

## 战后结算屏（挑战层 M2，D4）：历练入账（battle 侧已 grant，此处展示）＋内力+1＋
## 武学三选一（免费拿一；槽满类型自动缺位、牌灵补位——奖励永远可用）。
## 确认后：生成修习货架＋begin_visit＋存档，转 xiuxi。


var _picked := false


func _ready() -> void:
	if not RunSession.active or RunSession.state == null or RunSession.state.phase != "settlement":
		get_tree().change_scene_to_file.call_deferred(SceneRoutes.CHALLENGE_HUB)  # _ready 期内切场景须延迟（同 hub）
		return
	_picked = false
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
	var title := Label.new()
	title.text = "⚔ 第 %d 战告捷" % state.wins
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)

	var rewards := Label.new()
	rewards.text = "历练 +%d（共 %d）｜内力 +1（共 %d 点，可在修习洗点）" % [
		state.last_grant, state.lianli, state.neili_points]
	root.add_child(rewards)

	root.add_child(_pick3_panel(state))

	var confirm := Button.new()
	confirm.text = "前往修习 ›"
	confirm.custom_minimum_size = Vector2(240, 44)
	confirm.pressed.connect(_on_confirm)
	root.add_child(confirm)
	await PreviewCapture.maybe_capture(self)


func _pick3_panel(state: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := Label.new()
	head.text = "三选一·免费拿一（槽满的类型不出；牌灵需再择一枚牌种）"
	v.add_child(head)
	var picks := RunShop.roll_pick3(state, RunSession.shop_cfg())
	if picks.is_empty():
		var empty := Label.new()
		empty.text = "宝山已空——无可选之件"
		v.add_child(empty)
		return panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for entry in picks:
		row.add_child(_pick_card(entry))
	return panel


func _pick_card(entry: Dictionary) -> VBoxContainer:
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	var is_pailing := String(entry.get("cat", "")) == "pailing"
	var name_label := Label.new()
	var summary := ""
	if is_pailing:
		var ling := MJPaiLing.make(str(entry.get("id", "")), "", 0)
		name_label.text = "牌灵·%s" % (ling.display_name if ling != null else str(entry.get("id", "")))
		summary = ling.summary() if ling != null else ""
	else:
		var t := MJTechniqueLibrary.make(str(entry.get("id", "")))
		name_label.text = "武学·%s" % (t.display_name if t != null else str(entry.get("id", "")))
		summary = t.brief if t != null else ""
	card.add_child(name_label)
	var desc := Label.new()
	desc.text = summary
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	card.add_child(desc)
	var take := Button.new()
	take.text = "取之"
	take.pressed.connect(func() -> void:
		if _picked:
			return
		if is_pailing:
			ChTilePicker.open(self, RunSession.state, func(suit: String, value: int) -> void:
				if suit.is_empty():
					return  # 放弃绑定＝放弃本次三选一
				if RunShop.take_pick(RunSession.state, str(entry.get("id", "")), "pailing", "", "%s%d" % [suit, value]):
					_on_acquired(str(entry.get("id", "")))
					_picked = true)
		else:
			if RunShop.take_pick(RunSession.state, str(entry.get("id", "")), "wuxue", str(entry.get("kind", "gongfa"))):
				_on_acquired(str(entry.get("id", "")))
				_picked = true)
	card.add_child(take)
	return card


func _on_acquired(id_str: String) -> void:
	CodexState.discover(id_str)
	RunSaver.save_state(RunSession.state)
	get_tree().reload_current_scene()  # 拿一后刷新（剩余选项归零显示已取）


func _on_confirm() -> void:
	var state := RunSession.state
	state.phase = "xiuxi"
	state.begin_visit()
	RunShop.roll_shelf(state, RunSession.shop_cfg())
	RunSaver.save_state(state)
	get_tree().change_scene_to_file(SceneRoutes.XIUXI)
