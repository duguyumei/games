class_name LingZhong
extends MJPaiLing

# 灵重（挑战层首发牌灵，占位）：绑定牌作为功法耗式入河时自持标记；
# 该功法在途结算倍率 +30%（跨事件自持，不加新协议键）。


const PCT_BONUS := 30


func _init() -> void:
	id = "ling_zhong"
	display_name = "灵重"


func summary() -> String:
	return "灵重·%s：该牌入功法耗式时，该功法结算 +30%%" % (tile.key() if tile != null else "？")


var _marked_tech := ""


func register(hooks: MJHooks, side: String) -> void:
	_wrap(hooks, side, MJHooks.TECH_FIRE, _on_tech_fire)
	_wrap(hooks, side, MJHooks.TECH_RESOLVE, _on_tech_resolve)


func _on_tech_fire(input: Dictionary) -> Dictionary:
	for t in input.get("tiles", []):
		if tile != null and (t as MJTile).same(tile):
			_marked_tech = String(input.get("tech_id", ""))
			return {}
	return {}


func _on_tech_resolve(input: Dictionary) -> Dictionary:
	if _marked_tech != "" and String(input.get("tech_id", "")) == _marked_tech:
		_marked_tech = ""
		return {"pct_bonus": PCT_BONUS}
	return {}
