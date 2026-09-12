extends GutTest

# 版图场景结构回归（C-028 明牌网格）：当前地块＝3 列卡牌网格（可滚动），
# 全场没有任何「无视」类旧按钮；小地块带牌数角标。

func before_each() -> void:
	# autoload 会话用例间复位（17 号隔离策略）：本用例从干净会话开始
	ExpeditionSession.reset_for_tests()

func test_board_scene_builds_grid_tile() -> void:
	var board_scene: PackedScene = load("res://scenes/board/board.tscn")
	var board = board_scene.instantiate()
	add_child_autofree(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var bs: BoardState = board.board
	assert_ne(bs, null, "场景应挂上 BoardState")
	# 当前地块节点：内含滚动网格，卡面数＝网格牌数
	var current_tile = null
	for node in board.get_node("Table/Continent").get_children():
		if node.get_script() == load("res://ui/board_tile.gd") and str(node.name).begins_with("@"):
			continue
	var tiles := board.get_node("Table/Continent").get_children().filter(func(n): return n.has_signal("card_action_requested"))
	for tile in tiles:
		if tile._pos == bs.hero_site:
			current_tile = tile
			break
	assert_ne(current_tile, null, "应找到当前地块组件")
	var scroll: ScrollContainer = _find_first(current_tile, "ScrollContainer")
	assert_ne(scroll, null, "当前地块应有滚动容器")
	var grid_box: GridContainer = _find_first(current_tile, "GridContainer")
	assert_ne(grid_box, null, "当前地块应有 3 列网格")
	assert_eq(grid_box.columns, 3, "网格固定 3 列")
	var faces: Array = []
	_traverse(current_tile, func(node: Node):
		if node.get_script() == load("res://ui/card_face.gd"):
			faces.append(node))
	assert_eq(faces.size(), bs.card_count(bs.hero_site), "卡面数＝当前地块牌数")
	# 悬停详情：每张活牌的格子上都挂着 tooltip（卡牌游戏标配——不认字也能看懂效果）
	# 注：lambda 按值捕获整型，计数要用数组
	var tips: Array = []
	_traverse(current_tile, func(node: Node):
		if node is Control and node != current_tile and not str((node as Control).tooltip_text).is_empty():
			tips.append(node))
	assert_eq(tips.size(), bs.card_count(bs.hero_site), "活牌 tooltip 数＝牌数")
	# 旧交互按钮彻底退场：全场不允许再出现「无视」
	var old_buttons: Array = []
	_traverse(board, func(node: Node):
		if node is Button and "无视" in str(node.text):
			old_buttons.append(node))
	assert_eq(old_buttons.size(), 0, "不应再有「无视」按钮（C-028 点击即互动）")

func _find_first(root: Node, klass: String) -> Node:
	var found: Array[Node] = []
	_traverse(root, func(node: Node):
		if node.get_class() == klass and found.is_empty():
			found.append(node))
	return found[0] if not found.is_empty() else null

func _traverse(node: Node, fn: Callable) -> void:
	fn.call(node)
	for child in node.get_children():
		_traverse(child, fn)
