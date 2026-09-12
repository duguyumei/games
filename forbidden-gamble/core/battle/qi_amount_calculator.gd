class_name QiAmountCalculator
extends RefCounted

# 真气量（v1 全局唯一计价，《战斗系统底层_v1》§3）：
# 每张选入真气按（品级值 − 功法等级）计入，合计即本次真气量。
# 等级 1 量行：下 0／中 1／上 2；等级 2：下 −1／中 0／上 1。
# 贡献为负允许（软门槛——喂两口下品给等级 2 功法近乎空转，不设硬禁入），
# 由效果侧按 max(0, 基值＋系数×量) 钳底，这里不钳。
static func qi_amount(cards: Array, technique_level: int, modifier: int = 0) -> int:
	var total := modifier
	for card in cards:
		total += card.grade - technique_level
	return total
