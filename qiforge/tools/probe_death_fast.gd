extends SceneTree
const OUT := "/Users/cc/Documents/qi-forge-2/sandbox/"
func _initialize() -> void: _run()
func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12: await process_frame
	r._start_battle({"type":"enemy","cell":Vector2i(8,10),"id":"tut02","group":[["tut_side","tut_mid","tut_side"]]})
	for i in 40: await process_frame
	var sc = r._screen
	sc._play_clicked(int(sc._hand_wraps[0].get_meta("hand_uid", -1)))
	for n in 10:
		for i in 6: await process_frame
		root.get_viewport().get_texture().get_image().save_png(OUT + "n%d.png" % n)
	quit()
