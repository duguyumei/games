extends GutTest

# 词条族：压制＝给对方施加破绽（跳过下次获得行动权——净效果＝换节拍再动）；
# 冷却 N＝后续 N 次自己的原子行动内不可再发动（二重·换承载）；蓄力＝跨拍动作：
# 起手占行动权、充能拍让权、满值自动发动（纵横式承载）。敌方系统 v2 修订：
# 蓄力是全承诺——起蓄不可换功法，护盾被击碎不再销毁蓄力（断势退役，打断＝内容动词）。

const HIT_DEF := {
	"breathe_policy": "all",
	"hand": [{"id": "e1", "attribute": "风", "grade": "下品"}],
	"deck": [{"id": "e2", "attribute": "风", "grade": "下品"}],
	"ladder": [{"technique": "点星式"}, {"technique": "调息"}],
	"hooks": [],
}

const SMASH_DEF := {
	"breathe_policy": "all",
	"hand": [{"id": "e1", "attribute": "风", "grade": "上品"}],
	"deck": [{"id": "e2", "attribute": "风", "grade": "上品"}],
	"ladder": [{"technique": "点星式"}, {"technique": "调息"}],
	"hooks": [],
}

func _fighter(id: String, techniques: Array) -> FighterState:
	var fighter := FighterState.new(id, id, 30)
	fighter.techniques.assign(techniques)
	return fighter

func _wind(count: int, grade: int, prefix: String, attribute := "风") -> Array:
	var cards: Array = []
	for index in range(count):
		cards.append(QiCard.new("%s%d" % [prefix, index], attribute, grade))
	return cards

# 组 12 张：风火交替各 6 张中品——任意起手 6 张必含异属性对（二合）
func _mixed_pair_deck(prefix: String) -> Array:
	var cards: Array = []
	for index in range(6):
		cards.append(QiCard.new("%sw%d" % [prefix, index], "风", 2))
		cards.append(QiCard.new("%sh%d" % [prefix, index], "火", 2))
	return cards

func _start(player: FighterState, enemy: FighterState) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false)
	return tm

# ---------- 压制（＝施加破绽）与冷却 ----------

func test_tuna_suppression_applies_flaw() -> void:
	# 吐纳＝二合·压制：发动后对方获得破绽（跳过下次获得行动权）＝玩家换节拍再动
	var player := _fighter("p", ["二合·吐纳", "点星式"])
	player.draw_pile = _mixed_pair_deck("p")
	var tm := _start(player, _enemy())
	var mix := TechniqueResolver.find_legal_selection("二合·吐纳", player.hand, player)
	assert_false(mix.is_empty(), "手牌应能凑二合")
	var hand_before := player.hand.size()
	var result := tm.player_act("二合·吐纳", mix)
	assert_true(bool(result.get("ok", false)))
	assert_string_contains(str(result.get("effect", "")), "破绽")
	assert_eq(tm.combat.active_side, "player", "对方破绽跳一拍：玩家连动（换节拍）")
	assert_false(tm.combat.enemy.flawed, "破绽即查即耗")
	assert_eq(int(player.technique_cooldowns.get("二合·吐纳", 0)), 0, "吐纳无冷却")
	assert_eq(player.hand.size(), hand_before - 2 + 1, "两张散气＋提 1 张")

func test_huan_cooldown_gates_next_action() -> void:
	# 换＝二重·冷却1：发动后下一次自己的原子行动内不可再发动
	var player := _fighter("p", ["二重·换", "点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var tm := _start(player, _enemy())
	var pair := TechniqueResolver.find_legal_selection("二重·换", player.hand, player)
	assert_false(pair.is_empty(), "全风手牌必含二重")
	tm.player_act("二重·换", pair)
	assert_eq(int(player.technique_cooldowns.get("二重·换", 0)), 1, "冷却 1 自此刻起算")
	# 冷却中不可再发动
	assert_false(TechniqueResolver.can_use("二重·换", pair, player), "冷却中门控生效")
	# 冷却 1＝下一次自己的原子行动内不可再发动，之后解锁：
	# 敌方动 → 玩家调息（行动开始 tick 冷却 1→0）→ 可再发动
	tm.enemy_act()
	tm.player_breathe([])
	assert_eq(int(player.technique_cooldowns.get("二重·换", 0)), 0, "一次行动后冷却归零")
	assert_true(TechniqueResolver.can_use("二重·换", pair, player), "冷却归零后可再发")

# ---------- 蓄力生命周期（纵横式＝二合·等级2·蓄力1） ----------

func _enemy(def: Dictionary = HIT_DEF, hp := 60) -> FighterState:
	var fighter := FighterState.new("e", "e", hp)
	fighter.enemy_def = def
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func test_zongheng_charge_lifecycle() -> void:
	var player := _fighter("p", ["纵横式", "点星式"])
	player.draw_pile = _mixed_pair_deck("p")
	var tm := _start(player, _enemy())
	var mix := TechniqueResolver.find_legal_selection("纵横式", player.hand, player)
	assert_false(mix.is_empty(), "手牌应含异属性对")
	# 选中中品对（量0）：把起手对换成两张中品——直接找包含两张中品的二合
	var mid_pair: Array = []
	for card in player.hand:
		if card.attribute == "风":
			mid_pair.append(card)
			break
	for card in player.hand:
		if card.attribute == "火":
			mid_pair.append(card)
			break
	var started := tm.player_act("纵横式", mid_pair)
	assert_true(bool(started.get("ok", false)))
	assert_eq(str(started.get("action", "")), "charge_started", "蓄力起手不立即结算")
	assert_true(player.has_active_charge(), "蓄力态建立")
	assert_eq((player.charging.get("cards", []) as Array).size(), 2, "选入真气入招（无自动喂气）")
	assert_eq(tm.combat.active_side, "enemy", "起手让权——曝光开始")
	# 蓄力 0/1：敌方动 → 玩家充能拍（+1 即满，自动发动）
	tm.enemy_act()
	var fired := tm.player_charge_tick()
	assert_eq(str(fired.get("action", "")), "technique", "满值自动发动（走功法结算）")
	assert_false(player.has_active_charge(), "蓄力态清空")
	assert_eq(int(fired.get("damage", 0)), 10, "两张中品量0：10+5×0")
	assert_eq(tm.combat.enemy.hp, 50, "60 血敌方余 50")
	assert_eq(tm.combat.active_side, "enemy", "发动后照常让权")

func test_charge_survives_guard_shatter() -> void:
	# 断势退役（敌方系统 v2）：蓄力是全承诺——护盾被击碎不再销毁蓄力；
	# 蓄力期间玩家不能换功法（can_use 门控），充能拍照常自动推进。
	var player := _fighter("p", ["纵横式", "点星式"])
	player.draw_pile = _mixed_pair_deck("p")
	player.guard = 11
	var tm := _start(player, _enemy(SMASH_DEF))
	var mid_pair: Array = []
	for card in player.hand:
		if card.attribute == "风":
			mid_pair.append(card)
			break
	for card in player.hand:
		if card.attribute == "火":
			mid_pair.append(card)
			break
	tm.player_act("纵横式", mid_pair)
	assert_true(player.has_active_charge())
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()  # 上品点星 12 点砸穿 11 盾
	assert_eq(tm.combat.player.guard, 0, "护盾被击碎")
	assert_true(player.has_active_charge(), "断势退役：蓄力不散（全承诺）")
	assert_false(TechniqueResolver.can_use("点星式", [player.hand[0]], player), "蓄力期间不可换功法")
	var fired := tm.player_charge_tick()
	assert_eq(str(fired.get("action", "")), "technique", "充能照常推进满值发动")

# ---------- 蓄力失效兜底 ----------

func test_charge_fizzle_discards_cards() -> void:
	# 直接改写 charging 模拟结算失效兜底路径
	var player := _fighter("p", ["点星式"])
	player.draw_pile = _wind(12, 2, "p")
	var tm := _start(player, _enemy())
	player.charging = {"technique": "不存在的功法", "charge": 1, "need": 2, "cards": [QiCard.new("x1", "风", 2)]}
	var r := tm.player_charge_tick()
	assert_false(bool(r.get("ok", false)), "不存在的功法结算失败")
	assert_false(player.has_active_charge(), "蓄力态已清")
	assert_eq(player.discard_pile.size(), 1, "落空的真气散入气海")
