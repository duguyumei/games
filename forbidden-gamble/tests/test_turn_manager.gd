extends GutTest

# 真气语法 v2.2 流动制：敌我轮流（被动获得＝补满、主动截牌＝不补满）、架势（弃 1–4
# 入自己的牌河＋开窗）、截即打（碰/吃当场组型轰出、杠＝四张升档＋破绽无补牌）、
# 窗口放行即死、敌方同构必截（杠＞碰＞吃）、气海单向耗尽＋疲劳递增真伤兜底
# （气竭退役）、破绽＝烧被动拍。start_battle(false) 关洗牌保证确定性。
# 注意：对山4×3 的敌方（SHIELD_DEF）弃山4 会被必截——非截牌用例一律弃 火2/山2。

const SHIELD_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "山", "value": 4}, {"attribute": "山", "value": 4}, {"attribute": "山", "value": 4}],
	"deck": {"风": {"3": 2, "4": 2, "5": 2}},
	"ladder": [
		{"technique": "重盾式", "when": {"guard_lt": 3}},
		{"technique": "架势"},
	],
}

const SMASH_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "风", "value": 6}, {"attribute": "风", "value": 7}, {"attribute": "风", "value": 8}],
	"deck": {"风": {"4": 2}},
	"ladder": [{"technique": "点星式"}, {"technique": "架势"}],
}

# 同构必截卡：崩山式（刻子伤）＋起手两张山4 → 玩家弃山4 必被碰轰
const PON_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "山", "value": 4}, {"attribute": "山", "value": 4}, {"attribute": "火", "value": 6}],
	"deck": {"风": {"3": 2}},
	"ladder": [{"technique": "崩山式"}, {"technique": "架势"}],
}

# 杠卡：起手三张山5（重盾式为刻子功法）→ 玩家弃山5 必被杠轰＋破绽
const KAN_DEF := {
	"swap_policy": "all",
	"hand": [
		{"attribute": "山", "value": 5}, {"attribute": "山", "value": 5},
		{"attribute": "山", "value": 5}, {"attribute": "火", "value": 6},
	],
	"deck": {"风": {"3": 2}},
	"ladder": [{"technique": "重盾式"}, {"technique": "架势"}],
}

# 纯架势地板卡：它每拍架势（弃全部起手入它的牌河）→ 为玩家开窗；无攻技
const SWAP_DEF := {
	"swap_policy": "all",
	"hand": [{"attribute": "山", "value": 5}, {"attribute": "山", "value": 5}, {"attribute": "风", "value": 4}],
	"deck": {"风": {"3": 2}},
	"ladder": [{"technique": "架势"}],
}

func _card(attr: String, value := 3) -> QiCard:
	return QiCard.new("%s%d_%d" % [attr, value, randi()], attr, value)

func _destiny() -> Array:
	# 本命 8 张（start_battle(false) 不洗、从尾部抽入丹田——倒序写，使丹田前三是山4 刻子）：
	return [
		_card("火", 2), _card("山", 2), _card("风", 5), _card("风", 4),
		_card("风", 3), _card("山", 4), _card("山", 4), _card("山", 4),
	]

func _player(techniques: Array = ["崩山式", "点星式", "二重·壁"]) -> FighterState:
	var fighter := FighterState.new("p", "独行武者", 40)
	fighter.techniques.assign(techniques)
	fighter.destiny_pile = _destiny()
	return fighter

func _enemy(def: Dictionary, hp := 40) -> FighterState:
	var fighter := FighterState.new("e", "青锋剑徒", hp)
	EncounterLoader.fill_enemy_body(fighter, def)
	return fighter

func _start(player: FighterState, enemy: FighterState, enemy_first := false) -> TurnManager:
	var tm := TurnManager.new(CombatState.new(player, enemy))
	tm.start_battle(false, enemy_first)
	return tm

# 直接注入玩家截牌窗（绕开敌方架势流程，专注截即打本体）：往敌方牌河放一张批内牌并开窗。
func _open_window(tm: TurnManager, card: QiCard) -> void:
	tm.combat.river_batch += 1
	tm.combat.rivers["enemy"].append({"card": card, "batch": tm.combat.river_batch, "source": "swap"})
	tm.combat.window_state = {"owner": "player", "batch": tm.combat.river_batch}
	tm.awaiting_player_claims = true

# ---------- 开战 ----------

func test_start_battle_draws_eight_from_destiny_and_player_holds_right() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	assert_eq(tm.combat.player.hand.size(), TurnManager.DANTIAN_SIZE, "开局本命洗抽入丹田 8 口")
	assert_eq(tm.combat.player.destiny_pile.size(), 0, "本命全数入丹田")
	assert_eq(tm.combat.enemy.hand.size(), 3, "敌方起手丹田 authored（本卡 3 口）")
	assert_eq(tm.combat.enemy.dantian_capacity, 3, "敌方丹田容量＝起手张数")
	assert_true(tm.combat.qi_wall.size() > 0, "气海（共墙）由对手卡主场配置展开")
	assert_eq(tm.combat.active_side, "player", "默认玩家先动（被动获得）")
	assert_eq(str(tm.enemy_intent.get("technique", "")), "重盾式", "开战即锁敌方意图（梯顶）")

func test_ambush_gives_enemy_first_right() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF), true)
	assert_eq(tm.combat.active_side, "enemy", "被袭击＝敌方先动")

# ---------- 打出功法（三张成型→副露区；补满只发生在被动获得） ----------

func test_player_act_moves_cards_to_melds_without_mid_beat_refill() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	var wall_before := tm.combat.qi_wall.size()
	var selection := TechniqueResolver.find_legal_selection("崩山式", tm.combat.player.hand)
	assert_eq(selection.size(), 3, "山4 刻子应被找到")
	var result := tm.player_act("崩山式", selection)
	assert_true(bool(result.get("ok", false)))
	assert_eq(tm.combat.enemy.hp, 40 - 14, "崩山式＝2＋1×12＝14 点伤害")
	assert_eq(tm.combat.player.hand.size(), TurnManager.DANTIAN_SIZE - 3, "打出后不补满（补满挂被动获得）")
	assert_eq((tm.combat.player.melds[0] as Array).size(), 3, "打出的三张沉入副露区")
	assert_eq(tm.combat.qi_wall.size(), wall_before, "此拍不动气海")
	assert_eq(tm.combat.river_of("player").size(), 0, "功法打出的不入牌河")
	assert_eq(tm.combat.active_side, "enemy", "行动结束流动给敌方")
	# 敌方动完流动回玩家：被动获得→补满（此时才从气海纳 3 口）
	tm.enemy_act()
	assert_eq(tm.combat.player.hand.size(), TurnManager.DANTIAN_SIZE, "被动获得时补满丹田")
	assert_eq(tm.combat.qi_wall.size(), wall_before - 3, "补满的三口来自气海")

func test_player_act_when_not_holder_rejected() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF), true)
	var result := tm.player_act("点星式", TechniqueResolver.find_legal_selection("点星式", tm.combat.player.hand))
	assert_false(bool(result.get("ok", false)), "不持有行动权不能行动")

func test_enemy_act_executes_locked_intent() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.player_swap([6, 7])  # 弃 山2/火2（不喂敌方搭子）
	assert_eq(tm.combat.active_side, "enemy")
	tm.enemy_act()
	assert_eq(tm.combat.enemy.guard, 6 + 12, "敌方重盾式＝6＋1×（山4刻子和12）")
	assert_eq((tm.combat.enemy.melds[0] as Array).size(), 3, "敌方打出的三张沉入其副露区")
	assert_eq(tm.combat.active_side, "player", "敌方行动后流动给玩家")

# ---------- 架势（弃 1–4 入自己的牌河＋开窗，费一拍） ----------

func test_swap_discards_into_own_river_and_opens_window() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	var discarded = tm.combat.player.hand[6]
	tm.player_swap([6, 7])
	assert_eq(tm.combat.river_of("player").size(), 2, "弃牌入自己的牌河")
	assert_eq(tm.combat.river_of("enemy").size(), 0, "不进敌方的河")
	assert_true(tm.combat.window_open_for("enemy"), "架势弃牌为敌方开截牌窗")
	assert_eq(tm.combat.player.hand.size(), TurnManager.DANTIAN_SIZE, "弃 2 纳 2（架势自带补满）")
	assert_false(tm.combat.player.hand.has(discarded), "弃掉的牌不回手（气海未涸）")
	assert_eq(tm.combat.player_swap_count, 1, "架势计数 +1")
	assert_eq(tm.combat.active_side, "enemy", "架势让权")

func test_swap_requires_one_to_four_cards() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	assert_false(bool(tm.player_swap([]).get("ok", false)), "弃 0 张不成立")
	var too_many: Array = [0, 1, 2, 3, 4]
	assert_false(bool(tm.player_swap(too_many).get("ok", false)), "弃 5 张超上限")
	assert_true(bool(tm.player_swap([7]).get("ok", false)), "弃 1 张成立")

# 气持有即保留：不弃的牌跨拍留手
func test_cards_held_across_actions() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	var held = tm.combat.player.hand[2]
	tm.player_swap([6, 7])
	tm.enemy_act()
	assert_true(tm.combat.player.hand.has(held), "捏着的气不散")

# ---------- 截即打（窗口/碰/吃/杠） ----------

func test_player_pon_fires_immediately_into_melds() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	for _i in range(2):
		tm.combat.player.hand.append(_card("山", 5))
	var hand_before := tm.combat.player.hand.size()
	_open_window(tm, _card("山", 5))
	var options := tm.player_claim_options()
	var pon_options := options.filter(func(o): return str(o.get("kind", "")) == "碰")
	assert_eq(pon_options.size(), 1, "应给出碰选项（崩山式）")
	var enemy_hp_before := tm.combat.enemy.hp
	tm.player_claim_fire(pon_options[0])
	assert_eq(tm.combat.enemy.hp, enemy_hp_before - (2 + 15), "碰＝当场轰出崩山式：2＋1×（山5×3）＝17")
	assert_eq(tm.combat.player.hand.size(), hand_before - 2, "两张搭子随河牌一起入副露（不囤牌）")
	assert_eq((tm.combat.player.melds[0] as Array).size(), 3, "碰的三张沉入副露区")
	assert_eq(tm.combat.river_of("enemy").size(), 0, "河牌被截走")
	assert_false(tm.combat.enemy.flawed, "碰不给破绽")
	assert_eq(tm.combat.active_side, "enemy", "截完窗口枯竭，流动去敌方")
	assert_false(tm.awaiting_player_claims, "截牌窗关闭")

func test_player_chi_fires_shunzi() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.player.hand.append(_card("火", 3))
	tm.combat.player.hand.append(_card("火", 5))
	_open_window(tm, _card("火", 4))
	var options := tm.player_claim_options()
	var chi_options := options.filter(func(o): return str(o.get("kind", "")) == "吃")
	assert_eq(chi_options.size(), 1, "火3+火5 吃 火4 → 点星式")
	var enemy_hp_before := tm.combat.enemy.hp
	tm.player_claim_fire(chi_options[0])
	assert_eq(tm.combat.enemy.hp, enemy_hp_before - (2 + 12), "吃＝当场轰出点星式：2＋1×（火345 和12）")

func test_player_kan_fours_upgraded_flaw_no_draw() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	for _i in range(3):
		tm.combat.player.hand.append(_card("山", 5))
	var wall_before := tm.combat.qi_wall.size()
	_open_window(tm, _card("山", 5))
	var options := tm.player_claim_options()
	var kan_options := options.filter(func(o): return str(o.get("kind", "")) == "杠")
	assert_eq(kan_options.size(), 1, "应给出杠选项（崩山式）")
	var enemy_hp_before := tm.combat.enemy.hp
	tm.player_claim_fire(kan_options[0])
	assert_eq(tm.combat.enemy.hp, enemy_hp_before - (2 + 20), "杠＝升档四张：2＋1×（山5×4）＝22")
	assert_true(tm.combat.enemy.flawed, "被杠者破绽一枚")
	assert_eq(tm.combat.qi_wall.size(), wall_before, "杠后无补牌")
	assert_eq((tm.combat.player.melds[0] as Array).size(), 4, "四张沉入副露区")

# 截即打需要冷却好的对应功法：冷却中→无碰/杠选项
func test_claim_needs_ready_matching_technique() -> void:
	var tm := _start(_player(["崩山式"]), _enemy(SHIELD_DEF))
	for _i in range(2):
		tm.combat.player.hand.append(_card("山", 5))
	tm.combat.player.technique_cooldowns["崩山式"] = 1
	_open_window(tm, _card("山", 5))
	assert_eq(tm.player_claim_options().size(), 0, "刻子功法冷却中 → 碰/杠皆无门")

# 蓄力锁（核心层）：蓄力中无窗
func test_claim_locked_while_charging() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.player.charging = {"technique": "蓄势斩", "charge": 0, "need": 1, "cards": []}
	_open_window(tm, _card("山", 4))
	assert_eq(tm.player_claim_options().size(), 0, "蓄力中不可截")

# 自家弃牌不可自截：窗口属敌方时玩家无选项
func test_no_claim_on_own_discards() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.player_swap([7])
	assert_false(tm.combat.window_open_for("player"), "窗口开给敌方，玩家不是窗主")
	assert_eq(tm.player_claim_options().size(), 0, "自家弃牌不可自截")

# 窗口死亡：放行即作废（过水不追）
func test_window_dies_on_release() -> void:
	var tm := _start(_player(), _enemy(SWAP_DEF))
	tm.player_swap([7])
	tm.enemy_act()  # 敌方架势弃 3 张入它的河 → 玩家窗口
	assert_true(tm.awaiting_player_claims, "玩家截牌窗挂起")
	assert_false(tm.player_claim_options().is_empty(), "风4 可被吃（手里风3+风5）")
	tm.player_release_flow()
	assert_false(tm.awaiting_player_claims, "放行解挂")
	assert_eq(tm.player_claim_options().size(), 0, "窗口作废：过水不追")
	assert_eq(tm.combat.active_side, "player", "放行＝被动获得行动权")
	assert_true(bool(tm.player_swap([7]).get("ok", false)), "放行后正常行动")

# 连链：批内两张可截 → 连截两发后流动去敌方
func test_claim_chain_fires_twice_then_flows() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	for _i in range(4):
		tm.combat.player.hand.append(_card("山", 5))
	tm.combat.river_batch += 1
	tm.combat.rivers["enemy"].append({"card": _card("山", 5), "batch": tm.combat.river_batch, "source": "swap"})
	tm.combat.rivers["enemy"].append({"card": _card("山", 5), "batch": tm.combat.river_batch, "source": "swap"})
	tm.combat.window_state = {"owner": "player", "batch": tm.combat.river_batch}
	tm.awaiting_player_claims = true
	var first := tm.player_claim_options()[0]
	var r1 := tm.player_claim_fire(first)
	assert_true(bool(r1.get("chain_continues", false)), "批内还有一张 → 链继续")
	assert_true(tm.awaiting_player_claims, "仍挂起（可再截）")
	var second := tm.player_claim_options()[0]
	var r2 := tm.player_claim_fire(second)
	assert_false(bool(r2.get("chain_continues", false)), "批枯竭 → 链结束")
	assert_eq(tm.combat.active_side, "enemy", "链尽流动去敌方")
	assert_eq(tm.combat.player.melds.size(), 2, "两段副露")

# ---------- 敌方同构必截 ----------

func test_enemy_must_claim_pon_on_matching_discard() -> void:
	var tm := _start(_player(), _enemy(PON_DEF))
	var player_hp_before := tm.combat.player.hp
	var enemy_hand_before := tm.combat.enemy.hand.size()
	tm.player_swap([0])  # 弃山4 → 敌方必碰轰
	assert_eq(tm.combat.player.hp, player_hp_before - (2 + 12), "敌方碰轰崩山式：2＋1×（山4×3）＝14")
	assert_eq(tm.combat.enemy.hand.size(), enemy_hand_before - 2, "两张搭子入副露")
	assert_eq((tm.combat.enemy.melds[0] as Array).size(), 3, "敌方副露三张")
	assert_eq(tm.combat.active_side, "player", "敌方以截链占拍 → 流动回玩家")
	assert_false(tm.combat.player.flawed, "碰不铸破绽")

func test_enemy_must_claim_kan_over_pon() -> void:
	var tm := _start(_player(), _enemy(KAN_DEF))
	var wall_before := tm.combat.qi_wall.size()
	tm.combat.player.hand[3] = _card("山", 5)
	tm.player_swap([3])  # 弃山5 → 敌方三张山5 在手 → 杠优先于碰
	assert_eq(tm.combat.enemy.guard, 6 + 20, "杠重盾式＝6＋1×（山5×4 和20）＝升档四张")
	assert_true(tm.combat.player.flawed, "被杠者（玩家）破绽一枚")
	assert_eq(tm.combat.qi_wall.size(), wall_before, "杠后无补牌")

func test_enemy_ignores_non_claimable_discard() -> void:
	var tm := _start(_player(), _enemy(PON_DEF))
	var enemy_hand_before := tm.combat.enemy.hand.size()
	tm.player_swap([5])  # 弃风5（山4 外）→ 不截
	assert_eq(tm.combat.enemy.hand.size(), enemy_hand_before, "规格外不截")
	assert_eq(tm.combat.river_of("player").size(), 1, "风5 留在玩家河里（对方过水即死）")
	assert_eq(tm.combat.active_side, "enemy", "无截 → 敌方被动获得照常行动")

func test_enemy_claim_locked_while_charging() -> void:
	var tm := _start(_player(), _enemy(PON_DEF))
	tm.combat.enemy.charging = {"technique": "蓄势斩", "charge": 0, "need": 1, "cards": []}
	var enemy_hand_before := tm.combat.enemy.hand.size()
	tm.player_swap([0])
	assert_eq(tm.combat.enemy.hand.size(), enemy_hand_before, "蓄力锁：敌方不截")

# ---------- 气海单向耗尽与疲劳 ----------

func test_fatigue_escalates_per_draw_action_from_own_river() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.qi_wall.clear()
	tm.combat.rivers["player"].clear()
	for _i in range(2):
		tm.combat.rivers["player"].append({"card": _card("风", 3), "batch": 0, "source": "swap"})
	tm.combat.player.hand.resize(6)
	tm._refill(tm.combat.player)  # 缺 2 → 碰河一次（一口从自己河补、疲劳第 1 次＝1 点）
	assert_eq(tm.combat.player.hp, 39, "疲劳第 1 次＝1 点真伤")
	assert_eq(tm.combat.player.hand.size(), 8, "缺的口从自己河里补")
	tm.combat.player.hand.resize(7)
	tm._refill(tm.combat.player)  # 河已空 → 缺口碰不到牌、疲劳照跳（第 2 次＝2 点）
	assert_eq(tm.combat.player.hp, 37, "疲劳第 2 次＝2 点（按方递增；河空照样结算）")
	assert_eq(tm.combat.player.hand.size(), 7, "无气可纳")

func test_fatigue_bypasses_guard() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.player.guard = 10
	tm.combat.qi_wall.clear()
	tm.combat.rivers["player"].clear()
	tm.player_swap([7])  # 弃火2 → 补 1 缺口碰空河 → 疲劳真伤
	assert_eq(tm.combat.player.guard, 10, "疲劳不碰护境")
	assert_eq(tm.combat.player.hp, 40 - 1, "疲劳直砍气血（第 1 次＝1 点）")

func test_fatigue_is_sole_backstop_no_deadlock() -> void:
	# 双方手牌、气海、双河全空 → 无气让拍＋疲劳互相收割，血先光者死（气竭退役）
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.qi_wall.clear()
	tm.combat.rivers["player"].clear()
	tm.combat.rivers["enemy"].clear()
	tm.combat.player.hand.clear()
	tm.combat.enemy.hand.clear()
	tm.combat.player.hp = 3
	tm.combat.enemy.hp = 5
	tm._flow_to("player")  # 直接驱动流动
	assert_true(tm.is_over(), "疲劳兜底必然终结")
	assert_false(tm.combat.player.is_alive(), "血先光者死（玩家 3 血先耗尽）")
	assert_true(tm.combat.enemy.is_alive())

# ---------- 破绽（烧被动拍） ----------

func test_flaw_skips_passive_gain_and_consumes() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.enemy.flawed = true
	tm.player_swap([7])
	assert_eq(tm.combat.active_side, "player", "敌方破绽：烧掉它的被动拍，玩家连动")
	assert_false(tm.combat.enemy.flawed, "破绽即查即耗")
	tm.player_swap([7])
	assert_eq(tm.combat.active_side, "enemy", "破绽只烧一拍")

func test_flaw_skip_still_refills() -> void:
	var small := SHIELD_DEF.duplicate(true)
	small["hand"] = [{"attribute": "山", "value": 4}]
	var tm := _start(_player(), _enemy(small))
	tm.combat.enemy.hand.clear()  # 手 0/容量 1
	tm.combat.enemy.flawed = true
	tm.player_swap([7])
	assert_eq(tm.combat.enemy.hand.size(), 1, "破绽跳过行动但补满照常（吐纳不烧）")

func test_flaw_does_not_block_active_claim() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.combat.player.flawed = true
	for _i in range(2):
		tm.combat.player.hand.append(_card("山", 5))
	_open_window(tm, _card("山", 5))
	var pon := tm.player_claim_options().filter(func(o): return str(o.get("kind", "")) == "碰")
	assert_eq(pon.size(), 1, "带破绽仍可主动夺取")
	tm.player_claim_fire(pon[0])
	assert_true(tm.combat.enemy.hp < 40, "截即打照常轰出")
	assert_true(tm.combat.player.flawed, "破绽留给下一次被动获得（主动夺取不消耗它）")

func test_guard_shatter_is_pure_physics_no_flaw() -> void:
	var tm := _start(_player(), _enemy(SMASH_DEF))
	tm.combat.player.guard = 10
	tm.player_swap([7])
	tm.enemy_act()
	assert_eq(tm.combat.player.guard, 0, "护盾被击碎")
	assert_eq(tm.combat.player.hp, 40 - (2 + 21 - 10), "点星式风678＝2＋21，溢出扣气血")
	assert_false(tm.combat.player.flawed, "破盾不给破绽")
	assert_eq(tm.combat.active_side, "player", "流动照常轮流")

# ---------- 点位与计数 ----------

func test_initiative_points_fire_on_passive_gain() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	var gained: Array = []
	tm.combat.pipeline.register_hook({"carrier": "test", "on": "initiative_gain", "phase": "post", "priority": 0,
		"handler": func(action: GameAction) -> void: gained.append((action.target as FighterState).fighter_id)})
	tm.player_swap([7])
	assert_eq(gained, ["e"], "被动获得方收到 initiative_gain")

func test_action_and_swap_counters() -> void:
	var tm := _start(_player(), _enemy(SHIELD_DEF))
	tm.player_swap([7])    # 行动1
	tm.enemy_act()         # 行动2
	tm.player_swap([6])    # 行动3
	assert_eq(tm.combat.action_count, 3)
	assert_eq(tm.combat.player_swap_count, 2, "两次架势")
