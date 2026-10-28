## qi-forge 数据层现行态（唯一数据源＝design-docs/武器样例_v0.4 ＋ 基础规则_v0.8；
## 2026-10-27 随「属性重构＋内容大改」轮整体重写）。qiforge 禁 class_name，跨文件 preload。
## 口径：基础面板四维（耐久/攻击/威力/攻次）；防御/抗性＝状态式（出厂 0，效果给）；
## 器灵等级成长轴退役（无 growth 表）；威力＝法术侧攻击轴（原强度退役）；
## 能量/抽牌＝系统升级奇偶交替（§5 公式）；青锋剑/铁骨扇退役（剥离清单 v0.1）。
## 功法 ops＝战斗管线效果指令集（引擎只实现已录指令）；插件 fx/excl 同制。
## 数值全为暂定（用户裁「数值后面都可以改」）；功法新名/插件名占位待正名。
extends RefCounted

#region 器灵（4 件；panel 四维＋def/res 出厂 0；passive.ups＝被动升级方向 1/2）
const WEAPONS := {
	"youming": {
		"name": "幽冥剑", "seal": "冥", "lineage": "剑",
		"panel": {"hp": 34, "atk": 26, "def": 0, "res": 0, "pow": 8, "acts": 1},
		"passive": {"id": "sha_yi", "name": "杀意",
			"desc": "造成伤害后获得 1 层杀意；每有一名敌方死亡获得 1 层杀意。杀意：功法伤害 +1/层，回合结束失去所有层数。",
			"ups": {
				"1": "所有杀意效果提升至 2（+1/层 → +2/层）。",
				"2": "每累计获得 3 层杀意，抽一张牌。"}},
		"spells": [
			{"id": "suodi", "name": "索敌令", "cost": 0, "target": "enemy",
				"desc": "标记一名敌人。本回合被标记敌人死亡时，获得 1 点能量。",
				"ops": [{"op": "mark", "death_energy": 1}]},
			{"id": "miehun", "name": "灭魂斩", "cost": 2, "target": "enemy",
				"desc": "造成 10 点功法伤害（每点威力 +1）；获得 1 层杀意。",
				"ops": [{"op": "dmg_flat", "value": 10, "per_pow": 1, "channel": "功法"},
					{"op": "gain_shayi", "stacks": 1}]},
		],
	},
	"tiansi": {
		"name": "天丝手套", "seal": "丝", "lineage": "奇门",
		"panel": {"hp": 48, "atk": 10, "def": 0, "res": 0, "pow": 10, "acts": 0},
		"passive": {"id": "zhuiji", "name": "追击",
			"desc": "其他器灵普通攻击时，本武器对相同目标追加一次普通攻击。",
			"ups": {
				"1": "每有一点威力，自身攻击力提升一点。",
				"2": "普攻攻击施加一层毒。"}},
		"spells": [
			{"id": "yinsi", "name": "引丝诀", "cost": 2, "target": "ally",
				"desc": "指定一名其他器灵的攻击次数 +1。",
				"ops": [{"op": "aps_mod", "amount": 1, "others": true}]},
			{"id": "luanxin", "name": "乱心蛊", "cost": 1, "target": "enemy",
				"desc": "施加 5 层中毒，变更敌人意图。",
				"ops": [{"op": "status", "sid": "zhongdu", "stacks": 5, "abnormal": true},
					{"op": "reroll_intent"}]},
		],
	},
	"qinggu": {
		"name": "青蛊铃", "seal": "蛊", "lineage": "奇门",
		"panel": {"hp": 40, "atk": 12, "def": 0, "res": 0, "pow": 12, "acts": 1},
		"passive": {"id": "yang_gu", "name": "养蛊",
			"desc": "每次敌人毒发后，自身获得一只蛊虫。",
			"ups": {
				"1": "回合开始时，敌方毒发一次。",
				"2": "敌人死亡时，身上的蛊虫会回到自己身上。"}},
		"spells": [
			{"id": "gujian", "name": "蛊箭术", "cost": 2, "target": "enemy",
				"desc": "对当前敌人造成 3 点功法伤害；弹射 3（每 3 点威力 +1）次。",
				"ops": [{"op": "dmg_bounce", "value": 3, "bounce": 3, "per_pow_bounce": 3, "channel": "功法"}]},
			{"id": "zhaogu", "name": "召蛊术", "cost": 2, "target": "none",
				"desc": "召回自身的所有蛊虫，每只蛊虫回归时对敌人造成 1 点间接伤害。",
				"ops": [{"op": "bug_recall", "dmg_per_bug": 1}]},
		],
	},
	"jingang": {
		"name": "金刚盾", "seal": "刚", "lineage": "奇门",
		"panel": {"hp": 55, "atk": 14, "def": 0, "res": 0, "pow": 8, "acts": 1},
		"passive": {"id": "tie_bi", "name": "铁壁",
			"desc": "每回合第一次普通攻击后（自身），自身和相邻器灵获得 1 层护甲。",
			"ups": {
				"1": "自身耐久度损伤时，获得等于损伤量的护盾，并获得 1 层护甲。",
				"2": "回合结束时护盾量不清空；回合开始时将自身护盾量平均分配给相邻器灵（分配后自身清零；仅一邻＝各半；无邻＝自身减半）。"}},
		"spells": [
			{"id": "hubi", "name": "金刚护壁", "cost": 1, "target": "ally",
				"desc": "指定器灵获得 8 点护盾（每一点威力提升一点），并获得嘲讽，持续一回合。",
				"ops": [{"op": "shield_ally", "value": 8, "per_pow": 1, "taunt_rounds": 1}]},
			{"id": "tiezhao", "name": "铁壁诀", "cost": 2, "target": "ally",
				"desc": "指定器灵获得一（每 15 点威力 +1）层格挡。",
				"ops": [{"op": "block_ally", "per_pow15": true}]},
		],
	},
}
#endregion

#region 功法升级面（方向二选一，单张副本制；新名暂占位「·升一/·升二」待正名）——键 "%s#%d"
const SPELL_UPS := {
	"suodi#1": {"name": "索敌令·升一", "cost": 0,
		"desc": "标记一名敌人；该敌人所有破绽和封穴持续时间翻倍；本回合被标记敌人死亡时，获得 2 点能量。",
		"ops": [{"op": "mark", "death_energy": 2, "double_vuln": true}]},
	"suodi#2": {"name": "索敌令·升二", "cost": 0, "unique": true,
		"desc": "唯一。标记一名敌人；所有被标记敌人获得一层虚弱；获得被标记敌人数的杀意。",
		"ops": [{"op": "mark", "weaken_marked": 1, "shayi_per_marked": 1}]},
		"miehun#1": {"name": "灭魂斩·升一", "cost": 3,
			"desc": "造成 16 点功法伤害（每点威力 +2）；清空所有杀意，每 5 点杀意获得一张 0 费的「消耗」版基础灭魂斩。",
			"ops": [{"op": "dmg_flat", "value": 16, "per_pow": 2, "channel": "功法"},
			{"op": "shayi_cashout", "per": 5, "spawn": "miehun"}]},
	"miehun#2": {"name": "灭魂斩·升二", "cost": 1, "reuse": 2,
			"desc": "造成 2（每 5 点威力 +1）次 5 点功法伤害；复用 2。",
			"ops": [{"op": "dmg_flat", "value": 5, "hits_base": 2, "per_pow_hits": 5, "channel": "功法"}]},
	"yinsi#1": {"name": "引丝诀·升一", "cost": 2,
		"desc": "重置指定一名其他器灵的攻击次数为初始值。",
		"ops": [{"op": "aps_reset", "others": true}]},
		"yinsi#2": {"name": "引丝诀·升二", "cost": 1,
		"desc": "指定一名器灵（可含自身）的攻击次数 +1。",
		"ops": [{"op": "aps_mod", "amount": 1}]},
	"luanxin#1": {"name": "乱心蛊·升一", "cost": 1, "reuse": 1,
		"desc": "施加 5 层中毒，变更敌人意图；复用 1。",
		"ops": [{"op": "status", "sid": "zhongdu", "stacks": 5, "abnormal": true},
			{"op": "reroll_intent"}]},
	"luanxin#2": {"name": "乱心蛊·升二", "cost": 2,
		"desc": "施加 5 层中毒，变更敌人意图；若该敌已被标记，眩晕该敌。",
		"ops": [{"op": "status", "sid": "zhongdu", "stacks": 5, "abnormal": true},
			{"op": "reroll_intent"}, {"op": "stun_if_marked"}]},
		"gujian#1": {"name": "蛊箭术·升一", "cost": 2,
			"desc": "对随机敌方造成 3 点功法伤害和施加一层毒，弹射 3（每 3 点威力 +1）次。",
			"ops": [{"op": "dmg_bounce", "value": 3, "bounce": 3, "per_pow_bounce": 3, "channel": "功法",
				"random": true, "poison_per_hit": 1}]},
		"gujian#2": {"name": "蛊箭术·升二", "cost": 2,
			"desc": "对当前敌人造成 4 点功法伤害，弹射 3（每 4 点威力 +1）次；每命中一名不同敌人，抽一张牌。",
			"ops": [{"op": "dmg_bounce", "value": 4, "bounce": 3, "per_pow_bounce": 4, "channel": "功法",
				"draw_per_new": 1}]},
	"zhaogu#1": {"name": "召蛊术·升一", "cost": 2,
		"desc": "召回自身的所有蛊虫（每只 1 点间接伤害），随后再次随机分配。",
		"ops": [{"op": "bug_recall", "dmg_per_bug": 1, "reassign": true}]},
	"zhaogu#2": {"name": "召蛊术·升二", "cost": 2,
		"desc": "召回所有蛊虫（每只 1 点间接伤害），召回后所有器灵获得自身拥有蛊虫量的护盾。",
		"ops": [{"op": "bug_recall", "dmg_per_bug": 1, "shield_own_bugs": true}]},
		"hubi#1": {"name": "金刚护壁·升一", "cost": 1,
			"desc": "指定器灵获得 8 点护盾（每一点威力提升一点）；获得一层抵抗。",
			"ops": [{"op": "shield_ally", "value": 8, "per_pow": 1},
			{"op": "status", "sid": "dikang", "stacks": 1, "to": "target"}]},
		"hubi#2": {"name": "金刚护壁·升二", "cost": 1,
			"desc": "指定器灵获得 10 点护盾（每一点威力提升一点），并获得嘲讽，持续两回合。",
			"ops": [{"op": "shield_ally", "value": 10, "per_pow": 1, "taunt_rounds": 2}]},
	"tiezhao#1": {"name": "铁壁诀·升一", "cost": 2,
		"desc": "指定器灵获得一（每 15 点威力 +1）层格挡，并去除随机一个减益状态。",
		"ops": [{"op": "block_ally", "per_pow15": true}, {"op": "cleanse", "stacks": 1}]},
		"tiezhao#2": {"name": "铁壁诀·升二", "cost": 0, "exhaust": true,
		"desc": "指定器灵获得一（每 15 点威力 +1）层格挡。",
		"ops": [{"op": "block_ally", "per_pow15": true}]},
}
#endregion

#region 插件（通用七件＋专属件；专属件 excl＝{wid: 效果}——装对应器灵才生效；名占位「插件N」待正名）
const ACCESSORIES := {
	# —— 通用七件 ——
	"p1": {"name": "插件1", "lv": 5, "price": 160,
		"stats": {},
		"fx": {"kind": "pct_fade", "pct": 80, "fade": 20},
		"desc": "战斗开始时，攻击力/防御力/威力提升 80%；每回合结束降低 20%（四回合归零）。"},
	"p2": {"name": "插件2", "lv": 3, "price": 140,
		"stats": {"pow": 8}, "fx": {},
		"desc": "获得 8 点威力。"},
	"p3": {"name": "插件3", "lv": 4, "price": 120,
		"stats": {}, "fx": {"kind": "kill_act"},
		"desc": "一回合一次，敌人死亡后获得一次攻击次数。"},
	"p4": {"name": "插件4", "lv": 1, "price": 70,
		"stats": {"hp": 30}, "fx": {},
		"desc": "耐久度提升 30。"},
	"p5": {"name": "插件5", "lv": 4, "price": 110,
		"stats": {}, "fx": {"kind": "hit_poxian", "stacks": 1, "rounds": 1},
		"desc": "每次攻击造成一层破绽，持续 1 回合。"},
	"p6": {"name": "插件6", "lv": 3, "price": 90,
		"stats": {}, "fx": {"kind": "atk_energy"},
		"desc": "一回合一次，普攻后获得一点能量。"},
	"p7": {"name": "插件7", "lv": 3, "price": 90,
		"stats": {}, "fx": {"kind": "discard_draw"},
		"desc": "若自身的牌被弃置，抽一张牌（按次；回合末冲弃同样触发）。"},
	# —— 数值件按档（2026-10-28 配件轮：补 Lv1/Lv2 空档；占位名同制待正名）——
	"p8": {"name": "插件8", "lv": 1, "price": 45,
		"stats": {"atk": 3}, "fx": {},
		"desc": "攻击力 +3。"},
	"p9": {"name": "插件9", "lv": 1, "price": 45,
		"stats": {"pow": 3}, "fx": {},
		"desc": "威力 +3。"},
	"p10": {"name": "插件10", "lv": 2, "price": 70,
		"stats": {"atk": 5}, "fx": {},
		"desc": "攻击力 +5。"},
	"p11": {"name": "插件11", "lv": 2, "price": 70,
		"stats": {"pow": 5}, "fx": {},
		"desc": "威力 +5。"},
	"p12": {"name": "插件12", "lv": 2, "price": 80,
		"stats": {}, "fx": {"kind": "battle_start_status", "sid": "dikang", "stacks": 1},
		"desc": "战斗开始时，获得一层抵抗。"},
	"p13": {"name": "插件13", "lv": 3, "price": 110,
		"stats": {"atk": 4, "pow": 4}, "fx": {},
		"desc": "攻击力 +4，威力 +4。"},
	"p14": {"name": "插件14", "lv": 4, "price": 150,
		"stats": {"atk": 5, "pow": 5, "hp": 10}, "fx": {},
		"desc": "攻击力 +5，威力 +5，耐久度 +10。"},
	# —— 专属件（天丝1≡青蛊1 同一件双专属）——
	"x_ym_1": {"name": "插件·幽冥一", "lv": 3, "price": 100,
		"stats": {"acts": 1}, "fx": {"kind": "atk_poxian", "stacks": 1, "rounds": 2},
		"excl": {"youming": {"kind": "shayi_all"}},
		"desc": "攻击次数 +1。特殊：造成普攻伤害后，敌方获得一层破绽（持续 2 回合）。",
		"excl_desc": {"youming": "杀意改为增加所有伤害。"}},
	"x_ym_2": {"name": "插件·幽冥二", "lv": 2, "price": 130,
		"stats": {"pow": 5}, "fx": {},
		"excl": {"youming": {"kind": "spell_cycle", "n": 3}},
		"desc": "威力 +5。",
		"excl_desc": {"youming": "该器灵每累计打出 3 张功法，获得 1 点能量，执行一次自身抽牌。"}},
	"x_ym_3": {"name": "插件·幽冥三", "lv": 2, "price": 120,
		"stats": {"atk": -2}, "fx": {"kind": "round_start_shayi", "stacks": 3},
		"excl": {"youming": {"kind": "shayi_keep", "max": 5}},
		"desc": "攻击力 -2。特殊：每回合开始时获得 3 层杀意。",
		"excl_desc": {"youming": "回合结束后可以保留最多 5 层杀意。"}},
	"x_ts_1": {"name": "插件·丝蛊同源", "lv": 3, "price": 100,
		"stats": {"atk": 5, "pow": 5, "hp": -20}, "fx": {},
		"excl": {"tiansi": {"kind": "drain_atk", "amount": 3}, "qinggu": {"kind": "bug_pow"}},
		"desc": "攻击力 +5，威力 +5，生命值 -20。",
		"excl_desc": {"tiansi": "每次普攻后：敌方获得 3 层竭力，自身获得 3 层力量。",
			"qinggu": "身上每有一个蛊虫，获得一点威力加成。"}},
	"x_ts_2": {"name": "插件·天丝二", "lv": 2, "price": 130,
		"stats": {}, "fx": {"kind": "spell_cleanse"},
		"excl": {"tiansi": {"kind": "drain_mhp_per_debuff"}},
		"desc": "特殊：打出自身功法牌后，自身所有减益状态持续时间 -1。",
		"excl_desc": {"tiansi": "普攻后，敌人每有一种减益状态，汲取一点最大生命值。"}},
	"x_ts_3": {"name": "插件·天丝三", "lv": 2, "price": 120,
		"stats": {"pow": 5, "hp": 20}, "fx": {},
		"excl": {"tiansi": {"kind": "atk_bug"}},
		"desc": "威力 +5，生命值 +20。",
		"excl_desc": {"tiansi": "每次普攻后，自身获得一只蛊虫。"}},
	"x_qg_2": {"name": "插件·青蛊二", "lv": 3, "price": 130,
		"stats": {}, "fx": {"kind": "round_start_poison", "targets": 2, "stacks": 2},
		"excl": {"qinggu": {"kind": "bug_breed", "per": 3}},
		"desc": "特殊：回合开始时，随机两名敌人获得 2 层毒。",
		"excl_desc": {"qinggu": "回合结束时，自身每有 3 个蛊虫，获得一只蛊虫。"}},
	"x_qg_3": {"name": "插件·青蛊三", "lv": 2, "price": 120,
		"stats": {}, "fx": {"kind": "poison_transfer"},
		"excl": {"qinggu": {"kind": "atk_poison_tick"}},
		"desc": "特殊：敌人死亡时，身上剩余的毒层数的一半会转移给随机敌人。",
		"excl_desc": {"qinggu": "每次普通攻击会触发一次敌人的毒。"}},
	"x_jg_1": {"name": "插件·金刚一", "lv": 2, "price": 100,
		"stats": {"def": 3, "hp": 10}, "fx": {},
		"excl": {"jingang": {"kind": "shield_fanzhen", "pct": 50}},
		"desc": "防御力 +3，生命值 +10。",
		"excl_desc": {"jingang": "拥有护盾时，获得 50% 反震。"}},
	"x_jg_2": {"name": "插件·金刚二", "lv": 2, "price": 130,
		"stats": {}, "fx": {"kind": "battle_start_shield_pct", "pct": 25},
		"excl": {"jingang": {"kind": "atk_block", "stacks": 1}},
		"desc": "特殊：战斗开始时，获得 25% 最大生命值的护盾。",
		"excl_desc": {"jingang": "普攻后，随机器灵获得一层格挡。"}},
	"x_jg_3": {"name": "插件·金刚三", "lv": 2, "price": 120,
		"stats": {"def": 5}, "fx": {},
		"excl": {"jingang": {"kind": "def_atk"}},
		"desc": "防御力 +5。",
		"excl_desc": {"jingang": "每有一点防御力，自身攻击力提升一点。"}},
}

## 插件在某器灵上的完整描述（含专属词条）——备战舱装备窗/详情用
static func accessory_desc(aid: String, wid: String = "") -> String:
	var a: Dictionary = ACCESSORIES[aid]
	var txt := String(a["desc"])
	if wid != "" and a.get("excl_desc", {}).has(wid):
		txt += "专属（%s）：%s" % [WEAPONS[wid]["name"], String(a["excl_desc"][wid])]
	return txt

## 该器灵是否为该插件的专属对象（无 excl 条目的＝通用件，恒 false）
static func is_exclusive_for(aid: String, wid: String) -> bool:
	return ACCESSORIES[aid].get("excl", {}).has(wid)
#endregion

#region 货架出货率（蓝本实测档率；行＝系统等级 1~5）
const TIER_LADDER := [1, 3, 4, 5]
const TIER_ODDS := {
	1: [100, 0, 0, 0],
	2: [80, 20, 0, 0],
	3: [60, 35, 5, 0],
	4: [48, 40, 10, 2],
	5: [40, 40, 13, 7],
}

static func tier_pool(lv: int) -> Array:
	var out: Array = []
	for id in ACCESSORIES:
		if int(ACCESSORIES[id]["lv"]) == lv:
			out.push_back(id)
	return out

static func tier_odds(sys_lv: int) -> Array:
	return TIER_ODDS[clampi(sys_lv, 1, 5)]
#endregion

#region 卡组制常量与公式（基础规则 v0.7 §5：奇偶交替制；开局＝系统 Lv2：能 3 抽 4）
const ENERGY_BASE := 3
const DRAW_BASE := 4
const COPIES_PER_SPELL := 2

## 能量上限＝3＋⌊(Lv−2)/2⌋（偶数次升级 +1：Lv4/6/8…）
static func energy_cap_of(sys_lv: int) -> int:
	return ENERGY_BASE + int(floor(float(maxi(2, sys_lv) - 2) / 2.0))

## 抽牌＝4＋⌈(Lv−2)/2⌉（奇数次升级 +1：Lv3/5/7…）
static func draw_of(sys_lv: int) -> int:
	return DRAW_BASE + int(ceil(float(maxi(2, sys_lv) - 2) / 2.0))

static func build_deck(team: Array) -> Array:
	var deck: Array = []
	for m in team:
		if not WEAPONS.has(String(m["id"])):
			continue
		for s in WEAPONS[String(m["id"])]["spells"]:
			for i in COPIES_PER_SPELL:
				deck.push_back({"wid": String(m["id"]), "sid": String(s["id"]), "dir": 0})
	return deck

## 换装随卡组进出（升级保留制 2026-10-28 §3：下场器灵的功法卡含升级 dir 原样存档——
## 记录仍在队/后备＝挂成员档案 cards；记录被删回未解锁池＝挂 run.pool_cards；再装备优先按档案重建）
static func deck_swap(run: Dictionary, out_wid: String, in_wid: String = "") -> void:
	var deck: Array = run.get("deck", [])
	if out_wid != "":
		var stash: Array = []
		for i in range(deck.size() - 1, -1, -1):
			if String(deck[i]["wid"]) == out_wid:
				stash.push_front(deck[i])
				deck.remove_at(i)
		if not stash.is_empty():
			var rec := find_member(run, out_wid)
			if not rec.is_empty():
				rec["cards"] = stash
			else:
				var pool: Dictionary = run.get("pool_cards", {})
				pool[out_wid] = stash
				run["pool_cards"] = pool
	if in_wid != "" and WEAPONS.has(in_wid):
		var restore: Array = []
		var irec := find_member(run, in_wid)
		if not irec.is_empty() and irec.has("cards"):
			restore = irec["cards"]
			irec.erase("cards")
		elif run.get("pool_cards", {}).has(in_wid):
			restore = run["pool_cards"][in_wid]
			run["pool_cards"].erase(in_wid)
		if restore.is_empty():
			for s in WEAPONS[in_wid]["spells"]:
				for i in COPIES_PER_SPELL:
					deck.push_back({"wid": in_wid, "sid": String(s["id"]), "dir": 0})
		else:
			for e in restore:
				deck.push_back(e)
	run["deck"] = deck

#region 回血制套件（2026-10-28 §7 耐久跨场持久：全 run 无自动回血复活，三通道＝后备/金币/奖励位；数值暂定非锁定）
const RESERVE_HEAL_PCT := 25     # 后备每场战后回血 %（暂定）
const HEAL_COPPER_PER_HP := 1.0  # 金币回复 铜每点（暂定）
const REVIVE_COPPER_PER_HP := 1.5  # 阵亡复活溢价（暂定）
const REWARD_HEAL_PCT := 50      # 奖励位回复 %（暂定）

static func mhp_of(m: Dictionary) -> int:
	return int(weapon_panel(String(m["id"]), m.get("equips", [])).get("hp", 0))

static func hp_of(m: Dictionary) -> int:
	var mhp := mhp_of(m)
	return clampi(int(m.get("hp", mhp)), 0, mhp)

static func find_member(run: Dictionary, wid: String) -> Dictionary:
	for arr in [run.get("team", []), run.get("reserve", [])]:
		for m in arr:
			if String(m["id"]) == wid:
				return m
	return {}

## 后备池每场战后回血（含阵亡缓复：0 血逐场累积，>0 即可再上阵）
static func reserve_tick(run: Dictionary) -> void:
	for m in run.get("reserve", []):
		var mhp := mhp_of(m)
		m["hp"] = mini(mhp, int(m.get("hp", mhp)) + int(ceil(mhp * RESERVE_HEAL_PCT / 100.0)))

## 金币回复价（疗伤至满）：存活＝缺口×1；阵亡＝缺口×1.5（暂定）
static func heal_price(m: Dictionary) -> int:
	var mhp := mhp_of(m)
	var now := hp_of(m)
	if now >= mhp:
		return 0
	var rate := REVIVE_COPPER_PER_HP if now <= 0 else HEAL_COPPER_PER_HP
	return int(ceil(float(mhp - now) * rate))

static func reward_heal_amount(m: Dictionary) -> int:
	return int(ceil(mhp_of(m) * REWARD_HEAL_PCT / 100.0))

## 战后耐久写回（战斗屏 team_out → QiRoot 胜利分支调用）
static func apply_team_out(run: Dictionary, tout: Array) -> void:
	for rec in tout:
		var m := find_member(run, String(rec.get("id", "")))
		if not m.is_empty():
			m["hp"] = clampi(int(rec.get("hp", mhp_of(m))), 0, mhp_of(m))
#endregion

static func spell_of(wid: String, sid: String, dir: int) -> Dictionary:
	var base: Dictionary = {}
	for s in WEAPONS[wid]["spells"]:
		if String(s["id"]) == sid:
			base = s
			break
	var out: Dictionary = base.duplicate(true)
	if dir > 0:
		var key := "%s#%d" % [sid, dir]
		if SPELL_UPS.has(key):
			var up: Dictionary = SPELL_UPS[key]
			for k in up:
				out[k] = up[k]
	out["dir"] = dir
	return out

## 升级 diff（句级，2026-10-27 用户裁定「增/删/改特殊标记」）：desc 按 。；切句对比——
## 相同句＝same／仅升级有＝add／仅基础有＝del（附尾展示）／前 3 字相同或互含＝mod；
## 费用变化单列最前一行。返回 {lines: [{t, cls}], name_changed, cost_changed}
static func spell_diff(wid: String, sid: String, dir: int) -> Dictionary:
	var base: Dictionary = spell_of(wid, sid, 0)
	var up: Dictionary = spell_of(wid, sid, dir)
	var base_sents: Array = _split_sents(String(base.get("desc", "")))
	var up_sents: Array = _split_sents(String(up.get("desc", "")))
	var used := {}
	var lines: Array = []
	for us in up_sents:
		var hit := -1
		for i in base_sents.size():
			if not used.has(i) and String(base_sents[i]) == String(us):
				hit = i
				break
		if hit >= 0:
			used[hit] = true
			lines.push_back({"t": String(us), "cls": "same"})
			continue
		var mod_i := -1
		for i in base_sents.size():
			if used.has(i):
				continue
			var bs := String(base_sents[i])
			if bs.length() >= 3 and String(us).length() >= 3 and bs.substr(0, 3) == String(us).substr(0, 3):
				mod_i = i
				break
			if not bs.is_empty() and (bs.contains(String(us)) or String(us).contains(bs)):
				mod_i = i
				break
		if mod_i >= 0:
			used[mod_i] = true
			lines.push_back({"t": String(us), "cls": "mod"})
		else:
			lines.push_back({"t": String(us), "cls": "add"})
	for i in base_sents.size():
		if not used.has(i):
			lines.push_back({"t": String(base_sents[i]), "cls": "del"})
	var cost_changed := int(base.get("cost", 0)) != int(up.get("cost", 0))
	if cost_changed:
		lines.push_front({"t": "费用 %d → %d" % [int(base.get("cost", 0)), int(up.get("cost", 0))], "cls": "mod"})
	return {"lines": lines,
		"name_changed": String(base.get("name", "")) != String(up.get("name", "")),
		"cost_changed": cost_changed}

static func _split_sents(text: String) -> Array:
	var out: Array = []
	for part in text.replace("；", "。").split("。", false):
		var s := part.strip_edges()
		if not s.is_empty():
			out.push_back(s)
	return out
#endregion

#region 战后奖励六类操作池（基础规则 v0.7 §7；先掷类型→子池掷对象）
## 类型：add_spirit 新增器灵／upgrade_spirit 升级器灵（被动）／add_spell 新增功法／
## upgrade_spell 升级功法牌／remove_spell 删除功法牌／copy_spell 复制功法牌
const OP_KINDS := ["add_spirit", "upgrade_spirit", "add_spell", "upgrade_spell", "remove_spell", "copy_spell", "heal"]
const OP_NAMES := {
	"add_spirit": "新增器灵", "upgrade_spirit": "升级器灵", "add_spell": "新增功法",
	"upgrade_spell": "升级功法牌", "remove_spell": "删除功法牌", "copy_spell": "复制功法牌",
	"heal": "回复",
}
const OP_BUTTONS := {
	"add_spirit": "入后备", "upgrade_spirit": "升级被动", "add_spell": "添加",
	"upgrade_spell": "升级", "remove_spell": "删除", "copy_spell": "复制",
	"heal": "回复",
}

## 商店操作位定价（2026-10-27 用户裁定两档制：功法类 50／器灵类 70；升级相关 +10；回复类暂 50）
static func op_price(kind: String) -> int:
	if kind == "heal":
		return 50
	var base := 70 if kind in ["add_spirit", "upgrade_spirit"] else 50
	if kind in ["upgrade_spirit", "upgrade_spell"]:
		base += 10
	return base

## 某类型的子池（空池＝该类型本轮出局）；条目形如
## {kind, wid} 器灵类 / {kind, wid, sid, dir} 功法类
static func op_pool(run: Dictionary, kind: String) -> Array:
	var out: Array = []
	var team: Array = run.get("team", [])
	var deck: Array = run.get("deck", [])
	var owned := {}
	for m in team:
		owned[String(m["id"])] = m
	match kind:
		"add_spirit":
			for wid in WEAPONS:
				if not owned.has(wid):
					out.push_back({"kind": kind, "wid": wid})
		"upgrade_spirit":
			for m in team:
				if int(m.get("pdir", 0)) == 0:
					out.push_back({"kind": kind, "wid": String(m["id"])})
		"add_spell":
			var seen := {}
			for m in team:
				var wid := String(m["id"])
				for s in WEAPONS[wid]["spells"]:
					var sid := String(s["id"])
					var key := "%s#%s" % [wid, sid]
					if not seen.has(key):
						seen[key] = true
						out.push_back({"kind": kind, "wid": wid, "sid": sid, "dir": 0})
		"upgrade_spell":
			var seen2 := {}
			for e in deck:
				if int(e.get("dir", 0)) != 0:
					continue
				var key2 := "%s#%s" % [e["wid"], e["sid"]]
				if not seen2.has(key2):
					seen2[key2] = true
					out.push_back({"kind": kind, "wid": String(e["wid"]), "sid": String(e["sid"]), "dir": 0})
		"remove_spell":
			var seen3 := {}
			for e in deck:
				var key3 := "%s#%s#%d" % [e["wid"], e["sid"], int(e.get("dir", 0))]
				if not seen3.has(key3):
					seen3[key3] = true
					out.push_back({"kind": kind, "wid": String(e["wid"]), "sid": String(e["sid"]), "dir": int(e.get("dir", 0))})
		"copy_spell":
			var seen4 := {}
			for e in deck:
				if int(e.get("dir", 0)) <= 0:
					continue
				var key4 := "%s#%s#%d" % [e["wid"], e["sid"], int(e.get("dir", 0))]
				if not seen4.has(key4):
					seen4[key4] = true
					out.push_back({"kind": kind, "wid": String(e["wid"]), "sid": String(e["sid"]), "dir": int(e.get("dir", 0))})
		"heal":
			# 回复（2026-10-28 第七类）：子池＝我方全体带伤/阵亡器灵（满血出局；无 hp 字段＝满血）
			for arr in [run.get("team", []), run.get("reserve", [])]:
				for m in arr:
					if int(m.get("hp", -1)) >= 0 and int(m["hp"]) < mhp_of(m):
						out.push_back({"kind": kind, "wid": String(m["id"])})
	return out
#endregion

#region 状态总表（基础规则 v0.7 §4 状态表 v2；abnormal＝先过抗性；debuff＝抵抗可挡/可被驱散）
const STATUSES := {
	"xuan": {"name": "眩晕", "glyph": "眩", "cls": "控制", "color": "b48ae0", "debuff": true,
		"desc": "本回合无法行动（禁普攻/禁功法，被动停摆）。"},
	"jiaoxie": {"name": "缴械", "glyph": "械", "cls": "控制", "color": "b48ae0", "debuff": true,
		"desc": "无法普攻（功法照常）。"},
	"jingu": {"name": "禁锢", "glyph": "锢", "cls": "控制", "color": "b48ae0", "debuff": true,
		"desc": "本回合无法抽牌。"},
	"chaofeng": {"name": "嘲讽", "glyph": "嘲", "cls": "控制", "color": "b48ae0",
		"desc": "普攻必须先打嘲讽者；回合末层 -1。"},
	"biaoji": {"name": "标记", "glyph": "记", "cls": "协同", "color": "e0c26a", "debuff": true,
		"desc": "减益状态；跨武器协同锚；可多敌共存。"},
	"zhongdu": {"name": "中毒", "glyph": "毒", "cls": "掉血", "color": "a86ad0", "abnormal": true, "debuff": true,
		"desc": "回合结束受到等于层数的间接伤害（穿盾穿挡），层 -1。"},
	"poxian": {"name": "破绽", "glyph": "破", "cls": "易伤", "color": "e07a6a", "abnormal": true, "debuff": true,
		"desc": "受到的普攻伤害 +1/层。"},
	"fengxue": {"name": "封穴", "glyph": "穴", "cls": "易伤", "color": "e07a6a", "abnormal": true, "debuff": true,
		"desc": "受到的功法伤害 +1/层。"},
	"liliang": {"name": "力量", "glyph": "力", "cls": "面板", "color": "7fae62",
		"desc": "攻击力 +1/层，无持续时间（战斗内常驻）。"},
	"jieli": {"name": "竭力", "glyph": "竭", "cls": "面板", "color": "8a9a58", "debuff": true,
		"desc": "攻击力 -1/层，无持续时间（战斗内常驻）。"},
	"hujia": {"name": "护甲", "glyph": "甲", "cls": "面板", "color": "6a9ad0",
		"desc": "防御 +1/层（只减普攻伤害），无持续时间（战斗内常驻）。"},
	"pojia": {"name": "破甲", "glyph": "破", "cls": "面板", "color": "d08a6a", "debuff": true,
		"desc": "防御 -1/层，无持续时间（战斗内常驻）。"},
	"kangxing": {"name": "抗性加", "glyph": "抗", "cls": "面板", "color": "8aa8d0",
		"desc": "抗性 +N（负面状态落地前按百分比削减）。"},
	"qiangdu": {"name": "强度", "glyph": "强", "cls": "面板", "color": "d0b06a",
		"desc": "威力 +1/层（功法缩放轴），无持续时间（战斗内常驻）。"},
	"hudun": {"name": "护盾", "glyph": "盾", "cls": "资源", "color": "8ab8d0",
		"desc": "固定值吸收层，受伤先扣盾；回合结束清空。"},
	"gebi": {"name": "格挡", "glyph": "挡", "cls": "资源", "color": "8ad0a8",
		"desc": "免疫下一次受到的伤害（多段只挡一段）。"},
	"dikang": {"name": "抵抗", "glyph": "御", "cls": "资源", "color": "8ad0c8",
		"desc": "免疫下一次受到的负面状态（挡敌方施加）。"},
	"shayi": {"name": "杀意", "glyph": "杀", "cls": "身份", "color": "d04a4a",
		"desc": "功法伤害 +1/层，回合末失去所有层数。"},
	"xuruo": {"name": "虚弱", "glyph": "弱", "cls": "身份", "color": "8a9a58", "debuff": true,
		"desc": "造成伤害减半，回合末层 -1。"},
	"nuyi": {"name": "怒意", "glyph": "怒", "cls": "身份", "color": "d08a4a",
		"desc": "普攻伤害 +50%，普攻后层 -1。"},
	"longwei": {"name": "龙威", "glyph": "龙", "cls": "身份", "color": "d0b06a",
		"desc": "对龙威层数低于自身的敌人伤害翻倍；被击后层 -1。"},
	"leifan": {"name": "雷反", "glyph": "雷", "cls": "身份", "color": "e0a24a",
		"desc": "受击后即刻反震 2×层数真伤（即时插入；同链一来一回）。"},
	"fanji": {"name": "反击", "glyph": "击", "cls": "身份", "color": "d06a6a",
		"desc": "受到伤害后即刻对来源普攻反击一次（不耗攻击次数）；反击 N＝一回合最多触发 N 次。"},
}
#endregion

#region 敌方 G1（黑风寨；敌方防御同制＝只减我方普攻伤害）
const ENEMIES := {
	"shanfei_dashou": {
		"name": "山匪打手", "seal": "匪",
		"panel": {"hp": 60, "atk": 20, "def": 8, "res": 0, "acts": 1},
		"actions": [
			{"id": "huiji", "name": "挥击", "kind": "attack", "mult": 1.0,
				"tip": "挥击：对一件器灵造成 100% 攻击的外伤（已计入防御与破绽）。"},
			{"id": "mengji", "name": "猛击", "kind": "attack", "mult": 1.5, "cd": 2,
				"tip": "猛击（冷却 2 回合）：对一件器灵造成 150% 攻击的外伤。"},
		],
	},
	"shanfei_lieshou": {
		"name": "山匪猎手", "seal": "猎",
		"panel": {"hp": 35, "atk": 14, "def": 6, "res": 0, "acts": 1},
		"actions": [
			{"id": "sheji", "name": "射击", "kind": "attack", "mult": 1.1,
				"side": [{"op": "status", "sid": "poxian", "stacks": 1, "abnormal": true, "to": "target"}],
				"tip": "射击：造成 110% 攻击外伤，并给目标挂 1 层破绽。"},
			{"id": "ningshen", "name": "凝神", "kind": "buff", "cd": 3,
				"side": [{"op": "self_buff", "sid": "hujia", "stacks": 5}],
				"tip": "凝神（冷却 3 回合）：自身获得 5 层护甲（防御 +5）。"},
		],
	},
}

const GROUPS := [
	{"name": "第 1 组 · 黑风寨", "fights": [
		{"label": "第 1 场", "enemies": ["shanfei_dashou", "shanfei_lieshou"], "reward": 30, "boss": false},
		{"label": "第 2 场", "enemies": ["shanfei_dashou", "shanfei_dashou", "shanfei_lieshou"], "reward": 30, "boss": true},
	]},
]
#endregion

## 开局固定队（试玩切片＝用户亲设幽冥剑＋天丝手套；pdir＝被动升级方向 0=未选）
const START_TEAM := [{"id": "youming", "equips": ["", "", ""], "pdir": 0},
	{"id": "tiansi", "equips": ["", "", ""], "pdir": 0}]

## 默认 run（QiRoot/战斗屏/备战舱三处同源）；sys_lv=2 开局＝能量 3／抽牌 4
static func default_run() -> Dictionary:
	var run := {"copper": 130, "bag": [],
		"team": START_TEAM.duplicate(true),
		"sys_lv": 2, "group": 0, "fight": 0, "seed": 20261026}
	for m in run["team"]:
		m["hp"] = mhp_of(m)   # 新局满血（耐久跨场持久制 §7）
	run["deck"] = build_deck(run["team"])
	return run

#region 组装工具
## 器灵出厂面板（基础四维＋插件固定值；装备加成不进状态栏——直接入面板账）
static func weapon_panel(wid: String, equips: Array = []) -> Dictionary:
	var w: Dictionary = WEAPONS[wid]
	var p: Dictionary = {"hp": 0, "atk": 0, "def": 0, "res": 0, "pow": 0, "acts": 0}
	for k in ["hp", "atk", "def", "res", "pow", "acts"]:
		p[k] = int(w["panel"].get(k, 0))
	for eid in equips:
		if not ACCESSORIES.has(eid):
			continue
		var stats: Dictionary = ACCESSORIES[eid]["stats"]
		for k in ["hp", "atk", "def", "res", "pow", "acts"]:
			if stats.has(k):
				p[k] += int(stats[k])
	return p

static func fight_label(group_i: int, fight_i: int) -> String:
	if group_i >= GROUPS.size():
		return "旅途未尽（后续组待开）"
	var g: Dictionary = GROUPS[group_i]
	if fight_i >= g["fights"].size():
		return "%s · 已通关" % g["name"]
	var f: Dictionary = g["fights"][fight_i]
	var names: Array = []
	for eid in f["enemies"]:
		names.push_back(ENEMIES[eid]["name"])
	return "%s · %s—— %s" % [g["name"], f["label"], " ＋ ".join(PackedStringArray(names))]

## 该场是否组末强敌（Boss 保证位＝奖励固定占「新增器灵·已升级」一位）
static func is_boss_fight(group_i: int, fight_i: int) -> bool:
	if group_i >= GROUPS.size():
		return false
	var fights: Array = GROUPS[group_i]["fights"]
	return bool(fights[mini(fight_i, fights.size() - 1)].get("boss", fight_i >= fights.size() - 1))
#endregion
