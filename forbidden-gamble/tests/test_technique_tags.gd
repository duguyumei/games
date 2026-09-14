extends GutTest

# 词条族（真气语法 v2）：压制＝给对方施加破绽（缠丝劲承载）；冷却 N＝后续 N 次
# 自己的原子行动内不可再发动（磨刃式承载）；蓄力＝跨拍动作（蓄势斩承载）：
# 起手占行动权、充能拍让权、满值自动发动；蓄力是全承诺——起蓄不可换功法，
# 护盾被击碎不销毁蓄力（断势退役，打断＝内容动词）。

const HIT_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "风", "value": 3}],
	"deck": {"风": {"3": 2, "4": 2}},
	"ladder": [{"technique": "架势"}],
}

const SMASH_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "风", "value": 6}, {"attribute": "风", "value": 7}, {"attribute": "风", "value": 8}],
	"deck": {"风": {"4": 2}},
	"ladder": [{"technique": "点星式"}, {"technique": "架势"}],
}

func _fighter(id: String, techniques: Array) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	return fighter

func _kezi_destiny(prefix: String, value := 3) -> Array:
	# 本命倒序（尾部先入丹田）：开局前三口＝火3 刻子
	var cards: Array = []
	for index in range(5):
		cards.append(QiCard.new("%sf%d" % [prefix, index], "风", 4))
	for index in range(3):
		cards.append(QiCard.new("%sk%d" % [prefix, index], "火", 3))
	return cards

func _enemy(def: Dictionary = HIT_DEF, hp := 60) -> FighterState:
	var fighter := FighterState.new("e", "e", hp)
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func _start(player: FighterState, enemy: FighterState) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false)
	return tm

# ---------- 压制（＝施加破绽） ----------

func test_chansi_suppression_applies_flaw() -> void:
	# 缠丝劲＝刻子·压制：发动后对方获得破绽（跳过下次获得行动权）＝玩家换节拍再动
	var player := _fighter("p", ["缠丝劲", "点星式"])
	player.destiny_pile = _kezi_destiny("p")
	var tm := _start(player, _enemy())
	var kezi := TechniqueResolver.find_legal_selection("缠丝劲", player.hand, player)
	assert_eq(kezi.size(), 3, "开局应有火3 刻子")
	var result := tm.player_act("缠丝劲", kezi)
	assert_true(bool(result.get("ok", false)))
	assert_string_contains(str(result.get("effect", "")), "破绽")
	assert_eq(tm.combat.active_side, "player", "对方破绽跳一拍：玩家连动（换节拍）")
	assert_false(tm.combat.enemy.flawed, "破绽即查即耗")

# ---------- 冷却（磨刃式：刻子·力+1·冷却1） ----------

func test_cooldown_gates_next_action() -> void:
	var player := _fighter("p", ["磨刃式", "点星式"])
	player.destiny_pile = _kezi_destiny("p")
	var tm := _start(player, _enemy())
	var kezi := TechniqueResolver.find_legal_selection("磨刃式", player.hand, player)
	assert_eq(kezi.size(), 3)
	tm.player_act("磨刃式", kezi)
	assert_eq(int(player.technique_cooldowns.get("磨刃式", 0)), 1, "冷却 1 自此刻起算")
	assert_false(TechniqueResolver.can_use("磨刃式", kezi, player), "冷却中门控生效")
	# 冷却 1＝下一次自己的原子行动内不可再发动，之后解锁：
	# 敌方动 → 玩家换牌（行动开始 tick 冷却 1→0）→ 可再发动
	tm.enemy_act()
	tm.player_swap([0])
	assert_eq(int(player.technique_cooldowns.get("磨刃式", 0)), 0, "一次行动后冷却归零")
	assert_true(TechniqueResolver.can_use("磨刃式", kezi, player), "冷却归零后可再发")

# ---------- 蓄力生命周期（蓄势斩＝刻子·蓄力1） ----------

func test_shushi_charge_lifecycle() -> void:
	var player := _fighter("p", ["蓄势斩", "点星式"])
	player.destiny_pile = _kezi_destiny("p")
	var tm := _start(player, _enemy())
	var kezi := TechniqueResolver.find_legal_selection("蓄势斩", player.hand, player)
	assert_eq(kezi.size(), 3)
	var started := tm.player_act("蓄势斩", kezi)
	assert_true(bool(started.get("ok", false)))
	assert_eq(str(started.get("action", "")), "charge_started", "蓄力起手不立即结算")
	assert_true(player.has_active_charge(), "蓄力态建立")
	assert_eq((player.charging.get("cards", []) as Array).size(), 3, "选入真气入招")
	assert_eq(tm.combat.active_side, "enemy", "起手让权——曝光开始")
	# 蓄力 0/1：敌方动 → 玩家充能拍（+1 即满，自动发动）
	tm.enemy_act()
	var fired := tm.player_charge_tick()
	assert_eq(str(fired.get("action", "")), "technique", "满值自动发动（走功法结算）")
	assert_false(player.has_active_charge(), "蓄力态清空")
	assert_eq(int(fired.get("damage", 0)), 4 + 9, "火3 刻子和9：4+1×9")
	assert_eq(tm.combat.enemy.hp, 60 - 13, "60 血敌方余 47")
	assert_eq(tm.combat.active_side, "enemy", "发动后照常让权")

func test_charge_survives_guard_shatter() -> void:
	# 断势退役：蓄力是全承诺——护盾被击碎不销毁蓄力；蓄力期间玩家不能换功法。
	var player := _fighter("p", ["蓄势斩", "点星式"])
	player.destiny_pile = _kezi_destiny("p")
	player.guard = 20
	var tm := _start(player, _enemy(SMASH_DEF))
	var kezi := TechniqueResolver.find_legal_selection("蓄势斩", player.hand, player)
	tm.player_act("蓄势斩", kezi)
	assert_true(player.has_active_charge())
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()  # 点星式风678＝23 点砸穿 20 盾
	assert_eq(tm.combat.player.guard, 0, "护盾被击碎")
	assert_true(player.has_active_charge(), "断势退役：蓄力不散（全承诺）")
	assert_false(TechniqueResolver.can_use("点星式", [player.hand[0], player.hand[1], player.hand[2]], player), "蓄力期间不可换功法")
	var fired := tm.player_charge_tick()
	assert_eq(str(fired.get("action", "")), "technique", "充能照常推进满值发动")

# ---------- 蓄力失效兜底 ----------

func test_charge_fizzle_scatters_cards() -> void:
	# 直接改写 charging 模拟结算失效兜底路径
	var player := _fighter("p", ["点星式"])
	player.destiny_pile = _kezi_destiny("p")
	var tm := _start(player, _enemy())
	player.charging = {"technique": "不存在的功法", "charge": 1, "need": 2, "cards": [QiCard.new("x1", "风", 3)]}
	var r := tm.player_charge_tick()
	assert_false(bool(r.get("ok", false)), "不存在的功法结算失败")
	assert_false(player.has_active_charge(), "蓄力态已清")
