extends SceneTree
const OUT := "/Users/cc/Documents/qi-forge-2/sandbox/"
func _initialize() -> void:
	_run()
func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12:
		await process_frame
	var ent := {"type": "enemy", "cell": Vector2i(8, 10), "id": "tut02",
		"group": [["tut_side", "tut_mid", "tut_side"]]}
	r._start_battle(ent)
	for i in 40:
		await process_frame
	var sc = r._screen
	print("开打 hand=", sc._hand_wraps.size(), " cards=", sc._enemy_cards.size())
	var uid := int(sc._hand_wraps[0].get_meta("hand_uid", -1))
	sc._play_clicked(uid)
	# 全程每 10 帧记一次，直到彻底静下来
	for k in range(1, 21):
		for i in 10:
			await process_frame
		var alive := 0
		for e in sc.battle.encounter.get("active", []):
			if bool(e.get("alive", false)):
				alive += 1
		print("  +%d帧 场上活敌=%d  _enemy_cards=%d  节点数=%d" %
			[k * 10, alive, sc._enemy_cards.size(), _count_cards(sc)])
		if k == 6:
			_save("t2_mid.png")
	_save("t2_end.png")
	quit()
func _count_cards(sc) -> int:
	var n := 0
	for c in sc._enemy_holder.get_children():
		if c is Control and (c as Control).visible and (c as Control).size.x > 100:
			n += 1
	return n
func _save(nm: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OUT + nm)
	print("  saved ", nm)
