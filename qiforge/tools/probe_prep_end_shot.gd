## 一次性画面验收探针（2026-10-28 组末守卫轮）：备战舱以组毕档（fight 越界）直开 →
## 出战钮应封死显示「已通关」。跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const PREP := preload("res://qiforge/QiPrepBay.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var prep: Control = PREP.instantiate()
	var run: Dictionary = QI_DATA.default_run()
	run["fight"] = 2   # 组毕（GROUPS[0] 只有 2 场）
	prep.run_data = run
	root.add_child(prep)
	for i in 20:
		await process_frame
	var gb := prep.find_child("GoButton", true, false) as Button
	_eq("出战钮存在", true, gb != null)
	if gb != null:
		_eq("出战钮封死", true, gb.disabled)
		_eq("出战钮文案＝已通关", "已通关", gb.text)
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.prep_end_preview.png")
	await create_timer(0.1).timeout
	print("PREP_END_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	quit(1 if fails.size() > 0 else 0)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])
