extends GutTest

# 容器弹窗（D-028 弹窗翻牌，C-028 网格化恢复版）场景流：
# 点击容器牌→弹窗（暗牌数＝内容物数）→翻（1 行动力/张，视图变亮牌）→拿（免费入包）
# →拿空自动收窗→空壳再点不弹。弹窗不进 ui_layer：_refresh 清屏后仍在、视图自重读。
# 隔离（17 号）：autoload 会话在 GUT 下已系统性隔离（读档扑空/存档走测试路径）；
# 这里再显式复位＋start_run(固定种子)——要的是确定局面，不靠运气。

func _fresh_board_scene(new_seed: int):
	ExpeditionSession.reset_for_tests()
	ExpeditionSession.start_run(new_seed)
	var scene: PackedScene = load("res://scenes/board/board.tscn")
	return scene.instantiate()

func test_container_popup_flow() -> void:
	var scene = _fresh_board_scene(7)
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BoardState = scene.board
	# 铺一个受控网格：0 木箱（2 件）1 敌人（真实配置，wood 开启费 1）
	bs.current_site()["grid"] = [
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [
			{"item_id": "yaoshi", "flipped": false},
			{"item_id": "yinzi", "flipped": false}]},
		{"kind": "enemy", "enemy_id": "落魄拳师", "alert": 0},
	]
	scene._refresh()
	var ap_before: int = bs.ap
	# 点击容器牌＝开盖（1 行动力）→弹窗自动弹出
	scene._on_card_action(0)
	assert_true(scene.container_popup.is_open(), "开盖后应弹出容器窗")
	var view: Dictionary = scene.container_popup.view()
	assert_eq((view.get("entries", []) as Array).size(), 2, "两件东西摊成两张暗牌")
	assert_false(bool((view["entries"][0] as Dictionary).get("flipped", false)))
	assert_eq(bs.ap, ap_before - 1, "开木箱 1 点")
	# 翻一张：弹窗保持打开，视图里那张变亮
	scene._on_container_flip(0, 0)
	assert_true(scene.container_popup.is_open(), "翻牌后弹窗保持打开")
	view = scene.container_popup.view()
	assert_true(bool((view["entries"][0] as Dictionary).get("flipped", false)), "翻开的牌变亮")
	assert_false(bool((view["entries"][1] as Dictionary).get("flipped", false)), "没翻的还盖着")
	assert_eq(bs.ap, ap_before - 2, "翻牌 1 点")
	# 拿一张：免费入包，内容物少一件
	scene._on_container_take(0, 0)
	assert_true(scene.container_popup.is_open())
	assert_eq((scene.container_popup.view().get("entries", []) as Array).size(), 1, "拿走一件少一件")
	assert_eq(bs.inventory.size(), 1, "拿取免费入包")
	assert_eq(bs.ap, ap_before - 2, "拿取 0 行动力")
	# 翻+拿最后一张：拿空自动收窗
	scene._on_container_flip(0, 0)
	scene._on_container_take(0, 0)
	assert_false(scene.container_popup.is_open(), "拿空自动收窗")
	assert_eq(bs.inventory.size(), 2)
	# 空壳再点：开不动，不弹窗
	scene._on_card_action(0)
	assert_false(scene.container_popup.is_open(), "空壳没得开")
	assert_eq(str(bs.cell_card(bs.hero_site, 0).get("kind", "")), "chest", "空壳留场")

func test_container_popup_reopen_continues() -> void:
	var scene = _fresh_board_scene(7)
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BoardState = scene.board
	bs.current_site()["grid"] = [
		{"kind": "chest", "chest": "wood", "opened": false, "contents": [
			{"item_id": "yinzi", "flipped": false},
			{"item_id": "yinzi", "flipped": false}]},
	]
	scene._refresh()
	var ap_before: int = bs.ap
	scene._on_card_action(0)          # 开盖 + 弹窗
	scene._on_container_flip(0, 0)    # 翻一张
	scene.container_popup.close()     # 合窗走人（可翻一半走了再续）
	assert_false(scene.container_popup.is_open())
	# 回头再点容器：免费续翻视图，已翻开的还亮着
	scene._on_card_action(0)
	assert_true(scene.container_popup.is_open(), "再点已开的容器＝免费续翻")
	assert_eq(bs.ap, ap_before - 2, "开 1 + 翻 1，续开不收费")
	var view: Dictionary = scene.container_popup.view()
	assert_true(bool((view["entries"][0] as Dictionary).get("flipped", false)), "翻过的状态保留")
	assert_false(bool((view["entries"][1] as Dictionary).get("flipped", false)))
