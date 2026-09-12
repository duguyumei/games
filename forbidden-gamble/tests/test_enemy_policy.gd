extends GutTest

const ENCOUNTER_PATH := "res://data/sandbox_encounter.json"

func test_encounter_loads_both_sides() -> void:
	var combat := EncounterLoader.load(ENCOUNTER_PATH)
	assert_not_null(combat, "遭遇战配置应加载成功")
	if combat == null:
		return
	assert_eq(combat.player.display_name, "独行武者")
	assert_eq(combat.enemy.display_name, "青锋剑徒", "沙盒演练对手")
	assert_eq(combat.player.draw_pile.size(), 12, "玩家牌库应为12张（4属性×3品级）")
	assert_eq(combat.enemy.draw_pile.size(), 12, "敌方牌库应为12张")
	assert_eq(combat.player.hand.size(), 0, "战斗开始前手牌应为空")
	assert_eq(combat.player.draw_pile[0].grade, 1, "首牌下品（grade=1）")

func test_encounter_battle_start_draws_and_locks_intent() -> void:
	var combat := EncounterLoader.load(ENCOUNTER_PATH)
	assert_not_null(combat)
	if combat == null:
		return
	var tm := TurnManager.new(combat)
	tm.start_battle(false)
	assert_eq(combat.player.hand.size(), 6)
	assert_eq(combat.enemy.hand.size(), 7, "敌方带先纳功：起手 6＋战斗开始提 1")
	assert_ne(str(tm.enemy_intent.get("technique", "PASS")), "PASS", "敌方第一回合应有锁定意图")

# 回归守卫：敌人必须能在手牌子集中找到可用功法，而不是永远空转。
func test_enemy_acts_with_subset_search() -> void:
	var enemy := FighterState.new("e", "山匪刀客", 30)
	enemy.techniques.assign(["连风式", "点星式"])
	enemy.ai_priority.assign(["连风式", "点星式"])
	enemy.hand = [
		QiCard.new("e1", "火", 2), QiCard.new("e2", "山", 1), QiCard.new("e3", "火", 3),
		QiCard.new("e4", "林", 2), QiCard.new("e5", "风", 2),
	]
	var player := FighterState.new("p", "玩家", 30)
	var intent := EnemyPolicy.choose_action(enemy)
	assert_eq(str(intent.get("technique", "PASS")), "连风式", "敌人应找到一对火发动连风式")
	var result := TechniqueResolver.resolve(intent.technique, intent.cards, enemy, player)
	assert_true(bool(result.get("ok", false)))
	# 火2＋火3：量3、上品1（每段再+1），每段 4+3+1=8、双段 16
	assert_eq(player.hp, 14, "敌方连风式双段共 16 点伤害")

func test_enemy_lifts_before_breathing_when_nothing_legal() -> void:
	# 行动权模型（v1）：无合法功法→先提气（每口气 1 次让一拍换一张）
	var enemy := FighterState.new("e", "空手", 30)
	enemy.techniques.assign(["连风式"])
	enemy.ai_priority.assign(["连风式"])
	enemy.hand = [QiCard.new("e1", "火", 3)]
	enemy.draw_pile = [QiCard.new("e2", "山", 5)]
	assert_eq(str(EnemyPolicy.choose_action(enemy).get("action", "")), "lift_qi", "无合法功法且可提要提气")

func test_enemy_breathes_when_lift_used() -> void:
	var enemy := FighterState.new("e", "空手", 30)
	enemy.techniques.assign(["连风式"])
	enemy.ai_priority.assign(["连风式"])
	enemy.hand = [QiCard.new("e1", "火", 3)]
	enemy.draw_pile = [QiCard.new("e2", "山", 5)]
	enemy.lifts_this_breath = 1
	assert_eq(str(EnemyPolicy.choose_action(enemy).get("action", "")), "breathe", "已提过气应调息")

func test_enemy_passes_only_when_no_cards_at_all() -> void:
	var enemy := FighterState.new("e", "气尽", 30)
	enemy.techniques.assign(["连风式"])
	enemy.ai_priority.assign(["连风式"])
	assert_eq(str(EnemyPolicy.choose_action(enemy).get("action", "")), "pass", "牌尽气绝才纯过牌")

func test_fighter_has_legal_action_uses_subset() -> void:
	var fighter := FighterState.new("f", "武者", 30)
	fighter.techniques.assign(["二重·壁"])
	fighter.hand = [
		QiCard.new("f1", "风", 2), QiCard.new("f2", "林", 1), QiCard.new("f3", "火", 3),
	]
	assert_false(fighter.has_legal_action(), "手牌无同属性对不应有合法行动")
	fighter.hand.append(QiCard.new("f4", "火", 1))
	assert_true(fighter.has_legal_action(), "补一张火即成二重")
