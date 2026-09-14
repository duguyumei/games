extends GutTest

# 管线纯化（流动制时代延续）：夺取/护境动作化 + 通用取消词 + 方向条件 +
# 持有方优先排序。先机诀作为数据落地的行为验证（v2.2：被袭击时夺取先手）。
# 真气语法 v2：本命填 destiny_pile、二重·壁吃刻子。start_battle(false) 关洗牌保证确定性。

func _fighter(id: String, xinfa_list: Array = [], techniques: Array = ["二重·壁", "点星式"]) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	fighter.xinfa.assign(xinfa_list)
	return fighter

func _fire_triple(prefix: String) -> Array:
	var cards: Array = []
	for index in range(3):
		cards.append(QiCard.new("%s%d" % [prefix, index], "火", 3))
	return cards

func _destiny(prefix := "p") -> Array:
	# 本命 10 张（倒序无关——前三口必是火3 刻子以外的补充，凑不凑型不重要）
	var cards: Array = _fire_triple(prefix)
	for index in range(7):
		cards.append(QiCard.new("%sx%d" % [prefix, index], "风", 4))
	return cards

func _start(player: FighterState, enemy: FighterState, enemy_first := false) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false, enemy_first)
	return tm

# ---------- 引擎纯度：夺取是可拦截的动作（开战时点专用：被袭击夺回先手） ----------

func test_seize_action_flips_side() -> void:
	var player := _fighter("p")
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	var seize := GameAction.new("initiative_seize", enemy, 0, enemy)
	combat.pipeline.submit(seize)
	assert_eq(combat.active_side, "enemy", "夺取动作结算后持有方翻转")
	assert_string_contains("".join(combat.pipeline.drain_events()), "夺得先手")

func test_seize_can_be_cancelled() -> void:
	var player := _fighter("p")
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	combat.pipeline.register_hook({"carrier": "test", "on": "initiative_seize", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.cancelled = true})
	var seize := GameAction.new("initiative_seize", enemy, 0, enemy)
	combat.pipeline.submit(seize)
	assert_eq(combat.active_side, "player", "夺取被拦截：持有方不变")

# ---------- 引擎纯度：护境动作可拦截 ----------

func test_guard_set_interceptable() -> void:
	var player := _fighter("p")
	player.hand = _fire_triple("h")
	player.destiny_pile = _destiny()
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	combat.pipeline.register_hook({"carrier": "test", "on": "guard_set", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.cancelled = true})
	var result := TechniqueResolver.resolve("二重·壁", [player.hand[0], player.hand[1], player.hand[2]], player, enemy, combat.pipeline)
	assert_true(bool(result.get("ok", false)))
	assert_eq(player.guard, 0, "护境布设被拦：覆盖不生效")
	assert_string_contains(str(result.get("effect", "")), "被拦")

func test_guard_remove_interceptable() -> void:
	var player := _fighter("p")
	var enemy := _fighter("e")
	enemy.guard = 20
	var combat := CombatState.new(player, enemy)
	combat.pipeline.register_hook({"carrier": "test", "on": "guard_remove", "phase": "pre", "priority": 0,
		"handler": func(action: GameAction) -> void: action.cancelled = true})
	combat.pipeline.submit(GameAction.new("guard_remove", enemy, 5, player))
	assert_eq(enemy.guard, 20, "护境移除被拦：数值不动")

# ---------- 引擎纯度：持有方钩子优先（§11.5） ----------

func test_holder_side_hooks_run_first() -> void:
	var player := _fighter("p")
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	var order: Array = []
	combat.pipeline.register_hook({"carrier": "test:p", "side": "player", "on": "damage", "phase": "pre", "priority": 0,
		"handler": func(_action: GameAction) -> void: order.append("player")})
	combat.pipeline.register_hook({"carrier": "test:e", "side": "enemy", "on": "damage", "phase": "pre", "priority": 0,
		"handler": func(_action: GameAction) -> void: order.append("enemy")})
	combat.pipeline.acting_side = "enemy"
	combat.pipeline.submit(GameAction.new("damage", player, 1, enemy))
	assert_eq(order, ["enemy", "player"], "持有方钩子先结算，无视注册先后")

# ---------- 方向条件（事件归属） ----------

func test_direction_conditions() -> void:
	var player := _fighter("p")
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	var runtime := combat.xinfa_runtime
	var when_enemy := {"target_is_enemy": true}
	var gain_for_enemy := GameAction.new("initiative_gain", enemy, 0, enemy)
	var gain_for_player := GameAction.new("initiative_gain", player, 0, player)
	assert_true(runtime._conditions_met(when_enemy, player, gain_for_enemy), "敌方获得行动权→通过")
	assert_false(runtime._conditions_met(when_enemy, player, gain_for_player), "自己获得行动权→不通过")
	var when_source := {"source_is_enemy": true}
	var from_enemy := GameAction.new("damage", player, 1, enemy)
	var from_player := GameAction.new("damage", enemy, 1, player)
	assert_true(runtime._conditions_met(when_source, player, from_enemy))
	assert_false(runtime._conditions_met(when_source, player, from_player))

# ---------- 先机诀：被袭击时夺取先手（玩家侧） ----------

func test_xianjijue_recovers_from_ambush() -> void:
	var player := _fighter("p", ["先机诀"])
	player.destiny_pile = _destiny()
	var enemy := _fighter("e")
	var tm := _start(player, enemy, true)
	assert_eq(tm.combat.active_side, "player", "被袭击时先机诀夺回第一次行动权")

func test_xianjijue_single_gain_at_start() -> void:
	var player := _fighter("p", ["先机诀"])
	player.destiny_pile = _destiny()
	var enemy := _fighter("e")
	var combat := CombatState.new(player, enemy)
	var gained: Array = []
	combat.pipeline.register_hook({"carrier": "test", "on": "initiative_gain", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void: gained.append((action.target as FighterState).fighter_id)})
	var tm := TurnManager.new(combat)
	tm.start_battle(false, true)  # 被袭击＋玩家先机诀：夺取翻回玩家
	assert_eq(gained, ["p"], "只有被动获得方收一次 gain（夺取本身不发 gain）")

# ---------- 词表校验 ----------

func test_cancel_requires_pre_phase() -> void:
	var pack := {
		"items.json": {}, "enemies.json": {},
		"techniques.json": {}, "statuses.json": {},
		"xinfa.json": {
			"坏词": {"tier": 1, "school": "通用", "desc": "x", "effects": [
				{"on": "damage", "phase": "post", "do": {"type": "cancel"}}]},
			"坏词2": {"tier": 1, "school": "通用", "desc": "x", "effects": [
				{"on": "swap", "phase": "post", "do": {"type": "amount_bonus", "value": 1}}]},
		},
	}
	var errs := DataRepo.validate_pack(pack)
	var joined := "；".join(errs)
	assert_string_contains(joined, "cancel 只在 pre 相位合法")
	assert_string_contains(joined, "amount_bonus 只在 pre 相位合法")

func test_xianjijue_rule_text_generated() -> void:
	var text := XinfaRuntime.effect_text("先机诀")
	assert_string_contains(text, "战斗开始时")
	assert_string_contains(text, "夺取行动权")
