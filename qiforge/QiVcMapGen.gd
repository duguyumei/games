## VC 制楼层地图生成器（2026-11-01 地图轮；纯逻辑无 UI）。
## 每层＝一张连续网格地图（用户裁定「原版可走回头路——不就是一个地图吗」）：
## 房间矩形刻空＋L 形走廊顺连（原版 RoomSpring/PathMST 的我们尺度等价物），
## 明雷/宝箱/铲子撒点（离起点保距）。种子确定性——同种子同图（探针断言）。
extends RefCounted

const W := 44
const H := 24

## 生成一层：spec＝QiVcData.FLOORS[i]（＋seed/floor 掺种子）。
## 返回 {w, h, grid(行主序 0 墙 1 地), start: Vector2i, entities: [{type, cell, id}]}
## type ∈ enemy/chest/shovel/boss；grid[y][x]。
static func generate(seed: int, floor_idx: int, spec: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + floor_idx * 7919
	var grid: Array = []
	for y in H:
		var row: Array = []
		row.resize(W)
		row.fill(0)
		grid.push_back(row)
	# —— 房间：5~7 个矩形（4~9 × 3~6）随机刻空 ——
	var rooms: Array = []
	var n_rooms := 5 + rng.randi_range(0, 2)
	for i in n_rooms:
		var rw := rng.randi_range(4, 9)
		var rh := rng.randi_range(3, 6)
		var rx := rng.randi_range(1, W - rw - 2)
		var ry := rng.randi_range(1, H - rh - 2)
		for y in range(ry, ry + rh):
			for x in range(rx, rx + rw):
				grid[y][x] = 1
		rooms.push_back({"c": Vector2i(rx + rw / 2, ry + rh / 2), "r": Rect2i(rx, ry, rw, rh)})
	# —— 走廊：顺连相邻房间中心（L 形，先横后竖/先竖后横随机）＋一条回头环 ——
	for i in range(rooms.size() - 1):
		_carve_l(grid, rooms[i]["c"], rooms[i + 1]["c"], rng)
	if rooms.size() > 3:
		_carve_l(grid, rooms[rooms.size() - 1]["c"], rooms[0]["c"], rng)
	# —— 撒点：起点＝首房中心；实体取离起点 ≥5 的地格 ——
	var start: Vector2i = rooms[0]["c"]
	var cells := _floor_cells(grid)
	var far: Array = []
	for c in cells:
		if c.distance_to(start) >= 5:
			far.push_back(c)
	# far 保序打散（种子确定性）
	for i in range(far.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = far[i]
		far[i] = far[j]
		far[j] = t
	var entities: Array = []
	var used := {start: true}
	var pop_far := func() -> Vector2i:
		while not far.is_empty():
			var c: Vector2i = far.pop_front()
			if not used.has(c):
				used[c] = true
				return c
		return start
	if String(spec.get("boss", "")) != "":
		# Boss 层：Boss 摆最远房中心（保距）
		var best: Vector2i = start
		for r in rooms:
			if (r["c"] as Vector2i).distance_to(start) > best.distance_to(start):
				best = r["c"]
		entities.push_back({"type": "boss", "cell": best, "id": String(spec["boss"])})
	for i in int(spec.get("enemies", 0)):
		var pool: Array = spec.get("pool", [])
		if pool.is_empty():
			break
		entities.push_back({"type": "enemy", "cell": pop_far.call(),
			"id": String(pool[rng.randi_range(0, pool.size() - 1)])})
	for i in int(spec.get("chests", 0)):
		entities.push_back({"type": "chest", "cell": pop_far.call(), "id": ""})
	if String(spec.get("boss", "")) == "":
		entities.push_back({"type": "shovel", "cell": pop_far.call(), "id": ""})
	return {"w": W, "h": H, "grid": grid, "start": start, "entities": entities}

## 楼层图统一入口：spec.fixed 走固定图（新手教程），否则随机生成。
static func floor_map(seed: int, floor_idx: int, spec: Dictionary) -> Dictionary:
	if String(spec.get("fixed", "")) == "tutorial":
		return tutorial_floor(spec)
	return generate(seed, floor_idx, spec)

## 新手教程层（2026-11-03 用户裁定：「新手战斗第一关 就是一个蝙蝠 没其他的了」；
## 2026-11-04 续令：下一场教学战斗＝两蝠）：
## 一条短直路——起点底端 → 首战一蝠（y9）→ 二战两蝠（y6）→ 顶上出口。
## 开局即自动进首战（QiVcRoot 首敌直入）。
static func tutorial_floor(spec: Dictionary) -> Dictionary:
	var w := 13
	var h := 17
	var grid: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(0)
		grid.push_back(row)
	for y in range(3, 15):    # 一条竖路（x=8，起点 y=14 → 出口 y=3）
		grid[y][8] = 1
	var pool: Array = spec.get("pool", [])
	var bat := "tut01" if pool.is_empty() else String(pool[0])
	# 敌阵队列制（2026-11-07 v0.1）：group 嵌套＝排（index 0 前排）——
	# 第一场一排 1（20 血学甲蝠＝pool[0]）／第二场一排 3（2026-11-08 用户令调参：
	# 中 15 血·壮、边 5 血——对位原版预览「中间 16 两边 8」的分配手感）／
	# 宝箱（内容物＝内功「连击堆叠」——连击靠宝物解锁）／第三场一排 5（从下往上递进，出口在最上）
	var entities := [
		{"type": "enemy", "cell": Vector2i(8, 10), "id": bat, "group": [[bat]]},
		{"type": "enemy", "cell": Vector2i(8, 8), "id": "tut_mid", "group": [["tut_side", "tut_mid", "tut_side"]]},
		{"type": "chest", "cell": Vector2i(8, 7), "id": "combo_stack"},
		{"type": "enemy", "cell": Vector2i(8, 5), "id": bat, "group": [[bat, bat, bat, bat, bat]]},
		{"type": "exit", "cell": Vector2i(8, 3), "id": ""},
	]
	return {"w": w, "h": h, "grid": grid, "start": Vector2i(8, 14), "entities": entities}

static func _carve_l(grid: Array, a: Vector2i, b: Vector2i, rng: RandomNumberGenerator) -> void:
	var horiz_first := rng.randf() < 0.5
	if horiz_first:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			grid[a.y][x] = 1
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			grid[y][b.x] = 1
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			grid[y][a.x] = 1
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			grid[b.y][x] = 1

static func _floor_cells(grid: Array) -> Array:
	var out: Array = []
	for y in H:
		for x in W:
			if grid[y][x] == 1:
				out.push_back(Vector2i(x, y))
	return out

## BFS 寻路（走地格，可回头；遇实体由调用方截停）。返 null＝不可达。
static func path(map_data: Dictionary, from: Vector2i, to: Vector2i) -> Variant:
	var grid: Array = map_data["grid"]
	if from == to:
		return [from]
	if not _in_bounds(map_data, to) or grid[to.y][to.x] != 1:
		return null
	var prev := {from: Vector2i(-9999, -9999)}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if not _in_bounds(map_data, nxt) or grid[nxt.y][nxt.x] != 1 or prev.has(nxt):
				continue
			prev[nxt] = cur
			if nxt == to:
				var out: Array = [to]
				var p: Vector2i = cur
				while p != Vector2i(-9999, -9999):
					out.push_front(p)
					p = prev[p]
				return out
			queue.push_back(nxt)
	return null

static func _in_bounds(map_data: Dictionary, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < int(map_data["w"]) and c.y < int(map_data["h"])

## 全地格连通性（自 start BFS 覆盖所有地格）——探针断言用
static func all_reachable(map_data: Dictionary) -> bool:
	var grid: Array = map_data["grid"]
	var total := 0
	for y in int(map_data["h"]):
		for x in int(map_data["w"]):
			if grid[y][x] == 1:
				total += 1
	var seen := {map_data["start"]: true}
	var queue: Array = [map_data["start"]]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if _in_bounds(map_data, nxt) and grid[nxt.y][nxt.x] == 1 and not seen.has(nxt):
				seen[nxt] = true
				queue.push_back(nxt)
	return seen.size() >= total
