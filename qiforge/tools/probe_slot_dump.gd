extends SceneTree
const OUT := "/Users/cc/Documents/qi-forge-2/sandbox/"
func _initialize() -> void:
	_run()
func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12:
		await process_frame
	r._start_battle({"type": "enemy", "cell": Vector2i(8, 10), "id": "tut02",
		"group": [["tut_side", "tut_mid", "tut_side"]]})
	for i in 40:
		await process_frame
	var sc = r._screen
	sc._play_clicked(int(sc._hand_wraps[0].get_meta("hand_uid", -1)))
	var t := 0
	for k in range(400):
		await process_frame
		t = k
		if sc._enemy_cards.size() == 0:
			break
	print("=== cards=0 at frame ", t, " ===")
	for i in 10:
		await process_frame
	_dump(sc, "敌卡容器")
	root.get_viewport().get_texture().get_image().save_png(OUT + "slot_dump.png")
	quit()
func _dump(sc, tag: String) -> void:
	print("--- ", tag, " children=", sc._enemy_holder.get_child_count())
	for c in sc._enemy_holder.get_children():
		if c is Control:
			var cc: Control = c
			print("  [holder] ", cc.name, " ", cc.get_class(), " vis=", cc.visible,
				" a=%.2f" % cc.modulate.a, " rect=", cc.get_global_rect())
	print("--- 屏幕层里的「像卡的东西」")
	for c in sc.get_children():
		if c is Control:
			var q: Control = c
			if q.size.x > 120 and q.size.y > 150 and q.z_index >= 0:
				print("  [screen] ", q.name, " ", q.get_class(), " vis=", q.visible,
					" a=%.2f" % q.modulate.a, " z=", q.z_index, " rect=", q.get_global_rect())
