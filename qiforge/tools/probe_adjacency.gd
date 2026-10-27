## 相邻动态判定探针（2026-10-28 裁定：按存活者取最近邻、阵亡不占位）。跑法＝非无头：
## godot --path . --script res://qiforge/tools/probe_adjacency.gd
## 局A：[金刚盾, 幽冥剑, 天丝] 金刚盾普攻 → 铁壁加防＝自身＋幽冥剑（直邻），远位天丝不得；
## 局B：同队先置幽冥剑阵亡再普攻 → 铁壁加防＝自身＋天丝（跨死位取最近存活者＝战斗动态判定）。
extends SceneTree

const QIDATA := preload("res://qiforge/QiData.gd")
const QIBATTLE := preload("res://qiforge/QiBattle.gd")

var fails: Array = []

func _initialize() -> void:
	_run()

func _make_run() -> Dictionary:
	var run := QIDATA.default_run()
	run["team"] = [
		{"id": "jingang", "equips": [], "pdir": 0},
		{"id": "youming", "equips": [], "pdir": 0},
		{"id": "tiansi", "equips": [], "pdir": 0}]
	return run

func _run() -> void:
	## —— 局A：直邻 ——
	var b1 = QIBATTLE.new()
	b1.setup(_make_run())
	b1.start()
	b1.normal_attack(b1.allies[0], b1.enemies[0])
	_expect(b1.has_status(b1.allies[0], "fangyu"), true, "局A 金刚盾自身得防御")
	_expect(b1.has_status(b1.allies[1], "fangyu"), true, "局A 直邻幽冥剑得防御")
	_expect(b1.has_status(b1.allies[2], "fangyu"), false, "局A 远位天丝不得防御")

	## —— 局B：中位阵亡 → 跨死位 ——
	var b2 = QIBATTLE.new()
	b2.setup(_make_run())
	b2.start()
	b2.allies[1]["alive"] = false
	b2.allies[1]["hp"] = 0
	b2.normal_attack(b2.allies[0], b2.enemies[0])
	_expect(b2.has_status(b2.allies[0], "fangyu"), true, "局B 金刚盾自身得防御")
	_expect(b2.has_status(b2.allies[1], "fangyu"), false, "局B 死者幽冥剑不得")
	_expect(b2.has_status(b2.allies[2], "fangyu"), true, "局B 跨死位天丝得防御（动态相邻）")

	print("ADJ_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("ADJ_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)

func _expect(got: bool, want: bool, tag: String) -> void:
	if got != want:
		fails.append("%s：期望%s，实测%s" % [tag, "得" if want else "不得", "得" if got else "不得"])
