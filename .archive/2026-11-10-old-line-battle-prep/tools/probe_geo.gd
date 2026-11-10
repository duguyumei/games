## 几何验收探针：实例化 QiBattleScreen，量区块矩形，报越界/重叠。dev 件。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var scene: PackedScene = load("res://qiforge/QiBattleScreen.tscn")
	var node: Control = scene.instantiate()
	root.add_child(node)
	for i in 6:
		await process_frame
	var vp := Vector2(1920, 1080)
	var issues: Array = []
	var cards: Array = []
	var resbar: Control = null
	for c in node.get_children():
		if c is Button and c.text == "结束阶段":
			_check(c, "结束按钮", vp, issues)
		if c is VBoxContainer and c.position.y > 300 and c.position.y < 500 and c.get_child_count() >= 4:
			resbar = c  # 左侧钮组 y=450；资源条是 HBox——再单独认
	for c in node.get_children():
		if c is HBoxContainer and absf(c.position.x - 631.0) < 2.0:
			resbar = c
	# 手牌卡（拖拽件 HandCard*；尺寸＝工厂 hand 档）
	var hs: Vector2 = load("res://qiforge/QiCardStyle.gd").size_of("hand")
	for c in node.get_children():
		if c.name.begins_with("HandCard") and absf(c.size.x - hs.x) < 3.0 and absf(c.size.y - hs.y) < 3.0:
			cards.push_back(c)
	_check_list(cards, "手牌卡", vp, issues)
	if resbar:
		_check(resbar, "资源条", vp, issues)
		var rr: Rect2 = _global_rect(resbar)
		for i in cards.size():
			var cr: Rect2 = _global_rect(cards[i])
			if cr.intersects(rr):
				issues.append("资源条与手牌卡#%d 重叠（卡底=%.0f 资源条顶=%.0f）" % [i, cr.end.y, rr.position.y])
	print("CARD_N=", cards.size())
	for i in cards.size():
		var cr: Rect2 = _global_rect(cards[i])
		print("CARD_%d y=%.0f..%.0f x=%.0f..%.0f" % [i, cr.position.y, cr.end.y, cr.position.x, cr.end.x])
	if resbar:
		var rr: Rect2 = _global_rect(resbar)
		print("RESBAR y=%.0f..%.0f x=%.0f..%.0f" % [rr.position.y, rr.end.y, rr.position.x, rr.end.x])
	print("GEO_ISSUES=%d" % issues.size())
	for s in issues:
		print("ISSUE: " + s)
	print("GEO_DONE")
	quit(0)

func _global_rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)

func _check(c: Control, nm: String, vp: Vector2, issues: Array) -> void:
	var r := _global_rect(c)
	if r.position.x < 0 or r.position.y < 0 or r.end.x > vp.x or r.end.y > vp.y:
		issues.append("%s 越界 %s" % [nm, str(r)])

func _check_list(list: Array, nm: String, vp: Vector2, issues: Array) -> void:
	for c in list:
		_check(c, nm, vp, issues)
