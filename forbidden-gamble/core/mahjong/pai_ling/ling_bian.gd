class_name LingBian
extends MJPaiLing

# 灵变（挑战层首发牌灵，占位）：打出批次（虚招/普攻/反击）含绑定牌时，变招充能 +1。


func _init() -> void:
	id = "ling_bian"
	display_name = "灵变"


func summary() -> String:
	return "灵变·%s：打出该牌时变招充能 +1" % (tile.key() if tile != null else "？")


func register(hooks: MJHooks, side: String) -> void:
	_wrap(hooks, side, MJHooks.POSTURE, _on_posture)


func _on_posture(input: Dictionary) -> Dictionary:
	for t in input.get("batch", []):
		if tile != null and (t as MJTile).same(tile):
			return {"bian_charge": 1}
	return {}
