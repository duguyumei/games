## 战斗屏 UI 绑定探针：QiBattleScreen 直跑（默认局）——布局＋实况数据绑定＋一次普攻联动。
## 跑法＝非无头 -s。
extends SceneTree

const PROBE_LIB := preload("res://qiforge/tools/probe_lib.gd")

const SCREEN := preload("res://qiforge/QiBattleScreen.tscn")

var fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	await PROBE_LIB.fit(self)
	var screen: Control = SCREEN.instantiate()
	root.add_child(screen)
	for i in 20:
		await process_frame

	var enemy_row := screen.find_child("EnemyRow", false, false) as Container
	if enemy_row == null:
		fails.append("敌排缺失")
		_finish()
		return
	_eq("敌数=2（G1 第1场）", 2, enemy_row.get_children().size())
	var ally_row := screen.find_child("AllyRow", false, false) as Container
	_eq("我排槽＝实卡数（演示 2；空位占位已撤 2026-10-28 用户手改）", 2, ally_row.get_children().size())
	_eq("手牌=4（v0.6 出厂抽 4）", 4, screen.battle.hand.size())
	var hand_n := 0
	for c in screen.get_children():
		if String(c.name).begins_with("HandCard"):
			hand_n += 1
	_eq("手牌节点=4", 4, hand_n)
	var energy := screen.find_child("EnergyStack", false, false) as Container
	_eq("能量珠=3（青布衫上限）", 3, energy.get_child_count() if energy else -1)
	if screen.find_child("EndButton", false, false) == null:
		fails.append("结束回合钮缺失")
	var round_lbl := screen.find_child("RoundLbl", false, false) as Label
	_eq("回合标签", "回合 1", round_lbl.text if round_lbl else "")

	# 意图徽：内容随实况（部件非空）
	var chips := 0
	for rec in screen._enemy_slots:
		var chip := rec["chip"] as PanelContainer
		if chip.get_child_count() > 0:
			chips += 1
	_eq("意图徽已填=2", 2, chips)

	# 普攻联动：幽冥 26−8=18 ＋ 天丝追击 10−8=2 → 打手血条 40；幽冥攻次 1→0；杀意 +1
	bind_attack(screen, 0, 0)
	for i in 5:
		await process_frame
	# 血条引用守卫：屏层事件重绑（_rebind）是异发的，旧 rec 可能整位换新——回读现役槽位
	var hp_bar: ProgressBar = null
	for i in 30:
		if screen._enemy_slots.size() > 0 and screen._enemy_slots[0]["hp"] is ProgressBar:
			hp_bar = screen._enemy_slots[0]["hp"]
			break
		await process_frame
	if hp_bar == null:
		fails.append("敌方血条引用取不到（重绑竞态）")
	else:
		_eq("普攻+追击后打手血条=40", 40.0, float(hp_bar.value))
	var acts0 := screen._ally_slots[0]["acts"] as Label
	_eq("攻次标签=0", "剩余攻击 0", acts0.text if acts0 != null else "<null>")
	_eq("杀意获得=1（幽冥造成伤害）", 1, screen.battle.status_total(screen.battle.allies[0], "shayi"))

	# 冲弃联动（v0.6 卡组制）：回合末整手进弃牌堆（手动弃置已退役）
	var flush_n: int = screen.battle.hand.size()
	var disc_n: int = screen.battle.discard_pile.size()
	screen.battle.end_turn()
	for i in 5:
		await process_frame
	_eq("冲弃后手牌=0", 0, screen.battle.hand.size())
	_eq("冲弃后弃牌堆+%d" % flush_n, disc_n + flush_n, screen.battle.discard_pile.size())

	_finish()

func bind_attack(screen: Control, ally_i: int, enemy_i: int) -> void:
	var a: Dictionary = screen.battle.allies[ally_i]
	var e: Dictionary = screen.battle.enemies[enemy_i]
	screen.battle.normal_attack(a, e)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("BUI_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("BATTLE_UI_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
