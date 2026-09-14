extends GutTest

# 心法系统测试（真气语法 v2.2）：调息→换牌→架势重键后，先纳功/龟息功/养木功/盘根诀/先机诀
# 五门存活（调息诀/气海无涯/化浊诀随品级与调息模型退役，2026-09-14）。
# swap 时点词条只随本人的架势触发；牌堆从尾部抽；start_battle(false) 关洗牌。

func _fighter(id: String, xinfa_list: Array = [], techniques: Array = ["点星式", "二重·壁"]) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	fighter.xinfa.assign(xinfa_list)
	return fighter

func _enemy_fighter() -> FighterState:
	var fighter := FighterState.new("e", "靶子", 30)
	EncounterLoader.fill_enemy_body(fighter, {
		"swap_policy": "all",
		"hand": [{"attribute": "风", "value": 3}],
		"deck": {"风": {"3": 2, "4": 2, "5": 2}},
		"ladder": [{"technique": "架势"}],
	})
	return fighter

func _combat(player: FighterState, enemy: FighterState) -> CombatState:
	return CombatState.new(player, enemy)

# ---------- battle_start 词条 ----------

func test_xiannagong_draws_extra_card_on_battle_start() -> void:
	var player := _fighter("p", ["先纳功"])
	var destiny: Array = []
	for value in [4, 3, 4, 5, 3, 2, 7, 8]:
		destiny.append(QiCard.new("p%d" % value, "风", value))
	player.destiny_pile = destiny
	var tm := TurnManager.new(_combat(player, _enemy_fighter()))
	tm.start_battle(false)
	assert_eq(player.hand.size(), TurnManager.DANTIAN_SIZE + 1, "先纳功：战斗开始额外从气海多纳 1 口")

# ---------- damage 词条 ----------

func test_guixi_resists_every_hit() -> void:
	var player := _fighter("p", ["龟息功"])
	var combat := _combat(player, _enemy_fighter())
	combat.pipeline.submit(GameAction.new("damage", player, 7, combat.enemy))
	assert_eq(player.hp, 24, "龟息功：每次受到的伤害 −1（30-6）")
	combat.pipeline.submit(GameAction.new("damage", player, 7, combat.enemy))
	assert_eq(player.hp, 18, "龟息功非 once 类，第二次同样减伤")

# ---------- swap 词条（原调息锚，现＝架势） ----------

func _swap_action(combat: CombatState, unit: FighterState) -> void:
	# 直接提交 swap 动作（不弃牌只走时点），驱动换牌时点结算
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var action := GameAction.new("swap", unit, 0, unit)
	action.context["rng"] = rng
	action.context["discard_indices"] = []
	combat.pipeline.submit(action)

func test_pangen_guards_each_swap() -> void:
	var player := _fighter("p", ["盘根诀"])
	var combat := _combat(player, _enemy_fighter())
	assert_eq(player.guard, 0, "盘根诀是换牌词条，战斗开始不触发")
	_swap_action(combat, player)
	assert_eq(player.guard, 2, "换牌时护境 +2")
	_swap_action(combat, player)
	assert_eq(player.guard, 4, "再换牌再 +2")

func test_yangmu_heals_each_swap() -> void:
	var player := _fighter("p", ["养木功"])
	var combat := _combat(player, _enemy_fighter())
	player.hp = 20
	_swap_action(combat, player)
	assert_eq(player.hp, 21, "养木功：换牌回 1 气血")
	_swap_action(combat, player)
	assert_eq(player.hp, 22, "再换牌再回 1")

# 方向回归：换牌锚心法只随本人换牌触发
func test_swap_xinfa_not_fired_by_enemy_swap() -> void:
	var player := _fighter("p", ["盘根诀", "养木功"])
	var enemy := _enemy_fighter()
	var combat := _combat(player, enemy)
	player.hp = 20
	_swap_action(combat, enemy)
	assert_eq(player.guard, 0, "敌方换牌不触发我方盘根诀")
	assert_eq(player.hp, 20, "敌方换牌不触发我方养木功")
	_swap_action(combat, player)
	assert_eq(player.guard, 2, "本人换牌照常触发盘根诀")
	assert_eq(player.hp, 21, "本人换牌照常触发养木功")

# ---------- 面板助手与 schema ----------

func test_effect_text_generated_from_data() -> void:
	var text := XinfaRuntime.effect_text("龟息功")
	assert_string_contains(text, "伤害结算时")
	assert_string_contains(text, "受到的伤害−1")
	var text2 := XinfaRuntime.effect_text("盘根诀")
	assert_string_contains(text2, "每次架势时")
	assert_string_contains(text2, "护境+2")
	var text3 := XinfaRuntime.effect_text("养木功")
	assert_string_contains(text3, "每次架势时")
	assert_string_contains(text3, "回气1")

func test_equipped_school_count() -> void:
	var v1_schools := ["先机诀", "养木功", "盘根诀"]
	assert_eq(XinfaRuntime.equipped_school_count(v1_schools, "风"), 1, "先机诀计风系")
	assert_eq(XinfaRuntime.equipped_school_count(v1_schools, "通用"), 2, "养木功/盘根诀改通用系")
	assert_eq(XinfaRuntime.equipped_school_count(["先纳功"], "风"), 0, "通用系不计入风系")

func test_validate_pack_rejects_bad_xinfa() -> void:
	var pack := {
		"items.json": DataRepo.items(),
		"enemies.json": DataRepo.enemies(),
		"techniques.json": DataRepo.techniques(),
		"statuses.json": DataRepo.statuses(),
		"xinfa.json": {
			"坏心法": {
				"tier": 9, "school": "雷", "desc": "",
				"effects": [{ "on": "不存在的时机", "do": { "type": "乱来" } }]
			}
		},
	}
	var errs := DataRepo.validate_pack(pack)
	var joined := "；".join(errs)
	assert_string_contains(joined, "tier")
	assert_string_contains(joined, "未知系别")
	assert_string_contains(joined, "desc")
	assert_string_contains(joined, "未知时机")
	assert_string_contains(joined, "未知动作类型")

func test_player_def_carries_xinfa() -> void:
	var player := EncounterLoader.load_player("res://data/player.json")
	assert_eq(player.xinfa.size(), 3, "玩家定义应带 3 门初始心法")
	for xf_id in player.xinfa:
		assert_false(XinfaRuntime.xinfa_data(xf_id).is_empty(), "初始心法应在 xinfa.json 中存在: " + xf_id)
