extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")

const BattleSideScript = preload("res://core/battle_side.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const EffectExecutorScript = preload("res://core/effect_executor.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectPortsScript = preload("res://core/effects/battle_effect_ports.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const TargetQueryScript = preload("res://core/effects/effect_target_query.gd")
const ChoiceRequestScript = preload("res://core/effects/battle_choice_request.gd")
const BattleActionProposalScript = preload("res://core/battle_action_proposal.gd")
const BattleCommandScript = preload("res://core/battle_command_dto.gd")
const CommandResultScript = preload("res://core/command_result.gd")
const NodeDispatcherScript = preload("res://core/node_dispatcher.gd")
const CombatEngineScript = preload("res://core/combat_engine.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const TechniqueRepositoryScript = preload("res://core/technique_repository.gd")
const DamageResolverScript = preload("res://core/damage_resolver.gd")
const StatusSystemScript = preload("res://core/status_system.gd")
const BattleFlowCoordinatorScript = preload("res://core/battle_flow_coordinator.gd")
const TriggerQueueScript = preload("res://core/trigger_queue.gd")

const PendingChoiceHandlerScript = preload("res://tests/support/pending_choice_handler.gd")

var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    _test_technique_entities_are_individual_resources()
    _test_wind_common_card_flow_rules()
    _test_wind_high_technique_batch()
    _test_wind_cooperation_group_resolution()
    _test_wind_echo_and_five_card_power()
    _test_wind_four_kind_card_flow_and_persistent_trigger()
    _test_stagnant_gu_conceal_breath_pipeline()
    _test_borrow_fire_guard_heart_pipeline()
    _test_borrowed_force_attack_segments()
    _test_structured_context_and_ports()
    _test_action_preview_dto_contract()
    _test_action_and_dispatch_dto_contracts()
    _test_structured_results_and_pending_boundary()
    _test_typed_context_random_is_deterministic()
    _test_legacy_dictionary_compatibility()
    _test_target_query_filters_and_order()
    _test_choice_request_shortage_policies()
    _test_resumable_selection_does_not_replay_completed_effects()
    _test_combat_action_pauses_and_resumes_transactionally()
    if failures.is_empty():
        print("TECHNIQUE RUNTIME TEST PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("TECHNIQUE RUNTIME TEST FAIL: %s" % failure)
    quit(1)

func _test_technique_entities_are_individual_resources() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "功法实体测试载入统一内容目录：%s" % str(catalog.errors))
    var repository = TechniqueRepositoryScript.new()
    _assert_true(
        repository.configure(catalog.definition("techniques"), true),
        "功法仓库建立统一实体索引")
    _assert_equal(repository.definitions.size(), 47, "七门纵切夹具、三十八门风功法与两门产线探针均建立实体")
    var retired_pool_ids := ["pair_two_pair", "three_full_house", "four_five"]
    for technique_id in repository.definitions:
        var pool_id := str(repository.get_definition(str(technique_id)).pool)
        _assert_true(not retired_pool_ids.has(pool_id), "%s 正式功法资源不再使用旧池 ID" % str(technique_id))
    var wind_ids := [
        "sweeping_wind_sleeve", "full_sleeve_wind", "wind_transforms_force",
        "layered_leaves_return_tide", "long_wind_full_sleeve", "double_wind_continue_form",
        "listen_wind_stack_top", "wind_born_echo", "poison_wind_seek_meridian",
        "discard_gu_exchange_breath", "twin_wind_exchange", "measure_breath_twins",
        "twin_swallows_press_sleeve", "balance_sleeves_listen_wind",
        "twin_leaves_build_momentum", "exchange_nest_into_enemy",
        "enemy_discard_returns_nest", "double_gu_exchange_breath",
        "three_ring_breathing", "triple_layer_return_armor", "returning_wind_continue_form",
        "three_breath_turbulence", "gather_wind_faces", "three_ring_ensemble",
        "three_ring_chaos_qi", "three_cards_listen_tide", "wind_deck_return_tide",
        "exchange_sea_intake_qi", "seize_qi_return_nest", "four_poles_control_top",
        "poison_nest_seek_meridian", "full_sleeve_bind_enemy", "all_sounds_listen_wind",
        "four_symbols_harmony", "snake_path_order_meridian", "wind_path_control_top",
        "returning_loop_long_breath", "five_steps_echo",
    ]
    var wind_pool_counts := {
        "high": 0,
        "pair": 0,
        "three": 0,
        "bomb": 0,
        "straight": 0,
    }
    for wind_id in wind_ids:
        var wind_definition = repository.get_definition(wind_id)
        _assert_true(wind_definition != null, "风功法实体存在：%s" % wind_id)
        if wind_definition != null:
            wind_pool_counts[wind_definition.pool] = int(wind_pool_counts[wind_definition.pool]) + 1
    _assert_equal(wind_ids.size(), 38, "风运转功法清单固定为38门")
    _assert_equal(wind_pool_counts, {
        "high": 10,
        "pair": 8,
        "three": 8,
        "bomb": 8,
        "straight": 4,
    }, "风功法五个共用池数量为10/8/8/8/4")
    for technique_id in repository.definitions:
        var definition = repository.get_definition(technique_id)
        _assert_true(definition is TechniqueDefinition, "%s 使用统一功法实体类型" % technique_id)
        _assert_true(
            definition.resource_path.ends_with("/%s.tres" % technique_id),
            "%s 来自独立资源文件" % technique_id)
        _assert_true(not definition.effects.is_empty(), "%s 实体保存自身效果" % technique_id)
    var instance = repository.get_instance("long_wind_full_sleeve", "player", 2)
    _assert_true(instance is TechniqueInstance, "功法定义可以建立统一运行时实例")
    _assert_equal(instance.id(), "long_wind_full_sleeve", "运行时实例引用正确功法定义")
    _assert_equal(instance.owner_id, "player", "运行时实例保存拥有者")

func _test_wind_common_card_flow_rules() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(8701, false)
    var forest = _catalog_card(engine, "forest_5", "wind-common:forest")
    engine.status_system.apply_card_anomaly(forest, "mark", "wind_mark", {}, "风公共测试")
    _assert_true(forest.is_attribute("forest") and forest.is_attribute("wind"), "风标记保留原属性并同时视为风")

    var returning = _catalog_card(engine, "fire_6", "wind-common:returning")
    engine.status_system.apply_card_anomaly(returning, "mark", "returning_wind", {}, "风公共测试")
    engine.player.hand = [returning]
    engine.player.random_discard(1, engine.rng)
    _assert_true(engine.player.draw_pile.has(returning), "回风牌明确弃掉后改置牌库顶")
    _assert_true(not returning.has_anomaly("mark", "returning_wind"), "回风成功改置后移除")

    var turbulence = _catalog_card(engine, "mountain_7", "wind-common:turbulence")
    engine.status_system.apply_card_anomaly(turbulence, "mark", "turbulence", {}, "风公共测试")
    engine.enemy.draw_pile = [turbulence]
    engine.enemy.draw(1)
    _assert_true(engine.enemy.discard_pile.has(turbulence), "乱流牌抽入手后立即明确弃掉")
    _assert_true(not turbulence.has_anomaly("mark", "turbulence"), "乱流触发后移除")

    var lure = _catalog_card(engine, "forest_8", "wind-common:lure")
    var follow = _catalog_card(engine, "fire_9", "wind-common:follow")
    engine.status_system.apply_card_anomaly(lure, "mark", "wind_lure", {}, "风公共测试")
    engine.player.hand.clear()
    engine.player.draw_pile = [follow, lure]
    engine.player.draw(1)
    _assert_equal(engine.player.hand.size(), 2, "风引抽取时移除并继续额外抽1张")

    var stolen = _catalog_card(engine, "wind_10", "wind-common:stolen")
    engine.status_system.add_actor_status(engine.player, "steal_wind", 1, "风公共测试")
    engine.enemy.draw_pile = [stolen]
    engine.enemy.draw(1)
    _assert_true(engine.player.hand.has(stolen) and not engine.enemy.hand.has(stolen), "夺风先于被抽入手响应夺取风牌")
    _assert_equal(engine.player.stacks.get("steal_wind", 0), 0, "夺风每夺取1张消耗1层")

func _test_wind_high_technique_batch() -> void:
    var sweep = _wind_high_engine("sweeping_wind_sleeve", "wind_2", ["forest_3"], ["fire_4", "wind_5"], 8711)
    var sweep_result: Dictionary = sweep.confirm_play([sweep.player.hand[0].id])
    _assert_true(sweep_result.get("pending_choice", false), "掠风惊袖在抽牌后请求明确弃牌")
    var sweep_request: Dictionary = sweep.pending_effect_choice_snapshot()
    var discard_id := str(sweep.player.hand.filter(func(card): return card.definition_id == "forest_3")[0].id)
    var sweep_complete: Dictionary = sweep.resolve_effect_choice(
        str(sweep_request["request_id"]), [discard_id])
    _assert_true(sweep_complete.get("success", false), "掠风惊袖选择后完成行动")
    _assert_equal(sweep.enemy.life, 98, "掠风惊袖即时伤害读取P")
    _assert_equal(sweep.player.discard_pile.size(), 2, "掠风惊袖明确弃牌与打出牌分别进入弃牌堆")

    var full = _wind_high_engine("full_sleeve_wind", "wind_2", [], ["wind_3", "wind_4"], 8712)
    var full_result: Dictionary = full.confirm_play([full.player.hand[0].id])
    _assert_true(full_result.get("success", false), "满袖生风纯风抽牌分支完成")
    _assert_equal(full.player.defense, 2, "满袖生风获得P点防御")
    _assert_equal(full.enemy.life, 99, "满袖生风恰好抽到两张风牌后追加半P伤害")

    var long_wind = _wind_high_engine("long_wind_full_sleeve", "wind_10", [], ["wind_J"], 8713)
    long_wind.confirm_play([long_wind.player.hand[0].id])
    _assert_equal(long_wind.enemy.life, 85, "长风满袖结算P伤害与风牌半P追加伤害")

    var poison = _wind_high_engine("poison_wind_seek_meridian", "wind_10", [], [], 8714)
    var poison_card = _catalog_card(poison, "fire_7", "wind-high:poison")
    poison.status_system.apply_card_anomaly(poison_card, "poison", "lethal_poison", {}, "毒风索脉测试")
    poison.enemy.draw_pile = [poison_card]
    poison.confirm_play([poison.player.hand[0].id])
    _assert_true(poison.enemy.hand.has(poison_card), "毒风索脉从敌方牌库随机抽取带毒牌")
    _assert_equal(poison.enemy.life, 100, "毒风索脉有带毒目标时不执行失败补偿伤害")

    var exchange = _wind_high_engine("discard_gu_exchange_breath", "wind_10", ["fire_5"], [], 8715)
    var own_poison = exchange.player.hand.filter(func(card): return card.definition_id == "fire_5")[0]
    var enemy_poison = _catalog_card(exchange, "forest_7", "wind-high:enemy-poison")
    exchange.status_system.apply_card_anomaly(own_poison, "poison", "lethal_poison", {}, "弃蛊换息测试")
    exchange.status_system.apply_card_anomaly(enemy_poison, "poison", "stagnant_poison", {}, "弃蛊换息测试")
    exchange.enemy.hand = [enemy_poison]
    var exchange_result: Dictionary = exchange.confirm_play([exchange.player.hand[0].id])
    _assert_true(exchange_result.get("success", false), "弃蛊换息在双方各仅一张候选时自动完成选择")
    _assert_equal(exchange.player.stacks.get("qi_intake", 0), 2, "弃蛊换息弃掉我方毒牌获得2层纳气")
    _assert_equal(exchange.enemy.life, 93, "弃蛊换息按敌方毒牌弃前有效真气值造成伤害")

func _test_wind_cooperation_group_resolution() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(8720, false)
    engine.sequence_book.configure({
        "high_card": ["double_wind_continue_form", "long_wind_full_sleeve"],
    })
    var main_card = _catalog_card(engine, "wind_2", "cooperation:main")
    var cooperation_card = _catalog_card(engine, "forest_3", "cooperation:follow")
    engine.player.hand = [main_card, cooperation_card]
    engine.player.draw_pile.clear()
    engine.actions_available = 1

    var result: Dictionary = engine.confirm_play(
        [main_card.id], [cooperation_card.id])
    _assert_true(result.get("success", false), "双风接式完成主组与协同组的顺序结算")
    _assert_equal(result["preview"]["values"]["technique_value"], 3, "主组读取P_main加半个P_coop的共享功法值")
    _assert_equal(result["cooperation_preview"]["values"]["technique_value"], 3, "协同组读取同一个共享功法值")
    ## 双风接式 floor(P/2)=1 加协同组长风满袖 P=3，共 4 点。
    ## 牌库已清空，长风满袖的直接抽牌捕获为空，按 capture_all_attribute 对空集合
    ## 返回 false 走防御分支，不额外造成伤害。
    _assert_equal(engine.enemy.life, 96, "双风接式半P伤害与协同高牌功法依次结算")
    _assert_true(engine.player.discard_pile.has(main_card), "主牌型组先完成离场并进入我方弃牌堆")
    _assert_true(engine.enemy.draw_pile.has(cooperation_card), "双风接式将协同牌改置敌方牌库顶")
    _assert_true(not engine.player.discard_pile.has(cooperation_card), "改置敌方牌库的协同牌不进入我方弃牌堆")
    _assert_equal(engine.sequence_book.position("high_card"), 0, "同牌型主组与协同组各成功推进一次循环序列")

func _test_wind_echo_and_five_card_power() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(8721, false)
    engine.sequence_book.configure({
        "high_card": ["wind_born_echo"],
        "pair": ["double_gu_bind"],
    })
    var played = _catalog_card(engine, "wind_2", "echo:played")
    var pair_a = _catalog_card(engine, "forest_5", "echo:pair-a")
    var pair_b = _catalog_card(engine, "fire_5", "echo:pair-b")
    engine.player.hand = [played, pair_a, pair_b]
    engine.player.draw_pile.clear()
    engine.actions_available = 1
    var result: Dictionary = engine.confirm_play([played.id])
    _assert_true(result.get("success", false), "风生回响记录P并建立回合末延迟重触")
    _assert_equal(engine.enemy.life, 98, "风生回响即时伤害读取P")
    engine.timing_system.emit_timing(
        engine.timing_system.TURN_END,
        {"round_number": 1, "actor": engine.player, "actors": [engine.player]})
    _assert_equal(engine.player.defense, 1, "风生回响以记录P重触当前一对功法")
    _assert_equal(engine.enemy.stacks.get("gu_mark", 0), 1, "风生回响重触功法条件与层数效果生效")
    _assert_true(engine.player.hand.is_empty(), "风生回响回合末明确弃掉全部手牌")

    var five_engine = CombatEngineScript.new()
    five_engine.setup(8722, false)
    five_engine.sequence_book.configure({"straight": ["returning_loop_long_breath"]})
    var straight_cards: Array = []
    for definition_id in ["wind_2", "forest_3", "fire_4", "mountain_5", "wind_6"]:
        var card = _catalog_card(
            five_engine, definition_id, "five-wind:%s" % definition_id)
        if not card.is_attribute("wind"):
            five_engine.status_system.apply_card_anomaly(
                card, "mark", "wind_mark", {}, "纯风顺子测试")
        straight_cards.append(card)
    five_engine.player.hand = straight_cards
    five_engine.player.draw_pile.clear()
    five_engine.actions_available = 1
    var straight_result: Dictionary = five_engine.confirm_play(
        straight_cards.map(func(card): return card.id))
    _assert_true(straight_result.get("success", false), "五张同属性真气完成顺子功法")
    _assert_equal(straight_result["preview"]["hand"]["id"], "straight", "同属性顺子不升级为同花牌型")
    _assert_equal(straight_result["preview"]["hand"]["multiplier"], 4, "同属性顺子保持顺子固定倍率")
    _assert_equal(straight_result["preview"]["values"]["power_amp_percent"], 50, "五张同属性真气获得50%功法值增幅")
    _assert_equal(five_engine.player.draw_pile.size(), 5, "回环长息将顺子五张牌洗回牌库")

func _test_wind_four_kind_card_flow_and_persistent_trigger() -> void:
    var tide = CombatEngineScript.new()
    tide.setup(8723, false)
    tide.sequence_book.configure({"four_kind": ["wind_deck_return_tide"]})
    var four_cards: Array = []
    for attribute in ["wind", "forest", "fire", "mountain"]:
        four_cards.append(_catalog_card(
            tide, "%s_2" % attribute, "four-tide:played:%s" % attribute))
    tide.player.hand = four_cards
    var wind_discard = _catalog_card(tide, "wind_3", "four-tide:discard:wind")
    tide.player.discard_pile = [
        wind_discard,
        _catalog_card(tide, "forest_4", "four-tide:discard:forest"),
        _catalog_card(tide, "fire_5", "four-tide:discard:fire"),
        _catalog_card(tide, "mountain_6", "four-tide:discard:mountain"),
    ]
    tide.player.draw_pile.clear()
    tide.actions_available = 1
    var tide_result: Dictionary = tide.confirm_play(
        four_cards.map(func(card): return card.id))
    _assert_true(tide_result.get("success", false), "风库回潮完成四条分支结算")
    _assert_equal(tide.player.defense, 56, "风库回潮获得P点防御")
    _assert_equal(tide.player.draw_pile.size(), 2, "风库回潮将非风合格牌的一半向上取整洗回")
    _assert_true(tide.player.discard_pile.has(wind_discard), "四条风库回潮不把风牌计入默认合格目标")

    var harmony = CombatEngineScript.new()
    harmony.setup(8724, false)
    harmony.sequence_book.configure({"four_kind": ["four_symbols_harmony"]})
    var harmony_four: Array = []
    for attribute in ["wind", "forest", "fire", "mountain"]:
        harmony_four.append(_catalog_card(
            harmony, "%s_7" % attribute, "harmony:played:%s" % attribute))
    var retained = _catalog_card(harmony, "forest_8", "harmony:retained")
    harmony.player.hand = harmony_four + [retained]
    harmony.player.draw_pile.clear()
    harmony.actions_available = 1
    harmony.confirm_play(harmony_four.map(func(card): return card.id))
    _assert_equal(harmony.player.stacks.get("four_symbols_harmony", 0), 1, "四条建立1点四象合鸣倍率")
    _assert_true(harmony.player.discard_pile.has(retained), "四象合鸣建立前先明确弃掉剩余整手")
    _assert_equal(harmony.enemy.life, 100, "四象合鸣建立前的首次整手弃牌不造成伤害")
    var drawn = _catalog_card(harmony, "wind_9", "harmony:drawn")
    harmony.player.draw_pile = [drawn]
    harmony.effect_ports.draw(harmony.player, 1, "technique")
    _assert_equal(harmony.player.defense, 1, "四象合鸣统计后续功法直接抽牌并获得防御")
    harmony.effect_ports.discard_random(harmony.player, 1, harmony.rng)
    _assert_equal(harmony.enemy.life, 99, "四象合鸣统计后续功法明确弃牌并造成伤害")

func _test_stagnant_gu_conceal_breath_pipeline() -> void:
    var hand_target = _wind_high_engine(
        "stagnant_gu_conceal_breath", "forest_10", [], [], 8731)
    var first_hand = _catalog_card(hand_target, "wind_3", "stagnant:hand:first")
    var second_hand = _catalog_card(hand_target, "fire_4", "stagnant:hand:second")
    hand_target.enemy.hand = [first_hand, second_hand]
    var hand_preview: Dictionary = hand_target.preview([hand_target.player.hand[0].id])
    var hand_result: Dictionary = hand_target.confirm_play([hand_target.player.hand[0].id])
    _assert_equal(hand_preview["intent"]["defense"], 10, "郁蛊敛息预览获得P点防御")
    _assert_equal(hand_target.player.defense, 10, "郁蛊敛息实际防御与预览一致")
    _assert_true(hand_result.get("success", false), "郁蛊敛息手牌目标链完成")
    _assert_equal(_anomaly_count(hand_target.enemy.hand, "poison", "stagnant_poison"), 1, "敌方手牌随机一张合格真气获得郁毒")

    var deck_fallback = _wind_high_engine(
        "stagnant_gu_conceal_breath", "forest_10", [], [], 8732)
    var hand_zero_qi = _catalog_card(deck_fallback, "mountain_2", "stagnant:fallback:hand-zero-qi")
    hand_zero_qi.qi_value = 0
    deck_fallback.enemy.hand = [hand_zero_qi]
    var lower = _catalog_card(deck_fallback, "wind_3", "stagnant:fallback:lower")
    var top = _catalog_card(deck_fallback, "fire_4", "stagnant:fallback:top")
    deck_fallback.enemy.draw_pile = [lower, top]
    deck_fallback.confirm_play([deck_fallback.player.hand[0].id])
    _assert_true(top.has_anomaly("poison", "stagnant_poison"), "纯林高牌从牌库顶向下命中第一张合法目标")
    _assert_true(not lower.has_anomaly("poison"), "牌库候补找到第一张后停止继续附毒")

    var no_target = _wind_high_engine(
        "stagnant_gu_conceal_breath", "forest_10", [], [], 8733)
    var no_hand = _catalog_card(no_target, "mountain_2", "stagnant:none:hand")
    var no_deck = _catalog_card(no_target, "mountain_3", "stagnant:none:deck")
    no_hand.qi_value = 0
    no_deck.qi_value = 0
    no_target.enemy.hand = [no_hand]
    no_target.enemy.draw_pile = [no_deck]
    var no_result: Dictionary = no_target.confirm_play([no_target.player.hand[0].id])
    _assert_true(no_result.get("success", false), "郁蛊敛息没有合法目标时只结算实际部分")
    _assert_equal(_anomaly_count([no_hand, no_deck], "poison", "stagnant_poison"), 0, "没有合法目标时不错误施加郁毒")

func _test_borrow_fire_guard_heart_pipeline() -> void:
    var guarded = _wind_high_engine(
        "borrow_fire_guard_heart", "fire_10", [], [], 8741)
    guarded.player.defense = 1
    var guarded_preview: Dictionary = guarded.preview([guarded.player.hand[0].id])
    var guarded_result: Dictionary = guarded.confirm_play([guarded.player.hand[0].id])
    _assert_true(guarded_result.get("success", false), "借火护心有防御分支完成")
    _assert_equal(guarded_preview["intent"]["damage"], 5, "借火护心预览floor(P/2)伤害")
    _assert_equal(guarded.enemy.life, 95, "借火护心实际伤害与预览一致")
    _assert_equal(guarded.player.stacks.get("borrowed_force", 0), 1, "结算时有防御获得一层借力")

    var exposed = _wind_high_engine(
        "borrow_fire_guard_heart", "fire_10", [], [], 8742)
    exposed.player.defense = 0
    exposed.confirm_play([exposed.player.hand[0].id])
    _assert_equal(exposed.player.stacks.get("borrowed_force", 0), 2, "结算时防御为零改为两层借力")

func _test_borrowed_force_attack_segments() -> void:
    var defense_only = _borrowed_force_engine(1)
    defense_only.player.defense = 5
    defense_only.effect_ports.deal_damage(
        defense_only.enemy, defense_only.player, 3, "technique")
    _assert_equal(defense_only.player.defense, 2, "借力记录只损失防御的攻击段")
    _assert_equal(defense_only.enemy.life, 97, "只损失防御时按实际损失反击")
    _assert_equal(defense_only.player.stacks.get("borrowed_force", 0), 0, "实际损失后消耗一层借力")
    _assert_true(
        defense_only.status_system.history.any(func(entry):
            return entry.get("change_type", "") == "actor_status_consume" \
                and entry.get("status_id", "") == "borrowed_force"),
        "借力消费进入统一状态历史")
    _assert_true(
        defense_only.trigger_queue.history.any(func(entry):
            return entry.get("timing", "") == "damage_segment" \
                and entry.get("source", "") == "counter"),
        "借力反击进入统一战斗日志")

    var life_only = _borrowed_force_engine(1)
    life_only.effect_ports.deal_damage(life_only.enemy, life_only.player, 4, "chase")
    _assert_equal(life_only.player.life, 96, "借力记录只损失生命的攻击段")
    _assert_equal(life_only.enemy.life, 96, "只损失生命时按实际损失反击")

    var mixed = _borrowed_force_engine(1)
    mixed.player.defense = 2
    mixed.effect_ports.deal_damage(mixed.enemy, mixed.player, 5, "counter")
    _assert_equal(mixed.player.life, 97, "攻击段可以同时减少防御与生命")
    _assert_equal(mixed.enemy.life, 95, "同时损失时反击等于防御与生命损失之和")

    var blocked = _borrowed_force_engine(1)
    blocked.effect_ports.deal_damage(blocked.enemy, blocked.player, 0, "technique")
    _assert_equal(blocked.player.stacks.get("borrowed_force", 0), 1, "没有实际损失时不消耗借力")
    _assert_equal(blocked.enemy.life, 100, "没有实际损失时不加入反击")

    var segmented = _borrowed_force_engine(2)
    segmented.player.defense = 2
    var context = EffectContextScript.new().configure({
        "actor": segmented.enemy,
        "target": segmented.player,
        "power": 3,
        "ports": segmented.effect_ports,
    })
    segmented.effect_executor.execute_all([{
        "op": "multi_damage",
        "segments": 3,
        "amount": {"kind": "constant", "value": 3},
    }], context)
    _assert_equal(segmented.player.life, 93, "敌方多段攻击逐段读取防御与生命")
    _assert_equal(segmented.enemy.life, 94, "两层借力分别响应前两个实际损失攻击段")
    _assert_equal(segmented.player.stacks.get("borrowed_force", 0), 0, "多段攻击按段消耗借力")

    var lethal_counter = _borrowed_force_engine(1)
    lethal_counter.enemy.life = 2
    var lethal_context = EffectContextScript.new().configure({
        "actor": lethal_counter.enemy,
        "target": lethal_counter.player,
        "ports": lethal_counter.effect_ports,
    })
    lethal_counter.effect_executor.execute_all([{
        "op": "multi_damage",
        "segments": 3,
        "amount": {"kind": "constant", "value": 3},
    }], lethal_context)
    _assert_equal(lethal_counter.player.life, 97, "借力反击击杀攻击者后停止后续攻击段")
    _assert_equal(lethal_counter.enemy.life, 0, "致死借力反击按普通伤害结算")

func _wind_high_engine(
        technique_id: String,
        played_definition_id: String,
        retained_definition_ids: Array,
        draw_definition_ids: Array,
        seed: int):
    var engine = CombatEngineScript.new()
    engine.setup(seed, false)
    engine.sequence_book.configure({"high_card": [technique_id]})
    engine.player.hand = [_catalog_card(engine, played_definition_id, "%s:played" % technique_id)]
    for index in range(retained_definition_ids.size()):
        engine.player.hand.append(_catalog_card(
            engine,
            str(retained_definition_ids[index]),
            "%s:retained:%d" % [technique_id, index]))
    engine.player.draw_pile.clear()
    for index in range(draw_definition_ids.size()):
        engine.player.draw_pile.append(_catalog_card(
            engine,
            str(draw_definition_ids[index]),
            "%s:draw:%d" % [technique_id, index]))
    engine.actions_available = 1
    return engine

func _catalog_card(engine, definition_id: String, instance_id: String):
    return DeckFactoryScript.create_card_instance(
        engine.content_catalog.get_by_id("card", definition_id),
        instance_id)

func _borrowed_force_engine(stacks: int):
    var engine = CombatEngineScript.new()
    engine.setup(8750 + stacks, false)
    engine.player.defense = 0
    engine.player.life = 100
    engine.enemy.defense = 0
    engine.enemy.life = 100
    engine.status_system.add_actor_status(
        engine.player, "borrowed_force", stacks, "借力测试")
    return engine

func _anomaly_count(cards: Array, category: String, anomaly_id: String) -> int:
    var count := 0
    for card in cards:
        if card.has_anomaly(category, anomaly_id):
            count += 1
    return count

func _test_structured_context_and_ports() -> void:
    var actor = BattleSideScript.new("行动方", "actor")
    var target = BattleSideScript.new("目标", "target")
    ## 端口依赖必须是真实实例。此前这里传空构造，导致 add_stack 断言实际走的是
    ## 端口内的 null 兜底分支，而不是它声称验证的 StatusSystem 生产路径。
    var catalog = ContentCatalogScript.new()
    catalog.load_all()
    var status_system = StatusSystemScript.new(catalog)
    var ports = EffectPortsScript.new(
        DamageResolverScript.new(),
        status_system,
        BattleFlowCoordinatorScript.new(),
        TriggerQueueScript.new())
    ports.use_sides(actor, target)
    status_system.use_effect_ports(ports)
    var captures := {}
    var context = EffectContextScript.new().configure({
        "actor": actor,
        "target": target,
        "hand_result": {"id": "high_card", "contributing": []},
        "played_cards": [],
        "power": 20,
        "technique_id": "runtime_contract",
        "technique_name": "运行时契约",
        "action_token": "action-001",
        "source_kind": "technique",
        "captures": captures,
        "ports": ports,
    })
    _assert_equal(context.power, 20, "类型化上下文保存功法值")
    _assert_equal(context.technique_id, "runtime_contract", "类型化上下文保存功法身份")
    _assert_true(not context.public_metadata().has("engine"), "公开上下文不暴露完整战斗引擎")
    _assert_true(context.captures == captures, "类型化上下文共享同一捕获表")

    actor.draw_pile = [_card_stub("draw-1"), _card_stub("draw-2")]
    var rng := RandomNumberGenerator.new()
    rng.seed = 8601
    var executor = EffectExecutorScript.new(rng)
    var preview: Dictionary = executor.summarize_intent([
        {"op": "defense", "amount": {"kind": "power_fraction", "numerator": 1, "denominator": 2}},
    ], context)
    var result: Dictionary = executor.execute_all([
        {"op": "defense", "amount": {"kind": "power_fraction", "numerator": 1, "denominator": 2}},
        {"op": "draw", "count": {"kind": "constant", "value": 1}, "capture": "drawn"},
        {"op": "add_stack", "stack": "momentum", "amount": {"kind": "constant", "value": 2}},
    ], context)
    _assert_true(result["success"], "类型化上下文通过统一执行器完成效果链")
    _assert_equal(preview["defense"], 10, "预览与执行共用同一数值解析规则")
    _assert_equal(actor.defense, 10, "防御修改通过窄端口执行")
    _assert_equal(actor.hand.size(), 1, "抽牌修改通过窄端口执行")
    _assert_equal(actor.stacks.get("momentum", 0), 2, "角色状态修改通过窄端口执行")
    _assert_equal(context.captures.get("drawn", []).size(), 1, "效果捕获写回类型化上下文")

func _test_action_preview_dto_contract() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(8603, false)
    engine.start_player_turn()
    var dto = engine.action_preview_service.preview_dto(
        engine.player,
        [engine.player.hand[0].id],
        engine.sequence_book)
    _assert_equal(dto.SCHEMA_VERSION, 1, "行动预览 DTO 使用稳定版本号")
    _assert_true(dto.valid, "行动预览 DTO 保留合法结果")
    _assert_equal(dto.hand.id != "", true, "牌型 DTO 保留牌型身份")
    _assert_equal(dto.hand.to_dict()["schema_version"], 1, "牌型 DTO 使用稳定版本号")
    _assert_true(dto.to_dict().has("values"), "行动预览 DTO 可转换为兼容快照")

func _test_action_and_dispatch_dto_contracts() -> void:
    var proposal = BattleActionProposalScript.new().configure_accept(
        "runtime_test",
        ["wind_2"],
        {"valid": true, "hand": {"id": "high_card"}},
        3.5)
    _assert_equal(proposal.snapshot()["schema_version"], 1, "行动提案 DTO 使用稳定版本号")
    _assert_equal(proposal.to_dict()["controller_id"], "runtime_test", "行动提案 DTO 保留控制器身份")

    var engine = CombatEngineScript.new()
    engine.setup(8604, false)
    var record = engine.action_resolver.make_action_record(
        engine.player,
        engine.enemy,
        {"hand": {"id": "high_card", "name": "高牌"}, "technique_id": ""},
        engine.sequence_book,
        100,
        2)
    _assert_equal(record.snapshot()["schema_version"], 1, "行动记录 DTO 使用稳定版本号")
    _assert_equal(record.turn_number, 2, "行动记录 DTO 保存回合号")

    var dispatcher = NodeDispatcherScript.new({
        "node_types": {
            "combat": {
                "route": "battle",
                "content_id": "runtime_combat",
                "title": "测试战斗",
                "battle": {"scenario_path": "res://data/scripted_battle.json"},
            },
        },
    })
    var dispatch = dispatcher.dispatch_dto(
        {"id": "node-1", "type": "combat", "row": 1, "column": 2},
        {"seed": 8, "act": 1})
    _assert_true(dispatch.success, "节点调度 DTO 保留成功结果")
    _assert_equal(dispatch.to_dict()["schema_version"], 1, "节点调度 DTO 使用稳定版本号")
    _assert_equal(dispatch.route, "battle", "节点调度 DTO 保留路由")

    var command = BattleCommandScript.new().configure({
        "type": "move_technique_slot",
        "direction": -1,
        "card_ids": ["wind_2"],
        "cooperation_card_ids": ["forest_3"],
    })
    _assert_equal(command.snapshot()["schema_version"], 1, "战斗命令 DTO 使用稳定版本号")
    _assert_equal(command.direction, -1, "战斗命令 DTO 保留方向")
    _assert_equal(command.cooperation_card_ids, ["forest_3"], "战斗命令 DTO 保留协同组选牌")
    var command_result := CommandResultScript.from_dict(
        command.type,
        {"success": false, "reason": "测试拒绝", "value": 7})
    _assert_equal(command_result.to_dict()["schema_version"], 1, "命令结果 DTO 使用稳定版本号")
    _assert_equal(command_result.status, "rejected", "命令拒绝使用稳定状态字段")
    _assert_equal(command_result.reason_or("默认原因"), "测试拒绝", "命令结果公开统一原因入口")
    _assert_equal(command_result.payload_value("value"), 7, "命令结果 DTO 保留扩展负载")
    var successful_command := CommandResultScript.from_dict(
        "claim_reward",
        {"success": true, "phase": "awaiting_node", "experience": 3})
    _assert_equal(successful_command.status, "succeeded", "成功命令使用稳定状态字段")
    _assert_equal(successful_command.phase, "awaiting_node", "流程阶段使用显式字段")
    _assert_equal(successful_command.payload_value("experience"), 3, "领域数据进入命令负载")
    _assert_equal(
        engine.pending_action_transaction_snapshot()["schema_version"],
        1,
        "待恢复行动事务 DTO 使用稳定版本号")

func _test_structured_results_and_pending_boundary() -> void:
    var success = EffectResultScript.succeeded("完成", {"value": 3})
    var failure = EffectResultScript.failed("失败")
    _assert_equal(success.snapshot()["status"], "succeeded", "成功结果具有稳定状态")
    _assert_true(success.snapshot()["success"], "成功结果公开 success")
    _assert_equal(failure.snapshot()["status"], "failed", "失败结果具有稳定状态")
    _assert_true(not failure.snapshot()["success"], "失败结果不会误报成功")

    var rng := RandomNumberGenerator.new()
    var executor = EffectExecutorScript.new(rng)
    _assert_true(executor.registry.register_handler(PendingChoiceHandlerScript.new()), "运行时允许注册等待选择处理器")
    var pending: Dictionary = executor.execute_all(
        [{"op": "test_pending_choice"}],
        EffectContextScript.new())
    _assert_equal(pending["status"], "pending_choice", "统一执行器保留等待选择状态")
    _assert_true(pending["pending_choice"], "等待选择不会被当作普通失败吞掉")
    _assert_equal(pending["choice_request"]["request_id"], "choice-001", "选择请求结构完整传出")

func _test_legacy_dictionary_compatibility() -> void:
    var actor = BattleSideScript.new("兼容行动方")
    var rng := RandomNumberGenerator.new()
    var executor = EffectExecutorScript.new(rng)
    var result: Dictionary = executor.execute_all([
        {"op": "defense", "amount": {"kind": "constant", "value": 4}},
    ], {"actor": actor, "power": 0, "captures": {}})
    _assert_true(result["success"], "旧字典调用在迁移期保持兼容")
    _assert_equal(actor.defense, 4, "旧字典调用仍产生相同行为")

    var engine = CombatEngineScript.new()
    engine.setup(8602, false)
    var legacy_context = EffectContextScript.new().configure({
        "engine": engine,
        "actor": engine.player,
        "target": engine.enemy,
        "captures": {},
    })
    _assert_true(
        legacy_context.ports == engine.action_resolver.effect_ports,
        "旧上下文字典只适配到窄效果端口，不保留完整战斗引擎")

func _test_typed_context_random_is_deterministic() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "确定性目标测试载入统一内容目录")
    var first_target = BattleSideScript.new("第一目标")
    var second_target = BattleSideScript.new("第二目标")
    for definition_id in ["wind_2", "forest_5", "fire_9"]:
        first_target.hand.append(DeckFactoryScript.create_card_instance(
            catalog.get_by_id("card", definition_id),
            "first:%s" % definition_id))
        second_target.hand.append(DeckFactoryScript.create_card_instance(
            catalog.get_by_id("card", definition_id),
            "second:%s" % definition_id))
    var effect := {
        "op": "apply_random_card_anomaly",
        "zone": "hand",
        "category": "poison",
        "anomaly": "lethal_poison",
        "count": 1,
    }
    var first_rng := RandomNumberGenerator.new()
    first_rng.seed = 8602
    var second_rng := RandomNumberGenerator.new()
    second_rng.seed = 8602
    var first_result: Dictionary = EffectExecutorScript.new(
        first_rng, null, catalog).execute_all(
            [effect],
            EffectContextScript.new().configure({"target": first_target}))
    var second_result: Dictionary = EffectExecutorScript.new(
        second_rng, null, catalog).execute_all(
            [effect],
            EffectContextScript.new().configure({"target": second_target}))
    _assert_true(first_result["success"] and second_result["success"], "类型化上下文随机目标效果成功执行")
    _assert_equal(
        _poisoned_definition_id(first_target),
        _poisoned_definition_id(second_target),
        "相同固定种子在类型化上下文中选择相同目标")

func _test_target_query_filters_and_order() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "目标查询测试载入统一内容目录")
    var actor = BattleSideScript.new("查询行动方", "query_actor")
    var target = BattleSideScript.new("查询目标", "query_target")
    var wind_two = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_2"), "query:wind_2")
    var wind_three = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "wind_3"), "query:wind_3")
    var fire_four = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", "fire_4"), "query:fire_4")
    wind_three.set_anomaly("poison", "lethal_poison")
    fire_four.qi_value = 0
    target.draw_pile = [wind_two, wind_three, fire_four]
    var context = EffectContextScript.new().configure({
        "actor": actor,
        "target": target,
    })
    var query = TargetQueryScript.new().configure({
        "side": "target",
        "zone": "draw_pile",
        "order": "top",
        "filters": {
            "attributes": ["wind"],
            "card_kind": "normal",
            "anomaly": {"category": "poison", "present": false},
        },
    })
    var result: Dictionary = query.resolve(context)
    _assert_true(result["success"], "目标查询接受阵营、牌区与组合筛选")
    _assert_equal(result["cards"].size(), 1, "目标查询排除毒牌与零有效真气牌")
    _assert_equal(result["cards"][0].id, wind_two.id, "目标查询返回正确实例")

    var top_query = TargetQueryScript.new().configure({
        "side": "target",
        "zone": "draw_pile",
        "order": "top",
        "limit": 2,
    })
    var top_result: Dictionary = top_query.resolve(context)
    _assert_equal(top_result["cards"][0].id, fire_four.id, "牌库顶查询以 draw_pile.back 为第一张")
    _assert_equal(top_result["cards"][1].id, wind_three.id, "牌库顶查询保持向下顺序")

func _test_choice_request_shortage_policies() -> void:
    var candidate = _choice_card_stub("only-card")
    var use_available = ChoiceRequestScript.new().configure({
        "request_id": "choice-shortage-use",
        "minimum": 2,
        "maximum": 2,
        "insufficient_policy": "use_available",
        "candidates": [candidate],
    })
    _assert_equal(use_available.effective_limits()["minimum"], 1, "目标不足时 use_available 收缩最小数量")
    _assert_true(use_available.should_auto_resolve(), "必须选择全部剩余目标时无需额外交互")
    var fail_request = ChoiceRequestScript.new().configure({
        "request_id": "choice-shortage-fail",
        "minimum": 2,
        "maximum": 2,
        "insufficient_policy": "fail",
        "candidates": [candidate],
    })
    _assert_true(fail_request.requires_failure(), "目标不足时 fail 明确令效果失败")
    var skip_request = ChoiceRequestScript.new().configure({
        "request_id": "choice-shortage-skip",
        "minimum": 2,
        "maximum": 2,
        "insufficient_policy": "skip",
        "candidates": [candidate],
    })
    _assert_true(skip_request.should_auto_resolve(), "目标不足时 skip 自动以空选择继续")
    _assert_true(skip_request.validate_selection([])["ok"], "skip 的空选择满足恢复契约")
    var missing_policy = ChoiceRequestScript.new().configure({
        "request_id": "choice-shortage-missing",
        "minimum": 0,
        "maximum": 1,
        "candidates": [candidate],
    })
    _assert_true(not missing_policy.validate_definition()["ok"], "目标不足策略不能依靠未确认默认值")

func _test_resumable_selection_does_not_replay_completed_effects() -> void:
    var catalog = ContentCatalogScript.new()
    _assert_true(catalog.load_all(), "可恢复选择测试载入统一内容目录")
    var actor = BattleSideScript.new("选择行动方", "choice_actor")
    for definition_id in ["wind_2", "wind_3", "fire_4"]:
        actor.hand.append(DeckFactoryScript.create_card_instance(
            catalog.get_by_id("card", definition_id),
            "choice:%s" % definition_id))
    var context = EffectContextScript.new().configure({
        "actor": actor,
        "target": BattleSideScript.new("选择目标", "choice_target"),
        "power": 10,
        "technique_id": "choice_runtime",
        "action_token": "choice-action",
    })
    var rng := RandomNumberGenerator.new()
    rng.seed = 8603
    var executor = EffectExecutorScript.new(rng, null, catalog)
    var result: Dictionary = executor.execute_all([
        {"op": "defense", "amount": {"kind": "constant", "value": 5}},
        {
            "op": "select_cards",
            "choice_id": "wind_card",
            "prompt": "选择一张风属性真气",
            "chooser": "actor",
            "query": {
                "side": "actor",
                "zone": "hand",
                "order": "zone",
                "filters": {"attributes": ["wind"], "card_kind": "normal"},
            },
            "minimum": 1,
            "maximum": 1,
            "insufficient_policy": "use_available",
            "capture": "selected_wind",
        },
        {
            "op": "add_stack_per_captured_card",
            "capture": "selected_wind",
            "stack": "momentum",
            "default": 2,
        },
    ], context)
    _assert_true(result["pending_choice"], "选择效果暂停统一执行器")
    _assert_equal(actor.defense, 5, "暂停前效果已经结算一次")
    _assert_equal(result["choice_request"]["candidate_ids"].size(), 2, "选择请求只公开合格候选")
    var rng_state_after_request: int = rng.state
    var continuation = result["_continuation"]
    var invalid: Dictionary = executor.resume(
        continuation,
        result["choice_request"]["request_id"],
        [actor.hand[2].id])
    _assert_true(invalid["pending_choice"], "候选外选择被拒绝且保持暂停")
    _assert_equal(actor.defense, 5, "非法选择不会重放已完成防御")
    _assert_equal(rng.state, rng_state_after_request, "非法选择不会重新查询或消耗随机数")
    var chosen_id: String = str(result["choice_request"]["candidate_ids"][0])
    var completed: Dictionary = executor.resume(
        continuation,
        result["choice_request"]["request_id"],
        [chosen_id])
    _assert_true(completed["success"], "合法选择从原效果下标恢复")
    _assert_equal(actor.defense, 5, "恢复后不重放选择前效果")
    _assert_equal(actor.stacks.get("momentum", 0), 2, "恢复后继续执行选择后的效果")
    _assert_equal(context.captures["selected_wind"][0].id, chosen_id, "选择结果写入通用捕获表")
    _assert_equal(rng.state, rng_state_after_request, "恢复使用冻结候选且不重复消耗随机数")

func _test_combat_action_pauses_and_resumes_transactionally() -> void:
    var engine = CombatEngineScript.new()
    engine.setup(8604, false)
    engine.repository.configure({
        "pool_membership": {"high_card": ["high"]},
        "techniques": [{
            "id": "transactional_choice",
            "name": "事务选择测试",
            "pool": "high",
            "special": false,
            "effects": [
                {"op": "defense", "amount": {"kind": "constant", "value": 5}},
                {
                    "op": "select_cards",
                    "choice_id": "retain_one",
                    "prompt": "选择一张剩余手牌",
                    "chooser": "actor",
                    "query": {"side": "actor", "zone": "hand", "order": "zone"},
                    "minimum": 1,
                    "maximum": 1,
                    "insufficient_policy": "use_available",
                    "capture": "retained",
                },
            ],
        }],
    })
    engine.sequence_book.configure({
        "high_card": ["transactional_choice", "after_choice"],
    })
    engine.start_player_turn()
    var played_id: String = str(engine.player.hand[0].id)
    var result: Dictionary = engine.confirm_play([played_id])
    _assert_true(result["success"] and result["pending_choice"], "战斗行动在功法选择处暂停")
    _assert_equal(engine.player.staging.size(), 1, "暂停期间打出真气仍留在待出区")
    _assert_equal(engine.player.discard_pile.size(), 0, "暂停期间不提前进入弃牌堆")
    _assert_equal(engine.sequence_book.position("high_card"), 0, "暂停期间功法序列不推进")
    _assert_equal(engine.player.defense, 5, "暂停前阶段效果已经建立")
    var session: BattleSession = BattleSessionScript.new(engine)
    var request: Dictionary = session.snapshot().pending_choice
    _assert_equal(request["request_id"], engine.pending_effect_choice_snapshot()["request_id"], "战斗快照公开同一选择请求")
    var rejected := session.execute({
        "type": "resolve_choice",
        "request_id": str(request["request_id"]),
        "card_ids": ["not-a-candidate"],
    })
    _assert_true(
        not rejected.success and rejected.payload_value("pending_choice", false),
        "战斗核拒绝非法选择并保持事务")
    _assert_equal(engine.player.defense, 5, "战斗核非法恢复不重复结算")
    var completed := session.execute({
        "type": "resolve_choice",
        "request_id": str(request["request_id"]),
        "card_ids": [request["candidate_ids"][0]],
    })
    _assert_true(
        completed.success and not completed.payload_value("pending_choice", false),
        "合法选择完成整次行动")
    _assert_equal(engine.player.staging.size(), 0, "恢复完成后清空待出区")
    _assert_equal(engine.player.discard_pile.size(), 1, "恢复完成后打出真气进入弃牌堆")
    _assert_equal(engine.sequence_book.position("high_card"), 1, "恢复完成后功法序列只推进一格")
    _assert_equal(engine.player.defense, 5, "完整事务中选择前效果只结算一次")

func _card_stub(card_id: String):
    var card = RefCounted.new()
    card.set_meta("runtime_test_id", card_id)
    return card

func _choice_card_stub(card_id: String):
    return _ChoiceCardStub.new(card_id)

class _ChoiceCardStub:
    extends RefCounted

    var id: String

    func _init(value: String) -> void:
        id = value

    func to_dict() -> Dictionary:
        return {"id": id, "instance_id": id}

func _poisoned_definition_id(side) -> String:
    for card in side.hand:
        if card.has_anomaly("poison", "lethal_poison"):
            return str(card.definition_id)
    return ""

func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append("%s：期望为 true" % label)
