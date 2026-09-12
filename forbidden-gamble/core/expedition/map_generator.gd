class_name MapGenerator
extends RefCounted

# 大陆与卡牌工厂（BoardState 的生成模块）：
# - 预置地块大陆生长（frontier 扩张，连通由生长保证）
# - 地点卡藏入地块网格末尾；箱子内容物按掉落表掷定（稀有度权重）
# - 运行期也被规则调用：开地点卡长新地块、敌人变遗体、警戒落小镇物牌
# 经 setup 注入 BoardState 属主，读 config/items/enemies/rng/sites 等活引用。
# 铁律：卡牌不消失只转化（本模块只造牌，不消牌）。

var b: BoardState
var _rarity_cache: Dictionary = {}

func setup(owner: BoardState) -> void:
	b = owner

func reset_cache() -> void:
	_rarity_cache = {}

# ---------- 大陆生长 ----------

# 预置地块大陆：从入口向外放常规地点，连通由生长保证；地点卡随后藏入网格。
func generate_continent() -> void:
	var continent: Dictionary = b.config.get("continent", {})
	var count := int(continent.get("normal_sites", 0))
	var pool: Array = continent.get("type_pool", [])
	var frontier: Array[Vector2i] = [b.hero_site]
	for i in range(count):
		frontier = frontier.filter(func(p: Vector2i) -> bool: return not empty_neighbors(p).is_empty())
		if frontier.is_empty() or pool.is_empty():
			break
		var base: Vector2i = frontier[b.rng.randi_range(0, frontier.size() - 1)]
		var empties := empty_neighbors(base)
		var pos: Vector2i = empties[b.rng.randi_range(0, empties.size() - 1)]
		var site := make_site(pick(pool), pos)
		b.sites[pos] = site
		b.sites[base]["links"].append(pos)
		site["links"].append(base)
		frontier.append(pos)
	_hide_location_cards(continent)

func empty_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in BoardState.DIRECTIONS:
		var candidate: Vector2i = pos + dir
		if not b.sites.has(candidate):
			out.append(candidate)
	return out

# ---------- 节点制大陆（D-059：读锚点图纸建图） ----------

# 图纸建图：节点＝舆图锚点像素键，边＝带价通道；出生从图纸掷定，
# 带别按离出生点的加权距离动态算（D-051：≤2 浅／3–5 中／≥6 深），
# 密道每局从候选里掷定几条；地物按「动态带 × 枢纽/途经」分层掷（D-059 tier）。
# 途经点牌数封顶（way_cards）——两三张牌的小面板；枢纽用完整模板。
func generate_from_map(map_cfg: Dictionary) -> void:
	var doc: Dictionary = DataRepo.load_json(str(map_cfg.get("path", "")))
	if doc.is_empty():
		push_error("[MapGenerator] 图纸缺失或为空: " + str(map_cfg.get("path", "")))
		return
	var size: Array = doc.get("image_size", [1672, 940])
	var w := float(size[0])
	var h := float(size[1])
	# 节点表：id -> {pos, name, tier, extract…}
	var nodes := {}
	for n in doc.get("nodes", []):
		var id := str(n["id"])
		nodes[id] = {
			"pos": Vector2i(int(round(float(n["x"]) * w)), int(round(float(n["y"]) * h))),
			"name": str(n.get("name", id)),
			"tier": str(n.get("tier", "way")),
		}
	# 骨架：全部节点立壳（先无牌，带别算完再填内容）
	for id in nodes:
		var node: Dictionary = nodes[id]
		b.sites[node["pos"]] = {
			"type": "", "name": node["name"], "pos": node["pos"],
			"tier": node["tier"], "extract": false, "band": "浅",
			"grid": [], "links": [], "explored": false,
		}
	# 边：双向 links + 边价表
	for e in doc.get("edges", []):
		var pa: Vector2i = nodes[str(e["a"])]["pos"]
		var pb: Vector2i = nodes[str(e["b"])]["pos"]
		if pa == pb:
			continue
		if pb not in (b.sites[pa]["links"] as Array):
			b.sites[pa]["links"].append(pb)
		if pa not in (b.sites[pb]["links"] as Array):
			b.sites[pb]["links"].append(pa)
		b.link_costs[_edge_key(pa, pb)] = int(e.get("cost", 1))
	# 出生：图纸免费出生点掷一
	var spawn_ids: Array = []
	for s in doc.get("spawns", []):
		if str(s.get("cost", "free")) == "free":
			spawn_ids.append(str(s["node"]))
	if spawn_ids.is_empty():
		spawn_ids = [str(nodes.keys()[0])]
	var spawn_pos: Vector2i = nodes[pick(spawn_ids)]["pos"]
	b.hero_site = spawn_pos
	b.sites[spawn_pos]["explored"] = true
	# 撤离点标记
	for x in doc.get("extracts", []):
		if nodes.has(str(x["node"])):
			b.sites[nodes[str(x["node"])]["pos"]]["extract"] = true
	# 密道：候选掷定几条（D-051 每局随机）
	var secret_cost := int(map_cfg.get("secret_cost", 2))
	var candidates: Array = doc.get("secrets", []).duplicate()
	var rolls := mini(int(map_cfg.get("secret_rolls", 2)), candidates.size())
	for i in range(rolls):
		var idx := b.rng.randi_range(0, candidates.size() - 1)
		var secret: Dictionary = candidates.pop_at(idx)
		var pa: Vector2i = nodes[str(secret["a"])]["pos"]
		var pb: Vector2i = nodes[str(secret["b"])]["pos"]
		if pa == pb:
			continue
		if pb not in (b.sites[pa]["links"] as Array):
			b.sites[pa]["links"].append(pb)
		if pa not in (b.sites[pb]["links"] as Array):
			b.sites[pb]["links"].append(pa)
		b.link_costs[_edge_key(pa, pb)] = secret_cost
		b.secret_links.append({"a": pa, "b": pb})
	# 动态带（D-051）：离出生点加权距离
	var dists := _weighted_distances(spawn_pos)
	for pos in b.sites:
		var d := int(dists.get(pos, 999))
		b.sites[pos]["band"] = ("浅" if d <= 2 else ("中" if d <= 5 else "深"))
	# 地物与牌：按「动态带 × tier」掷；途经点封顶牌数（出生点同填——入口也要有货）
	var pools: Dictionary = map_cfg.get("pools", {})
	var way_cap := int(map_cfg.get("way_cards", 3))
	for pos in b.sites:
		_fill_site_content(pos, pools, way_cap)
	_hide_shortcut_cards()

# 单点内容填充：按带与 tier 掷地物类型，套模板生成牌网格（途经点截短）。
func _fill_site_content(pos: Vector2i, pools: Dictionary, way_cap: int) -> void:
	var site: Dictionary = b.sites[pos]
	var tier := str(site.get("tier", "way"))
	var type_id := _roll_type(pools, str(site.get("band", "浅")), tier)
	var rolled := make_site(type_id, pos, way_cap if tier != "hub" else -1)
	site["type"] = type_id
	site["grid"] = rolled["grid"]

func _roll_type(pools: Dictionary, band: String, tier: String) -> String:
	var band_pools: Dictionary = pools.get(band, {})
	var pool: Array = band_pools.get(tier, [])
	if pool.is_empty():
		pool = band_pools.get("way", [])
	if pool.is_empty():
		pool = b.config.get("continent", {}).get("type_pool", [])
	return pick(pool)

# 捷径类地点卡照旧藏（成长类在节点制下无处可长，不藏；撤离已由图纸原生提供）。
func _hide_shortcut_cards() -> void:
	var defs: Dictionary = b.config.get("location_cards", {})
	var candidates: Array = []
	for pos in b.sites:
		if pos != b.hero_site:
			candidates.append(pos)
	for spec in b.config.get("continent", {}).get("hide_cards", []):
		var def: Dictionary = defs.get(str(spec.get("location", "")), {})
		if str(def.get("effect", "")) != "shortcut":
			continue
		for i in range(int(spec.get("count", 1))):
			if candidates.is_empty():
				return
			var idx := b.rng.randi_range(0, candidates.size() - 1)
			var pos: Vector2i = candidates[idx]
			candidates.remove_at(idx)
			(b.sites[pos]["grid"] as Array).append({"kind": "location", "location": str(spec.get("location", ""))})

# Dijkstra 加权距离（边价即权重；图纸规模 49 点，朴素实现足够）。
func _weighted_distances(from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var frontier: Array[Vector2i] = [from]
	while not frontier.is_empty():
		frontier.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return int(dist.get(x, 999999)) < int(dist.get(y, 999999)))
		var here: Vector2i = frontier.pop_front()
		var d_here := int(dist.get(here, 999999))
		for link in (b.sites.get(here, {}).get("links", []) as Array):
			var nd := d_here + _cost_between(here, link)
			if nd < int(dist.get(link, 999999)):
				dist[link] = nd
				if not frontier.has(link):
					frontier.append(link)
	return dist

func _cost_between(a: Vector2i, c: Vector2i) -> int:
	var k := _edge_key(a, c)
	if b.link_costs.has(k):
		return int(b.link_costs[k])
	var rk := _edge_key(c, a)
	if b.link_costs.has(rk):
		return int(b.link_costs[rk])
	return 1

static func _edge_key(a: Vector2i, c: Vector2i) -> String:
	return "%d,%d|%d,%d" % [a.x, a.y, c.x, c.y]


# 地点卡藏法：按 continent.hide_cards 把特殊地点卡压进随机非入口地块的网格末尾。
func _hide_location_cards(continent: Dictionary) -> void:
	var candidates: Array[Vector2i] = []
	for pos in b.sites:
		if pos != b.hero_site:
			candidates.append(pos)
	for spec in continent.get("hide_cards", []):
		for i in range(int(spec.get("count", 1))):
			if candidates.is_empty():
				return
			var idx := b.rng.randi_range(0, candidates.size() - 1)
			var pos: Vector2i = candidates[idx]
			candidates.remove_at(idx)
			(b.sites[pos]["grid"] as Array).append({"kind": "location", "location": str(spec.get("location", ""))})

func shuffle(deck: Array) -> void:
	for i in range(deck.size() - 1, 0, -1):
		var j := b.rng.randi_range(0, i)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp

# ---------- 地块与卡牌工厂 ----------

# card_limit：途经点封顶牌数（D-059 tier 分层）；-1＝完整模板（枢纽）。
func make_site(type_id: String, pos: Vector2i, card_limit := -1) -> Dictionary:
	var template: Dictionary = b.config.get("site_types", {}).get(type_id, {})
	var site := {
		"type": type_id,
		"name": str(template.get("name", type_id)),
		"pos": pos,
		"extract": bool(template.get("extract", false)),
		"grid": [],
		"links": [],
		"explored": false,
	}
	var cards: Array = []
	for spec in template.get("cards", []):
		cards.append(make_card(spec))
	shuffle(cards)
	if card_limit >= 0 and cards.size() > card_limit:
		cards = cards.slice(0, card_limit)
	for card in cards:
		site["grid"].append(card)
	# 沉底牌按配置顺序压在网格末尾（可放地点卡，保底可解锁）
	for spec in template.get("bottom", []):
		site["grid"].append(make_card(spec))
	return site

func make_card(spec: Dictionary) -> Dictionary:
	match str(spec.get("kind", "")):
		"scatter":
			return {"kind": "scatter", "item_id": pick(spec.get("table", b.config.get("scatter_table", [])))}
		"enemy":
			return {"kind": "enemy", "enemy_id": pick(spec.get("table", [])), "alert": 0}
		"chest":
			var chest_id := str(spec.get("chest", "wood"))
			return {"kind": "chest", "chest": chest_id, "opened": false, "contents": roll_contents(chest_id)}
		"npc":
			return {"kind": "npc", "npc_id": pick(spec.get("table", []))}
		"location":
			return {"kind": "location", "location": str(spec.get("location", ""))}
	return {"kind": "unknown"}

# 遗体是容器：按敌人的 loot_chest 档次装东西（弹窗里逐张翻牌，D-028）。
func make_body(enemy_id: String) -> Dictionary:
	var loot_chest := str(b.enemies.get(enemy_id, {}).get("loot_chest", "pockets_default"))
	return {"kind": "body", "enemy_id": enemy_id, "chest": loot_chest, "opened": false, "contents": roll_contents(loot_chest)}

# ---------- 掉落掷定 ----------

# 内容物条目统一 {item_id, flipped}：生成时全暗着，开盖后进弹窗逐张翻。
func roll_contents(chest_id: String) -> Array:
	var chest: Dictionary = b.config.get("chests", {}).get(chest_id, {})
	var contents: Array = []
	for i in range(int(chest.get("draws", 3))):
		var item_id := ""
		if chest.has("table"):
			item_id = pick(chest.get("table", []))
		else:
			item_id = _roll_item_id_of_rarity(_roll_rarity(chest.get("weights", {})))
		if not item_id.is_empty():
			contents.append({"item_id": item_id, "flipped": false})
	return contents

func _roll_rarity(weights: Dictionary) -> String:
	var total := 0
	var valid: Dictionary = {}
	for rarity in weights:
		var w := int(weights[rarity])
		if w > 0 and not _items_of_rarity(str(rarity)).is_empty():
			valid[rarity] = w
			total += w
	if total <= 0:
		return ""
	var roll := b.rng.randi_range(1, total)
	for rarity in valid:
		roll -= int(valid[rarity])
		if roll <= 0:
			return str(rarity)
	return str(valid.keys()[0])

func _roll_item_id_of_rarity(rarity: String) -> String:
	var pool: Array = _items_of_rarity(rarity)
	if pool.is_empty():
		return ""
	return str(pool[b.rng.randi_range(0, pool.size() - 1)].get("id", ""))

func _items_of_rarity(rarity: String) -> Array:
	if not _rarity_cache.has(rarity):
		var fresh: Array = []
		for item_id in b.items:
			var item: Dictionary = b.items[item_id]
			# no_drop：掉落黑名单（辟谷丹等"禁地内搜不到"的门派垄断物）
			if str(item.get("rarity", "")) == rarity and not bool(item.get("no_drop", false)):
				fresh.append(item)
		_rarity_cache[rarity] = fresh
	return _rarity_cache[rarity]

func pick(table: Array) -> String:
	if table.is_empty():
		return ""
	return str(table[b.rng.randi_range(0, table.size() - 1)])
