## 备战舱几何探针（2026-10-28 槽位制退役改版：自动居中＋器灵/卡组弹窗；UI实施对照）
## 卡尺寸＝工厂动态推导（QiCardStyle 唯一基准 300×422×场合系数）
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QIDIALOG := preload("res://qiforge/QiDialog.gd")
const QIPREFS := preload("res://qiforge/QiPrefs.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = PREP.instantiate()
	root.add_child(screen)
	for i in 25:
		await process_frame

	var panel: Control = screen.get_node("SystemPanel")
	_rect_near(panel, Rect2(69.5, 88.0, 1781.0, 303.5), 10.0, "系统带整体（2026-10-27 加高容 170 方卡；对齐器灵列±14）")

	var rf: Control = screen.get_node("SystemPanel/SystemBody/SystemHead/ReflashButton")
	_eqt("刷新起步价 1 铜（2026-10-29 递增制）", "刷新 ·1铜", String((rf as Button).text))
	if rf.global_position.x + rf.size.x < 1600.0:
		fails.append("刷新钮应靠右（实测右缘 %.0f < 1600）" % (rf.global_position.x + rf.size.x))
	if rf.global_position.y > panel.global_position.y + 80.0:
		fails.append("刷新钮应在系统带头行内")

	# 出货率行（2026-10-29 五档制＋五色）：前缀＋五分色 Label 拼行、含 Lv2 档、系统 Lv2 起步档率 40/40/15/4/1
	var odds_txt := ""
	var odds_ok := false
	var odds_el := screen.find_child("OddsRow", true, false)
	if odds_el is HBoxContainer:
		var segs: Array = []
		for c in (odds_el as HBoxContainer).get_children():
			if c is Label:
				segs.push_back(String((c as Label).text))
		odds_txt = "".join(PackedStringArray(segs))
		odds_ok = (odds_el as HBoxContainer).get_child_count() >= 6
	_eqt("出货率行＝前缀＋五分色 Label（HBox≥6 子）", "true", str(odds_ok))
	_eqt("出货率含 Lv2 档（五档制）", "true", str("Lv2" in odds_txt))
	_eqt("出货率五段齐（Lv1~Lv5）", "true",
		str(["Lv1", "Lv2", "Lv3", "Lv4", "Lv5"].all(func(k: String) -> bool: return k in odds_txt)))
	_eqt("起步档率 70/20/5/4/1（开局 Lv1，2026-10-29 再裁）", "true",
		str("Lv1 70%" in odds_txt and "Lv5 1%" in odds_txt))

	var goods := screen.get_node("SystemPanel/SystemBody/GoodsRow") as HBoxContainer
	_eq(goods.get_child_count(), 6, "货架 6 位")
	if goods.get_child(0).size.y < 100.0:
		fails.append("配件小卡高度异常（%.0f）" % goods.get_child(0).size.y)
	var g0: Control = goods.get_child(0)
	_near(g0.size.x, 170.0, 6.0, "货位宽 170（正方形制）")
	var part0: Panel = g0.get_child(0) as Panel
	if part0 == null:
		fails.append("货位首子件应为面板")
	else:
		_near(part0.size.y, 170.0, 6.0, "货位面板高 170（正方形制）")
	# 配件名＝裸名＋品阶色（2026-10-29 用户裁定：去「配件 ·」前缀与 Lv 品阶徽）
	var nm_lbls: Array = part0.find_children("*", "Label", true, false)
	if nm_lbls.is_empty():
		fails.append("货位内无 Label")
	else:
		var nm0 := nm_lbls[0] as Label
		if "配件 ·" in String(nm0.text):
			fails.append("配件名应去「配件 ·」前缀（实测「%s」）" % nm0.text)
		var tier_cols := [Color("e8e2d4"), Color("8fd8b0"), Color("57b8d6"), Color("b48ae0"), Color("ffc94d")]
		if not (nm0.get_theme_color("font_color") in tier_cols):
			fails.append("配件名应按品阶色着色（实测 %s）" % str(nm0.get_theme_color("font_color")))
		var has_lv_badge := false
		for c in nm_lbls:
			if String((c as Label).text).begins_with("Lv"):
				has_lv_badge = true
		if has_lv_badge:
			fails.append("货位名行应无 Lv 品阶徽（颜色已承载品阶）")
	# 底行〔购买｜锁定〕并排（2026-10-29 裁定：锁钮在购买旁，非面板浮层）
	var price0: Button = null
	var lock0: Button = null
	if g0.get_child_count() >= 2 and g0.get_child(1) is HBoxContainer:
		for c in (g0.get_child(1) as HBoxContainer).get_children():
			if c is Button and String((c as Button).name) == "LockButton":
				lock0 = c
			elif c is Button:
				price0 = c
	if price0 == null or lock0 == null:
		fails.append("底行应有购买签＋锁定钮并排（得 price=%s lock=%s）" % [str(price0), str(lock0)])
	# 购后空位制（2026-10-29）：买走货位0 → 空位「已售」无钮；手动刷新补回
	var shelf_arr: Array = screen.get("_shelf")
	if price0 != null and not shelf_arr.is_empty():
		screen.set("_copper", 500)
		screen.call("_on_buy", shelf_arr[0], part0)
		for i in 4:
			await process_frame
		if not (shelf_arr[0] as Dictionary).is_empty():
			fails.append("购后本位应空置（去自动补货，2026-10-29 裁定）")
		var g0b: Control = goods.get_child(0)
		var sold_txt := ""
		for l in (g0b.get_child(0) as Control).find_children("*", "Label", true, false):
			sold_txt += String((l as Label).text)
		_eqt("购后空位显「已售」", "true", str("已售" in sold_txt))
		_eqt("购后空位无钮（购买/锁定皆无）", "true",
			str(g0b.find_children("*", "Button", true, false).is_empty()))
		screen.call("_on_refresh")
		for i in 4:
			await process_frame
		_eqt("刷新补回空位", "true",
			str(not ((screen.get("_shelf") as Array)[0] as Dictionary).is_empty()))

	# —— 编队列（2026-10-28 槽位制退役）：列数＝在场器灵数（默认演示 2），自动居中 ——
	var ps := QICARD.size_of("prep")   # 工厂权威（当前 234×329＝基准 300×422×0.78）
	var row := screen.get_node("CrewRow") as HBoxContainer
	var n0: int = row.get_child_count()
	_eq(n0, 2, "编队列数＝在场器灵数（默认 2，无空槽）")
	var col0 := row.get_child(0) as VBoxContainer
	_eq(col0.get_child_count(), 3, "列三段（名/卡/装备格）")
	var name0 := col0.get_child(0) as Control
	var wrap0 := col0.get_child(1) as Control
	var eq0 := col0.get_child(2) as Control
	if not (name0.global_position.y < wrap0.global_position.y - 2.0):
		fails.append("名字行应在卡上方")
	_near(name0.global_position.y, 440.0, 8.0, "名字行 y≈440")
	_near(wrap0.global_position.y, 484.0, 8.0, "卡顶基准 y≈484")
	_near(wrap0.size.x, ps.x, 3.0, "卡宽（工厂 prep 档）")
	_near(wrap0.size.y, ps.y, 3.0, "卡高（工厂 prep 档）")
	_near(wrap0.global_position.x, (1920.0 - (float(n0) * ps.x + float(n0 - 1) * 18.0)) * 0.5,
		12.0, "首列 x（n 张自动居中推导）")
	if eq0.global_position.y < wrap0.global_position.y + ps.y - 24.0:
		fails.append("装备格应在卡下方（实测 %.0f < %.0f）" % [eq0.global_position.y, wrap0.global_position.y + ps.y - 24.0])
	_eq(eq0.get_child_count(), 3, "装备格 3 位")
	_near(eq0.get_child(0).size.x, 60.0, 5.0, "装备格宽 60")

	# —— 器灵入口＝出战正上方大钮（2026-10-29 二挪，250×70 避满编装备格底 866px）；卡组留顶栏；后备落区已退役 ——
	var rbtn: Control = screen.find_child("RosterBtn", true, false)
	var dbtn: Control = screen.find_child("DeckBtn", true, false)
	if rbtn != null and not (rbtn.get_anchor(SIDE_TOP) >= 0.79 and rbtn.get_anchor(SIDE_TOP) <= 0.82):
		fails.append("器灵钮应在出战正上方（anchor_top=%.3f 应 0.79~0.82）" % rbtn.get_anchor(SIDE_TOP))
	_eqt("器灵钮文案", "器 灵", String(rbtn.text) if rbtn != null else "缺钮")
	_eqt("卡组钮文案", "卡组", String(dbtn.text) if dbtn != null else "缺钮")
	if screen.find_child("ReserveZone", false, false) != null:
		fails.append("后备落区应已退役（仍找到 ReserveZone）")

	# —— 装卸血件耐久联动（2026-10-29 用户裁定：±stats.hp 同步当前耐久；存活最低 1；阵亡保持 0） ——
	var dm := {"id": "youming", "equips": ["p4", "", ""], "pdir": 0, "hp": 54}
	dm["equips"][0] = ""
	QI_DATA.plugin_hp_shift(dm, "p4", false)
	_eq(int(dm["hp"]), 34, "卸血件＝当前耐久同扣（54−20）")
	_eq(QI_DATA.mhp_of(dm), 34, "卸后 mhp 回落（快照反锁之反证）")
	dm["equips"][0] = "p4"
	QI_DATA.plugin_hp_shift(dm, "p4", true)
	_eq(int(dm["hp"]), 54, "装血件＝当前耐久同加（34+20）")
	_eq(QI_DATA.mhp_of(dm), 54, "装后 mhp")
	var dm2 := {"id": "youming", "equips": ["p4", "", ""], "pdir": 0, "hp": 20}
	dm2["equips"][0] = ""
	QI_DATA.plugin_hp_shift(dm2, "p4", false)
	_eq(int(dm2["hp"]), 1, "卸血件不够降最低 1（20−20→1）")
	dm2["equips"][0] = "p4"
	QI_DATA.plugin_hp_shift(dm2, "p4", true)
	_eq(int(dm2["hp"]), 21, "降 1 后重装＝1+20")
	var dm3 := {"id": "youming", "equips": ["", "", ""], "pdir": 0, "hp": 0}
	dm3["equips"][0] = "p4"
	QI_DATA.plugin_hp_shift(dm3, "p4", true)
	_eq(int(dm3["hp"]), 0, "阵亡装血件当前耐久保持 0（复活只走回复通道）")
	_eq(QI_DATA.mhp_of(dm3), 54, "阵亡者 mhp 照常随件变动")

	# —— 名字行耐久现算（活查询实时连锁：装/卸后重画即变，反快照） ——
	var crew0: Dictionary = screen._crew[0]["_member"]
	crew0["equips"][0] = "p4"
	QI_DATA.plugin_hp_shift(crew0, "p4", true)
	screen._rebuild_crew_cols()
	for i in 2:
		await process_frame
	var name_lbl0: Label = screen.get_node("CrewRow/CrewCol0").get_child(0).get_child(0) as Label
	if not ("54/54" in String(name_lbl0.text)):
		fails.append("装血件后名字行应显 54/54（实测「%s」）" % name_lbl0.text)
	crew0["equips"][0] = ""
	QI_DATA.plugin_hp_shift(crew0, "p4", false)
	screen._rebuild_crew_cols()
	for i in 2:
		await process_frame
	name_lbl0 = screen.get_node("CrewRow/CrewCol0").get_child(0).get_child(0) as Label   # rebuild 后旧列已释放，重取引用
	if not ("34/34" in String(name_lbl0.text)):
		fails.append("卸血件后名字行应显 34/34（实测「%s」）" % name_lbl0.text)

	# —— heal 操作位掷货不崩（2026-10-29 修：heal 无 sid 掉功法分支＝opt["sid"] 崩之真凶） ——
	screen._crew[0]["_member"]["hp"] = 10   # 造伤员→heal 池非空；_draw_op 掷货 20 次走全 kind 分支
	var op_kinds_seen := {}
	for i in 20:
		var d_op: Dictionary = screen._draw_op()
		if not String(d_op.get("desc", "")).is_empty():
			op_kinds_seen[String(d_op.get("kind", ""))] = true
	if op_kinds_seen.is_empty():
		fails.append("操作位掷货 desc 全空（分支异常）")

	# —— 阵亡战后自动入未上场（2026-10-29 用户裁定：离场语义全套） ——
	var dr := QI_DATA.default_run()
	dr["team"][0]["hp"] = 0
	dr["team"][0]["equips"] = ["p4", "", ""]
	QI_DATA.apply_team_out(dr, [{"id": "youming", "hp": 0}, {"id": "tiansi", "hp": 48}])
	_eq(dr["team"].size(), 1, "阵亡战后自动离场（team 剩 1）")
	_eq(dr["reserve"].size(), 1, "阵亡入未上场池")
	_eqt("入池对象", "youming", String(dr["reserve"][0]["id"]))
	_eq(dr["bag"].size(), 1, "配件离队自动卸回包（p4）")
	_eq(dr["deck"].size(), 4, "功法随档移除（8−4）")
	_eq(int(dr["reserve"][0]["hp"]), 0, "入池保持 0 血（复活走回复通道）")

	var lv: Control = screen.get_node("SystemPanel/SystemBody/SystemHead/LvUpButton")
	if not ("系统 Lv1" in lv.text and "升级" in lv.text):
		fails.append("Lv 徽应与升级合并为一件（实测文案：%s）" % lv.text)
	var go: Control = screen.get_node("GoButton")
	_near(go.global_position.x, 1651.0, 14.0, "出战 x≈1651")
	_near(go.global_position.y, 957.0, 10.0, "出战 y≈957")
	_near(go.size.x, 250.0, 12.0, "出战宽 250")

	# —— 回归段一：插件跟随（成员引用制）＋离场/换位（紧凑序）＋离场卸件 ——
	var run2: Dictionary = QI_DATA.default_run()
	run2["team"] = [
		{"id": "youming", "equips": ["", "", ""], "pdir": 0},
		{"id": "tiansi", "equips": ["p4", "", ""], "pdir": 0},
		{"id": "qinggu", "equips": ["", "", ""], "pdir": 0}]
	var prep2: Control = PREP.instantiate()
	prep2.run_data = run2
	root.add_child(prep2)
	for i in 15:
		await process_frame
	var pname: String = String(QI_DATA.ACCESSORIES["p4"]["name"])
	var row2: Control = prep2.get_node("CrewRow")
	var eqtxt := func(col_i: int) -> String:
		var colx := row2.get_child(col_i) as VBoxContainer
		return String((colx.get_child(2).get_child(0) as Button).text)
	_eq(row2.get_child_count(), 3, "三件在场＝三列")
	_eqt("起手：天丝（列1）带插件4", pname, eqtxt.call(1))
	prep2._bench_member(run2["team"][0])   # 幽冥离场 → [天丝,青蛊]
	for i in 8:
		await process_frame
	_eq(row2.get_child_count(), 2, "离场后两列（无空槽补位）")
	_eqt("离场后：天丝列0，插件跟随", pname, eqtxt.call(0))
	_eqt("青蛊列1 无插件", "空", eqtxt.call(1))
	prep2._on_swap(0, 1)   # 卡拖卡换位（保留制）：[青蛊,天丝]
	for i in 8:
		await process_frame
	_eqt("换位后：天丝列1，插件跟随", pname, eqtxt.call(1))
	_eqt("换位后：青蛊列0 无插件", "空", eqtxt.call(0))
	_eqt("数据层：run.team[1]=天丝 带插件4", pname,
		String(QI_DATA.ACCESSORIES[String(run2["team"][1]["equips"][0])]["name"]))
	var bag_n0: int = (run2.get("bag", []) as Array).count("p4")
	prep2._bench_member(run2["team"][1])   # 天丝离场＝自动卸全部插件回背包
	for i in 8:
		await process_frame
	_eqt("天丝离场：插件4 卸回背包", str(bag_n0 + 1),
		str((run2.get("bag", []) as Array).count("p4")))
	var mres: Dictionary = run2["reserve"][run2["reserve"].size() - 1]
	var eq_all_empty := true
	for x in mres["equips"]:
		if String(x) != "":
			eq_all_empty = false
	_eqt("离场档插件位已清空", "true", str(eq_all_empty))
	var rentry: Dictionary = prep2._reserve[prep2._reserve.size() - 1]
	# 2026-10-29 反锁定制：entry 快照字段（equips/hp/mhp/attrs）整体退役——显示点现算，无残影可言
	_eqt("离场条目已无 equips/hp/mhp/attrs 快照字段", "true",
		str(not (rentry.has("equips") or rentry.has("hp") or rentry.has("mhp") or rentry.has("attrs"))))

	# —— 回归段二：器灵/卡组＝STS2 式整屏页（页互斥→开一关一）＋装备窗无遮罩 ——
	prep2._open_roster()
	for i in 6:
		await process_frame
	_eqt("器灵整屏页打开（RosterPage 在树）", "true",
		str(prep2.find_child("RosterPage", false, false) != null))
	(prep2.get_node("RosterPage") as Control).queue_free()
	for i in 3:
		await process_frame
	prep2._open_deck_view()
	for i in 6:
		await process_frame
	_eqt("卡组整屏页打开（DeckPage 在树）", "true",
		str(prep2.find_child("DeckPage", false, false) != null))
	_eqt("卡组页顶排序带在树", "true",
		str(prep2.get_node("DeckPage").get_child_count() >= 6))
	(prep2.get_node("DeckPage") as Control).queue_free()
	for i in 3:
		await process_frame
	prep2._open_equip(run2["team"][0], 0)
	for i in 6:
		await process_frame
	var scrim2: ColorRect = null
	for c in prep2.get_children():
		if c is ColorRect and String(c.name) == "QiScrim":
			scrim2 = c   # 取最后一个同名 scrim＝最新窗
	_eqt("装备窗无背板遮罩（alpha=0）", "true",
		str(scrim2 != null and scrim2.color.a < 0.05))
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_viewport().get_texture().get_image().save_png(
			"/Users/cc/Documents/qi-forge-2/.prep_equips_fix.png")
	await _close_open_box()

	# —— 回归段三：设置弹窗（2026-10-29 战斗音效入设置轮）——
	var sfx_before: bool = QIPREFS.battle_sfx()
	var setbtn: Button = null
	for b in prep2.find_children("*", "Button", true, false):
		if String((b as Button).text) == "设置":
			setbtn = b
			break
	_eqt("顶栏设置钮存在", "true", str(setbtn != null))
	if setbtn != null:
		setbtn.pressed.emit()
		for i in 6:
			await process_frame
		var sbox: Control = QIDIALOG._open_box
		_eqt("设置弹窗打开（QiDialogBox 互斥位）", "true",
			str(sbox != null and is_instance_valid(sbox)))
		var tgbtn: Button = null
		if sbox != null and is_instance_valid(sbox):
			for b in sbox.find_children("*", "Button", true, false):
				var bb := b as Button
				if bb.toggle_mode and "战斗音效" in String(bb.text):
					tgbtn = bb
					break
		_eqt("设置弹窗含战斗音效开关（深面 toggle 钮）", "true", str(tgbtn != null))
		var resopt: OptionButton = null
		var fsbtn: Button = null
		var rzbtn: Button = null
		if sbox != null and is_instance_valid(sbox):
			for c in sbox.find_children("*", "OptionButton", true, false):
				resopt = c as OptionButton
				break
			for c in sbox.find_children("*", "Button", true, false):
				var cb := c as Button
				if not cb.toggle_mode:
					continue
				if "全屏" in String(cb.text):
					fsbtn = cb
				elif "窗口可调" in String(cb.text):
					rzbtn = cb
		_eqt("显示段分辨率下拉存在", "true", str(resopt != null))
		_eqt("分辨率档位数＝4（16:9 白名单）", "true",
			str(resopt != null and resopt.item_count == QIPREFS.RESOLUTIONS.size()))
		_eqt("显示段全屏/窗口可调开关存在", "true",
			str(fsbtn != null and rzbtn != null))
		if tgbtn != null:
			tgbtn.button_pressed = not sfx_before
			_eqt("开关即时落偏好（battle_sfx 翻转）", "true",
				str(QIPREFS.battle_sfx() == (not sfx_before)))
			_eqt("开关钮文案跟随态", "true",
				str(("音效：开" in String(tgbtn.text)) == (not sfx_before)))
			tgbtn.button_pressed = sfx_before   # 还原用户原值
			_eqt("开关还原", "true", str(QIPREFS.battle_sfx() == sfx_before))
		if DisplayServer.get_name() != "headless":
			tgbtn.button_pressed = not sfx_before   # 截图留开着态，关前还原
			await process_frame
			root.get_viewport().get_texture().get_image().save_png(
				"/Users/cc/Documents/qi-forge-2/.prefs_settings.png")
			tgbtn.button_pressed = sfx_before
		await _close_open_box()
	prep2.queue_free()
	for i in 5:
		await process_frame

	print("PREP_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("PREP_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

func _close_open_box() -> void:
	var b: Control = QIDIALOG._open_box
	if b != null and is_instance_valid(b):
		b.queue_free()
	for i in 3:
		await process_frame

func _rect_near(c: Control, want: Rect2, tol: float, tag: String) -> void:
	var got := Rect2(c.global_position, c.size)
	if abs(got.position.x - want.position.x) > tol or abs(got.position.y - want.position.y) > tol \
			or abs(got.size.x - want.size.x) > tol or abs(got.size.y - want.size.y) > tol:
		fails.append("%s 位置/尺寸偏差（得 %s 要 %s 容 %s）" % [tag, got, want, tol])

func _near(v: float, want: float, tol: float, tag: String) -> void:
	if abs(v - want) > tol:
		fails.append("%s 偏差（得 %.1f 要 %.1f 容 %.1f）" % [tag, v, want, tol])

func _eq(v: int, want: int, tag: String) -> void:
	if v != want:
		fails.append("%s 数量错（得 %d 要 %d）" % [tag, v, want])

func _eqt(tag: String, want: String, got: String) -> void:
	if got != want:
		fails.append("%s（得「%s」要「%s」）" % [tag, got, want])
