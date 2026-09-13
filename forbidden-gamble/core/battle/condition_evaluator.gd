class_name ConditionEvaluator
extends RefCounted

# 共用条件求值层（架构收口 2026-09-13）：牌面/棋盘条件一处求值，多处委托——
# 功法效果 when（TechniqueResolver）、敌方行为链梯 when、应手武装 arm。
# 新增条件键＝此处一个分支＋DataRepo 对应白名单，其余调用方零改动。
# 键表与 DataRepo（TECHNIQUE_WHEN_KEYS / ENEMY_LADDER_WHEN / ENEMY_ARM_KEYS）同步维护。
# 心法条件（XinfaRuntime）是动作语境族（once_per_breath/as_target 等挂在具体动作上），
# 暂不并轨——见其文件头注；并轨时把动作塞进 ctx.action 即可。

# 语境 ctx：{cards: Array（选入真气）, unit: FighterState（自况主体）}。
# 未知键告警并放行（运行期宽容；schema 在加载期拦截坏键）。
static func evaluate(when: Dictionary, ctx: Dictionary) -> bool:
	if when.is_empty():
		return true
	for key in when:
		match key:
			"attribute_gte":
				var spec: Dictionary = when[key]
				var need := int(spec.get("count", 1))
				var owned := 0
				for card in ctx.get("cards", []):
					if str((card as QiCard).attribute) == str(spec.get("attribute", "")):
						owned += 1
				if owned < need:
					return false
			"guard_lt":
				if _unit(ctx).guard >= int(when[key]):
					return false
			"guard_gt":
				if _unit(ctx).guard <= int(when[key]):
					return false
			"guard_gte":
				if _unit(ctx).guard < int(when[key]):
					return false
			"hp_lte":
				if _unit(ctx).hp > int(when[key]):
					return false
			"hp_gte":
				if _unit(ctx).hp < int(when[key]):
					return false
			"status_gte":
				var spec: Dictionary = when[key]
				for status_id in spec:
					if _unit(ctx).get_status(str(status_id)) < int(spec[status_id]):
						return false
			_:
				push_warning("ConditionEvaluator: 未知条件键 " + str(key))
	return true


static func _unit(ctx: Dictionary) -> FighterState:
	return ctx.get("unit", null)
