class_name MJTechnique
extends RefCounted

# 功法基类（真气语法 v3.5；§12 纪律一：功法一类一文件——打开一个文件改完
# 配方、数值、词条、钩子全部侧面，加内容路径长度＝1）。
# 功法＝式的配方（如 点穴式＝点×1）；**倍率与词条固定，不挂牌面点数**（power＝倍率%）。
# 攻（功法槽）：吃式、占打出（每拍一门）、效果**在途**（v3.3：下次能够行动的那一刻自动发动，延迟＝式数）。
# 守（护身槽）：吃罡气、免费即时、**行动窗口内可放**（摸牌后或招架后、打出前）。
#
# 子类约定：_init 里填 id/display_name/kind/recipe/power/词条；按需覆盖 _on_* 虚方法。
# 钩子只对归属方（owner_side）的事件触发——基类注册时包装过滤。


var id := ""
var display_name := ""
var kind := "attack"  # "attack"（功法槽）| "defense"（护身槽）

# 攻功法：式配方（symbol -> 数量）——价格语言（式数同时定价默认前摇，v3.6）。
var recipe: Dictionary = {}
# 守功法（护体）：罡气价。
var gang_qi_cost := 0
# 前摇（v3.6）：按对方经过拍数计；0＝缺省取配方式数（sum of recipe values）。
# 到期在发射者自身摸牌后的自动效果阶段结算；在途期间不能发动防御。
var windup := 0

var tags: Array[String] = []
# 效果全文（浮窗详情用）：明码印刷在类内——一类一文件，打开即见这门功法全部侧面。
var brief := ""
# 重击倍率（百分比整数；v3.5：倍率住功法——同一门功夫内力深者威力不同，基数＝攻击面板）。
var power := 0

var owner_side := ""


func register(hooks: MJHooks, side: String) -> void:
	owner_side = side
	var wrap := func(event: String, method: String) -> void:
		hooks.on(event, self, func(input: Dictionary) -> Dictionary:
			if String(input.get("side", "")) != side:
				return {}
			return call(method, input))
	wrap.call(MJHooks.TECH_RESOLVE, "_on_tech_resolve")
	wrap.call(MJHooks.BEAT_END, "_on_beat_end")
	wrap.call(MJHooks.DAMAGE_DEALT, "_on_damage_dealt")


# 效果摘要（意图/应显示用，按数据生成不写死）。
func summary() -> String:
	if kind == "defense":
		return "%s（护体·罡气%d）" % [display_name, gang_qi_cost]
	var parts: Array[String] = []
	for symbol in recipe:
		parts.append("%s×%d" % [symbol, int(recipe[symbol])])
	return "%s（%s·%d%%）" % [display_name, "＋".join(parts), power]


# 护体即时效果（引擎在行动窗口内应用；罡气已扣、窗口闸已过）。
# Output 键：{notes: Array[String]}——铁布衫类在子类内改 fighter 护体状态。
func apply_defense(_fighter: MJFighter) -> Dictionary:
	return {}


# ———— 生命周期钩子（子类按需覆盖；返回值即 Output DTO）————

# 在途结算前（本方）——改倍率/断势/词条。
# Output 键：pct_bonus:int, break_enemy_pending:bool, notes:Array[String]
func _on_tech_resolve(input: Dictionary) -> Dictionary:
	return {}


func _on_beat_end(input: Dictionary) -> Dictionary:
	return {}


# 伤害落地后（input.side＝**受击方**，注意与 owner 的关系由子类自判）。
func _on_damage_dealt(input: Dictionary) -> Dictionary:
	return {}
