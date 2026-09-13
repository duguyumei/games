class_name ResolverTable
extends RefCounted

# 默认结算器表（纯机体结算，架构收口 2026-09-13）：CombatState 与
# TechniqueResolver 的临时管线共用一份——新增纯动作类型只改这里，不再双份漂移。
# 带状态/计数/钩子通知的结算（damage 的破盾与脑唤醒、status_apply 的词表注册、
# draw/breath 的气循环、initiative_seize）由宿主各自注册，不属于共享层。


static func register(pipe: EffectPipeline) -> void:
	pipe.register_resolver("hp_loss", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.hp = maxi(unit.hp - maxi(action.amount, 0), 0))
	pipe.register_resolver("heal", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.hp = mini(unit.hp + maxi(action.amount, 0), unit.max_hp))
	pipe.register_resolver("guard_set", func(action: GameAction) -> void:
		(action.target as FighterState).guard = maxi(action.amount, 0))
	pipe.register_resolver("guard_remove", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.guard = maxi(unit.guard - maxi(action.amount, 0), 0))
	pipe.register_resolver("guard_gain", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.guard = maxi(unit.guard + action.amount, 0))
