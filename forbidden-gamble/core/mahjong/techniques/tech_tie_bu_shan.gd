class_name TechTieBuShan
extends MJTechnique

# 铁布衫（v3.5 基础护体·护身槽，数值占位）：3 罡气 → 80% 免伤，持续 3 个敌方拍；
# 期间每累计减免 5 点免伤率 −10%（最低 0）；期间不能发功法、罡气冻结。
# 每次激活从 80% 起算（重激活需等上一件到期——被击渐损的横练气罩）。


func _init() -> void:
	id = "tie_bu_shan"
	display_name = "铁布衫"
	kind = "defense"
	gang_qi_cost = 3


func apply_defense(f: MJFighter) -> Dictionary:
	f.start_iron()
	return {"notes": ["铁布衫：80% 免伤，持续 3 个敌方拍（每累计减免 5 点免伤率 −10%）"]}
