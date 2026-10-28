## 升级预览探针（2026-10-27 真卡对照制）：spell_diff 句级断言 ＋ QiUpgradePick 三卡行/被动块
## 实例化尺寸与点选回传。跑法＝非无头：godot --path . --script res://qiforge/tools/probe_upgrade.gd
extends SceneTree

const QI_DATA := preload("res://qiforge/QiData.gd")
const QIUP := preload("res://qiforge/QiUpgradePick.gd")
const QICARD := preload("res://qiforge/QiCardStyle.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	# —— §1 spell_diff 句级断言（灭魂斩·升一：改伤害句/删杀意句/增清杀意出消耗副本句/费用行）——
	var d1: Dictionary = QI_DATA.spell_diff("youming", "miehun", 1)
	_eq("diff·费用变化标记", true, bool(d1["cost_changed"]))
	_eq("diff·换名标记", true, bool(d1["name_changed"]))
	var cls_count := {}
	for l in d1["lines"]:
		cls_count[String(l["cls"])] = int(cls_count.get(String(l["cls"]), 0)) + 1
	_eq("diff·含改（伤害 10→20 句）", true, cls_count.has("mod"))
	_eq("diff·含删（获得杀意句被删）", true, cls_count.has("del"))
	_eq("diff·含增（清杀意出消耗副本句）", true, cls_count.has("add"))
	_eq("diff·费用行居首且为改", "mod", String(d1["lines"][0]["cls"]))
	# —— §2 索敌令·升一：费用不变；标记句同、翻倍句增、回能句改 ——
	var d2: Dictionary = QI_DATA.spell_diff("youming", "suodi", 1)
	_eq("diff·索敌令升一费用不变", false, bool(d2["cost_changed"]))
	var has_same := false
	var has_add2 := false
	for l in d2["lines"]:
		if String(l["cls"]) == "same":
			has_same = true
		if String(l["cls"]) == "add":
			has_add2 = true
	_eq("diff·索敌令标记句原样保留", true, has_same)
	_eq("diff·索敌令翻倍句为新增", true, has_add2)

	# —— §3 三卡行实例化：3 张单位档工厂卡＋点选回传方向 ——
	var holder := Control.new()
	holder.size = Vector2(1100, 500)
	root.add_child(holder)
	var state := {"picked": 0}
	var row: Control = QIUP.spell_dir_row("youming", "miehun",
		func(dir: int) -> void: state["picked"] = dir)
	holder.add_child(row)
	for i in 6:
		await process_frame
	var cards: Array = _find_field_cards(row)
	_eq("三卡行·工厂数量=3", 3, cards.size())
	var field: Vector2 = QICARD.size_of("field")
	if cards.size() == 3:
		_eq("三卡行·卡宽（工厂 field 档）", true, absf(cards[0].size.x - field.x) < 2.0)
		_eq("三卡行·卡高（工厂 field 档）", true, absf(cards[0].size.y - field.y) < 2.0)
		(cards[2] as Button).emit_signal("pressed")
		await process_frame
		_eq("三卡行·点方向二卡回传=2", 2, int(state["picked"]))

	# —— §4 被动块：主卡（含被动原文）＋两方向按钮点选 ——
	var pb: Control = QIUP.passive_dir_block("youming", func(dir: int) -> void: state["picked"] = dir + 10)
	holder.add_child(pb)
	for i in 4:
		await process_frame
	var pcol: Control = pb.get_child(pb.get_child_count() - 1)   # 末位＝方向按钮列
	var dir_btns: Array = []
	for cc in pcol.get_children():
		if cc is Button:
			dir_btns.push_back(cc)
	_eq("被动块·方向按钮=2", 2, dir_btns.size())
	if dir_btns.size() == 2:
		(dir_btns[1] as Button).emit_signal("pressed")
		await process_frame
		_eq("被动块·点方向二回传=12", 12, int(state["picked"]))
	_finish()

func _find_field_cards(node: Node) -> Array:
	var field: Vector2 = QICARD.size_of("field")
	var out: Array = []
	if node is Button and absf(node.size.x - field.x) < 3.0 and absf(node.size.y - field.y) < 3.0:
		out.push_back(node)
	for c in node.get_children():
		out.append_array(_find_field_cards(c))
	return out

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("UPGRADE_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("UPGRADE_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
