## 拖放探针（v0.7）：合成输入走真·原生拖放（按住我方卡→拖到敌卡→松手＝普攻）；
## 器灵目标功法拖到「我方卡」施放（引丝诀——新落点路径）；敌方目标功法拖到敌卡；
## 敌方区对器灵目标功法＝不可落点（负例）。跑法＝非无头 -s。
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
	var b: RefCounted = screen.battle
	var dashou: Dictionary = b.enemies[0]
	var ally_rec: Dictionary = screen._ally_slots[0]
	var enemy_rec: Dictionary = screen._enemy_slots[0]

	# —— 接线层断言（不依赖输入模拟）——
	var ok_hand: bool = enemy_rec["wrap"].drop_ok.call({"drag_data": {"hand_uid": 9}})
	_eq("手牌拖到敌卡不该判为普攻落点", false, ok_hand)
	var ok_atk: bool = enemy_rec["wrap"].drop_ok.call(
		{"drag_data": {"atk_uid": int(ally_rec["unit"]["uid"])}})
	_eq("我方卡拖到敌卡＝可落点", true, ok_atk)
	_eq("预估伤害=18（幽冥 26−8）", 18, b.preview_normal_attack(ally_rec["unit"], dashou))
	_eq("悬停高亮已亮", true, (enemy_rec["mark"]["ring"] as Control).visible)
	_eq("预估文案", "预估 18", (enemy_rec["mark"]["est"] as Label).text)
	screen._clear_drag_marks()
	_eq("清罩后高亮灭", false, (enemy_rec["mark"]["ring"] as Control).visible)

	# —— 原生拖放会话（引擎 force_drag 起手＝真拖拽态；验拖起之后的全链路）——
	var from: Vector2 = (ally_rec["wrap"] as Control).get_global_rect().get_center()
	var to: Vector2 = (enemy_rec["wrap"] as Control).get_global_rect().get_center()
	(ally_rec["wrap"] as Control).force_drag(
		{"drag_data": {"atk_uid": int(ally_rec["unit"]["uid"])}, "from": ally_rec["wrap"]},
		screen._make_attack_chip("幽冥剑"))
	for i in 3:
		await process_frame
	_move(to)
	for i in 3:
		await process_frame
	_eq("拖拽悬停中高亮已亮", true, (enemy_rec["mark"]["ring"] as Control).visible)
	_release(to)
	await create_timer(1.05).timeout
	_eq("拖放普攻已结算（60−18幽冥−2天丝追击=40）", 40, int(dashou["hp"]))
	_eq("拖放后拖源攻次=0（幽冥攻次1）", 0, int(ally_rec["unit"]["acts"]))
	_eq("拖放结束高亮已清", false, (enemy_rec["mark"]["ring"] as Control).visible)

	# —— 敌方目标功法拖放施放：手牌卡拖到敌卡（索敌令→挂标记＋本回合死亡回能挂账）——
	b.hand = [{"uid": 777, "wid": "youming", "sid": "suodi", "dir": 0,
		"spell": QI_DATA.WEAPONS["youming"]["spells"][0],
		"reuse_left": 0, "retain": false}]
	b.changed.emit()
	for i in 5:
		await process_frame
	var hand_wrap: Control = null
	for c in screen.get_children():
		if String(c.name) == "HandCard777":
			hand_wrap = c
	if hand_wrap == null:
		fails.append("手牌节点缺失（功法拖放）")
	else:
		var cast_ok: bool = enemy_rec["wrap"].drop_ok.call({"drag_data": {"hand_uid": 777}})
		_eq("功法卡拖到敌卡＝可落点", true, cast_ok)
		hand_wrap.force_drag({"drag_data": {"hand_uid": 777}, "from": hand_wrap},
			hand_wrap.preview_card)
		for i in 3:
			await process_frame
		_move(to)
		for i in 3:
			await process_frame
		_release(to)
		await create_timer(1.05).timeout
		_eq("拖放施放已结算（索敌令＝标记 1 层）", 1, b.status_total(dashou, "biaoji"))
		_eq("施放后手牌已消耗", 0, b.hand.size())

	# —— 器灵目标功法拖到「我方卡」施放（引丝诀：其他器灵攻次 +1）——
	b.energy = 3
	b.hand = [{"uid": 778, "wid": "tiansi", "sid": "yinsi", "dir": 0,
		"spell": QI_DATA.WEAPONS["tiansi"]["spells"][0],
		"reuse_left": 0, "retain": false}]
	b.changed.emit()
	for i in 5:
		await process_frame
	var hw: Control = null
	for c in screen.get_children():
		if String(c.name) == "HandCard778":
			hw = c
	if hw == null:
		fails.append("手牌节点缺失（器灵目标功法）")
	else:
		var ally_ok: bool = (screen._ally_slots[0]["wrap"] as Control).drop_ok.call(
			{"drag_data": {"hand_uid": 778}})
		_eq("器灵目标功法拖到我方卡＝可落点", true, ally_ok)
		var zone: Control = screen.find_child("EnemyZone", false, false)
		var zone_ok: bool = zone.drop_ok.call({"drag_data": {"hand_uid": 778}})
		_eq("器灵目标功法拖敌方区＝不可落点", false, zone_ok)
		var to_ally: Vector2 = (screen._ally_slots[0]["wrap"] as Control).get_global_rect().get_center()
		hw.force_drag({"drag_data": {"hand_uid": 778}, "from": hw}, hw.preview_card)
		for i in 3:
			await process_frame
		_move(to_ally)
		for i in 3:
			await process_frame
		_release(to_ally)
		await create_timer(1.05).timeout
		_eq("引丝诀拖放施放（幽冥攻次 0→1）", 1, int(screen._ally_slots[0]["unit"]["acts"]))
		_eq("拖我方卡释放后手牌已消耗", 0, b.hand.size())

	_finish()

func _move(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	root.push_input(ev)

func _release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	root.push_input(ev)

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("DRAG_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DRAG_PROBE_DONE")
	quit(1 if fails.size() > 0 else 0)
