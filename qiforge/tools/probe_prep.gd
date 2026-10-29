## 备战舱几何探针（UI实施 §9 v0.12 定稿对照；跑法＝非无头：godot --path . --script res://qiforge/tools/probe_prep.gd）
## 卡尺寸＝工厂动态推导（2026-10-27 起 QiCardStyle 唯一基准 300×422×场合系数，不再硬编码三档实物值）
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QICARD := preload("res://qiforge/QiCardStyle.gd")
const QI_DATA := preload("res://qiforge/QiData.gd")
const QISTYLE := preload("res://qiforge/QiStyle.gd")

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
	if rf.global_position.x + rf.size.x < 1600.0:
		fails.append("刷新钮应靠右（实测右缘 %.0f < 1600）" % (rf.global_position.x + rf.size.x))
	if rf.global_position.y > panel.global_position.y + 80.0:
		fails.append("刷新钮应在系统带头行内")

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

	var ps := QICARD.size_of("prep")   # 工厂权威（当前 234×329＝基准 300×422×0.78）
	var row := screen.get_node("CrewRow") as HBoxContainer
	_eq(row.get_child_count(), 7, "编队 7 列")
	# 列 0：名字行→卡→装备格；卡 235×300、基准 y≈484
	var col0 := row.get_child(0) as VBoxContainer
	_eq(col0.get_child_count(), 3, "占用列三段（名/卡/装备格）")
	var name0 := col0.get_child(0) as Control
	var wrap0 := col0.get_child(1) as Control
	var eq0 := col0.get_child(2) as Control
	if not (name0.global_position.y < wrap0.global_position.y - 2.0):
		fails.append("名字行应在卡上方")
	_near(name0.global_position.y, 440.0, 8.0, "名字行 y≈440")
	_near(wrap0.global_position.y, 484.0, 8.0, "卡顶基准 y≈484")
	_near(wrap0.size.x, ps.x, 3.0, "卡宽（工厂 prep 档）")
	_near(wrap0.size.y, ps.y, 3.0, "卡高（工厂 prep 档）")
	_near(wrap0.global_position.x, (1920.0 - (7.0 * ps.x + 6.0 * 18.0)) * 0.5, 12.0, "首列 x（居中推导）")
	if eq0.global_position.y < wrap0.global_position.y + 300.0:
		fails.append("装备格应在卡下方（实测 %.0f < %.0f）" % [eq0.global_position.y, wrap0.global_position.y + 300.0])
	_eq(eq0.get_child_count(), 3, "装备格 3 位")
	_near(eq0.get_child(0).size.x, 60.0, 5.0, "装备格宽 60")
	# 空位（列 3）与真卡同基准（零位移裁定）
	var col3 := row.get_child(3) as VBoxContainer
	var pad := col3.get_child(0) as Control
	var empty := col3.get_child(1) as Control
	_near(pad.size.y, 36.0, 6.0, "空位垫块 36（＋列距 8＝44 垫高）")
	_near(empty.global_position.y, wrap0.global_position.y, 4.0, "空位与真卡同基准（防放置跳位）")
	_near(empty.size.y, ps.y, 3.0, "空位高（工厂 prep 档）")

	var lv: Control = screen.get_node("SystemPanel/SystemBody/SystemHead/LvUpButton")
	if not ("系统 Lv2" in lv.text and "升级" in lv.text):
		fails.append("Lv 徽应与升级合并为一件（实测文案：%s）" % lv.text)
	var go: Control = screen.get_node("GoButton")
	_near(go.global_position.x, 1651.0, 14.0, "出战 x≈1651")
	_near(go.global_position.y, 957.0, 10.0, "出战 y≈957")
	_near(go.size.x, 250.0, 12.0, "出战宽 250")

	# —— 后备落区（2026-10-28 用户裁定：自编队行右上小条移至左下角并放大）——
	var rz: Control = screen.get_node("ReserveZone")
	_rect_near(rz, Rect2(23.0, 912.6, 345.6, 137.2), 6.0, "后备落区左下（锚 0.012/0.845→0.192/0.972）")
	var rpanel: Panel = rz.get_child(0) as Panel
	var rbody: VBoxContainer = rpanel.get_child(0) as VBoxContainer
	_eqt("落区标题", "后备", String((rbody.get_child(0).get_child(0) as Label).text))
	_eqt("落区计数 0/3", "0 / 3", String((rbody.get_child(0).get_child(1) as Label).text))
	_eqt("落区提示文案", "拖器灵至此收起 · 点击开名册", String((rbody.get_child(1) as Label).text))
	if bool(screen.get("_zone_hot")):
		fails.append("落区初始非亮边态")
	screen._set_zone_hot(true)
	var hsb: StyleBoxFlat = rpanel.get_theme_stylebox("panel") as StyleBoxFlat
	if hsb == null or hsb.border_color != QISTYLE.JADE:
		fails.append("亮边态边框应为玉绿（得 %s）" % str(hsb.border_color if hsb != null else "null"))
	screen._set_zone_hot(false)
	# 拖放收后备链路（直调＝真拖 on_drop 同入口）：列0 幽冥收起，计数联动刷新
	screen._on_bench({"drag_data": {"slot": 0}}, null)
	for i in 8:
		await process_frame
	if (screen.get("_crew") as Array)[0] != null:
		fails.append("落区收后备：列0 应已空")
	_eq(int(screen.run_data.get("reserve", []).size()), 1, "落区收后备 reserve=1")
	_eqt("落区计数随收后备刷新 1/3", "1 / 3", String((rbody.get_child(0).get_child(1) as Label).text))
	# —— 落区渲染像素采样（.qi_prep_preview.png＝--qi-shot 产物；先跑截图再跑本探针，缺档跳过）——
	var pv_path := "/Users/cc/Documents/qi-forge-2/.qi_prep_preview.png"
	if FileAccess.file_exists(pv_path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(pv_path)) == OK:
			var border_px: Color = img.get_pixel(int(23.0 + 345.6 * 0.5), 914)
			var bg_px: Color = img.get_pixel(int(23.0 + 345.6 * 0.5), 980)
			if border_px.a < 0.3 or border_px.r < 0.3 or border_px.r < border_px.b * 2.0:
				fails.append("落区上边框像素非琥珀系（得 %s）" % str(border_px))
			if bg_px.r > 0.2 or bg_px.r < 0.03:
				fails.append("落区区内心非暗底（得 %s）" % str(bg_px))

	# —— 装配绑定回归（2026-10-28 修「插件跟槽不跟灵」）：收后备/换位产生空位后，插件跟随原器灵 ——
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
	_eqt("起手：天丝（列1）带插件4", pname, eqtxt.call(1))
	# 收起幽冥（列0 入后备）→ run.team 压缩为 [天丝,青蛊]——旧索引制在此错位（列1 读到青蛊）
	prep2._bench_at(0)
	for i in 8:
		await process_frame
	_eqt("收列0后：天丝仍在列1，插件跟随", pname, eqtxt.call(1))
	_eqt("青蛊列2 无插件", "空", eqtxt.call(2))
	# 换位：天丝(列1) ↔ 空位(列4)
	prep2._on_swap(1, 4)
	for i in 8:
		await process_frame
	_eqt("换位后：天丝列4，插件跟随", pname, eqtxt.call(4))
	_eqt("青蛊列2 仍无插件", "空", eqtxt.call(2))
	_eqt("数据层：run.team[1]=天丝 带插件4", pname,
		String(QI_DATA.ACCESSORIES[String(run2["team"][1]["equips"][0])]["name"]))
	# 入后备＝自动卸下全部插件回背包（2026-10-28 用户裁定）：天丝（列4 带 p4）入后备
	var bag_n0: int = (run2.get("bag", []) as Array).count("p4")
	prep2._bench_at(4)
	for i in 8:
		await process_frame
	_eqt("天丝入后备：插件4 卸回背包", str(bag_n0 + 1),
		str((run2.get("bag", []) as Array).count("p4")))
	var mres: Dictionary = run2["reserve"][run2["reserve"].size() - 1]
	var eq_all_empty := true
	for x in mres["equips"]:
		if String(x) != "":
			eq_all_empty = false
	_eqt("后备档插件位已清空", "true", str(eq_all_empty))
	var rentry: Dictionary = prep2._reserve[prep2._reserve.size() - 1]
	_eqt("后备显示缓存无插件残影", "true",
		str((rentry["equips"] as Array).all(func(x): return String(x) == "")))
	# 装备窗＝无背板遮罩（2026-10-28 用户裁定）：开后 QiScrim alpha 恒 0（输入门保留）
	prep2._open_equip(run2["team"][0], 0)
	for i in 6:
		await process_frame
	var scrim2: ColorRect = prep2.find_child("QiScrim", false, false) as ColorRect
	_eqt("装备窗无背板遮罩（alpha=0）", "true",
		str(scrim2 != null and scrim2.color.a < 0.05))
	if DisplayServer.get_name() != "headless":
		await process_frame
		root.get_viewport().get_texture().get_image().save_png(
			"/Users/cc/Documents/qi-forge-2/.prep_equips_fix.png")
	prep2.queue_free()
	for i in 5:
		await process_frame

	print("PREP_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("PREP_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

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
