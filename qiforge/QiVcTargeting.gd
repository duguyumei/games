## VC 制索敌与伤害模拟库（2026-11-07 逆向重构轮）。
## 对应原版 Nosebleed.Pancake.GameLogic.Weapons（WeaponTargeting＋八索敌型＋CritChainState）——
## 结构/职责/方法名逐一对齐，证据住 references/吸血鬼爬行者_伤害管线逆向_v0.1.md。
## 单链制（原版 isRealAttack）：同一套 calculate 既跑预演（is_real=false，只读）也跑真打
## （is_real=true，经 hooks 回调落账）——预览与结算物理同源，永不漂移。
## 纯函数：不吃全局状态，rng 由调用方注入（确定性）；副作用全部走 ctx.hooks。
extends RefCounted

const DATA := preload("res://qiforge/QiVcData.gd")

# ── 穿透三型（原版 PierceType：OncePerEnemy/MultiHit/MultiHitSwitchTarget）──
const PIERCE_ONCE_PER_ENEMY := 0   # 一敌只吃一击
const PIERCE_MULTI_HIT := 1        # 同一敌可连吃多击
const PIERCE_MULTI_SWITCH := 2     # 连击但换目标

# ── 连暴链（原版 CritChainState：PriorCritCount＋malus 衰减＋爆炸触发配额）──
## malus 曲线为自拟（原版方法体未还原，结构对齐）：每层连暴 −5% 暴击率，下限 0；
## TryRegisterExplosionTrigger 限一次攻击内的爆炸触发次数。
static func make_crit_chain() -> Dictionary:
	return {"prior_crit_count": 0, "malus_enabled": true, "explosion_triggers": 0}

static func roll_crit(rng: RandomNumberGenerator, params: Dictionary,
		chain: Dictionary) -> bool:
	var threshold: float = float(params.get("crit_chance", 0.0))
	if bool(chain.get("malus_enabled", true)) and threshold > 0.0:
		threshold = maxf(0.0, threshold - 0.05 * float(chain.get("prior_crit_count", 0)))
	if threshold <= 0.0 or rng.randf() >= threshold:
		return false
	chain["prior_crit_count"] = int(chain.get("prior_crit_count", 0)) + 1
	return true

static func try_register_explosion_trigger(chain: Dictionary, max_triggers: int) -> bool:
	if int(chain.get("explosion_triggers", 0)) >= max_triggers:
		return false
	chain["explosion_triggers"] = int(chain.get("explosion_triggers", 0)) + 1
	return true

# ── 索敌型（对应原版八个 Targeting 子类；col＝前排内位置，0＝最右）──
## first_column/next_column 对应原版 GetFirstColumnIndex/NextColumn；
## wrap 对应 TryWrapColumn（到最左回绕）；"random" 型为列袋不重复。
static func first_column(targeting: String, max_col: int, rng: RandomNumberGenerator,
		bag: Array = []) -> int:
	match targeting:
		"right_left", "front_row", "whip":
			return 0
		"left_right":
			return max_col - 1
		"single":
			return 0
		"random":
			if bag.is_empty():
				return 0
			return int(bag[0])
	return 0

static func next_column(targeting: String, cur: int, max_col: int, bag: Array = []) -> int:
	match targeting:
		"left_right":
			return cur - 1
		"single":
			return cur   # 锁列：同列连打（多段单体卡的后续击落同一目标——2026-11-07 修二击丢失）
		"random":
			for c in bag:
				if int(c) != cur:
					return int(c)
			return -1
		_:
			return cur + 1   # right_left/front_row/whip：右→左推进

static func wrap_column(targeting: String, cur: int, max_col: int) -> int:
	## 对应 TryWrapColumn：越界回绕（右→左到头回最右；左→右到头回最左）。
	## "single" 锁列不越界（next_column 原地推进）；"infinite_corridor" 走默认右→左回绕。
	if targeting == "single":
		return clampi(cur, 0, maxi(0, max_col - 1))
	if cur < 0 or cur >= max_col:
		return 0 if targeting != "left_right" else max_col - 1
	return cur

static func make_column_bag(max_col: int, rng: RandomNumberGenerator) -> Array:
	## "random" 型列袋（不重复抽取；对应原版 InitColumnBag）
	var bag: Array = []
	for i in max_col:
		bag.push_back(i)
	for i in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = bag[i]
		bag[i] = bag[j]
		bag[j] = t
	return bag

# ── 伤害参数（对应原版 DamageParams——由 QiVcEffects.generate_damage_params 生成）──
## 字段：damage_per_hit/hits/targeting/pierce/pierce_type/crit_chance/crit_mult/
##       might_pct/knockback/freeze/bouncy{base,decay,max}/crit_explosion{...}/pierce_distance_scaling

# ── 模拟账本（对应原版 EnemyStatData＋InitialiseLists）──
## 每行 {e(真敌引用), hp, armor, row}——结算全程只改账本；is_real 由 hooks 落真值。
static func make_ledger(enemies: Array) -> Array:
	var ledger: Array = []
	for e in enemies:
		if bool(e.get("alive", false)):
			ledger.push_back({"e": e, "hp": int(e.get("hp", 0)),
				"armor": int(e.get("armor", 0)), "row": int(e.get("row", 0)),
				"uid": int(e.get("uid", 0)), "hit": false})
	return ledger

static func front_row(ledger: Array) -> Array:
	## 前排账本行（右→左序；对应原版 FrontEnemies）
	var out: Array = []
	for l in ledger:
		if int(l["row"]) == 0:
			out.push_back(l)
	out.reverse()   # 数组序＝左→右，反转＝右→左（col 0 = 最右）
	return out

# ── 结算主链（对应 CalculateEnemiesToHit 全链；账单制——模拟即定账）──
## ctx＝{enemies, params, rng}——模拟全程不动真敌（账本推进），产出 events 事件流
## （hit 含 e/amount/is_crit；death 含 e——按结算序）。真打与预览同一套（原版 isRealAttack 制）；
## 真落账由调用方逐事件执行（2026-11-08 落账延迟制——击中帧结算跳数，对齐原版 WeaponCollision）。
static func calculate(ctx: Dictionary) -> Dictionary:
	var params: Dictionary = ctx["params"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var res := {"hits": [], "damage": {}, "kills": [],
		"bounce_hits": 0, "explosion_hits": 0, "events": [], "total_strikes": 0}
	var ledger := make_ledger(ctx["enemies"])
	if ledger.is_empty():
		return res
	var chain := make_crit_chain()
	var targeting := String(params.get("targeting", "front_row"))
	var bag := make_column_bag(front_row(ledger).size(), rng) if targeting == "random" else []
	var hits_left: int = int(params.get("hits", 1))
	var bouncy: Dictionary = params.get("bouncy", {})
	var bounce_budget: int = int(bouncy.get("max", 0)) if not bouncy.is_empty() else 0
	var col := first_column(targeting, front_row(ledger).size(), rng, bag.duplicate())
	var pierced := {}   # uid -> 已吃击数（PIERCE_ONCE_PER_ENEMY 用）
	while hits_left > 0:
		var row := front_row(ledger)
		if row.is_empty():
			## 前排清空：账本层顶替（对应 TryMoveAliveEnemiesInColumnForward）——
			## 后排整体 row−1 上移，is_real 的真顶替由 hooks.death → battle._promote_rows 负责
			var moved := false
			for l in ledger:
				if int(l["row"]) > 0:
					l["row"] = int(l["row"]) - 1
					moved = true
			if not moved:
				break   # 全灭：余段空放（对应 sequence_end）
			col = first_column(targeting, front_row(ledger).size(), rng, bag.duplicate())
			continue
		if col < 0 or col >= row.size():
			col = wrap_column(targeting, col, row.size())
			if col < 0:
				break
		var target: Dictionary = row[col]
		## 穿透三型（对应 PierceType/GetPierce/PierceAlwaysMultiHits）：
		## ONCE_PER_ENEMY＝每敌只吃一击（整排 AOE 语义）；MULTI_HIT＝同敌连吃（pierce>0 时
		## 同敌至多 pierce 击，0＝无限）；MULTI_SWITCH＝连吃但每击换目标。
		if int(params.get("pierce_type", PIERCE_MULTI_HIT)) == PIERCE_ONCE_PER_ENEMY \
				and int(pierced.get(int(target["uid"]), 0)) > 0:
			## 已吃过：跳到下一列；整排全吃过＝无可打之敌，余击作废（防 wrap 空转死循环）
			var any_fresh := false
			for l in row:
				if int(pierced.get(int(l["uid"]), 0)) == 0:
					any_fresh = true
					break
			if not any_fresh:
				break
			col = next_column(targeting, col, row.size(), bag)
			continue
		if int(params.get("pierce_type", PIERCE_MULTI_HIT)) == PIERCE_MULTI_HIT \
				and int(params.get("pierce", 0)) > 0 \
				and int(pierced.get(int(target["uid"]), 0)) >= int(params.get("pierce", 0)):
			var any_fresh2 := false
			for l2 in row:
				if int(pierced.get(int(l2["uid"]), 0)) < int(params.get("pierce", 0)):
					any_fresh2 = true
					break
			if not any_fresh2:
				break
			col = next_column(targeting, col, row.size(), bag)
			continue
		var is_crit := roll_crit(rng, params, chain)
		var dmg := _per_hit_damage(params, targeting, col, is_crit)
		_apply_hit(ledger, target, dmg, is_crit, ctx, res)
		pierced[int(target["uid"])] = int(pierced.get(int(target["uid"]), 0)) + 1
		hits_left -= 1
		## 死者出列后指针不动（下一击落顺位）；未死进位（用户规格正文条款）
		if int(target["hp"]) > 0:
			col = next_column(targeting, col, front_row(ledger).size(), bag)
			if col < 0 or col >= front_row(ledger).size():
				col = wrap_column(targeting, col, front_row(ledger).size())
				if col < 0:
					break
		## 弹跳链（对应 GetBounceCount/GetBounceChance：概率衰减追加击）
		if hits_left <= 0 and bounce_budget > 0:
			var chance: float = float(bouncy.get("base", 0.0))
			for bi in int(bouncy.get("max", 0)):
				if chance <= 0.0 or rng.randf() >= chance:
					break
				hits_left += 1
				bounce_budget -= 1
				res["bounce_hits"] = int(res["bounce_hits"]) + 1
				chance -= float(bouncy.get("decay", 0.0))
	## 飞行总段数（2026-11-08 余段空放制）：演出拍数＝总段数与账单事件数解耦——武器
	## 飞完全程（死目标段空放、无账无数字，对应原版 WeaponCollision 死者跳过＋胜利
	## WaitWhile 等武器）。弹射追加段也计入（bounce_hits 循环内已终值）。
	res["total_strikes"] = int(params.get("hits", 1)) + int(res["bounce_hits"])
	## 暴击爆炸（对应 TryTriggerCritExplosion→ProcessCritExplosionTrigger 递归）：
	## 暴击命中按配置概率对全排追加减伤段，逐层衰减，MaxDepth 封顶
	var explosion: Dictionary = params.get("crit_explosion", {})
	if not explosion.is_empty():
		_process_explosions(ledger, explosion, ctx, res, chain)
	return res

## 账单→演出拍映射（2026-11-08 余段空放制，纯函数——Screen 与探针共用）：
## 每拍消费 1 hit＋紧随其后全部 death（同拍落账同拍收尸——死亡本无独立特效）；
## 拍数不足 total 补空放拍（blank＝刀照飞、无闪白无数字）；事件多于拍数
## （爆炸段等追加 hit 超额）尾拍吞下剩余全部——由循环尾 settle_all 兜底。
static func map_strike_beats(strikes: Array, total: int) -> Array:
	var beats: Array = []
	var i := 0
	var n := strikes.size()
	while i < n:
		var beat := {"blank": false, "uid": -1, "amount": 0, "crit": false,
			"settle": 0, "death_uids": []}
		var st: Dictionary = strikes[i]
		if String(st.get("type", "")) == "hit":
			beat["uid"] = int(st.get("uid", -1))
			beat["amount"] = int(st.get("amount", 0))
			beat["crit"] = bool(st.get("is_crit", false))
			beat["settle"] = 1
			i += 1
		while i < n and String((strikes[i] as Dictionary).get("type", "")) == "death":
			(beat["death_uids"] as Array).push_back(int((strikes[i] as Dictionary).get("uid", -1)))
			beat["settle"] = int(beat["settle"]) + 1
			i += 1
		beats.push_back(beat)
	while i < n:
		beats[beats.size() - 1]["settle"] = int(beats[beats.size() - 1]["settle"]) + 1
		i += 1
	while beats.size() < total:
		beats.push_back({"blank": true, "uid": -1, "amount": 0, "crit": false,
			"settle": 0, "death_uids": []})
	return beats

## 单击伤害（对应 ApplyWeaponHitsToEnemy 的 GetDamageToDo＋GetEnemyDamage：
## 基础×(暴击×倍率)×(1+might)；infinite_corridor 按列距递增——对应其 GetEnemyDamage 覆写）
static func _per_hit_damage(params: Dictionary, targeting: String, col: int, is_crit: bool) -> int:
	var dmg: float = float(params.get("damage_per_hit", 0))
	if is_crit:
		dmg *= float(params.get("crit_mult", 2.0))
	dmg *= 1.0 + float(params.get("might_pct", 0)) / 100.0
	if targeting == "infinite_corridor":
		dmg *= 1.0 + 0.25 * float(col)   # 距离增伤（原版语义；系数自拟）
	return maxi(1, int(round(dmg)))

## 单击落账（对应 ResolveArmorDamage→ApplyResolvedDamageToEnemy→OnSimulatedEnemyDied）：
## 甲吸收即消除（防御成功不穿透）；血伤**封顶剩余血量——多余伤害浪费不结转**
## （2026-11-08 撤溢出轮，用户批：对齐蓝本「伤害不超剩余血量」——其主链杀敌后无
## 伤害转移调用，Overkill 是遗物专属机制与此无关）；跳数记实扣量（甲实扣＋血实扣）。
static func _apply_hit(ledger: Array, target: Dictionary, dmg: int, is_crit: bool,
		ctx: Dictionary, res: Dictionary) -> void:
	var left := dmg
	var applied := 0
	if int(target["armor"]) > 0:
		var absorb := mini(int(target["armor"]), left)
		target["armor"] = int(target["armor"]) - absorb
		left -= absorb
		applied += absorb
	if left > 0:
		var to_hp := mini(left, int(target["hp"]))
		target["hp"] = int(target["hp"]) - to_hp
		applied += to_hp
		_emit_hit(target, applied, is_crit, ctx, res)
		if int(target["hp"]) <= 0:
			ledger.erase(target)
			_emit_death(target, ctx, res)
	else:
		_emit_hit(target, applied, is_crit, ctx, res)

## 暴击爆炸递归（对应 ProcessCritExplosionTrigger 的 depth/nextLevel 双层迭代）
static func _process_explosions(ledger: Array, cfg: Dictionary, ctx: Dictionary,
		res: Dictionary, chain: Dictionary) -> void:
	var max_depth: int = int(cfg.get("max_depth", 1))
	var dmg_pct: float = float(cfg.get("damage_pct", 0.0))
	if dmg_pct <= 0.0:
		return
	for depth in max_depth:
		var triggers: Array = res["hits"].duplicate()
		var fired := 0
		for h in triggers:
			if not bool(h.get("is_crit", false)):
				continue
			if not try_register_explosion_trigger(chain, int(cfg.get("max_triggers", 2))):
				break
			var boom := maxi(1, int(round(float(h.get("amount", 0)) * dmg_pct)))
			for l in front_row(ledger).duplicate():
				_apply_hit(ledger, l, boom, false, ctx, res)
				res["explosion_hits"] = int(res["explosion_hits"]) + 1
				fired += 1
		if fired == 0:
			break
		dmg_pct *= 1.0 - float(cfg.get("decay", 0.0)) / 100.0   # 逐层衰减

static func _emit_hit(target: Dictionary, dmg: int, is_crit: bool,
		ctx: Dictionary, res: Dictionary) -> void:
	res["hits"].push_back({"uid": int(target["uid"]), "amount": dmg, "is_crit": is_crit})
	res["damage"][int(target["uid"])] = int(res["damage"].get(int(target["uid"]), 0)) + dmg
	## 账单事件流（2026-11-08 落账延迟制，对应原版 EnemyDamageInfo 账单＋WeaponCollision
	## 逐目标落账）：hit/death 按结算序入 events——真落账由调用方在击中帧逐事件执行
	(res["events"] as Array).push_back({"type": "hit", "e": target.get("e", {}),
		"uid": int(target["uid"]), "amount": dmg, "is_crit": is_crit})

static func _emit_death(target: Dictionary, ctx: Dictionary, res: Dictionary) -> void:
	(res["kills"] as Array).push_back(int(target["uid"]))
	(res["events"] as Array).push_back({"type": "death", "e": target.get("e", {}),
		"uid": int(target["uid"])})

# ── UI/预览聚合口（对应 IIntentHolder.TryGetIntentValues 的伤害侧等价物）──
static func total_damage(res: Dictionary) -> int:
	var t := 0
	for k in (res["damage"] as Dictionary).keys():
		t += int(res["damage"][k])
	return t
