class_name HuntSystem
extends RefCounted

# 镇物追杀（M2/C-023；C-028 改 AP 钟＋网格压顶＋迫近）：
# 气息（累计搜刮价值）过线 → 分身/真身追杀。
# - 统一世界钟：你每花 1 点行动力它动一拍（on_ap_spent）——分身寿命倒数、行动节拍倒数、
#   压顶迫近累计都在这口钟上；战斗 0 行动力不推钟。
# - 分身：出生压在你当前地块网格前排；每 avatar_interval 点行动力走一步；
#   寿命 avatar_life 点行动力后气尽自散，散后等气息下一条线再来。
# - 真身：追杀触发时禁地状态 ≥3 级即登场（按次判，在场不替换），永不消散。
# - 瞬移条款：轮到它行动时图距离 > teleport_distance → 直接落到你当前地块压顶。
# - 压顶＝它的卡占你地块网格的一格（可迎战）；迫近：压顶期间你每花 1 点行动力 +1，
#   满 proximity_cap 层 → 它主动扑上来（被袭击，敌方先手）。你离开地块即归零重积。
# - 非玩家地块只做驻留标记（hunter.site），不占网格；到你地块才压顶。
# 状态全部挂在 BoardState（qixi/hunter/hunt_count/hunt_queue/guardians_off），
# 本模块只管规则（owner 注入，与 MapGenerator 同构）。

var b: BoardState

func setup(owner: BoardState) -> void:
	b = owner

func _cfg() -> Dictionary:
	return b.config.get("hunt", {})

# ---------- 统一 AP 钟（玩家每花行动力调一次，amount 为点数） ----------

func on_ap_spent(amount: int) -> void:
	if b.guardians_off:
		return
	for i in range(amount):
		_tick()

func _tick() -> void:
	if b.hunter.is_empty():
		if b.hunt_queue > 0:
			b.hunt_queue -= 1
			_spawn()
		return
	# 分身寿命：每点行动力 -1，归零自散（本拍不再行动）
	if bool(b.hunter.get("avatar", false)):
		b.hunter["life"] = int(b.hunter.get("life", 0)) - 1
		if int(b.hunter["life"]) <= 0:
			_dissipate()
			return
	# 压顶迫近：它盯着你，你花力气它逼近一层（刚积满的那次行动不咬，下一次才咬）
	if _hunter_site() == b.hero_site:
		var cap := int(_cfg().get("proximity_cap", 3))
		var before := int(b.hunter.get("prox", 0))
		var prox := mini(cap, before + 1)
		b.hunter["prox"] = prox
		if before < cap and prox >= cap:
			b.hunter["primed"] = false
			b.log_event("%s 的杀意已到顶——再动一下它就扑上来了！" % _hunter_name())
	# 行动节拍
	b.hunter["move_in"] = int(b.hunter.get("move_in", 1)) - 1
	if int(b.hunter["move_in"]) > 0:
		return
	b.hunter["move_in"] = _next_interval()
	# 瞬移条款：轮到它行动时图距离过远 → 直接落顶（橡皮筋反风筝）
	if _graph_distance(_hunter_site(), b.hero_site) > int(_cfg().get("teleport_distance", 3)):
		_teleport_to_player()
		return
	if _hunter_site() == b.hero_site:
		_rise_to_top()
	else:
		_step_toward_player()

# 玩家搬走一件东西：气息累计；连过几线就排几只（同屏只一只）。
func on_loot(value: int) -> void:
	if b.guardians_off or value <= 0:
		return
	b.qixi += value
	var crossed := false
	while b.qixi >= _next_line():
		b.hunt_count += 1
		crossed = true
		if b.hunter.is_empty():
			_spawn()
		else:
			b.hunt_queue += 1
	if crossed and b.hunt_queue > 0:
		b.log_event("气息愈重——禁地里有什么东西记下了你。（下一只追杀者已在途中）")

func _next_line() -> int:
	return int(_cfg().get("first", 120)) + b.hunt_count * int(_cfg().get("step", 160))

# 玩家抵达地块：镇物驻留此处 → 压顶。
func on_player_arrived() -> void:
	if not b.hunter.is_empty() and _hunter_site() == b.hero_site:
		_rise_to_top()

# 玩家离开地块：镇物的压顶卡撤下（回驻留标记，不占网格），迫近归零重积。
func on_player_departed(old_site: Vector2i) -> void:
	if not b.hunter.is_empty() and _hunter_site() == old_site and old_site != b.hero_site:
		b.hunter["prox"] = 0
		b.hunter["primed"] = false
		_remove_card()

# 追杀者被击杀（战斗胜利，BoardState.resolve_battle_result 调用）。
func on_hunter_slain() -> void:
	var was_avatar := bool(b.hunter.get("avatar", false))
	b.hunter = {}
	if was_avatar:
		if b.hunt_queue > 0:
			b.log_event("分身散了，可气息未消——追杀仍会再来。")
	else:
		_disable_guardians()

# ---------- 内部 ----------

func _spawn() -> void:
	var true_body := b.alert_level >= 3
	b.hunter = {
		"enemy_id": str(_cfg().get("true_body", "")) if true_body else str(_cfg().get("avatar", "")),
		"avatar": not true_body,
		"site": b.hero_site,
		"move_in": 1,
		"life": -1 if true_body else int(_cfg().get("avatar_life", 10)),
		"prox": 0,
		"primed": false,
		"cell": -1,
	}
	b.hunter["move_in"] = _next_interval()
	_rise_to_top()
	if true_body:
		b.log_event("—— 山风骤止 —— 禁地彻底醒了。镇物真身·%s 挡在你面前！" % b.hunter["enemy_id"])
	else:
		b.log_event("—— 山风停了 —— 镇物分身·%s 循着气息，压进了你的地块！" % b.hunter["enemy_id"])

func _next_interval() -> int:
	if bool(b.hunter.get("avatar", true)):
		return int(_cfg().get("avatar_interval", 2))
	return b.rng.randi_range(int(_cfg().get("true_interval_min", 1)), int(_cfg().get("true_interval_max", 2)))

func _hunter_site() -> Vector2i:
	return b.hunter.get("site", Vector2i(0, 0))

func _hunter_name() -> String:
	var prefix := "镇物分身" if bool(b.hunter.get("avatar", true)) else "镇物真身"
	return "%s·%s" % [prefix, str(b.hunter.get("enemy_id", ""))]

# 压顶：镇物卡落进你当前地块的网格（就近前排空格；没有空格接尾）。不封锁——
# 动它旁边的东西会喂它的警戒，赖着不动会被迫近咬（C-028 惊动制统一表达）。
# 已在场的卡不动（节拍重入不洗掉它已积累的警戒与位置）。
func _rise_to_top() -> void:
	b.hunter["site"] = b.hero_site
	for i in range((b.current_site().get("grid", []) as Array).size()):
		if str(((b.current_site()["grid"] as Array)[i] as Dictionary).get("kind", "")) == "zhenwu":
			b.hunter["cell"] = i
			return
	_remove_card()
	var site := b.current_site()
	var card := {"kind": "zhenwu", "enemy_id": str(b.hunter.get("enemy_id", "")),
		"avatar": bool(b.hunter.get("avatar", false)), "alert": 0}
	b.hunter["cell"] = b._place_card(site, card, 0)

func _remove_card() -> void:
	var site: Dictionary = b.sites.get(_hunter_site(), {})
	var grid: Array = site.get("grid", [])
	for i in range(grid.size()):
		if str((grid[i] as Dictionary).get("kind", "")) == "zhenwu":
			grid[i] = {}
	b.hunter["cell"] = -1

func _step_toward_player() -> void:
	var dists := _distances_from(b.hero_site)
	var here := _hunter_site()
	var best := here
	var best_d := int(dists.get(here, 999))
	for link in (b.sites.get(here, {}).get("links", []) as Array):
		var d := int(dists.get(link, 999))
		if d < best_d:
			best_d = d
			best = link
	if best == here:
		return
	_remove_card()
	b.hunter["site"] = best
	if best == b.hero_site:
		_rise_to_top()
		b.log_event("金铁之声迫在眉睫——%s 追至，压进了你的地块！" % _hunter_name())
	else:
		b.log_event("远处传来金铁微鸣——%s 又近了一步。" % _hunter_name())

func _teleport_to_player() -> void:
	_remove_card()
	b.hunter["site"] = b.hero_site
	b.hunter["prox"] = 0
	_rise_to_top()
	b.log_event("山风倒卷——%s 破雾而至，落在你的地块！" % _hunter_name())

func _dissipate() -> void:
	_remove_card()
	var name := _hunter_name()
	b.hunter = {}
	b.log_event("青烟散尽——%s 的气息耗尽了，循旧路退去。它还在禁地深处。" % name)

# 杀真身＝禁地免疫系统关机：状态清零、追杀队列清空、场上现存小镇物卡消失。
# 状态照常累计（撤离门槛钩子继续有效），但升级不再标记。
func _disable_guardians() -> void:
	b.guardians_off = true
	b.alert_level = 0
	b.hunt_queue = 0
	var guardian_id := str(b.config.get("guardian_minor", ""))
	var swept := 0
	if not guardian_id.is_empty():
		for pos in b.sites:
			var grid: Array = b.sites[pos]["grid"]
			for i in range(grid.size() - 1, -1, -1):
				var card: Dictionary = grid[i]
				if str(card.get("kind", "")) == "enemy" and str(card.get("enemy_id", "")) == guardian_id:
					grid[i] = {}
					swept += 1
	b.log_event("镇物陨落，禁地一声长叹——山间石仆尽数碎裂（%d 处），守卫的怒意随之熄灭。这一局，随便搜。" % swept)

# ---------- 图距离 ----------

func _graph_distance(from: Vector2i, to: Vector2i) -> int:
	if from == to:
		return 0
	var visited := {from: true}
	var frontier: Array = [from]
	var dist := 0
	while not frontier.is_empty():
		dist += 1
		var next: Array = []
		for pos in frontier:
			for link in (b.sites.get(pos, {}).get("links", []) as Array):
				if visited.has(link):
					continue
				if link == to:
					return dist
				visited[link] = true
				next.append(link)
		frontier = next
	return 999

func _distances_from(origin: Vector2i) -> Dictionary:
	var dists := {origin: 0}
	var frontier: Array = [origin]
	while not frontier.is_empty():
		var next: Array = []
		for pos in frontier:
			for link in (b.sites.get(pos, {}).get("links", []) as Array):
				if dists.has(link):
					continue
				dists[link] = int(dists[pos]) + 1
				next.append(link)
		frontier = next
	return dists
