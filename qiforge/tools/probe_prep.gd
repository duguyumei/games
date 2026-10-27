## 备战舱几何探针（UI实施 §9 v0.12 定稿对照；跑法＝非无头：godot --path . --script res://qiforge/tools/probe_prep.gd）
## 卡尺寸＝工厂动态推导（2026-10-27 起 QiCardStyle 唯一基准 300×422×场合系数，不再硬编码三档实物值）
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QICARD := preload("res://qiforge/QiCardStyle.gd")

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
