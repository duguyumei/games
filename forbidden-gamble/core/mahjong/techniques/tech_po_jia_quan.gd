class_name TechPoJiaQuan
extends MJTechnique

# 破甲拳（挑战层新功法·功法槽，占位）：崩×2（万门重刻两式）——90%；
# 结算后削对方下一次受击的防御 1（gu_drop_next 一次性——先打后削，本击不吃）。


func _init() -> void:
	id = "po_jia_quan"
	display_name = "破甲拳"
	kind = "attack"
	recipe = {"崩": 2}
	power = 90
	brief = "破甲拳：万门重刻两式·90%；命中后对方下次受击防御 −1。"


func _on_tech_resolve(_input: Dictionary) -> Dictionary:
	return {"debuff_gu_next": 1, "notes": ["破甲拳：对方下次受击防御 −1"]}
