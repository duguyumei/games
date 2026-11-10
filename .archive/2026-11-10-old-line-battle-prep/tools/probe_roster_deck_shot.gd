## 一次性画面验收探针（2026-10-28 STS2 整屏页轮；2026-10-29 器灵入口左下轮同步）：
## 器灵页＋卡组页各截一张（DeckViewScreen 制）。断言：左下器灵钮开页、顶栏无器灵钮、
## 渐隐 BorderGradient 原版结构（Cubic＋上下各 5%，黑线病根回归哨）、卡组分组标签、底中计数条。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var run: Dictionary = QI_DATA.default_run()
	run["team"] = [
		{"id": "youming", "equips": ["p4", "", ""], "pdir": 0},
		{"id": "tiansi", "equips": ["", "", ""], "pdir": 0}]
	run["reserve"] = [
		{"id": "qinggu", "equips": ["", "", ""], "pdir": 0, "hp": 20},
		{"id": "jingang", "equips": ["", "", ""], "pdir": 0}]
	var prep: Control = PREP.instantiate()
	prep.run_data = run
	root.add_child(prep)
	for i in 20:
		await process_frame
	# 器灵入口＝出战正上方大钮（2026-10-29 裁定）：锚位底部带＋点按开页；顶栏不得再有器灵钮
	var rbtn: Button = prep.find_child("RosterBtn", false, false) as Button
	if rbtn == null:
		fails.append("器灵大钮缺失（出战正上方）")
	elif rbtn.get_anchor(SIDE_TOP) < 0.8:
		fails.append("器灵钮不在底部带（anchor_top=%.3f）" % rbtn.get_anchor(SIDE_TOP))
	else:
		rbtn.pressed.emit()
	var top: HBoxContainer = prep.find_child("TopBar", false, false) as HBoxContainer
	if top != null:
		for c in top.get_children():
			if c is Button and String((c as Button).text) == "器灵":
				fails.append("顶栏仍有器灵钮（应只留左下入口）")
	for i in 8:
		await process_frame
	var rp: Control = prep.find_child("RosterPage", false, false)
	if rp == null:
		fails.append("器灵页未开")
	else:
		_eqt("器灵页底中计数条", "true", str(_page_bottom_has(rp, "上场 2/7")))
		_check_fade(rp)
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.roster_view.png")
	if rp != null:
		rp.queue_free()
	for i in 3:
		await process_frame
	prep._open_deck_view()
	for i in 8:
		await process_frame
	var dp: Control = prep.find_child("DeckPage", false, false)
	if dp == null:
		fails.append("卡组页未开")
	else:
		var group_labels := 0
		for l in dp.find_children("*", "Label", true, false):
			if String((l as Label).text).begins_with("「"):
				group_labels += 1
		if group_labels < 2:
			fails.append("按器灵分组标签不足（得 %d）" % group_labels)
		_eqt("卡组页底中计数条", "true", str(_page_bottom_has(dp, "当前卡组")))
		_check_fade(dp)
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.deck_view.png")
	print("ROSTER_DECK_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	quit(1 if fails.size() > 0 else 0)

## 渐隐结构＝BorderGradient 原版（Cubic＋offsets 0/.05/.95/1）；回归 CONSTANT 即黑线病根回潮
func _check_fade(page: Control) -> void:
	var tr: TextureRect = null
	for c in page.find_children("*", "TextureRect", true, false):
		var t: TextureRect = c as TextureRect
		if t.texture is GradientTexture2D:
			tr = t
			break
	if tr == null:
		fails.append("%s 无渐隐纹理" % String(page.name))
		return
	var g: Gradient = (tr.texture as GradientTexture2D).gradient
	if g.interpolation_mode != Gradient.GRADIENT_INTERPOLATE_CUBIC:
		fails.append("%s 渐隐非 Cubic（黑线病根回归）" % String(page.name))
	elif absf(g.offsets[1] - 0.05) > 0.001 or absf(g.offsets[2] - 0.95) > 0.001:
		fails.append("%s 渐隐带非上下各 5%%" % String(page.name))

func _page_bottom_has(page: Control, needle: String) -> bool:
	for pc in page.get_children():
		if pc is PanelContainer:
			for l in pc.find_children("*", "Label", true, false):
				if needle in String((l as Label).text):
					return true
	return false

func _eqt(tag: String, want: String, got: String) -> void:
	if got != want:
		fails.append("%s（得「%s」要「%s」）" % [tag, got, want])
