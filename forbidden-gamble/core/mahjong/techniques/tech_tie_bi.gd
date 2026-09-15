class_name TechTieBi
extends MJTechnique

# 铁壁式（占位守功法）：吃罡气、行动期间免费即时（v3.4：摸牌后出牌前）——
# 护境覆盖制（v3 不动件：新值覆盖旧值）。数值全占位。


func _init() -> void:
	id = "tie_bi"
	display_name = "铁壁式"
	kind = "defense"
	gang_qi_cost = 3


func apply_defense(_fighter: MJFighter) -> Dictionary:
	return {"guard_set": 8, "notes": ["铁壁式：护境覆盖为 8"]}
