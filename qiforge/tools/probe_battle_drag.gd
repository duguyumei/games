## 拖放探针（v0.7；2026-10-28 STS2 手感轮扩展）：合成输入走真·原生拖放（按住我方卡→拖到敌卡→松手＝普攻）；
## 器灵目标功法拖到「我方卡」施放（引丝诀——新落点路径）；敌方目标功法拖到敌卡；
## 敌方区对器灵目标功法＝不可落点（负例）。新增：悬停弹起、吸附状态机回落不灭灯、×/○吸附符、arrow 拖拽态。
## 跑法＝非无头 -s。
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

	# —— 悬停弹起（2026-10-28 STS2 RefreshLayout 制）：只弹内层卡面、wrap 原地不动 ——
	if screen._hand_wraps.size() > 0:
		var h0: Control = screen._hand_wraps[0]
		var v0: Control = h0.get_child(0)
		var pre_pos: Vector2 = h0.position
		var pre_rot: float = h0.rotation
		screen._set_hand_focus(h0)
		_eq("指卡拍平（卡面转角抵消扇角）", "%.3f" % -h0.rotation, "%.3f" % v0.rotation)
		_eq("指卡放大到详情档等效 1.25", "1.25", "%.2f" % v0.scale.x)
		_eq("指卡置顶", 20, v0.z_index)
		_eq("wrap 原地不动（命中区稳定）", true,
			absf(h0.position.x - pre_pos.x) < 0.01 and absf(h0.rotation - pre_rot) < 0.001)
		screen._set_hand_focus(null)
		_eq("散焦复位 z", 0, v0.z_index)

	# —— 吸附状态机回归（2026-10-28 修「移开高亮消失」bug）：双有效目标，换目标旧槽回落底灯不灭 ——
	var suodi_card: Dictionary = {"uid": 910, "wid": "youming", "sid": "suodi", "dir": 0,
		"spell": QI_DATA.WEAPONS["youming"]["spells"][0], "reuse_left": 0, "retain": false}
	b.hand = [suodi_card]
	b.changed.emit()
	for i in 5:
		await process_frame
	var rec_a: Dictionary = screen._enemy_slots[0]
	var rec_b: Dictionary = screen._enemy_slots[1]
	screen._light_spell_targets(suodi_card)
	_eq("起拖双目标底灯亮 A", true, (rec_a["mark"]["ring"] as Control).visible)
	_eq("起拖双目标底灯亮 B", true, (rec_b["mark"]["ring"] as Control).visible)
	rec_a["wrap"].drop_ok.call({"drag_data": {"hand_uid": 910}})
	_eq("吸附 A＝×符出", true, (rec_a["mark"]["gx1"] as Control).visible)
	_eq("吸附 A＝○符收", false, (rec_a["mark"]["go"] as Control).visible)
	rec_b["wrap"].drop_ok.call({"drag_data": {"hand_uid": 910}})
	_eq("换到 B 后 A 底灯仍亮（修灭灯 bug）", true, (rec_a["mark"]["ring"] as Control).visible)
	_eq("换到 B 后 A ×符已收", false, (rec_a["mark"]["gx1"] as Control).visible)
	_eq("B 吸附 ×符出", true, (rec_b["mark"]["gx1"] as Control).visible)
	screen._clear_drag_marks()
	screen._clear_spell_lights()
	_eq("收拖全清", false, (rec_b["mark"]["ring"] as Control).visible)

	# —— 原生拖放会话（引擎 force_drag 起手＝真拖拽态；验拖起之后的全链路）——
	var from: Vector2 = (ally_rec["wrap"] as Control).get_global_rect().get_center()
	var to: Vector2 = (enemy_rec["wrap"] as Control).get_global_rect().get_center()
	(ally_rec["wrap"] as Control).force_drag(
		{"drag_data": {"atk_uid": int(ally_rec["unit"]["uid"])}, "from": ally_rec["wrap"]},
		screen._make_attack_chip("幽冥剑"))
	# 引擎拖拽悬停轮询依赖真实鼠标位（离屏窗被 macOS 钳回＋坐标按窗原点换算＝垃圾值，
	# 实测 2026-10-28）——motion 态吸附在探针环境不可测，撤该断言；
	# 由上方 B1 直接 drop_ok 断言＋drag_shot 截图探针覆盖。drop-at-release 链路（can_drop→drop→结算）真拖拽态可测，见下。
	for i in 3:
		await process_frame
	_move(to)
	for i in 3:
		await process_frame
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
		_eq("目标功法＝arrow 拖拽形态", "arrow", hand_wrap.drag_style)
		hand_wrap.on_drag_begin.call()   # force_drag 不走 _get_drag_data，手动起拖（STS2 升卡＋亮目标集）
		for i in 3:
			await process_frame
		_eq("arrow 起拖＝升卡接管", true, not screen._spell_drag.is_empty())
		_eq("arrow 起拖＝鼠标穿透升卡", true, hand_wrap.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		var cast_ok: bool = enemy_rec["wrap"].drop_ok.call({"drag_data": {"hand_uid": 777}})
		_eq("功法卡拖到敌卡＝可落点", true, cast_ok)
		_eq("吸附＝×符出（敌）", true, (enemy_rec["mark"]["gx1"] as Control).visible)
		hand_wrap.force_drag({"drag_data": {"hand_uid": 777}, "from": hand_wrap},
			hand_wrap.preview_card)
		for i in 3:
			await process_frame
		_move(to)
		for i in 3:
			await process_frame
		_release(to)
		await create_timer(1.05).timeout
		_eq("arrow 收拖已复位", true, screen._spell_drag.is_empty())
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
		hw.on_drag_begin.call()   # arrow 起拖：器灵目标功法亮我方有效集
		for i in 3:
			await process_frame
		_eq("起拖亮我方有效目标底灯", true,
			(screen._ally_slots[0]["mark"]["ring"] as Control).visible)
		var ally_ok: bool = (screen._ally_slots[0]["wrap"] as Control).drop_ok.call(
			{"drag_data": {"hand_uid": 778}})
		_eq("器灵目标功法拖到我方卡＝可落点", true, ally_ok)
		_eq("友方吸附＝○符出", true, (screen._ally_slots[0]["mark"]["go"] as Control).visible)
		_eq("友方吸附＝×符收", false, (screen._ally_slots[0]["mark"]["gx1"] as Control).visible)
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
	# push_input 直注视口（离屏后台窗 parse_input_event 不投递，实测 2026-10-28；drop 链 push 可达）
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
