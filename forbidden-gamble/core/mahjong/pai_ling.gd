class_name MJPaiLing
extends RefCounted

# 牌灵基类（挑战层 v1.4 §4.6，参考我地麻宝牌/牌灵——绑具体牌种的效果件）：
# 一灵一文件；绑定牌种 tile（购入时 27 选 1，key 与 MJTile.key() 同型）；
# register 与 MJTechnique 同款 owner_side 包装过滤。Output 键见 hooks.gd 头注
# （TILE_DRAWN→gang_qi/iron_bonus_next；POSTURE→bian_charge；TECH_RESOLVE→pct_bonus）。
# 数值全占位。每牌种限一枚、每 id 限一枚（RunState.acquire_pailing 校验）。


var id := ""
var display_name := ""
var tile: MJTile


func summary() -> String:
	return display_name


# 共用包装：只听归属方事件。
func _wrap(hooks: MJHooks, side: String, event: String, callable: Callable) -> void:
	hooks.on(event, self, func(input: Dictionary) -> Dictionary:
		if String(input.get("side", "")) != side:
			return {}
		return callable.call(input))


func register(_hooks: MJHooks, _side: String) -> void:
	pass  # 子类按需订阅


static func make(id_str: String, suit: String, value: int) -> MJPaiLing:
	var ling: MJPaiLing = null
	match id_str:
		"ling_gang":
			ling = LingGang.new()
		"ling_zhong":
			ling = LingZhong.new()
		"ling_bian":
			ling = LingBian.new()
		"ling_jia":
			ling = LingJia.new()
	if ling != null and not suit.is_empty():
		ling.tile = MJTile.make(suit, value)
	return ling


# 全量名册（图鉴/交叉校验用；对局注入走 cfg {side}_pailing）
static func roster() -> Array[String]:
	return ["ling_gang", "ling_zhong", "ling_bian", "ling_jia"]
