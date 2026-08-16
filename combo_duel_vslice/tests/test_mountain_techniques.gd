extends "res://tests/support/expanded_technique_test_base.gd"

const MOUNTAIN_TECHNIQUES := {
    "high_mountain_array_stones":"山·列石",
    "high_mountain_lone_peak":"山·独峰",
    "high_mountain_meet_edge":"山·迎锋",
    "high_mountain_still_peak":"山·静岳",
    "high_mountain_hear_edge":"山·听锋",
    "high_mountain_shed_wall":"山·舍壁还生",
    "pair_mountain_collect_stone":"山·收石",
    "pair_mountain_crossed_rock":"山·错岩",
    "pair_mountain_embrace_one":"山·抱一",
    "pair_mountain_piled_ridges":"山·积峦",
    "pair_mountain_shift_formation":"山·移阵",
    "pair_mountain_poison_cave":"山·蛊穴",
    "pair_mountain_hidden_jade":"山·藏璞",
    "pair_mountain_return_armor":"山·回甲",
    "pair_mountain_reflection_momentum":"山·借震生势",
    "pair_mountain_poison_armor":"山·蛊甲",
    "pair_mountain_discard_wall":"山·弃石成墙",
    "pair_mountain_flawless_wall":"山·无漏壁",
    "pair_mountain_forging_guard":"山·打铁式",
    "pair_mountain_broken_armor_qi":"山·折甲行气",
    "pair_mountain_three_knocks":"山·听阵三叩",
    "three_mountain_guard_jade":"山·护璞",
    "three_mountain_joined_ridge":"山·合脊",
    "three_mountain_high_card_cooperate":"山·列峰并阵",
    "three_mountain_layered_formation":"山·叠阵",
    "three_mountain_temper_stone":"山·砺石",
    "three_mountain_reflection_crack":"山·震裂",
    "three_mountain_mixed_armor":"山·浑甲",
    "three_mountain_aftershock":"山·余震",
    "three_mountain_ash_rampart":"山·灰垒",
    "three_mountain_cross_guard":"山·横架",
    "three_mountain_challenge_gate":"山·擂关",
    "straight_mountain_long_wall":"山·长垣",
    "straight_mountain_split_ridge":"山·分岭",
    "straight_mountain_open_mountain":"山·开山",
    "straight_mountain_seal_pass":"山·封关",
    "straight_mountain_reshape_rampart":"山·返璞成垒",
    "straight_mountain_meet_wave":"山·迎浪",
    "straight_mountain_iron_wall":"山·铁壁",
    "straight_mountain_true_reflection":"山·逆震",
    "straight_mountain_valley_echo":"山·空谷回声",
    "straight_mountain_hidden_edge":"山·裂壁藏锋",
    "bomb_mountain_four_symbols":"山·四象镇岳",
    "bomb_mountain_five_peaks":"山·五岳定极",
    "bomb_mountain_topple_peak":"山·倾岳",
    "bomb_mountain_break_formation":"山·断阵",
    "bomb_mountain_hundred_refinements":"山·百炼成峰",
    "bomb_mountain_myriad_cliff_armor":"山·万仞甲",
    "bomb_mountain_true_aura_reflection":"山·真罡返照",
    "bomb_mountain_reflection_return":"山·震返",
    "bomb_mountain_shattered_wall":"山·碎壁震心",
    "bomb_mountain_heaven_gate":"山·天门",
    "bomb_mountain_challenge_death":"山·天关索命",
}

func _initialize() -> void:
    if not _require_test_mode():
        return
    var repository = _repository()
    _assert_resource_contract(repository, MOUNTAIN_TECHNIQUES)
    _test_formal_pool_contract(repository)
    _test_every_technique_executes()
    _test_frozen_contribution_and_structure_queries()
    _test_reflection_source_timeline_and_true_damage()
    _test_block_contract()
    _test_synchronized_block_consumes_only_on_flush()
    _test_challenge_contract()
    _test_temporary_reshape_and_gray_rampart()
    _test_collect_stone_returns_at_action_end()
    _test_cooperation_source_binding_waits_for_next_action()
    _test_same_qi_atomic_effects()
    _test_named_structure_boundaries(repository)
    _test_response_snapshot_restore_and_cleanup()
    _test_existing_reflection_uses_source_op(repository)
    _finish("MOUNTAIN TECHNIQUE TEST")

func _test_formal_pool_contract(repository) -> void:
    _assert_equal(repository.techniques.size(), 228, "正式资源总数为228")
    var expected := {"high":60, "pair":54, "three":35, "straight":37, "bomb":40}
    var actual := {"high":0, "pair":0, "three":0, "straight":0, "bomb":0}
    for technique in repository.techniques.values():
        if not bool(technique.get("built_in", false)):
            var pool := str(technique.get("pool", ""))
            if actual.has(pool):
                actual[pool] = int(actual[pool]) + 1
    _assert_equal(actual, expected, "五个普通正式池数量准确")
    var raw = JSON.parse_string(FileAccess.get_file_as_string("res://data/techniques.json"))
    for technique_id in MOUNTAIN_TECHNIQUES:
        _assert_equal(raw.get("integration_statuses", {}).get(technique_id, ""), "formal_complete", "%s正式完成" % technique_id)
        _assert_true(raw.get("resource_paths", []).has("res://data/techniques/%s.tres" % technique_id), "%s独立资源已登记" % technique_id)

func _test_every_technique_executes() -> void:
    for technique_id in MOUNTAIN_TECHNIQUES:
        var engine = _engine(5100 + assertions)
        var result := _execute_with(engine, technique_id, 20, {
            "played_cards": [],
            "contributing_cards": [],
            "extra_cards": [],
            "card_contribution": 8,
            "common_attributes": [],
            "contributing_common_attributes": [],
            "facts_by_id": {},
            "action_same_qi_gain": 0,
            "action_same_qi_trigger_count": 0,
            "base_attribute_count": 0,
        })
        _assert_true(result.get("success", false) or result.get("pending_choice", false), "%s至少一条成功执行路径" % technique_id)

func _test_frozen_contribution_and_structure_queries() -> void:
    var engine = _engine(5201)
    var high = _card("A", "mountain")
    var extra = _card("8", "mountain")
    engine.status_system.apply_card_anomaly(extra, "buff", "qi_heat", {}, "测试", 4)
    var snapshot := _snapshot([high, extra], [high], [extra], 12)
    var result := _execute_with(engine, "high_mountain_array_stones", 20, snapshot)
    _assert_true(result.get("success", false), "列石成功读取额外真气")
    _assert_equal(engine.player.defense, 26, "列石按额外牌当前有效值12的一半加防")
    engine = _engine(5202)
    result = _execute_with(engine, "high_mountain_lone_peak", 20, _snapshot([high], [high], [], 12))
    _assert_equal(engine.player.defense, 32, "独峰额外防御读取冻结C而非P")
    engine = _engine(5203)
    var fire = _card("8", "fire")
    snapshot = _snapshot([high, fire], [high, fire], [], 16)
    snapshot["contributing_common_attributes"] = []
    result = _execute_with(engine, "pair_mountain_crossed_rock", 20, snapshot, "pair")
    _assert_equal(engine.player.defense, 28, "错岩只在组成牌没有共同可视属性时加C/2")
    engine = _engine(5204)
    snapshot["base_attribute_count"] = 2
    result = _execute_with(engine, "straight_mountain_long_wall", 20, snapshot, "straight")
    _assert_equal(engine.player.defense, 20, "长垣不足三种基础属性不追加")
    snapshot["facts_by_id"][str(high.id)] = {"base_attribute_at_freeze":"mountain"}
    snapshot["facts_by_id"][str(fire.id)] = {"base_attribute_at_freeze":"fire"}
    var wind = _card("7", "wind")
    snapshot["played_cards"].append(wind)
    snapshot["facts_by_id"][str(wind.id)] = {"base_attribute_at_freeze":"wind"}
    engine = _engine(5205)
    result = _execute_with(engine, "straight_mountain_long_wall", 20, snapshot, "straight")
    _assert_equal(engine.player.defense, 28, "长垣三种冻结基础属性时追加C/2")

func _test_reflection_source_timeline_and_true_damage() -> void:
    var engine = _engine(5301)
    var result := _execute_with(engine, "bomb_mountain_true_aura_reflection", 20, _snapshot([], [], [], 8), "four_kind")
    _assert_true(result.get("success", false), "真罡返照建立双来源")
    _assert_equal(engine.player.current_reflection_percent, 50, "真罡首回合50%反震")
    _assert_true(engine.player.reflection_is_true_damage(), "真罡独立启用反震真伤")
    engine.player.tick_round_limited_sources()
    engine.player.add_reflection_source(100, "override", 1, "round_end", "", "覆盖")
    _assert_equal(engine.player.current_reflection_percent, 100, "后来100%来源覆盖真罡50%")
    _assert_true(engine.player.reflection_is_true_damage(), "覆盖比例仍使用独立真伤修改")
    engine.player.tick_round_limited_sources()
    _assert_equal(engine.player.current_reflection_percent, 50, "100%到期后恢复仍有效的50%")
    _assert_true(engine.player.reflection_is_true_damage(), "第二次回合结束后真伤仍有效")
    engine.player.tick_round_limited_sources()
    _assert_equal(engine.player.current_reflection_percent, 0, "第三个完整回合结束后真罡到期")
    _assert_true(not engine.player.reflection_is_true_damage(), "真伤修改与三回合比例一同到期")
    engine = _engine(5302)
    engine.player.defense = 10
    engine.player.add_reflection_source(50, "reflect", 1)
    engine.player.add_reflection_true_damage_source("reflect-true", 1)
    var life_before: int = int(engine.enemy.life)
    engine.effect_ports.deal_damage(engine.enemy, engine.player, 6, "technique", false, "r", "normal", {"direct_attack":true})
    _assert_equal(life_before - engine.enemy.life, 3, "真伤反震按实际防御损失和比例结算")
    _assert_equal(engine.enemy.defense, 0, "反震真伤不经敌方防御")

func _test_block_contract() -> void:
    var engine = _engine(5401)
    engine.player.defense = 5
    engine.effect_ports.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    engine.effect_ports.grant_block_source(engine.player, engine.enemy, "damage_at_most_defense", "条件格挡")
    var failed: Dictionary = engine.effect_ports.deal_damage(engine.enemy, engine.player, 6, "technique", false, "b1", "normal", {"direct_attack":true})
    _assert_true(not failed.get("blocked", false), "A高于当前防御时不格挡")
    _assert_equal(engine.player.block_sources.size(), 1, "条件失败不消费格挡")
    engine.player.defense = 6
    var blocked: Dictionary = engine.effect_ports.deal_damage(engine.enemy, engine.player, 6, "technique", false, "b2", "normal", {"direct_attack":true})
    _assert_true(blocked.get("blocked", false), "A不高于当前防御时成功格挡普通伤害")
    _assert_equal(engine.player.defense, 6, "成功格挡不损失防御")
    _assert_equal(engine.player.life, 99, "成功格挡不再损失生命")
    _assert_equal(engine.player.block_sources.size(), 0, "一个攻击段只消费一个格挡")
    engine.effect_ports.abort_action_resolution()
    engine = _engine(5402)
    engine.effect_ports.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    engine.effect_ports.grant_block_source(engine.player, engine.enemy, "unconditional", "无条件格挡")
    blocked = engine.effect_ports.deal_damage(engine.enemy, engine.player, 9, "technique", true, "b3", "true", {"direct_attack":true})
    _assert_true(blocked.get("blocked", false), "真伤可被通用格挡")
    _assert_equal(engine.player.life, 100, "被格挡真伤不损失生命")
    engine.effect_ports.abort_action_resolution()
    engine = _engine(5403)
    var poison = _card("5")
    engine.player.hand = [poison]
    engine.status_system.apply_card_anomaly(poison, "state", "poison", {}, "测试")
    engine.effect_ports.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    engine.effect_ports.grant_block_source(engine.player, engine.enemy, "unconditional", "非直接伤害保护")
    engine.effect_ports.trigger_poison_card(engine.player, poison, "poison")
    _assert_equal(engine.player.life, 95, "自毒不能被格挡")
    _assert_equal(engine.player.block_sources.size(), 1, "非直接伤害不消费格挡")
    engine.effect_ports.abort_action_resolution()

func _test_synchronized_block_consumes_only_on_flush() -> void:
    var engine = _engine(5501)
    engine.effect_ports.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    engine.effect_ports.grant_block_source(engine.player, engine.enemy, "unconditional", "同步格挡")
    engine.effect_ports.begin_synchronized_damage([{"actor":engine.enemy}])
    var buffered: Dictionary = engine.effect_ports.deal_damage(engine.enemy, engine.player, 7, "technique", false, "sync", "normal", {"direct_attack":true})
    _assert_true(buffered.get("buffered", false), "同步攻击先进入shadow缓冲")
    _assert_equal(engine.player.block_sources.size(), 1, "shadow阶段不消费格挡")
    engine.effect_ports.flush_synchronized_damage()
    _assert_equal(engine.player.block_sources.size(), 0, "真实flush才消费格挡")
    _assert_equal(engine.player.life, 100, "同步flush格挡后不写入生命")
    engine.effect_ports.abort_action_resolution()

func _test_challenge_contract() -> void:
    var engine = _engine(5601)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)],"action_tokens":[]})
    var context = _context(engine, "challenge", 10, _snapshot([], [], [], 10), "high_card")
    var registered: Dictionary = engine.effect_ports.register_challenge(context, 10, [
        {"op":"defense","amount":{"kind":"capture_field_first","capture":"challenge_difference","field":"amount"}}
    ], "测试邀战")
    _assert_true(registered.get("success", false), "邀战绑定当前敌方行动窗口")
    engine.effect_ports.deal_damage(engine.enemy, engine.player, 3, "technique", true, "challenge-hit", "true", {"direct_attack":true})
    _assert_equal(int(engine.player.challenge_records[0].get("current", 0)), 3, "邀战累计实际生命损失")
    var finished: Dictionary = engine.action_resolver.finish_action_resolution()
    _assert_true(finished.get("success", false), "邀战行动窗口完成")
    _assert_equal(engine.player.defense, 7, "邀战按Q-X差额结算效果")
    _assert_equal(engine.player.challenge_records.size(), 0, "邀战来源到期后移除")
    engine = _engine(5603)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.enemy.owner_id)],"action_tokens":[]})
    context = _context(
        engine, "three_mountain_challenge_gate", 20,
        _snapshot([], [], [], 6), "three_kind")
    engine.status_system.register_response(
        "challenge_resolved", "turn_end",
        [{"op":"defense","amount":1}], context,
        {"challenge_met":true,"max_triggers":1})
    var gate: Dictionary = engine.effect_executor.execute_all(
        engine.repository.get_definition("three_mountain_challenge_gate").effects,
        context)
    _assert_true(gate.get("success", false), "擂关通过通用邀战建立双结果分支")
    engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 6, "technique", true,
        "challenge-met", "normal", {"direct_attack":true})
    finished = engine.action_resolver.finish_action_resolution()
    _assert_true(finished.get("success", false), "达标邀战行动窗口完成")
    _assert_equal(engine.player.momentum_value, 6, "擂关达标时获得冻结C点连势")
    _assert_equal(engine.player.defense, 15, "结构化邀战达标事件可被通用响应监听")
    _assert_equal(engine.player.challenge_records.size(), 0, "达标邀战同样在结算后移除")
    engine = _engine(5602)
    engine.action_resolver.begin_action_resolution([engine.player, engine.enemy], {"acting_owner_ids":[str(engine.player.owner_id)],"action_tokens":[]})
    context = _context(engine, "waiting", 10, _snapshot([], [], [], 10), "high_card")
    engine.effect_ports.register_challenge(context, 10, [], "等待邀战")
    _assert_true(engine.player.challenge_records[0].get("waiting_for_action", false), "敌方本次无行动时邀战等待下一合法行动")
    engine.action_resolver.finish_action_resolution()
    _assert_equal(engine.player.challenge_records.size(), 1, "无敌方行动不提前补结算邀战")

func _test_temporary_reshape_and_gray_rampart() -> void:
    var engine = _engine(5701)
    var mountain = _card("5", "mountain")
    engine.player.hand = [mountain]
    var result := _execute_with(engine, "pair_mountain_flawless_wall", 20, _snapshot([], [], [], 8), "pair")
    if result.get("pending_choice", false):
        result = engine.effect_executor.resume(result["_continuation"], str(result["choice_request"]["request_id"]), [str(mountain.id)])
    _assert_true(result.get("success", false), "无漏壁选择恢复成功")
    _assert_equal(str(mountain.temporary_reshapes.get("enhancement", "")), "flawless", "无漏壁写入临时强化槽")
    engine = _engine(5702)
    var legal = _card("5", "fire")
    var rock = _card("7", "fire")
    legal.set_anomaly("mark", "burned_out")
    rock.set_anomaly("mark", "burned_out")
    rock.set_temporary_enhancement("rock_solid")
    engine.player.hand = [legal, rock]
    result = _execute_with(engine, "three_mountain_ash_rampart", 20, _snapshot([], [], [], 8), "three_kind")
    _assert_true(result.get("success", false), "灰垒批量明确弃牌链成功")
    _assert_true(engine.player.discard_pile.has(legal), "灰垒弃掉合法燃尽牌")
    _assert_true(engine.player.hand.has(rock), "灰垒跳过磐石燃尽牌")
    _assert_equal(engine.player.defense, 25, "灰垒只按实际弃掉牌基础值加防")
    _assert_true(legal.has_anomaly("mark", "burned_out"), "燃尽不会因进入弃牌堆移除")
    engine = _engine(5703)
    var reshaped = _card("6", "mountain")
    reshaped.set_temporary_attribute("fire")
    reshaped.set_temporary_enhancement("flawless")
    result = _execute_with(engine, "straight_mountain_reshape_rampart", 20, _snapshot([reshaped], [reshaped], [], 6), "straight")
    _assert_equal(engine.player.defense, 26, "返璞同牌清除两个临时槽只计算一次基础值")
    _assert_equal(str(reshaped.temporary_reshapes.get("attribute", "")), "", "返璞清除临时属性")
    _assert_equal(str(reshaped.temporary_reshapes.get("enhancement", "")), "", "返璞清除临时强化")

func _test_collect_stone_returns_at_action_end() -> void:
    var engine = _engine(5751)
    var extra = _card("6", "mountain")
    var result := _execute_with(
        engine, "pair_mountain_collect_stone", 20,
        _snapshot([extra], [], [extra], 0), "pair")
    _assert_true(result.get("pending_choice", false), "收石锁定额外牌选择")
    result = engine.effect_executor.resume(
        result["_continuation"], str(result["choice_request"]["request_id"]),
        [str(extra.id)])
    _assert_true(result.get("success", false), "收石完成选择并建立行动末响应")
    engine.player.discard_pile = [extra]
    engine.status_system.handle_response_event("action_resolution_end", {
        "action_tokens":["mountain-test-%d" % (assertions - 2)],
    })
    _assert_true(engine.player.hand.has(extra), "收石在当前行动结束时从弃牌堆回手")
    _assert_true(not engine.player.discard_pile.has(extra), "收石回手后不再留在弃牌堆")

func _test_cooperation_source_binding_waits_for_next_action() -> void:
    var engine = _engine(5752)
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy],
        {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    engine.effect_ports.close_current_source_binding_window()
    var block: Dictionary = engine.effect_ports.grant_block_source(
        engine.player, engine.enemy, "unconditional", "协同格挡")
    var context = _context(
        engine, "cooperation-challenge", 8, _snapshot([], [], [], 8),
        "high_card")
    var challenge: Dictionary = engine.effect_ports.register_challenge(
        context, 8, [], "协同邀战")
    _assert_true(block["record"].get("waiting_for_action", false), "协同阶段新格挡不绑定已结算的同步攻击")
    _assert_true(challenge["record"].get("waiting_for_action", false), "协同阶段新邀战不绑定已结算的同步攻击")
    engine.effect_ports.finish_action_resolution()
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy],
        {"acting_owner_ids":[str(engine.enemy.owner_id)]})
    _assert_true(not block["record"].get("waiting_for_action", true), "协同格挡绑定下一次敌方实际行动")
    _assert_true(not challenge["record"].get("waiting_for_action", true), "协同邀战绑定下一次敌方实际行动")
    _assert_equal(
        str(block["record"].get("window_id", "")),
        str(challenge["record"].get("window_id", "")),
        "协同格挡与邀战绑定同一下一行动窗口")
    engine.effect_ports.abort_action_resolution()

func _test_same_qi_atomic_effects() -> void:
    var engine = _engine(5753)
    var snapshot := _snapshot([], [], [], 8)
    var result := _execute_with(
        engine, "straight_mountain_open_mountain", 20, snapshot,
        "straight")
    _assert_true(result.get("success", false), "开山建立同气收口响应")
    engine.status_system.handle_response_event("same_qi_gain_resolved", {
        "actor":engine.player, "holder":engine.player,
        "granted_actions":1, "same_qi_after":0,
    })
    _assert_equal(engine.player.pending_power_fixed_total(), 4, "开山只在同气实际授予额外行动后冻结C/2")
    engine = _engine(5754)
    result = _execute_with(
        engine, "straight_mountain_open_mountain", 20, snapshot,
        "straight")
    engine.status_system.handle_response_event("same_qi_gain_resolved", {
        "actor":engine.player, "holder":engine.player,
        "granted_actions":0, "same_qi_after":3,
    })
    _assert_equal(engine.player.pending_power_fixed_total(), 0, "开山未授予额外行动时不建立功法值修正")
    engine = _engine(5755)
    engine.player.same_qi_value = 3
    result = _execute_with(
        engine, "straight_mountain_seal_pass", 20, snapshot,
        "straight")
    _assert_true(result.get("success", false), "封关建立同气收口响应")
    engine.status_system.handle_response_event("same_qi_gain_resolved", {
        "actor":engine.player, "holder":engine.player,
        "granted_actions":1, "same_qi_after":3,
    })
    _assert_equal(engine.player.same_qi_value, 0, "封关只清空阈值结算后的剩余同气")
    _assert_equal(engine.player.defense, 22, "封关先获得P/2再按剩余3点同气获得12防御")

func _test_named_structure_boundaries(repository) -> void:
    var engine = _engine(5756)
    var snapshot := _snapshot([], [], [], 8)
    snapshot["opposing_has_normal_attack"] = false
    _execute_with(engine, "high_mountain_meet_edge", 20, snapshot)
    _assert_equal(engine.player.current_reflection_percent, 0, "迎锋没有同步普通攻击投影时不建立反震")
    engine = _engine(5757)
    snapshot["opposing_has_normal_attack"] = true
    _execute_with(engine, "high_mountain_meet_edge", 20, snapshot)
    _assert_equal(engine.player.current_reflection_percent, 75, "迎锋读取同步敌方普通攻击投影建立75%反震")
    engine = _engine(5758)
    snapshot = _snapshot([], [], [], 8)
    var life_before: int = int(engine.enemy.life)
    _execute_with(engine, "bomb_mountain_break_formation", 20, snapshot, "four_kind")
    _assert_equal(engine.enemy.life, life_before, "断阵没有同步敌方牌型组时不造成真伤")
    engine = _engine(5759)
    snapshot["opposing_hand_id"] = "high_card"
    life_before = int(engine.enemy.life)
    _execute_with(engine, "bomb_mountain_break_formation", 20, snapshot, "four_kind")
    _assert_equal(life_before - engine.enemy.life, 8, "断阵只在本组强于同步敌方牌型时造成C真伤")
    engine = _engine(5760)
    snapshot = _snapshot([], [], [], 8)
    life_before = int(engine.enemy.life)
    _execute_with(engine, "bomb_mountain_five_peaks", 20, snapshot, "four_kind")
    _assert_equal(engine.enemy.life, life_before, "五岳定极不接受四条")
    engine = _engine(5761)
    life_before = int(engine.enemy.life)
    _execute_with(engine, "bomb_mountain_five_peaks", 20, snapshot, "five_kind")
    _assert_equal(life_before - engine.enemy.life, 8, "五岳定极只接受精确五条")
    var peaks = repository.get_definition("three_mountain_high_card_cooperate")
    _assert_equal(str(peaks.cooperation.get("hand_id", "")), "high_card", "列峰并阵只协同精确高牌")
    _assert_equal(int(peaks.cooperation.get("exact_card_count", 0)), 1, "列峰并阵协同精确一张高牌")
    _assert_true(bool(peaks.cooperation.get("shares_attribute_with_main", false)), "列峰并阵要求与主组三条共享可视属性")
    var split = repository.get_definition("straight_mountain_split_ridge")
    _assert_equal(str(split.cooperation.get("hand_id", "")), "pair", "分岭只协同精确一对")
    _assert_equal(int(split.cooperation.get("exact_card_count", 0)), 2, "分岭协同精确两张真气")

func _test_response_snapshot_restore_and_cleanup() -> void:
    var engine = _engine(5801)
    var context = _context(engine, "snapshot", 20, _snapshot([], [], [], 8), "pair")
    engine.status_system.register_response("damage_blocked", "turn_end", [{"op":"defense","amount":1}], context, {"holder_is_actor":true})
    engine.player.add_reflection_source(50, "snapshot-reflection", 2)
    engine.player.add_block_source("unconditional", "snapshot-block", str(engine.enemy.owner_id))
    var state: Dictionary = engine.player.capture_passive_query_state()
    engine.status_system.response_records.clear()
    engine.player.clear_combat_sources()
    engine.player.replace_passive_query_state(state)
    _assert_equal(engine.status_system.response_records.size(), 1, "战斗快照恢复响应记录")
    _assert_equal(engine.player.current_reflection_percent, 50, "战斗快照恢复反震来源聚合")
    _assert_equal(engine.player.block_sources.size(), 1, "战斗快照恢复格挡来源")
    engine.player.clear_combat_sources()
    _assert_equal(engine.player.public_reflection_sources(), [], "战斗结束清理公开反震来源")
    _assert_equal(engine.player.public_block_sources(), [], "战斗结束清理公开格挡来源")
    _assert_equal(engine.player.public_challenge_records(), [], "战斗结束清理公开邀战记录")

func _test_existing_reflection_uses_source_op(repository) -> void:
    var definition = repository.get_definition("high_mountain_reflection")
    _assert_equal(str(definition.effects[1].get("op", "")), "grant_reflection_source", "既有山·反震迁移到可恢复来源接口")

func _execute_with(engine, technique_id: String, power: int, snapshot: Dictionary, hand_id: String = "high_card", captures: Dictionary = {}) -> Dictionary:
    var definition = engine.repository.get_definition(technique_id)
    var context = _context(
        engine, technique_id, power, snapshot, hand_id, captures)
    if definition != null and not definition.marker_definitions.is_empty():
        engine.sequence_book.configure({hand_id:[technique_id]})
        context.sequence_book = engine.sequence_book
        context.slot_instance_id = str(engine.sequence_book.current_slot(
            hand_id).get("slot_instance_id", ""))
    return engine.effect_executor.execute_all(definition.effects, context)

func _context(engine, technique_id: String, power: int, snapshot: Dictionary, hand_id: String, captures: Dictionary = {}):
    var definition = engine.repository.get_definition(technique_id)
    return EffectContextScript.new().configure({
        "ports":engine.effect_ports,
        "actor":engine.player,
        "target":engine.enemy,
        "power":power,
        "initial_power":power,
        "values":{"technique_value":power,"initial_power":power},
        "hand_result":{"id":hand_id,"contributing":snapshot.get("contributing_cards", [])},
        "played_cards":snapshot.get("played_cards", []),
        "group_snapshot":snapshot,
        "captures":captures,
        "technique_id":technique_id,
        "technique_name":definition.display_name if definition != null else technique_id,
        "technique_pool":definition.pool if definition != null else "",
        "actual_hand_id":hand_id,
        "branch_hand_id":hand_id,
        "action_token":"mountain-test-%d" % assertions,
        "source_kind":"technique",
        "card_identity_policy":engine.player.card_identity_policy,
    })

func _snapshot(played: Array, contributing: Array, extra: Array, contribution: int) -> Dictionary:
    var facts := {}
    var common := ["wind","forest","fire","mountain"]
    var contributing_common := ["wind","forest","fire","mountain"]
    for card in played:
        var attributes := []
        for attribute in ["wind","forest","fire","mountain"]:
            if card.is_attribute(attribute):
                attributes.append(attribute)
        facts[str(card.id)] = {
            "card":card,
            "base_qi_at_freeze":card.current_base_qi_value(),
            "base_attribute_at_freeze":card.current_attribute(),
            "attributes_at_freeze":attributes,
        }
        common = common.filter(func(value): return attributes.has(value))
    for card in contributing:
        var attributes: Array = facts.get(str(card.id), {}).get("attributes_at_freeze", [])
        contributing_common = contributing_common.filter(func(value): return attributes.has(value))
    return {
        "played_cards":played.duplicate(),
        "contributing_cards":contributing.duplicate(),
        "extra_cards":extra.duplicate(),
        "facts_by_id":facts,
        "common_attributes":common,
        "contributing_common_attributes":contributing_common,
        "card_contribution":contribution,
        "action_same_qi_gain":0,
        "action_same_qi_trigger_count":0,
        "has_cooperation_group":false,
        "opposing_hand_id":"",
        "opposing_has_normal_attack":false,
        "on_play_success_cards":[],
    }
