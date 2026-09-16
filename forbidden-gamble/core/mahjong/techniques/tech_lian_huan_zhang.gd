class_name TechLianHuanZhang
extends MJTechnique

# 连环掌（挑战层新功法·功法槽，占位）：点×1（万门轻顺）——130%；对方带破绽时 +20%。
# 快攻重击线（一式速攻），与点穴式同配方不同倍率——破绽窗口的赏金猎手。


func _init() -> void:
	id = "lianhuan_zhang"
	display_name = "连环掌"
	kind = "attack"
	recipe = {"点": 1}
	power = 130
	brief = "连环掌：万门轻顺一式·130%；对方带破绽时 +20%。"


func _on_tech_resolve(input: Dictionary) -> Dictionary:
	if bool(input.get("opp_flawed", false)):
		return {"pct_bonus": 20, "notes": ["连环掌：对方露破绽 +20%"]}
	return {}
