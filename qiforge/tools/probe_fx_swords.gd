## 飞剑特效时间线探针：打两次连环刺，记录每柄飞剑的到达/释放时刻
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12:
		await process_frame
	var ent: Dictionary = r._first_enemy_entity()
	r._run["deck"] = ["zhici", "zhici", "zhici", "zhici", "zhici"]
	r._start_battle(ent)
	for i in 20:
		await process_frame
	var sc = r._screen
	if sc == null or sc.battle == null:
		print("NO SCREEN"); quit(); return
	sc.battle.draw_cards(5)
	sc._rebuild_hand()
	for i in 30:
		await process_frame
	for k in 2:
		if sc.battle.hand.is_empty():
			print("NO CARD"); break
		var uid := int(sc.battle.hand[0]["uid"])
		print("PLAY ", k)
		sc._play_clicked(uid)
		print("  after play pile=", sc.battle.played_pile.size(), " phase=", sc.battle.phase)
		for i in 90:
			await process_frame
			if k == 1 and i % 10 == 0:
				root.get_viewport().get_texture().get_image().save_png(
					"/Users/cc/Documents/qi-forge-2/sandbox/fx_%02d.png" % (i / 10))
	for i in 30:
		await process_frame
	quit()
