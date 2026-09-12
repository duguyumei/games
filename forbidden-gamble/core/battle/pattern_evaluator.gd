class_name PatternEvaluator
extends RefCounted

# 牌型（v1 属性轴，《战斗系统底层_v1》§2）：牌型只认属性构成——
# 重族＝N 张同属性（二重/三重/四重），合族＝N 张各不同属性（二合/三合/四合），
# 一气＝任意 1 张。选牌上限 4 张：超过 4 张不构成任何牌型。
# 混合构成（如同属性两张＋异属性一张）既非重也非合，返回空。
# 领（合族中主系品级 ≥ 其余）规则定版但 v1 无领功法，此处不判。

const ONE_QI := "ONE_QI"
const HEAVY_2 := "HEAVY_2"
const HEAVY_3 := "HEAVY_3"
const HEAVY_4 := "HEAVY_4"
const MIX_2 := "MIX_2"
const MIX_3 := "MIX_3"
const MIX_4 := "MIX_4"

const MAX_PATTERN_SIZE := 4

static func evaluate(selected_cards: Array) -> Array[String]:
	var result: Array[String] = []
	var count := selected_cards.size()
	if count < 1 or count > MAX_PATTERN_SIZE:
		return result
	if count == 1:
		result.append(ONE_QI)
		return result
	var attributes := {}
	for card in selected_cards:
		attributes[str(card.attribute)] = true
	if attributes.size() == 1:
		result.append(["", "", HEAVY_2, HEAVY_3, HEAVY_4][count])
	elif attributes.size() == count:
		result.append(["", "", MIX_2, MIX_3, MIX_4][count])
	return result

# 牌型中文名（心法规则文本等面板披露用）
static func pattern_name(pattern: String) -> String:
	return {
		ONE_QI: "一气",
		HEAVY_2: "二重",
		HEAVY_3: "三重",
		HEAVY_4: "四重",
		MIX_2: "二合",
		MIX_3: "三合",
		MIX_4: "四合",
	}.get(pattern, pattern)
