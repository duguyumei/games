## 升级选卡点击后：验证(1)特效不抖 (2)弹窗会消失
extends SceneTree

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
	var rw = (load("res://qiforge/QiVcReward.gd") as GDScript).new()
	rw.setup(r._run)
	rw.card_chosen.connect(sc._on_card_chosen)
	rw.done.connect(sc._on_reward_done)
	sc._reward_ui = rw
	sc.add_child(rw)
	paused = true   # 模拟真实：弹窗开着时世界暂停（弹窗是 WHEN_PAUSED）
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/sandbox/rc_before.png")
	var cid := ""
	if rw._offers.size() > 0:
		cid = String(rw._offers[0])
	print("CLICK ", cid)
	rw._card_clicked(cid)
	for i in 22:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/sandbox/rc_mid.png")
	await create_timer(1.6).timeout
	for i in 10:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("/Users/cc/Documents/qi-forge-2/sandbox/rc_after.png")
	print("DIALOG_VALID=", is_instance_valid(rw), " IN_TREE=", rw.is_inside_tree() if is_instance_valid(rw) else false)
	quit()
