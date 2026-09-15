class_name MJShiki
extends RefCounted

# 六式（真气语法 v3 §4）：**顺＝轻式、刻＝重式**，三门各一对（名目占位，随三门改名重锚）。
# 截来的全是重式（碰杠皆刻子经济）；轻式只能自产（手牌暗顺，无吃）。
# 基本招：一个式触发一次——明式在入副露（截牌）时；暗式在被功法消耗时。
# 轻重＝功法配方的价格语言（崩×2 重击 vs 点×3 连击）。

const LIGHT := "轻"
const HEAVY := "重"

const SYMBOLS := {
	"万轻": "点", "万重": "崩",
	"筒轻": "刺", "筒重": "劈",
	"条轻": "碾", "条重": "撼",
}

const SUIT_OF_SYMBOL := {"点": "万", "崩": "万", "刺": "筒", "劈": "筒", "碾": "条", "撼": "条"}
const WEIGHT_OF_SYMBOL := {"点": LIGHT, "崩": HEAVY, "刺": LIGHT, "劈": HEAVY, "碾": LIGHT, "撼": HEAVY}

# 基本招威力占位（v3 §10：数字全占位，演武场校准）
const BASIC_DAMAGE := {LIGHT: 2, HEAVY: 4}


static func symbol_for(kind: String, suit: String) -> String:
	return String(SYMBOLS.get(suit + kind, ""))


static func suit_of(symbol: String) -> String:
	return String(SUIT_OF_SYMBOL.get(symbol, ""))


static func weight_of(symbol: String) -> String:
	return String(WEIGHT_OF_SYMBOL.get(symbol, ""))


static func basic_damage(symbol: String) -> int:
	return int(BASIC_DAMAGE.get(weight_of(symbol), 0))


# 暗式检测（v3 §4：手牌成组可被功法直接消耗，不必晒出）。
# 返回可成组列表：[{tiles: Array[MJTile]×3, kind: 轻|重, suit, symbol}]。
# 先刻后顺（刻子占牌优先）；顺序确定性：属性常序、数值升序、手牌序。
static func find_groups(hand: Array) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var used := {}  # 手牌索引 -> true（已被某组占用）

	# —— 刻子：同 key 计数，取未被占用的前三张 ——
	var by_key := {}  # key -> Array[int]（手牌索引）
	for i in range(hand.size()):
		var key := (hand[i] as MJTile).key()
		if not by_key.has(key):
			by_key[key] = []
		(by_key[key] as Array).append(i)
	var keys := by_key.keys()
	keys.sort()
	for key in keys:
		var indexes: Array = by_key[key]
		var free: Array[int] = []
		for idx in indexes:
			if not used.has(idx):
				free.append(idx)
		if free.size() >= 3:
			var tiles: Array[MJTile] = []
			for k in range(3):
				used[free[k]] = true
				tiles.append(hand[free[k]] as MJTile)
			var suit := String(key).left(1)
			groups.append({"tiles": tiles, "kind": HEAVY, "suit": suit, "symbol": symbol_for(HEAVY, suit)})

	# —— 顺子：同属性数值连三，各取一张未占用 ——
	# 索引查"首个未占用"（不破坏池：失败的尝试不留泄漏）；同址可重复成组（两组 5-6-7 都能找到）。
	var by_suit_value := {}  # "suit|value" -> Array[int]
	for i in range(hand.size()):
		if used.has(i):
			continue
		var t := hand[i] as MJTile
		var k := "%s|%d" % [t.suit, t.value]
		if not by_suit_value.has(k):
			by_suit_value[k] = []
		(by_suit_value[k] as Array).append(i)
	for suit in MJTile.SUITS:
		for v in range(MJTile.VALUE_MIN, MJTile.VALUE_MAX - 1):
			while true:
				var got: Array[int] = []
				for rv in [v, v + 1, v + 2]:
					var picked := -1
					for idx in (by_suit_value.get("%s|%d" % [suit, rv], []) as Array):
						if not used.has(idx):
							picked = idx
							break
					if picked < 0:
						break
					got.append(picked)
				if got.size() != 3:
					break
				var run: Array[MJTile] = []
				for gi in got:
					used[gi] = true
					run.append(hand[gi] as MJTile)
				groups.append({"tiles": run, "kind": LIGHT, "suit": suit, "symbol": symbol_for(LIGHT, suit)})
	return groups


# 在手牌中找一组能供给指定符号的暗式（轻→顺子、重→刻子）。找不到返回空字典。
static func find_symbol(hand: Array, symbol: String) -> Dictionary:
	for group in find_groups(hand):
		if String(group["symbol"]) == symbol:
			return group
	return {}
