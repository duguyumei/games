## 一次性画面验收探针（2026-10-28 STS2 手感轮）：三图验拖拽手感件——
## ①悬停弹起（内层卡面拍平升起放大、wrap 原地）②目标功法 arrow 拖拽（卡升＋箭头＋敌吸附×＋双敌底灯）
## ③友方吸附○（引丝诀亮我方有效集）。跑法＝非无头 -s（截图须真渲染器）。
## motion 态吸附在离屏探针环境不可测（鼠标位垃圾），此处以直接调用持态截图，配 battle_drag 断言。
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
	var rec_e0: Dictionary = screen._enemy_slots[0]
	var rec_e1: Dictionary = screen._enemy_slots[1]
	var rec_a0: Dictionary = screen._ally_slots[0]

	# ① 悬停弹起
	var h0: Control = screen._hand_wraps[0]
	var v0: Control = h0.get_child(0)
	screen._set_hand_focus(h0)
	for i in 3:
		await process_frame
	_eq("弹起：卡面放大 1.25", "1.25", "%.2f" % v0.scale.x)
	_shot(".qi_drag_pop.png")
	screen._set_hand_focus(null)
	for i in 12:
		await process_frame

	# ② arrow 拖拽＋敌吸附×（索敌令：双敌底灯＋吸附 X＋箭头连线）——双卡同注（③ 用 911，免中段重建）
	var yinsi_card: Dictionary = {"uid": 911, "wid": "tiansi", "sid": "yinsi", "dir": 0,
		"spell": QI_DATA.WEAPONS["tiansi"]["spells"][0], "reuse_left": 0, "retain": false}
	b.hand = [{"uid": 910, "wid": "youming", "sid": "suodi", "dir": 0,
		"spell": QI_DATA.WEAPONS["youming"]["spells"][0], "reuse_left": 0, "retain": false},
		yinsi_card]
	b.changed.emit()
	for i in 6:
		await process_frame
	var wrap: Control = null
	for c in screen.get_children():
		if String(c.name) == "HandCard910":
			wrap = c
	if wrap == null:
		fails.append("HandCard910 缺失")
	else:
		wrap.on_drag_begin.call()   # arrow 起拖：升卡＋亮有效集（离屏鼠标垃圾不触发脱离检测）
		for i in 8:
			await process_frame
		_eq("arrow：升卡接管", true, not screen._spell_drag.is_empty())
		_eq("arrow：双敌底灯", true, (rec_e1["mark"]["ring"] as Control).visible)
		rec_e0["wrap"].drop_ok.call({"drag_data": {"hand_uid": 910}})
		for i in 3:
			await process_frame
		_eq("吸附敌：×符出", true, (rec_e0["mark"]["gx1"] as Control).visible)
		_eq("吸附敌：连线已画", true, (screen.find_child("DragLine", false, false) as Line2D).visible)
		_shot(".qi_drag_snap_enemy.png")
		var ec: Vector2 = (rec_e0["wrap"] as Control).get_global_rect().get_center()
		_px(".qi_drag_snap_enemy.png", "×臂交叉点＝敌红", int(ec.x), int(ec.y), Color("e88a70"))

	# ③ 友方吸附○（直接换引丝口径：亮我方集＋吸附 O）
	screen._unsnap_mark()
	screen._clear_spell_lights()
	screen._light_spell_targets(yinsi_card)
	rec_a0["wrap"].drop_ok.call({"drag_data": {"hand_uid": 911}})
	for i in 3:
		await process_frame
	_eq("吸附友：○符出", true, (rec_a0["mark"]["go"] as Control).visible)
	_eq("吸附友：×符收", false, (rec_a0["mark"]["gx1"] as Control).visible)
	_shot(".qi_drag_snap_ally.png")
	var ac: Vector2 = (rec_a0["wrap"] as Control).get_global_rect().get_center()
	_px(".qi_drag_snap_ally.png", "○环上缘＝玉绿", int(ac.x), int(ac.y - 28.0), Color("8fd8b0"))

	_finish()

func _shot(path: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/" + path)
	await create_timer(0.1).timeout

## 像素采样（V 律回退制的密度档：视觉工具两次伪造后，以真像素为准）
func _px(path: String, tag: String, x: int, y: int, want: Color) -> void:
	var img := Image.load_from_file("/Users/cc/Documents/qi-forge-2/" + path)
	if img == null:
		fails.append(tag + "：截图读不回")
		return
	var c: Color = img.get_pixel(x, y)
	if absf(c.r - want.r) > 0.12 or absf(c.g - want.g) > 0.12 or absf(c.b - want.b) > 0.12:
		fails.append("%s：期望 %s 实得 %s" % [tag, want.to_html(false), c.to_html(false)])

func _eq(tag: String, want: Variant, got: Variant) -> void:
	if str(want) != str(got):
		fails.append("%s：期望 %s 实得 %s" % [tag, str(want), str(got)])

func _finish() -> void:
	print("DRAGSHOT_FAILS=%d" % fails.size())
	for f in fails:
		print("FAIL: " + f)
	print("DRAG_SHOT_DONE")
	quit(1 if fails.size() > 0 else 0)
