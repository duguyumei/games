class_name TechBengShan
extends MJTechnique

# 崩山式（占位）：崩×2 —— 双万刻重击（延迟 2 回合，v3.3：延迟＝式数）。数值全占位。


func _init() -> void:
	id = "beng_shan"
	display_name = "崩山式"
	kind = "attack"
	recipe = {"崩": 2}
	power = 10
