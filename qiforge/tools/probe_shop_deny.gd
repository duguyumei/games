## 商店买不起反馈探针（2026-10-27 裁定＝STS2 制）：铜钱不足时货位正弦摇摆 ±10px/0.4s
## 后归位、钱袋不动、货不消耗；探针环境（-s 无 autoload）下音效静默跳过不崩。
## 跑法＝非无头：godot --path . --script res://qiforge/tools/probe_shop_deny.gd
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const PREP := preload("res://qiforge/QiPrepBay.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = PREP.instantiate()
	root.add_child(screen)
	for i in 25:
		await process_frame
	screen.set("_copper", 1)
	var shelf: Array = screen.get("_shelf")
	if shelf.is_empty():
		fails.append("货架为空（前置失败）")
		_finish()
		return
	var goods := screen.get_node("SystemPanel/SystemBody/GoodsRow")
	var part: Control = goods.get_child(0).get_child(0)
	var base_x := part.position.x
	var kids_before := screen.get_node("SystemPanel/SystemBody").get_child_count()
	# 价格必 ≥50 > 1 → 走买不起分支
	screen.call("_on_buy", shelf[0], part)
	var max_dx := 0.0
	for i in 30:   # 0.5s 采样（60fps 假设下覆盖 0.4s 摇摆全程）
		await create_timer(0.02).timeout
		max_dx = maxf(max_dx, absf(part.position.x - base_x))
	_eq("买不起·摇摆幅度 ≥5px", true, max_dx >= 5.0)
	_eq("买不起·摇摆归位（±0.5px）", true, absf(part.position.x - base_x) <= 0.5)
	_eq("买不起·钱袋不动", 1, int(screen.get("_copper")))
	_eq("买不起·无新浮层/弹窗", true,
		screen.get_node("SystemPanel/SystemBody").get_child_count() == kids_before)
	_finish()

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("DENY_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DENY_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
