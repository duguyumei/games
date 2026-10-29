## 战斗管线核心（纯逻辑无 UI；qiforge 禁 class_name）。
## v0.7 属性重构：基础四维（耐久/攻/威力/攻次）；防御/抗性＝状态式；防御只减普攻；
## 伤害管线＝格挡 →（普攻）防御 → 护盾 → 耐久；间接伤害穿盾穿挡不可增减；
## 杀意/破绽/封穴平值；中毒＝尖塔制（伤＝层数，层−1）；蛊虫循环；插件 fx/excl 指令集；
## 五区牌堆＋冲弃制；能量/抽牌＝奇偶公式（QiData.energy_cap_of/draw_of）。
extends RefCounted

signal changed
signal event(text: String)
signal ended(result: String)
signal hit_landed(target: Dictionary, amount: int, kind: String)   # 普攻/功法/间接/治疗
signal pursuit_fired(attacker: Dictionary, target: Dictionary, dealt: int)   # 追击触发（带已结算量；画面在各自命中帧表现）

const DATA := preload("res://qiforge/QiData.gd")

const HAND_CAP := 7
const VULN_PER_STACK := 1        # 破绽/封穴 +1/层（v0.7 平值）
const LEIFAN_PER_STACK := 2

var rng := RandomNumberGenerator.new()
var allies: Array = []
var enemies: Array = []
var hand: Array = []
var draw_pile: Array = []
var discard_pile: Array = []
var exhaust_pile: Array = []
var energy := 0
var energy_cap := 0
var draw_base := 0
var round_no := 1
var phase := "player"
var result := ""

var _acted := {}                 # uid -> 本回合普攻过
var _kill_act_used := {}         # uid -> 本回合插件3（击杀得攻次）已用
var _atk_energy_used := {}       # uid -> 本回合插件6（普攻回能）已用
var _jg_first_used := {}         # uid -> 本回合金刚盾被动（首次普攻）已用
var _spell_played := {}          # uid -> 该器灵累计打出功法数（幽冥插件2专属）
var _shayi_gained := {}          # uid -> 该器灵累计获得杀意（幽冥升2：每 3 层抽 1）
var _mark_watch := {}            # uid -> 本回合标记的死亡回能额（索敌令）
var _enemy_intent: Array = []
var _enemy_hist := {}
var _cd_left := {}
var _card_uid := 0
var _uid := 0
var _turn_cards_played := 0
var _current_sid := ""
var _fanji_used := {}              # uid -> 本回合已反击次数（反击 N＝每回合上限 N）
var _forms := {}                   # uid -> "dao"/"jian"（两仪刀剑形态；缺键＝无形态，逐段判定）
var _cost_cut := {}                # card uid -> 本回合临时降费额（两仪升1；回合末清）
var _round_spell_used := false     # 本回合已打出过功法（两仪配件3「回合首功法 −1」充能判定）
var _playing_uid := -1             # 正在结算的卡 uid（两仪升1 随机降费排除其自身）
var _spawned_this_turn := {}       # uid -> 本回合入场（召唤物落地回合不行动）
# —— 防环（蓝本伤害管线制）——
var _chain: Array = []
var _in_pursuit := false   # 追击链内（命中上报改标「追击」——飘字/受击由追击自己的命中帧接管）
var _deferred: Array = []

func _chain_push(key: String) -> bool:
	if _chain.has(key):
		return false
	_chain.push_back(key)
	return true

func setup(run: Dictionary) -> void:
	rng.seed = int(run.get("seed", 20261026))
	energy_cap = DATA.energy_cap_of(int(run.get("sys_lv", 2)))
	draw_base = DATA.draw_of(int(run.get("sys_lv", 2)))
	allies = []
	for m in run.get("team", []):
		var hp0 := int(m.get("hp", -1))
		if hp0 == 0:
			continue   # 阵亡未复活者不上场（耐久跨场持久制 §7；复活只走回血通道）
		allies.push_back(_make_ally(String(m["id"]), m.get("equips", []), int(m.get("pdir", 0))))
		if hp0 > 0:
			allies[allies.size() - 1]["hp"] = hp0   # 上场＝带当前耐久上阵，不重置（§7）
	enemies = []
	var gi: int = int(run.get("group", 0))
	var fi: int = int(run.get("fight", 0))
	var fights: Array = DATA.GROUPS[gi]["fights"] if gi < DATA.GROUPS.size() else []
	if fi < fights.size():
		for eid in fights[fi]["enemies"]:
			enemies.push_back(_make_enemy(String(eid)))
	var deck: Array = run.get("deck", [])
	if deck.is_empty():
		deck = DATA.build_deck(run.get("team", []))
	draw_pile = []
	discard_pile = []
	exhaust_pile = []
	hand = []
	for entry in deck:
		draw_pile.push_back(_make_card_instance(entry))
	_shuffle(draw_pile)

## 战后耐久写回源（§7 耐久跨场持久）：QiRoot 胜利分支取此经 QiData.apply_team_out 写回 run
func team_out() -> Array:
	var out: Array = []
	for a in allies:
		out.push_back({"id": a["id"], "hp": maxi(0, int(a["hp"]))})
	return out

func _make_card_instance(entry: Dictionary) -> Dictionary:
	_card_uid += 1
	var spell: Dictionary = DATA.spell_of(String(entry["wid"]), String(entry["sid"]), int(entry.get("dir", 0)))
	return {"uid": _card_uid, "wid": String(entry["wid"]), "sid": String(entry["sid"]),
		"dir": int(entry.get("dir", 0)), "spell": spell,
		"reuse_left": int(spell.get("reuse", 0)), "retain": false,
		"exhaust": bool(spell.get("exhaust", false))}

func _shuffle(pile: Array) -> void:
	for i in range(pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp

func start() -> void:
	_battle_start_effects()
	_round_start()
	changed.emit()

func _battle_start_effects() -> void:
	# 插件·金刚二特殊：战斗开始获得 25% 最大生命值的护盾；
	# 通用开局挂状态（插件12 抵抗层等）：kind=battle_start_status, sid, stacks
	for a in allies:
		for fx in _fx_of(a):
			if String(fx.get("kind", "")) == "battle_start_shield_pct":
				var amt := int(int(a["mhp"]) * float(fx.get("pct", 25)) / 100.0)
				apply_status(a, "hudun", 1, amt)
				event.emit("「%s」开局获得 %d 点护盾" % [a["name"], amt])
			elif String(fx.get("kind", "")) == "battle_start_status":
				var sid := String(fx.get("sid", ""))
				apply_status(a, sid, int(fx.get("stacks", 1)))
				event.emit("「%s」开局获得 %d 层%s" % [a["name"], int(fx.get("stacks", 1)),
					String(DATA.STATUSES.get(sid, {}).get("name", sid))])

#region 单位与派生值（记录层：面板＋隐藏修正（被动/装备——不进状态栏）＋状态（功法/效果——进状态栏））
func _make_ally(wid: String, equips: Array, pdir: int) -> Dictionary:
	var w: Dictionary = DATA.WEAPONS[wid]
	var panel: Dictionary = DATA.weapon_panel(wid, equips)
	_uid += 1
	return {"uid": _uid, "side": "ally", "id": wid, "name": String(w["name"]),
		"alive": true, "hp": panel["hp"], "mhp": panel["hp"], "base": panel,
		"acts": panel["acts"], "acts_max": panel["acts"], "statuses": [],
		"bugs": 0, "pdir": pdir,
		"spells": w["spells"], "passive": w["passive"],
		"equips": equips}

func _make_enemy(eid: String) -> Dictionary:
	var e: Dictionary = DATA.ENEMIES[eid]
	var p: Dictionary = e["panel"]
	_uid += 1
	return {"uid": _uid, "side": "enemy", "id": eid, "name": String(e["name"]),
		"alive": true, "hp": p["hp"], "mhp": p["hp"], "base": p.duplicate(),
		"acts": p["acts"], "acts_max": p["acts"], "statuses": [],
		"bugs_on": 0, "pdir": 0,
		"spells": [], "passive": e.get("passive", {}), "equips": [], "actions": e["actions"]}

## 两仪剑主形态（敌方设计 v0.1 §二）：奇数回合＝刀、偶数回合＝剑；非形态单位恒 ""
func _enemy_form(e: Dictionary) -> String:
	if String(e.get("passive", {}).get("id", "")) != "yi_dao_yi_jian":
		return ""
	return "dao" if round_no % 2 == 1 else "jian"

## 敌方回合开始被动——先于掷意图，成长即时入意图显示
func _enemy_round_start_passives() -> void:
	_spawned_this_turn = {}
	for e in enemies:
		if not e["alive"]:
			continue
		var ph := String(e.get("passive", {}).get("hook", ""))
		if ph == "round_start":
			apply_status(e, String(e["passive"].get("sid", "liliang")), int(e["passive"].get("stacks", 1)))
			event.emit("「%s」被动「%s」发动" % [e["name"], String(e["passive"].get("name", ""))])
		elif ph == "round_start_adj_shield":
			# 祝祷：相邻友军获盾（撑过我方回合，于各自下次行动开始才清——敌方护盾持续制）
			var amt5 := int(e["passive"].get("value", 5)) \
				+ int(float(pow_of(e)) / float(e["passive"].get("pow_step", 4)))
			for t5 in _adjacent_in(enemies, e):
				apply_status(t5, "hudun", 1, amt5)
			event.emit("祝祷：「%s」的相邻友军获得 %d 点护盾" % [e["name"], amt5])
		elif ph == "form":
			event.emit("「%s」转入%s形态" % [e["name"], "刀" if _enemy_form(e) == "dao" else "剑"])

## 召唤入场（两仪剑主·御召）：已存活者不重复；落地回合不行动
func summon_enemy(eid: String) -> void:
	if not DATA.ENEMIES.has(eid):
		return
	for o in enemies:
		if String(o["id"]) == eid and o["alive"]:
			return
	enemies.push_back(_make_enemy(eid))
	var nu: Dictionary = enemies[enemies.size() - 1]
	_enemy_intent.push_back({})
	_spawned_this_turn[int(nu["uid"])] = true
	event.emit("召唤：「%s」入场" % nu["name"])

## 插件1（通用）：攻/防/威力 +100% 起，每回合末 −20 个百分点（只此一条百分比源）
func _pct_of(u: Dictionary) -> float:
	if not u["equips"].has("p1"):
		return 0.0
	var pct := 100.0 - 20.0 * float(round_no - 1)
	return maxf(0.0, pct) / 100.0

## 插件效果指令集：通用 fx（装谁都生效）＋专属 excl（装对应器灵才生效）
func _fx_of(u: Dictionary) -> Array:
	var out: Array = []
	if u["side"] != "ally":
		return out
	for eid in u["equips"]:
		if not DATA.ACCESSORIES.has(eid):
			continue
		var a: Dictionary = DATA.ACCESSORIES[eid]
		if not a.get("fx", {}).is_empty():
			out.push_back(a["fx"])
		var excl: Dictionary = a.get("excl", {})
		if excl.has(String(u["id"])):
			out.push_back(excl[String(u["id"])])
	return out

func _has_fx(u: Dictionary, kind: String) -> bool:
	for fx in _fx_of(u):
		if String(fx.get("kind", "")) == kind:
			return true
	return false

func atk_of(u: Dictionary) -> int:
	var v: int = int(u["base"]["atk"]) + status_total(u, "liliang") - status_total(u, "jieli")
	# 天丝升1：每一点威力 +1 攻击力（被动修正——隐藏账，实时连锁）
	if u.get("passive", {}).get("id") == "zhuiji" and int(u.get("pdir", 0)) == 1:
		v += pow_of(u)
	# 插件·金刚三专属：每有一点防御力 +1 攻击力
	if _has_fx(u, "def_atk"):
		v += def_of(u)
	return int(round(float(v) * (1.0 + _pct_of(u))))

func def_of(u: Dictionary) -> int:
	# 防御＝面板（出厂一般 0＋装备）＋状态（功法/效果给——进状态栏）；只减普攻伤害
	var v: int = int(u["base"]["def"]) + status_total(u, "hujia") - status_total(u, "pojia")
	return int(round(float(v) * (1.0 + _pct_of(u))))

func res_of(u: Dictionary) -> int:
	return int(u["base"]["res"]) + _status_valued(u, "kangxing")

func pow_of(u: Dictionary) -> int:
	var v: int = int(u["base"]["pow"]) + status_total(u, "qiangdu")
	# 插件·丝蛊同源（青蛊铃专属）：每只蛊虫 +1 威力（装备修正——隐藏账）
	if _has_fx(u, "bug_pow"):
		v += int(u.get("bugs", 0))
	return int(round(float(v) * (1.0 + _pct_of(u))))

func _status_valued(u: Dictionary, sid: String) -> int:
	var v := 0
	for s in u["statuses"]:
		if s["sid"] == sid:
			v += int(s["value"]) * int(s["stacks"])
	return v
#endregion

#region 状态实例制（抵抗＝挡下一次敌方施加的负面状态）
func status_total(u: Dictionary, sid: String) -> int:
	var n := 0
	for s in u["statuses"]:
		if s["sid"] == sid:
			n += int(s["stacks"])
	return n

func has_status(u: Dictionary, sid: String) -> bool:
	return status_total(u, sid) > 0

## 护盾总量（数值在 value×stacks；显示层用——STS2 制血条盾徽读数）
func shield_of(u: Dictionary) -> int:
	return _status_valued(u, "hudun")

func apply_status(dst: Dictionary, sid: String, stacks: int, value: int = 0,
		rounds: int = -1, abnormal: bool = false, src: Variant = null) -> void:
	if not dst["alive"] or stacks <= 0:
		return
	# 抵抗：免疫下一次受到的负面状态（只挡敌方施加——我方主动挂的嘲讽等不吃抵抗）
	if bool(DATA.STATUSES[sid].get("debuff", false)) and status_total(dst, "dikang") > 0 \
			and src is Dictionary and not src.is_empty() and src.get("side", "") != dst.get("side", ""):
		_consume_stacks(dst, "dikang", 1)
		event.emit("「%s」抵抗了「%s」" % [dst["name"], DATA.STATUSES[sid]["name"]])
		return
	var land := stacks
	if abnormal:
		land = int(floor(float(stacks) * (100.0 - float(res_of(dst))) / 100.0))
		if land <= 0:
			event.emit("「%s」的抗性完全抵挡了「%s」" % [dst["name"], DATA.STATUSES[sid]["name"]])
			return
	# 蛊虫增幅（v0.7 §6）：敌方被施加毒时 +该敌身上蛊虫数
	if sid == "zhongdu" and dst.get("side") == "enemy" and int(dst.get("bugs_on", 0)) > 0:
		land += int(dst["bugs_on"])
		event.emit("蛊虫增幅：「%s」毒 +%d 层" % [dst["name"], int(dst["bugs_on"])])
	for s in dst["statuses"]:
		if s["sid"] == sid:
			s["stacks"] = int(s["stacks"]) + land
			s["value"] = maxi(int(s["value"]), value)
			if rounds > 0:
				s["rounds"] = maxi(int(s["rounds"]), rounds)
			event.emit("「%s」获得「%s」%d 层（共 %d 层）" % [dst["name"], DATA.STATUSES[sid]["name"], land, status_total(dst, sid)])
			return
	dst["statuses"].push_back({"sid": sid, "stacks": land, "value": value, "rounds": rounds})
	event.emit("「%s」获得「%s」%d 层" % [dst["name"], DATA.STATUSES[sid]["name"], land])
#endregion

#region 伤害管线（格挡 →（普攻）防御 → 护盾 → 耐久；间接＝穿全直扣）
## channel: "普攻"/"功法"；opts: {indirect: 间接伤害}
func resolve_damage(src: Dictionary, dst: Dictionary, base_amt: float, channel: String,
		opts: Dictionary = {}) -> int:
	if not dst["alive"] or base_amt <= 0:
		return 0
	# —— 间接伤害：穿护盾穿格挡、不吃防御、不可增减、不触发反震（直扣耐久）——
	if opts.get("indirect", false):
		var ind := maxi(1, int(round(base_amt)))
		dst["hp"] = maxi(0, int(dst["hp"]) - ind)
		event.emit("「%s」受到 %d 点间接伤害" % [dst["name"], ind])
		hit_landed.emit(dst, ind, "间接")
		_after_deal_damage(src, dst, ind)
		if dst["hp"] <= 0:
			_on_death(src, dst)
		return ind
	# 格挡：免疫下一次受到的伤害（多段只挡一段）
	if status_total(dst, "gebi") > 0:
		_consume_stacks(dst, "gebi", 1)
		event.emit("「%s」格挡了伤害" % dst["name"])
		return 0
	var amt := base_amt
	# 攻方侧：三通道取最高（杀意平值入功法通道，专属改所有；怒意/虚弱＝命名倍率）
	var shayi_per := 2 if (src.get("passive", {}).get("id") == "sha_yi" and int(src.get("pdir", 0)) == 1) else 1
	var shayi := float(status_total(src, "shayi")) * float(shayi_per)
	var pools := {"所有": 0.0, "普攻": 0.0, "功法": 0.0}
	if _has_fx(src, "shayi_all"):
		pools["所有"] += shayi
	else:
		pools["功法"] += shayi
	var bonus: float = pools["所有"]
	if pools.has(channel):
		bonus = maxf(bonus, pools[channel])
	amt += bonus
	if status_total(src, "xuruo") > 0:
		amt *= 0.75   # 虚弱＝−25%（蓝本 0.75 同制；层＝时长不叠深）
	if channel == "普攻" and status_total(src, "nuyi") > 0:
		amt *= 1.5
	if status_total(src, "fengmang") > 0:
		amt += float(status_total(src, "fengmang"))   # 锋芒：直伤固定值 +1/层（间接旁路不吃）
	# 受方侧：易伤两层并算（破绽吃普攻／封穴吃功法；+1/层）＋脆弱（攻击伤×1.5）＋韧性（直伤−1/层）
	if channel == "普攻":
		amt += VULN_PER_STACK * status_total(dst, "poxian")
		if status_total(dst, "cuiruo") > 0:
			amt *= 1.5
	elif channel == "功法":
		amt += VULN_PER_STACK * status_total(dst, "fengxue")
	amt -= float(status_total(dst, "renxing"))
	var total := maxi(1, int(round(amt)))
	# 防御＝固定减伤（只减普攻通道；功法伤害无防御降低）
	if channel == "普攻":
		total = maxi(1, total - def_of(dst))
	# 护盾吸收（先挂先消）
	if status_total(dst, "hudun") > 0 and total > 0:
		var absorb := _absorb_shield(dst, total)
		total -= absorb
		if absorb > 0:
			event.emit("「%s」的护盾吸收了 %d 点" % [dst["name"], absorb])
	var dealt := 0
	if total > 0:
		dealt = total
		dst["hp"] = maxi(0, int(dst["hp"]) - total)
		event.emit("「%s」对「%s」造成 %d 点%s伤害" % [src["name"], dst["name"], total, channel])
		hit_landed.emit(dst, total, "追击" if _in_pursuit else channel)
		_after_deal_damage(src, dst, total)
		_form_check(src, channel)
		# 插件5（通用）：每次攻击造成一层破绽（持续 1 回合）——逐段独立
		if src.get("side") == "ally" and _has_fx(src, "hit_poxian") and dst["alive"]:
			apply_status(dst, "poxian", int(1), 0, 1, true, src)
		if dst["hp"] <= 0:
			_on_death(src, dst)
		else:
			# 金刚盾升1：耐久损伤→等量护盾＋1 层护甲（2026-10-28 面板状态具名制）
			if dst.get("passive", {}).get("id") == "tie_bi" and int(dst.get("pdir", 0)) == 1 and dealt > 0:
				apply_status(dst, "hudun", 1, dealt)
				apply_status(dst, "hujia", 1)
				event.emit("铁壁·升1：「%s」获得 %d 点护盾与 1 层护甲" % [dst["name"], dealt])
			# —— 反震/反击＝即时插入（2026-10-27 用户裁定：不排延迟队列，落地后原地结算；
			#    反震伤走间接＝天然不再触发受方后置位，无环；血统键保同链一来一回封顶）——
			if src.get("side", "") != dst.get("side", "") and src["alive"]:
				var lei := status_total(dst, "leifan")
				if lei > 0 and _chain_push("leifan#%d#reflect" % dst["uid"]):
					var lei_amt := LEIFAN_PER_STACK * lei
					event.emit("雷反：「%s」向「%s」反震 %d 点" % [dst["name"], src["name"], lei_amt])
					resolve_damage(dst, src, float(lei_amt), "功法", {"indirect": true})
					_chain.pop_back()
				# 插件·金刚一专属：拥有护盾时 50% 反震（间接）
				if _has_fx(dst, "shield_fanzhen") and status_total(dst, "hudun") > 0 and src["alive"]:
					var fz_amt := int(round(dealt * 0.5))
					event.emit("反震：「%s」向「%s」反震 %d 点间接伤害" % [dst["name"], src["name"], fz_amt])
					resolve_damage(dst, src, float(fz_amt), "功法", {"indirect": true})
				# 反击：受伤后即刻普攻回击（不耗攻次；上限＝层数/回合；血统键防环）
				if status_total(dst, "fanji") > int(_fanji_used.get(dst["uid"], 0)) \
						and dst["alive"] and src["alive"] \
						and _chain_push("fanji#%d#hit" % dst["uid"]):
					_fanji_used[dst["uid"]] = int(_fanji_used.get(dst["uid"], 0)) + 1
					event.emit("反击：「%s」向「%s」反击" % [dst["name"], src["name"]])
					_basic_attack(dst, src)
					_chain.pop_back()
		# 普攻段命中后钩子（2026-10-28「视为普通攻击」口径）：真实普攻与功法内普攻段共用——
		# 铁壁/插件6/破绽/追击/回耐久等普攻系词条在功法内普攻段同样触发（不耗攻次；仅普攻通道）
		if channel == "普攻" and src.get("side", "") == "ally" and src.get("alive", false):
			_after_attack_landed(src, dst)
	return dealt

func _after_deal_damage(src: Dictionary, dst: Dictionary, amount: int) -> void:
	if amount <= 0 or not src.get("alive", false):
		return
	# 杀意（幽冥剑被动）：造成伤害后 +1 层（任何通道含间接）
	if src.get("side") == "ally" and src.get("passive", {}).get("id") == "sha_yi":
		_gain_shayi(src, 1)

func _gain_shayi(a: Dictionary, n: int) -> void:
	apply_status(a, "shayi", n)
	_shayi_gained[a["uid"]] = int(_shayi_gained.get(a["uid"], 0)) + n
	# 幽冥升2：每累计获得 3 层杀意抽一张牌
	if a.get("passive", {}).get("id") == "sha_yi" and int(a.get("pdir", 0)) == 2 \
			and int(_shayi_gained[a["uid"]]) >= 3 and a["alive"]:
		_shayi_gained[a["uid"]] = int(_shayi_gained[a["uid"]]) % 3
		event.emit("杀意·升2：累计 3 层，抽一张牌")
		draw_cards(1)

## 两仪刀剑「亦刀亦剑」形态机（逐段判定；仅形态实际改变时触发）：
## 普攻伤害段→刀（+1 层强度）、功法伤害段→剑（+1 层力量）；间接伤害旁路不触发；
## 升1＝转换后随机手牌功法 −1 费；升2＝转换后全队护盾 3+威/5（按自身威力，实时连锁）。
func _form_check(src: Dictionary, channel: String) -> void:
	if src.get("side", "") != "ally" or not src.get("alive", false):
		return
	if src.get("passive", {}).get("id", "") != "yi_dao_yi_jian":
		return
	var want := "dao" if channel == "普攻" else "jian"
	if String(_forms.get(int(src["uid"]), "")) == want:
		return
	_forms[int(src["uid"])] = want
	event.emit("亦刀亦剑：「%s」转为%s形态" % [src["name"], "刀" if want == "dao" else "剑"])
	if want == "dao":
		apply_status(src, "qiangdu", 1)
	else:
		apply_status(src, "liliang", 1)
	if int(src.get("pdir", 0)) == 1:
		_discount_random_spell()
	elif int(src.get("pdir", 0)) == 2:
		var amt6 := 3 + int(float(pow_of(src)) / 5.0)
		for t6 in allies:
			if t6["alive"]:
				apply_status(t6, "hudun", 1, amt6)
		event.emit("亦刀亦剑·升2：全队获得 %d 点护盾" % amt6)
	if _has_fx(src, "form_shayi"):
		for t6 in allies:
			if t6["alive"]:
				_gain_shayi(t6, 1)
	if want == "jian" and _has_fx(src, "jian_draw"):
		draw_cards(1)
	if want == "dao" and _has_fx(src, "dao_act"):
		var cap6 := int(_fx_val(src, "dao_act", "cap", 9))
		if int(src["acts"]) < cap6:
			src["acts"] = int(src["acts"]) + 1
			event.emit("两仪二：「%s」攻击次数 +1（现 %d）" % [src["name"], int(src["acts"])])

## 两仪升1：随机一张手牌功法 −1 费（至回合末，可叠，封 0；排除正在结算的卡）
func _discount_random_spell() -> void:
	var pool6: Array = []
	for c in hand:
		if int(c["uid"]) != _playing_uid:
			pool6.push_back(c)
	if pool6.is_empty():
		return
	var pick6: Dictionary = pool6[rng.randi_range(0, pool6.size() - 1)]
	var cut_uid := int(pick6["uid"])
	_cost_cut[cut_uid] = int(_cost_cut.get(cut_uid, 0)) + 1
	event.emit("亦刀亦剑·升1：「%s」本回合费用 −%d" % [pick6["spell"]["name"], int(_cost_cut[cut_uid])])

## 敌方目标＋动态相邻（左右各取最近存活者，与战场行收拢相邻一致）
func _target_and_adjacent_enemies(target: Dictionary) -> Array:
	var out6 := [target]
	var idx6 := enemies.find(target)
	if idx6 >= 0:
		var lo6 := idx6 - 1
		while lo6 >= 0 and not enemies[lo6]["alive"]:
			lo6 -= 1
		if lo6 >= 0:
			out6.push_back(enemies[lo6])
		var hi6 := idx6 + 1
		while hi6 < enemies.size() and not enemies[hi6]["alive"]:
			hi6 += 1
		if hi6 < enemies.size():
			out6.push_back(enemies[hi6])
	return out6

func _absorb_shield(dst: Dictionary, amount: int) -> int:
	var left := amount
	for s in dst["statuses"]:
		if left <= 0:
			break
		if s["sid"] != "hudun":
			continue
		var pool: int = int(s["value"]) * int(s["stacks"])
		var take: int = mini(left, pool)
		pool -= take
		left -= take
		s["stacks"] = int(ceil(float(pool) / float(maxi(1, int(s["value"])))))
		if pool <= 0:
			s["stacks"] = 0
	for i in range(dst["statuses"].size() - 1, -1, -1):
		if dst["statuses"][i]["sid"] == "hudun" and dst["statuses"][i]["stacks"] <= 0:
			dst["statuses"].remove_at(i)
	return amount - left

func _consume_stacks(u: Dictionary, sid: String, n: int) -> void:
	for s in u["statuses"]:
		if s["sid"] == sid:
			s["stacks"] = maxi(0, int(s["stacks"]) - n)
	for i in range(u["statuses"].size() - 1, -1, -1):
		if u["statuses"][i]["sid"] == sid and u["statuses"][i]["stacks"] <= 0:
			u["statuses"].remove_at(i)

func _on_death(src: Dictionary, dst: Dictionary) -> void:
	var poison_left := status_total(dst, "zhongdu")
	var bugs_left := int(dst.get("bugs_on", 0))
	var death_passive := String(dst.get("passive", {}).get("hook", "")) == "on_death"
	dst["alive"] = false
	dst["statuses"] = []
	event.emit("「%s」离场" % dst["name"])
	if dst["side"] == "enemy":
		# 死咒（力士）：我方攻击力最高的器灵获得 3 层虚弱
		if death_passive:
			var best: Dictionary = {}
			for a in allies:
				if a["alive"] and (best.is_empty() or atk_of(a) > atk_of(best)):
					best = a
			if not best.is_empty():
				apply_status(best, "xuruo", 3)
				event.emit("死咒：「%s」获得 3 层虚弱" % best["name"])
		# 索敌令：本回合被标记者死亡 → 回能（挂账表触发）
		if _mark_watch.has(dst["uid"]):
			gain_energy(int(_mark_watch[dst["uid"]]))
			event.emit("索敌令：被标记者死亡，能量 +%d" % int(_mark_watch[dst["uid"]]))
			_mark_watch.erase(dst["uid"])
		# 杀意：每有一名敌方死亡 +1 层
		for a in allies:
			if a["alive"] and a.get("passive", {}).get("id") == "sha_yi":
				_gain_shayi(a, 1)
		# 青蛊铃升2：敌人死亡时身上蛊虫回归
		if bugs_left > 0:
			for a in allies:
				if a["alive"] and a.get("passive", {}).get("id") == "yang_gu" and int(a.get("pdir", 0)) == 2:
					a["bugs"] = int(a["bugs"]) + bugs_left
					event.emit("养蛊·升2：回收 %d 只蛊虫" % bugs_left)
		# 插件3（通用）：一回合一次敌人死亡 +1 攻次；插件·青蛊三特殊：剩余毒一半转移
		for a in allies:
			if a["alive"] and a["equips"].has("p3") and not _kill_act_used.get(a["uid"], false):
				_kill_act_used[a["uid"]] = true
				a["acts"] = int(a["acts"]) + 1
				event.emit("插件3：「%s」攻击次数 +1" % a["name"])
			if a["alive"] and _has_fx(a, "poison_transfer") and poison_left >= 2:
				var pool := _alive_enemies()
				if not pool.is_empty():
					var to: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
					apply_status(to, "zhongdu", int(poison_left / 2.0), 0, -1, true)
					event.emit("尸毒转移：「%s」的 %d 层毒转给「%s」" % [dst["name"], int(poison_left / 2.0), to["name"]])
		# 死亡扩散（蓝本制：毒向同侧邻位扩散一半层数）
		var idx := enemies.find(dst)
		if poison_left >= 2:
			for ni in [idx - 1, idx + 1]:
				if ni >= 0 and ni < enemies.size() and enemies[ni]["alive"]:
					_deferred.push_back({"kind": "spread", "to": enemies[ni],
						"stacks": int(poison_left / 2.0), "from_name": dst["name"]})
	elif dst["side"] == "ally":
		_wipe_wid_cards(String(dst["id"]))

func _wipe_wid_cards(wid: String) -> void:
	var n := 0
	for pile_name in ["hand", "draw_pile", "discard_pile", "exhaust_pile"]:
		var pile: Array = get(pile_name)
		for i in range(pile.size() - 1, -1, -1):
			if String(pile[i]["wid"]) == wid:
				pile.remove_at(i)
				n += 1
	if n > 0:
		event.emit("阵亡牌消：「%s」的 %d 张功法从各牌区消失" % [DATA.WEAPONS[wid]["name"], n])
#endregion

#region 我方操作
## 费用＝实时查询制（2026-10-28 立，STS2 制）：显示/校验/扣费三处同一活查询，
## 临时降费与形态条件随状态即时跳；恢复时点＝首张功法提交打出时（非结算完）。
func card_cost(card: Dictionary) -> int:
	var c := int(card["spell"]["cost"])
	c -= int(_cost_cut.get(int(card["uid"]), 0))   # 两仪升1：随机功法 −1（至回合末，封 0）
	if not _round_spell_used and _first_spell_free_ready():
		c -= 1                                      # 两仪配件3：回合首功法 −1（充能期全牌面同显）
	var owner := _owner_of(card)
	if String(card["sid"]) == "daojian" and int(card.get("dir", 0)) == 2 \
			and not owner.is_empty() and String(_forms.get(int(owner["uid"]), "")) == "dao":
		c = 0                                       # 刀剑合击·升二：刀形态下 0 费
	return maxi(0, c)

func _first_spell_free_ready() -> bool:
	for a in allies:
		if a["alive"] and _has_fx(a, "first_spell_free"):
			return true
	return false

func can_play(card: Dictionary) -> bool:
	if phase != "player":
		return false
	var owner := _owner_of(card)
	if owner.is_empty():
		return false
	return energy >= card_cost(card) and not has_status(owner, "xuan")

## 拖放目标校验（2026-10-28 尸姬 CheckCardUse 制·单一事实源）：无效目标在 drop_ok 即被挡、
## 根本进不了结算（修「引丝诀拖到归属器灵＝卡飞出被拒后悬空卡死」）；屏侧高亮/落点共用本口径。
func can_target(card: Dictionary, target: Dictionary) -> bool:
	if card.is_empty() or not can_play(card):
		return false
	var st := String(card["spell"]["target"])
	if target.is_empty():
		return st == "none"
	if not target.get("alive", false):
		return false
	match st:
		"enemy":
			return String(target.get("side", "")) == "enemy"
		"ally":
			if String(target.get("side", "")) != "ally":
				return false
			# 「其他器灵」限定（引丝诀基础/升一）：归属者自己是无效目标
			var owner := _owner_of(card)
			for op in card["spell"]["ops"]:
				if bool(op.get("others", false)) and not owner.is_empty() \
						and int(target["uid"]) == int(owner["uid"]):
					return false
			return true
	return false

func _owner_of(card: Dictionary) -> Dictionary:
	for a in allies:
		if a["id"] == card["wid"] and a["alive"]:
			return a
	return {}

func normal_attack(a: Dictionary, e: Dictionary) -> void:
	if phase != "player" or not a["alive"] or not e["alive"]:
		return
	if int(a["acts"]) <= 0 or has_status(a, "jiaoxie") or has_status(a, "xuan"):
		event.emit("「%s」无法普攻" % a["name"])
		return
	a["acts"] = int(a["acts"]) - 1
	_acted[a["uid"]] = true
	_basic_attack(a, e)
	_drain_deferred()
	check_end()
	changed.emit()

## 普攻一次（含追击/反击）：命中后钩子由 resolve_damage 普攻段落地处统一触发
func _basic_attack(a: Dictionary, e: Dictionary) -> void:
	resolve_damage(a, e, float(atk_of(a)), "普攻")

## 普攻命中后全套钩子（真实普攻与功法内普攻段共用；不耗攻次）
func _after_attack_landed(a: Dictionary, e: Dictionary) -> void:
	# 金刚盾被动：每回合自身第一次普攻后，自身＋相邻各 +1 防御
	if a.get("passive", {}).get("id") == "tie_bi" and not _jg_first_used.get(a["uid"], false):
		_jg_first_used[a["uid"]] = true
		for u in _self_and_adjacent(a):
			apply_status(u, "hujia", 1)
		event.emit("铁壁：「%s」与相邻器灵获得 1 层护甲" % a["name"])
	# 插件6（通用）：一回合一次普攻后 +1 能量
	if a["equips"].has("p6") and not _atk_energy_used.get(a["uid"], false):
		_atk_energy_used[a["uid"]] = true
		gain_energy(1)
		event.emit("插件6：「%s」能量 +1" % a["name"])
	# 插件·幽冥一特殊：造成普攻伤害后敌方 1 层破绽（持续 2 回合）
	if _has_fx(a, "atk_poxian") and e["alive"]:
		apply_status(e, "poxian", 1, 0, 2, true, a)
	# 插件·丝蛊同源（天丝专属）：每次普攻后敌方 3 层竭力、自身 3 层力量（2026-10-28 面板状态具名制）
	if _has_fx(a, "drain_atk") and e["alive"]:
		apply_status(e, "jieli", 3, 0, -1, false, a)
		apply_status(a, "liliang", 3, 0, -1, false, a)
		event.emit("丝蛊同源：「%s」获得 3 层竭力，自身获得 3 层力量" % e["name"])
	# 插件·天丝二专属：普攻后敌人每有一种减益状态汲取 1 点最大生命值
	if _has_fx(a, "drain_mhp_per_debuff") and e["alive"]:
		var kinds := 0
		var seen := {}
		for s in e["statuses"]:
			if bool(DATA.STATUSES[s["sid"]].get("debuff", false)) and not seen.has(s["sid"]):
				seen[s["sid"]] = true
				kinds += 1
		if kinds > 0:
			e["mhp"] = maxi(1, int(e["mhp"]) - kinds)
			e["hp"] = mini(int(e["hp"]), int(e["mhp"]))
			a["mhp"] = int(a["mhp"]) + kinds
			a["hp"] = mini(int(a["mhp"]), int(a["hp"]) + kinds)
			event.emit("天丝二：汲取 %d 点最大生命值" % kinds)
	# 插件·天丝三专属：每次普攻后自身获得一只蛊虫
	if _has_fx(a, "atk_bug"):
		a["bugs"] = int(a["bugs"]) + 1
	# 插件·金刚二专属：普攻后随机器灵获得一层格挡
	if _has_fx(a, "atk_block"):
		var pool_a: Array = []
		for t0 in allies:
			if t0["alive"]:
				pool_a.push_back(t0)
		if not pool_a.is_empty():
			var lucky: Dictionary = pool_a[rng.randi_range(0, pool_a.size() - 1)]
			apply_status(lucky, "gebi", 1)
	# 插件·两仪二特殊：每次普攻后恢复 5 点耐久
	if _has_fx(a, "atk_heal"):
		var heal := int(_fx_val(a, "atk_heal", "hp", 5))
		a["hp"] = mini(int(a["mhp"]), int(a["hp"]) + heal)
		event.emit("两仪二：「%s」恢复 %d 点耐久" % [a["name"], heal])
	# 插件·青蛊三专属：每次普通攻击触发一次敌人的毒
	if _has_fx(a, "atk_poison_tick") and e["alive"] and status_total(e, "zhongdu") > 0:
		_poison_tick(e)
	# 天丝升2：普攻攻击施加一层毒
	if a.get("passive", {}).get("id") == "zhuiji" and int(a.get("pdir", 0)) == 2 and e["alive"]:
		apply_status(e, "zhongdu", 1, 0, -1, true, a)
	# 追击：其他器灵普攻时自动追加（不耗攻次；同链每个追击者至多一次）
	for t in allies:
		if t["alive"] and t["uid"] != a["uid"] and t.get("passive", {}).get("id") == "zhuiji" \
				and not has_status(t, "jiaoxie") and not has_status(t, "xuan") and e["alive"] \
				and _chain_push("zhuiji#%d#hit" % t["uid"]):
			event.emit("追击：「%s」自动追加普攻" % t["name"])
			var hp_before := int(e["hp"])
			_in_pursuit = true
			_basic_attack(t, e)
			_in_pursuit = false
			pursuit_fired.emit(t, e, int(hp_before) - int(e["hp"]))
			_chain.pop_back()

## 相邻＝战场动态判定（2026-10-28 用户裁定）：左右各取最近存活者，阵亡者不占位——
## 与战斗行「阵亡整槽收拢居中」的视觉相邻一致；备战槽位序只定初始排布。
func _self_and_adjacent(a: Dictionary) -> Array:
	var out := [a]
	for u in _adjacent(a):
		out.push_back(u)
	return out

func _adjacent(a: Dictionary) -> Array:
	return _adjacent_in(allies, a)

## 动态相邻（左右各取最近存活者，阵亡不占位——敌我两侧同制）
func _adjacent_in(arr: Array, u: Dictionary) -> Array:
	var out: Array = []
	var idx := arr.find(u)
	if idx < 0:
		return out
	var lo := idx - 1
	while lo >= 0 and not arr[lo]["alive"]:
		lo -= 1
	if lo >= 0:
		out.push_back(arr[lo])
	var hi := idx + 1
	while hi < arr.size() and not arr[hi]["alive"]:
		hi += 1
	if hi < arr.size():
		out.push_back(arr[hi])
	return out

## 延迟队列（v3：反震/反击已改即时插入，本队列只剩尸毒扩散）
func _drain_deferred() -> void:
	var guard := 0
	while not _deferred.is_empty():
		guard += 1
		if guard > 400:
			_deferred.clear()
			break
		var act: Dictionary = _deferred.pop_front()
		if String(act.get("kind", "")) == "spread":
			var to: Dictionary = act["to"]
			if to["alive"] and int(act["stacks"]) > 0:
				event.emit("尸毒蔓延：「%s」的毒向「%s」扩散 %d 层" % [act["from_name"], to["name"], act["stacks"]])
				apply_status(to, "zhongdu", int(act["stacks"]), 0, -1, true)

## 普攻命中预估（纯查询，2026-10-28 起严格镜像 resolve_damage 普攻通道：
## 杀意「所有」池＋虚弱/怒意倍率＋受方破绽−防御，封底 1）
func _preview_hit(a: Dictionary, e: Dictionary) -> int:
	var amt := float(atk_of(a))
	var shayi_per := 2 if (a.get("passive", {}).get("id") == "sha_yi" and int(a.get("pdir", 0)) == 1) else 1
	if _has_fx(a, "shayi_all"):
		amt += float(status_total(a, "shayi")) * float(shayi_per)
	if status_total(a, "xuruo") > 0:
		amt *= 0.75
	if status_total(a, "nuyi") > 0:
		amt *= 1.5
	amt += float(status_total(a, "fengmang"))
	amt += VULN_PER_STACK * float(status_total(e, "poxian"))
	if status_total(e, "cuiruo") > 0:
		amt *= 1.5
	return maxi(1, int(round(amt)) - float(status_total(e, "renxing")) - def_of(e))

func preview_normal_attack(a: Dictionary, e: Dictionary) -> int:
	if phase != "player" or not a["alive"] or not e["alive"]:
		return 0
	if int(a["acts"]) <= 0 or has_status(a, "jiaoxie") or has_status(a, "xuan"):
		return 0
	return _preview_hit(a, e)

## 反震/反击预估（拖拽普攻吸附态用，2026-10-28 用户裁定）：目标雷反＝2×层间接；
## 反击＝其普攻攻防差（一次）。仅预估，实际以结算为准（多段/格挡会变）。
func preview_reflect(a: Dictionary, e: Dictionary) -> int:
	if not e.get("alive", false) or not a.get("alive", false):
		return 0
	var n := 0
	var lei := status_total(e, "leifan")
	if lei > 0:
		n += LEIFAN_PER_STACK * lei
	if status_total(e, "fanji") > 0:
		n += maxi(1, atk_of(e) - def_of(a))
	return n

## 追击连带预估（拖拽连线用）：镜像真实触发门（不耗攻次；缴械/眩晕不放行；同链每人至多一次）
func preview_pursuits(a: Dictionary, e: Dictionary) -> Array:
	var out: Array = []
	if phase != "player" or not a["alive"] or not e["alive"]:
		return out
	for t in allies:
		if t["alive"] and t["uid"] != a["uid"] and t.get("passive", {}).get("id") == "zhuiji" \
				and not has_status(t, "jiaoxie") and not has_status(t, "xuan"):
			out.push_back({"uid": int(t["uid"]), "name": String(t["name"]),
				"dmg": _preview_hit(t, e)})
	return out

func play_card(card_uid: int, target: Dictionary = {}) -> void:
	var card := {}
	for c in hand:
		if c["uid"] == card_uid:
			card = c
			break
	if card.is_empty():
		return
	var owner := _owner_of(card)
	if owner.is_empty() or phase != "player":
		return
	if energy < card_cost(card):
		event.emit("能量不足")
		return
	if has_status(owner, "xuan"):
		event.emit("「%s」眩晕，无法施放功法" % owner["name"])
		return
	var tgt_kind := String(card["spell"]["target"])
	if tgt_kind == "enemy" and (target.is_empty() or not target.get("alive", false)):
		return
	if tgt_kind == "ally":
		if target.is_empty() or not target.get("alive", false):
			return
		# 「其他器灵」限定（引丝诀基础/升一）
		for op in card["spell"]["ops"]:
			if bool(op.get("others", false)) and int(target.get("uid", -1)) == int(owner["uid"]):
				event.emit("须指定其他器灵")
				changed.emit()   # 防御：异常路径拒放也要刷手牌（飞行卡别悬空）
				return
	energy -= card_cost(card)
	_turn_cards_played += 1
	_round_spell_used = true   # 两仪配件3：首张提交即消耗「回合首功法 −1」充能
	_current_sid = String(card["sid"])
	event.emit("施放「%s」" % card["spell"]["name"])
	_playing_uid = int(card["uid"])
	for op in card["spell"]["ops"]:
		_run_op(op, owner, target)
	_playing_uid = -1
	_current_sid = ""
	# 打出记账＋专属/特殊钩子
	_spell_played[owner["uid"]] = int(_spell_played.get(owner["uid"], 0)) + 1
	# 插件·幽冥二专属：每累计 3 张功法 → +1 能量＋自身抽牌
	if _has_fx(owner, "spell_cycle") and int(_spell_played[owner["uid"]]) % 3 == 0:
		gain_energy(1)
		event.emit("幽冥二：能量 +1，执行自身抽牌")
		self_draw(owner)
	# 插件·天丝二特殊：打出自身功法牌后自身减益持续时间 −1
	if _has_fx(owner, "spell_cleanse"):
		for s in owner["statuses"]:
			if int(s.get("rounds", -1)) > 0 and bool(DATA.STATUSES[s["sid"]].get("debuff", false)):
				s["rounds"] = int(s["rounds"]) - 1
	if int(card.get("reuse_left", 0)) > 0:
		card["reuse_left"] = int(card["reuse_left"]) - 1
		card["retain"] = true
		event.emit("「%s」复用回手（余 %d 次）" % [card["spell"]["name"], card["reuse_left"]])
	else:
		hand.erase(card)
		if bool(card.get("exhaust", false)):
			# 「消耗」关键词（StS2 制：打出进消耗堆，本场不回弃牌堆；未打出的回合末随手牌冲弃）
			exhaust_card(card)
			event.emit("「%s」已消耗" % String(card["spell"]["name"]))
		else:
			discard_pile.push_back(card)
	_drain_deferred()
	check_end()
	changed.emit()

func _run_op(op: Dictionary, src: Dictionary, target: Dictionary) -> void:
	match String(op["op"]):
		"dmg_flat":
			# 段数＝hits_base＋每 per_pow_hits 点威力 +1（灭魂斩·升二 2+威/5 段；每段独立结算）
			var hits := int(op.get("hits_base", 1)) if op.has("hits_base") \
				else maxi(1, int(op.get("hits", 1)))
			if op.has("per_pow_hits"):
				hits += int(float(pow_of(src)) / float(op["per_pow_hits"]))
			for h in hits:
				if not target.get("alive", false):
					break
				if not src.get("alive", false):
					break   # 攻方段间死亡→剩余段作废（2026-10-28 裁定，STS2 AttackCommand 同制）
				# per_pow＝每点威力乘数（灭魂斩族）；atk_step/pow_step＝每 N 点攻/威 +1（裂甲斩族÷）
				var amt := float(op["value"]) + float(op.get("per_pow", 0)) * float(pow_of(src))
				if op.has("atk_step"):
					amt += float(int(float(atk_of(src)) / float(op["atk_step"])))
				if op.has("pow_step"):
					amt += float(int(float(pow_of(src)) / float(op["pow_step"])))
				resolve_damage(src, target, amt, String(op.get("channel", "功法")))
		"dmg_bounce":
			# 弹射：首发（目标或随机）＋弹射段（随机敌），段数＝bounce+1＋每 per_pow_bounce 威力 +1
			var segs := int(op["bounce"]) + 1
			if op.has("per_pow_bounce"):
				segs += int(float(pow_of(src)) / float(op["per_pow_bounce"]))
			var hit_uids := {}
			for h in segs:
				if not src.get("alive", false):
					break   # 攻方段间死亡→剩余段作废（2026-10-28 裁定，STS2 AttackCommand 同制；目标死亡仍换目标继续）
				var t: Dictionary = {}
				if h == 0 and not bool(op.get("random", false)) and target.get("alive", false):
					t = target
				else:
					var pool := _alive_enemies()
					if pool.is_empty():
						break
					t = pool[rng.randi_range(0, pool.size() - 1)]
				if not t.get("alive", false):
					continue
				resolve_damage(src, t, float(op["value"]), String(op.get("channel", "功法")))
				if op.get("poison_per_hit", 0) > 0 and t["alive"]:
					apply_status(t, "zhongdu", int(op["poison_per_hit"]), 0, -1, true, src)
				hit_uids[int(t["uid"])] = true
			if op.get("draw_per_new", 0) > 0:
				var n := int(op["draw_per_new"]) * hit_uids.size()
				if n > 0:
					event.emit("蛊箭·升二：命中 %d 名不同敌人，抽 %d 张" % [hit_uids.size(), n])
					draw_cards(n)
		"status":
			# to=target（金刚护壁·升一的抵抗）：作用于功法目标（我方）
			var dsts: Array = [target] if String(op.get("to", "enemy")) == "target" else [target]
			for t in dsts:
				if t.get("alive", false):
					apply_status(t, String(op["sid"]), int(op["stacks"]), 0,
						int(op.get("rounds", -1)), op.get("abnormal", false), src)
		"shield_ally":
			if target.get("alive", false):
				var amt2 := int(op["value"]) + int(op.get("per_pow", 0)) * pow_of(src)
				apply_status(target, "hudun", 1, amt2)
				if int(op.get("taunt_rounds", 0)) > 0:
					apply_status(target, "chaofeng", 1, 0, int(op["taunt_rounds"]))
		"block_ally":
			if target.get("alive", false):
				var stacks := 1
				if bool(op.get("per_pow15", false)):
					stacks += int(float(pow_of(src)) / 15.0)
				apply_status(target, "gebi", stacks)
		"cleanse":
			# 铁壁诀·升一：去除目标随机一个减益状态（整实例）
			var cand: Array = []
			for s in target.get("statuses", []):
				if bool(DATA.STATUSES[s["sid"]].get("debuff", false)):
					cand.push_back(s)
			if not cand.is_empty():
				var pick: Dictionary = cand[rng.randi_range(0, cand.size() - 1)]
				target["statuses"].erase(pick)
				event.emit("铁壁诀·升一：去除「%s」的「%s」" % [target["name"], DATA.STATUSES[pick["sid"]]["name"]])
		"aps_mod":
			if target.get("alive", false):
				target["acts"] = int(target["acts"]) + int(op.get("amount", 1))
				event.emit("引丝诀：「%s」攻击次数 +1" % target["name"])
		"aps_reset":
			if target.get("alive", false):
				target["acts"] = int(target["acts_max"])
				event.emit("引丝诀·升一：「%s」攻击次数重置为 %d" % [target["name"], int(target["acts_max"])])
		"mark":
			if target.get("alive", false):
				apply_status(target, "biaoji", 1, 0, -1, false, src)
				if int(op.get("death_energy", 0)) > 0:
					_mark_watch[int(target["uid"])] = int(op["death_energy"])
				if bool(op.get("double_vuln", false)):
					for s in target["statuses"]:
						if s["sid"] in ["poxian", "fengxue"] and int(s.get("rounds", -1)) > 0:
							s["rounds"] = int(s["rounds"]) * 2
							event.emit("索敌令·升一：「%s」破绽/封穴时长翻倍" % target["name"])
				if int(op.get("weaken_marked", 0)) > 0:
					for e2 in _alive_enemies():
						if status_total(e2, "biaoji") > 0:
							apply_status(e2, "xuruo", int(op["weaken_marked"]))
				if int(op.get("shayi_per_marked", 0)) > 0 and src.get("passive", {}).get("id") == "sha_yi":
					var marked_n := 0
					for e2 in _alive_enemies():
						if status_total(e2, "biaoji") > 0:
							marked_n += 1
					if marked_n > 0:
						_gain_shayi(src, marked_n)
		"gain_shayi":
			if src.get("passive", {}).get("id") == "sha_yi":
				_gain_shayi(src, int(op.get("stacks", 1)))
		"shayi_cashout":
			# 灭魂斩·升一（2026-10-28 用户裁定重做）：伤害结算后清空全部杀意
			# （含本刀被动 +1），每 per 层生成一张 0 费消耗版基础功法入手中；手满则溢出不生成。
			var sy: int = status_total(src, "shayi")
			var copies: int = int(float(sy) / float(op.get("per", 5))) if sy > 0 else 0
			if sy > 0:
				_consume_stacks(src, "shayi", sy)
			for i in copies:
				if hand.size() >= HAND_CAP:
					event.emit("手牌已满，多余副本未生成")
					break
				var spawn := _make_card_instance({"wid": String(src["id"]),
					"sid": String(op.get("spawn", "miehun")), "dir": 0})
				spawn["spell"]["cost"] = 0
				spawn["exhaust"] = true
				hand.push_back(spawn)
			if sy > 0:
				event.emit("灭魂斩·升一：清空 %d 层杀意，生成 %d 张 0 费「消耗」版基础灭魂斩" % [sy, copies])
		"bug_recall":
			var bugs := int(src.get("bugs", 0))
			if bugs <= 0:
				event.emit("「%s」身上没有蛊虫" % src["name"])
				return
			src["bugs"] = 0
			for i in bugs:
				var pool2 := _alive_enemies()
				if pool2.is_empty():
					break
				var t2: Dictionary = pool2[rng.randi_range(0, pool2.size() - 1)]
				resolve_damage(src, t2, float(op.get("dmg_per_bug", 1)), "功法", {"indirect": true})
			event.emit("召蛊术：召回 %d 只蛊虫" % bugs)
			if bool(op.get("reassign", false)):
				for i in bugs:
					var pool3 := _alive_enemies()
					if pool3.is_empty():
						break
					var e3: Dictionary = pool3[rng.randi_range(0, pool3.size() - 1)]
					e3["bugs_on"] = int(e3["bugs_on"]) + 1
				event.emit("召蛊术·升一：蛊虫再次藏身")
			if bool(op.get("shield_own_bugs", false)):
				for a in allies:
					if a["alive"]:
						apply_status(a, "hudun", 1, bugs)
				event.emit("召蛊术·升二：全体器灵获得 %d 点护盾" % bugs)
		"stun_if_marked":
			if not target.is_empty() and target.get("alive", false) and status_total(target, "biaoji") > 0:
				apply_status(target, "xuan", 1, 0, -1, false, src)
				event.emit("乱心蛊·升二：「%s」被标记，眩晕" % target["name"])
		"attack_after":
			# 功法内普攻段（刀剑合击）：视为普通攻击——走普攻通道，
			# 命中后钩子（转形态/铁壁/插件/追击）由 resolve_damage 普攻段统一触发
			if target.get("alive", false) and src.get("alive", false):
				resolve_damage(src, target, float(atk_of(src)) * float(op.get("atk_mult", 1.0)), "普攻")
		"pojia_aoe":
			# 裂甲斩：目标＋动态相邻 1+威/per_pow 层破甲
			var pj7 := int(op.get("stacks", 1)) + int(float(pow_of(src)) / float(op.get("per_pow", 5)))
			for te7 in _target_and_adjacent_enemies(target):
				if te7.get("alive", false):
					apply_status(te7, "pojia", pj7, 0, -1, false, src)
			event.emit("裂甲斩：「%s」及相邻受到 %d 层破甲" % [target["name"], pj7])
		"pojia_all":
			# 裂甲斩·升二：全体 威/per_pow 层（无基础层）；护甲层数高于将受破甲层数者翻倍
			var pj8 := int(float(pow_of(src)) / float(op.get("per_pow", 5)))
			for te8 in _alive_enemies():
				if not te8["alive"]:
					continue
				var k8 := pj8
				if pj8 > 0 and status_total(te8, "hujia") > pj8:
					k8 = pj8 * 2
					event.emit("裂甲斩·升二：「%s」护甲高于破甲，层数翻倍" % te8["name"])
				if k8 > 0:
					apply_status(te8, "pojia", k8, 0, -1, false, src)
		"self_status_scale":
			# 裂甲斩·升二：自身获层＝stacks＋每 atk_step/pow_step 点属性 +1
			var st9 := int(op.get("stacks", 1))
			if op.has("atk_step"):
				st9 += int(float(atk_of(src)) / float(op["atk_step"]))
			if op.has("pow_step"):
				st9 += int(float(pow_of(src)) / float(op["pow_step"]))
			if st9 > 0:
				apply_status(src, String(op.get("sid", "qiangdu")), st9)
		"spawn_spell":
			# 裂甲斩·升一/刀剑合击·升一：获得一张基础版另一功法入手中（手满溢出不生成）
			if hand.size() >= HAND_CAP:
				event.emit("手牌已满，副本未生成")
				return
			var spawn9 := _make_card_instance({"wid": String(src["id"]),
				"sid": String(op.get("sid", "")), "dir": 0})
			hand.push_back(spawn9)
			event.emit("获得一张「%s」" % spawn9["spell"]["name"])
		"draw":
			draw_cards(int(op.get("count", 1)))
		"reroll_intent":
			if not target.is_empty() and target.get("alive", false):
				reroll_intent(target)

func gain_energy(n: int) -> void:
	if energy_cap > 0:
		energy = mini(energy_cap, energy + n)
#endregion

#region 蛊虫循环（v0.7 §6：回合开始藏身→施毒增幅→回合结束先回归再毒）
## 某器灵的全部蛊虫藏身随机敌人（可叠同目标）
func _hide_bugs(a: Dictionary) -> void:
	var pool := _alive_enemies()
	if pool.is_empty():
		return
	while int(a["bugs"]) > 0:
		var e: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		e["bugs_on"] = int(e["bugs_on"]) + 1
		a["bugs"] = int(a["bugs"]) - 1

## 全体我方蛊虫藏身（回合开始）
func _hide_all_bugs() -> void:
	for a in allies:
		if a["alive"] and int(a["bugs"]) > 0:
			_hide_bugs(a)

## 全部蛊虫回归（回合结束，先于毒结算）
func _return_all_bugs() -> void:
	for e in enemies:
		if int(e.get("bugs_on", 0)) > 0:
			for a in allies:
				if a["id"] == "qinggu" and a["alive"]:
					a["bugs"] = int(a["bugs"]) + int(e["bugs_on"])
					break
			e["bugs_on"] = 0

## 毒结算：受到＝层数的间接伤害，层 −1（尖塔制）；敌方结算＝毒发（青蛊铃被动计数）
func _poison_tick(u: Dictionary) -> void:
	var stacks := status_total(u, "zhongdu")
	if stacks <= 0:
		return
	u["hp"] = maxi(0, int(u["hp"]) - stacks)
	event.emit("「%s」中毒发作 −%d" % [u["name"], stacks])
	hit_landed.emit(u, stacks, "间接")
	if u["side"] == "enemy":
		for a in allies:
			if a["alive"] and a.get("passive", {}).get("id") == "yang_gu":
				a["bugs"] = int(a["bugs"]) + 1
	_consume_stacks(u, "zhongdu", 1)
	if int(u["hp"]) <= 0:
		_on_death({}, u)
#endregion

#region 回合流
func _round_start() -> void:
	_acted = {}
	_kill_act_used = {}
	_atk_energy_used = {}
	_jg_first_used = {}
	_fanji_used = {}
	_mark_watch = {}
	_turn_cards_played = 0
	_cost_cut = {}
	_round_spell_used = false
	for a in allies:
		if a["alive"]:
			a["acts"] = a["acts_max"]
	energy = energy_cap
	# ① 蛊虫藏身（先于施毒类回合开始效果——增幅吃得到）
	_hide_all_bugs()
	# ② 回合开始效果
	for a in allies:
		if not a["alive"]:
			continue
		# 插件·幽冥三特殊：每回合开始 3 层杀意
		if _has_fx(a, "round_start_shayi") and a.get("passive", {}).get("id") == "sha_yi":
			_gain_shayi(a, 3)
		# 青蛊铃升1：回合开始敌方毒发一次
		if a.get("passive", {}).get("id") == "yang_gu" and int(a.get("pdir", 0)) == 1:
			for e in enemies:
				if e["alive"]:
					_poison_tick(e)
		# 插件·青蛊二特殊：回合开始随机两名敌人 2 层毒
		if _has_fx(a, "round_start_poison"):
			var pool := _alive_enemies().duplicate()
			for i in int(_fx_val(a, "round_start_poison", "targets", 2)):
				if pool.is_empty():
					break
				var e: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
				apply_status(e, "zhongdu", int(_fx_val(a, "round_start_poison", "stacks", 2)), 0, -1, true, a)
		# 金刚盾升2：回合开始将自身护盾平均分配给相邻器灵
		if a.get("passive", {}).get("id") == "tie_bi" and int(a.get("pdir", 0)) == 2:
			_distribute_shield(a)
	# ③ 抽牌（禁锢拦回合抽）
	var jinggu := false
	for a in allies:
		if a["alive"] and has_status(a, "jingu"):
			jinggu = true
	if jinggu:
		event.emit("禁锢：本回合无法抽牌")
	else:
		draw_cards(draw_base)
	# ④ 敌方回合开始被动（战意等，死亡螺旋律＝回合时钟制）——先于掷意图，成长即时入意图
	_enemy_round_start_passives()
	roll_intents()
	phase = "player"

func _fx_val(u: Dictionary, kind: String, key: String, fallback: Variant) -> Variant:
	for fx in _fx_of(u):
		if String(fx.get("kind", "")) == kind:
			return fx.get(key, fallback)
	return fallback

## 金刚盾升2：护盾分配（两邻＝各半自身清零；一邻＝各半；无邻＝自身减半）
func _distribute_shield(a: Dictionary) -> void:
	var shield := 0
	for s in a["statuses"]:
		if s["sid"] == "hudun":
			shield += int(s["value"]) * int(s["stacks"])
	if shield <= 0:
		return
	var adj := _adjacent(a)
	for i in range(a["statuses"].size() - 1, -1, -1):
		if a["statuses"][i]["sid"] == "hudun":
			a["statuses"].remove_at(i)
	if adj.is_empty():
		apply_status(a, "hudun", 1, int(shield / 2.0))
		event.emit("铁壁·升2：无相邻，「%s」护盾减半留存" % a["name"])
		return
	var per := int(shield / 2.0)
	for t in adj:
		apply_status(t, "hudun", 1, per)
	if adj.size() == 1:
		apply_status(a, "hudun", 1, int(shield / 2.0))
	event.emit("铁壁·升2：「%s」将 %d 点护盾分给相邻器灵" % [a["name"], shield])

func end_turn() -> void:
	if phase != "player":
		return
	# 冲弃制：整手冲弃（复用回流豁免）
	var kept: Array = []
	var flushed: Array = []
	for card in hand:
		if bool(card.get("retain", false)):
			card["retain"] = false
			kept.push_back(card)
		else:
			discard_pile.push_back(card)
			flushed.push_back(card)
	hand = kept
	if not flushed.is_empty():
		event.emit("回合结束：手牌冲弃")
	# 插件7（通用）：一次弃牌事件含自身牌 → 抽 1（回合末冲弃同样触发——弃完再抽）
	for a in allies:
		if not a["alive"] or not a["equips"].has("p7"):
			continue
		var own := false
		for card in flushed:
			if String(card["wid"]) == String(a["id"]):
				own = true
				break
		if own:
			event.emit("插件7：「%s」的牌被弃置，抽一张牌" % a["name"])
			draw_cards(1)
	phase = "enemy"
	changed.emit()

func apply_enemy_action(i: int) -> void:
	if phase != "enemy" or i >= enemies.size():
		return
	var e: Dictionary = enemies[i]
	if not e["alive"]:
		return
	# 敌方护盾持续制：撑过我方回合、本次行动开始才清（我方护盾仍回合末清）
	_consume_stacks(e, "hudun", 999)
	if _spawned_this_turn.has(int(e["uid"])):
		return   # 召唤物落地回合不行动
	var intent: Dictionary = _enemy_intent[i] if i < _enemy_intent.size() else {}
	if intent.is_empty():
		return
	var action: Dictionary = intent["action"]
	var hist: Array = _enemy_hist.get(e["uid"], [])
	hist.push_back(action["id"])
	if hist.size() > 2:
		hist = hist.slice(hist.size() - 2)
	_enemy_hist[e["uid"]] = hist
	if action.has("cd"):
		var cds: Dictionary = _cd_left.get(e["uid"], {})
		cds[action["id"]] = int(action["cd"])
		_cd_left[e["uid"]] = cds
	if has_status(e, "xuan"):
		event.emit("「%s」眩晕，无法行动" % e["name"])
		_consume_stacks(e, "xuan", 999)   # 敌方眩晕＝跳过本次行动即消耗（不待回合末）
		return
	event.emit("「%s」使用「%s」" % [e["name"], action["name"]])
	if String(action["kind"]) == "attack":
		var target := _intent_target(e, i)
		if target.is_empty():
			return
		# 行动池功法化：攻击伤＝（攻击×倍率＋威力缩放）过我方防御；功法伤＝value＋威力缩放（无视防御）
		var hits5 := int(action.get("hits", 1))
		if action.has("hits_base"):
			hits5 = int(action["hits_base"])
		if action.has("hits_pow_step"):
			hits5 += int(float(pow_of(e)) / float(action["hits_pow_step"]))
		if String(action.get("channel", "普攻")) == "功法":
			var base5 := float(action.get("value", 0))
			if action.has("per_pow"):
				base5 += float(action["per_pow"]) * float(pow_of(e))
			if action.has("pow_step"):
				base5 += float(int(float(pow_of(e)) / float(action["pow_step"])))
			for h5 in hits5:
				if not target.get("alive", false) or not e["alive"]:
					break
				if resolve_damage(e, target, base5, "功法") > 0:
					_enemy_on_hit_passive(e, target)
		else:
			var m5 := float(atk_of(e)) * float(action.get("mult", 1.0))
			if action.has("per_pow"):
				m5 += float(action["per_pow"]) * float(pow_of(e))
			if action.has("pow_step"):
				m5 += float(int(float(pow_of(e)) / float(action["pow_step"])))
			for h5 in hits5:
				if not target.get("alive", false) or not e["alive"]:
					break
				if resolve_damage(e, target, m5, "普攻") > 0:
					_enemy_on_hit_passive(e, target)
		# 猛击·自眩（打完跳过下回合行动）
		if bool(action.get("self_stun", false)) and e["alive"]:
			apply_status(e, "xuan", 1)
			event.emit("「%s」力竭眩晕" % e["name"])
		for side in action.get("side", []):
			_run_side(side, e, target)
	else:
		for side in action.get("side", []):
			_run_side(side, e, {})

## 命中型敌方被动（穿甲：造成伤害后目标挂层——逐段独立）
func _enemy_on_hit_passive(e: Dictionary, target: Dictionary) -> void:
	if String(e.get("passive", {}).get("hook", "")) == "on_hit" and target.get("alive", false):
		apply_status(target, String(e["passive"].get("sid", "pojia")),
			int(e["passive"].get("stacks", 1)), 0, -1,
			bool(e["passive"].get("abnormal", false)), e)
	_drain_deferred()
	check_end()
	changed.emit()   # 每敌一刷（2026-10-28 时序裁定：飘字在命中帧弹、血条也必须同帧降——漏发＝冻到 finish_round 才补）

func _run_side(side: Dictionary, e: Dictionary, target: Dictionary) -> void:
	match String(side["op"]):
		"status":
			if target.is_empty() or not target.get("alive", false):
				return
			apply_status(target, String(side["sid"]), int(side["stacks"]), 0, -1,
				side.get("abnormal", false), e)
		"self_buff":
			apply_status(e, String(side["sid"]), int(side.get("stacks", 1)), int(side.get("value", 0)),
				int(side.get("rounds", -1)), false, e)
		"ally_buff":
			# 授刃/授锋（刀奴/剑仆）：随机一名其他存活友军挂层
			var pool4: Array = []
			for o in enemies:
				if o["alive"] and o["uid"] != e["uid"]:
					pool4.push_back(o)
			if not pool4.is_empty():
				var lucky4: Dictionary = pool4[rng.randi_range(0, pool4.size() - 1)]
				apply_status(lucky4, String(side["sid"]), int(side.get("stacks", 1)),
					int(side.get("value", 0)), int(side.get("rounds", -1)), false, e)
				event.emit("「%s」获得「%s」" % [lucky4["name"],
					String(DATA.STATUSES.get(String(side["sid"]), {}).get("name", side["sid"]))])
		"mark_ally":
			# 瞄准（猎手）：标记随机我方器灵＋1 层破绽（敌方攻击将集火被标记者，无视嘲讽）
			var pool6: Array = []
			for a6 in allies:
				if a6["alive"]:
					pool6.push_back(a6)
			if not pool6.is_empty():
				var mk: Dictionary = pool6[rng.randi_range(0, pool6.size() - 1)]
				apply_status(mk, "biaoji", 1, 0, -1, false, e)
				if int(side.get("poxian", 0)) > 0:
					apply_status(mk, "poxian", int(side["poxian"]), 0, int(side.get("rounds", 2)), true, e)
				event.emit("瞄准：「%s」被标记" % mk["name"])
		"fengxue_random":
			# 封穴咒（巫祝）：随机我方器灵封穴（功法易伤）
			var pool7: Array = []
			for a7 in allies:
				if a7["alive"]:
					pool7.push_back(a7)
			if not pool7.is_empty():
				var fx: Dictionary = pool7[rng.randi_range(0, pool7.size() - 1)]
				apply_status(fx, "fengxue", int(side.get("stacks", 2)), 0, int(side.get("rounds", 2)), true, e)
				event.emit("封穴咒：「%s」被封穴" % fx["name"])
		"adj_armor":
			# 铁壁阵（力士）：自身与动态相邻各获护甲
			for t7 in [e] + _adjacent_in(enemies, e):
				if t7["alive"]:
					apply_status(t7, "hujia", int(side.get("stacks", 2)))
			event.emit("铁壁阵：「%s」及相邻获得护甲" % e["name"])
		"summon":
			# 御召（两仪剑主）：召唤刀奴与剑仆（已存活者不重复）
			for eid7 in side.get("summons", []):
				summon_enemy(String(eid7))

func _intent_target(e: Dictionary, i: int) -> Dictionary:
	var intent: Dictionary = _enemy_intent[i] if i < _enemy_intent.size() else {}
	var target := {}
	if not intent.is_empty() and allies.any(func(a): return a["uid"] == intent.get("target_uid")):
		for a in allies:
			if a["uid"] == intent["target_uid"] and a["alive"]:
				target = a
	if target.is_empty() or not target["alive"]:
		target = _pick_target()
	return target

func _pick_target() -> Dictionary:
	# 集火制（2026-10-28 用户裁定）：被标记者优先且无视嘲讽 → 嘲讽 → 随机
	var marked: Array = []
	var taunts: Array = []
	var pool: Array = []
	for a in allies:
		if not a["alive"]:
			continue
		pool.push_back(a)
		if has_status(a, "biaoji"):
			marked.push_back(a)
		elif has_status(a, "chaofeng"):
			taunts.push_back(a)
	var from: Array = marked if not marked.is_empty() else (taunts if not taunts.is_empty() else pool)
	if from.is_empty():
		return {}
	return from[rng.randi_range(0, from.size() - 1)]

func finish_round() -> void:
	if phase != "enemy":
		return
	# ① 蛊虫回归（先虫后毒）
	_return_all_bugs()
	# ② 毒结算（敌我通用；敌方结算＝毒发计数）
	for u in allies + enemies:
		if u["alive"]:
			_poison_tick(u)
	# ③ 状态时限/回合末结算
	_tick_statuses()
	_drain_deferred()
	if not check_end():
		round_no += 1
		_round_start()
	changed.emit()

func _tick_statuses() -> void:
	for u in allies + enemies:
		if not u["alive"]:
			continue
		for i in range(u["statuses"].size() - 1, -1, -1):
			var s: Dictionary = u["statuses"][i]
			var sid: String = s["sid"]
			# 回合末 −1 层：嘲讽（时长语义）
			# 格挡/抵抗 2026-10-28 用户裁定改纯按次消耗：不随时间衰减不清空（StS Buffer/Artifact 制）
			if sid == "chaofeng":
				s["stacks"] = int(s["stacks"]) - 1
			elif sid == "xuan" and u.get("side", "") == "ally":
				s["stacks"] = 0   # 敌方眩晕在跳过行动时消耗（猛击自眩要跨回合）
			elif sid == "shayi":
				# 杀意回合末失去所有层（插件·幽冥三专属：保留至多 5 层）
				if _has_fx(u, "shayi_keep"):
					s["stacks"] = mini(int(s["stacks"]), 5)
				else:
					s["stacks"] = 0
			elif sid == "hudun":
				# 我方护盾回合末清空（金刚盾升2例外）；敌方护盾不清——撑过我方回合，
				# 于该敌下次行动开始才清（敌方护盾持续制，蓝本格挡同制）
				if u.get("side", "") == "ally" \
						and not (u.get("passive", {}).get("id") == "tie_bi" and int(u.get("pdir", 0)) == 2):
					s["stacks"] = 0
			elif int(s.get("rounds", -1)) > 0:
				s["rounds"] = int(s["rounds"]) - 1
			if int(s["stacks"]) <= 0 or (int(s.get("rounds", -1)) == 0 and sid != "hudun"):
				u["statuses"].remove_at(i)
	# 插件·青蛊二专属：回合结束自身每有 3 只蛊虫 +1 只
	for a in allies:
		if a["alive"] and _has_fx(a, "bug_breed"):
			var gain := int(a["bugs"]) / int(_fx_val(a, "bug_breed", "per", 3))
			if gain > 0:
				a["bugs"] = int(a["bugs"]) + gain
				event.emit("青蛊二：繁育 %d 只蛊虫" % gain)
	# 冷却递减
	for k in _cd_left:
		var cds: Dictionary = _cd_left[k]
		for a in cds:
			cds[a] = maxi(0, int(cds[a]) - 1)

func check_end() -> bool:
	var e_alive := false
	for e in enemies:
		if e["alive"]:
			e_alive = true
	var a_alive := false
	for a in allies:
		if a["alive"]:
			a_alive = true
	if not e_alive:
		phase = "over"
		result = "win"
		_deferred.clear()
		ended.emit("win")
		return true
	if not a_alive:
		phase = "over"
		result = "lose"
		_deferred.clear()
		ended.emit("lose")
		return true
	return false
#endregion

#region 意图（提前一拍亮出；数值＝实际结算值）
func roll_intents() -> void:
	_enemy_intent = []
	for e in enemies:
		if not e["alive"]:
			_enemy_intent.push_back({})
			continue
		var cds: Dictionary = _cd_left.get(e["uid"], {})
		var hist: Array = _enemy_hist.get(e["uid"], [])
		var pool: Array = []
		for a in e["actions"]:
			if int(cds.get(a["id"], 0)) > 0:
				continue
			if String(a.get("form", "")) != "" and String(a.get("form", "")) != _enemy_form(e):
				continue   # 两仪剑主形态池过滤（敌方设计 v0.1）
			if hist.size() >= 2 and hist[0] == a["id"] and hist[1] == a["id"]:
				continue
			pool.push_back(a)
		if pool.is_empty():
			pool = e["actions"]
		var action: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var target_uid := -1
		if String(action["kind"]) == "attack":
			var t := _pick_target()
			if not t.is_empty():
				target_uid = int(t["uid"])
		_enemy_intent.push_back({"action": action, "target_uid": target_uid})

func intent_parts(e: Dictionary) -> Array:
	# 眩晕＝意图失效（蓝本 Stun 制）：意图位亮「眩」，该回合行动作废、跳过即消耗
	if has_status(e, "xuan"):
		return [{"g": "眩", "n": "失效"}]
	var i := enemies.find(e)
	if i < 0 or i >= _enemy_intent.size() or _enemy_intent[i].is_empty():
		return []
	var action: Dictionary = _enemy_intent[i]["action"]
	var parts: Array = []
	if String(action["kind"]) == "attack":
		var target := {}
		for a in allies:
			if a["uid"] == _enemy_intent[i]["target_uid"] and a["alive"]:
				target = a
		if target.is_empty():
			target = _pick_target_preview()
		var n_txt := ""
		var hits_i := int(action.get("hits", 1))
		if action.has("hits_base"):
			hits_i = int(action["hits_base"])
		if action.has("hits_pow_step"):
			hits_i += int(float(pow_of(e)) / float(action["hits_pow_step"]))
		if String(action.get("channel", "普攻")) == "功法":
			# 功法伤意图（无视防御）：value＋威力缩放；封穴层计入；多段标 ×n
			var amt3 := float(action.get("value", 0))
			if action.has("per_pow"):
				amt3 += float(action["per_pow"]) * float(pow_of(e))
			if action.has("pow_step"):
				amt3 += float(int(float(pow_of(e)) / float(action["pow_step"])))
			amt3 += float(status_total(e, "fengmang"))
			if not target.is_empty():
				amt3 += VULN_PER_STACK * status_total(target, "fengxue")
				amt3 -= float(status_total(target, "renxing"))
			n_txt = str(maxi(1, int(round(amt3))))
			if hits_i > 1:
				n_txt = "%s×%d" % [n_txt, hits_i]
			parts.push_back({"g": "法", "n": n_txt})
		else:
			# 攻击伤意图（过我方防御）：攻击×倍率＋威力缩放；破绽层计入
			var amt := float(atk_of(e)) * float(action.get("mult", 1.0))
			if action.has("per_pow"):
				amt += float(action["per_pow"]) * float(pow_of(e))
			if action.has("pow_step"):
				amt += float(int(float(pow_of(e)) / float(action["pow_step"])))
			amt += float(status_total(e, "fengmang"))
			if not target.is_empty():
				amt += VULN_PER_STACK * status_total(target, "poxian")
				if status_total(target, "cuiruo") > 0:
					amt *= 1.5
				amt = maxf(1.0, amt - float(status_total(target, "renxing")) - float(def_of(target)))
			n_txt = str(int(round(amt)))
			if hits_i > 1:
				n_txt = "%s×%d" % [n_txt, hits_i]
			parts.push_back({"g": "攻", "n": n_txt})
		if not target.is_empty():
			parts.push_back({"g": "→%d号" % (allies.find(target) + 1), "is_pos": true})
		for side in action.get("side", []):
			if side.get("op") == "status":
				parts.push_back({"g": DATA.STATUSES[side["sid"]]["glyph"]})
	else:
		for side in action.get("side", []):
			if side.get("op") == "self_buff":
				parts.push_back({"g": DATA.STATUSES[String(side["sid"])]["glyph"],
					"n": "+%d" % int(side.get("stacks", side.get("value", 0)))})
			elif side.get("op") == "ally_buff":
				parts.push_back({"g": DATA.STATUSES[String(side["sid"])]["glyph"],
					"n": "+%d盟" % int(side.get("stacks", 1))})
			elif side.get("op") == "mark_ally":
				parts.push_back({"g": "记", "n": "＋破%d" % int(side.get("poxian", 1))})
			elif side.get("op") == "fengxue_random":
				parts.push_back({"g": "穴", "n": "+%d" % int(side.get("stacks", 2))})
			elif side.get("op") == "adj_armor":
				parts.push_back({"g": "甲", "n": "+%d阵" % int(side.get("stacks", 2))})
			elif side.get("op") == "summon":
				parts.push_back({"g": "召"})
	return parts

func intent_target(e: Dictionary) -> Dictionary:
	var i := enemies.find(e)
	if i < 0 or i >= _enemy_intent.size() or _enemy_intent[i].is_empty():
		return {}
	if String(_enemy_intent[i]["action"].get("kind", "")) != "attack":
		return {}
	for a in allies:
		if a["uid"] == _enemy_intent[i]["target_uid"] and a["alive"]:
			return a
	return _pick_target_preview()

func _pick_target_preview() -> Dictionary:
	for a in allies:   # 预览同集火口径：被标记者优先
		if a["alive"] and has_status(a, "biaoji"):
			return a
	var pool: Array = []
	for a in allies:
		if a["alive"]:
			pool.push_back(a)
	if pool.is_empty():
		return {}
	return pool[0]

func intent_tip(e: Dictionary) -> String:
	var i := enemies.find(e)
	if i < 0 or i >= _enemy_intent.size() or _enemy_intent[i].is_empty():
		return ""
	var tip := String(_enemy_intent[i]["action"].get("tip", ""))
	var target := intent_target(e)
	if not target.is_empty():
		tip += "\n目标：%d号位 · %s（伤害已计入其防御与破绽）" % [allies.find(target) + 1, target["name"]]
	return tip

func intent_target_uid(e: Dictionary) -> int:
	var i := enemies.find(e)
	if i < 0 or i >= _enemy_intent.size() or _enemy_intent[i].is_empty():
		return -1
	return int(_enemy_intent[i].get("target_uid", -1))

func reroll_intent(e: Dictionary) -> void:
	var i := enemies.find(e)
	if i < 0 or not e["alive"] or i >= _enemy_intent.size() or _enemy_intent[i].is_empty():
		return
	var cur_id := String(_enemy_intent[i]["action"]["id"])
	var cds: Dictionary = _cd_left.get(e["uid"], {})
	var pool: Array = []
	for a in e["actions"]:
		if int(cds.get(a["id"], 0)) > 0 or String(a["id"]) == cur_id:
			continue
		pool.push_back(a)
	if pool.is_empty():
		return
	var action: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	var target_uid := -1
	if String(action["kind"]) == "attack":
		var t := _pick_target()
		if not t.is_empty():
			target_uid = int(t["uid"])
	_enemy_intent[i] = {"action": action, "target_uid": target_uid}
	event.emit("「%s」的意图被变更为「%s」" % [e["name"], action["name"]])
	changed.emit()
#endregion

#region 五区牌堆（冲弃＋洗牌＋唯一自动弃＋手满留堆顶）
func draw_cards(n: int) -> void:
	for _i in n:
		if hand.size() >= HAND_CAP:
			event.emit("手牌已满，停止抽牌")
			break
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				event.emit("抽牌堆与弃牌堆皆空，无牌可抽")
				break
			draw_pile = discard_pile
			discard_pile = []
			_shuffle(draw_pile)
			event.emit("弃牌堆洗回抽牌堆")
		var card: Dictionary = draw_pile.pop_front()
		if bool(card["spell"].get("unique", false)) and _hand_has_same_unique(card):
			discard_pile.push_back(card)
			event.emit("「%s」唯一：重复抽取自动弃置" % card["spell"]["name"])
		else:
			hand.push_back(card)

## 自身抽牌（v0.7 关键词）：抽其牌；抽牌堆没有→弃牌堆洗入再抽；还没有则不抽
func self_draw(a: Dictionary) -> void:
	if not a.get("alive", false) or hand.size() >= HAND_CAP:
		return
	for i in draw_pile.size():
		if String(draw_pile[i]["wid"]) == String(a["id"]):
			hand.push_back(draw_pile.pop_at(i))
			event.emit("自身抽牌：「%s」抽到一张功法" % a["name"])
			return
	var own_in_discard := false
	for c in discard_pile:
		if String(c["wid"]) == String(a["id"]):
			own_in_discard = true
			break
	if not own_in_discard:
		event.emit("自身抽牌：「%s」无牌可抽" % a["name"])
		return
	draw_pile = discard_pile
	discard_pile = []
	_shuffle(draw_pile)
	event.emit("自身抽牌：弃牌堆洗回抽牌堆")
	for i in draw_pile.size():
		if String(draw_pile[i]["wid"]) == String(a["id"]):
			hand.push_back(draw_pile.pop_at(i))
			event.emit("自身抽牌：「%s」抽到一张功法" % a["name"])
			return
	event.emit("自身抽牌：「%s」无牌可抽" % a["name"])

func _hand_has_same_unique(card: Dictionary) -> bool:
	for c in hand:
		if String(c["sid"]) == String(card["sid"]) and bool(c["spell"].get("unique", false)):
			return true
	return false

func exhaust_card(card: Dictionary) -> void:
	exhaust_pile.push_back(card)

func _alive_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if e["alive"]:
			out.push_back(e)
	return out
#endregion
