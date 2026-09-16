class_name MJXinfa
extends RefCounted

# 心法基类（v3.5 构筑层·心法槽）：被动规则修改器。事件点由引擎直呼（与护体
# apply_defense 同型的小协议，不走事件总线——心法要改 fighter 状态，DTO 不便）。
# 子类覆盖事件方法；一人可持多门（槽位数＝心法槽上限）。


var id := ""
var display_name := ""


func summary() -> String:
	return display_name


# 招架成立（碰/杠/暗杠入副露）——拆招诀的挂点。
func on_claim_done(_f: MJFighter) -> void:
	pass
