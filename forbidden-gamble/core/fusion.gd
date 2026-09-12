class_name FusionRules
extends RefCounted

# 融合（《战斗系统底层_v1》§1）：同属性、同品级两张 → 一张品级＋1；上品封顶；
# 手动进行（演武场网格"凝"按钮）；v1 免费；牌库下限 12 张。
# 纯规则裁定（可测）——UI 只负责把 can_fuse 的结论呈现出来。

const DECK_MIN := 12

# count＝该属性该品级张数；deck_total＝当前牌库总张数。融合净减 1 张，故需总数 ≥ 下限＋1。
static func can_fuse(count: int, grade: int, deck_total: int) -> Dictionary:
	if grade >= 3:
		return {"ok": false, "reason": "上品封顶，不可再凝"}
	if count < 2:
		return {"ok": false, "reason": "同属性同品级至少 2 张才能凝"}
	if deck_total - 1 < DECK_MIN:
		return {"ok": false, "reason": "牌库下限 %d 张——再凝就破了下限" % DECK_MIN}
	return {"ok": true}
