class_name TechDianXue
extends MJTechnique

# 点穴式（v3.5 基础功法·功法槽，数值占位）：点×1（万门轻顺）——200% 伤害。
# 一式速攻：延迟 1 回合，重击线的最快落点（快攻线）。


func _init() -> void:
	id = "dian_xue"
	display_name = "点穴式"
	kind = "attack"
	recipe = {"点": 1}
	power = 200  # 倍率%（v3.5：倍率住功法，基数＝攻击面板）
