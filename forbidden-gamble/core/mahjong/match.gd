class_name MJMatch
extends RefCounted

# 对弈引擎（真气语法 v3.6 拍结构）：
# **一拍 ＝ 摸牌或招架 → 自动效果 → 附属行为（防御/变招）→ 完成一次打出（恰一次）**。
# **agent 回调＝唯一决策缝**（内容协议之外的另一道协议）：玩家 UI、敌方 AI、测试脚本同协议接入。
# 确定性（§12 纪律四）：全定点整数（气血/伤害＝百分之一单位，显示向上取整）；rng 全程种子，可复盘。
#
# ## 拍结构（v3.6）
# 正常拍：摸 3（＋罡气1）→ 缺牌补充（气力 ⌊气÷3⌋、至容量）→ 变招充能（1＋气力）→
#   在途到期发动（前摇按对方经过拍数计）→ 附属行为（变招/护体，任意次免费）→
#   打出恰一次：张数＝max(1, 手牌−静息上限)——**有超额＝普攻**（100%＋50%×副露组数，开窗可被碰/杠取消）；
#   **无超额＝虚招**（0 伤，开窗可被吃/碰/杠截走）→ 流向对方。**回气拍退役**（无死拍）。
# 破绽拍＝只自然摸牌（无附属、无打出、不解算在途、不充能）。破绽生产＝手牌清零即时触发（空手兜底）。
# 招架（吃/碰/杠＝以截代摸 → 罡气+1）：**吃仅对虚招**（成轻式入副露）；截牌拍充能照计；
#   截者打出＝**反击（不可被截、无窗）**、暂不造成伤害（COUNTER_PLAYED 插座）。
# 重击（功法＝打出）：耗式在发动那一刻入河明牌；**前摇**（默认＝式数）按对方经过拍数计，
#   到期在发射者自身摸牌后的自动效果阶段发动；**在途期间不能发动防御**（与"护体期间不能发功法"互斥）。
# 伤害管线（v3.6 K 曲线）：倍率%×攻击面板 → 承伤比 5/(5+防御) → 护体免伤 → 气血。
#
# ## decide(decision) 应答格式（按 phase；free_fire/posture 应答可附带 "defense": tech_id）
# - free_fire: {fire: [tech_id]}（引擎只取第一个可发项；发完自动进入打出）
# - posture: {discard_indexes: [手牌索引]}（张数必须＝max(1, hand.size()-rest_cap)）
# - claim: {claim_indexes: [批位]}（一次按钮多截）｜{claim: null | {type, batch_index}}（兼容旧式）
# 变招与护体走 try_bian_*/try_defense 直呼（窗口内免费操作，不入应答流）。
#
# 首发简化（待拍板项见 v3 §11）：功法耗式不开截牌窗；加杠未实装（暗杠已实装）。

enum Phase { FREE_FIRE, POSTURE, CLAIM }

var match_seed := 0
var rng := RandomNumberGenerator.new()
var wall := MJWall.new()
var river := MJRiver.new()
var fighters: Dictionary = {}   # side -> MJFighter
var techniques: Dictionary = {}  # side -> Dictionary{id -> MJTechnique}（功法槽＋护身槽）
var xinfa: Dictionary = {}       # side -> Array[MJXinfa]（心法槽，引擎直呼小协议）
var hooks := MJHooks.new()
var log: Array[String] = []
var last_marker := ""  # UI 用：最近特殊事件标记（"flaw:side:beat" 破绽——回气拍已退役）

var state := "idle"  # idle | running | over
var winner := ""
var beat := 0
var turn_side := "player"
var _phase := Phase.FREE_FIRE
var _claim_side := ""           # 截牌窗的应答方
var _counter_beat := false      # 截牌拍的打出＝反击（不可截、暂不造成伤害，v3.6）
var _xu_beat := false           # 本批打出＝虚招（无超额、0 伤、可被吃——吃仅对虚招）
var pending_batch: Array[MJTile] = []


func setup(cfg: Dictionary = {}) -> void:
	hooks = MJHooks.new()  # 每次布新局换新事件表：旧局功法监听随旧表消亡，防重复注册
	match_seed = int(cfg.get("seed", 20260915))
	rng.seed = match_seed
	wall.setup(rng)
	xinfa = {}
	for side in ["player", "enemy"]:
		var f := MJFighter.new()
		f.side = side
		f.display_name = String(cfg.get(side + "_name", "对手" if side == "enemy" else "玩家"))
		f.base_attack = int(cfg.get(side + "_base_attack", 10))
		f.base_defense = int(cfg.get(side + "_base_defense", 0))
		f.base_max_hp = int(cfg.get(side + "_base_max_hp", 100))
		f.jin_li = int(cfg.get(side + "_jin_li", 1))
		f.gu_li = int(cfg.get(side + "_gu_li", 1))
		f.qi_li = int(cfg.get(side + "_qi_li", 1))
		f.apply_neili()
		f.hp_fp = f.max_hp_fp
		fighters[side] = f
		# 构筑三轨槽（v3.5）：功法槽＋护身槽合一张注册表（kind 区分），心法槽独立
		var ids: Array = cfg.get(side + "_techniques", MJTechniqueLibrary.all_ids())
		var def_ids: Array = cfg.get(side + "_defenses", MJTechniqueLibrary.defense_ids())
		var map := {}
		for t in MJTechniqueLibrary.make_all(ids + def_ids):
			t.register(hooks, side)
			map[t.id] = t
		techniques[side] = map
		var xf_list: Array[MJXinfa] = []
		for xf_id in cfg.get(side + "_xinfa", MJTechniqueLibrary.xinfa_ids()):
			var xf := MJTechniqueLibrary.make_xinfa(str(xf_id))
			if xf != null:
				xf_list.append(xf)
		xinfa[side] = xf_list
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
	# 护体＝免费即时（附属行为阶段，v3.5）：free_fire/posture 应答可附带，先于阶段逻辑结算；
	# CLAIM 应答不带护体（截牌决定不是行动窗口——窗口在截成后的打出阶段）
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

# 拍开始：破绽检查（只自然摸牌）→ 摸牌＋罡气 → 缺牌补充 → 变招充能（按拍）→ 在途到期发动 → 打出环节。
func _begin_turn(side: String) -> void:
	turn_side = side
	_counter_beat = false
	_xu_beat = false
	var f := fighter(side)
	if f.flawed:
		f.flawed = false
		last_marker = "flaw:%s:%d" % [side, beat]
		_log("%s 露出破绽：只自然摸牌 %d 张，错失本拍" % [f.display_name, f.draw_count()])
		f.hand.append_array(_draw_with_recycle(f.draw_count()))
		f.add_gang_qi(1)  # 摸牌进账照常（不充能、不补缺）
		_end_turn_flow()
		return
	f.hand.append_array(_draw_with_recycle(f.draw_count()))
	f.add_gang_qi(1)  # 每次摸牌 +1（护体期间冻结在 fighter 内闸）
	# 缺牌补充（v3.6 气力）：正常摸牌后仍低于容量 → 补 ⌊气÷3⌋、至容量（每拍只查一次）
	var deficit := f.rest_cap() - f.hand.size()
	if deficit > 0 and f.topup_count() > 0:
		var extra := mini(f.topup_count(), deficit)
		f.hand.append_array(_draw_with_recycle(extra))
		_log("%s 缺牌补充：+%d（气力 %d）" % [f.display_name, extra, f.qi_li])
	# 变招充能（v3.6 按拍）：每个自身拍 +（1＋气力）
	f.add_bian_charge(1 + f.qi_li)
	# 自动效果：在途功法到期即发动（前摇按对方经过拍数计）
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
	var fired := false
	for id in decision.get("fire", []):
		if try_fire(turn_side, str(id), variant):
			fired = true
			break  # 每拍至多一门（try_fire 内亦有拍号闸）
	if state != "running":
		return
	if fired:
		# 重击＝本拍的打出：支付后余超额同拍整理弃置（不开窗、不追加普攻）；无超额直接收拍
		var excess := f.hand.size() - f.rest_cap()
		if excess > 0:
			var tidy: Array[MJTile] = []
			for i in range(excess):
				tidy.append(f.hand[f.hand.size() - 1 - i])
			for t in tidy:
				f.hand.erase(t)
			river.add(tidy, turn_side)
			_log("%s 重击余张整理：弃 %d 张（弃置，不开窗）" % [f.display_name, tidy.size()])
		_end_turn_flow()
		return
	if f.hand.is_empty():
		_on_hand_emptied(turn_side)  # 空手兜底（v3.6）：效果完成点即时触发
		return
	# 打出恰一次（v3.6）：未发重击 → 进入打出（无超额＝虚招，至少 1 张）
	_phase = Phase.POSTURE


func _decide_posture(decision: Dictionary) -> void:
	var f := fighter(turn_side)
	var overflow := f.hand.size() - f.rest_cap()
	var need := maxi(1, overflow)
	var xu := overflow <= 0  # 虚招实时判定（v3.6）：打出那一刻无超额（含恰好等于）
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
	# 安全网：非法输入导致张数不足时，从手牌尾补弃（打出恰一次不容跳过）
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
	hooks.emit_event(MJHooks.POSTURE, {"side": turn_side, "batch": picked.duplicate()})
	if _counter_beat:
		# 反击不可被截（v3.6）：直接入河收拍，不开窗
		river.add(picked, turn_side)
		pending_batch.clear()
		_log("%s 反击：招架后打出 %d 张（不可截、暂不造成伤害）" % [f.display_name, picked.size()])
		hooks.emit_event(MJHooks.COUNTER_PLAYED, {"side": turn_side, "batch": picked.duplicate()})
		_end_turn_flow()
		return
	_xu_beat = xu
	if xu:
		_log("%s 虚招：打出 1 张试探（0 伤，可被吃/碰/杠截走）" % f.display_name)
	else:
		_log("%s 普攻：打出 %d 张开截牌窗（可被招架取消）" % [f.display_name, picked.size()])
	_phase = Phase.CLAIM
	_claim_side = opponent(turn_side)


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


# 窗口关闭（放行）：余批入河（来源＝打出方）。普攻放行 → 伤害落地；虚招 → 无伤害（0 伤本来）。
func _close_claim_window() -> void:
	var was_xu := _xu_beat
	var batch_owner := turn_side
	river.add(pending_batch, batch_owner)
	pending_batch.clear()
	_xu_beat = false
	if not was_xu:
		_strike(batch_owner, 100 + 50 * fighter(batch_owner).melds.size(), "普攻")
	_end_turn_flow()


# 截者接续（真实招架后）：截牌拍充能照计 → 反击打出（不可截）；空手则破绽收口。
func _begin_claimant_play() -> void:
	turn_side = _claim_side
	_counter_beat = true
	_xu_beat = false
	var claimant := fighter(_claim_side)
	claimant.add_bian_charge(1 + claimant.qi_li)  # 招架拍也算一个自身拍（v3.6 按拍充能）
	if claimant.hand.is_empty():
		_on_hand_emptied(_claim_side)
		return
	_phase = Phase.POSTURE


# 截后收尾：余批入河（来源＝打出方），截者接续打出。被招架的普攻伤害已取消（v3.5）。
func _finish_claim_window() -> void:
	river.add(pending_batch, turn_side)
	pending_batch.clear()
	_xu_beat = false
	_begin_claimant_play()


# 一次按钮多截：只收当前可截位（去重），杠优先于碰、碰优先于吃；高位往低位执行防索引位移。
func _apply_multi_claim(indexes: Array) -> void:
	var type_by_batch := {}
	for option in _claim_options(fighter(_claim_side), pending_batch, _xu_beat):
		var bi := int(option["batch_index"])
		var ty := String(option["type"])
		if ty == "kan":
			type_by_batch[bi] = ty
		elif not type_by_batch.has(bi):
			type_by_batch[bi] = ty
	var picked: Array[int] = []
	for idx in indexes:
		var i := int(idx)
		if type_by_batch.has(i) and not picked.has(i):
			picked.append(i)
	picked.sort()
	picked.reverse()
	var done := 0
	for i in picked:
		if _do_one_claim(i, String(type_by_batch[i])):
			done += 1
		else:
			_log("多截中一截失败（凑不齐牌）：批位 %d 跳过，余批照入河" % i)
	if done == 0:
		_close_claim_window()  # 应答全无效＝无人招架：普攻照落地（不得白吃取消）
		return
	_finish_claim_window()


# 单个招架执行（只做效果不动流程）：吃＝顺子两张伴牌＋截牌成轻式；碰＝刻子成重式；杠＝万能式。
# 招架本身不造成伤害（v3.5）；副露面子＝常驻光环（普攻 +50%/组）。
func _do_one_claim(batch_index: int, claim_type: String) -> bool:
	var claimant := fighter(_claim_side)
	if batch_index < 0 or batch_index >= pending_batch.size():
		return false
	var tile := pending_batch[batch_index]
	var meld_tiles: Array[MJTile] = [tile]
	var need := 0
	if claim_type == "chi":
		var low := _chi_combo(claimant, tile)
		if low <= 0:
			return false
		var vals: Array[int] = [low, low + 1, low + 2]
		vals.erase(tile.value)
		for v in vals:
			for i in range(claimant.hand.size()):
				var ht: MJTile = claimant.hand[i]
				if ht.suit == tile.suit and ht.value == v and not meld_tiles.has(ht):
					meld_tiles.append(ht)
					claimant.hand.remove_at(i)
					break
	else:
		need = 2 if claim_type == "pon" else 3
		var hand_indexes: Array[int] = []
		for i in range(claimant.hand.size()):
			if (claimant.hand[i] as MJTile).same(tile):
				hand_indexes.append(i)
		if hand_indexes.size() < need:
			return false
		for k in range(need):
			meld_tiles.append(claimant.hand[hand_indexes[k]])
		for k in range(need):
			claimant.hand.remove_at(hand_indexes[need - 1 - k])
	pending_batch.remove_at(batch_index)
	var suit := tile.suit
	var symbol := ""
	if claim_type == "pon":
		symbol = MJShiki.symbol_for(MJShiki.HEAVY, suit)
	elif claim_type == "chi":
		symbol = MJShiki.symbol_for(MJShiki.LIGHT, suit)
	var meld := {"tiles": meld_tiles, "type": claim_type.to_upper(), "suit": suit, "symbol": symbol}
	claimant.melds.append(meld)
	claimant.add_gang_qi(1)  # 招架 +1（v3.5 经济；吃同族）
	var claim_name := "碰"
	if claim_type == "kan":
		claim_name = "杠"
	elif claim_type == "chi":
		claim_name = "吃"
	_log("%s 招架·%s：%s 入副露（罡气+1→%d，普攻光环+%d%%）" % [
		claimant.display_name, claim_name, tile.key(),
		claimant.gang_qi, 50 * claimant.melds.size()])
	hooks.emit_event(MJHooks.CLAIM_DONE, {"side": _claim_side, "claim_type": claim_type, "symbol": symbol, "tile": tile})
	for xf in xinfa.get(_claim_side, []):
		(xf as MJXinfa).on_claim_done(claimant)  # 拆招诀：每次招架（含吃）+1 变招充能
	if claim_type == "kan":
		# 杠：岭上摸 1（v3 §4）
		claimant.hand.append_array(_draw_with_recycle(1))
		_log("%s 杠成，岭上摸 1" % claimant.display_name)
	return true


# 吃顺子落位（吃仅对虚招，v3.6）：返回三连最小值（0＝不可吃）；确定性顺序＝low 升序取首个可付组合。
func _chi_combo(f: MJFighter, tile: MJTile) -> int:
	for low in range(maxi(tile.value - 2, MJTile.VALUE_MIN), mini(tile.value, MJTile.VALUE_MAX - 2) + 1):
		var vals: Array[int] = [low, low + 1, low + 2]
		vals.erase(tile.value)
		var ok := true
		for v in vals:
			var found := false
			for t in f.hand:
				if t.suit == tile.suit and t.value == v:
					found = true
					break
			if not found:
				ok = false
				break
		if ok:
			return low
	return 0


# ———— 暗杠（2026-09-16 用户拍板：手里摸齐四张自晒） ————
# 免费动作、不占打出、窗口＝选打出阶段（free_fire）：四张入副露成本门万能式（同截杠）
# ＋岭上摸 1＋罡气+1；不开截牌窗（成副露不是递出的牌）。之后照常选打出。
# 暗杠不是招架（没拦对方的牌）——不触发拆招诀。
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
	f.add_gang_qi(1)
	f.hand.append_array(_draw_with_recycle(1))  # 岭上摸 1（麻将原生补张）
	_log("%s 暗杠：%s 四张入副露（罡气+1→%d），岭上摸 1" % [f.display_name, key, f.gang_qi])
	hooks.emit_event(MJHooks.CLAIM_DONE, {"side": side, "claim_type": "ankan",
		"symbol": MJShiki.symbol_for(MJShiki.HEAVY, suit), "tile": quad[0]})
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


# ———— 护体（护身槽·守功法）：附属行为阶段免费即时 ————

func try_defense(side: String, tech_id: String) -> bool:
	var f := fighter(side)
	var tech: MJTechnique = techniques[side].get(tech_id)
	if tech == null or tech.kind != "defense" or f.gang_qi < tech.gang_qi_cost:
		return false
	if f.iron_active:
		return false  # 上一件铁布衫未到期不可重激活（衰减从 80% 起算的前提）
	if f.has_pending():
		return false  # 重击在途期间不能发动防御（v3.6 双向承诺互斥）
	# 窗口闸：轮到本人＋处于打出前阶段；对方回合／截牌决定／破绽拍一律不放
	if side != turn_side or (_phase != Phase.FREE_FIRE and _phase != Phase.POSTURE):
		return false
	f.gang_qi -= tech.gang_qi_cost
	var out := tech.apply_defense(f)
	for note in out.get("notes", []):
		_log(str(note))
	_log("%s 护体·%s（罡气-%d→%d；期间不能发功法、罡气冻结）" % [
		f.display_name, tech.display_name, tech.gang_qi_cost, f.gang_qi])
	return true


# ———— 重击（功法槽·攻功法）＝打出：每拍至多一门、耗式入河不回填、效果按前摇在途 ————

func try_fire(side: String, tech_id: String, variant_index := 0) -> bool:
	var f := fighter(side)
	var tech: MJTechnique = techniques[side].get(tech_id)
	if tech == null or tech.kind != "attack":
		return false
	if f.iron_active:
		return false  # 护体持续期间不能发功法（v3.5）
	if f.last_fire_beat == beat:
		return false  # 每拍一门
	if not f.pending.is_empty():
		return false  # 在途至多一门（结构性：前摇走完前不能再发射）
	var variants := _plan_variants(f, tech.recipe)
	if variant_index < 0 or variant_index >= variants.size():
		return false
	_execute_plan(f, variants[variant_index], side)
	f.last_fire_beat = beat
	var windup := tech.windup if tech.windup > 0 else _recipe_count(tech.recipe)
	f.pending.append({"tech_id": tech_id, "windup": windup, "elapsed": 0})
	_log("%s 重击·%s：%d%% 前摇 %d 拍进在途（式已入河明牌；对方经过 %d 拍后、我方摸牌后发动）" % [
		f.display_name, tech.display_name, tech.power, windup, windup])
	hooks.emit_event(MJHooks.TECH_FIRE, {"side": side, "tech_id": tech_id, "windup": windup})
	return true


func _recipe_count(recipe: Dictionary) -> int:
	var total := 0
	for sym in recipe:
		total += int(recipe[sym])
	return total


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
	# 候选一：明式（PON 精确付；KAN 本门万能付轻/重；CHI 轻式付本门轻）
	for mi in range(f.melds.size()):
		if used_melds.has(mi):
			continue
		var meld: Dictionary = f.melds[mi]
		var m_type := String(meld["type"])
		var pays := (m_type == "PON" and String(meld["symbol"]) == sym) \
			or (m_type == "CHI" and String(meld["symbol"]) == sym) \
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


# 执行支付：明式出仓入河（光环同步消失）；暗式入河。
# **不回填（v3.2）**：坑留给摸牌回填（缺牌补充可加速，v3.6）。
func _execute_plan(f: MJFighter, plan: Array[Dictionary], side: String) -> void:
	for pay in plan:
		if String(pay["src"]) == "meld":
			var meld: Dictionary = pay["meld"]
			river.add(meld["tiles"], side)
			f.melds.erase(meld)
			_log("%s 消耗明式（%s）→入气河（普攻光环降至 %d%%）" % [
				f.display_name, String(pay["symbol"]), 100 + 50 * f.melds.size()])
		else:
			var group: Dictionary = pay["group"]
			var tiles: Array = group["tiles"]
			for t in tiles:
				f.hand.erase(t)
			river.add(tiles, side)
			_log("%s 消耗暗式（%s）→入气河" % [f.display_name, String(pay["symbol"])])


# ———— 变招（v3.5 资源）：窗口内免费操作，不占打出、弃牌入河不开截牌窗 ————

# 换手牌：1 机会，弃 1 摸 1。
func try_bian_hand(side: String, hand_index: int) -> bool:
	var f := fighter(side)
	if not _in_action_window(side):
		return false
	if f.bian_opps < 1:
		return false
	if hand_index < 0 or hand_index >= f.hand.size():
		return false
	var tile := f.hand[hand_index]
	f.hand.remove_at(hand_index)
	river.add([tile], side)
	f.hand.append_array(_draw_with_recycle(1))
	f.bian_opps -= 1
	_log("%s 变招：换 %s（机会-1→%d）" % [f.display_name, tile.key(), f.bian_opps])
	hooks.emit_event(MJHooks.BIAN_DONE, {"side": side, "kind": "hand", "count": 1})
	return true


# 换面子组：3 机会，弃整组（副露明组 或 手牌暗组：3 张刻/顺、4 张杠）摸等量，每组造成 50% 伤害。
func try_bian_group(side: String, meld_index := -1, hand_indexes: Array = []) -> bool:
	var f := fighter(side)
	if not _in_action_window(side):
		return false
	if f.bian_opps < 3:
		return false
	var tiles: Array = []
	if meld_index >= 0:
		if meld_index >= f.melds.size():
			return false
		for t in f.melds[meld_index]["tiles"]:
			tiles.append(t)
		f.melds.remove_at(meld_index)
	else:
		var picked: Array[MJTile] = []
		var seen := {}
		for idx in hand_indexes:
			var i := int(idx)
			if i >= 0 and i < f.hand.size() and not seen.has(i):
				seen[i] = true
				picked.append(f.hand[i])
		if not _is_meld_group(picked):
			return false
		tiles = picked
		var idx_desc := seen.keys()
		idx_desc.sort()
		idx_desc.reverse()
		for i in idx_desc:
			f.hand.remove_at(int(i))
	river.add(tiles, side)
	f.hand.append_array(_draw_with_recycle(tiles.size()))
	f.bian_opps -= 3
	var keys: Array[String] = []
	for t in tiles:
		keys.append((t as MJTile).key())
	_log("%s 变招：换组 %s（机会-3→%d，伤 50%%）" % [f.display_name, "＋".join(keys), f.bian_opps])
	_strike(side, 50, "变招")
	hooks.emit_event(MJHooks.BIAN_DONE, {"side": side, "kind": "group", "count": tiles.size()})
	return true


# 变招/护体公共窗口闸（附属行为阶段）：摸牌后或招架后、打出前。
func _in_action_window(side: String) -> bool:
	return side == turn_side and (_phase == Phase.FREE_FIRE or _phase == Phase.POSTURE)


# 手牌组校验：3 张全同（刻）／4 张全同（杠）／同门连三（顺）。
func _is_meld_group(tiles: Array[MJTile]) -> bool:
	if tiles.size() != 3 and tiles.size() != 4:
		return false
	var all_same := true
	for t in tiles:
		if not (t as MJTile).same(tiles[0]):
			all_same = false
			break
	if all_same:
		return true
	if tiles.size() != 3:
		return false
	var suits := {}
	for t in tiles:
		suits[(t as MJTile).suit] = true
	if suits.size() != 1:
		return false
	var values: Array[int] = []
	for t in tiles:
		values.append((t as MJTile).value)
	values.sort()
	return values[1] == values[0] + 1 and values[2] == values[1] + 1


# 变招可换的组清单（请求 DTO 用）：手牌暗组（find_groups＋手牌杠）＋副露明组。
func _bian_groups(f: MJFighter) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var used := {}  # 手牌索引 -> true（被前面组占用）
	for g in MJShiki.find_groups(f.hand):
		var indexes: Array[int] = []
		for t in g["tiles"]:
			for i in range(f.hand.size()):
				if not used.has(i) and (f.hand[i] as MJTile) == t:
					used[i] = true
					indexes.append(i)
					break
		var keys: Array[String] = []
		for t in g["tiles"]:
			keys.append((t as MJTile).key())
		groups.append({"kind": "hand", "indexes": indexes, "keys": keys, "symbol": String(g["symbol"])})
	# 手牌杠（四张全同）：find_groups 只找三张组，杠组单独扫
	var by_key := {}
	for i in range(f.hand.size()):
		var k := (f.hand[i] as MJTile).key()
		if not by_key.has(k):
			by_key[k] = []
		(by_key[k] as Array).append(i)
	for k in by_key.keys():
		var idxs: Array = by_key[k]
		if idxs.size() >= 4:
			var quad: Array[int] = []
			for i in idxs.slice(0, 4):
				if not used.has(int(i)):
					quad.append(int(i))
			if quad.size() == 4:
				for i in quad:
					used[i] = true
				groups.append({"kind": "hand", "indexes": quad, "keys": [String(k), String(k), String(k), String(k)], "symbol": "杠"})
	for mi in range(f.melds.size()):
		var keys: Array[String] = []
		for t in f.melds[mi]["tiles"]:
			keys.append((t as MJTile).key())
		groups.append({"kind": "meld", "meld_index": mi, "keys": keys,
			"symbol": "杠" if String(f.melds[mi]["type"]) == "KAN" else ("吃" if String(f.melds[mi]["type"]) == "CHI" else "碰")})
	return groups


# 空手兜底（v3.6 用户定案）：任一自动效果/附属行为结算完手牌＝0 → 立刻破绽、本拍就地终止。
# 效果为原子单位（弃后摸回中间态不算）——只在完成点触发。
func _on_hand_emptied(side: String) -> void:
	if state != "running":
		return
	var f := fighter(side)
	f.flawed = true
	last_marker = "flaw:%s:%d" % [side, beat]
	_log("%s 手牌清零：露出破绽，本拍就地终止" % f.display_name)
	hooks.emit_event(MJHooks.FLAW_GAINED, {"side": side})
	_end_turn_flow()


# ———— 伤害管线（v3.6 K 曲线：倍率%×攻击面板 → 承伤比 5/(5+防御) → 护体免伤 → 气血）————
# 全程百分之一定点整数；显示一律向上取整（MJFighter.ceil_fp）。
# K 曲线（用户为解决 100% 满免伤委托重设计）：永不到免疫；每点防御＝恒定+20% 有效耐久；
# 与护体乘区叠加永不到顶。唯一下限＝伤害不为负。
func _strike(from_side: String, pct: int, source: String) -> Dictionary:
	var attacker := fighter(from_side)
	var target := fighter(opponent(from_side))
	var raw_fp := maxi(pct, 0) * attacker.attack_panel()       # 百分比×面板＝定点两位小数
	var defense := maxi(target.defense_panel(), 0)
	var after_curve := raw_fp * 5 / (5 + defense)              # 承伤比 5/(5+防御)
	var reduction := target.iron_reduction if target.iron_active else 0
	var after_iron := maxi(after_curve * (100 - reduction) / 100, 0)
	target.hp_fp = maxi(target.hp_fp - after_iron, 0)
	var display := MJFighter.ceil_fp(after_iron)
	var iron_note := ("→免伤%d%%" % reduction) if reduction > 0 else ""
	_log("%s %s：%d%%×面板%d → 承伤5/(5+%d)%s → 伤 %d（%s 气血 %d/%d）" % [
		attacker.display_name, source, pct, attacker.attack_panel(), defense, iron_note,
		display, target.display_name, target.hp_display(), target.max_hp_display()])
	if target.iron_active and reduction > 0:
		target.iron_absorbed_fp += after_curve - after_iron
		while target.iron_absorbed_fp >= 500 and target.iron_reduction > 0:
			target.iron_absorbed_fp -= 500
			target.iron_reduction = maxi(target.iron_reduction - 10, 0)
			_log("铁布衫被击渐损：免伤率 → %d%%" % target.iron_reduction)
	hooks.emit_event(MJHooks.DAMAGE_DEALT, {
		"side": opponent(from_side), "amount_fp": after_iron, "display": display, "source": source})
	_check_win()
	return {"dealt_fp": after_iron, "display": display}


# ———— 拍结束：护体计拍、前摇推进、胜负 ————

# next_owner 非空＝指定下拍归属（截牌链用）；空＝翻转到对方。
func _end_turn_flow(next_owner: String = "") -> void:
	_counter_beat = false
	_xu_beat = false
	var next_side := next_owner if next_owner != "" else opponent(turn_side)
	_beat_end()
	if state == "running":
		_begin_turn(next_side)


func _beat_end() -> void:
	var actor := turn_side
	beat += 1
	hooks.emit_event(MJHooks.BEAT_END, {"beat": beat, "actor": actor})
	# 前摇推进（v3.6）：对方经过的拍（含招架拍、破绽拍）各 +1
	for side in fighters:
		if side == actor:
			continue
		for entry in fighter(side).pending:
			entry["elapsed"] = int(entry.get("elapsed", 0)) + 1
	# 护体持续＝3 个敌方拍（敌方拍末 −1）：护体持有者的对方结束拍时递减
	for side in fighters:
		var f := fighter(side)
		if f.iron_active and side != actor:
			f.iron_beats_left -= 1
			if f.iron_beats_left <= 0:
				f.end_iron()
				_log("%s 的铁布衫到期解除" % f.display_name)
				hooks.emit_event(MJHooks.IRON_END, {"side": side})
	_check_win()


# 在途结算（v3.6 前摇）：发射者自身摸牌后的自动效果阶段调用——到期（elapsed ≥ windup）即发动；
# 未满则继续等（招架拍/破绽拍不摸牌→不进本函数，v3.3 挂起条款沿用）。结构性在途至多一门。
func _resolve_pending(side: String) -> void:
	var f := fighter(side)
	while not f.pending.is_empty():
		var entry: Dictionary = f.pending[0]
		if int(entry.get("elapsed", 0)) < int(entry.get("windup", 1)):
			return  # 前摇未满：继续等
		f.pending.pop_front()
		var tech_id := String(entry["tech_id"])
		var tech: MJTechnique = techniques[side].get(tech_id)
		if tech == null:
			continue
		var pct := tech.power
		var pct_bonus := 0
		var break_pending := false
		for result in hooks.emit_event(MJHooks.TECH_RESOLVE, {"side": side, "tech_id": tech_id, "power": pct}):
			var out: Dictionary = result["out"]
			pct_bonus += int(out.get("pct_bonus", 0))
			break_pending = break_pending or bool(out.get("break_enemy_pending", false))
			for note in out.get("notes", []):
				_log("%s" % str(note))
		_strike(side, pct + pct_bonus, "%s·在途" % tech.display_name)
		if break_pending:
			var enemy := fighter(opponent(side))
			if enemy.has_pending():
				for broken in enemy.pending:
					hooks.emit_event(MJHooks.PENDING_BROKEN, {"side": opponent(side), "tech_id": String(broken["tech_id"])})
				enemy.pending.clear()
				_log("%s 在途功法被断势击碎" % enemy.display_name)
		if state != "running":
			return


func _check_win() -> void:
	if state != "running":
		return
	for side in fighters:
		if fighter(side).hp_fp <= 0:
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


# ———— 请求构建（公开信息口径：面板/明式/罡气/变招/护体/气血全公开，手牌只给本人） ————

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
		"hp": f.hp_display(), "max_hp": f.max_hp_display(), "opp_hp": o.hp_display(),
		"attack_panel": f.attack_panel(), "defense_panel": f.defense_panel(),
		"taken_ratio": f.damage_taken_ratio(),
		"opp_taken_ratio": o.damage_taken_ratio(),
		"opp_attack_panel": o.attack_panel(),
		"gang_qi": f.gang_qi, "opp_gang_qi": o.gang_qi,
		"bian_opps": f.bian_opps, "bian_charge": f.bian_charge,
		"bian_groups": _bian_groups(f),
		"iron": _iron_view(f), "opp_iron": _iron_view(o),
		"river_count": river.size(),
		"wall_live": wall.live_left(),
	}
	match _phase:
		Phase.POSTURE:
			var overflow := f.hand.size() - f.rest_cap()
			request["discard_count"] = maxi(1, overflow)
			# 反击拍单列（2026-09-16 审计修正）：招架后的打出不可截，不得按虚招/普攻口径提示
			if _counter_beat:
				request["play_kind"] = "counter"
			else:
				request["play_kind"] = "xuzhao" if overflow <= 0 else "normal"
		Phase.CLAIM:
			request["batch"] = pending_batch.duplicate()
			request["claim_options"] = _claim_options(f, pending_batch, _xu_beat)
			request["batch_is_xu"] = _xu_beat
		Phase.FREE_FIRE:
			request["ankan_options"] = _ankan_options(f)
	request["techniques"] = _technique_view(actor)
	var own_pending: Array[Dictionary] = []
	for c in f.pending:
		var t0: MJTechnique = techniques[actor].get(String(c["tech_id"]))
		own_pending.append({
			"tech_id": String(c["tech_id"]),
			"power": t0.power if t0 != null else 0, "name": t0.display_name if t0 != null else "",
			"windup_left": maxi(int(c.get("windup", 1)) - int(c.get("elapsed", 0)), 0),
		})
	request["pending"] = own_pending
	var opp_pending: Array[Dictionary] = []
	for c in o.pending:
		var t: MJTechnique = techniques[opponent(actor)].get(String(c["tech_id"]))
		opp_pending.append({
			"tech_id": String(c["tech_id"]),
			"power": t.power if t != null else 0, "name": t.display_name if t != null else "",
			"windup_left": maxi(int(c.get("windup", 1)) - int(c.get("elapsed", 0)), 0),
		})
	request["opp_pending"] = opp_pending
	return request


func _iron_view(f: MJFighter) -> Dictionary:
	return {"active": f.iron_active, "reduction": f.iron_reduction, "beats_left": f.iron_beats_left}


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
		var windup := tech.windup if tech.windup > 0 else _recipe_count(tech.recipe)
		if tech.kind == "attack":
			# 无超额前置（2026-09-16 用户拍板"重击不要超额前置"）：静息位也可发，
			# 付式后手牌低于上限、坑留给摸牌回填——与引擎 try_fire 闸一致
			can = not f.iron_active and f.last_fire_beat != beat and f.pending.is_empty() \
				and not _plan_recipe(f, tech.recipe).is_empty()
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
			# 护体：在途期间不可发动（v3.6 双向承诺互斥）
			can = not f.iron_active and f.gang_qi >= tech.gang_qi_cost and f.pending.is_empty()
		view.append({
			"id": id, "name": tech.display_name, "kind": tech.kind,
			"summary": tech.summary(), "can_use": can,
			"gang_qi_cost": tech.gang_qi_cost,
			"recipe": tech.recipe.duplicate(), "power": tech.power, "windup": windup,
			"plans": plans,
		})
	return view


# 截牌选项：碰（对子）/杠（三张，与碰并列杠优先）——普攻与虚招皆可；
# 吃（顺子搭子）——**仅虚招批开放**（v3.6；轻式入副露）。
func _claim_options(f: MJFighter, batch: Array[MJTile], allow_chi := false) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for i in range(batch.size()):
		var tile := batch[i]
		var copies := 0
		for t in f.hand:
			if (t as MJTile).same(tile):
				copies += 1
		if copies >= 3:
			# 手里三张：碰/杠两个选项并列，玩家选（交互轮裁定；杠列前＝默认推荐位）
			options.append({"type": "kan", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, tile.suit)})
			options.append({"type": "pon", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, tile.suit)})
		elif copies >= 2:
			options.append({"type": "pon", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.HEAVY, tile.suit)})
		elif allow_chi and _chi_combo(f, tile) > 0:
			options.append({"type": "chi", "batch_index": i, "symbol": MJShiki.symbol_for(MJShiki.LIGHT, tile.suit)})
	return options


func _log(text: String) -> void:
	log.append("[拍%d] %s" % [beat, text])
