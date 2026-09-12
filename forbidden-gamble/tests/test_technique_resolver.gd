extends GutTest

func _card(attr: String, grade := 2) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, grade, randi()], attr, grade)

func test_technique_table_loads_nine_entries() -> void:
	assert_eq(TechniqueResolver.technique_ids().size(), 9, "v1 基础功法九门")

func test_unknown_technique_is_illegal() -> void:
	assert_false(TechniqueResolver.can_use("不存在的功法", [_card("风")]))

func test_empty_selection_is_illegal() -> void:
	assert_false(TechniqueResolver.can_use("点星式", []))

# 牌型门控：三门原型功法各守各的牌型
func test_dianxing_takes_any_single() -> void:
	for grade in range(1, 4):
		assert_true(TechniqueResolver.can_use("点星式", [_card("山", grade)]), "一气任意 1 张（品级%d）" % grade)

func test_lianfeng_needs_heavy_pair() -> void:
	assert_true(TechniqueResolver.can_use("连风式", [_card("火", 1), _card("火", 3)]), "同属性两张即二重（品级无关）")
	assert_false(TechniqueResolver.can_use("连风式", [_card("火", 2), _card("山", 2)]), "异属性两张不是二重")
	assert_false(TechniqueResolver.can_use("连风式", [_card("火", 1), _card("火", 2), _card("火", 3)]), "三重不满足二重牌型")

func test_zongheng_needs_mix_pair() -> void:
	assert_true(TechniqueResolver.can_use("纵横式", [_card("风", 2), _card("火", 2)]), "异属性两张即二合")
	assert_false(TechniqueResolver.can_use("纵横式", [_card("风", 2), _card("风", 3)]), "同属性两张不是二合")

# 子集搜索：手牌整体不构成牌型，但其中的同属性对必须能被找到
func test_find_legal_selection_finds_heavy_pair_in_mixed_hand() -> void:
	var hand: Array = [
		_card("风", 3), _card("林", 2), _card("火", 1),
		_card("山", 3), _card("风", 1),
	]
	var selection := TechniqueResolver.find_legal_selection("连风式", hand)
	assert_eq(selection.size(), 2, "应找到一对同属性")
	if selection.size() == 2:
		assert_eq(selection[0].attribute, selection[1].attribute, "找到的不是重族")

func test_find_legal_selection_returns_empty_when_impossible() -> void:
	# 4 张全异属性（4 属性各一）：任何子集都无同属性对，凑不出二重
	var hand: Array = [
		_card("风", 1), _card("林", 2), _card("火", 3), _card("山", 1),
	]
	assert_eq(TechniqueResolver.find_legal_selection("连风式", hand).size(), 0, "全异属性手牌凑不出二重")

# 一键补齐（M7b 装配流）：以已选真气为前提搜索最小合法组合

func test_containing_keeps_picked_and_adds_minimum() -> void:
	var hand: Array = [
		_card("风", 3), _card("林", 2), _card("火", 1),
		_card("山", 3), _card("风", 1),
	]
	# 已选 风3，连风式（二重）：应补最少的 1 张同属性（山3 或 风1）成对
	var selection := TechniqueResolver.find_legal_selection_containing("连风式", hand, [hand[0]])
	assert_eq(selection.size(), 2, "应在已选基础上补成二重")
	assert_true(selection.has(hand[0]), "已选真气必须保留")

func test_containing_returns_empty_when_picked_breaks_pattern() -> void:
	var hand: Array = [
		_card("风", 1), _card("林", 2), _card("火", 3),
		_card("山", 1), _card("风", 2),
	]
	# 手牌只有一张山：已选山1 永远凑不出二重
	assert_eq(TechniqueResolver.find_legal_selection_containing("连风式", hand, [hand[3]]).size(), 0, "已选孤张时二重不可能")

# ---------- 结算 ----------

func test_dianxing_resolve_deals_nine_damage() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	var result := TechniqueResolver.resolve("点星式", [_card("风", 2)], user, target)
	assert_true(bool(result.get("ok", false)))
	assert_eq(target.hp, 90, "点星式中品＝6+3×1＝9 点伤害")
	assert_eq(int(result.get("qi_amount", -1)), 1, "战报上下文应携带真气量")

func test_illegal_resolve_is_rejected() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	var result := TechniqueResolver.resolve("连风式", [_card("火", 2)], user, target)
	assert_false(bool(result.get("ok", false)))
	assert_eq(target.hp, 99, "非法发动不应造成伤害")

# ---------- M4 系别增幅与护具减伤 ----------

# v1 九门全通用：任何兵器都不吃增幅
func test_v1_techniques_never_amplified() -> void:
	var user := FighterState.new("u", "掌客", 30)
	user.weapon_school = "剑法"
	user.weapon_level = 5
	for tid in TechniqueResolver.technique_ids():
		assert_eq(TechniqueResolver.technique_amp(TechniqueResolver.data_for(tid), user), 0, "%s 不吃兵器增幅" % tid)

# 引擎规则仍保留系别增幅通路（将来门派功法用），用合成数据钉住
func test_school_amp_logic_kept_for_future() -> void:
	var user := FighterState.new("u", "刀客", 30)
	user.weapon_school = "刀法"
	user.weapon_level = 2
	assert_eq(TechniqueResolver.technique_amp({"school": "刀法"}, user), 2)
	assert_eq(TechniqueResolver.technique_amp({"school": "剑法"}, user), 0, "异系不增幅")
	user.weapon_level = 0
	assert_eq(TechniqueResolver.technique_amp({"school": "刀法"}, user), 0, "等级 0 不增幅")

# 护具减伤：护境吸收后的余伤再减 armor_defend，最低 0
func test_armor_defend_reduces_leaking_damage() -> void:
	var fighter := FighterState.new("f", "穿甲", 30)
	fighter.guard = 3
	fighter.armor_defend = 2
	var report: Dictionary = fighter.take_damage(10)
	assert_eq(report["guard_damage"], 3, "护境先吸收")
	assert_eq(report["hp_damage"], 5, "余伤 7 再被护具减 2")
	assert_eq(fighter.hp, 25)
	# 打不穿的攻击：护境全吸后护具再压到 0，不掉血
	fighter.guard = 0
	var chip: Dictionary = fighter.take_damage(1)
	assert_eq(chip["hp_damage"], 0, "护具把 1 点余伤压到 0")
	assert_eq(fighter.hp, 25)

# 连风式双段：两段各自独立吃护境（第一段破盾，第二段直扣气血）
func test_lianfeng_segments_hit_guard_separately() -> void:
	var user := FighterState.new("u", "测试者", 99)
	var target := FighterState.new("t", "靶子", 99)
	target.guard = 3
	var result := TechniqueResolver.resolve("连风式", [_card("火", 2), _card("火", 2)], user, target)
	assert_true(bool(result.get("ok", false)))
	# 每段 6：第一段被护境吃 3 余 3，第二段 6 直扣——气血共掉 9，护境归零
	assert_eq(target.guard, 0)
	assert_eq(target.hp, 90)
