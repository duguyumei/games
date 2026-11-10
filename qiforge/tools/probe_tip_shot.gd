## 浮窗截图探针（2026-11-08；2026-11-10 改组件口径——词条浮窗＝卡下 QiKeywordTooltip 组件，
## 不再有全局按宿主字典）。
## 用法＝"$GODOT" --path . --position 19000,19000 --script res://qiforge/tools/probe_tip_shot.gd
## 坑：屏幕必须挂 shot_no_hold（否则真鼠标轮询会清掉合成焦点，截图里没有浮窗）。
extends SceneTree

const OUT := "/Users/cc/Documents/qi-forge-2/sandbox/"

func _initialize() -> void:
	_run()

func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12:
		await process_frame
	var ent: Dictionary = r._first_enemy_entity()
	r._run["deck"] = ["zhici", "zhici", "zhici", "zhici", "zhici", "zhici"]
	r._start_battle(ent)
	for i in 10:
		await process_frame
	var sc = r._screen
	if sc == null or sc.battle == null:
		print("NO SCREEN"); quit(); return
	sc.battle.draw_cards(3)
	sc._rebuild_hand()   # 抽完立刻重建壳（否则手牌数停在首抽 3 张）
	for i in 40:
		await process_frame
	sc.set_meta("shot_no_hover", true)
	sc.set_meta("shot_no_hold", true)
	if sc._hand_wraps.size() >= 4:
		sc._set_hand_focus(sc._hand_wraps[3])
		for i in 50:
			await process_frame
		_save("vc_tip_hand.png")
	sc._set_hand_focus(null)
	for i in 10:
		await process_frame
	# 最右那张：扇角最大，梯度最明显
	var last: Control = sc._hand_wraps[sc._hand_wraps.size() - 1]
	sc._set_hand_focus(last)
	# 预览件观感检查：连环刺 0 费无护盾，手工补两个资源标（只为看图，不参与逻辑）
	for i in 6:
		await process_frame
	var qt = sc.find_child("QiText", true, false)
	var ht = sc.find_child("HpText", true, false)
	print("  QiText=", qt, " HpText=", ht)
	if qt != null: print("    qi rect=", (qt as Control).get_global_rect())
	if ht != null: print("    hp rect=", (ht as Control).get_global_rect())
	sc._mk_res_mark("QiText", "+4", Color(0.96, 0.80, 0.32))
	sc._mk_res_mark("HpText", "+8", Color(0.62, 0.84, 1.0))
	for i in 50:
		await process_frame
	var tip = last.get_meta("kw_tip", null)   # 卡下组件（2026-11-10 制）
	if tip == null or not tip.is_active():    # 合成鼠标没动被收起 → 补开一次
		sc._show_kw_tips(last)
		for i in 20:
			await process_frame
	var cs: PackedVector2Array = sc._card_face_corners(last)
	print("  corners=", cs)
	tip = last.get_meta("kw_tip", null)
	for q in tip._panels:
		print("    panel pos=", (q as Control).position, " size=", (q as Control).size)
	print("  card_rect=", sc._card_visual_rect(last))
	print("  _card_corner L=", sc._card_corner(last, false), " R=", sc._card_corner(last, true))
	print("  corner_for_side(-1)=", tip._corner_for_side(sc._card_visual_rect(last), -1))
	# 演示：后排括号款（20(10)）+ 致命金框
	var ec: Control = null
	for k2 in sc._enemy_cards.keys():
		ec = sc._enemy_cards[k2]
		break
	if ec != null:
		sc._mk_dmg_mark(ec, 20, true, true)
	_save("vc_prev_overlap.png")   # 词条浮窗＋预览标同屏＝当前真实情况
	quit()

func _save(nm: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + nm)
	print("saved ", nm)
