## 奖励六类池探针（v0.7）：Boss 保证位／刷新加价／选项应用；商店第 6 位（最右）操作位。
## 跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")
const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	# —— Boss 奖励保证位（组末场＝第 2 场）——
	var screen: Control = SCREEN.instantiate()
	screen.run_data = {"copper": 100,
		"team": [{"id": "youming", "equips": ["", "", ""], "pdir": 0},
			{"id": "tiansi", "equips": ["", "", ""], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 2, "seed": 20261026}
	screen.run_data["deck"] = QI_DATA.build_deck(screen.run_data["team"])
	root.add_child(screen)
	for i in 20:
		await process_frame
	var b: RefCounted = screen.battle
	b.allies[0]["acts"] = 99
	for e in b.enemies:
		if e["alive"]:
			e["hp"] = 1
			b.normal_attack(b.allies[0], e)
	await _wait_dialog(screen)
	var dlg = screen.find_child("QiDialog", true, false)
	if dlg == null:
		fails.append("胜局弹窗未出现")
	else:
		dlg.get_ok_button().pressed.emit()   # 胜利结算 → tree_exited → 奖励
		await _wait_dialog(screen)
		dlg = screen.find_child("QiDialog", true, false)
		if dlg == null:
			fails.append("奖励弹窗未出现")
		else:
			var cells := _option_cells(screen)
			_eq("三选项位", 3, cells.size())
			var head0 := _cell_head(cells[0]) if cells.size() > 0 else ""
			if not ("新增器灵" in head0 and "已升级" in head0):
				fails.append("Boss 保证位应为 新增器灵·已升级（得 %s）" % head0)
			# 刷新：基价＝装备中器灵数 2 → 每刷 +1；Boss 位刷新后仍在
			var copper0 := int(screen.run_data.get("copper", 0))
			var refresh := _find_button_with(screen, "刷新 ·2铜")
			if refresh == null:
				fails.append("刷新钮价格应为 2 铜（装备中器灵 2 件）")
			else:
				refresh.pressed.emit()
				await create_timer(0.3).timeout
				_eq("刷新扣 2 铜", copper0 - 2, int(screen.run_data.get("copper", 0)))
				var cells2 := _option_cells(screen)
				var head1 := _cell_head(cells2[0]) if cells2.size() > 0 else ""
				if not ("新增器灵" in head1 and "已升级" in head1):
					fails.append("刷新后 Boss 保证位仍在（得 %s）" % head1)
				if _find_button_with(screen, "刷新 ·3铜") == null:
					fails.append("刷新后下次价格应为 3 铜")
				# 选保证位（入后备——后备空）→ 收尾弹窗 → 战斗屏自毁
				var btn := _action_button(cells2[0]) if cells2.size() > 0 else null
				if btn == null:
					fails.append("保证位动作钮缺失")
				else:
					btn.pressed.emit()
					await create_timer(0.3).timeout
					_eq("新增器灵入后备（run.reserve=1）", 1, screen.run_data.get("reserve", []).size())
					var res_wid := String(screen.run_data.get("reserve", [{}])[0].get("id", ""))
					_eq("入后备者来自未解锁池（青蛊铃/金刚盾/两仪刀剑）", true,
						res_wid == "qinggu" or res_wid == "jingang" or res_wid == "liangyi")
					_eq("已升级态入后备（pdir 1/2）", true,
						int(screen.run_data.get("reserve", [{}])[0].get("pdir", 0)) in [1, 2])
					await _wait_dialog(screen)
					var fin = screen.find_child("QiDialog", true, false)
					if fin and fin.visible:
						fin.get_ok_button().pressed.emit()
					await create_timer(0.6).timeout
					if is_instance_valid(screen) and screen.is_inside_tree():
						fails.append("收尾后战斗屏应自毁")
	if is_instance_valid(screen):
		screen.queue_free()
	await create_timer(0.2).timeout

	# —— 商店第 6 位（最右）＝操作位 ——
	var prep: Control = PREP.instantiate()
	root.add_child(prep)
	for i in 20:
		await process_frame
	var goods: Container = prep.get_node("SystemPanel/SystemBody/GoodsRow")
	_eq("货架 6 位", 6, goods.get_children().size())
	var op_i := -1
	for i in goods.get_children().size():
		var lbl := _first_label(goods.get_child(i))
		if lbl != null and String(lbl.text).begins_with("操作 ·"):
			op_i = i
	_eq("操作位在第 6 位（最右，索引 5）", 5, op_i)
	prep.queue_free()
	_finish()

func _wait_dialog(screen: Control) -> void:
	for i in 240:
		await process_frame
		var d = screen.find_child("QiDialog", true, false)
		if d and d.visible:
			return

## 选项位＝VBox：类型标 Label ＋ 工厂卡（Button）＋ 动作钮（Button）——取动作钮＝最后一个 Button
func _option_cells(root_node: Node) -> Array:
	var cols: Array = []
	_collect_cols(root_node, cols)
	return cols

func _collect_cols(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is VBoxContainer and _is_option_col(c):
			out.push_back(c)
		_collect_cols(c, out)

func _is_option_col(col: VBoxContainer) -> bool:
	var has_head := false
	var btn_n := 0
	for c in col.get_children():
		if c is Label:
			for kw in ["新增", "升级", "删除", "复制"]:
				if kw in String(c.text):
					has_head = true
		if c is Button:
			btn_n += 1
	return has_head and btn_n >= 2

func _cell_head(col: Control) -> String:
	for c in col.get_children():
		if c is Label:
			return String(c.text)
	return ""

func _action_button(col: Control) -> Button:
	var last: Button = null
	for c in col.get_children():
		if c is Button:
			last = c
	return last

func _first_label(node: Node) -> Label:
	if node is Label:
		return node
	for c in node.get_children():
		var l := _first_label(c)
		if l != null:
			return l
	return null

func _find_button_with(screen: Control, txt: String) -> Button:
	var dlg = screen.find_child("QiDialog", true, false)
	if dlg == null:
		return null
	var stack: Array = [dlg]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and txt in String(n.text):
			return n
		for c in n.get_children():
			stack.push_back(c)
	return null

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("REWARD_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("REWARD_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
