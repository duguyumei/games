class_name GameAction
extends RefCounted

# 管线中流转的动作对象。PRE（拦截）阶段可修改 amount/tags，也可 cancel。
# 动作类型示例：damage / heal / status_apply / draw / round_start。

var type := ""
var source: Variant = null       # 来源（FighterState、载体 id……管线不关心）
var target: Variant = null       # 目标（通常是 FighterState）
var amount := 0
var tags: Array[String] = []
var cancelled := false
var context: Dictionary = {}     # 附加信息（功法 id、随机数器、结算回写等）

func _init(new_type: String = "", new_target: Variant = null, new_amount: int = 0, new_source: Variant = null) -> void:
	type = new_type
	target = new_target
	amount = new_amount
	source = new_source
