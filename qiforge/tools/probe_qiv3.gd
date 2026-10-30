## QiBattleScreen 几何探针 v3.2（1920×1080；须真窗口跑，非 --headless）。
## 2026-10-27 尺寸制改版：期望值一律取工厂权威 QiCardStyle.size_of（基准 300×422×场合系数）；
## 布局断言按 v0.7 演示局实况（敌 2 卡／手牌 4 张／能量珠=上限 3），不再写死绝对像素锚。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const QICARD := preload("res://qiforge/QiCardStyle.gd")

var fails := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var ps: PackedScene = load("res://qiforge/QiBattleScreen.tscn")
	var scr: Control = ps.instantiate()
	root.add_child(scr)
	await process_frame
	await process_frame
	var vp := root.get_visible_rect().size
	if absf(vp.x - 1920.0) > 2.0 or absf(vp.y - 1080.0) > 2.0:
		print("✗ 视口非 1920×1080：", vp)
		fails += 1

	var field: Vector2 = QICARD.size_of("field")
	var hand: Vector2 = QICARD.size_of("hand")
	var er: HBoxContainer = scr.get_node("EnemyRow")
	var ar: HBoxContainer = scr.get_node("AllyRow")

	# —— 敌排（演示局 G1F1＝2 敌；卡＝工厂单位档）——
	chk("敌排 2 槽（演示局）", er.get_child_count(), 2.0, 0.0)
	var wrap1: Control = er.get_child(0).get_child(1).get_child(0)   # 块制：slot→zone→wrap（2026-10-29）
	var card1: Control = wrap1.get_child(0)
	chk("敌卡宽（工厂 field 档）", card1.size.x, field.x, 1.5)
	chk("敌卡高（工厂 field 档）", card1.size.y, field.y, 1.5)
	chk("敌卡在屏内", 1.0 if card1.global_position.y > 90.0
		and card1.global_position.y + card1.size.y < 480.0 else 0.0, 1.0, 0.0)
	if er.get_child_count() == 2:
		var card2: Control = er.get_child(1).get_child(1).get_child(0).get_child(0)
		var gap: float = card2.global_position.x - (card1.global_position.x + card1.size.x)
		bt("敌卡不重叠且留隙 ≥20（实测 %.0f）" % gap, gap >= 20.0)

	# —— 敌方状态列（VBox 型子件、卡外右侧锚 +12~+32、不出卡底）——
	var stat1: VBoxContainer = null
	for c in wrap1.get_children():
		if c is VBoxContainer and c != card1:
			stat1 = c
			break
	bt("状态列存在", stat1 != null)
	if stat1 != null:
		var off: float = stat1.global_position.x - (card1.global_position.x + card1.size.x)
		bt("状态列在卡右 12±6（实测 %.0f）" % off, absf(off - 12.0) <= 6.0)
		bt("状态列不出卡底", stat1.global_position.y + stat1.size.y
			<= wrap1.global_position.y + wrap1.size.y + 3.0)

	# —— 我排（槽位＝实卡数——空位占位 2026-10-28 用户手改撤除；演示局 2 实卡；
	#    槽子件序 2026-10-28 血条出卡后＝[wrap, STS2 血条, 词条行]）——
	chk("我排槽＝实卡数（演示 2）", ar.get_child_count(), 2.0, 0.0)
	var awrap: Control = ar.get_child(0).get_child(0)
	var acard: Control = awrap.get_child(0)
	chk("我卡尺寸（工厂 field 档）", acard.size.x + acard.size.y * 0.001, field.x + field.y * 0.001, 1.6)
	var aslot: Control = ar.get_child(0)
	var ahpb: Control = aslot.get_child(1)
	var trow: Control = aslot.get_child(2)
	bt("血条紧贴卡下（STS2 制·卡外下方）", ahpb.global_position.y >= acard.global_position.y + acard.size.y - 2.0)
	var tgap: float = trow.global_position.y - (ahpb.global_position.y + ahpb.size.y)
	bt("词条行在血条下（隔 2~30，实测 %.0f）" % tgap, tgap >= 2.0 and tgap <= 30.0)

	# —— 手牌（拖拽件 HandCard*；尺寸＝工厂 hand 档；顶＝75.2% 屏高；底裁出屏）——
	var hands: Array = []
	for c in scr.get_children():
		if c.name.begins_with("HandCard"):
			hands.push_back(c)
	chk("手牌 4 张（出厂抽 4）", hands.size(), 4.0, 0.0)
	if hands.size() == 4:
		var h0: Control = hands[0]
		chk("手牌宽（工厂 hand 档）", h0.size.x, hand.x, 2.0)
		chk("手牌高（工厂 hand 档）", h0.size.y, hand.y, 2.0)
		chk("手牌顶 ≈812（75.2% 屏高）", h0.position.y, vp.y * 0.752, 5.0)
		bt("手牌底裁出屏（底缘动画带）", h0.position.y + h0.size.y > vp.y)
		bt("词条行不与手牌叠（隔 ≥25）", h0.position.y - (trow.global_position.y + 20.0) >= 25.0)

	# —— 能量（2026-10-28 STS2 宝珠制：单珠大数字＋/上限角标；旧 pip 竖栈退役）——
	var eorb: Control = scr.find_child("EnergyOrb", false, false)
	bt("能量宝珠存在", eorb != null)
	if eorb != null:
		var enlbl: Label = eorb.get_meta("num") as Label
		chk("能量数字=3（Lv2 上限）", enlbl.text.to_float(), 3.0, 0.0)

	print("QIV3_FAILS=", fails)
	quit(1 if fails > 0 else 0)

func chk(label: String, got: float, want: float, tol: float) -> void:
	var ok: bool = absf(got - want) <= tol
	if not ok:
		fails += 1
	print("%s %s：got=%s want=%s±%s" % ["FAIL" if not ok else "OK", label, got, want, tol])

func bt(label: String, cond: bool) -> void:
	if not cond:
		fails += 1
	print("%s %s" % ["FAIL" if not cond else "OK", label])
