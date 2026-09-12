extends Node
# 单次点击装配流验收（v1 九门通用功法，功法与手牌从沙盒数据动态选取）：
# 1) 无预选直接点功法 → 自动补齐 → 直接待确认（准备槽）
# 2) 预选一颗珠点功法 → 带入+围绕它补齐 → 待确认
# 3) 预选凑不出的珠点功法 → 提示 + 保持装配态
# 4) 装配态点掉那颗珠 → 重点功法 → 重试成功 → 确认发动

func _ready() -> void:
	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	if main.combat == null:
		print("FAIL: 战斗未初始化")
		get_tree().quit()
		return

	var fails: Array[String] = []
	var tech: TechniqueBar = main.get_node("Center/Column/TechLayer")
	var hand: HandBar = main.get_node("Center/Column/HandLayer")
	var panel: FighterPanel = main.get_node("Center/Column/Stage/PlayerPanel")
	var confirm: Button = main.get_node("Center/Column/Stage/CenterZone/Buttons/ConfirmButton")
	var cancel: Button = main.get_node("Center/Column/Stage/CenterZone/Buttons/CancelButton")
	var pass_btn: Button = main.get_node("Center/Column/Stage/CenterZone/Buttons/PassButton")
	var close_btn: Button = main.get_node("Center/Column/Stage/CenterZone/Buttons/BreatheButton")
	var meld: Label = main.get_node("Center/Column/HandLayer/MeldInfo")

	# 主角功法：非蓄力、当前手牌能凑出的第一门（沙盒种子固定，选取确定）
	var fighter: FighterState = main.combat.player
	var tech_id := ""
	for tid in fighter.techniques:
		if int(TechniqueResolver.data_for(str(tid)).get("charge", 0)) > 0:
			continue
		if not TechniqueResolver.find_legal_selection(str(tid), fighter.hand, fighter).is_empty():
			tech_id = str(tid)
			break
	if tech_id.is_empty():
		print("FAIL: 沙盒手牌凑不出任何非蓄力功法")
		get_tree().quit()
		return
	var legal := TechniqueResolver.find_legal_selection(tech_id, fighter.hand, fighter)
	var slot_total := legal.size()

	var card: Control = tech._cards.get(tech_id)
	if card == null:
		print("FAIL: %s 卡未找到" % tech_id)
		get_tree().quit()
		return

	# --- 0) 按钮组互换：未装配＝[调息][提气]，装配＝[确认][取消]（C-018/D-063） ---
	if not pass_btn.visible or not close_btn.visible or confirm.visible or cancel.visible:
		fails.append("[0] 未装配时应显示[调息][提气]、隐藏[确认][取消]")

	# --- 1) 无预选：点一次功法 → 智能补齐 → 直接待确认 ---
	await _click_async(_center_of(card))
	await get_tree().process_frame
	if main.armed_technique != tech_id or main.selected_indices.size() != slot_total:
		fails.append("[1] 单击未完成装配补齐（armed='%s' selected=%s 期望%d张）" % [main.armed_technique, main.selected_indices, slot_total])
	if not panel.show_intent or panel.intent_name != tech_id:
		fails.append("[1] 准备槽未显示（%s）" % panel.intent_name)
	if confirm.disabled:
		fails.append("[1] 装配完成但确认不可用")
	# 装配中，手牌凑不出的功法必须保持压灰（不因选中功法而"解锁"）
	var blocked_id := _blocked_technique(main)
	var blocked_card: TechniqueCard = tech._cards.get(blocked_id) if not blocked_id.is_empty() else null
	if blocked_card != null and blocked_card.modulate == Color.WHITE:
		fails.append("[1.5] 装配中缺牌型的%s不应恢复可选态" % blocked_id)
	print("[1] 单击装配：%s selected=%s 准备槽='%s' 确认可用=%s 压灰检查=%s（%s）" % [
		tech_id, main.selected_indices, panel.intent_name, not confirm.disabled,
		blocked_id if blocked_id.is_empty() else "有", blocked_id])
	if not confirm.visible or not cancel.visible or pass_btn.visible or close_btn.visible:
		fails.append("[1] 装配后应显示[确认][取消]、隐藏[调息][提气]")

	# --- 2) 取消，预选一颗可参与的珠再点功法 → 带入并围绕它补齐 ---
	main._cancel_pending()
	await get_tree().process_frame
	if not pass_btn.visible or not close_btn.visible or confirm.visible or cancel.visible:
		fails.append("[2] 取消后应回到[调息][提气]")
	var anchor: QiCard = legal[0]
	var anchor_index: int = fighter.hand.find(anchor)
	await _click_async(_center_of(hand._runtime_orbs[anchor_index]))
	await get_tree().process_frame
	await _click_async(_center_of(card))
	await get_tree().process_frame
	if not main.selected_indices.has(anchor_index) or main.selected_indices.size() != slot_total:
		fails.append("[2] 未围绕已选珠补齐（selected=%s 期望含%d共%d张）" % [main.selected_indices, anchor_index, slot_total])
	print("[2] 带入补齐：selected=%s（含预选珠%d）" % [main.selected_indices, anchor_index])

	# --- 3) 取消，预选凑不出的珠点功法 → 提示 + 保持装配态 ---
	main._cancel_pending()
	await get_tree().process_frame
	for idx in main.selected_indices.duplicate():
		main._on_card_clicked(idx)
	await get_tree().process_frame
	var bad_index := _unusable_card_index(main, tech_id)
	if bad_index < 0:
		print("[3] 当前手牌每颗珠都能参与%s，跳过反例测试" % tech_id)
	else:
		await _click_async(_center_of(hand._runtime_orbs[bad_index]))
		await get_tree().process_frame
		await _click_async(_center_of(card))
		await get_tree().process_frame
		var warned := false
		for line in main.log_lines.slice(-3):
			if String(line).begins_with("提示：无法以当前已选真气凑成"):
				warned = true
		if not warned:
			fails.append("[3] 凑不成未提示（日志尾=%s）" % str(main.log_lines.slice(-3)))
		if main.armed_technique != tech_id or not main.selected_indices.has(bad_index):
			fails.append("[3] 装配态未保持（armed='%s' selected=%s）" % [main.armed_technique, main.selected_indices])
		if not meld.text.begins_with("装配中"):
			fails.append("[3] 失败后信息行应显示装配中（实际='%s'）" % meld.text)
		if not confirm.disabled:
			fails.append("[3] 未凑成条件时确认应不可用")
		print("[3] 失败提示：armed='%s' selected=%s 信息行='%s'" % [main.armed_technique, main.selected_indices, meld.text])

		# --- 4) 装配态点掉凑不出的珠 → 重点功法 → 重试成功 → 确认发动 ---
		await _click_async(_center_of(hand._runtime_orbs[bad_index]))
		await get_tree().process_frame
		await _click_async(_center_of(card))
		await get_tree().process_frame
		if main.selected_indices.size() != slot_total or confirm.disabled:
			fails.append("[4] 重试装配未成功（selected=%s confirm_disabled=%s）" % [main.selected_indices, confirm.disabled])
		else:
			await _click_async(_center_of(confirm))
			await get_tree().process_frame
			await get_tree().process_frame
			if main.armed_technique != "":
				fails.append("[4] 确认后装配未清空")
			print("[4] 重试+发动：armed='' 最新日志='%s'" % main.log_lines.back())

	if fails.is_empty():
		print("PASS: 单次点击装配流全部通过")
	else:
		for f in fails:
			print("FAIL: " + f)
	get_tree().quit()

# 找一门当前压灰（缺牌型/冷却）的功法，没有则返回空串
func _blocked_technique(main) -> String:
	for tid in main.combat.player.techniques:
		if not main._technique_block_reason(str(tid)).is_empty():
			return str(tid)
	return ""

# 找一颗无法参与该功法任何合法选择的珠（没有则返回 -1）
func _unusable_card_index(main, tech_id: String) -> int:
	var fighter: FighterState = main.combat.player
	for index in range(fighter.hand.size()):
		var containing := TechniqueResolver.find_legal_selection_containing(
			tech_id, fighter.hand, [fighter.hand[index]], fighter)
		if containing.is_empty():
			return index
	return -1

func _center_of(node: Control) -> Vector2:
	var rect := node.get_global_rect()
	return rect.position + rect.size * 0.5

func _click_async(pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	get_viewport().push_input(release, true)
	await get_tree().process_frame
