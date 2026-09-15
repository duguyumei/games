class_name MJTechnique
extends RefCounted

# 功法基类（真气语法 v3 §5；§12 纪律一：功法一类一文件——打开一个文件改完
# 配方、数值、词条、钩子全部侧面，加内容路径长度＝1）。
# 功法＝式的配方（如 崩山式＝崩×2），可跨式；**数值与词条固定，不挂牌面点数**。
# 攻：吃式、占行动权（每拍一门）、效果**在途**（v3.3：下次能够行动的那一刻自动发动，延迟＝式数）。
# 守：吃罡气、免费即时、**行动期间可放**（v3.4：自己这拍摸牌后、出牌前）。
#
# 子类约定：_init 里填 id/display_name/kind/recipe/power/词条；按需覆盖 _on_* 虚方法。
# 钩子只对归属方（owner_side）的事件触发——基类注册时包装过滤。


var id := ""
var display_name := ""
var kind := "attack"  # "attack" | "defense"

# 攻功法：式配方（symbol -> 数量）——价格语言（式数同时定价延迟，v3.3）。
var recipe: Dictionary = {}
# 守功法：罡气价（占位 3）。
var gang_qi_cost := 0

var tags: Array[String] = []
# 固定威力（不挂牌面点数；v3 §10 全占位待校准）。
var power := 0

var owner_side := ""


func register(hooks: MJHooks, side: String) -> void:
	owner_side = side
	var wrap := func(event: String, method: String) -> void:
		hooks.on(event, self, func(input: Dictionary) -> Dictionary:
			if String(input.get("side", "")) != side:
				return {}
			return call(method, input))
	wrap.call(MJHooks.SHIKI_BASIC, "_on_shiki_basic")
	wrap.call(MJHooks.TECH_RESOLVE, "_on_tech_resolve")
	wrap.call(MJHooks.BEAT_END, "_on_beat_end")
	wrap.call(MJHooks.DAMAGE_DEALT, "_on_damage_dealt")


# 效果摘要（意图/应显示用，按数据生成不写死）。
func summary() -> String:
	if kind == "defense":
		return "%s（守·罡气%d）" % [display_name, gang_qi_cost]
	var parts: Array[String] = []
	for symbol in recipe:
		parts.append("%s×%d" % [symbol, int(recipe[symbol])])
	var head := "%s（%s" % [display_name, "＋".join(parts)]
	if power > 0:
		head += "·伤%d" % power
	head += "）"
	return head


# 守功法即时效果（引擎在行动窗口内应用；罡气已扣）。
# Output 键：{guard_set: int, notes: Array[String]}——guard_set 覆盖护境（覆盖制）。
func apply_defense(_fighter: MJFighter) -> Dictionary:
	return {}


# ———— 生命周期钩子（子类按需覆盖；返回值即 Output DTO）————

# 式基本招触发（本方）——加伤等增幅。
func _on_shiki_basic(input: Dictionary) -> Dictionary:
	return {}


# 蓄力满、结算前（本方）——改伤害/断势/词条。
# Output 键：damage_bonus:int, guard_set:int(>=0 覆盖护境), break_enemy_pending:bool, notes:Array[String]
func _on_tech_resolve(input: Dictionary) -> Dictionary:
	return {}


func _on_beat_end(input: Dictionary) -> Dictionary:
	return {}


# 伤害落地后（input.side＝**受击方**，注意与 owner 的关系由子类自判）。
func _on_damage_dealt(input: Dictionary) -> Dictionary:
	return {}
