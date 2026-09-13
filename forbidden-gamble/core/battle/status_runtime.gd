class_name StatusRuntime
extends RefCounted

# 状态效果的载体运行时：读 data/statuses.json，把状态注册成管线钩子。
# 载体 = 数据；管线不关心钩子来自状态、内功还是装备——都由这里注册成同一形态。
# 状态数据经 DataRepo 统一加载（缓存可失效，替代原先永不失效的静态缓存）。

var _pipeline: EffectPipeline
var _registered: Array[String] = []    # "fighter_id:status_id"，防止重复注册

static func status_name(status_id: String) -> String:
	return str(DataRepo.statuses().get(status_id, {}).get("name", status_id))

static func status_data(status_id: String) -> Dictionary:
	return DataRepo.statuses().get(status_id, {})

func _init(pipeline: EffectPipeline) -> void:
	_pipeline = pipeline

# 状态落到目标身上时调用：按数据把该状态注册成管线钩子（同一目标同一状态只注册一次）。
func ensure_hooks(unit: FighterState, status_id: String) -> void:
	var data := status_data(status_id)
	if data.is_empty():
		return
	var key := "%s:%s" % [unit.fighter_id, status_id]
	if _registered.has(key):
		return
	_registered.append(key)
	_pipeline.register_hook({
		"carrier": "status:%s:%s" % [status_id, unit.fighter_id],
		"on": str(data.get("on", "round_start")),
		"phase": str(data.get("phase", "post")),
		"priority": int(data.get("priority", 0)),
		"is_alive": func() -> bool: return unit.get_status(status_id) > 0,
		"handler": _build_handler(unit, status_id, data),
	})

# 由数据构建状态的行为：amount=stacks 表示按层数结算/修正，decay 表示每次触发后递减层数。
# damage_modify 型挂在伤害 PRE：as=target（体——受击方修正，游身/体走这路）、
# as=attacker（力——出招方修正）。amount 为数字＝固定值，为 "stacks"＝按当前层数。
# 注意：handler 用弱引用拿管线，避免 pipeline→hook→lambda→pipeline 循环引用泄漏。
func _build_handler(unit: FighterState, status_id: String, data: Dictionary) -> Callable:
	var pipeline_ref: WeakRef = weakref(_pipeline)
	return func(action: GameAction) -> void:
		var pipe: EffectPipeline = pipeline_ref.get_ref()
		if pipe == null:
			return
		# breath 时点（D-063）：状态只随本人的调息发作——别人的喘气不催你的毒
		var on_point := str(data.get("on", ""))
		if on_point == "breath" and action.target != unit:
			return
		# damage_modify（力/体/游身）：按 as 方向挂在伤害 PRE 修正 amount
		if str(data.get("action", "")) == "damage_modify":
			var as_role := str(data.get("as", "target"))
			if as_role == "target" and action.target != unit:
				return
			if as_role == "attacker" and action.source != unit:
				return
			var stacks_now := unit.get_status(status_id)
			if stacks_now <= 0:
				return
			var delta := int(data.get("amount", 0))
			if str(data.get("amount", "")) == "stacks":
				delta = stacks_now
			action.amount = maxi(action.amount + delta, 0)
			if as_role == "target" and delta < 0:
				pipe.events.append("%s游身避开，伤害减免至%d。" % [unit.display_name, action.amount])
			var decay_now := int(data.get("decay", 0))
			if decay_now != 0:
				unit.add_status(status_id, -decay_now)
				if unit.get_status(status_id) <= 0:
					pipe.events.append("%s的%s消散了。" % [unit.display_name, status_name(status_id)])
			return
		var stacks := unit.get_status(status_id)
		if stacks <= 0:
			return
		# amount=stacks 表示按层数结算，action 决定走哪个点位（damage 可被护境挡 / hp_loss 绕开护境）。
		if str(data.get("amount", "")) == "stacks":
			var tick := GameAction.new(str(data.get("action", "damage")), unit, stacks)
			tick.tags = [status_id]
			pipe.submit(tick)
			if tick.type == "hp_loss":
				pipe.events.append("%s 的%s发作，失去 %d 点气血。" % [unit.display_name, status_name(status_id), stacks])
			else:
				pipe.events.append("%s 受到 %d 点%s伤害。" % [unit.display_name, stacks, status_name(status_id)])
		var decay := int(data.get("decay", 0))
		if decay != 0:
			unit.add_status(status_id, -decay)
			if unit.get_status(status_id) <= 0:
				pipe.events.append("%s 的%s消散了。" % [unit.display_name, status_name(status_id)])
