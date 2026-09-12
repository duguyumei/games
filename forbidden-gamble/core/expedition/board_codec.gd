class_name BoardCodec
extends RefCounted

# BoardState 存档编解码（存档形状的唯一 Owner）：
# Vector2i 无法直接进 JSON——sites 字典键编码为 "x,y" 字符串，pos/links 编码为 [x, y]。
# 导出/还原经 b（BoardState）读写字段；rng.state 一并入档（uint64 经字符串存取，
# 只作测试辅助，正常游玩不保证世界线一致）。事件日志与稀有度缓存是瞬态，不入档。

# 导出全部牌阵状态（玩家气血在 RunState 层）。
static func to_dict(b: BoardState) -> Dictionary:
	var sites_data := {}
	for pos in b.sites:
		var site: Dictionary = b.sites[pos]
		var s: Dictionary = site.duplicate(true)
		s["pos"] = _vec_to_arr(site["pos"])
		var links: Array = []
		for link in site["links"]:
			links.append(_vec_to_arr(link))
		s["links"] = links
		sites_data[_vkey(pos)] = s
	return {
		"seed": b.seed,
		"rng_state": str(b.rng.state),
		"ap": b.ap,
		"ap_spent": b.ap_spent,
		"alert_level": b.alert_level,
		"pursuers_spawned": b.pursuers_spawned,
		"qixi": b.qixi,
		"hunt_count": b.hunt_count,
		"hunt_queue": b.hunt_queue,
		"guardians_off": b.guardians_off,
		"hunter": _hunter_to_dict(b.hunter),
		"outcome": b.outcome,
		"hero_site": _vec_to_arr(b.hero_site),
		"sneak_ap": b.sneak_ap,
		"battle_cell": b.battle_cell,
		"battle_enemy_first": b.battle_enemy_first,
		"chain_queue": b.chain_queue.duplicate(),
		"inventory": b.inventory.duplicate(true),
		"pouch": b.pouch.duplicate(true),
		"link_costs": b.link_costs.duplicate(),
		"secret_links": _secrets_to_dict(b.secret_links),
		"equipped": {
			"weapon": (b.equipped.get("weapon", {}) as Dictionary).duplicate(true),
			"armor": (b.equipped.get("armor", {}) as Dictionary).duplicate(true),
			"bag": (b.equipped.get("bag", {}) as Dictionary).duplicate(true),
		},
		"sites": sites_data,
	}

# 追杀者状态序列化（site 是 Vector2i；空追杀返回空字典）。
static func _hunter_to_dict(hunter: Dictionary) -> Dictionary:
	if hunter.is_empty():
		return {}
	var out := hunter.duplicate()
	out["site"] = _vec_to_arr(hunter.get("site", Vector2i.ZERO))
	return out

# 密道对序列化（两端 Vector2i → [x, y]）。
static func _secrets_to_dict(secrets: Array) -> Array:
	var out: Array = []
	for secret in secrets:
		var s: Dictionary = secret
		out.append({"a": _vec_to_arr(s.get("a", Vector2i.ZERO)), "b": _vec_to_arr(s.get("b", Vector2i.ZERO))})
	return out

static func _secrets_from_dict(data: Array) -> Array:
	var out: Array = []
	for entry in data:
		if not entry is Dictionary:
			continue
		var s: Dictionary = entry
		out.append({"a": _arr_to_vec(s.get("a", [0, 0])), "b": _arr_to_vec(s.get("b", [0, 0]))})
	return out

static func _hunter_from_dict(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var out: Dictionary = data.duplicate()
	out["site"] = _arr_to_vec(data.get("site", [0, 0]))
	out["move_in"] = int(out.get("move_in", 1))
	out["life"] = int(out.get("life", -1))
	out["avatar"] = bool(out.get("avatar", true))
	out["prox"] = int(out.get("prox", 0))
	out["cell"] = int(out.get("cell", -1))
	out["primed"] = bool(out.get("primed", false))
	return out

# 从 to_dict 的数据整体还原（需先 load 配置）。
static func from_dict(b: BoardState, data: Dictionary) -> void:
	b.seed = int(data.get("seed", 0))
	b.rng.seed = b.seed
	b.rng.state = int(str(data.get("rng_state", "0")))
	b.ap = int(data.get("ap", 0))
	b.ap_spent = int(data.get("ap_spent", 0))
	b.alert_level = int(data.get("alert_level", 0))
	b.pursuers_spawned = int(data.get("pursuers_spawned", 0))
	b.qixi = int(data.get("qixi", 0))
	b.hunt_count = int(data.get("hunt_count", 0))
	b.hunt_queue = int(data.get("hunt_queue", 0))
	b.guardians_off = bool(data.get("guardians_off", false))
	b.hunter = _hunter_from_dict(data.get("hunter", {}))
	b.outcome = str(data.get("outcome", ""))
	b.hero_site = _arr_to_vec(data.get("hero_site", [0, 0]))
	b.sneak_ap = int(data.get("sneak_ap", 0))
	b.battle_cell = int(data.get("battle_cell", -1))
	b.battle_enemy_first = bool(data.get("battle_enemy_first", false))
	b.chain_queue = []
	for cell in data.get("chain_queue", []):
		b.chain_queue.append(int(cell))
	b.inventory = _read_stacks(data.get("inventory", []))
	b.pouch = _read_stacks(data.get("pouch", []))
	# 节点制边价与密道（旧档没有＝空，走兜底）
	b.link_costs = {}
	var lc: Dictionary = data.get("link_costs", {})
	for key in lc:
		b.link_costs[str(key)] = int(lc[key])
	b.secret_links = _secrets_from_dict(data.get("secret_links", []))
	var equipped_data: Dictionary = data.get("equipped", {})
	b.equipped = read_equipped(equipped_data)
	b.sites.clear()
	var sites_data: Dictionary = data.get("sites", {})
	for key in sites_data:
		if not sites_data[key] is Dictionary:
			continue
		var pos := _parse_vkey(str(key))
		var s: Dictionary = (sites_data[key] as Dictionary).duplicate(true)
		s["pos"] = pos
		var links: Array = []
		for link in s.get("links", []):
			links.append(_arr_to_vec(link))
		s["links"] = links
		s["grid"] = _read_grid(s.get("grid", []))
		b.sites[pos] = s

static func _vkey(pos: Vector2i) -> String:
	return "%d,%d" % [pos.x, pos.y]

# 地块网格还原：空字典＝洞原样保留；牌字典整型化（alert 等字段 JSON 往返会变 float）。
static func _read_grid(data: Array) -> Array:
	var out: Array = []
	for entry in data:
		if not entry is Dictionary or (entry as Dictionary).is_empty():
			out.append({})
			continue
		var card: Dictionary = intify_numbers((entry as Dictionary).duplicate(true))
		if card.has("alert"):
			card["alert"] = int(card["alert"])
		out.append(card)
	return out

# 堆叠条目数组还原（背包/锦囊同构）：JSON 数字一律解析成 float，intify 归一回 int
# （定义加载时已归一，这里把 JSON 往返再吃回来的 float 洗掉，两侧全等才成立）。
static func _read_stacks(data: Array) -> Array:
	var out: Array = []
	for entry in data:
		if not entry is Dictionary:
			continue
		var stack: Dictionary = intify_numbers((entry as Dictionary).duplicate(true))
		stack["qty"] = int(stack.get("qty", 1))
		stack["value"] = int(stack.get("value", 0))
		if stack.has("uid"):
			stack["uid"] = int(stack["uid"])
		if stack.has("dur"):
			stack["dur"] = int(stack["dur"])
		out.append(stack)
	return out

# 递归整型化：把值等于自身取整的 float 换成 int（JSON 无整数类型，物品定义加载时
# 归一一次，活局面与存档还原局面的数字类型从此一致，全等比较才可能成立）。
static func intify_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key in value:
			out[key] = intify_numbers(value[key])
		return out
	if value is Array:
		var arr: Array = []
		for item in value:
			arr.append(intify_numbers(item))
		return arr
	if value is float and is_equal_approx(value, roundf(value)):
		return int(value)
	return value

# 穿戴槽条目还原：缺失/非字典/空字典＝空槽。
static func _read_equipped_entry(data: Dictionary, slot: String) -> Dictionary:
	var value = data.get(slot, {})
	if not value is Dictionary or (value as Dictionary).is_empty():
		return {}
	return _read_stacks([value])[0]

# 整副穿戴栏还原（兵器/护具/行囊三槽）：远征档 v6 与 meta 档 v3 共用（C-027：
# 穿戴是跨局角色状态，撤离带回的耐久原样存取）。
static func read_equipped(data: Dictionary) -> Dictionary:
	return {
		"weapon": _read_equipped_entry(data, "weapon"),
		"armor": _read_equipped_entry(data, "armor"),
		"bag": _read_equipped_entry(data, "bag"),
	}
static func _parse_vkey(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func _vec_to_arr(pos: Vector2i) -> Array:
	return [pos.x, pos.y]

static func _arr_to_vec(arr: Array) -> Vector2i:
	if arr.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(arr[0]), int(arr[1]))
