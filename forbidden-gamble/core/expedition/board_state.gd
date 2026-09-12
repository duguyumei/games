class_name BoardState
extends RefCounted

# 牌阵规则核心（纯逻辑，不含 UI，全种子驱动）——规则门面：
# 动作规则（地块网格/地点卡/移动/背包）与 AP 枢纽（行动力/禁地状态/警戒/追兵/力竭）
# 留在本类；大陆与卡牌生成（MapGenerator）、只读展示（BoardPresenters）、存档编解码
# （BoardCodec）各自成模块，经 setup 注入本类活引用。公共 API 是稳定契约（测试钉住）。
# - C-028 明牌地块网格：每个地点的牌摊成 3 列网格（grid 数组，空字典＝洞，拿走留洞
#   不回填），全部亮牌、点击即互动，无翻牌无顺序限制；地图保持散点＋路网。
# - 三态警戒（刺客信条式）：活敌（敌/追兵/镇物）带警戒值，互动产噪按曼哈顿距离传播
#   （1 格×2、2 格×1 行动力）；满表＝准备态，玩家再动一次且仍在地块→被袭击（敌方先手）。
#   只有你在别处花行动力才会消警戒（每点 −1）。普通敌人不主动袭击，被动攻击性归镇物
#   （迫近：压顶期间你每花 1 行动力 +1，满 3 层它扑上来）。
# - 统一世界钟＝你花的行动力：追杀节拍/分身寿命/迫近/警戒衰减全部挂在 _spend_ap 上；
#   战斗 0 行动力（代价是血与装备磨损），不推钟；0 行动力操作（整理/用道具/交谈）安静无声。
# - 迷踪香＝静音窗：窗内动牌不产噪（遮住气息偷东西）；开战本身总是很吵（固定档）。
# - 卡牌转化：物品入包留洞；敌人胜后原地变遗体（搜空也留场灰化）；容器（箱/遗体）
#   点击弹窗翻牌——开启费开盖、内容物留牌上逐张翻（1 行动力/张）、拿取免费，
#   可翻一半走了再续（D-028，C-028 网格化后照旧）；拿空留空壳；
#   小镇物与镇物分身被打死直接消失无掉落；杀真身清场（现存小镇物卡消失）。
# - 力竭：行动力归 0 且不在撤离点 = 被擒。
# - 背包：格数由穿戴的行囊决定（无行囊兜底 config.backpack_size）；同名可叠物品叠放占一格；
#   满格拾取/拿取被拒，需丢弃或用掉。
# - 穿戴栏（M4，25 号 §1；C-027 改跨局角色状态）：兵器/护具/行囊各一槽，不占背包。
#   兵器定系别增幅（同系功法伤害 +等级，招式本身不受装备限制）、护具定减伤（等级＝每次
#   气血伤害减免）；两者每场战斗结束耐久 -1，归零损毁。行囊定背包格数。穿戴件撤离原样
#   带回（耐久照旧，存 meta 档）、死亡/力竭全丢；开局穿什么由备战页（ExpeditionPrep）
#   决定，本类不再自动配发。
# - 锦囊（25 号 §6）：贴身保底——死亡/力竭只保锦囊（背包当场清空），撤离全保；
#   兵器/护具/行囊放不进；格数是局外升级（初始 1 封顶 3，MetaArchive.pouch_slots）。

const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DEFAULT_BACKPACK_SIZE := 5
const DEFAULT_POUCH_SLOTS := 1
# 放不进贴身锦囊的大类（兵器/护具/行囊是"穿戴"不是"捎带"；容器装不进容器）。
const POUCH_BLOCKED_TYPES := ["weapon", "armor", "container"]
# 穿戴槽位（兵器/护具/行囊），equipped 字典的键。
const EQUIP_SLOTS := ["weapon", "armor", "bag"]
# 各槽接受的物品 type。
const EQUIP_SLOT_TYPES := {"weapon": "weapon", "armor": "armor", "bag": "container"}
# 地块内部卡牌网格列数（C-028：当前地块放大成 3 列网格）。
const GRID_COLS := 3
# 会袭击你的活敌类别（警戒/迫近的载体；遗体与空壳不算）。
const LIVE_ENEMY_KINDS := ["enemy", "pursuer", "zhenwu"]
# 会被战斗连坐拉进场的类别（镇物独来独往，不参与凡人结阵）。
const CHAIN_KINDS := ["enemy", "pursuer"]

var config: Dictionary = {}
var items: Dictionary = {}
var enemies: Dictionary = {}
var rng := RandomNumberGenerator.new()
var seed := 0
var sites: Dictionary = {}           # Vector2i -> site（节点制＝舆图锚点像素键）
var hero_site := Vector2i(0, 0)
# 节点制（D-059）：边价表 "ax,ay|bx,by" -> cost；密道是本局掷定的特殊边；
# map_mode 标记本局走图纸建图（旧档/测试手搓局没有这些，走兜底逻辑）。
var map_mode := false
var link_costs: Dictionary = {}
var secret_links: Array = []
var ap := 0
var ap_spent := 0
var alert_level := 0
var pursuers_spawned := 0
var outcome := ""                    # "" / "extracted" / "exhausted" / "dead"
var inventory: Array = []            # 堆叠条目：{id,name,rarity,value,qty,...定义副本}
var pouch: Array = []                # 贴身锦囊（与背包同构；死亡保底，格数 pouch_slots）
var pouch_slots := DEFAULT_POUCH_SLOTS  # 局外升级容量（初始 1 封顶 3，ExpeditionSession 接线）
# 穿戴栏（M4）：槽键见 EQUIP_SLOTS，值为装备实例（定义副本＋uid/dur，qty 恒 1）或空字典。
var equipped := {"weapon": {}, "armor": {}, "bag": {}}
var issue_uid: Callable
var _events: Array[String] = []
# 探索域使用道具的 heal 效果落点：(amount: int) -> void。
var heal_player: Callable
# 镇物追杀状态（规则在 HuntSystem）
var qixi := 0
var hunter: Dictionary = {}
var hunt_count := 0
var hunt_queue := 0
var guardians_off := false
# C-028 警戒与战斗编排状态：
var sneak_ap := 0        # 迷踪香静音窗余量（每花 1 行动力 −1；窗内动牌不产噪）
var _sneak_covered := false  # 本次已花的行动力是否落在静音窗内（产噪判定用）
var battle_cell := -1    # 正在打/待打的网格位（场景往返与强退续战用）
var battle_enemy_first := false  # 这场是不是被袭击（敌方先手）
var chain_queue: Array = []  # 连坐待战的网格位（上下左右连通敌牌一组，逐场 1v1）

var _gen := MapGenerator.new()
var _present := BoardPresenters.new()
var _hunt := HuntSystem.new()

# 构造即接线：测试会直接 new 后戳 config/items/enemies 而不走 load()，
# 模块必须从出生就持有属主引用。
func _init() -> void:
	_gen.setup(self)
	_present.setup(self)
	_hunt.setup(self)

# 事件播报口（HuntSystem 等模块写入用）
func log_event(msg: String) -> void:
	_events.append(msg)

func load(config_path: String, items_path: String, enemies_path: String) -> bool:
	# JSON 读取统一走 DataRepo（缓存 + schema 校验）
	config = DataRepo.load_json(config_path)
	items = DataRepo.load_json(items_path)
	enemies = DataRepo.load_json(enemies_path)
	items = BoardCodec.intify_numbers(items)
	return not config.is_empty() and not items.is_empty() and not enemies.is_empty()

func generate(new_seed: int) -> void:
	seed = new_seed
	rng.seed = new_seed
	sites.clear()
	inventory = []
	pouch = []
	equipped = {"weapon": {}, "armor": {}, "bag": {}}
	_events = []
	_gen.reset_cache()
	outcome = ""
	ap_spent = 0
	alert_level = 0
	pursuers_spawned = 0
	qixi = 0
	hunter = {}
	hunt_count = 0
	hunt_queue = 0
	guardians_off = false
	sneak_ap = 0
	_sneak_covered = false
	battle_cell = -1
	battle_enemy_first = false
	chain_queue = []
	link_costs = {}
	secret_links = []
	ap = int(_ap_table().get("start", 40))
	var map_cfg: Dictionary = config.get("map", {})
	if not map_cfg.is_empty():
		# D-059 节点制：读锚点图纸建图（出生/边价/带别由生成器定）
		map_mode = true
		hero_site = Vector2i(0, 0)
		_gen.generate_from_map(map_cfg)
	else:
		map_mode = false
		hero_site = Vector2i(0, 0)
		var entrance := _make_site(str(config.get("entrance_type", "entrance")), hero_site)
		entrance["explored"] = true
		sites[hero_site] = entrance
		_gen.generate_continent()
	_events.append("远征开始：你来到 %s。行动力 %d 点。" % [_site_name(hero_site), ap])

# ---------- 生成委托（MapGenerator） ----------

func _make_site(type_id: String, pos: Vector2i) -> Dictionary:
	return _gen.make_site(type_id, pos)

func _make_card(spec: Dictionary) -> Dictionary:
	return _gen.make_card(spec)

func _make_body(enemy_id: String) -> Dictionary:
	return _gen.make_body(enemy_id)

func _empty_neighbors(pos: Vector2i) -> Array[Vector2i]:
	return _gen.empty_neighbors(pos)

func _pick(table: Array) -> String:
	return _gen.pick(table)

# ---------- 网格几何 ----------

# 网格位 -> 坐标（列, 行）；曼哈顿距离按此计算（警戒传播与连坐同一套几何）。
static func cell_coord(cell: int) -> Vector2i:
	return Vector2i(cell % GRID_COLS, cell / GRID_COLS)

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

# 上下左右相邻的网格位（越界由调用方按 grid.size() 过滤）。
static func cell_neighbors(cell: int) -> Array[int]:
	var out: Array[int] = []
	var col := cell % GRID_COLS
	if col > 0:
		out.append(cell - 1)
	if col < GRID_COLS - 1:
		out.append(cell + 1)
	if cell - GRID_COLS >= 0:
		out.append(cell - GRID_COLS)
	out.append(cell + GRID_COLS)
	return out

# ---------- 查询 ----------

func site_at(pos: Vector2i) -> Dictionary:
	return sites.get(pos, {})

func current_site() -> Dictionary:
	return sites.get(hero_site, {})

func grid_of(pos: Vector2i) -> Array:
	return site_at(pos).get("grid", [])

func cell_card(pos: Vector2i, cell: int) -> Dictionary:
	var grid := grid_of(pos)
	if cell < 0 or cell >= grid.size():
		return {}
	var card: Dictionary = grid[cell]
	if card.is_empty():
		return {}
	return card

# 地点里还剩几张牌（非洞；小地图角标与预览用）。
func card_count(pos: Vector2i) -> int:
	var count := 0
	for entry in grid_of(pos):
		if not (entry as Dictionary).is_empty():
			count += 1
	return count

func is_extract_site(pos: Vector2i) -> bool:
	return bool(site_at(pos).get("extract", false))

# 节点的动态带（D-051 加权距离口径；图纸外的旧局兜底浅）。
func site_band(pos: Vector2i) -> String:
	return str(site_at(pos).get("band", "浅"))

# 通道边价（D-059 加权边）：无记录的旧局/手搓局兜底 ap.travel。
func travel_cost(a: Vector2i, b: Vector2i) -> int:
	var k := "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	if link_costs.has(k):
		return int(link_costs[k])
	var rk := "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
	if link_costs.has(rk):
		return int(link_costs[rk])
	return _ap_cost("travel", 1)

func can_travel_to(pos: Vector2i) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var site := site_at(pos)
	if site.is_empty() or pos == hero_site:
		return false
	return hero_site in site["links"]

# 追兵在场 = 强制拦截（v1 scripted 拦截遗留；正式配置不产追兵）。
func pending_intercept() -> bool:
	for entry in grid_of(hero_site):
		var card: Dictionary = entry
		if not card.is_empty() and str(card.get("kind", "")) == "pursuer":
			return true
	return false

func is_run_over() -> bool:
	return outcome != ""

func drain_events() -> Array[String]:
	var out: Array[String] = _events
	_events = []
	return out

# ---------- 展示委托（BoardPresenters，纯查询零副作用） ----------

func alert_info() -> Dictionary:
	return _present.alert_info()

# 三态警戒角标（calm/alerted/ready + 数值/上限）——活敌牌面用。
func alert_badge(card: Dictionary) -> Dictionary:
	return _present.alert_badge(card)

# 压顶镇物的迫近进度（-1＝未压顶）。
func hunter_proximity() -> int:
	return _present.hunter_proximity()

# 地块牌面预览（小地块 tooltip）。
func site_peek(pos: Vector2i) -> Array[String]:
	return _present.site_peek(pos)

# 容器弹窗视图（箱/遗体：名字＋内容物条目的暗/亮与物品名）。
func container_view(cell: int) -> Dictionary:
	return _present.container_view(cell_card(hero_site, cell))

func kind_name(kind: String) -> String:
	return _present.kind_name(kind)

func card_display(card: Dictionary) -> String:
	return _present.card_display(card)

# 牌面悬停详情（tooltip 文案；物品详情见 BoardPresenters.item_entry_tooltip）。
func card_tooltip(card: Dictionary) -> String:
	return _present.card_tooltip(card)

func rarity_name(rarity: String) -> String:
	return _present.rarity_name(rarity)

func tier_name(tier: String) -> String:
	return _present.tier_name(tier)

func item_rarity(item_id: String) -> String:
	return _present.item_rarity(item_id)

func chest_open_cost(chest_id: String) -> int:
	return _present.chest_open_cost(chest_id)

func _chest_config(chest_id: String) -> Dictionary:
	return _present.chest_config(chest_id)

func _item_name(item_id: String) -> String:
	return _present.item_name(item_id)

func _location_def(card: Dictionary) -> Dictionary:
	return _present.location_def(card)

func _site_name(pos: Vector2i) -> String:
	return _present.site_name(pos)

# ---------- 动作：地块网格（点击即互动） ----------

# 拾取零散物品：0 行动力，物品入包（叠放；满格拒收，牌留原地留洞）。
# 有动静：0 费互动也至少算 1 点动静（翻找不是无声的）。
func pickup_cell(cell: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) != "scatter":
		return false
	var item := _item(str(card.get("item_id", "")))
	if item.is_empty() or not _add_to_inventory(item):
		return false
	current_site()["grid"][cell] = {}
	_noise(cell, 0)
	_events.append("拾取 %s。" % str(item.get("name", "")))
	return true

# 打开箱子 / 搜刮遗体（弹窗容器，D-028）：首次付开启费开盖，内容物留在牌上
# （弹窗里逐张翻牌）；已开过的再点＝免费查看（可翻一半走了再续）；空壳没得开。
func open_cell(cell: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	var kind := str(card.get("kind", ""))
	if kind not in ["chest", "body"]:
		return false
	var contents: Array = card.get("contents", [])
	if bool(card.get("opened", false)) or contents.is_empty():
		return bool(card.get("opened", false)) and not contents.is_empty()
	var cost := int(_chest_config(str(card.get("chest", ""))).get("ap_cost", 1))
	if not _pay(cost):
		return false
	card["opened"] = true
	_noise(cell, cost)
	if kind == "chest":
		_events.append("打开%s——里面盖着 %d 件东西。" % [card_display(card), contents.size()])
	else:
		_events.append("搜刮%s——贴身行囊里盖着 %d 件东西。" % [card_display(card), contents.size()])
	return true

# 容器内翻一张牌（弹窗里点暗牌）：1 行动力（ap.flip），翻开亮出物品；产噪照常。
func flip_cell_content(cell: int, index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) not in ["chest", "body"] or not bool(card.get("opened", false)):
		return false
	var contents: Array = card.get("contents", [])
	if index < 0 or index >= contents.size():
		return false
	var entry: Dictionary = contents[index]
	if bool(entry.get("flipped", false)) or str(entry.get("item_id", "")).is_empty():
		return false
	var cost := _ap_cost("flip", 1)
	if not _pay(cost):
		return false
	entry["flipped"] = true
	_noise(cell, cost)
	_events.append("翻开一看——%s。" % _item_name(str(entry.get("item_id", ""))))
	return true

# 拿取容器里一件已翻开的物品（弹窗里点亮牌）：0 行动力（D-028 拿取免费），
# 满格拒收（东西留在容器里）；拿空容器变空壳留场（遗体搜空也不消失）。
func take_cell_content(cell: int, index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) not in ["chest", "body"] or not bool(card.get("opened", false)):
		return false
	var contents: Array = card.get("contents", [])
	if index < 0 or index >= contents.size():
		return false
	var entry: Dictionary = contents[index]
	if not bool(entry.get("flipped", false)):
		return false
	var item := _item(str(entry.get("item_id", "")))
	if item.is_empty() or not _add_to_inventory(item):
		return false
	contents.remove_at(index)
	_noise(cell, 0)
	if contents.is_empty():
		_events.append("%s 被拿空了。" % card_display(card))
	return true

# 与敌人/追兵/镇物交战（0 行动力）：返回敌人 id，由外层切战斗场景。
# 连坐：上下左右连通的敌牌一组（C-029 多人战斗前的临时口径＝组内逐场 1v1）。
func engage_cell(cell: int) -> String:
	if not _can_act():
		return ""
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) not in LIVE_ENEMY_KINDS:
		return ""
	# 追兵拦截封锁一切，除了迎战追兵本身
	if pending_intercept() and str(card.get("kind", "")) != "pursuer":
		return ""
	chain_queue = _enemy_group_cells(cell)
	chain_queue.erase(cell)
	battle_cell = cell
	battle_enemy_first = false
	return str(card.get("enemy_id", ""))

# 连坐组（含自身）——从 cell 出发对连通的敌/追兵做 BFS。
func _enemy_group_cells(cell: int) -> Array:
	var grid: Array = current_site()["grid"]
	var group: Array = []
	var frontier: Array[int] = [cell]
	var seen := {cell: true}
	while not frontier.is_empty():
		var here: int = frontier.pop_front()
		var card: Dictionary = grid[here] if here < grid.size() else {}
		if card.is_empty() or str(card.get("kind", "")) not in CHAIN_KINDS:
			continue
		group.append(here)
		for next_cell in cell_neighbors(here):
			if not seen.has(next_cell):
				seen[next_cell] = true
				frontier.append(next_cell)
	return group

# 袭击判定（每次玩家动作后调用）：准备态（满表）的活敌扑上来，敌方先手；
# 迫近满的压顶镇物同理。返回敌人 id（""＝平安无事）。人已离开地块则查不到＝安全。
# 逃生窗：刚被填满的那次行动不挨咬——primed 标记在本次检查里挂上，下一次行动才咬。
func check_ambush() -> String:
	if outcome != "":
		return ""
	if not hunter.is_empty() and _hunter_at_hero():
		if int(hunter.get("prox", 0)) >= _prox_cap():
			if bool(hunter.get("primed", false)):
				battle_cell = int(hunter.get("cell", -1))
				battle_enemy_first = true
				_events.append("迫近！%s 扑了上来！" % card_display(cell_card(hero_site, battle_cell)))
				return str(hunter.get("enemy_id", ""))
			hunter["primed"] = true
			_events.append("%s 蓄势待发——再动一下它就扑上来了！" % card_display(cell_card(hero_site, int(hunter.get("cell", -1)))))
	var grid := grid_of(hero_site)
	var first_ready := -1
	for cell in range(grid.size()):
		var card: Dictionary = grid[cell]
		if card.is_empty() or str(card.get("kind", "")) not in LIVE_ENEMY_KINDS:
			continue
		if int(card.get("alert", 0)) < _alert_cap(card):
			continue
		if bool(card.get("primed", false)):
			battle_cell = cell
			battle_enemy_first = true
			_events.append("%s 一直盯着你——此刻骤然发难！" % card_display(card))
			return str(card.get("enemy_id", ""))
		card["primed"] = true
		if first_ready < 0:
			first_ready = cell
	if first_ready >= 0:
		_events.append("%s 已经盯死了你——再动一下它就会扑上来！" % card_display(grid[first_ready]))
	return ""

# 连坐队列取下一场（打完上一场后由外层连战）：设好战斗位，返回敌人 id。
func next_chain() -> String:
	if chain_queue.is_empty() or outcome != "":
		return ""
	battle_cell = int(chain_queue.pop_front())
	battle_enemy_first = false
	var card := cell_card(hero_site, battle_cell)
	if card.is_empty() or str(card.get("kind", "")) not in LIVE_ENEMY_KINDS:
		return next_chain()
	_events.append("旁边%s闻声加入战团！" % card_display(card))
	return str(card.get("enemy_id", ""))

# 战斗场景回来后结算。胜：敌人原地变遗体/直接消失（分身与小镇物），开战动静震邻；
# 负：远征失败。0 行动力（战斗的代价是血与装备磨损，C-028）。
func resolve_battle_result(result: String) -> void:
	if result == "lose":
		outcome = "dead"
		inventory.clear()
		equipped = {"weapon": {}, "armor": {}, "bag": {}}
		battle_cell = -1
		battle_enemy_first = false
		chain_queue = []
		_events.append("你倒下了，随身兵甲散落一地。" + _pouch_survives_text())
		return
	var card := cell_card(hero_site, battle_cell)
	var kind := str(card.get("kind", ""))
	if kind not in LIVE_ENEMY_KINDS:
		return
	_wear_equipment()
	var enemy_id := str(card.get("enemy_id", ""))
	var noise_cell := battle_cell
	battle_cell = -1
	battle_enemy_first = false
	var site := current_site()
	if kind == "zhenwu":
		if bool(card.get("avatar", false)):
			# 分身：直接散去，无遗体无掉落（C-028）
			site["grid"][noise_cell] = {}
			_events.append("%s 散作青烟，消散无踪。" % card_display(card))
			_hunt.on_hunter_slain()
			return
		site["grid"][noise_cell] = _make_body(enemy_id)
		_events.append("%s 的剑当啷落地——守冢遗骸留在这里。" % card_display(card))
		_hunt.on_hunter_slain()
	elif enemy_id == str(config.get("guardian_minor", "")):
		# 小镇物：碎裂消失，无遗体无掉落（C-028）
		site["grid"][noise_cell] = {}
		_events.append("%s 应声碎裂，散作齑粉。" % card_display(card))
	else:
		site["grid"][noise_cell] = _make_body(enemy_id)
		_events.append("%s 倒下了，遗体留在原地——可搜刮。" % card_display(card))
	_battle_noise(noise_cell)

# 与 NPC 交谈：0 行动力，牌留原地（可再谈）。
func talk_cell(cell: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) != "npc":
		return false
	_say_npc_lines(card)
	return true

func _say_npc_lines(card: Dictionary) -> void:
	var npc: Dictionary = config.get("npcs", {}).get(str(card.get("npc_id", "")), {})
	_events.append("—— %s ——" % str(npc.get("name", "路人")))
	for line in npc.get("lines", []):
		_events.append(str(line))

# ---------- 动作：地点卡 ----------

# 打开网格里的地点卡：0 AP，可能要特定物品。捷径=接通既有地块；其余=长出新地块并抵达。
func open_location_cell(cell: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	var card := cell_card(hero_site, cell)
	if str(card.get("kind", "")) != "location":
		return false
	var reason := _location_block_reason(card)
	if not reason.is_empty():
		_events.append(reason)
		return false
	_pay_location_requirement(card)
	current_site()["grid"][cell] = {}
	_apply_location_card(card)
	return true

# 地点卡的打开条件：{item: 物品 id（""=无条件）, consume: 是否消耗（默认消耗）}。
func location_requirement(card: Dictionary) -> Dictionary:
	var def := _location_def(card)
	return {"item": str(def.get("require_item", "")), "consume": bool(def.get("consume", true))}

# 条件是否满足（物品在背包或锦囊里——都在身上）。
func can_open_location(card: Dictionary) -> bool:
	var item_id := str(location_requirement(card)["item"])
	if item_id.is_empty():
		return true
	for stack in inventory + pouch:
		if str(stack.get("id", "")) == item_id and int(stack.get("qty", 1)) > 0:
			return true
	return false

func _location_block_reason(card: Dictionary) -> String:
	var def := _location_def(card)
	if str(def.get("effect", "")) != "shortcut" and _empty_neighbors(hero_site).is_empty():
		return "四周都被堵死，无处可去。"
	# 节点制（D-059）：地块全由图纸锚定，成长类地点卡无处可长（生成时不藏，
	# 旧档兜底拦截）；捷径照常接通既有节点。
	if map_mode and str(def.get("effect", "")) != "shortcut":
		return "此地无从拓展。"
	var item_id := str(location_requirement(card)["item"])
	if not item_id.is_empty() and not can_open_location(card):
		return "需要%s才能打开。" % _item_name(item_id)
	return ""

func _pay_location_requirement(card: Dictionary) -> void:
	var req := location_requirement(card)
	var item_id := str(req["item"])
	if not item_id.is_empty() and bool(req["consume"]):
		_consume_item(item_id)

# 跨背包＋锦囊消耗一件（地点开启条件/战斗侧用）：先背包后锦囊——都在身上。
func _consume_item(item_id: String) -> void:
	if not _consume_unit_from(inventory, item_id):
		_consume_unit_from(pouch, item_id)

func _consume_unit_from(arr: Array, item_id: String) -> bool:
	for i in range(arr.size()):
		var stack: Dictionary = arr[i]
		if str(stack.get("id", "")) == item_id:
			stack["qty"] = int(stack.get("qty", 1)) - 1
			if int(stack.get("qty", 0)) <= 0:
				arr.remove_at(i)
			return true
	return false

func _apply_location_card(card: Dictionary) -> void:
	var def := _location_def(card)
	var card_name := str(def.get("name", "地点卡"))
	if str(def.get("effect", "")) == "shortcut":
		_open_shortcut(card_name)
		return
	var empties := _empty_neighbors(hero_site)
	var new_pos: Vector2i = empties[rng.randi_range(0, empties.size() - 1)]
	var new_site := _make_site(str(def.get("site_type", "")), new_pos)
	sites[new_pos] = new_site
	current_site()["links"].append(new_pos)
	new_site["links"].append(hero_site)
	_events.append("你打开了%s。" % card_name)
	_move_to(new_pos)
	if bool(new_site.get("extract", false)):
		_events.append("这里是撤离点！站定后即可撤离。")

# 捷径：在当前地块与另一个未连通地块间接通新通道（取曼哈顿距离最远的一批）。
func _open_shortcut(card_name: String) -> void:
	var candidates: Array[Vector2i] = []
	for pos in sites:
		if pos == hero_site or hero_site in (sites[pos]["links"] as Array):
			continue
		candidates.append(pos)
	if candidates.is_empty():
		_events.append("%s转了转，没有发现新路。" % card_name)
		return
	var best := -1
	var far: Array[Vector2i] = []
	for pos in candidates:
		var d: int = absi(pos.x - hero_site.x) + absi(pos.y - hero_site.y)
		if d > best:
			best = d
			far = [pos]
		elif d == best:
			far.append(pos)
	var target: Vector2i = far[rng.randi_range(0, far.size() - 1)]
	current_site()["links"].append(target)
	sites[target]["links"].append(hero_site)
	_events.append("发现%s——%s 与 %s 之间多出一条近路！" % [card_name, _site_name(hero_site), _site_name(target)])

# ---------- 动作：地点间 ----------

# 沿已连通通道移动：按边价付行动力（D-059 加权边，旧局无记录＝1 AP/条）。
# 走到未探索地块即翻开。
func travel_to(pos: Vector2i) -> bool:
	if not can_travel_to(pos):
		return false
	var cost := travel_cost(hero_site, pos)
	if ap < cost:
		_events.append("行动力不足——这条路要走 %d 点。" % cost)
		return false
	_move_to(pos)
	_spend_ap(cost)
	return true

# 抵达地块：未探索则翻开（探索状态从此保留）。
func _move_to(pos: Vector2i) -> void:
	var old := hero_site
	hero_site = pos
	var site := current_site()
	if not bool(site.get("explored", false)):
		site["explored"] = true
		_events.append("你翻开了这片地块——这里是 %s。" % str(site.get("name", "")))
	else:
		_events.append("你来到 %s。" % _site_name(pos))
	_hunt.on_player_departed(old)
	_hunt.on_player_arrived()

# 在当前撤离点撤离：0 AP，远征成功。
func extract() -> bool:
	if outcome != "" or pending_intercept():
		return false
	if not is_extract_site(hero_site):
		return false
	outcome = "extracted"
	_events.append("—— 撤离成功 —— 你带着物资离开了这片险地。")
	return true

# ---------- 动作：背包丢弃 ----------

# 从背包丢弃一件（堆叠减一，减空移出）：0 行动力，变成当前地点网格里的一张零散物品牌。
func drop_item(inv_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var stack: Dictionary = inventory[inv_index]
	stack["qty"] = int(stack.get("qty", 1)) - 1
	if int(stack.get("qty", 0)) <= 0:
		inventory.remove_at(inv_index)
	_place_card(current_site(), {"kind": "scatter", "item_id": str(stack.get("id", ""))}, 0)
	_events.append("你丢下了 %s。" % str(stack.get("name", "")))
	return true

# ---------- 警戒（三态：平常/惊动/准备） ----------

func _alert_cfg() -> Dictionary:
	return config.get("alert", {})

func _alert_cap(card: Dictionary) -> int:
	var enemy_id := str(card.get("enemy_id", ""))
	var own := int(enemies.get(enemy_id, {}).get("alert_cap", 0))
	if own > 0:
		return own
	return int(_alert_cfg().get("cap", 10))

func _prox_cap() -> int:
	return int(config.get("hunt", {}).get("proximity_cap", 3))

# 互动产噪：从互动位按曼哈顿距离传播（1 格 ×2、2 格 ×1，按行动花费倍乘；
# 0 费互动至少算 1 点动静）。迷踪香静音窗内无声。
func _noise(cell: int, ap_cost: int) -> void:
	if sneak_ap > 0 or _sneak_covered:
		return
	var units := maxi(1, ap_cost)
	_spread_noise(cell, units)

# 开战产噪：固定档（默认按 2 行动力的动静），静音窗也不遮掩打斗。
func _battle_noise(cell: int) -> void:
	_spread_noise(cell, int(_alert_cfg().get("combat_ap", 2)))

func _spread_noise(cell: int, units: int) -> void:
	var origin := cell_coord(cell)
	var grid := grid_of(hero_site)
	var near1 := int(_alert_cfg().get("near1", 2))
	var near2 := int(_alert_cfg().get("near2", 1))
	for i in range(grid.size()):
		var card: Dictionary = grid[i]
		if card.is_empty() or str(card.get("kind", "")) not in LIVE_ENEMY_KINDS:
			continue
		var d := _manhattan(cell_coord(i), origin)
		var gain := 0
		if d == 1:
			gain = near1 * units
		elif d == 2:
			gain = near2 * units
		if gain <= 0:
			continue
		var cap := _alert_cap(card)
		var before := int(card.get("alert", 0))
		var after: int = mini(cap, before + gain)
		card["alert"] = after
		if before < cap and after >= cap:
			card["primed"] = false  # 刚满表：本次行动不咬，下一次才咬（逃生窗）
			_events.append("%s 已经盯死了你——再动一下，它就会扑上来！" % card_display(card))
		elif before <= 0 and after > 0:
			_events.append("%s 似乎察觉了什么动静。" % card_display(card))

# 网格里放一张牌：就近找空格（洞优先、按距离），没有洞就接尾追加。返回落位。
func _place_card(site: Dictionary, card: Dictionary, near_cell: int) -> int:
	var grid: Array = site["grid"]
	var best := -1
	var best_d := 9999
	var origin := cell_coord(near_cell)
	for i in range(grid.size()):
		if not (grid[i] as Dictionary).is_empty():
			continue
		var d := _manhattan(cell_coord(i), origin)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		grid.append(card)
		return grid.size() - 1
	grid[best] = card
	return best

func _hunter_at_hero() -> bool:
	return not hunter.is_empty() and hunter.get("site", Vector2i(9, 9)) == hero_site

# ---------- 背包与穿戴 ----------

# 背包容格数＝穿戴行囊的格数；没穿行囊兜底 config.backpack_size（C-027 后即"随身衣兜"
# 基线 5 格——保底配发取消，开局有没有行囊全看备战页带没带）。
func backpack_capacity() -> int:
	var bag: Dictionary = equipped.get("bag", {})
	if not bag.is_empty():
		return int(bag.get("container", {}).get("slots", DEFAULT_BACKPACK_SIZE))
	return int(config.get("backpack_size", DEFAULT_BACKPACK_SIZE))

# 装备判定：定义里带 weapon/armor/container 参数包即为装备（实例不叠堆）。
func is_equipment(item: Dictionary) -> bool:
	return item.has("weapon") or item.has("armor") or item.has("container")

# 入包（叠放）：同名可叠物品未到堆叠上限叠数量；装备实例不叠堆，每件占一格。
# 成功返回 true，满格返回 false。每入一件都计气息。
func _add_to_inventory(item: Dictionary) -> bool:
	if not _stack_into(inventory, item, backpack_capacity(), "背包已满，%s 拿不下。" % str(item.get("name", ""))):
		return false
	_hunt.on_loot(int(item.get("value", 0)))
	return true

# 通用入列（叠放）：装备实例（is_equipment）永不合并，每件占一格；定义副本首次入列时
# 补 uid 与初始耐久变成实例（已带 uid 的旧实例原样保留）。满时播报 full_msg。
func _stack_into(arr: Array, item: Dictionary, cap: int, full_msg: String) -> bool:
	var item_id := str(item.get("id", ""))
	var max_stack := 1 if is_equipment(item) else int(item.get("max_stack", 99))
	for stack in arr:
		if str(stack.get("id", "")) == item_id and int(stack.get("qty", 1)) < max_stack:
			stack["qty"] = int(stack.get("qty", 1)) + 1
			return true
	if arr.size() >= cap:
		_events.append(full_msg)
		return false
	var entry: Dictionary = item.duplicate()
	entry["qty"] = 1
	if is_equipment(entry) and not entry.has("uid"):
		entry = _instance_of(entry)
	arr.append(entry)
	return true

# 从一堆里取走一件（数量减一，减空移出该堆）。
func _take_unit_from(arr: Array, index: int) -> void:
	var stack: Dictionary = arr[index]
	stack["qty"] = int(stack.get("qty", 1)) - 1
	if int(stack.get("qty", 0)) <= 0:
		arr.remove_at(index)

# ---------- 穿戴栏（M4，25 号 §1） ----------

func equipped_weapon_school() -> String:
	return str(equipped.get("weapon", {}).get("weapon", {}).get("school", ""))

func equipped_weapon_level() -> int:
	return int(equipped.get("weapon", {}).get("weapon", {}).get("level", 0))

func equipped_armor_defend() -> int:
	return int(equipped.get("armor", {}).get("armor", {}).get("level", 0))

# 穿戴概览（构筑面板一行）：兵器（系别+等级+耐久）/护具（减伤+耐久）/行囊格数。
func equipment_summary() -> String:
	var parts: Array[String] = []
	var weapon: Dictionary = equipped.get("weapon", {})
	if weapon.is_empty():
		parts.append("空手")
	else:
		parts.append("%s·%s+%d（耐%d）" % [str(weapon.get("name", "")),
			str(weapon.get("weapon", {}).get("school", "")), equipped_weapon_level(),
			int(weapon.get("dur", 0))])
	var armor: Dictionary = equipped.get("armor", {})
	if armor.is_empty():
		parts.append("无护具")
	else:
		parts.append("%s·减%d（耐%d）" % [str(armor.get("name", "")),
			equipped_armor_defend(), int(armor.get("dur", 0))])
	parts.append("行囊%d格" % backpack_capacity())
	return " ｜ ".join(parts)

# 背包 → 穿戴（0 行动力）。旧穿戴件先回背包（需空位）。换小行囊时背包件数不得超过新格数。
func equip_from_inventory(inv_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var entry: Dictionary = inventory[inv_index]
	var slot := _equip_slot_for(entry)
	if slot.is_empty():
		_events.append("%s 不是能穿戴的东西。" % str(entry.get("name", "")))
		return false
	if slot == "bag":
		var new_cap := int(entry.get("container", {}).get("slots", 0))
		if inventory.size() > new_cap:
			_events.append("背包里有 %d 件东西，放不进 %d 格的新行囊。" % [inventory.size(), new_cap])
			return false
	var old: Dictionary = equipped.get(slot, {})
	if not old.is_empty() and slot != "bag":
		if not _stack_into(inventory, old, backpack_capacity(), "背包已满，%s 腾不出来。" % str(old.get("name", ""))):
			return false
	if not entry.has("uid"):
		entry = _instance_of(entry)
	inventory.remove_at(inv_index)
	equipped[slot] = entry
	if not old.is_empty() and slot == "bag":
		if not _stack_into(inventory, old, backpack_capacity(), "背包已满，%s 腾不出来。" % str(old.get("name", ""))):
			equipped[slot] = old
			inventory.insert(inv_index, entry)
			return false
	_events.append("你穿戴了 %s。" % str(entry.get("name", "")))
	return true

# 穿戴 → 背包（0 行动力）。卸行囊后背包容量回落到兜底值，背包必须装得下现有件数＋这一件。
func unequip_to_inventory(slot: String) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if not EQUIP_SLOTS.has(slot):
		return false
	var entry: Dictionary = equipped.get(slot, {})
	if entry.is_empty():
		return false
	var cap_after := backpack_capacity()
	if slot == "bag":
		cap_after = int(config.get("backpack_size", DEFAULT_BACKPACK_SIZE))
		if inventory.size() + 1 > cap_after:
			_events.append("背包已满，卸下的 %s 没处放。" % str(entry.get("name", "")))
			return false
	if not _stack_into(inventory, entry, cap_after, "背包已满，%s 拿不下来。" % str(entry.get("name", ""))):
		return false
	equipped[slot] = {}
	_events.append("你卸下了 %s。" % str(entry.get("name", "")))
	return true

# 该物品应放入哪个穿戴槽（""＝不可穿戴）。
func _equip_slot_for(entry: Dictionary) -> String:
	var type_id := str(entry.get("type", ""))
	for slot in EQUIP_SLOTS:
		if EQUIP_SLOT_TYPES[slot] == type_id:
			return slot
	return ""

# 定义副本 → 装备实例（补 uid 与初始耐久；兵器/护具有耐久，行囊没有）。
func _instance_of(item: Dictionary) -> Dictionary:
	var inst: Dictionary = item.duplicate()
	inst["qty"] = 1
	inst["uid"] = _next_uid()
	for pkg in ["weapon", "armor"]:
		if inst.has(pkg) and not inst.has("dur"):
			inst["dur"] = int(inst[pkg].get("base_dur", 1))
	return inst

func _next_uid() -> int:
	if issue_uid.is_valid():
		return int(issue_uid.call())
	return 0

# 每场战斗结束的耐久磨损（M4 定案）：兵器与护具各 -1，归零损毁（槽清空）。
func _wear_equipment() -> void:
	for slot in ["weapon", "armor"]:
		var entry: Dictionary = equipped.get(slot, {})
		if entry.is_empty():
			continue
		var dur := int(entry.get("dur", 0)) - 1
		if dur <= 0:
			_events.append("%s 经此一役彻底损毁。" % str(entry.get("name", "")))
			equipped[slot] = {}
		else:
			entry["dur"] = dur
			_events.append("%s 磨损（耐久余 %d）。" % [str(entry.get("name", "")), dur])

# ---------- 锦囊（贴身保底，25 号 §6） ----------

func pouch_capacity() -> int:
	return pouch_slots

# 背包 → 锦囊（一次一件，0 行动力）：兵器/护具放不进贴身锦囊。
func move_to_pouch(inv_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var entry: Dictionary = inventory[inv_index]
	if POUCH_BLOCKED_TYPES.has(str(entry.get("type", ""))):
		_events.append("%s 放不进贴身锦囊。" % str(entry.get("name", "")))
		return false
	if not _stack_into(pouch, entry, pouch_slots, "锦囊已满，%s 塞不进去。" % str(entry.get("name", ""))):
		return false
	_take_unit_from(inventory, inv_index)
	_events.append("你把 %s 收进贴身锦囊。" % str(entry.get("name", "")))
	return true

# 锦囊 → 背包（一次一件，0 行动力）。内部腾挪不计气息（拾取时已计过）。
func move_to_bag(pouch_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if pouch_index < 0 or pouch_index >= pouch.size():
		return false
	var entry: Dictionary = pouch[pouch_index]
	if not _stack_into(inventory, entry, backpack_capacity(), "背包已满，%s 拿不下。" % str(entry.get("name", ""))):
		return false
	_take_unit_from(pouch, pouch_index)
	_events.append("你把 %s 取回背包。" % str(entry.get("name", "")))
	return true

# 从锦囊丢弃一件到当前地点网格（0 行动力，与背包丢弃同规则）。
func drop_pouch_item(pouch_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if pouch_index < 0 or pouch_index >= pouch.size():
		return false
	var stack: Dictionary = pouch[pouch_index]
	var item_id := str(stack.get("id", ""))
	_take_unit_from(pouch, pouch_index)
	_place_card(current_site(), {"kind": "scatter", "item_id": item_id}, 0)
	_events.append("你丢下了 %s。" % str(stack.get("name", "")))
	return true

# 使用背包里的一件道具（探索域，0 行动力）：前置检查全过才执行（不留半生效状态），
# 效果逐条结算后消耗一件。战斗域道具在这里不可用（use.scopes 不含 explore）。
func use_item(inv_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	return _use_entry(inventory[inv_index], inventory)

# 使用锦囊里的一件道具（探索域，规则与背包使用相同；消耗落在锦囊那一份上）。
func use_pouch_item(pouch_index: int) -> bool:
	if not _can_act() or pending_intercept():
		return false
	if pouch_index < 0 or pouch_index >= pouch.size():
		return false
	return _use_entry(pouch[pouch_index], pouch)

func _use_entry(entry: Dictionary, from: Array) -> bool:
	var use: Dictionary = entry.get("use", {})
	if use.is_empty() or not (use.get("scopes", []) as Array).has("explore"):
		_events.append("%s 在探索中用不了。" % str(entry.get("name", "")))
		return false
	for effect in use.get("effects", []):
		var block := _explore_effect_block(effect)
		if not block.is_empty():
			_events.append(block)
			return false
	for effect in use.get("effects", []):
		_apply_explore_effect(effect)
	_consume_unit_from(from, str(entry.get("id", "")))
	_events.append("你使用了%s。" % str(entry.get("name", "")))
	return true

# UI 按钮态：这件道具在探索中是否可点用。
func item_usable_in_explore(inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var use: Dictionary = inventory[inv_index].get("use", {})
	return not use.is_empty() and (use.get("scopes", []) as Array).has("explore")

func pouch_item_usable_in_explore(pouch_index: int) -> bool:
	if pouch_index < 0 or pouch_index >= pouch.size():
		return false
	var use: Dictionary = pouch[pouch_index].get("use", {})
	return not use.is_empty() and (use.get("scopes", []) as Array).has("explore")

# 战斗侧消耗背包道具（battle 场景调用；与地点开启条件共用逻辑）。
func consume_item(item_id: String) -> void:
	_consume_item(item_id)

func _explore_effect_block(effect: Dictionary) -> String:
	match str(effect.get("kind", "")):
		"open_all_chests":
			var found := false
			for entry in grid_of(hero_site):
				var card: Dictionary = entry
				if not card.is_empty() and str(card.get("kind", "")) == "chest" \
						and not bool(card.get("opened", false)) \
						and not (card.get("contents", []) as Array).is_empty():
					found = true
					break
			if not found:
				return "这里没有能开的箱子。"
	return ""

func _apply_explore_effect(effect: Dictionary) -> void:
	match str(effect.get("kind", "")):
		"heal":
			if heal_player.is_valid():
				heal_player.call(int(effect.get("amount", 0)))
				_events.append("气血回复 %d 点。" % int(effect.get("amount", 0)))
			else:
				push_error("BoardState.heal_player 未接线，heal 效果无处落地")
		"restore_ap":
			ap += int(effect.get("amount", 0))
			_events.append("药力化开，行动力回复 %d 点（当前 %d）。" % [int(effect.get("amount", 0)), ap])
		"open_all_chests":
			_open_all_chests_effect()
		"sneak_window":
			sneak_ap += int(effect.get("amount", 3))
			_events.append("青烟裹身，气息断绝——接下来 %d 点行动力内，动东西不再惊动任何人。" % sneak_ap)

# 百匣钥：当前地点未开的箱子尽数崩开（免开启费；东西仍盖着，进弹窗逐张翻）。
func _open_all_chests_effect() -> void:
	var opened_count := 0
	for entry in current_site()["grid"]:
		var card: Dictionary = entry
		if card.is_empty() or str(card.get("kind", "")) != "chest" or bool(card.get("opened", false)):
			continue
		if (card.get("contents", []) as Array).is_empty():
			continue
		card["opened"] = true
		opened_count += 1
	if opened_count > 0:
		_events.append("机关簧片自走，此地 %d 只箱子尽数崩开——盖子开了，东西还盖着。" % opened_count)
	else:
		_events.append("机关簧片自走——这里没有能开的箱子。")

# ---------- 行动力与统一世界钟（AP 枢纽） ----------

func _pay(amount: int) -> bool:
	if amount > 0 and ap < amount:
		_events.append("行动力不足。")
		return false
	_spend_ap(amount)
	return true

# 统一世界钟（C-028）：你花的每一滴行动力同时驱动——禁地状态升级、别处警戒衰减、
# 迷踪香窗倒数、镇物节拍（寿命/移动/瞬移/迫近）。战斗与 0 费操作不推钟。
func _spend_ap(amount: int) -> void:
	if amount <= 0 or outcome != "":
		return
	_sneak_covered = sneak_ap > 0  # 扣窗前先记覆盖：第 N 点余量护住第 N 次动作
	ap -= amount
	ap_spent += amount
	# 追兵阈值（scripted 拦截遗留；正式配置无此项）。
	var thresholds: Array = config.get("pursuer_thresholds", [])
	while pursuers_spawned < thresholds.size() and ap_spent >= int(thresholds[pursuers_spawned]):
		pursuers_spawned += 1
		_spawn_pursuer()
	# 禁地状态：分等级；到阈值即把敌人牌洗入随机地点的网格。
	var levels: Array = config.get("alert_levels", [])
	while alert_level < levels.size() and ap_spent >= int(levels[alert_level].get("at", 2147483647)):
		var lvl: Dictionary = levels[alert_level]
		alert_level += 1
		_raise_alert(lvl)
	# 警戒衰减：只有你在别处花的行动力才消警戒（每点 −1，全场其他地块）。
	_decay_alerts_away(amount)
	# 迷踪香窗倒数。
	if sneak_ap > 0:
		sneak_ap = maxi(0, sneak_ap - amount)
	# 镇物节拍（每点行动力一拍：寿命/移动/瞬移/迫近）。
	_hunt.on_ap_spent(amount)
	if ap <= 0 and outcome == "" and not is_extract_site(hero_site):
		outcome = "exhausted"
		inventory.clear()
		equipped = {"weapon": {}, "armor": {}, "bag": {}}
		_events.append("—— 力竭被擒 —— 你眼前一黑，倒在了荒郊野外。" + _pouch_survives_text())

func _decay_alerts_away(amount: int) -> void:
	var decay := amount * int(_alert_cfg().get("decay", 1))
	if decay <= 0:
		return
	for pos in sites:
		if pos == hero_site:
			continue
		for entry in sites[pos]["grid"]:
			var card: Dictionary = entry
			if card.is_empty() or str(card.get("kind", "")) not in LIVE_ENEMY_KINDS:
				continue
			if int(card.get("alert", 0)) > 0:
				var after := maxi(0, int(card["alert"]) - decay)
				card["alert"] = after
				if after < _alert_cap(card):
					card["primed"] = false  # 掉出满表解除准备态

# 倒下时锦囊的播报（死亡保底口吻；空囊不加戏）。
func _pouch_survives_text() -> String:
	if pouch.is_empty():
		return ""
	return "唯有贴身锦囊还系在腰间。"

# 禁地状态升级（M2/C-023）：随机标记 30% 地点（guardian_mark_ratio），各落一张
# 小镇物（就近空格或接尾，不重复标记同地）——镇物的免疫系统。守卫关机后只报级不标记。
func _raise_alert(lvl: Dictionary) -> void:
	var guardian_id := str(config.get("guardian_minor", ""))
	if guardians_off or guardian_id.is_empty() or not enemies.has(guardian_id):
		_events.append("禁地的怒意又深了一层（%s）——但已无人应它。" % str(lvl.get("name", "骚动")))
		return
	var positions: Array = []
	for pos in sites:
		positions.append(pos)
	if positions.is_empty():
		return
	var mark_count := maxi(1, int(ceil(positions.size() * float(config.get("guardian_mark_ratio", 0.3)))))
	var shuffled := positions.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp
	_events.append("山间嗡鸣——禁地状态·%s：石仆在暗处睁开了眼。" % str(lvl.get("name", "骚动")))
	for i in range(mini(mark_count, shuffled.size())):
		var pos: Vector2i = shuffled[i]
		var site: Dictionary = sites[pos]
		_place_card(site, {"kind": "enemy", "enemy_id": guardian_id, "alert": 0}, maxi(0, site["grid"].size() - 1))
		_events.append("%s 多了一名石仆镇守。" % _site_name(pos))

func _spawn_pursuer() -> void:
	var enemy_id := _pick(config.get("pursuer_table", []))
	_place_card(current_site(), {"kind": "pursuer", "enemy_id": enemy_id, "alert": 0}, 0)
	_events.append("山下传来哨声——追兵 %s 已至，避无可避！" % enemy_id)

# ---------- 杂项 ----------

func _can_act() -> bool:
	return outcome == ""

func _ap_table() -> Dictionary:
	return config.get("ap", {})

func _ap_cost(key: String, fallback: int) -> int:
	return int(_ap_table().get(key, fallback))

func _item(item_id: String) -> Dictionary:
	if not items.has(item_id):
		return {}
	return items[item_id].duplicate()

# ---------- 序列化（BoardCodec 委托；被动存档） ----------

func to_dict() -> Dictionary:
	return BoardCodec.to_dict(self)

# 从 to_dict 的数据整体还原（需先 load 配置）。事件日志与稀有度缓存是瞬态，不入档。
func from_dict(data: Dictionary) -> void:
	BoardCodec.from_dict(self, data)
	_events = []
	_gen.reset_cache()
