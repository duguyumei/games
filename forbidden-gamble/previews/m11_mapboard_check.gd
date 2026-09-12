extends Node
# M11 节点制版图验收（D-059 接入 v1）：
# 图纸建图（49 节点/边价/动态带/出生/撤离/密道）→ 边价赶路扣行动力 →
# 两档视图（地块档当前面板 ↔ 大地图档节点印）→ 存档往返保边价与密道。

func _ready() -> void:
	ExpeditionSession.reset_for_tests()
	ExpeditionSession.start_run(7)
	var fails: Array[String] = []
	var bs: BoardState = ExpeditionSession.board_state

	# --- 1) 图纸建图 ---
	if bs.sites.size() != 49:
		fails.append("节点数 %d != 49" % bs.sites.size())
	if not bs.map_mode:
		fails.append("应进入节点制（map_mode）")
	var link_total := 0
	for pos in bs.sites:
		var links: Array = bs.sites[pos]["links"]
		link_total += links.size()
		for link in links:
			if not bs.sites.has(link):
				fails.append("边指向不存在的节点 %s" % link)
				break
			if not (bs.sites[link]["links"] as Array).has(pos):
				fails.append("边不是双向：%s ↔ %s" % [pos, link])
				break
	if link_total < 100:
		fails.append("双向边总数 %d < 100（连通可疑）" % link_total)
	var bands := {"浅": 0, "中": 0, "深": 0}
	var extracts := 0
	for pos in bs.sites:
		var band := str(bs.sites[pos].get("band", ""))
		if bands.has(band):
			bands[band] += 1
		else:
			fails.append("非法带别 %s" % band)
		if bool(bs.sites[pos].get("extract", false)):
			extracts += 1
	if extracts != 7:
		fails.append("撤离点 %d != 7" % extracts)
	if str(bs.sites[bs.hero_site].get("band", "")) != "浅":
		fails.append("出生点应在浅带（加权距离 0）")
	if bs.secret_links.size() != 2:
		fails.append("密道掷定 %d 条 != 2" % bs.secret_links.size())
	for secret in bs.secret_links:
		var sa: Vector2i = secret["a"]
		var sb: Vector2i = secret["b"]
		if not (bs.sites[sa]["links"] as Array).has(sb):
			fails.append("密道未接通 %s ↔ %s" % [sa, sb])
	var max_cost := 0
	for key in bs.link_costs:
		max_cost = maxi(max_cost, int(bs.link_costs[key]))
	if max_cost > 3:
		fails.append("边价越界（最大 %d）" % max_cost)
	print("[1] 建图：49节点 ✓ 双向边 %d 带 %s 撤离%d 密道%d 最大边价%d" % [link_total, str(bands), extracts, bs.secret_links.size(), max_cost])

	# --- 2) 边价赶路 ---
	var spent0 := bs.ap_spent
	var ap0 := bs.ap
	var origin := bs.hero_site
	var target := Vector2i(9999, 9999)
	var want_cost := 0
	for link in bs.sites[bs.hero_site]["links"]:
		var c := bs.travel_cost(bs.hero_site, link)
		if c >= 2 and bs.can_travel_to(link):
			target = link
			want_cost = c
			break
	if target == Vector2i(9999, 9999):
		for link in bs.sites[bs.hero_site]["links"]:
			if bs.can_travel_to(link):
				target = link
				want_cost = bs.travel_cost(bs.hero_site, link)
				break
	if target == Vector2i(9999, 9999):
		fails.append("出生点无可走邻点")
	else:
		if not bs.travel_to(target):
			fails.append("赶路失败（邻点应可走）")
		elif bs.ap_spent - spent0 != want_cost or ap0 - bs.ap != want_cost:
			fails.append("边价未生效（期望扣 %d，实际扣 %d）" % [want_cost, ap0 - bs.ap])
		elif bs.hero_site != target:
			fails.append("赶路未抵达")
	print("[2] 边价赶路：cost=%d 扣行动力 %d ✓" % [want_cost, ap0 - bs.ap])

	# --- 3) 两档视图 ---
	var board: Control = load("res://scenes/board/board.tscn").instantiate()
	add_child(board)
	await get_tree().process_frame
	await get_tree().process_frame
	var marks := _children_of(board, "Table/Continent", func(n: Node) -> bool:
		return n.get_script() == load("res://ui/map_node_mark.gd"))
	var tiles := _children_of(board, "Table/Continent", func(n: Node) -> bool:
		return n is Control and n.has_signal("card_action_requested"))
	if not marks.is_empty():
		fails.append("地块档不应有节点印")
	if tiles.size() != 1:
		fails.append("地块档应有且仅有当前面板（实际 %d）" % tiles.size())
	elif tiles[0]._pos != bs.hero_site:
		fails.append("面板不在当前节点")
	board._set_map_mode(true)
	await get_tree().process_frame
	marks = _children_of(board, "Table/Continent", func(n: Node) -> bool:
		return n.get_script() == load("res://ui/map_node_mark.gd"))
	if marks.size() != 49:
		fails.append("大地图档节点印 %d != 49" % marks.size())
	var edges_layer := _children_of(board, "Table/Continent", func(n: Node) -> bool:
		return n.get_script() == load("res://ui/map_edges.gd"))
	if edges_layer.size() != 1:
		fails.append("路网层缺失")
	board._set_map_mode(false)
	await get_tree().process_frame
	tiles = _children_of(board, "Table/Continent", func(n: Node) -> bool:
		return n is Control and n.has_signal("card_action_requested"))
	if tiles.size() != 1:
		fails.append("回地块档后当前面板丢失")
	print("[3] 两档视图：地块档面板1 地图档节点印%d 路网层%d" % [marks.size(), edges_layer.size()])

	# --- 4) 存档往返（边价/密道不丢） ---
	var dump: Dictionary = bs.to_dict()
	var restored := BoardState.new()
	if not restored.load("res://data/location_qingfeng.json", "res://data/items.json", "res://data/enemies.json"):
		fails.append("还原局加载配置失败")
	else:
		restored.from_dict(dump)
		if restored.link_costs.size() != bs.link_costs.size():
			fails.append("边价表往返丢失（%d → %d）" % [bs.link_costs.size(), restored.link_costs.size()])
		if restored.secret_links.size() != bs.secret_links.size():
			fails.append("密道往返丢失")
		if restored.travel_cost(origin, target) != want_cost:
			fails.append("还原局边价不一致")
	print("[4] 存档往返：边价%d条 密道%d条" % [restored.link_costs.size(), restored.secret_links.size()])

	if fails.is_empty():
		print("M11 PASS：图纸建图·边价赶路·两档视图·存档往返全过")
		get_tree().quit(0)
	else:
		print("M11 FAIL：", "; ".join(fails))
		get_tree().quit(1)

func _children_of(root: Node, path: String, pred: Callable) -> Array:
	var out: Array = []
	var holder: Node = root.get_node(path)
	for child in holder.get_children():
		if child is Control and pred.call(child):
			out.append(child)
	return out
