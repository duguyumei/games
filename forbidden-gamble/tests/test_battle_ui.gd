extends GutTest

# 战斗场景级回归（C-028 袭击制）：被袭击＝敌方先手，开场即敌方回合——
# 敌方第一击必须由演出链自动打出。修复前场景停在"敌方行动"却无人推进：
# 按钮全隐、手牌锁死，玩家被袭击后无法操作。

func before_each() -> void:
	DojoConfig.clear()

func test_ambush_enemy_first_strike_runs_and_returns_control() -> void:
	var enemy_id := _first_enemy_id()
	assert_false(enemy_id.is_empty(), "敌人表里有敌人可打")
	DojoConfig.active = true
	DojoConfig.enemy_id = enemy_id
	DojoConfig.enemy_first = true  # 被袭击：敌方先手
	var main: Control = load("res://scenes/battle/battle.tscn").instantiate()
	add_child_autofree(main)
	assert_not_null(main.combat, "演武场战斗应加载成功")
	assert_not_null(main.turn_manager, "回合控制器应就位")
	if main.combat == null or main.turn_manager == null:
		return
	# 演出链第一步同步结算、随后挂在节拍计时上——加进来就该是 busy 态。
	# 修复前这里就是 false：没有任何链在跑，战斗永远停在"敌方行动"。
	assert_true(main.sequencer.busy, "被袭击开场敌方演出链应立即启动")
	# 演出链自行推进（每步 0.6s×速度档）；封顶 5 秒防死等。
	var waited := 0.0
	while (main.sequencer.busy or main.combat.active_side == "enemy") and waited < 5.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	# 敌方架势开出的截牌窗：测试策略一律放行（窗口作废 → 玩家被动获得行动权）
	while main.turn_manager.awaiting_player_claims and not main.turn_manager.is_over():
		main._release_claim_window()
		await get_tree().process_frame
	if main.turn_manager.is_over():
		# 敌方第一击直接终结战斗（极端情况）：终局停拍后结算浮层必须弹出。
		var overlay_wait := 0.0
		while not main.end_overlay.visible and overlay_wait < 2.0:
			await get_tree().create_timer(0.1).timeout
			overlay_wait += 0.1
		assert_true(main.end_overlay.visible, "终局应弹结算浮层")
		return
	assert_eq(main.combat.active_side, "player", "敌方先手打完后行动权回到玩家")
	assert_true(main.buttons_row.visible, "按钮行恢复——玩家可以操作")

func _first_enemy_id() -> String:
	var file := FileAccess.open("res://data/enemies.json", FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and not (parsed as Dictionary).is_empty():
		return str((parsed as Dictionary).keys()[0])
	return ""
