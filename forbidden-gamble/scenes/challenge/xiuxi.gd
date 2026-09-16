extends Control

## 修习（挑战层 M2，D5/D10/D11）：四区——抽选货架（三件＋重掷）｜疗伤丹固定格（限购）｜
## 开槽区（三轨递增价）｜洗点（免费，首战锁死禁用）。每次变更写穿存档＋图鉴发现。


func _ready() -> void:
	if not RunSession.active or RunSession.state == null:
		get_tree().change_scene_to_file.call_deferred(SceneRoutes.DECK_SELECT)  # _ready 期内切场景须延迟
		return
	_build()
	await PreviewCapture.maybe_capture(self)


func _build() -> void:
	for child in get_children():
		child.queue_free()
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
	var shop := RunSession.shop_cfg()
	var head := Label.new()
	head.text = "修习（第 %d 战后）　历练 %d" % [state.battle_index, state.lianli]
	head.add_theme_font_size_override("font_size", 24)
	root.add_child(head)

	root.add_child(_shelf_panel(state, shop))
	root.add_child(_heal_and_slots_panel(state, shop))
	root.add_child(_respec_panel(state))

	var cont := Button.new()
	cont.text = "继续 › 下一战"
	cont.custom_minimum_size = Vector2(240, 44)
	cont.pressed.connect(func() -> void:
		state.phase = "hub"
		RunSaver.save_state(state)
		get_tree().change_scene_to_file(SceneRoutes.CHALLENGE_HUB))
	root.add_child(cont)


func _shelf_panel(state: RunState, shop: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "货架（武学×2＋牌灵×1；槽满的武学须先开槽方可购买）"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reroll := Button.new()
	reroll.text = "重掷（%d）" % RunShop.reroll_cost(state, shop)
	reroll.disabled = state.lianli < RunShop.reroll_cost(state, shop)
	reroll.pressed.connect(func() -> void:
		RunShop.reroll(state, shop)
		RunSaver.save_state(state)
		_build())
	head.add_child(reroll)
	v.add_child(head)

	var available := 0
	for item in state.shelf:
		if not bool((item as Dictionary).get("bought", false)):
			available += 1
	if available == 0:
		var empty := Label.new()
		empty.text = "宝山已空"
		v.add_child(empty)
		return panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for i in range(state.shelf.size()):
		var entry: Dictionary = state.shelf[i]
		if bool(entry.get("bought", false)):
			continue
		row.add_child(_shelf_card(state, shop, entry, i))
	return panel


func _shelf_card(state: RunState, shop: Dictionary, entry: Dictionary, index: int) -> VBoxContainer:
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
	var buy := Button.new()
	var price := int(entry.get("price", 0))
	buy.text = "历练 %d 购入" % price
	buy.disabled = state.lianli < price
	buy.pressed.connect(func() -> void:
		var cat := RunShop.buy(state, shop, index)
		if cat == "pailing":
			ChTilePicker.open(self, state, func(suit: String, value: int) -> void:
				if not suit.is_empty() and state.acquire_pailing(str(entry.get("id", "")), "%s%d" % [suit, value]):
					CodexState.discover(str(entry.get("id", "")))
				RunSaver.save_state(state)
				_build())
		elif cat == "wuxue":
			CodexState.discover(str(entry.get("id", "")))
			RunSaver.save_state(state)
			_build())
	card.add_child(buy)
	return card


func _heal_and_slots_panel(state: RunState, shop: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var heal: Dictionary = shop.get("heal_item", {})
	var heal_row := HBoxContainer.new()
	var heal_label := Label.new()
	heal_label.text = "%s：价 %d 回 %d（每访限一）　气血 %d/%d" % [
		heal.get("name", "疗伤丹"), int(heal.get("price", 0)), int(heal.get("heal", 0)),
		state.hp_fp / 100, int(state.deck.get("base_max_hp", 100))]
	heal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heal_row.add_child(heal_label)
	var heal_btn := Button.new()
	heal_btn.text = "已购" if state.heal_bought_this_visit else "服下"
	heal_btn.disabled = state.heal_bought_this_visit or state.lianli < int(heal.get("price", 0))
	heal_btn.pressed.connect(func() -> void:
		RunShop.buy_heal(state, shop)
		RunSaver.save_state(state)
		_build())
	heal_row.add_child(heal_btn)
	v.add_child(heal_row)

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	for kind in ["gongfa", "xinfa", "hushen"]:
		var box := VBoxContainer.new()
		var kind_name: String = {"gongfa": "功法", "xinfa": "心法", "hushen": "护身"}[kind]
		var info := Label.new()
		info.text = "%s槽 %d（满员 %d/%d）" % [kind_name, state.slot_caps[kind],
			(state.loadout[kind] as Array).size(), state.slot_caps[kind]]
		box.add_child(info)
		var btn := Button.new()
		var cap: int = int((shop.get("slot_unlock", {}) as Dictionary).get("cap", 5))
		if int(state.slot_caps[kind]) >= cap:
			btn.text = "已达上限"
			btn.disabled = true
		else:
			var cost := RunShop.slot_unlock_cost(state, shop)
			btn.text = "%s槽+1（历练 %d）" % [kind_name, cost]
			btn.disabled = state.lianli < cost
			btn.pressed.connect(func() -> void:
				RunShop.unlock_slot(state, shop, kind)
				RunSaver.save_state(state)
				_build())
		box.add_child(btn)
		slots_row.add_child(box)
	v.add_child(slots_row)
	return panel


func _respec_panel(state: RunState) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	var head := Label.new()
	head.text = "洗点（免费）　内力总量 %d：%s" % [state.neili_points,
		"首战锁死——第一胜后解锁" if state.neili_locked else "劲 %d·骨 %d·气 %d" % [
			state.neili["jin"], state.neili["gu"], state.neili["qi"]]]
	v.add_child(head)
	if state.neili_locked:
		return panel
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var pending := {"jin": int(state.neili["jin"]), "gu": int(state.neili["gu"]), "qi": int(state.neili["qi"])}
	for key in ["jin", "gu", "qi"]:
		var cname: String = {"jin": "劲（攻+2/点）", "gu": "骨（防+1/点）", "qi": "气（流转）"}[key]
		var box := VBoxContainer.new()
		var info := Label.new()
		var sync := func() -> void:
			info.text = "%s：%d" % [cname, pending[key]]
		sync.call()
		box.add_child(info)
		var btns := HBoxContainer.new()
		for delta in [-1, 1]:
			var b := Button.new()
			b.text = ("＋" if delta > 0 else "－")
			b.custom_minimum_size = Vector2(36, 32)
			b.pressed.connect(func() -> void:
				pending[key] = maxi(pending[key] + delta, 0)
				sync.call())
			btns.add_child(b)
		box.add_child(btns)
		row.add_child(box)
	v.add_child(row)
	var apply := Button.new()
	apply.text = "重排内力"
	apply.pressed.connect(func() -> void:
		if state.alloc_neili(pending["jin"], pending["gu"], pending["qi"]):
			RunSaver.save_state(state)
			_build())
	v.add_child(apply)
	return panel
