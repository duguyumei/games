class_name MJFighter
extends RefCounted

# 对弈者状态（真气语法 v3 §2–5）：丹田 13＋静息不变量、副露活式仓、罡气、蓄力、冷却、破绽。
# 敌我同构（§6）：敌方同 13 张手牌、同规则打牌。


const REST_TOTAL := 13   # 静息不变量：手牌 ＋ 3×明式数 ＝ 13
const GANG_QI_CAP := 6   # 罡气上限（占位）

var side: String  # "player" | "enemy"
var display_name := ""
var max_hp := 40  # 占位
var hp := 40
var guard := 0    # 护境（覆盖制，v3 不动件：新的覆盖旧的）

var hand: Array[MJTile] = []
# 副露（活式仓）：{tiles: Array[MJTile], type: "PON"|"KAN", suit, symbol}
# PON → 该门重式；KAN → 本门万能式（可付本门轻或重，v3 §4 提案态）。
var melds: Array[Dictionary] = []

var gang_qi := 0
# 在途功法（v3.3）：[{tech_id: String}]——发射者下次能够行动的那一刻自动结算；
# 回气拍/破绽拍/截牌拍不解算（暂定，内容钩子空间）。结构性在途至多一门。
var pending: Array[Dictionary] = []
var flawed := false             # 破绽：跳过下次获得行动权（不叠加）
var last_fire_beat := -1        # 功法＝打出：每拍至多一门（v3.2 §3）


func rest_cap() -> int:
	return REST_TOTAL - 3 * melds.size()


func at_rest() -> bool:
	return hand.size() == rest_cap()


func rest_total() -> int:
	return hand.size() + 3 * melds.size()


func add_gang_qi(amount: int) -> void:
	gang_qi = clampi(gang_qi + amount, 0, GANG_QI_CAP)


func has_pending() -> bool:
	return not pending.is_empty()
