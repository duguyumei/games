class_name TechDuanShiZhan
extends MJTechnique

# 断势斩（占位）：劈＋刺 跨门配方 —— 结算时击碎对方在途功法（断势词条示范）。
# 数值全占位。


func _init() -> void:
	id = "duan_shi_zhan"
	display_name = "断势斩"
	kind = "attack"
	recipe = {"劈": 1, "刺": 1}
	power = 4
	tags = ["断势"]


func _on_tech_resolve(input: Dictionary) -> Dictionary:
	# 钩子事件按 side 广播（同方多功法共享事件流），子类须自查 tech_id。
	if String(input.get("tech_id", "")) != id:
		return {}
	return {"damage_bonus": 0, "break_enemy_pending": true, "notes": ["断势：击碎对方在途功法"]}
