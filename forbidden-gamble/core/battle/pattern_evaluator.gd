class_name PatternEvaluator
extends RefCounted

# 牌型（真气语法 v2，《真气语法_v2》§1–2）：麻将语法，属性与数值同时参与——
# **刻子**＝三张全同（属性、数值皆同）；**顺子**＝同属性、数值连续三张。
# 功法输入固定三张（功法声明要刻子还是顺子）；对子只是搭子（中间态），
# 不是功法输入。一气/重族/合族/领（v1 属性轴）整体退役。

const KEZI := "KEZI"
const SHUNZI := "SHUNZI"

const PATTERN_SIZE := 3
const MAX_PATTERN_SIZE := 3

static func evaluate(selected_cards: Array) -> Array[String]:
	var result: Array[String] = []
	if selected_cards.size() != PATTERN_SIZE:
		return result
	if is_kezi(selected_cards):
		result.append(KEZI)
	elif is_shunzi(selected_cards):
		result.append(SHUNZI)
	return result

# 刻子：三张全同（属性＋数值）
static func is_kezi(cards: Array) -> bool:
	if cards.size() != PATTERN_SIZE:
		return false
	var first: QiCard = cards[0]
	for card in cards:
		if str(card.attribute) != str(first.attribute) or int(card.value) != int(first.value):
			return false
	return true

# 顺子：同属性、数值连续（排序后两两差 1）
static func is_shunzi(cards: Array) -> bool:
	if cards.size() != PATTERN_SIZE:
		return false
	var first: QiCard = cards[0]
	var values: Array[int] = []
	for card in cards:
		if str(card.attribute) != str(first.attribute):
			return false
		values.append(int(card.value))
	values.sort()
	for index in range(values.size() - 1):
		if values[index + 1] - values[index] != 1:
			return false
	return true

static func pattern_name(pattern: String) -> String:
	return {KEZI: "刻子", SHUNZI: "顺子"}.get(pattern, pattern)

# ---------- 吃碰杠搭子检测（河上截牌用，《真气语法_v2》§6） ----------

# 同一张牌（属性＋数值都同）——碰/杠的比对基础。
static func same_tile(a: QiCard, b: QiCard) -> bool:
	return str(a.attribute) == str(b.attribute) and int(a.value) == int(b.value)

# 碰搭子：手里另有 ≥2 张与河牌全同（截来即成刻子）
static func can_pon(hand: Array, river_card: QiCard) -> bool:
	var copies := 0
	for card in hand:
		if same_tile(card, river_card):
			copies += 1
	return copies >= 2

# 杠搭子：手里另有 ≥3 张与河牌全同（截来即成杠——升档刻子功法＋补一张＋被杠者破绽）
static func can_kan(hand: Array, river_card: QiCard) -> bool:
	var copies := 0
	for card in hand:
		if same_tile(card, river_card):
			copies += 1
	return copies >= 3

# 吃搭子：手里另有两张能与河牌组成顺子（同属性连续三张）——返回可用的搭子组合
static func chi_melds(hand: Array, river_card: QiCard) -> Array:
	var melds: Array = []
	var seen := {}
	for i in range(hand.size()):
		for j in range(i + 1, hand.size()):
			var pair_key := "%d|%d" % [i, j]
			var candidate: Array = [hand[i], hand[j], river_card]
			if is_shunzi(candidate) and not seen.has(pair_key):
				seen[pair_key] = true
				melds.append([hand[i], hand[j]])
	return melds
