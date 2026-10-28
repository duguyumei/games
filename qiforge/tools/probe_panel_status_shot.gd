## 一次性画面验收探针（2026-10-28 面板状态具名制轮）：金刚盾队开战斗 →
## 普攻触发铁壁 → 金刚盾＋相邻各得 1 层护甲 → 截全屏验状态列「甲」图标。
## 跑法＝非无头 -s（截图须真渲染器）。断言：护甲层落地、跨单位、画面渲染。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = SCREEN.instantiate()
	screen.run_data = {"copper": 0,
		"team": [{"id": "jingang", "equips": [], "pdir": 0},
			{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026}
	root.add_child(screen)
	for i in 20:
		await process_frame
	var battle: RefCounted = screen.battle
	var jg: Dictionary = battle.allies[0]
	battle.normal_attack(jg, battle.enemies[0])
	await create_timer(0.6).timeout
	for i in 10:
		await process_frame

	_eq("铁壁：金刚盾 1 层护甲", 1, battle.status_total(jg, "hujia"))
	_eq("铁壁：相邻幽冥 1 层护甲", 1, battle.status_total(battle.allies[1], "hujia"))
	_eq("护甲防御 +1 生效", 1, battle.def_of(jg))
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.panel_status_preview.png")
	await create_timer(0.1).timeout
	print("PANEL_SHOT_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	quit(1 if fails.size() > 0 else 0)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])
