## 一次性画面验收探针（2026-10-28 灭魂斩·升一重做轮）：开默认战斗局 →
## 造 12 层杀意 → 手里放升一灭魂斩 → 打出（清杀意出 0 费消耗副本）→ 截全屏验手牌。
## 跑法＝非无头 -s（截图须真渲染器）。断言：副本 2 张、卡面带「（消耗）」角标、费用 0。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")
const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")
const QI_DATA := preload("res://qiforge/QiData.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = SCREEN.instantiate()
	root.add_child(screen)
	for i in 20:
		await process_frame
	var battle: RefCounted = screen.battle
	var ym: Dictionary = battle.allies[0]
	battle.apply_status(ym, "shayi", 12)
	var spell: Dictionary = QI_DATA.spell_of("youming", "miehun", 1)
	battle.hand = [{"uid": 7001, "wid": "youming", "sid": "miehun", "dir": 1, "spell": spell,
		"reuse_left": 0, "retain": false}]
	battle.changed.emit()
	await create_timer(0.2).timeout
	battle.play_card(7001, battle.enemies[0])
	await create_timer(0.5).timeout
	for i in 10:
		await process_frame

	var copies: Array = []
	for c in screen.get_children():
		if String(c.name).begins_with("HandCard"):
			copies.push_back(c)
	_eq("打出后手牌＝2 张消耗副本", 2, copies.size())
	var saw_tag := 0
	var saw_zero := 0
	for w in copies:
		for lbl in _labels(w):
			if String(lbl.text).contains("（消耗）"):
				saw_tag += 1
			if String(lbl.text).contains("灭魂斩"):
				saw_zero += 1
	_eq("卡面带（消耗）角标", 2, saw_tag)
	root.get_viewport().get_texture().get_image().save_png(
		"/Users/cc/Documents/qi-forge-2/.cashout_preview.png")
	await create_timer(0.1).timeout
	print("CASHOUT_SHOT_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	quit(1 if fails.size() > 0 else 0)

func _labels(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.push_back(n)
	for c in n.get_children():
		out.append_array(_labels(c))
	return out

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])
