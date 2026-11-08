## VC 制数据层（2026-10-31 立档，复刻阶段命名、换皮时整体改名）。
## 模型＝单主角＋连击阶梯（内功「连击堆叠」）＋血池波次遭遇（去目标制）；
## 卡＝四色制：红武器（攻击）／蓝道具（防御）／黄道具（特殊）／紫道具（法力）；
## **2026-11-01 数值同步轮（用户批「开始」）：卡牌效果/费用全量换官方 wiki 真值**
## （vampire.survivors.wiki/w/Crawlers:Cards）＋敌方血量换一手 EnemyDatabase 真值；
## 敌方攻击数值仍暂定（一手表无行为定义，意图运行时生成）。
## 机制词占位口径（效果后批）：Crit＝15% ×2（概率/倍率暂定）；击退/优先攻击者/抹除行数＝记录待做；
## 缴械/冰冻＝该敌下次合并打击跳过；灼烧＝下回合末全体结算；局外轴卡（经验/金币/幸运/复活/弹数/范围/
## 角色触发/敌强）只录数据不进任何初始牌组，效果随局外批实装。
extends RefCounted

#region 内功（对应原作遗物系统；2026-10-31 用户裁定：先做战斗相关，场外升级后批）
## 首件「连击堆叠」＝连击规则本体（规格 2026-10-31 三源闭环＋用户口述裁定）：
## 逐档 +1 连续阶梯／链上第 n 张 ×n／断连重算（断的那张 ×1 结算并成新链第一张）。
const NEIGONG := {
	"combo_stack": {
		"name": "连击堆叠",
		"desc": "装备后连击规则生效（2026-11-07 教程轮：宝物获得——开局不带；"
			+ "2026-11-08 状态制改版）：每打出一张牌连击 +1、按新连击数线性放大；"
			+ "硬换剑型（短/长/巨互跳）＝断链重 1；变招照 +1 且不锁型；无型牌不动链；"
			+ "回合开始连击清零、剑型归无。",
	},
}

## 剑型四类（2026-11-08 状态制改版，用户裁）：卡表 stance 字段值域——
## short 短剑（轻快连击向·蓝）/ long 长剑（控场架式向·墨）/ great 巨剑（重破防守势向·红）/
## flex 变招（稀有标记·金：照常 +1 且不锁型，下一张任何型接链）；效果牌未标型＝""（不动链，后续单项设计补标）
const FORMS := {
	"short": {"cn": "短剑", "color": "blue"},
	"long": {"cn": "长剑", "color": "ink"},
	"great": {"cn": "巨剑", "color": "red"},
	"flex": {"cn": "变招", "color": "gold"},
}

static func has_neigong(run: Dictionary, nid: String) -> bool:
	return (run.get("neigong", []) as Array).has(nid)
#endregion

#region 卡（2026-11-03 用户裁定：普攻/催破合并为单一「攻击」卡种；新手开局＝直刺孤张）。
## 卡种＝attack(攻击)/effect(奇窍·耗气)/defense(护体·耗气)。
## —— 气·式·连击（2026-11-06 终裁）——
## 气：上限＝基础 2，局外（run.qi_max）／局内（qi_max 效果）可成长（护栏 6）；
##     回合开始重置到当前上限（重置在前、抽牌在后；洗牌换气**暂缓撤下**——2026-11-07 用户令）；
##     不再有「打攻击 +1 气」。cost＝气费（need 卡每耗 1 层式抵 1 气）。
## 〔2026-11-08 状态制改版〕式＝当前剑型状态（short/long/great/flex），不攒不耗；
## 旧「式弹药库（gain 得式/need 耗式抵气/跨回合保存/上限 9）」全链退役——
## gain/need/pip 卡表字段留档不消费（文本轮清）。
## 连击（涨＝每张 +1／断＝硬换剑型重 1／桥＝变招照涨不锁型／不动＝无型牌／清＝回合开始
## ＋型归无）：**先涨后算**——本张按新连击数线性 ×N。
## ops 同引擎指令集（dmg 加 hits 多段）。
const KEYWORDS := {
	"crit": {"name": "暴击", "desc": "有概率造成多倍伤害。"},   # 2026-11-07 用户令：词条文案不带具体数值
}

const CARDS := {
	# —— 攻击卡 targeting 字段（2026-11-07 逆向重排，对应原版武器配 Targeting 组件）——
	# right_left＝右→左逐列顺发（Knife）；front_row＋pierce_type 0＝前排每敌一击（Death Spiral/
	# Axe 族）；single＝锁最右首列（单体）。pierce_type 0/1/2＝OncePerEnemy/MultiHit/MultiSwitch。
	# 下斩＝鞭位（2026-11-07 用户映射：Whip→下斩；「全体＝前排」口径）
	"hengpi": {"name": "下斩", "cost": 0, "color": "purple", "kind": "attack",
		"stance": "great", "gain": "斩", "pip": "斩", "targeting": "front_row",
		"pierce_type": 0,
		"desc": "对全体敌人造成 5 点伤害；得 1 层「斩」式。",
		"ops": [{"op": "dmg", "value": 5, "hits": 12}]},
	# 连环刺＝匕首制·顺发（2026-11-08 更名「直刺→连环刺」；数值轮：5 刺×8 点＝卡面
	# 总伤 40——蓝本刀页「Deal 40 damage」5 投掷物×8 伤同值）：**左→右**逐列点名
	# （首目标＝最左，与蓝本那把刀的右→左刚好相反——用户裁）；死者出列顺位接
	# （顶上来的继续挨打）、环绕、排清才打后排；伤害封顶剩余血量、多余浪费（蓝本无溢出）。
	"zhici": {"name": "连环刺", "cost": 0, "color": "purple", "kind": "attack",
		"stance": "short", "gain": "刺", "pip": "刺", "targeting": "left_right",
		"desc": "造成 40 点伤害。暴击。",
		"kw": ["crit"],
		"ops": [{"op": "dmg", "value": 8, "hits": 5, "crit": true}]},
	"shangliao": {"name": "上撩", "cost": 0, "color": "purple", "kind": "attack",
		"stance": "long", "gain": "撩", "pip": "撩", "targeting": "single",
		"desc": "对最前敌人造成 10 点伤害；得 1 层「撩」式。",
		"ops": [{"op": "dmg", "value": 10, "hits": 1}]},
	# —— 攻击（耗式型·连击位：每耗 1 层式＝气费 −1＋连击 +1）——
	"cuipo_pi": {"name": "劈空斩", "cost": 1, "color": "red", "kind": "attack",
		"stance": "great", "need": {"stance": "great", "n": 1}, "pip": "斩",
		"targeting": "front_row", "pierce_type": 0,
		"desc": "消耗至多 1 层「斩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对前排所有敌人造成 15 点伤害，按新连击数放大；得 1 层「斩」式。",
		"ops": [{"op": "dmg", "value": 15, "hits": 12}]},
	"cuipo_ci": {"name": "连珠刺", "cost": 1, "color": "red", "kind": "attack",
		"stance": "short", "need": {"stance": "short", "n": 1}, "pip": "刺",
		"targeting": "single",
		"desc": "消耗至多 1 层「刺」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对最前敌人造成 8 点伤害 ×2 段，按新连击数放大；得 1 层「刺」式。",
		"ops": [{"op": "dmg", "value": 8, "hits": 2}]},
	"cuipo_liao": {"name": "撩月斩", "cost": 1, "color": "red", "kind": "attack",
		"stance": "long", "need": {"stance": "long", "n": 1}, "pip": "撩",
		"targeting": "single",
		"desc": "消耗至多 1 层「撩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对最前敌人造成 25 点伤害，按新连击数放大；得 1 层「撩」式。",
		"ops": [{"op": "dmg", "value": 25, "hits": 1}]},
	"cuipo_pi_heavy": {"name": "重劈·山崩", "cost": 2, "color": "red", "kind": "attack",
		"stance": "great", "need": {"stance": "great", "n": 2}, "pip": "斩×2",
		"targeting": "front_row", "pierce_type": 0,
		"desc": "消耗至多 2 层「斩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对前排所有敌人造成 28 点伤害，按新连击数放大；得 1 层「斩」式。",
		"ops": [{"op": "dmg", "value": 28, "hits": 12}]},
	"cuipo_liao_heavy": {"name": "重撩·断岳", "cost": 2, "color": "red", "kind": "attack",
		"stance": "long", "need": {"stance": "long", "n": 2}, "pip": "撩×2",
		"targeting": "single",
		"desc": "消耗至多 2 层「撩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对最前敌人造成 45 点伤害，按新连击数放大；得 1 层「撩」式。",
		"ops": [{"op": "dmg", "value": 45, "hits": 1}]},
	# —— 三剑（2026-11-07 用户映射：Bone/圣经/Garlic 位→弹射/游走/回身）——
	# 逍遥剑＝骨头位（Bone 弹射投射）：首发单体，段尽后按概率弹跳追击（衰减链）
	"xiaoyao_jian": {"name": "逍遥剑", "cost": 1, "color": "red", "kind": "attack",
		"stance": "long", "need": {"stance": "long", "n": 1}, "gain": "斩", "pip": "撩",
		"targeting": "single",
		"bouncy": {"base": 0.5, "decay": 0.15, "max": 3},
		"desc": "消耗至多 1 层「撩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对最前敌人造成 12 点伤害，按新连击数放大，有几率弹跳追击；得 1 层「斩」式。",
		"ops": [{"op": "dmg", "value": 12, "hits": 1}]},
	# 游龙剑＝圣经位（King Bible 弧形发射→游走多目标近似：random 列袋不重复；数值暂定可调）
	"youlong_jian": {"name": "游龙剑", "cost": 1, "color": "red", "kind": "attack",
		"stance": "short", "need": {"stance": "short", "n": 1}, "gain": "撩", "pip": "刺",
		"targeting": "random",
		"desc": "消耗至多 1 层「刺」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。游走出击，对随机敌人造成 9 点伤害 ×2 段，按新连击数放大；得 1 层「撩」式。",
		"ops": [{"op": "dmg", "value": 9, "hits": 2}]},
	# 回身剑＝大蒜位（Garlic 真值：前排 10 伤＋缴械——「描述也一样」实证）
	"huishen_jian": {"name": "回身剑", "cost": 1, "color": "red", "kind": "attack",
		"stance": "great", "need": {"stance": "great", "n": 1}, "gain": "刺", "pip": "斩",
		"targeting": "front_row", "pierce_type": 0,
		"desc": "消耗至多 1 层「斩」式（无式也可打出）。每耗 1 层：气费 −1、连击 +1。对前排所有敌人造成 10 点伤害，按新连击数放大；缴械（下次攻击跳过）；得 1 层「刺」式。",
		"ops": [{"op": "dmg", "value": 10, "hits": 12}, {"op": "disarm", "rounds": 1}]},
	# —— 黄卡·属性三型（2026-11-07 属性轮；wiki 真值＋原版持续制实证）——
	# duration: "dungeon"＝本局（打出入 run.dungeon_stats，跨场保留）／"encounter"＝本场（battle 层，
	# 随实例销毁清零）；exhaust＝Destroy 自毁型（wiki 明标：打出即效果、卡销毁不回牌堆）。
	# 属性轴：might/greed/luck/curse（pct 100 基）、amount/deal_count/max_hp/revival（计数 0 基）。
	"spinach": {"name": "菠菜", "cost": 1, "color": "yellow", "kind": "stat",
		"desc": "本局威力 +10%（伤害提升）。",
		"ops": [{"op": "stat", "axis": "might", "amount": 10, "duration": "dungeon"}]},
	"sprig_spinach": {"name": "嫩菠菜", "cost": 2, "color": "yellow", "kind": "stat",
		"desc": "本局威力 +20%。",
		"ops": [{"op": "stat", "axis": "might", "amount": 20, "duration": "dungeon"}]},
	"candle": {"name": "蜡烛", "cost": 0, "color": "yellow", "kind": "stat",
		"desc": "本局范围 +5%。",
		"ops": [{"op": "stat", "axis": "area", "amount": 5, "duration": "dungeon"}]},
	"candella": {"name": "烛光", "cost": 1, "color": "yellow", "kind": "stat",
		"desc": "本局范围 +10%。",
		"ops": [{"op": "stat", "axis": "area", "amount": 10, "duration": "dungeon"}]},
	"candelabrador": {"name": "烛台", "cost": 2, "color": "yellow", "kind": "stat",
		"desc": "本局范围 +15%。",
		"ops": [{"op": "stat", "axis": "area", "amount": 15, "duration": "dungeon"}]},
	"hollow_heart": {"name": "空心之心", "cost": 1, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "血上限 +3（Destroy：打出自毁）。立即生效。",
		"ops": [{"op": "stat", "axis": "max_hp", "amount": 3, "duration": "encounter"}]},
	"forever_heart": {"name": "永恒之心", "cost": 2, "color": "yellow", "kind": "stat",
		"desc": "本局血上限 +1。",
		"ops": [{"op": "stat", "axis": "max_hp", "amount": 1, "duration": "dungeon"}]},
	"crown": {"name": "王冠", "cost": 1, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "本局成长 +15%（经验获取提升）。Destroy。",
		"ops": [{"op": "stat", "axis": "growth", "amount": 15, "duration": "dungeon"}]},
	"crystal_crown": {"name": "水晶王冠", "cost": 2, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "本局成长 +20%。Destroy。",
		"ops": [{"op": "stat", "axis": "growth", "amount": 20, "duration": "dungeon"}]},
	"stone_mask": {"name": "石面具", "cost": 1, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "本局贪婪 +10%（金币获取提升）。Destroy。",
		"ops": [{"op": "stat", "axis": "greed", "amount": 10, "duration": "dungeon"}]},
	"clover": {"name": "三叶草", "cost": 2, "color": "yellow", "kind": "stat",
		"desc": "本局幸运 +10%（暴击率提升）。",
		"ops": [{"op": "stat", "axis": "luck", "amount": 10, "duration": "dungeon"}]},
	"skull_omaniac": {"name": "骷髅咒", "cost": 0, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "本局诅咒 +5%（敌人更强，金币与经验更多）。Destroy。",
		"ops": [{"op": "stat", "axis": "curse", "amount": 5, "duration": "dungeon"}]},
	"duplicator": {"name": "分身器", "cost": 1, "color": "yellow", "kind": "stat",
		"desc": "本局弹数 +1（攻击段数增加）。",
		"ops": [{"op": "stat", "axis": "amount", "amount": 1, "duration": "dungeon"}]},
	"du_duplicator": {"name": "双重分身器", "cost": 2, "color": "yellow", "kind": "stat",
		"desc": "本局弹数 +2。",
		"ops": [{"op": "stat", "axis": "amount", "amount": 2, "duration": "dungeon"}]},
	"bracer": {"name": "护腕", "cost": 0, "color": "yellow", "kind": "stat",
		"desc": "本局发牌 +1（每回合多抽 1 张）。",
		"ops": [{"op": "stat", "axis": "deal_count", "amount": 1, "duration": "dungeon"}]},
	"spellbinder": {"name": "咒术书", "cost": 0, "color": "yellow", "kind": "stat",
		"desc": "本局持续 +5%（时长轴——机制留位）。",
		"ops": [{"op": "stat", "axis": "duration", "amount": 5, "duration": "dungeon"}]},
	"tirajisu": {"name": "提拉米苏", "cost": 2, "color": "yellow", "kind": "stat",
		"exhaust": true,
		"desc": "获得一次复活（Destroy）。倒下时原地半血复活。",
		"ops": [{"op": "stat", "axis": "revival", "amount": 1, "duration": "encounter"}]},
	"attractorb": {"name": "吸引球", "cost": 1, "color": "yellow", "kind": "stat",
		"desc": "抽 1 张牌。",
		"ops": [{"op": "draw", "count": 1}]},
	"friendship_amulet": {"name": "友谊护符", "cost": 1, "color": "yellow", "kind": "stat",
		"desc": "本局连击基础 +1（催破起始连击更高）。",
		"ops": [{"op": "stat", "axis": "combo_base", "amount": 1, "duration": "dungeon"}]},
	# —— 奇窍（黄·耗气：效果 ×当前连击先结算，结算后连击 −气费）——
	"ningshen": {"name": "凝神诀", "cost": 2, "color": "yellow", "kind": "effect",
		"desc": "耗 2 气。抽 1 张牌，按当前连击数放大；连击 −2。",
		"ops": [{"op": "draw", "count": 1}]},
	"juqi": {"name": "聚气式", "cost": 1, "color": "yellow", "kind": "effect",
		"desc": "耗 1 气。本回合造成的伤害 +10%；连击 −1。",
		"ops": [{"op": "might", "pct": 10}]},
	"yinqi_jue": {"name": "引气诀", "cost": 3, "color": "yellow", "kind": "effect",
		"desc": "耗 3 气。抽 2 张牌，按当前连击数放大；连击 −3。",
		"ops": [{"op": "draw", "count": 2}]},
	# —— 护体（蓝·耗气：效果 ×当前连击先结算，结算后连击 −气费）——
	"tiegu": {"name": "铁骨", "cost": 1, "color": "blue", "kind": "defense",
		"desc": "耗 1 气。获得 2 护甲（本回合），按当前连击数放大；连击 −1。",
		"ops": [{"op": "armor", "amount": 2}]},
	"jinzzhong": {"name": "金钟罩", "cost": 3, "color": "blue", "kind": "defense",
		"desc": "耗 3 气。获得 5 护甲（本回合），按当前连击数放大；连击 −3。",
		"ops": [{"op": "armor", "amount": 5}]},
}
#endregion

#region 进化配方（一手全量；materials 按卡 id；本批只录数据不触发——
## 触发条件＝配方齐＋基础卡空宝石孔＋进化触发点，随宝石批后做）
const EVOLUTIONS := [
	{"result": "bloody_tear", "name": "血之泪", "cost": 2, "materials": ["whip", "hollow_heart"]},
	{"result": "soul_eater", "name": "噬魂者", "cost": 3, "materials": ["garlic", "pummarola"]},
	{"result": "thousand_edge", "name": "千刃", "cost": 3, "materials": ["knife", "bracer"]},
	{"result": "hellfire", "name": "地狱火", "cost": 3, "materials": ["fire_wand", "spinach"]},
	{"result": "holy_wand", "name": "圣杖", "cost": 2, "materials": ["magic_wand", "empty_tome"]},
	{"result": "unholy_vespers", "name": "邪恶晚祷", "cost": 2, "materials": ["king_bible", "spellbinder"]},
	{"result": "no_future", "name": "无未来", "cost": 3, "materials": ["runetracer", "armor"]},
	{"result": "la_borra", "name": "泥沼", "cost": 4, "materials": ["santa_water", "attractorb"]},
	{"result": "gorgeous_moon", "name": "华丽之月", "cost": 1, "materials": ["pentagram", "crown"]},
	{"result": "heaven_sword", "name": "天堂之剑", "cost": 3, "materials": ["cross", "clover"]},
	# —— 以下配方的材料卡不在已实装集内（随卡池扩充批实装）——
	{"result": "valkyrie_turner", "name": "女武神", "cost": 2, "materials": ["shadow_pinion", "wings"]},
	{"result": "vicious_hunger", "name": "贪婪之饥", "cost": 2, "materials": ["gatti_amari", "stone_mask"]},
	{"result": "death_spiral", "name": "死亡螺旋", "cost": 3, "materials": ["axe", "candelabrador"]},
	{"result": "phieraggi", "name": "菲拉吉", "cost": 4, "materials": ["phiera_der_tuphello", "eight_the_sparrow", "tirajisu"]},
	{"result": "thunder_loop", "name": "雷电环", "cost": 4, "materials": ["lightning_ring", "duplicator"]},
	{"result": "vandalier", "name": "破坏者", "cost": 5, "materials": ["peachone", "ebony_wings"]},
	{"result": "mannajja", "name": "曼纳加", "cost": 5, "materials": ["song_of_mana", "skull_omaniac"]},
	# —— 待查（一手有成品卡但配方表未录，随考古补）——
	{"result": "fuwalafuwaloo", "name": "富瓦拉富瓦卢", "cost": 4, "materials": []},
	{"result": "infinite_corridor", "name": "无限回廊", "cost": 6, "materials": []},
]
#endregion

#region 敌人（2026-11-01 敌人页真值轮：hp/max hit 全实证；攻击值＝Max hit 真值——
## 此前 4~12 攻暂定全偏高，真值蝙蝠 1/泥人 1/骷髅 1/幽灵 2，威胁靠波次数量堆）
## Max armor 语义＝该敌「结甲」动作可向遭遇护甲池累计贡献的档位（本批按小折扣实现，标注暂定）。
## 动作格式（kind ∈ attack/multi/armor/wait；引擎实装全四型＋缴械/冰冻跳过）。
## 2026-11-01 经验真值轮：xp＝VC EnemyDatabase.Xp 一手值（蝙蝠1/骷髅2/僵尸4/精英30-55）；
## 七种无对位（暗影炸弹/螳螂/不洁/美杜莎/溺亡者/欺诈者/腥红死神）＝同档插值自拟，标注于此待考古替换。
const ENEMIES := {
	# —— 教程蝠族（Tutorial 生物群；max hit 0＝纯靶子不攻击）——
	"tut_guardian": {"difficulty": 0.5, "name": "守关者", "hp": 30, "xp": 2,
		"actions": [{"kind": "wait"}, {"kind": "attack", "value": 1}]},
	"tut01": {"difficulty": 0.0, "name": "幼雏蝠", "hp": 3, "xp": 1,
		"actions": [{"kind": "wait"}]},
	"tut01x": {"difficulty": 0.5, "name": "幼雏蝠·壮", "hp": 13, "xp": 2,
		"actions": [{"kind": "wait"}]},
	"tut00": {"difficulty": 1.0, "name": "学步蝠", "hp": 21, "xp": 1,
		"actions": [{"kind": "wait"}]},
	"tut06": {"difficulty": 1.5, "name": "学弟蝠", "hp": 26, "xp": 3,
		"actions": [{"kind": "wait"}]},
	# 教程层敌行为＝固定叠甲（2026-11-08 用户令：「敌人不会造成伤害，只会叠加」；
	# 每次行动给自身 +4 护甲——与 wiki 敌表 Max armor=4 同值）——不攻击不等待，
	# 纯软压力教学（拖越久甲越厚）。
	"tut02": {"difficulty": 1.0, "name": "学甲蝠", "hp": 20, "xp": 1,
		"actions": [{"kind": "armor", "value": 4}]},
	# 教程第二场专用对位（2026-11-08 用户令调参「中 15 边 5」——对位原版预览 16/8/8 手感）
	"tut_side": {"difficulty": 0.5, "name": "雏翼蝠", "hp": 5, "xp": 1,
		"actions": [{"kind": "armor", "value": 4}]},
	"tut_mid": {"difficulty": 0.5, "name": "雏翼蝠·壮", "hp": 15, "xp": 2,
		"actions": [{"kind": "armor", "value": 4}]},   # xp2（2026-11-08 用户令：一级打完第二关正好首升——1+2+1+1=5）
	"tut04": {"difficulty": 1.5, "name": "学徒蝠", "hp": 26, "xp": 3,
		"actions": [{"kind": "attack", "value": 1}]},
	"tut05": {"difficulty": 2.0, "name": "见习蝠", "hp": 30, "xp": 2,
		"actions": [{"kind": "attack", "value": 1}]},
	"tut03": {"difficulty": 2.0, "name": "学长蝠", "hp": 38, "xp": 2,
		"actions": [{"kind": "attack", "value": 1}]},
	# —— Mad Forest 生物群（真值）——
	"bat": {"difficulty": 1.0, "name": "蝙蝠", "hp": 8, "xp": 1,   # 2026-11-07 对齐匕首语义：直刺 8/段＝一发一只
		"actions": [{"kind": "attack", "value": 1}]},
	"flower_wall": {"difficulty": 4.0, "name": "花墙", "hp": 60, "xp": 4,
		"actions": [{"kind": "attack", "value": 1}, {"kind": "armor", "value": 6}]},
	"ghoul": {"difficulty": 3.5, "name": "食尸鬼", "hp": 40, "xp": 3,
		"actions": [{"kind": "attack", "value": 2}]},
	"skeleton3": {"difficulty": 3.0, "name": "骷髅", "hp": 25, "xp": 2,
		"actions": [{"kind": "attack", "value": 1}, {"kind": "armor", "value": 5}]},
	"zombie": {"difficulty": 5.0, "name": "僵尸", "hp": 125, "xp": 4,
		"actions": [{"kind": "wait"}, {"kind": "attack", "value": 2}]},
	"mudman": {"difficulty": 2.0, "name": "泥人", "hp": 20, "xp": 1,
		"actions": [{"kind": "attack", "value": 1}]},
	# —— Inlaid Library 生物群（真值）——
	"ecto": {"difficulty": 4.0, "name": "灵质", "hp": 40, "xp": 2,
		"actions": [{"kind": "attack", "value": 1}, {"kind": "armor", "value": 6}]},
	"ghost": {"difficulty": 5.0, "name": "幽灵", "hp": 100, "xp": 3,
		"actions": [{"kind": "attack", "value": 2}]},
	"shade_bomb": {"difficulty": 4.5, "name": "暗影炸弹", "hp": 80, "xp": 3,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 1}]},
	"sneaky_head": {"difficulty": 6.0, "name": "鬼祟头", "hp": 200, "xp": 5,
		"actions": [{"kind": "attack", "value": 3}]},
	"lion_head": {"difficulty": 6.0, "name": "狮首", "hp": 170, "xp": 4,
		"actions": [{"kind": "attack", "value": 2}, {"kind": "armor", "value": 8}]},
	"glowing_bat_elite": {"difficulty": 8.0, "name": "辉光蝠精英", "hp": 100, "xp": 40, "boss": true,
		"actions": [{"kind": "attack", "value": 1}, {"kind": "multi", "value": 1, "hits": 2},
			{"kind": "armor", "value": 5}]},
	# —— 精英/Boss（真值；armor 意图值＝Max armor 折扣暂定）——
	"bat_elite": {"difficulty": 8.0, "name": "精英蝙蝠", "hp": 400, "xp": 30,
		"actions": [{"kind": "attack", "value": 2}]},
	"treasure_bat_elite": {"difficulty": 9.0, "name": "宝箱蝠精英", "hp": 800, "xp": 45, "boss": true,
		"actions": [{"kind": "attack", "value": 3}]},
	"skeleton_king": {"difficulty": 9.0, "name": "骷髅精英王", "hp": 600, "xp": 35, "boss": true,
		"actions": [{"kind": "attack", "value": 4}, {"kind": "multi", "value": 2, "hits": 2},
			{"kind": "armor", "value": 10}]},
	"mudman_elite": {"difficulty": 9.0, "name": "泥人精英", "hp": 750, "xp": 35, "boss": true,
		"actions": [{"kind": "attack", "value": 6}, {"kind": "armor", "value": 10}]},
	"zombie_elite": {"difficulty": 9.5, "name": "僵尸精英", "hp": 750, "xp": 40, "boss": true,
		"actions": [{"kind": "attack", "value": 7}, {"kind": "armor", "value": 10}]},
	"ecto_elite": {"difficulty": 9.5, "name": "灵质精英", "hp": 1000, "xp": 40, "boss": true,
		"actions": [{"kind": "attack", "value": 8}, {"kind": "armor", "value": 15}]},
	"mantis_elite": {"difficulty": 10.0, "name": "螳螂精英", "hp": 1200, "xp": 45, "boss": true,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 12}, {"kind": "multi", "value": 6, "hits": 2}]},
	"ghost_elite": {"difficulty": 10.0, "name": "幽灵精英", "hp": 1500, "xp": 45, "boss": true,
		"actions": [{"kind": "attack", "value": 9}, {"kind": "armor", "value": 20}]},
	"lion_head_elite": {"difficulty": 10.0, "name": "狮首精英", "hp": 2000, "xp": 55, "boss": true,
		"actions": [{"kind": "attack", "value": 10}, {"kind": "armor", "value": 25}]},
	"nesuferit_elite": {"difficulty": 10.0, "name": "不洁精英", "hp": 4000, "xp": 60, "boss": true,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 14}, {"kind": "armor", "value": 30}]},
	"queen_medusa_elite": {"difficulty": 10.0, "name": "美杜莎女王精英", "hp": 3500, "xp": 60, "boss": true,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 14}, {"kind": "armor", "value": 35}]},
	"drowner": {"difficulty": 10.0, "name": "溺亡者", "hp": 4000, "xp": 65,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 11}]},
	"trickster": {"difficulty": 10.0, "name": "欺诈者", "hp": 30000, "xp": 100,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 30}]},
	"red_death": {"difficulty": 10.0, "name": "腥红死神", "hp": 1000000, "xp": 500,   # xp 自拟插值
		"actions": [{"kind": "attack", "value": 333}]},
}
#endregion

#region 遭遇（血池波次制：pool＝总池出场序；active_max＝同场活跃位；refill＝回合末补位数）
## 都死了＝活跃位清空且总池耗尽；打赢进下一层（DUNGEON 序）。
## 2026-11-01 教程层入序（用户裁定「先做个新手教程类似的」）：前两层＝Tutorial 蝠族零压力教学
## （幼雏 3 血 0 攻——教点击出牌/连击阶梯/都死了才进层），后接正式三层；全敌真值下节奏对表。
const ENCOUNTERS := {
	"enc_tut1": {"name": "蝙蝠（教学）", "active_max": 1, "refill": 0,
		"pool": ["bat"]},   # 2026-11-03 用户裁定：新手第一战＝一只蝙蝠，没其他的
	"enc_tut2": {"name": "试炼巢（教学）", "active_max": 3, "refill": 1,
		"pool": ["tut02", "tut04", "tut06", "tut05", "tut03"]},
	"enc_bats": {"name": "蝙蝠巢", "active_max": 3, "refill": 1,
		"pool": ["bat", "bat", "bat", "mudman", "bat", "bat"]},
	"enc_crypt": {"name": "乱葬岗", "active_max": 3, "refill": 1,
		"pool": ["mudman", "skeleton3", "bat", "skeleton3", "mudman", "skeleton3"]},
	"enc_king": {"name": "蝠精英巢穴", "active_max": 2, "refill": 1,
		"pool": ["glowing_bat_elite", "skeleton3", "mudman"]},
}

const DUNGEON := ["enc_tut1", "enc_tut2", "enc_bats", "enc_crypt", "enc_king"]

#region 楼层表（2026-11-01 地图轮：每层＝一张连续网格地图；2026-11-01 用户裁定「原版可走回头路」）
## pool＝该层明雷敌池（每雷随机组队 group[min,max] 只）；enemies＝图上明雷数；chests＝宝箱数；
## boss 层＝无铲子，杀 Boss 直接通关。教学层零/低威胁（蝠族真值）。
## FLOORS 难度选敌制（2026-11-07 实装，原版 DifficultyRange 同构）：
## 每层配 "difficulty"（该层 tile 难度值，0-10）——组队时按 ENEMIES.difficulty 标签过滤
## 池（|敌难度 − 层难度| ≤ 容差 1.5），归一化方差加权随机（deep 层偏出高难怪）。
## fixed:"tutorial" 层＝固定编队豁免（明雷 group 嵌套死编队，不走选敌）。
const FLOORS := [
	{"name": "蝙蝠（教学）", "fixed": "tutorial", "pool": ["tut02"], "difficulty": 0.0,
		"group": [1, 1], "enemies": 3, "chests": 1},   # 2026-11-08 数值轮：教程默认敌＝学甲蝠 tut02（20 血，wiki Bat Tutorial02）——三场递进 1→3→宝箱→5
	{"name": "试炼巢（教学）", "pool": ["tut02", "tut04", "tut05", "tut06", "tut03"], "difficulty": 1.5,
		"group": [1, 2], "enemies": 5, "chests": 1},
	{"name": "蝙蝠巢", "pool": ["bat", "bat", "bat", "mudman"], "difficulty": 2.0,
		"group": [2, 3], "enemies": 5, "chests": 2},
	{"name": "乱葬岗", "pool": ["mudman", "skeleton3", "bat", "skeleton3"], "difficulty": 3.5,
		"group": [2, 3], "enemies": 6, "chests": 2},
	{"name": "蝠精英巢穴", "pool": ["skeleton3", "mudman"], "difficulty": 6.0,
		"group": [1, 2], "enemies": 2, "chests": 1, "boss": "glowing_bat_elite"},
]

## 难度→选敌方方差（原版 CalculateEnemyVarianceForDifficulty 同构数学）：
## variance01 = clamp((tileDifficulty − range.min)/(range.max − range.min), 0, 1)
## 我方 range 取全表 [0,10]；返回 0-1 进度值（越高偏出高难池）
static func difficulty_variance(tile_difficulty: float) -> float:
	return clampf((tile_difficulty - 0.0) / 10.0, 0.0, 1.0)

## 难度选敌（一局组队时从层池按难度标签过滤＋方差加权随机；n＝要选的敌数）：
## 过滤＝|敌难度 − 层难度| ≤ 容差；加权＝难度贴近层难度的权重高（方差越高高难池越活跃）。
## 池空时回退全池（保底不空）。boss 敌（boss:true）不进随机池（Boss 由 FLOORS.boss 指定）。
static func pick_enemies_by_difficulty(rng: RandomNumberGenerator, floor_spec: Dictionary,
		pool: Array, n: int) -> Array:
	var out: Array = []
	if n <= 0 or pool.is_empty():
		return out
	var fd := float(floor_spec.get("difficulty", 0.0))
	var candidates: Array = []
	for eid in pool:
		var spec: Dictionary = ENEMIES.get(String(eid), {})
		if spec.is_empty() or bool(spec.get("boss", false)):
			continue
		if absf(float(spec.get("difficulty", 0.0)) - fd) <= 1.5:
			candidates.push_back(String(eid))
	if candidates.is_empty():
		candidates = pool.duplicate()   # 回退：容差内无候选＝用全池（保底）
	for i in n:
		out.push_back(candidates[rng.randi_range(0, candidates.size() - 1)])
	return out
#endregion
#endregion

#region 主角与开局（2026-11-03 用户裁定：初始 50 血 0 气；气只来自攻击卡、跨回合保存、上限 9；
## 式每回合重置、上限 9 层）
const PLAYER_BASE := {"hp": 50, "qi_base": 0, "draw_per_turn": 3}   # qi_base 已退役（气改上限重置制，2026-11-06）
const QI_BASE_MAX := 2        # 气上限·基础档（可成长：局外 run.qi_max／局内 qi_max 效果——2026-11-06 终裁）
const QI_CAP := 6             # 气上限成长护栏（数值轮可调；回合重置/洗牌 +当前上限，上限成长两处同步放大）
const STANCE_CAP := 9         # 〔2026-11-08 状态制退役〕式层数上限旧值——引擎不再消费，留档待文本轮清
const HAND_CAP := 10
const CRIT_CHANCE := 0.25   # 暴击率初始 25%（2026-11-07 用户定；倍率 ×2）
const CRIT_MULT := 2.0

## 开局卡组（2026-11-03 用户裁定：新手关初始就一张「连环刺」〔原直刺〕——孤张制）
const START_DECK := ["zhici"]

## VC 制属性表（2026-11-04 裁定照原版属性表；**2026-11-07 属性轮四层接线**）：
## 原版三层合成 GetStartingX(playerConfig, runSettings, progressionData)＋本场增量层——
## 我方对应：base（角色基础）＋ progression（局外金币养成 QiVcMeta）＋ dungeon（run.dungeon_stats
## ——本局型黄卡）合成 starting；encounter（本场型黄卡）只写 battle 实例、随实例销毁清零
## （＝原版 OnEncounterDefeated 重算回基线语义）。pct 轴 base=100（100% 起步），计数轴 base=0。
const STATS := [
	{"id": "might", "cn": "威力", "side": "L", "pct": true, "base": 100, "glyph": "力", "color": "c86a5a"},
	{"id": "area", "cn": "范围", "side": "L", "pct": true, "base": 100, "glyph": "域", "color": "d08a3e"},
	{"id": "duration", "cn": "持续", "side": "L", "pct": true, "base": 100, "glyph": "时", "color": "6f9fd8"},
	{"id": "amount", "cn": "弹数", "side": "L", "pct": false, "base": 0, "glyph": "弹", "color": "c9a227"},
	{"id": "magnet", "cn": "抽牌", "side": "L", "pct": false, "base": 0, "glyph": "磁", "color": "8fb4d8"},
	{"id": "recovery", "cn": "回复", "side": "L", "pct": false, "base": 0, "glyph": "愈", "color": "7fae62"},
	{"id": "deal_count", "cn": "发牌", "side": "L", "pct": false, "base": 0, "glyph": "抽", "color": "cbb2ef"},
	{"id": "scavenge", "cn": "拾取", "side": "L", "pct": false, "base": 0, "glyph": "拾", "color": "b9a978"},
	{"id": "growth", "cn": "成长", "side": "R", "pct": true, "base": 100, "glyph": "长", "color": "7fae62"},
	{"id": "curse", "cn": "诅咒", "side": "R", "pct": true, "base": 100, "glyph": "咒", "color": "b07ad0"},
	{"id": "luck", "cn": "幸运", "side": "R", "pct": true, "base": 100, "glyph": "运", "color": "7fae62"},
	{"id": "greed", "cn": "贪婪", "side": "R", "pct": true, "base": 100, "glyph": "贪", "color": "e0b84a"},
	{"id": "reroll", "cn": "重掷", "side": "R", "pct": false, "base": 0, "glyph": "骰", "color": "d8d8d8"},
	{"id": "banish", "cn": "剔除", "side": "R", "pct": false, "base": 0, "glyph": "剔", "color": "d05a5a"},
	{"id": "skip", "cn": "跳过", "side": "R", "pct": false, "base": 0, "glyph": "跳", "color": "e0a05a"},
	{"id": "revival", "cn": "复活", "side": "R", "pct": false, "base": 0, "glyph": "复", "color": "d05a5a"},
	{"id": "risk", "cn": "风险", "side": "R", "pct": true, "base": 100, "glyph": "险", "color": "d08a3e"},
	{"id": "charm", "cn": "魅惑", "side": "R", "pct": true, "base": 100, "glyph": "魅", "color": "d07aa8"},
	{"id": "max_hp", "cn": "血上限", "side": "R", "pct": false, "base": 0, "glyph": "命", "color": "c86a5a"},   # 固定值轴（黄卡 Gain N Max Health）
	{"id": "max_hp_pct", "cn": "体魄", "side": "R", "pct": true, "base": 100, "glyph": "魄", "color": "c86a5a"},   # 百分比轴（养成 +10%/级——wiki 真值）
]

## 属性默认值（全部取 base）
static func default_stats() -> Dictionary:
	var d := {}
	for s in STATS:
		d[String(s["id"])] = int(s["base"])
	return d

## 三层基线合成（对应原版 GetStartingX 三参——playerConfig/runSettings/progressionData）：
## base（STATS.base）＋ progression（QiVcMeta.upgrades 的每级加成）＋ dungeon（run.dungeon_stats）。
## meta 传 {} ＝局外层为零（探针/无档环境）。返回值即战斗 starting——encounter 增量在 battle 层另加。
## 局外养成真值表（2026-11-07 wiki PowerUps 页一手值）：每轴 {每级加成, 满级, 每级花费}。
## max_hp_pct＝百分比轴（PowerUp Max Health +10%/级）——与黄卡固定值 max_hp 分轴。
const PROGRESSION_TABLE := {
	"might": {"per": 20, "max_lv": 5, "cost": 500},
	"area": {"per": 10, "max_lv": 5, "cost": 850},
	"amount": {"per": 1, "max_lv": 3, "cost": 1250},
	"growth": {"per": 20, "max_lv": 5, "cost": 750},
	"greed": {"per": 25, "max_lv": 4, "cost": 1000},
	"luck": {"per": 20, "max_lv": 5, "cost": 400},
	"curse": {"per": 20, "max_lv": 5, "cost": 350},
	"revival": {"per": 1, "max_lv": 1, "cost": 4000},
	"max_hp_pct": {"per": 10, "max_lv": 5, "cost": 450},
	"recovery": {"per": 1, "max_lv": 3, "cost": 500},
	"duration": {"per": 1, "max_lv": 5, "cost": 250},
	"deal_count": {"per": 1, "max_lv": 2, "cost": 2500},
	"magnet": {"per": 1, "max_lv": 1, "cost": 2000},
	"reroll": {"per": 2, "max_lv": 5, "cost": 200},
	"skip": {"per": 2, "max_lv": 5, "cost": 250},
	"banish": {"per": 2, "max_lv": 5, "cost": 300},
}
## 兼容别名（旧引用面）
const PROGRESSION_PER_LEVEL := {
	"might": 20, "area": 10, "amount": 1, "deal_count": 1, "growth": 20,
	"greed": 25, "luck": 20, "curse": 20, "revival": 1, "max_hp_pct": 10, "magnet": 1, "recovery": 1}
const PROGRESSION_MAX_LEVEL := 5   # 多数轴 5 级（真值分轴存 PROGRESSION_TABLE.max_lv）

static func get_starting_stats(meta: Dictionary, run: Dictionary) -> Dictionary:
	var d := default_stats()
	var ups: Dictionary = meta.get("upgrades", {})
	for axis in ups:
		if PROGRESSION_PER_LEVEL.has(axis):
			d[axis] = int(d.get(axis, 0)) + int(PROGRESSION_PER_LEVEL[axis]) * int(ups[axis])
	var dun: Dictionary = run.get("dungeon_stats", {})
	for axis in dun:
		d[axis] = int(d.get(axis, 0)) + int(dun[axis])
	return d

## 局外养成花费（wiki 真值：每轴固定每级花费）
static func upgrade_cost(axis: String, _level: int) -> int:
	return int((PROGRESSION_TABLE.get(axis, {}).get("cost", 500)))

## 属性轴中文名（UI 查询口——养成面板/属性列用）
static func stat_cn_of(axis: String) -> String:
	for s in STATS:
		if String(s["id"]) == axis:
			return String(s["cn"])
	return axis

## 属性轴是否百分比制（100 基）
static func stat_pct_of(axis: String) -> bool:
	for s in STATS:
		if String(s["id"]) == axis:
			return bool(s["pct"])
	return false

static func default_vc_run() -> Dictionary:
	return {"hp": PLAYER_BASE["hp"], "copper": 0, "level": 1, "xp": 0,
		"deck": START_DECK.duplicate(),
		"neigong": [],   # 2026-11-07 教程轮：开局无连击——内功「连击堆叠」改由宝箱获得（教程层首个）
		"stats": default_stats(),
		"dungeon_stats": {},   # 2026-11-07 属性轮：本局层（dungeon 型黄卡入账——三层合成的第三层）
		"enc": 0, "seed": 20261101}
#endregion

#region 等级与经验（2026-11-01 经验轮，照 VC PlayerLevelConfig 一手值：
## 0-4 级段每级需 10，每 5 级段 +2，45-49 段 28，50 级封顶；经验来自击杀（ENEMIES.xp）。
## 升级奖励＝三选一（VC 制）——奖励界面随奖励批实装，升级先记账 pending_picks）
const XP_LEVEL_RANGES := [[0, 5, 10], [5, 10, 12], [10, 15, 14], [15, 20, 16], [20, 25, 18],
	[25, 30, 20], [30, 35, 22], [35, 40, 24], [40, 45, 26], [45, 50, 28]]
const LEVEL_CAP := 50
const XP_BASE_REQ := 5   # 首次升级门槛（PlayerConfig._baseXpReq 一手值——漏抄回潮修 2026-11-01）

## 当前级升下一级所需经验（1→2 阶走基础值 5；2 阶起按分段）
static func xp_to_next(level: int) -> int:
	if level <= 1:
		return XP_BASE_REQ
	var l := clampi(level - 1, 0, LEVEL_CAP - 1)
	for r in XP_LEVEL_RANGES:
		if l >= int(r[0]) and l < int(r[1]):
			return int(r[2])
	return 28

## 经验进度归并（连续升级一并结算）：返回 {lvl, xp, need, gained}
static func level_progress(level: int, xp: int) -> Dictionary:
	var lvl := level
	var left := xp
	var gained := 0
	while lvl < LEVEL_CAP and left >= xp_to_next(lvl):
		left -= xp_to_next(lvl)
		lvl += 1
		gained += 1
	return {"lvl": lvl, "xp": left, "need": xp_to_next(lvl), "gained": gained}

#region 升级三选一（2026-11-01 奖励轮）：出题＝照 VC RewardConfig 分段费权制（简化四段）——
## 逐槽掷费用档→该费池等权抽卡、三张互异；跳过＝得经验（SKIP_XP 自拟暂定，一手表未录）；
## 跳过/重选/排除次数＝run.skips/rerolls/banishes（VC 基础全 0、商店购买，商店未开恒 0）。
const SKIP_XP := 10
const REWARD_BANDS := [
	{"min": 1, "costs": {0: 60, 1: 40}},
	{"min": 7, "costs": {0: 40, 1: 60}},
	{"min": 11, "costs": {0: 25, 1: 25, 2: 50}},
	{"min": 20, "costs": {0: 15, 1: 15, 2: 20, 3: 50}},
]

static func reward_band(level: int) -> Dictionary:
	var best: Dictionary = REWARD_BANDS[0]
	for b in REWARD_BANDS:
		if level >= int(b["min"]):
			best = b
	return best

static func _cards_of_cost(cost: int) -> Array:
	var out: Array = []
	for cid in CARDS:
		if int(CARDS[cid].get("cost", 0)) == cost:
			out.push_back(String(cid))
	return out

## 三选一出题：三槽互异；某费池空则重掷（guard 60）。
## 低级过滤（VC cardLevelConfig 真值）：3 级前只出攻击型（普攻/催破）且只出卡组没有的新卡。
const ATTACK_ONLY_UNTIL_LEVEL := 2   # weaponsOnlyUntilLevel（VC 原值 2＝「直到 2 级」）
const NEW_ONLY_UNTIL_LEVEL := 2

static func reward_offers(rng: RandomNumberGenerator, level: int, deck: Array = []) -> Array:
	var band := reward_band(level)
	var costs: Array = (band["costs"] as Dictionary).keys()
	var low_attack_only := level <= ATTACK_ONLY_UNTIL_LEVEL
	var low_new_only := level <= NEW_ONLY_UNTIL_LEVEL
	var picks: Array = []
	var guard_i := 0
	while picks.size() < 3 and guard_i < 60:
		guard_i += 1
		var total := 0
		for c in costs:
			total += int(band["costs"][c])
		var roll := rng.randi_range(1, maxi(1, total))
		var acc := 0
		var chosen := int(costs[0])
		for c in costs:
			acc += int(band["costs"][c])
			if roll <= acc:
				chosen = int(c)
				break
		var pool_c := _cards_of_cost(chosen)
		if pool_c.is_empty():
			continue
		var cid := String(pool_c[rng.randi_range(0, pool_c.size() - 1)])
		if picks.has(cid):
			continue
		if low_attack_only and not ["attack", "basic", "burst"].has(String(CARDS[cid].get("kind", ""))):
			continue
		if low_new_only and deck.has(cid):
			continue
		picks.push_back(cid)
	return picks
#endregion
