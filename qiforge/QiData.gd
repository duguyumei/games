## qi-forge 数据层现行态（唯一数据源＝design-docs/武器样例_v0.4 ＋ 基础规则_v0.8；
## 2026-10-27 随「属性重构＋内容大改」轮整体重写）。qiforge 禁 class_name，跨文件 preload。
## 口径：基础面板四维（耐久/攻击/威力/攻次）；防御/抗性＝状态式（出厂 0，效果给）；
## 器灵等级成长轴退役（无 growth 表）；威力＝法术侧攻击轴（原强度退役）；
## 能量/抽牌＝系统升级奇偶交替（§5 公式）；青锋剑/铁骨扇退役（剥离清单 v0.1）。
## 功法 ops＝战斗管线效果指令集（引擎只实现已录指令）；插件 fx/excl 同制。
## 数值全为暂定（用户裁「数值后面都可以改」）；功法新名/插件名占位待正名。
extends RefCounted

#region 器灵（5 件；panel 四维＋def/res 出厂 0；passive.ups＝被动升级方向 1/2）
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
			"desc": "其他器灵普通攻击时（含功法内的普攻段；被格挡或护盾完全吸收也算），本武器对相同目标追加一次普通攻击，不消耗攻击次数。",
			"ups": {
				"1": "每有一点威力，自身攻击力提升一点。",
				"2": "普攻攻击施加一层毒。"}},
		"spells": [
		{"id": "yinsi", "name": "引丝诀", "cost": 1, "target": "ally",
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
			"desc": "每次敌人毒发后，自身获得一只蛊虫（以状态层数计）。向带有蛊虫的敌人施加中毒时，额外增加其身上蛊虫数量的层数（蛊虫增幅）。",
			"ups": {
				"1": "回合开始时，所有敌方各毒发一次。",
				"2": "敌人死亡时，身上的蛊虫会回到自己身上。"}},
		"spells": [
		{"id": "gujian", "name": "蛊箭术", "cost": 1, "target": "enemy",
			"desc": "对当前敌人造成 3 点功法伤害和施加一层毒；弹射 2（每 5 点威力 +1）次。",
			"ops": [{"op": "dmg_bounce", "value": 3, "bounce": 2, "per_pow_bounce": 5, "channel": "功法",
				"poison_per_hit": 1}]},
		{"id": "zhaogu", "name": "召蛊术", "cost": 1, "target": "none",
			"desc": "召回自身的所有蛊虫，每只蛊虫回归时对敌人造成 1 点间接伤害。",
			"ops": [{"op": "bug_recall", "dmg_per_bug": 1}]},
		],
	},
	"jingang": {
		"name": "金刚盾", "seal": "刚", "lineage": "奇门",
		"panel": {"hp": 55, "atk": 14, "def": 0, "res": 0, "pow": 8, "acts": 1},
		"passive": {"id": "tie_bi", "name": "铁壁",
			"desc": "每次普通攻击后（含功法内的普攻段，多次普攻每次都触发），自身和相邻器灵获得 1 层护甲。",
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
	"liangyi": {
		"name": "两仪刀剑", "seal": "仪", "lineage": "刀剑",
		"panel": {"hp": 42, "atk": 15, "def": 0, "res": 0, "pow": 12, "acts": 1},
		"passive": {"id": "yi_dao_yi_jian", "name": "亦刀亦剑",
			"desc": "初始无形态。造成普攻伤害（含功法内普攻段）时转为刀形态，造成功法伤害时转为剑形态；逐段判定，仅形态实际改变时触发。转为刀时获得 1 层强度，转为剑时获得 1 层力量。",
			"ups": {
				"1": "每次形态转换后，随机一张手牌中的功法牌能量消耗 −1（持续到回合结束，可叠加，最低 0）。",
				"2": "每次形态转换后，所有器灵获得 3 点护盾（每 5 点威力 +1，按两仪刀剑自身威力计）。"}},
		"spells": [
			{"id": "liejia", "name": "裂甲斩", "cost": 1, "target": "enemy",
				"desc": "对目标造成 6 点普攻伤害（每 2 点攻击力 +1，每 3 点威力 +1），并对目标及其相邻单位施加 1 层破甲（每 5 点威力 +1 层）。视为普通攻击。",
				"ops": [{"op": "dmg_flat", "value": 6, "atk_step": 2, "pow_step": 3, "channel": "普攻"},
					{"op": "pojia_aoe", "stacks": 1, "per_pow": 5}]},
			{"id": "daojian", "name": "刀剑合击", "cost": 1, "target": "enemy",
				"desc": "造成 4 点功法伤害（每点威力 +1），随后对同一目标进行一次攻击力减半的普通攻击。",
				"ops": [{"op": "dmg_flat", "value": 4, "per_pow": 1, "channel": "功法"},
					{"op": "attack_after", "atk_mult": 0.5}]},
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
	"yinsi#1": {"name": "引丝诀·升一", "cost": 1, "reuse": 2,
		"desc": "重置指定一名其他器灵的攻击次数为初始值；复用 2。",
		"ops": [{"op": "aps_reset", "others": true}]},
	"yinsi#2": {"name": "引丝诀·升二", "cost": 1,
		"desc": "指定一名器灵（可含自身）的攻击次数 +1。",
		"ops": [{"op": "aps_mod", "amount": 1}]},
	"luanxin#1": {"name": "乱心蛊·升一", "cost": 1, "reuse": 2,
		"desc": "施加 5 层中毒，变更敌人意图；复用 2。",
		"ops": [{"op": "status", "sid": "zhongdu", "stacks": 5, "abnormal": true},
			{"op": "reroll_intent"}]},
	"luanxin#2": {"name": "乱心蛊·升二", "cost": 1,
		"desc": "施加 5 层中毒，变更敌人意图；若该敌已被标记，眩晕该敌。",
		"ops": [{"op": "status", "sid": "zhongdu", "stacks": 5, "abnormal": true},
			{"op": "reroll_intent"}, {"op": "stun_if_marked"}]},
	"gujian#1": {"name": "蛊箭术·升一", "cost": 1,
		"desc": "对当前敌方造成 3 点功法伤害和施加二层毒，弹射 3（每 5 点威力 +1）次。",
		"ops": [{"op": "dmg_bounce", "value": 3, "bounce": 3, "per_pow_bounce": 5, "channel": "功法",
			"poison_per_hit": 2}]},
	"gujian#2": {"name": "蛊箭术·升二", "cost": 2,
		"desc": "对当前敌人造成 6 点功法伤害，弹射 2（每 5 点威力 +1）次；每命中一名不同敌人，抽一张牌。",
		"ops": [{"op": "dmg_bounce", "value": 6, "bounce": 2, "per_pow_bounce": 5, "channel": "功法",
			"draw_per_new": 1}]},
	"zhaogu#1": {"name": "召蛊术·升一", "cost": 1,
		"desc": "召回自身的所有蛊虫（每只 1 点间接伤害），随后再次随机分配。",
		"ops": [{"op": "bug_recall", "dmg_per_bug": 1, "reassign": true}]},
	"zhaogu#2": {"name": "召蛊术·升二", "cost": 1,
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
		"liejia#1": {"name": "裂甲斩·升一", "cost": 1,
			"desc": "对目标造成 6 点普攻伤害（每 2 点攻击力 +1，每 3 点威力 +1），并对目标及其相邻单位施加 1 层破甲（每 5 点威力 +1 层）。视为普通攻击。获得一张基础版的「刀剑合击」。",
			"ops": [{"op": "dmg_flat", "value": 6, "atk_step": 2, "pow_step": 3, "channel": "普攻"},
				{"op": "pojia_aoe", "stacks": 1, "per_pow": 5},
				{"op": "spawn_spell", "sid": "daojian"}]},
		"liejia#2": {"name": "裂甲斩·升二",
			"desc": "对全体敌人施加破甲（每 5 点威力 +1 层，无基础层）；若某敌人护甲层数高于其将受到的破甲层数，该敌人受到的破甲层数翻倍；对目标造成 6 点普攻伤害（每 2 点攻击力 +1，每 3 点威力 +1），视为普通攻击；获得 1 层强度（每 10 点攻击力 +1 层）。",
			"ops": [{"op": "pojia_all", "per_pow": 5},
				{"op": "dmg_flat", "value": 6, "atk_step": 2, "pow_step": 3, "channel": "普攻"},
				{"op": "self_status_scale", "sid": "qiangdu", "stacks": 1, "atk_step": 10}]},
		"daojian#1": {"name": "刀剑合击·升一", "cost": 1,
			"desc": "造成 4 点功法伤害（每点威力 +1），随后对同一目标进行一次攻击力减半的普通攻击。获得一张基础版的「裂甲斩」。",
			"ops": [{"op": "dmg_flat", "value": 4, "per_pow": 1, "channel": "功法"},
				{"op": "attack_after", "atk_mult": 0.5},
				{"op": "spawn_spell", "sid": "liejia"}]},
		"daojian#2": {"name": "刀剑合击·升二",
			"desc": "刀形态下此卡能量消耗为 0（费用随形态实时显示与结算）。造成 4 点功法伤害（每点威力 +1），随后对同一目标进行一次普通攻击（攻击力全额）。",
			"ops": [{"op": "dmg_flat", "value": 4, "per_pow": 1, "channel": "功法"},
				{"op": "attack_after", "atk_mult": 1.0}]},
}
#endregion

#region 插件（通用七件＋专属件；专属件 excl＝{wid: 效果}——装对应器灵才生效；名占位「插件N」待正名）
const ACCESSORIES := {
	# —— 通用七件 ——
	"p1": {"name": "插件1", "lv": 5, "price": 50,
		"stats": {},
		"fx": {"kind": "pct_fade", "pct": 80, "fade": 20},
		"desc": "战斗开始时，攻击力/防御力/威力提升 80%；每回合结束降低 20%（四回合归零）。"},
	"p2": {"name": "插件2", "lv": 3, "price": 30,
		"stats": {"pow": 15}, "fx": {},
		"desc": "获得 15 点威力。"},
	"p3": {"name": "插件3", "lv": 4, "price": 40,
		"stats": {}, "fx": {"kind": "kill_act"},
		"desc": "一回合一次，敌人死亡后获得一次攻击次数。"},
	"p4": {"name": "插件4", "lv": 1, "price": 10,
		"stats": {"hp": 20}, "fx": {},
		"desc": "耐久度提升 20。"},
	"p5": {"name": "插件5", "lv": 4, "price": 40,
		"stats": {}, "fx": {"kind": "hit_poxian", "stacks": 1, "rounds": 1},
		"desc": "每次攻击造成一层破绽，持续 1 回合。"},
	"p6": {"name": "插件6", "lv": 3, "price": 30,
		"stats": {}, "fx": {"kind": "atk_energy"},
		"desc": "一回合一次，普攻后获得一点能量。"},
	"p7": {"name": "插件7", "lv": 3, "price": 30,
		"stats": {}, "fx": {"kind": "discard_draw"},
		"desc": "若自身的牌被弃置，抽一张牌（按次；回合末冲弃同样触发）。"},
	# —— 数值件按档（2026-10-28 配件轮：补 Lv1/Lv2 空档；占位名同制待正名）——
	"p8": {"name": "插件8", "lv": 1, "price": 10,
		"stats": {"atk": 5}, "fx": {},
		"desc": "攻击力 +5。"},
	"p9": {"name": "插件9", "lv": 1, "price": 10,
		"stats": {"pow": 5}, "fx": {},
		"desc": "威力 +5。"},
	"p10": {"name": "插件10", "lv": 2, "price": 20,
		"stats": {"atk": 10}, "fx": {},
		"desc": "攻击力 +10。"},
	"p11": {"name": "插件11", "lv": 2, "price": 20,
		"stats": {"pow": 10}, "fx": {},
		"desc": "威力 +10。"},
	"p12": {"name": "插件12", "lv": 2, "price": 20,
		"stats": {}, "fx": {"kind": "battle_start_status", "sid": "dikang", "stacks": 1},
		"desc": "战斗开始时，获得一层抵抗。"},
	"p13": {"name": "插件13", "lv": 3, "price": 30,
		"stats": {"atk": 4, "pow": 4}, "fx": {},
		"desc": "攻击力 +4，威力 +4。"},
	"p14": {"name": "插件14", "lv": 4, "price": 40,
		"stats": {"atk": 5, "pow": 5, "hp": 10}, "fx": {},
		"desc": "攻击力 +5，威力 +5，耐久度 +10。"},
	# —— 专属件（天丝1≡青蛊1 同一件双专属）——
	"x_ym_1": {"name": "插件·一", "lv": 3, "price": 30,
		"stats": {"acts": 1}, "fx": {"kind": "atk_poxian", "stacks": 1, "rounds": 2},
		"excl": {"youming": {"kind": "shayi_all"}},
		"desc": "攻击次数 +1。特殊：造成普攻伤害后，敌方获得一层破绽（持续 2 回合）。",
		"excl_desc": {"youming": "杀意改为增加所有伤害。"}},
	"x_ym_2": {"name": "插件·二", "lv": 2, "price": 20,
		"stats": {"pow": 10}, "fx": {},
		"excl": {"youming": {"kind": "spell_cycle", "n": 3}},
		"desc": "威力 +10。",
		"excl_desc": {"youming": "该器灵每累计打出 3 张功法，获得 1 点能量，执行一次自身抽牌。"}},
	"x_ym_3": {"name": "插件·三", "lv": 2, "price": 20,
		"stats": {"atk": -2}, "fx": {"kind": "round_start_shayi", "stacks": 3},
		"excl": {"youming": {"kind": "shayi_keep", "max": 5}},
		"desc": "攻击力 -2。特殊：每回合开始时获得 3 层杀意。",
		"excl_desc": {"youming": "回合结束后可以保留最多 5 层杀意。"}},
	"x_ts_1": {"name": "插件·一", "lv": 3, "price": 30,
		"stats": {"atk": 5, "pow": 5, "hp": -20}, "fx": {},
		"excl": {"tiansi": {"kind": "drain_atk", "amount": 3}, "qinggu": {"kind": "bug_pow"}},
		"desc": "攻击力 +5，威力 +5，生命值 -20。",
		"excl_desc": {"tiansi": "每次普攻后：敌方获得 3 层竭力，自身获得 3 层力量。",
			"qinggu": "身上每有一个蛊虫，获得一点威力加成。"}},
	"x_ts_2": {"name": "插件·二", "lv": 2, "price": 20,
		"stats": {}, "fx": {"kind": "spell_cleanse"},
		"excl": {"tiansi": {"kind": "drain_mhp_per_debuff"}},
		"desc": "特殊：打出自身功法牌后，自身所有减益状态持续时间 -1。",
		"excl_desc": {"tiansi": "普攻后，敌人每有一种减益状态，汲取一点最大生命值。"}},
	"x_ts_3": {"name": "插件·三", "lv": 2, "price": 20,
		"stats": {"pow": 5, "hp": 20}, "fx": {},
		"excl": {"tiansi": {"kind": "atk_bug"}},
		"desc": "威力 +5，生命值 +20。",
		"excl_desc": {"tiansi": "每次普攻后，自身获得一只蛊虫。"}},
	"x_qg_2": {"name": "插件·二", "lv": 3, "price": 30,
		"stats": {}, "fx": {"kind": "round_start_poison", "targets": 2, "stacks": 2},
		"excl": {"qinggu": {"kind": "bug_breed", "per": 3}},
		"desc": "特殊：回合开始时，随机两名敌人获得 2 层毒。",
		"excl_desc": {"qinggu": "回合结束时，自身每有 3 个蛊虫，获得一只蛊虫。"}},
	"x_qg_3": {"name": "插件·三", "lv": 2, "price": 20,
		"stats": {}, "fx": {"kind": "poison_transfer"},
		"excl": {"qinggu": {"kind": "atk_poison_tick"}},
		"desc": "特殊：敌人死亡时，身上剩余的毒层数的一半会转移给随机敌人。",
		"excl_desc": {"qinggu": "每次普通攻击会触发一次敌人的毒。"}},
	"x_jg_1": {"name": "插件·一", "lv": 2, "price": 20,
		"stats": {"def": 3, "hp": 10}, "fx": {},
		"excl": {"jingang": {"kind": "shield_fanzhen", "pct": 50}},
		"desc": "防御力 +3，生命值 +10。",
		"excl_desc": {"jingang": "拥有护盾时，获得 50% 反震。"}},
	"x_jg_2": {"name": "插件·二", "lv": 2, "price": 20,
		"stats": {}, "fx": {"kind": "battle_start_shield_pct", "pct": 25},
		"excl": {"jingang": {"kind": "atk_block", "stacks": 1}},
		"desc": "特殊：战斗开始时，获得 25% 最大生命值的护盾。",
		"excl_desc": {"jingang": "普攻后，随机器灵获得一层格挡。"}},
	"x_jg_3": {"name": "插件·三", "lv": 2, "price": 20,
		"stats": {"def": 4}, "fx": {},
		"excl": {"jingang": {"kind": "def_atk"}},
		"desc": "防御力 +4。",
		"excl_desc": {"jingang": "每有一点防御力，自身攻击力提升一点。"}},
	"x_ly_1": {"name": "插件·一", "lv": 3, "price": 30,
		"stats": {"res": 25, "hp": 50}, "fx": {},
		"excl": {"liangyi": {"kind": "jian_draw"}},
		"desc": "抗性 +25，耐久 +50。",
		"excl_desc": {"liangyi": "每次转为剑形态后，抽一张牌。"}},
	"x_ly_2": {"name": "插件·二", "lv": 2, "price": 20,
		"stats": {"atk": 5}, "fx": {"kind": "atk_heal", "hp": 5},
		"excl": {"liangyi": {"kind": "dao_act", "cap": 9}},
		"desc": "攻击力 +5。特殊：每次普攻后恢复 5 点耐久。",
		"excl_desc": {"liangyi": "每次转为刀形态后，获得一次攻击机会（攻次 +1，可超基础值，硬上限 9）。"}},
	"x_ly_3": {"name": "插件·三", "lv": 4, "price": 40,
		"stats": {"pow": 5}, "fx": {"kind": "first_spell_free", "cut": 1},
		"excl": {"liangyi": {"kind": "form_shayi", "stacks": 1}},
		"desc": "威力 +5。特殊：每回合首次使用的功法能量消耗 −1。",
		"excl_desc": {"liangyi": "每次形态转换后，所有器灵获得 1 层杀意。"}},
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

## 专属器灵名列表（无 excl＝通用件，空表）
static func excl_spirits(aid: String) -> Array:
	var out: Array = []
	for wid in ACCESSORIES.get(aid, {}).get("excl", {}):
		if WEAPONS.has(wid):
			out.push_back(String(WEAPONS[wid]["name"]))
	return out

## 展示描述＝desc＋尾行「专属：器灵名」（2026-10-29 用户裁定：专属不进名字，入描述末行）
static func desc_of(aid: String) -> String:
	var txt := String(ACCESSORIES.get(aid, {}).get("desc", ""))
	var sp := excl_spirits(aid)
	if not sp.is_empty():
		txt += "\n专属：" + "、".join(PackedStringArray(sp))
	return txt

## 专属效果行（浮窗用）：[{spirit: 器灵名, text: 效果文}]
static func excl_effects(aid: String) -> Array:
	var out: Array = []
	var ex: Dictionary = ACCESSORIES.get(aid, {}).get("excl_desc", {})
	for wid in ex:
		var sname := String(wid)
		if WEAPONS.has(wid):
			sname = String(WEAPONS[wid]["name"])
		out.push_back({"spirit": sname, "text": String(ex[wid])})
	return out
#endregion

#region 货架出货率（五档制＝2026-10-29 用户裁定表，含 Lv2 档——旧蓝本实测四档表 1/3/4/5 退役；
# 旧表下 lv2 池 12 件永不出货＝档率/数据错位 bug 由本表修复；行＝系统等级 1~5）
const TIER_LADDER := [1, 2, 3, 4, 5]
const TIER_ODDS := {
	1: [70, 20, 5, 4, 1],
	2: [40, 40, 15, 4, 1],
	3: [30, 30, 30, 5, 5],
	4: [20, 20, 30, 20, 10],
	5: [10, 20, 20, 30, 20],
}

static func tier_pool(lv: int) -> Array:
	var out: Array = []
	for id in ACCESSORIES:
		if int(ACCESSORIES[id]["lv"]) == lv:
			out.push_back(id)
	return out

## 器灵离队（入后备/被替换删除）＝自动卸下全部配件回背包（2026-10-28 用户裁定：
## 配件＝背包资产，离队即回收；功法卡＝档案权益随档走，两制分离）。
## 返回卸下的配件名列表（供提示文案）。
static func unequip_all(run: Dictionary, m: Dictionary) -> Array:
	if not run.has("bag"):
		run["bag"] = []
	var names: Array = []
	var eqs: Array = m.get("equips", [])
	for i in eqs.size():
		var eid := String(eqs[i])
		if not eid.is_empty() and ACCESSORIES.has(eid):
			run["bag"].push_back(eid)
			names.push_back(String(ACCESSORIES[eid]["name"]))
			eqs[i] = ""
			plugin_hp_shift(m, eid, false)   # 血件离队：当前耐久同扣（2026-10-29 裁定）
	return names

static func tier_odds(sys_lv: int) -> Array:
	return TIER_ODDS[clampi(sys_lv, 1, 5)]
#endregion

#region 卡组制常量与公式（2026-10-29 用户再裁：开局＝系统 Lv1：能 3 抽 4；升到偶数级→抽牌 +1、
# 升到奇数级（≥3）→能量上限 +1——即 Lv2＝能3抽5、Lv3＝能4抽5、Lv4＝能4抽6、Lv5＝能5抽6；
# 旧「Lv2 锚＋奇次抽/偶次能」制退役）
const ENERGY_BASE := 3
const DRAW_BASE := 4
const COPIES_PER_SPELL := 2

## 能量上限＝3＋⌊(Lv−1)/2⌋（Lv1/2＝3、Lv3/4＝4、Lv5＝5——升到奇数级时 +1）
static func energy_cap_of(sys_lv: int) -> int:
	return ENERGY_BASE + int(floor(float(maxi(1, sys_lv) - 1) / 2.0))

## 抽牌＝4＋⌊Lv/2⌋（Lv1＝4、Lv2/3＝5、Lv4/5＝6——升到偶数级时 +1）
static func draw_of(sys_lv: int) -> int:
	return DRAW_BASE + int(floor(float(maxi(1, sys_lv)) / 2.0))

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

## 装卸血件耐久联动（2026-10-29 用户裁定）：最大耐久随 weapon_panel 活变，
## 当前耐久同步 ±stats.hp；存活下限 1（不够降 1）、上限＝新 mhp；
## 阵亡（0 血）不动当前耐久（复活只走回复通道，同日裁定）。
## 时序约定：调用方先写/清 equips 再调本函数（mhp_of 按新装备面取）。
static func plugin_hp_shift(m: Dictionary, eid: String, equipping: bool) -> void:
	var dhp := int(ACCESSORIES.get(eid, {}).get("stats", {}).get("hp", 0))
	if dhp == 0 or int(m.get("hp", 0)) <= 0:
		return
	if equipping:
		m["hp"] = clampi(int(m["hp"]) + dhp, 1, mhp_of(m))
	else:
		m["hp"] = clampi(int(m["hp"]) - dhp, 1, mhp_of(m))

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

## 组末整队回血（2026-10-29 用户裁定试运行）：全部器灵（在场＋未上场）回复 50% 最大耐久、
## 上限满血；阵亡（0 血）复活至 50%——回血三通道（后备/金币/奖励位）保留
static func group_heal(run: Dictionary) -> void:
	for arr in [run.get("team", []), run.get("reserve", [])]:
		for m in arr:
			var mhp := mhp_of(m)
			m["hp"] = clampi(int(m.get("hp", 0)) + int(mhp * 0.5), 0, mhp)

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

## 战后耐久写回（战斗屏 team_out → QiRoot 胜利分支调用）；
## 2026-10-29 用户裁定：阵亡者战后自动入未上场池（离场语义全套＝功法随档移除＋配件回包；
## 阵亡不能上场＝器灵页禁则已有；复活只走回复通道——未上场池每场战后回血含阵亡缓复）
static func apply_team_out(run: Dictionary, tout: Array) -> void:
	for rec in tout:
		var m := find_member(run, String(rec.get("id", "")))
		if not m.is_empty():
			m["hp"] = clampi(int(rec.get("hp", mhp_of(m))), 0, mhp_of(m))
	var team: Array = run.get("team", [])
	var moved: Array = []
	for i in range(team.size() - 1, -1, -1):
		if int(team[i].get("hp", 1)) <= 0:
			moved.push_back(team[i])
			team.remove_at(i)
	for m in moved:
		deck_swap(run, String(m["id"]), "")
		unequip_all(run, m)
	(run.get("reserve", []) as Array).append_array(moved)
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
	for arr in [team, run.get("reserve", [])]:
		for m in arr:
			owned[String(m["id"])] = m
	match kind:
		"add_spirit":
			for wid in WEAPONS:
				if not owned.has(wid) and not spirit_locked(run, wid):
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
		"desc": "敌方攻击类伤害优先命中被标记者（无视嘲讽）；跨武器协同锚；可多敌共存。"},
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
	"guchong": {"name": "蛊虫", "glyph": "蛊", "cls": "面板", "color": "b8d98a",
		"desc": "青蛊铃的蛊虫：自身持有每只 +1 威力（插件·丝蛊同源）；藏身敌方时对其施毒 +1 层/只，回合结束回归主人。"},
	"hudun": {"name": "护盾", "glyph": "盾", "cls": "资源", "color": "8ab8d0",
		"desc": "固定值吸收层，受伤先扣盾；回合结束清空。"},
	"gebi": {"name": "格挡", "glyph": "挡", "cls": "资源", "color": "8ad0a8",
		"desc": "免疫下一次受到的伤害（多段只挡一段）。"},
	"dikang": {"name": "抵抗", "glyph": "御", "cls": "资源", "color": "8ad0c8",
		"desc": "免疫下一次受到的负面状态（挡敌方施加）。"},
	"shayi": {"name": "杀意", "glyph": "杀", "cls": "身份", "color": "d04a4a",
		"desc": "功法伤害 +1/层，回合末失去所有层数。"},
	"xuruo": {"name": "虚弱", "glyph": "弱", "cls": "身份", "color": "8a9a58", "debuff": true,
		"desc": "造成伤害 −25%（层＝时长不叠深），回合末层 -1。"},
	"cuiruo": {"name": "脆弱", "glyph": "脆", "cls": "易伤", "color": "e07a6a", "debuff": true,
		"desc": "受到的攻击伤害 +50%，回合末层 -1（不吃功法/间接）。"},
	"jinli": {"name": "劲力", "glyph": "劲", "cls": "资源", "color": "d0b06a",
		"desc": "下一段攻击伤害 +N（数值在层值，用后即清）。"},
	"xiufu": {"name": "修复", "glyph": "修", "cls": "资源", "color": "8ad0a8",
		"desc": "回合结束回复等于层数的耐久，层 -1。"},
	"fengmang": {"name": "锋芒", "glyph": "锋", "cls": "面板", "color": "d0b06a",
		"desc": "造成的直接伤害 +1/层（普攻/功法，不含间接），无持续时间（暂名待正名）。"},
	"renxing": {"name": "韧性", "glyph": "韧", "cls": "面板", "color": "6a9ad0",
		"desc": "受到的直接伤害 -1/层（普攻/功法，不含间接；保底 1），无持续时间（暂名待正名）。"},
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

#region 敌方（敌方设计 v0.2：G1 三场；伤害三型＝攻击伤（过我方防御）／功法伤（无视防御）／毒（间接）；
## 敌方护盾＝撑过我方回合、于该敌下次行动开始才清；行动池数值吃属性缩放（普攻吃攻击×倍率、功法吃 value＋威力））
const ENEMY_BASE := {
	"zhanshi": {
		"name": "刀客", "seal": "武",
		"panel": {"hp": 92, "atk": 15, "def": 8, "res": 0, "pow": 0, "acts": 1},
		"passive": {"id": "zhan_yi", "name": "战意", "hook": "round_start", "sid": "liliang", "stacks": 1,
			"desc": "每回合开始获得 1 层力量。"},
		"actions": [
			{"id": "huiji", "name": "挥击", "kind": "attack", "channel": "普攻", "mult": 1.0,
				"tip": "挥击：攻击伤害（过我方防御），100% 攻击。"},
			{"id": "mengji", "name": "猛击", "kind": "attack", "channel": "普攻", "mult": 1.4, "per_pow": 1, "self_stun": true,
				"tip": "猛击：攻击伤害（过我方防御），140% 攻击＋每点威力 +1；结算后眩晕自身（下回合无法行动）。"},
			{"id": "xushi", "name": "蓄势", "kind": "buff",
				"side": [{"op": "self_buff", "sid": "hudun", "stacks": 1, "value": 8},
					{"op": "self_buff", "sid": "qiangdu", "stacks": 1}],
				"tip": "蓄势：获得 8 点护盾与 1 层强度。"},
		],
	},
	"sheshou": {
		"name": "猎手", "seal": "箭",
		"panel": {"hp": 49, "atk": 12, "def": 6, "res": 0, "pow": 6, "acts": 1},
		"passive": {"id": "chuan_jia", "name": "穿甲", "hook": "on_hit", "sid": "pojia", "stacks": 1, "abnormal": false,
			"desc": "造成伤害后，目标获得 1 层破甲。"},
		"actions": [
			{"id": "sheji", "name": "射击", "kind": "attack", "channel": "普攻", "mult": 1.0,
				"tip": "射击：攻击伤害（过我方防御），100% 攻击。"},
			{"id": "miaozhun", "name": "瞄准", "kind": "buff", "cd": 3,
				"side": [{"op": "mark_ally", "poxian": 1, "rounds": 2}],
				"tip": "瞄准（冷却 3 回合）：标记一件我方器灵并施加 1 层破绽（持续 2 回合）；敌方攻击优先集火被标记者（无视嘲讽）。"},
			{"id": "lianzhu", "name": "连珠", "kind": "attack", "channel": "普攻", "mult": 0.6, "hits_base": 2, "hits_pow_step": 6,
				"tip": "连珠：攻击伤害（过我方防御），2 段 60% 攻击，每 6 点威力 +1 段。"},
		],
	},
	"fuzhu": {
		"name": "巫祝", "seal": "祝",
		"panel": {"hp": 45, "atk": 6, "def": 4, "res": 0, "pow": 12, "acts": 1},
		"passive": {"id": "zhu_dao", "name": "祝祷", "hook": "round_start_adj_shield", "value": 5, "pow_step": 4,
			"desc": "每回合开始，相邻友军获得 5（每 4 点威力 +1）点护盾。"},
		"actions": [
			{"id": "ningshen", "name": "凝神", "kind": "buff",
				"side": [{"op": "self_buff", "sid": "qiangdu", "stacks": 2}],
				"tip": "凝神：自身获得 2 层强度。"},
			{"id": "fengxue_zhou", "name": "封穴咒", "kind": "buff",
				"side": [{"op": "fengxue_random", "stacks": 2, "rounds": 2}],
				"tip": "封穴咒：随机一件我方器灵获得 2 层封穴（受到的功法伤害 +1/层），持续 2 回合。"},
			{"id": "shigu", "name": "蚀骨", "kind": "attack", "channel": "功法", "value": 4, "pow_step": 2,
				"tip": "蚀骨：功法伤害（无视我方防御），4＋每 2 点威力 +1。"},
		],
	},
	"dun": {
		"name": "力士", "seal": "岩",
		"panel": {"hp": 130, "atk": 11, "def": 9, "res": 0, "pow": 0, "acts": 1},
		"passive": {"id": "si_zhou", "name": "死咒", "hook": "on_death",
			"desc": "死亡时，我方攻击力最高的器灵获得 3 层虚弱。"},
		"actions": [
			{"id": "bilei", "name": "壁垒", "kind": "buff",
				"side": [{"op": "self_buff", "sid": "hudun", "stacks": 1, "value": 8},
					{"op": "self_buff", "sid": "chaofeng", "stacks": 1, "rounds": 1}],
				"tip": "壁垒：获得 8 点护盾与嘲讽（1 回合）。"},
			{"id": "tiebizhen", "name": "铁壁阵", "kind": "buff",
				"side": [{"op": "adj_armor", "stacks": 2}],
				"tip": "铁壁阵：自身与相邻单位各获得 2 层护甲。"},
			{"id": "chuiji", "name": "挥击", "kind": "attack", "channel": "普攻", "mult": 1.0,
				"tip": "挥击：攻击伤害（过我方防御），100% 攻击。"},
		],
	},
	"boss": {
		"name": "两仪剑主", "seal": "仪",
		"panel": {"hp": 210, "atk": 20, "def": 6, "res": 0, "pow": 16, "acts": 1},
		"passive": {"id": "yi_dao_yi_jian", "name": "亦刀亦剑", "hook": "form",
			"desc": "奇数回合刀形态（刀系行动池），偶数回合剑形态（剑系行动池）。"},
		"actions": [
			{"id": "zhantie", "name": "斩铁", "kind": "attack", "channel": "普攻", "mult": 1.2, "form": "dao",
				"tip": "斩铁：攻击伤害（过我方防御），120% 攻击。"},
			{"id": "yuzhao", "name": "御召", "kind": "buff", "cd": 3,
				"side": [{"op": "summon", "summons": ["daonu", "jianpu"]}],
				"tip": "御召（冷却 3 回合）：召唤刀奴与剑仆（已存活者不重复召唤；召唤物落地回合不行动）。"},
			{"id": "jiangang", "name": "剑罡", "kind": "attack", "channel": "功法", "value": 8, "per_pow": 1, "form": "jian",
				"tip": "剑罡：功法伤害（无视我方防御），8＋每点威力 +1。"},
		],
	},
	"daonu": {
		"name": "刀奴", "seal": "刃",
		"panel": {"hp": 18, "atk": 0, "def": 0, "res": 0, "pow": 0, "acts": 1},
		"passive": {},
		"actions": [
			{"id": "shouren", "name": "授刃", "kind": "buff",
				"side": [{"op": "ally_buff", "sid": "liliang", "stacks": 1}],
				"tip": "授刃：随机一名其他友军获得 1 层力量。"},
		],
	},
	"jianpu": {
		"name": "剑仆", "seal": "锋",
		"panel": {"hp": 18, "atk": 0, "def": 0, "res": 0, "pow": 8, "acts": 1},
		"passive": {},
		"actions": [
			{"id": "shoufeng", "name": "授锋", "kind": "buff",
				"side": [{"op": "ally_buff", "sid": "qiangdu", "stacks": 1}],
				"tip": "授锋：随机一名其他友军获得 1 层强度。"},
		],
	},
}

const ENEMY_THEMES := ["黑风", "野狼", "双锋", "荒骨", "血衣", "两仪殿"]

## 组缩放（2026-10-28 用户裁定：G2-G6 与 G1 同阵容、仅属性变化；全暂定）
const GROUP_SCALE := {
	"hp": [1.0, 1.25, 1.5, 1.8, 2.15, 2.55],
	"atk": [0, 2, 4, 6, 8, 10],
	"def": [0, 1, 2, 3, 4, 5],
	"pow": [0, 2, 4, 6, 8, 10],
}

static var ENEMIES := _build_enemies()

static func _build_enemies() -> Dictionary:
	var out := {}
	for arch in ENEMY_BASE:
		var spec: Dictionary = ENEMY_BASE[arch]
		var p: Dictionary = spec["panel"]
		for g in 6:
			var eid := "%s_g%d" % [arch, g]
			var np := {"hp": int(round(float(p["hp"]) * float(GROUP_SCALE["hp"][g]))),
				"atk": int(p["atk"]) + int(GROUP_SCALE["atk"][g]),
				"def": int(p["def"]) + int(GROUP_SCALE["def"][g]),
				"res": 0, "pow": int(p.get("pow", 0)) + int(GROUP_SCALE["pow"][g]),
				"acts": int(p.get("acts", 1))}
			var nm := ""
			if arch == "boss":
				nm = "两仪剑主" if g < 5 else "两仪剑主·极"
			else:
				nm = String(ENEMY_THEMES[g]) + String(spec["name"])
			out[eid] = {"name": nm, "seal": String(spec["seal"]), "panel": np,
				"passive": (spec["passive"] as Dictionary).duplicate(true),
				"actions": (spec["actions"] as Array).duplicate(true)}
	out["daonu"] = {"name": "刀奴", "seal": "刃",
		"panel": {"hp": 18, "atk": 0, "def": 0, "res": 0, "pow": 0, "acts": 1},
		"passive": {},
		"actions": [{"id": "shouren", "name": "授刃", "kind": "buff",
			"side": [{"op": "ally_buff", "sid": "liliang", "stacks": 1}],
			"tip": "授刃：随机一名其他友军获得 1 层力量。"}]}
	out["jianpu"] = {"name": "剑仆", "seal": "锋",
		"panel": {"hp": 18, "atk": 0, "def": 0, "res": 0, "pow": 0, "acts": 1},
		"passive": {},
		"actions": [{"id": "shoufeng", "name": "授锋", "kind": "buff",
			"side": [{"op": "ally_buff", "sid": "qiangdu", "stacks": 1}],
			"tip": "授锋：随机一名其他友军获得 1 层强度。"}]}
	return out

const GROUPS := [
	{"name": "第 1 组 · 黑风寨", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g0", "sheshou_g0"], "reward": 30},
		{"label": "第 2 场", "enemies": [["zhanshi_g0", "zhanshi_g0"], ["sheshou_g0"], ["fuzhu_g0"]], "reward": 40},
		{"label": "第 3 场", "enemies": ["boss_g0", "dun_g0", "fuzhu_g0"], "reward": 60, "boss": true, "grant": "liangyi"},
	]},
	{"name": "第 2 组 · 野狼帮", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g1", "sheshou_g1"], "reward": 40},
		{"label": "第 2 场", "enemies": [["zhanshi_g1", "zhanshi_g1"], ["sheshou_g1"], ["fuzhu_g1"]], "reward": 50},
		{"label": "第 3 场", "enemies": ["boss_g1", "dun_g1", "fuzhu_g1"], "reward": 70, "boss": true},
	]},
	{"name": "第 3 组 · 双锋阁", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g2", "sheshou_g2"], "reward": 50},
		{"label": "第 2 场", "enemies": [["zhanshi_g2", "zhanshi_g2"], ["sheshou_g2"], ["fuzhu_g2"]], "reward": 60},
		{"label": "第 3 场", "enemies": ["boss_g2", "dun_g2", "fuzhu_g2"], "reward": 80, "boss": true},
	]},
	{"name": "第 4 组 · 荒骨盟", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g3", "sheshou_g3"], "reward": 60},
		{"label": "第 2 场", "enemies": [["zhanshi_g3", "zhanshi_g3"], ["sheshou_g3"], ["fuzhu_g3"]], "reward": 70},
		{"label": "第 3 场", "enemies": ["boss_g3", "dun_g3", "fuzhu_g3"], "reward": 90, "boss": true},
	]},
	{"name": "第 5 组 · 血衣楼", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g4", "sheshou_g4"], "reward": 70},
		{"label": "第 2 场", "enemies": [["zhanshi_g4", "zhanshi_g4"], ["sheshou_g4"], ["fuzhu_g4"]], "reward": 80},
		{"label": "第 3 场", "enemies": ["boss_g4", "dun_g4", "fuzhu_g4"], "reward": 100, "boss": true},
	]},
	{"name": "第 6 组 · 两仪殿", "fights": [
		{"label": "第 1 场", "enemies": ["zhanshi_g5", "sheshou_g5"], "reward": 80},
		{"label": "第 2 场", "enemies": [["zhanshi_g5", "zhanshi_g5"], ["sheshou_g5"], ["fuzhu_g5"]], "reward": 90},
		{"label": "第 3 场", "enemies": ["boss_g5", "dun_g5", "fuzhu_g5"], "reward": 110, "boss": true},
	]},
]

## 两仪解锁制（敌方设计 v0.1 §五）：锁定器灵未解锁不进「新增器灵」池
const LOCKED_UNTIL_UNLOCK := ["liangyi"]

static func spirit_locked(run: Dictionary, wid: String) -> bool:
	return wid in LOCKED_UNTIL_UNLOCK and not (run.get("unlocks", []) as Array).has(wid)

## Boss 战利品直授（QiRoot 胜利分支调用）：入后备（满员超额占位）＋本局解锁＋跨局 meta 解锁
static func grant_spirit(run: Dictionary, wid: String, meta: Dictionary) -> void:
	if not WEAPONS.has(wid):
		return
	var m := {"id": wid, "equips": ["", "", ""], "pdir": 0}
	m["hp"] = mhp_of(m)
	(run.get("reserve", []) as Array).push_back(m)
	var unl: Array = run.get("unlocks", [])
	if not unl.has(wid):
		unl.push_back(wid)
	run["unlocks"] = unl
	var munl: Array = meta.get("unlocks", [])
	if not munl.has(wid):
		munl.push_back(wid)
	meta["unlocks"] = munl
#endregion

## 开局固定队（试玩切片＝用户亲设幽冥剑＋天丝手套；pdir＝被动升级方向 0=未选）
const START_TEAM := [{"id": "youming", "equips": ["", "", ""], "pdir": 0},
	{"id": "tiansi", "equips": ["", "", ""], "pdir": 0}]

## 默认 run（QiRoot/战斗屏/备战舱三处同源）；sys_lv=1 开局＝能量 3／抽牌 4
static func default_run() -> Dictionary:
	var run := {"copper": 130, "bag": [],
		"team": START_TEAM.duplicate(true),
		"reserve": [], "unlocks": [],
		"sys_lv": 1, "group": 0, "fight": 0, "seed": 20261026}   # 开局 Lv1（2026-10-29 用户再裁）
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
	for eid0 in f["enemies"]:
		var ids0: Array = eid0 if eid0 is Array else [eid0]   # 块队列制：标签按块顶计
		if not ids0.is_empty():
			names.push_back(ENEMIES[String(ids0[0])]["name"])
	return "%s · %s—— %s" % [g["name"], f["label"], " ＋ ".join(PackedStringArray(names))]

## 该场是否组末强敌（Boss 保证位＝奖励固定占「新增器灵·已升级」一位）
static func is_boss_fight(group_i: int, fight_i: int) -> bool:
	if group_i >= GROUPS.size():
		return false
	var fights: Array = GROUPS[group_i]["fights"]
	return bool(fights[mini(fight_i, fights.size() - 1)].get("boss", fight_i >= fights.size() - 1))
#endregion
