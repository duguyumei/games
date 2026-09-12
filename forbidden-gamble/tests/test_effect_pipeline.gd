extends GutTest

# 动作管线地基测试：PRE 拦截可改可挡、RESOLVE 默认结算、POST 触发入队、
# 链长上限防死循环、毒状态端到端（数据载体→管线钩子→回合开始结算）。

func _fighter(fid: String, hp: int = 30) -> FighterState:
	return FighterState.new(fid, fid, hp)

func _damage_pipeline() -> EffectPipeline:
	var pipe := EffectPipeline.new()
	pipe.register_resolver("damage", func(action: GameAction) -> void:
		action.context["damage_result"] = (action.target as FighterState).take_damage(maxi(action.amount, 0)))
	return pipe

func _give_deck(unit: FighterState, n: int = 20) -> void:
	for i in range(n):
		unit.draw_pile.append(QiCard.new("%s_%d" % [unit.fighter_id, i], "火", 3))

# ---------- 管线基础 ----------

func test_damage_flows_through_pipeline() -> void:
	var pipe := _damage_pipeline()
	var target := _fighter("目标")
	pipe.submit(GameAction.new("damage", target, 7))
	assert_eq(target.hp, 23)

func test_pre_hook_modifies_amount() -> void:
	var pipe := _damage_pipeline()
	var target := _fighter("目标")
	pipe.register_hook({"carrier": "test:金钟罩", "on": "damage", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.amount = maxi(0, action.amount - 2)})
	pipe.submit(GameAction.new("damage", target, 7))
	assert_eq(target.hp, 25, "伤害-2 的拦截器应生效")

func test_pre_hook_cancels_action() -> void:
	var pipe := _damage_pipeline()
	var target := _fighter("目标")
	pipe.register_hook({"carrier": "test:免疫", "on": "damage", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.cancelled = true})
	pipe.submit(GameAction.new("damage", target, 7))
	assert_eq(target.hp, 30, "被取消的动作不应结算")

func test_hooks_fire_in_priority_order() -> void:
	var pipe := _damage_pipeline()
	var order: Array[String] = []
	pipe.register_hook({"carrier": "test:慢", "on": "damage", "phase": "pre", "priority": 10,
		"handler": func(_action: GameAction) -> void: order.append("慢")})
	pipe.register_hook({"carrier": "test:快", "on": "damage", "phase": "pre", "priority": -5,
		"handler": func(_action: GameAction) -> void: order.append("快")})
	pipe.submit(GameAction.new("damage", _fighter("目标"), 1))
	assert_eq(order, ["快", "慢"], "优先级数值小的先触发")

func test_post_hook_enqueues_new_action() -> void:
	var pipe := _damage_pipeline()
	pipe.register_resolver("heal", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.hp = mini(unit.max_hp, unit.hp + action.amount))
	var attacker := _fighter("攻击方")
	attacker.hp = 10
	var target := _fighter("目标")
	var pipe_ref: WeakRef = weakref(pipe)
	pipe.register_hook({"carrier": "test:吸血", "on": "damage", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void:
			var p: EffectPipeline = pipe_ref.get_ref()
			if p != null:
				p.submit(GameAction.new("heal", action.source, action.amount))})
	pipe.submit(GameAction.new("damage", target, 7, attacker))
	assert_eq(target.hp, 23)
	assert_eq(attacker.hp, 17, "吸血触发应入队并结算")

func test_chain_guard_caps_infinite_triggers() -> void:
	var pipe := EffectPipeline.new()
	pipe.register_resolver("ping", func(_action: GameAction) -> void: pass)
	var pipe_ref: WeakRef = weakref(pipe)
	pipe.register_hook({"carrier": "test:互触发", "on": "ping", "phase": "post", "priority": 0,
		"handler": func(_action: GameAction) -> void:
			var p: EffectPipeline = pipe_ref.get_ref()
			if p != null:
				p.submit(GameAction.new("ping"))})
	pipe.submit(GameAction.new("ping"))
	var text := ""
	for event in pipe.drain_events():
		text += event
	assert_true(text.contains("截断"), "互触发死循环应被链长上限截断")

func test_is_alive_gates_hook() -> void:
	var pipe := _damage_pipeline()
	var target := _fighter("目标")
	var enabled := [true]
	pipe.register_hook({"carrier": "test:开关", "on": "damage", "phase": "pre", "priority": 0,
		"is_alive": func() -> bool: return enabled[0],
		"handler": func(action: GameAction) -> void: action.amount = 0})
	pipe.submit(GameAction.new("damage", target, 5))
	assert_eq(target.hp, 30, "载体存活时钩子生效")
	enabled[0] = false
	pipe.submit(GameAction.new("damage", target, 5))
	assert_eq(target.hp, 25, "载体消亡后钩子不再触发")

# ---------- 毒：数据载体端到端 ----------

func test_poison_ticks_and_decays_via_combat() -> void:
	var player := _fighter("玩家")
	var enemy := _fighter("敌人")
	_give_deck(player)
	_give_deck(enemy)
	var combat := CombatState.new(player, enemy)
	var turn_manager := TurnManager.new(combat, 1)
	turn_manager.start_battle()
	var apply := GameAction.new("status_apply", enemy, 2)
	apply.context["status"] = "poison"
	combat.pipeline.submit(apply)
	assert_eq(enemy.get_status("poison"), 2, "上毒 2 层")
	turn_manager.drain_messages()
	_breathe(combat, enemy)  # 毒随本人调息发作（D-063）
	assert_eq(enemy.hp, 28, "敌方调息时毒发 2 点")
	assert_eq(enemy.get_status("poison"), 1, "毒发后递减")
	_breathe(combat, enemy)
	assert_eq(enemy.hp, 27, "第二次毒发 1 点")
	assert_eq(enemy.get_status("poison"), 0, "毒尽消散")
	_breathe(combat, enemy)
	assert_eq(enemy.hp, 27, "毒尽后不再掉血")

func test_apply_status_via_pipeline() -> void:
	# v1 九门无上状态功法；状态施加走管线动作（功法将来的挂点同一条路）
	var user := _fighter("用户")
	var target := _fighter("目标")
	var pipe := EffectPipeline.new()
	pipe.register_resolver("status_apply", func(action: GameAction) -> void:
		(action.target as FighterState).add_status(str(action.context.get("status", "")), action.amount))
	var apply := GameAction.new("status_apply", target, 2, user)
	apply.context["status"] = "poison"
	pipe.submit(apply)
	assert_eq(target.get_status("poison"), 2, "管线应上毒 2 层")

# ---------- 管线化后行为不变 ----------

func test_technique_damage_unchanged_without_pipeline() -> void:
	# 不传管线（纯函数式调用）时伤害结算与管线路径一致
	var user := _fighter("用户")
	var target := _fighter("目标")
	target.guard = 8
	var cards := [QiCard.new("c3", "火", 1)]
	var result := TechniqueResolver.resolve("点星式", cards, user, target)
	assert_true(bool(result.get("ok", false)))
	assert_eq(int(result.get("damage", 0)), 6, "下品量0：6+3×0")
	assert_eq(target.hp, 30, "6 点伤害全被护境挡住")
	assert_eq(target.guard, 2)

# ---------- 点位目录：伤害 vs 失去气血、抽象时点 ----------

func test_hp_loss_bypasses_guard() -> void:
	var pipe := _damage_pipeline()
	pipe.register_resolver("hp_loss", func(action: GameAction) -> void:
		var unit: FighterState = action.target
		unit.hp = maxi(unit.hp - maxi(action.amount, 0), 0))
	var target := _fighter("目标")
	target.guard = 10
	pipe.submit(GameAction.new("hp_loss", target, 4))
	assert_eq(target.hp, 26, "失去气血绕开护境")
	assert_eq(target.guard, 10, "护境不消耗")

func test_damage_and_hp_loss_are_separate_points() -> void:
	var pipe := _damage_pipeline()
	var fired: Array[String] = []
	pipe.register_hook({"carrier": "test", "on": "damage", "phase": "pre", "priority": 0,
		"handler": func(_action: GameAction) -> void: fired.append("damage")})
	pipe.register_hook({"carrier": "test", "on": "hp_loss", "phase": "pre", "priority": 0,
		"handler": func(_action: GameAction) -> void: fired.append("hp_loss")})
	pipe.submit(GameAction.new("hp_loss", _fighter("目标"), 1))
	assert_eq(fired, ["hp_loss"], "hp_loss 不触发 damage 钩子")

func test_poison_bypasses_guard_via_combat() -> void:
	var player := _fighter("玩家")
	var enemy := _fighter("敌人")
	_give_deck(player)
	_give_deck(enemy)
	var combat := CombatState.new(player, enemy)
	var turn_manager := TurnManager.new(combat, 1)
	turn_manager.start_battle()
	var apply := GameAction.new("status_apply", enemy, 2)
	apply.context["status"] = "poison"
	combat.pipeline.submit(apply)
	enemy.guard = 10
	_breathe(combat, enemy)
	assert_eq(enemy.hp, 28, "毒发是失去气血，护境不挡")
	assert_eq(enemy.guard, 10, "护境不被毒发消耗")

func test_battle_start_point_fires() -> void:
	var player := _fighter("玩家")
	var enemy := _fighter("敌人")
	_give_deck(player)
	_give_deck(enemy)
	var combat := CombatState.new(player, enemy)
	var fired := [false]
	combat.pipeline.register_hook({"carrier": "test", "on": "battle_start", "phase": "post", "priority": 0,
		"handler": func(_action: GameAction) -> void: fired[0] = true})
	var turn_manager := TurnManager.new(combat, 1)
	turn_manager.start_battle()
	assert_true(fired[0], "战斗开始点位应触发")

func test_technique_use_point_fires() -> void:
	var player := _fighter("玩家")
	var enemy := _fighter("敌人")
	_give_deck(player)
	_give_deck(enemy)
	var combat := CombatState.new(player, enemy)
	var seen: Array[String] = []
	combat.pipeline.register_hook({"carrier": "test", "on": "technique_use", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void: seen.append(str(action.context.get("technique", "")))})
	var turn_manager := TurnManager.new(combat, 1)
	turn_manager.start_battle()
	# 起手五张都是 火3，任选两张成同属性对发动二重·壁
	var cards := [combat.player.hand[0], combat.player.hand[1]]
	var result := turn_manager.player_act("二重·壁", cards)
	assert_true(bool(result.get("ok", false)))
	assert_eq(seen, ["二重·壁"], "发动功法点位应带着功法名触发")

# ---------- 真气卡状态词条 ----------

func test_qi_card_carries_statuses() -> void:
	var card := QiCard.new("q1", "火", 3)
	card.add_status("poison", 2)
	assert_eq(card.get_status("poison"), 2)
	card.add_status("poison", -1)
	assert_eq(card.get_status("poison"), 1)
	card.add_status("poison", -1)
	assert_eq(card.get_status("poison"), 0)
	assert_false(card.statuses.has("poison"), "归 0 清除词条")

# 直接对某单位提交一次调息动作（amount 0＝只吐故不纳新），驱动 breath 时点结算。
func _breathe(combat: CombatState, unit: FighterState) -> void:
	var action := GameAction.new("breath", unit, 0, unit)
	action.context["rng"] = RandomNumberGenerator.new()
	combat.pipeline.submit(action)
