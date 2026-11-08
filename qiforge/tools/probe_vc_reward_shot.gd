## VC 升级三选一截图探针（2026-11-08）——在真游玩线上叠一层 QiVcReward 截图
extends SceneTree

const OUT := "/Users/cc/Documents/qi-forge-2/sandbox/vc_reward.png"

func _initialize() -> void:
	_run()

func _run() -> void:
	var r = (load("res://qiforge/QiVcRoot.tscn") as PackedScene).instantiate()
	root.add_child(r)
	for i in 12:
		await process_frame
	var ent: Dictionary = r._first_enemy_entity()
	r._run["deck"] = ["zhici", "zhici", "zhici"]
	r._start_battle(ent)
	for i in 10:
		await process_frame
	var sc = r._screen
	if sc == null:
		print("NO SCREEN"); quit(); return
	var rw = (load("res://qiforge/QiVcReward.gd") as GDScript).new()
	rw.setup(r._run)
	sc.add_child(rw)
	for i in 45:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(OUT)
	print("SAVED ", OUT)
	quit()
