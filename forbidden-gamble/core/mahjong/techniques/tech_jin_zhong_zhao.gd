class_name TechJinZhongZhao
extends MJTechnique

# 金钟罩（挑战层新护体·护身槽，占位）：3 罡气 → 70% 免伤，持续 2 个敌方拍
# （铁布衫轻量变体：便宜一档、短一拍；衰减规则随 fighter.start_iron 通用逻辑）。


func _init() -> void:
	id = "jin_zhong_zhao"
	display_name = "金钟罩"
	kind = "defense"
	gang_qi_cost = 3
	brief = "3 罡气 → 70% 免伤，持续 2 个敌方拍；期间不能发功法、罡气冻结。"


func apply_defense(f: MJFighter) -> Dictionary:
	f.start_iron(70, 2)
	return {"notes": ["金钟罩：70% 免伤，持续 2 个敌方拍"]}
