class_name TechDianLie
extends MJTechnique

# 点列式（占位）：点×1 —— 一式速攻（延迟 1 回合，最快落点；v3.3 快攻线）。
# 原占位配方 点×3（三回合延迟换 6 伤）判不成立改此，观察项见 v3 §10。数值全占位。


func _init() -> void:
	id = "dian_lie"
	display_name = "点列式"
	kind = "attack"
	recipe = {"点": 1}
	power = 3
