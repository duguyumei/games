## 一次性画面验收探针（2026-10-28 普攻预览族轮）：幽冥+天丝队 → 模拟普攻拖拽吸附敌 1 →
## 主攻实线＋线边 -18、追击（天丝）虚线＋线边 -2、敌血条将受段＋段上 -20，截全屏验收。
## 跑法＝非无头 -s（截图须真渲染器；鼠标 warp 到敌卡中心维持吸附态——_process 脱离检测吃鼠标位）。
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
		"team": [{"id": "youming", "equips": [], "pdir": 0},
			{"id": "tiansi", "equips": [], "pdir": 0}],
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026}
	root.add_child(screen)
	for i in 20:
		await process_frame
	var battle: RefCounted = screen.battle
	var ym: Dictionary = battle.allies[0]
	var rec: Dictionary = screen._enemy_slots[0]
	var center: Vector2 = (rec["wrap"] as Control).get_global_rect().get_center()
	for i in 3:
		root.warp_mouse(center)
		await process_frame
	screen._mark_drag(rec, int(ym["uid"]))
	for i in 10:
		root.warp_mouse(center)
		await process_frame

	_eq("吸附态主攻预估 18", 18, int(screen._drag_mark.get("est", -1)))
	_eq("追击连带 1 人", 1, (screen._drag_mark.get("follows", []) as Array).size())
	var seg: Panel = rec.get("hpprev", null)
	_eq("血条将受段可见", true, seg != null and seg.visible)
	_eq("段上合计 -20", "-20", (seg.get_child(0) as Label).text if seg != null else "")
	_eq("追击虚线已画且可见", true,
		screen._dash_pool.size() >= 1 and (screen._dash_pool[0] as Control).visible)
	_eq("主攻线边数字 -18", "-18", (screen._num_pool[0] as Label).text)
	_eq("追击线边数字 -2", "-2", (screen._num_pool[1] as Label).text)
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.attack_preview.png")
	await create_timer(0.1).timeout
	print("ATTACK_PREVIEW_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	quit(1 if fails.size() > 0 else 0)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])
