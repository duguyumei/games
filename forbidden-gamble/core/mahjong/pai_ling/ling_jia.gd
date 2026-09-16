class_name LingJia
extends MJPaiLing

# 灵甲（挑战层首发牌灵，占位）：摸到绑定牌时，下次护体免伤 +10%（自持，
# start_iron 消费即清；叠加无上限、激活时钳于 100%）。


const IRON_BONUS := 10


func _init() -> void:
	id = "ling_jia"
	display_name = "灵甲"


func summary() -> String:
	return "灵甲·%s：摸到该牌时，下次护体免伤 +10%%" % (tile.key() if tile != null else "？")


func register(hooks: MJHooks, side: String) -> void:
	_wrap(hooks, side, MJHooks.TILE_DRAWN, _on_tile_drawn)


func _on_tile_drawn(input: Dictionary) -> Dictionary:
	for t in input.get("tiles", []):
		if tile != null and (t as MJTile).same(tile):
			return {"iron_bonus_next": IRON_BONUS}
	return {}
