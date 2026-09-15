class_name MJMatch
extends RefCounted

# 对弈引擎（真气语法 v3.2 §3 统一循环）：**所有流程都是"摸牌开始、打出结束"**。
# **agent 回调＝唯一决策缝**（内容协议之外的另一道协议）：玩家 UI、敌方 AI、测试脚本同协议接入。
# 确定性（§12 纪律四）：全部整数；rng 全程种子，match_seed 可复盘。
#
# ## 拍结构（v3.2/v3.3）
# 正常拍：自动摸 3 → **回气判定（手牌 ≤ 静息上限 → 整拍跳过：无发功/架势/窗口，在途不解算）**
#         → **在途功法结算（v3.3：发射者可行动拍开头自动发动，先于打出选择）**
#         → 打出二选一（每拍恰一种）：
#            ①架势＝弃牌至静息上限（张数不固定）→ 开截牌窗；
#            ②功法＝耗式（占行动，每拍至多一门，效果进在途；延迟＝式数）；
#            耗式后仍超上限则续架势补齐 → 流向对方。
# 截牌拍：截 1（杠＋岭上 1）＝摸牌环节 → 打出至上限（通常 1 张）＝打出环节 → 开窗 → 换边。
#         截牌拍不能发功、不解算在途（暂定，v3 §3 钩子空间）。
# 守功法：免费即时（无打出不占行动，罡气唯一代价）。**行动期间才能放（v3.4）**：
#         轮到本人、且处于"选打出"阶段（free_fire 发功选择／posture 架势确认前）；
#         摸牌两态（摸 3／截牌）之后、出牌两态（功法／架势）之前。回气拍、破绽拍
#         整拍跳过＝无窗口；对方回合（含对方开给自己的截牌窗）＝无窗口。
#
# ## decide(decision) 应答格式（按 phase；free_fire/posture 应答可附带 "defense": tech_id 先行结算）
# - free_fire: {fire: [tech_id]}（引擎只取第一个可发项；发完自动进入架势或收拍）
# - posture: {discard_indexes: [手牌索引]}（张数必须＝hand.size()-rest_cap）
# - claim: {claim: null | {type: "pon"|"kan", batch_index: int}}
#
# 首发简化（待拍板项见 v3 §11）：功法耗式不开截牌窗；加杠未实装（暗杠已实装）。
# 截牌窗＝一次按钮多截（2026-09-16 用户定案）：弹窗灰显不可截、默认全选、点「碰」一次执行全部选中（手里≥3 自动按杠）。

enum Phase { FREE_FIRE, POSTURE, CLAIM }

const DRAW_PER_TURN := 3  # 摸 3（v3 §3：3 为参数，功法/心法可增减——当前固定，改法=此处读词条）

var match_seed := 0
var rng := RandomNumberGenerator.new()
var wall := MJWall.new()
var river := MJRiver.new()
var fighters: Dictionary = {}   # side -> MJFighter
var techniques: Dictionary = {}  # side -> Dictionary{id -> MJTechnique}
var hooks := MJHooks.new()
var log: Array[String] = []
var last_marker := ""  # UI 用：最近特殊事件标记（"rest:side:beat" 回气／"flaw:side:beat" 破绽，带拍号防连拍吞演出）

var state := "idle"  # idle | running | over
var winner := ""
var beat := 0
var turn_side := "player"
var _phase := Phase.FREE_FIRE
var _claim_side := ""           # 截牌窗的应答方
var pending_batch: Array[MJTile] = []


func setup(cfg: Dictionary = {}) -> void:
	hooks = MJHooks.new()  # 每次布新局换新事件表：旧局功法监听随旧表消亡，防重复注册
	match_seed = int(cfg.get("seed", 20260915))
	rng.seed = match_seed
	wall.setup(rng)
	for side in ["player", "enemy"]:
		var f := MJFighter.new()
		f.side = side
		f.display_name = String(cfg.get(side + "_name", "对手" if side == "enemy" else "玩家"))
		var hp := int(cfg.get(side + "_hp", 40))
		f.max_hp = hp
		f.hp = hp
		fighters[side] = f
		var ids: Array = cfg.get(side + "_techniques", MJTechniqueLibrary.all_ids())
		var map := {}
		for t in MJTechniqueLibrary.make_all(ids):
			t.register(hooks, side)
			map[t.id] = t
		techniques[side] = map
	turn_side = String(cfg.get("first_side", "player"))
	log.clear()
	state = "idle"


func fighter(side: String) -> MJFighter:
	return fighters[side]


func opponent(side: String) -> String:
	return "enemy" if side == "player" else "player"


# 开局：双方各摸 13（v3 §2），随即进入首拍（摸牌环节在拍内）。
func start_battle() -> void:
	for side in fighters:
		fighters[side].hand.append_array(wall.draw(MJFighter.REST_TOTAL))
	state = "running"
	_log("开局：双方各摸 13，先手 %s" % turn_side)
	_begin_turn(turn_side)


# ———— 请求/应答循环 ————

func next_request() -> Dictionary:
	if state != "running":
		return {}
	var actor := turn_side
	if _phase == Phase.CLAIM:
		actor = _claim_side
	return _build_request(actor)


func decide(decision: Dictionary) -> void:
	if state != "running":
		return
	# 守功法＝免费即时（行动期间，v3.4）：free_fire/posture 应答可附带，先于阶段逻辑结算；
	# CLAIM 应答不带守（截牌决定不是行动窗口——窗口在截成后的打出阶段）
	if _phase != Phase.CLAIM and decision.has("defense") and str(decision.get("defense", "")) != "":
		try_defense(turn_side, str(decision["defense"]))
	match _phase:
		Phase.FREE_FIRE:
			_decide_free_fire(decision)
		Phase.POSTURE:
			_decide_posture(decision)
		Phase.CLAIM:
			_decide_claim(decision)


# ———— 内部：拍结构 ————

# 拍开始：破绽检查 → 摸牌环节 → 回气判定 → 在途结算（v3.3）→ 进入打出环节（free_fire→posture）。
func _begin_turn(side: String) -> void:
	turn_side = side
	var f := fighter(side)
	if f.flawed:
		f.flawed = false
		last_marker = "flaw:%s:%d" % [side, beat]
		_log("%s 露出破绽，错失一拍" % f.display_name)
		_end_turn_flow()
		return
	f.hand.append_array(_draw_with_recycle(DRAW_PER_TURN))
	if f.hand.size() <= f.rest_cap():
		# 回气拍（v3.2 §3）：手牌 ≤ 静息上限——无发功、无架势、无窗口，整拍跳过
		last_marker = "rest:%s:%d" % [side, beat]
		_log("%s 回气：手牌 %d ≤ 上限 %d，跳过本拍" % [f.display_name, f.hand.size(), f.rest_cap()])
		_end_turn_flow()
		return
	# 在途功法（v3.3）：发射者能够行动的那一刻自动结算，先于本拍打出选择
	_resolve_pending(side)
	if state != "running":
		return
	_phase = Phase.FREE_FIRE


func _decide_free_fire(decision: Dictionary) -> void:
	var f := fighter(turn_side)
	# 暗杠（免费动作，不占打出）：先于功法处理；非法暗杠静默忽略
	if decision.has("ankan"):
		try_ankan(turn_side, str(decision["ankan"]))
	var variant := int(decision.get("fire_variant", 0))
	for id in decision.get("fire", []):
		if try_fire(turn_side, str(id), variant):
			break  # 每拍至多一门（try_fire 内亦有拍号闸）
	# 功法＝打出：耗式后未超上限 → 本拍的打出已完成，直接收拍；仍超 → 续架势
	if f.hand.size() > f.rest_cap():
		_phase = Phase.POSTURE
	else:
		_end_turn_flow()


func _decide_posture(decision: Dictionary) -> void:
	var f := fighter(turn_side)
	var need := f.hand.size() - f.rest_cap()
	var indexes: Array = decision.get("discard_indexes", [])
	if indexes.size() != need:
		push_warning("MJMatch: 弃牌数不符（需 %d 收到 %d）" % [need, indexes.size()])
	var picked: Array[MJTile] = []
	var seen := {}
	for idx in indexes:
		var i := int(idx)
		if i >= 0 and i < f.hand.size() and not seen.has(i):
			seen[i] = true
			picked.append(f.hand[i])
	# 安全网：非法输入导致张数不足时，从手牌尾补弃（静息不变量不容破坏）
	while picked.size() < need:
		for i in range(f.hand.size() - 1, -1, -1):
			if not seen.has(i):
				seen[i] = true
				picked.append(f.hand[i])
				break
	# 从手牌移除（按索引降序删，避免位移）
	var idx_desc := seen.keys()
	idx_desc.sort()
	idx_desc.reverse()
	for i in idx_desc:
		f.hand.remove_at(int(i))
	pending_batch = picked
	if not picked.is_empty():
		f.add_gang_qi(1)  # 架势 +1（占位）
		_log("%s 架势：打出 %d 张开截牌窗（罡气+1→%d）" % [f.display_name, picked.size(), f.gang_qi])
		hooks.emit_event(MJHooks.POSTURE, {"side": turn_side, "batch": picked.duplicate()})
		_phase = Phase.CLAIM
		_claim_side = opponent(turn_side)
	else:
		_end_turn_flow()


func _decide_claim(decision: Dictionary) -> void:
	# 一次按钮多截（2026-09-16 用户定案）：claim_indexes＝选中批位清单，一次执行全部；
	# 兼容旧式单截 {"claim": {type, batch_index}}（测试/明确指定碰或杠时用）。
	var indexes = decision.get("claim_indexes")
	if indexes is Array and not (indexes as Array).is_empty():
		_apply_multi_claim((indexes as Array).duplicate())
		return
	var claim = decision.get("claim")
	if claim is Dictionary and not (claim as Dictionary).is_empty():
		var claim_type := String(claim.get("type", ""))
		if _do_one_claim(int(claim.get("batch_index", -1)), claim_type):
			_finish_claim_window()
			return
	_close_claim_window()


# 窗口关闭（放行/非法应答）：余批入河（来源＝弃牌方），正常流向弃牌方的对面（应答方的正常拍）。
func _close_claim_window() -> void:
	river.add(pending_batch, turn_side)
	pending_batch.clear()
	_end_turn_flow()


# 截者接续（仅真实截牌后）：截牌拍＝打出至上限 → 开窗；不超上限则收拍流向对方。
func _begin_claimant_play() -> void:
	turn_side = _claim_side
	var claimant := fighter(_claim_side)
	if claimant.hand.size() > claimant.rest_cap():
		_phase = Phase.POSTURE
	else:
		_end_turn_flow()


# 截后收尾：余批入河（来源＝弃牌方），截者接续打出。
func _finish_claim_window() -> void:
	river.add(pending_batch, turn_side)
	pending_batch.clear()
	_begin_claimant_play()


# 一次按钮多截：只收当前可截位（去重），杠优先（手里≥3 即按杠）；高位往低位执行防索引位移。
func _apply_multi_claim(indexes: Array) -> void:
	var kan_ok := {}
	var pon_ok := {}
	for option in _claim_options(fighter(_claim_side), pending_batch):
		var bi := int(option["batch_index"])
		if String(option["type"]) == "kan":
			kan_ok[bi] = true
		else:
			pon_ok[bi] = true
	var picked: Array[int] = []
	for idx in indexes:
		var i := int(idx)
		if (kan_ok.has(i) or pon_ok.has(i)) and not picked.has(i):
			picked.append(i)
	picked.sort()
	picked.reverse()
	for i in picked:
		_do_one_claim(i, "kan" if kan_ok.has(i) else "pon")
	_finish_claim_window()


# 单个截牌执行（只做效果不动流程）：手牌取 need 张＋截牌 1 张成副露；碰＝本门重式、杠＝万能式。
func _do_one_claim(batch_index: int, claim_type: String) -> bool:
	var claimant := fighter(_claim_side)
	if batch_index < 0 or batch_index >= pending_batch.size():
		return false
	var tile := pending_batch[batch_index]
	var need := 2 if claim_type == "pon" else 3
	var hand_indexes: Array[int] = []
	for i in range(claimant.hand.size()):
		if (claimant.hand[i] as MJTile).same(tile):
			hand_indexes.append(i)
	if hand_indexes.size() < need:
		return false
	var meld_tiles: Array[MJTile] = [tile]
	for k in range(need):
		meld_tiles.append(claimant.hand[hand_indexes[k]])
	for k in range(need):
		claimant.hand.remove_at(hand_indexes[need - 1 - k])
	pending_batch.remove_at(batch_index)
	var suit := tile.suit
	var meld := {
		"tiles": meld_tiles, "type": claim_type.to_upper(), "suit": suit,
		"symbol": MJShiki.symbol_for(MJShiki.HEAVY, suit) if claim_type == "pon" else "",
	}
	claimant.melds.append(meld)
	claimant.add_gang_qi(2)  # 碰/杠 +2（占位）
	_log("%s %s：%s 入副露（罡气+2→%d）" % [claimant.display_name, "碰" if claim_type == "pon" else "杠", tile.key(), claimant.gang_qi])
	hooks.emit_event(MJHooks.CLAIM_DONE, {"side": _claim_side, "claim_type": claim_type, "symbol": meld["symbol"], "tile": tile})
	if claim_type == "kan":
		# 杠：岭上摸 1（v3 §4）
		claimant.hand.append_array(_draw_with_recycle(1))
		_log("%s 杠成，岭上摸 1" % claimant.display_name)
	# 明式基本招：入副露即触发一次（重式；杠的万能式按重式计，占位）
	_fire_basic_shiki(_claim_side, MJShiki.symbol_for(MJShiki.HEAVY, suit), "明")
	return true


# ———— 暗杠（2026-09-16 用户拍板：手里摸齐四张自晒） ————
# 免费动作、不占打出、窗口＝选打出阶段（free_fire）：四张入副露成本门万能式（同截杠）
# ＋岭上摸 1＋罡气+2＋重式基本招一发；不开截牌窗（成副露不是递出的牌）。之后照常选打出。
func try_ankan(side: String, key: String) -> bool:
	var f := fighter(side)
	if side != turn_side or _phase != Phase.FREE_FIRE:
		return false
	var quad: Array[MJTile] = []
	for t in f.hand:
		if (t as MJTile).key() == key:
			quad.append(t)
	if quad.size() != 4:
		return false
	for t in quad:
		f.hand.erase(t)
	var suit := (quad[0] as MJTile).suit
	f.melds.append({"tiles": quad, "type": "KAN", "suit": suit, "symbol": ""})
	f.add_gang_qi(2)
	f.hand.append_array(_draw_with_recycle(1))  # 岭上摸 1（麻将原生补张）
	_log("%s 暗杠：%s 四张入副露（罡气+2→%d），岭上摸 1" % [f.display_name, key, f.gang_qi])
	hooks.emit_event(MJHooks.CLAIM_DONE, {"side": side, "claim_type": "ankan",
		"symbol": MJShiki.symbol_for(MJShiki.HEAVY, suit), "tile": quad[0]})
	_fire_basic_shiki(side, MJShiki.symbol_for(MJShiki.HEAVY, suit), "杠")
	return true


# 暗杠选项：手里恰有四张全同的 key 列表（UI/AI 按需浮现）。
func _ankan_options(f: MJFighter) -> Array[Dictionary]:
	var by_key := {}
	for t in f.hand:
		var k := (t as MJTile).key()
		by_key[k] = int(by_key.get(k, 0)) + 1
	var options: Array[Dictionary] = []
	for k in by_key.keys():
		if int(by_key[k]) >= 4:
			options.append({"key": String(k), "suit": String(k).left(1)})
	return options


# ———— 守功法：行动期间免费即时（v3.4：摸牌后、出牌前） ————

func try_defense(side: String, tech_id: String) -> bool:
	var f := fighter(side)
	var tech: MJTechnique = techniques[side].get(tech_id)
	if tech == null or tech.kind != "defense" or f.gang_qi < tech.gang_qi_cost:
		return false
	# 窗口闸：轮到本人＋处于"选打出"阶段；对方回合／截牌决定／回气拍／破绽拍一律不放
	if side != turn_side or (_phase != Phase.FREE_FIRE and _phase != Phase.POSTURE):
		return false
	f.gang_qi -= tech.gang_qi_cost
	var out := tech.apply_defense(f)
	f.guard = int(out.get("guard_set", 0))  # 覆盖制
	for note in out.get("notes", []):
		_log(str(note))
	_log("%s 守功法·%s（罡气-%d，护境覆盖为%d）" % [f.display_name, tech.display_name, tech.gang_qi_cost, f.guard])
	return true


# ———— 攻功法＝打出（v3.2）：每拍至多一门、耗式入河不回填 ————

func try_fire(side: String, tech_id: String, variant_index := 0) -> bool:
	var f := fighter(side)
	var tech: MJTechnique = techniques[side].get(tech_id)
	if tech == null or tech.kind != "attack":
		return false
	if f.last_fire_beat == beat:
		return false  # 每拍一门
	if not f.pending.is_empty():
		return false  # 在途至多一门（结构性：结算先于再发射，此为保险闸）
	var variants := _plan_variants(f, tech.recipe)
	if variant_index < 0 or variant_index >= variants.size():
		return false
	_execute_plan(f, variants[variant_index], side)
	f.last_fire_beat = beat
	f.pending.append({"tech_id": tech_id})
	_log("%s 发动 %s：进在途（下次能够行动时自动发动）" % [f.display_name, tech.display_name])
	hooks.emit_event(MJHooks.TECH_FIRE, {"side": side, "tech_id": tech_id})
	return true


# 配方规划（默认＝第一个变体；确定性顺序：明式先、手牌组后，同符号先重后轻）。
# 返回支付清单：[{src: "meld", meld: Dictionary, symbol} | {src: "hand", symbol, group}]；不可付＝空数组。
func _plan_recipe(f: MJFighter, recipe: Dictionary) -> Array[Dictionary]:
	var variants := _plan_variants(f, recipe)
	return variants[0] if not variants.is_empty() else []


# 付法变体枚举（交互轮）：同一配方的全部支付组合（明式/暗式、哪几组），
# 供 UI 功法按钮的选项与手牌高亮。按牌组签名去重（同组不同序＝同一付法）；cap 防组合爆炸（首发 8 足够）。
func _plan_variants(f: MJFighter, recipe: Dictionary, cap := 8) -> Array[Array]:
	var results: Array[Array] = []
	_search_plans(f, recipe.duplicate(), {}, f.hand.duplicate(), [], results, {}, cap)
	return results


func _search_plans(f: MJFighter, need: Dictionary, used_melds: Dictionary, hand_pool: Array,
		plan: Array[Dictionary], results: Array[Array], seen: Dictionary, cap: int) -> void:
	if results.size() >= cap:
		return
	var sym := ""
	for s in need.keys():
		if int(need[s]) > 0:
			sym = String(s)
			break
	if sym == "":
		# 完成态签名去重：手牌 key 排序＋明式内容哈希（同组不同序＝同一付法）
		var keys: Array[String] = []
		var meld_hashes: Array[int] = []
		for pay in plan:
			if String(pay["src"]) == "hand":
				for t in pay["group"]["tiles"]:
					keys.append((t as MJTile).key())
			else:
				meld_hashes.append((pay["meld"] as Dictionary).hash())
		keys.sort()
		meld_hashes.sort()
		var sig := "%s|%s" % ["+".join(keys), str(meld_hashes)]
		if seen.has(sig):
			return
		seen[sig] = true
		results.append(plan.duplicate())
		return
	# 候选一：明式（PON 精确付；KAN 本门万能付轻/重）
	for mi in range(f.melds.size()):
		if used_melds.has(mi):
			continue
		var meld: Dictionary = f.melds[mi]
		var m_type := String(meld["type"])
		var pays := (m_type == "PON" and String(meld["symbol"]) == sym) \
			or (m_type == "KAN" and MJShiki.suit_of(sym) == String(meld["suit"]))
		if not pays:
			continue
		used_melds[mi] = true
		need[sym] = int(need[sym]) - 1
		plan.append({"src": "meld", "meld": meld, "symbol": sym})
		_search_plans(f, need, used_melds, hand_pool, plan, results, seen, cap)
		plan.remove_at(plan.size() - 1)
		need[sym] = int(need[sym]) + 1
		used_melds.erase(mi)
		if results.size() >= cap:
			return
	# 候选二：手牌暗式（该符号的每个可用组各成一枝）
	for group in MJShiki.find_groups(hand_pool):
		if String(group["symbol"]) != sym:
			continue
		var reduced: Array = hand_pool.duplicate()
		for t in group["tiles"]:
			reduced.erase(t)
		need[sym] = int(need[sym]) - 1
		plan.append({"src": "hand", "symbol": sym, "group": group})
		_search_plans(f, need, used_melds, reduced, plan, results, seen, cap)
		plan.remove_at(plan.size() - 1)
		need[sym] = int(need[sym]) + 1
		if results.size() >= cap:
			return


# 执行支付：明式出仓入河；暗式入河＋基本招触发（v3 §4：暗式在被消耗时触发）。
# **不回填（v3.2）**：坑留给未来摸牌——超发由回气拍付节奏价。
func _execute_plan(f: MJFighter, plan: Array[Dictionary], side: String) -> void:
	for pay in plan:
		if String(pay["src"]) == "meld":
			var meld: Dictionary = pay["meld"]
			river.add(meld["tiles"], side)
			f.melds.erase(meld)
			_log("%s 消耗明式（%s）→入气河" % [f.display_name, String(pay["symbol"])])
		else:
			var group: Dictionary = pay["group"]
			var tiles: Array = group["tiles"]
			for t in tiles:
				f.hand.erase(t)
			river.add(tiles, side)
			_log("%s 消耗暗式（%s）→入气河" % [f.display_name, String(pay["symbol"])])
			_fire_basic_shiki(side, String(pay["symbol"]), "暗")


# 式基本招：威力＝轻重基值＋词条加成；打对手。
func _fire_basic_shiki(side: String, symbol: String, source: String) -> void:
	var base := MJShiki.basic_damage(symbol)
	var bonus := 0
	for result in hooks.emit_event(MJHooks.SHIKI_BASIC, {"side": side, "symbol": symbol, "source": source}):
		bonus += int(result["out"].get("damage_bonus", 0))
	var amount := base + bonus
	if amount > 0:
		_log("%s %s式·%s 基本招：伤 %d" % [fighter(side).display_name, source, symbol, amount])
		_deal_damage(side, amount, "%s式基本招" % source)


# ———— 拍结束：蓄力结算、冷却、胜负 ————

# next_owner 非空＝指定下拍归属（截牌链用）；空＝翻转到对方。
func _end_turn_flow(next_owner: String = "") -> void:
	var next_side := next_owner if next_owner != "" else opponent(turn_side)
	_beat_end()
	if state == "running":
		_begin_turn(next_side)


func _beat_end() -> void:
	beat += 1
	hooks.emit_event(MJHooks.BEAT_END, {"beat": beat, "actor": turn_side})
	_check_win()


# 在途结算（v3.3）：发射者可行动拍开头调用；结构性在途至多一门，循环仅为形状统一。
func _resolve_pending(side: String) -> void:
	var f := fighter(side)
	while not f.pending.is_empty():
		var entry: Dictionary = f.pending.pop_front()
		var tech_id := String(entry["tech_id"])
		var tech: MJTechnique = techniques[side].get(tech_id)
		if tech == null:
			continue
		var power := tech.power
		var damage_bonus := 0
		var break_pending := false
		for result in hooks.emit_event(MJHooks.TECH_RESOLVE, {"side": side, "tech_id": tech_id, "power": power}):
			var out: Dictionary = result["out"]
			damage_bonus += int(out.get("damage_bonus", 0))
			if out.get("guard_set", -1) is int and int(out.get("guard_set", -1)) >= 0:
				f.guard = int(out["guard_set"])
			break_pending = break_pending or bool(out.get("break_enemy_pending", false))
			for note in out.get("notes", []):
				_log("%s" % str(note))
		var amount := power + damage_bonus
		_log("%s %s 在途结算：伤 %d" % [f.display_name, tech.display_name, amount])
		_deal_damage(side, amount, tech.display_name)
		if break_pending:
			var enemy := fighter(opponent(side))
			if enemy.has_pending():
				for broken in enemy.pending:
					hooks.emit_event(MJHooks.PENDING_BROKEN, {"side": opponent(side), "tech_id": String(broken["tech_id"])})
				enemy.pending.clear()
				_log("%s 在途功法被断势击碎" % enemy.display_name)
		if state != "running":
			return


# 伤害结算：护境覆盖制吸收→溢出扣气血（v3 不动件：护境/伤害分类简化为首发版）。
func _deal_damage(from_side: String, amount: int, source: String) -> void:
	var target := fighter(opponent(from_side))
	var to_guard := mini(amount, target.guard)
	target.guard -= to_guard
	var to_hp := amount - to_guard
	if to_hp > 0:
		target.hp = maxi(target.hp - to_hp, 0)
	_log("%s 受 %d 伤（护境抵 %d，气血-%d）←%s" % [target.display_name, amount, to_guard, to_hp, source])
	hooks.emit_event(MJHooks.DAMAGE_DEALT, {"side": opponent(from_side), "amount": amount, "source": source})
	if target.hp <= 0:
		_check_win()


func _check_win() -> void:
	if state != "running":
		return
	for side in fighters:
		if fighter(side).hp <= 0:
			state = "over"
			winner = opponent(side)
			_log("%s 气血耗尽——%s 胜" % [fighter(side).display_name, fighter(winner).display_name])
			return


# 气海干涸 → 气河整条洗回（惰性循环，v3 §1；死牌山已退役，全墙皆活）。
func _draw_with_recycle(count: int) -> Array[MJTile]:
	var drawn: Array[MJTile] = []
	for _i in range(count):
		if wall.is_dry():
			if river.size() > 0:
				_log("气海干涸：气河 %d 张整条洗回" % river.size())
				wall.recycle(river.drain(), rng)
			else:
				push_warning("MJMatch: 气海气河俱枯，摸牌短缺")
				break
		drawn.append_array(wall.draw(1))
	return drawn


# ———— 请求构建（公开信息口径：明式/罡气/蓄力/气血全公开，手牌只给本人） ————

func _build_request(actor: String) -> Dictionary:
	var f := fighter(actor)
	var o := fighter(opponent(actor))
	var request := {
		"phase": _phase_name(),
		"side": actor,
		"beat": beat,
		"hand": f.hand.duplicate(),
		"melds": f.melds.duplicate(true),
		"opp_melds": o.melds.duplicate(true),
		"hp": f.hp, "max_hp": f.max_hp, "opp_hp": o.hp,
		"gang_qi": f.gang_qi, "opp_gang_qi": o.gang_qi,
		"guard": f.guard, "opp_guard": o.guard,
		"river_count": river.size(),
		"wall_live": wall.live_left(),
	}
	match _phase:
		Phase.POSTURE:
			request["discard_count"] = f.hand.size() - f.rest_cap()
		Phase.CLAIM:
			request["batch"] = pending_batch.duplicate()
			request["claim_options"] = _claim_options(f, pending_batch)
		Phase.FREE_FIRE:
			request["ankan_options"] = _ankan_options(f)
	request["techniques"] = _technique_view(actor)
	var own_pending: Array[Dictionary] = []
	for c in f.pending:
		var t0: MJTechnique = techniques[actor].get(String(c["tech_id"]))
		own_pending.append({
			"tech_id": String(c["tech_id"]),
			"power": t0.power if t0 != null else 0, "name": t0.display_name if t0 != null else "",
		})
	request["pending"] = own_pending
	var opp_pending: Array[Dictionary] = []
	for c in o.pending:
		var t: MJTechnique = techniques[opponent(actor)].get(String(c["tech_id"]))
		opp_pending.append({
			"tech_id": String(c["tech_id"]),
			"power": t.power if t != null else 0, "name": t.display_name if t != null else "",
		})
	request["opp_pending"] = opp_pending
	return request


func _phase_name() -> String:
	match _phase:
		Phase.FREE_FIRE:
			return "free_fire"
		Phase.POSTURE:
			return "posture"
		Phase.CLAIM:
			return "claim"
	return ""


func _technique_view(side: String) -> Array[Dictionary]:
	var f := fighter(side)
	var view: Array[Dictionary] = []
	for id in techniques[side]:
		var tech: MJTechnique = techniques[side][id]
		var can := false
		var plans: Array[Dictionary] = []
		if tech.kind == "attack":
			can = f.last_fire_beat != beat and f.pending.is_empty() \
				and f.hand.size() > f.rest_cap() and not _plan_recipe(f, tech.recipe).is_empty()
			if can:
				# 付法清单（交互轮）：手牌实例 id＋耗明式数——供按钮选项与手牌高亮
				for variant in _plan_variants(f, tech.recipe):
					var ids: Array[int] = []
					var meld_count := 0
					for pay in variant:
						if String(pay["src"]) == "hand":
							for t in pay["group"]["tiles"]:
								ids.append((t as MJTile).get_instance_id())
						else:
							meld_count += 1
					plans.append({"ids": ids, "melds": meld_count})
		else:
			can = f.gang_qi >= tech.gang_qi_cost
		view.append({
			"id": id, "name": tech.display_name, "kind": tech.kind,
			"summary": tech.summary(), "can_use": can,
			"gang_qi_cost": tech.gang_qi_cost,
			"recipe": tech.recipe.duplicate(), "power": tech.power,
			"plans": plans,
		})
	return view


func _claim_options(f: MJFighter, batch: Array[MJTile]) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for i in range(batch.size()):
		var copies := 0
		for t in f.hand:
			if (t as MJTile).same(batch[i]):
				copies += 1
		if copies >= 3:
			# 手里三张：碰/杠两个选项并列，玩家选（交互轮裁定；杠列前＝默认推荐位）
			options.append({"type": "kan", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, batch[i].suit)})
			options.append({"type": "pon", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, batch[i].suit)})
		elif copies >= 2:
			options.append({"type": "pon", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, batch[i].suit)})
	return options


func _log(text: String) -> void:
	log.append("[拍%d] %s" % [beat, text])
