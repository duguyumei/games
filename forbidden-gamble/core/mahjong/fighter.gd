class_name MJFighter
extends RefCounted

# 对弈者状态（真气语法 v3.6）：内力三力（劲＝出力/骨＝承伤/气＝流转——"属性"概念退役）、
# 丹田 13（静息收敛于 13，重击挖坑后逐拍回填；2026-09-18 用户定方向：上限将调 18–24 区间取 20，
# 涉及 39 套测试场景迁移，独立规则轮实装）、副露活式仓、罡气、变招充能/机会（按拍充能）、
# 护体（铁布衫）、在途功法（前摇）、破绽。
# 气血以"百分之一"定点整数记账（内部两位小数、显示一律向上取整）。
# 数值全占位（规则冻结、数值不冻结——演武场校准）。


const REST_TOTAL := 13    # 静息账本：手牌 ＋ 3×明式数 收敛于 13（一本账上限；调 20 待规则轮）
const GANG_QI_CAP := 5    # 罡气上限（占位；增长轴全走内容层——资源不进加点）
const BIAN_STEP := 6      # 变招充能兑换门槛（6 充能＝1 机会）

# —— 内力·基础数值（机体底盘：卡组/对手卡携带，挑战层注入；缺省＝演武场现状）——
var base_attack := 10     # 1:5 比例定稿（2026-09-16 用户拍板"数值按1比5"，×10 缩放弃用）
var base_defense := 0     # 玩家 0；敌方基础防＝身份旋钮（厚防墙）
var base_jing := 1        # 基础精力：架势数＝base_jing＋2（v3.6 摸牌 3 定值由此派生；卡组可改）
var base_max_hp := 100    # 骨力不管血（v3.6 解耦）；轮层每过一组 +20（挑战层注入）

# —— 内力·增幅（成长轴；开局 1/1/1，无单项硬上限——K 曲线自限）——
var jin_li := 1           # 劲力：出力——攻击面板 +2/点
var gu_li := 1            # 骨力：承伤——防御 +1/点（承伤比＝5/(5+防御)）
var qi_li := 1            # 气力：流转——每拍变招充能 +1；每逢 3 点缺牌补充 +1

var side: String  # "player" | "enemy"
var display_name := ""
var max_hp_fp := 10000  # 血量面板（百分之一单位）＝基础血量×100
var hp_fp := 10000

var hand: Array[MJTile] = []
# 副露（活式仓）：{tiles: Array[MJTile], type: "PON"|"KAN"|"CHI", suit, symbol}
# PON → 该门重式；KAN → 本门万能式；CHI → 该门轻式（吃仅对虚招，v3.6）。
# 每组副露面子给普攻 +50%（光环）。
var melds: Array[Dictionary] = []

# 内容词条瞬态（挑战层内容件用，引擎消费即清）：
var draw_bonus_next := 0     # 下次摸牌 +N（洗练诀；正常/破绽拍摸牌时消费清零，缺牌补充不吃）
var gu_drop_next := 0        # 下拍骨力临时 −N（破甲拳；自身拍末消费清零）
var iron_bonus_next := 0     # 下次护体免伤 +N%（灵甲；start_iron 消费清零）

var gang_qi := 0
# 变招（v3.6）：按拍充能——每个自身拍 +（1＋气力），满 6 转 1 机会（机会上限 9）。
var bian_charge := 0
var bian_opps := 0

# 在途功法（v3.6 前摇）：按对方经过拍数计，到期在发射者自身摸牌后的自动效果阶段结算；
# 招架拍/破绽拍不摸牌→不解算。结构性在途至多一门。在途期间不能发动防御（双向承诺互斥）。
var pending: Array[Dictionary] = []
var flawed := false             # 破绽：下一拍＝只自然摸牌（生产通道＝手牌清零即时触发）
var last_fire_beat := -1        # 重击（功法＝打出）：每拍至多一门（v3.2 §3）

# 护体（铁布衫，v3.5）：激活期免伤；每累计减免 5 点免伤率 −10%（最低 0）；
# 持续 3 个敌方拍（敌方拍末 −1）；期间不能发功法、罡气冻结。
var iron_active := false
var iron_reduction := 0     # 当前免伤（百分比整数；激活时 80）
var iron_absorbed_fp := 0   # 本次激活累计已减免量（百分之一单位）
var iron_beats_left := 0    # 剩余敌方拍


func rest_cap() -> int:
	return REST_TOTAL - 3 * melds.size()


func rest_total() -> int:
	return hand.size() + 3 * melds.size()


# —— 面板（v3.6 两层账）——

func attack_panel() -> int:
	return base_attack + 2 * jin_li


func defense_panel() -> int:
	return maxi(base_defense + gu_li - gu_drop_next, 0)


# 承伤比（千分之整数，显示/请求用）：5/(5+防御)×1000。
func damage_taken_ratio() -> int:
	return 5000 / (5 + maxi(defense_panel(), 0))


# 每拍基础摸牌数（架势数＝基础精力＋2；内容词条走 draw_bonus_next 瞬态叠加）。
func draw_count() -> int:
	return base_jing + 2


# 缺牌补充量（v3.6 气力）：正常摸牌后仍低于容量 → 补 ⌊气力÷3⌋（至容量由引擎钳）。
func topup_count() -> int:
	return qi_li / 3


# 基础数值/增幅改动后刷新派生账（setup 与测试改数值时调用；不回血）。
func apply_neili() -> void:
	max_hp_fp = base_max_hp * 100


# 显示口径：一律向上取整（v3.5 用户拍板）。
static func ceil_fp(fp: int) -> int:
	return (fp + 99) / 100


func hp_display() -> int:
	return ceil_fp(hp_fp)


func max_hp_display() -> int:
	return max_hp_fp / 100


func add_gang_qi(amount: int) -> void:
	if iron_active and amount > 0:
		return  # 护体生效期间罡气冻结（v3.5）
	gang_qi = clampi(gang_qi + amount, 0, GANG_QI_CAP)


# 按拍充能（v3.6）：每个自身拍 +amount（＝1＋气力，招架拍同），满 6 转 1 机会。
func add_bian_charge(amount: int) -> void:
	bian_charge += amount
	while bian_charge >= BIAN_STEP and bian_opps < 9:
		bian_charge -= BIAN_STEP
		bian_opps += 1
	if bian_opps >= 9:
		bian_charge = mini(bian_charge, BIAN_STEP - 1)  # 机会满后充能不再积压（明码浪费）


func start_iron(reduction := 80, beats := 3) -> void:
	iron_active = true
	iron_reduction = mini(reduction + iron_bonus_next, 100)
	iron_bonus_next = 0
	iron_absorbed_fp = 0
	iron_beats_left = beats


func end_iron() -> void:
	iron_active = false
	iron_reduction = 0
	iron_absorbed_fp = 0
	iron_beats_left = 0


func has_pending() -> bool:
	return not pending.is_empty()
