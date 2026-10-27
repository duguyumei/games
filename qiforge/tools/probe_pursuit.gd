## 追击被动逻辑探针（2026-10-28 用户报天丝手套追击没生效）。跑法＝非无头：
## godot --path . --script res://qiforge/tools/probe_pursuit.gd
## 幽冥剑普攻 → 天丝（zhuiji）应自动追加：事件含「追击」＋敌方掉两段血。
extends SceneTree

const QIDATA := preload("res://qiforge/QiData.gd")
const QIBATTLE := preload("res://qiforge/QiBattle.gd")

func _initialize() -> void:
	var run := QIDATA.default_run()
	var battle = QIBATTLE.new()
	battle.setup(run)
	battle.start()
	var evts: Array = []
	battle.event.connect(func(t: String) -> void: evts.push_back(t))
	var a0: Dictionary = battle.allies[0]
	var a1: Dictionary = battle.allies[1]
	print("TEAM ", a0["name"], "/", a1["name"], " passives=", a0["passive"].get("id"), "/", a1["passive"].get("id"))
	var e0: Dictionary = battle.enemies[0]
	var hp0 := int(e0["hp"])
	print("PHASE=", battle.phase, " acts0=", a0["acts"], " acts1=", a1["acts"],
		" ehp=", hp0, " edef=", battle.def_of(e0), " atk0=", battle.atk_of(a0), " atk1=", battle.atk_of(a1))
	battle.normal_attack(a0, e0)
	for t in evts:
		print("EVT ", t)
	print("EHP ", hp0, "->", int(e0["hp"]))
	var pursuit := false
	for t in evts:
		if "追击" in String(t):
			pursuit = true
	print("PURSUIT_%s" % ("OK" if pursuit else "MISSING"))
	## 反证：直接用天丝普攻 → 应发「无法普攻」（零攻次）
	battle.normal_attack(a1, e0)
	for t in evts:
		if "无法普攻" in String(t):
			print("ZERO_ACTS_FEEDBACK_OK")
	print("PURSUIT_PROBE_DONE")
	quit(0)
