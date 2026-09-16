class_name LingGang
extends MJPaiLing

# 灵罡（挑战层首发牌灵，占位）：摸到绑定牌（任意来路：正常/破绽/缺补/岭上）时罡气 +1。


func _init() -> void:
	id = "ling_gang"
	display_name = "灵罡"


func summary() -> String:
	return "灵罡·%s：摸到该牌时罡气 +1" % (tile.key() if tile != null else "？")


func register(hooks: MJHooks, side: String) -> void:
	_wrap(hooks, side, MJHooks.TILE_DRAWN, _on_tile_drawn)


func _on_tile_drawn(input: Dictionary) -> Dictionary:
	for t in input.get("tiles", []):
		if tile != null and (t as MJTile).same(tile):
			return {"gang_qi": 1}
	return {}
