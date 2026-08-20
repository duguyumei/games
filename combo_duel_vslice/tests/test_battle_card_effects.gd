extends "res://tests/support/technique_test_group.gd"

const RunDeckScript = preload("res://core/run_deck.gd")

const SOLIDIFY_INNER_SKILL_ID := "solidify_hand_at_battle_end"
const NURTURE_ITEM_ID := "deck_growth_and_reshape_vitality"


func _initialize() -> void:
    _run_group("battle-card-effects", [
        "_test_zone_moves_queries_and_atomic_operations",
        "_test_temporary_card_void_and_battle_cleanup",
        "_test_shared_template_generation_and_victory_solidification",
        "_test_defeat_does_not_solidify_temporary_cards",
        "_test_shared_template_generation_failure_rolls_back",
        "_test_anomaly_and_temporary_reshape_facade",
        "_test_played_anomaly_bridge_keeps_poison_pipeline",
    ])


func _test_zone_moves_queries_and_atomic_operations() -> void:
    var engine = _engine_with_cards([])
    var bottom = _card("3", "wind")
    var top = _card("4", "forest")
    engine.player.draw_pile = [bottom, top]

    var located: Dictionary = engine.effect_ports.locate_active_card(str(top.id))
    _assert_true(located.get("success", false), "Facade 可定位当前战斗真气实例")
    _assert_equal(located.get("zone"), "draw_pile", "定位结果保留牌区")
    _assert_equal(engine.effect_ports.side_holding_card(top, "draw_pile"),
        engine.player, "Facade 可定位持牌方")

    var snapshot: Array = engine.effect_ports.zone_cards(
        engine.player, "draw_pile")
    snapshot.clear()
    _assert_equal(engine.player.draw_pile.size(), 2, "牌区查询只返回只读副本")

    var drawn: Array = engine.effect_ports.draw(engine.player, 1, {
        "source_kind": "item",
        "source_id": "card-test-item",
        "source_name": "专项物品",
        "source_instance_key": "item:card-test-item",
        "trigger_mode": "direct",
        "draw_reason": "card_service_test",
    })
    _assert_equal(drawn, [top], "抽牌仍从牌堆顶部取牌")
    _assert_equal(engine.status_system.technique_draw_count(engine.player), 0,
        "物品抽牌不计入功法抽牌")

    var moved_bottom: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "draw_pile", top,
        "effect", "bottom", "rule")
    _assert_true(moved_bottom.get("success", false), "同侧牌区移动成功")
    _assert_equal(engine.player.draw_pile[0], top, "底部放置仍由牌区服务完成")

    var context = EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
    })
    var queried: Dictionary = engine.effect_ports.query_effect_targets(
        context, {
            "side": "actor",
            "zone": "draw_pile",
            "order": "top",
            "limit": 1,
        }, engine.rng)
    _assert_true(queried.get("success", false), "目标查询通过 Facade 成功")
    _assert_equal(queried.get("cards"), [bottom], "目标查询保持牌堆顶语义")

    var protected = _card("9", "mountain")
    engine.effect_ports.apply_temporary_enhancement(protected, "rock_solid")
    engine.player.hand = [protected]
    var discard_permission: Dictionary = engine.effect_ports.can_explicit_discard(
        engine.player, protected)
    _assert_true(not discard_permission.get("allowed", true),
        "明确弃牌查询经过统一权限服务")
    var protected_move: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", protected,
        "explicit_discard", "top", "rule")
    _assert_true(not protected_move.get("success", true),
        "牌区移动复用同一明确弃牌否决")

    var normal_discard = _card("5", "fire")
    var void_discard = _card("6", "mountain")
    engine.player.hand = [normal_discard, void_discard]
    engine.effect_ports.apply_card_anomaly(
        void_discard, "mark", "void", {}, "专项测试")
    var synchronized: Dictionary = engine.effect_ports.move_cards_synchronously([
        {
            "side": engine.player,
            "source_zone": "hand",
            "destination_zone": "discard_pile",
            "card": normal_discard,
            "reason": "explicit_discard",
        },
        {
            "side": engine.player,
            "source_zone": "hand",
            "destination_zone": "discard_pile",
            "card": void_discard,
            "reason": "explicit_discard",
        },
    ], "rule")
    _assert_true(synchronized.get("success", false), "同步移动批次提交成功")
    _assert_equal(synchronized.get("cards", []).size(), 2,
        "同步移动冻结并提交完整合法目标集")
    _assert_true(engine.player.discard_pile.has(normal_discard),
        "普通明确弃牌进入弃牌堆")
    _assert_true(engine.player.temporarily_removed_cards.has(void_discard),
        "虚无明确弃牌改为消散")

    var actor_card = _card("7", "wind")
    var target_card = _card("8", "fire")
    engine.player.hand = [actor_card]
    engine.enemy.draw_pile = [target_card]
    var exchange: Dictionary = engine.effect_ports.atomic_exchange_cards(
        engine.player, "hand", actor_card,
        engine.enemy, "draw_pile", target_card,
        "rule")
    _assert_true(exchange.get("success", false), "跨侧原子交换成功")
    _assert_equal(engine.player.hand, [target_card], "原子交换后我方获得冻结目标")
    _assert_equal(engine.enemy.hand, [actor_card], "原子交换后敌方获得冻结目标")
    _assert_equal(str(target_card.original_owner_id), str(engine.enemy.owner_id),
        "交换所得真气保留原持有者")


func _test_temporary_card_void_and_battle_cleanup() -> void:
    var engine = _engine_with_cards([])
    var source = _card("2", "forest")
    engine.player.hand = [source]
    var generated = engine.effect_ports.generate_temporary_normal_card(
        engine.player, source, {
            "rank_mode": "same_current",
            "attribute_mode": "same_base",
        })
    _assert_true(generated != null, "战斗临时真气生成成功")
    _assert_true(generated.temporary_card, "生成实例标记为战斗临时真气")
    _assert_true(generated.has_anomaly("mark", "void"),
        "战斗临时真气默认带虚无")
    _assert_true(str(generated.id) != str(source.id), "生成实例 ID 不与现有牌冲突")
    _assert_true(engine.effect_ports.locate_active_card(
        str(generated.id)).get("success", false), "生成实例进入正式牌区索引")

    var dispersed: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", generated,
        "explicit_discard", "top", "rule")
    _assert_true(dispersed.get("dispersed", false), "虚无临时真气明确弃牌后消散")
    _assert_true(not engine.player.discard_pile.has(generated),
        "虚无消散不混入普通弃牌堆")
    _assert_true(engine.player.temporarily_removed_cards.has(generated),
        "虚无消散进入战斗临时移除区")

    var purified = engine.effect_ports.generate_temporary_normal_card(
        engine.player, source, {"add_void": false})
    _assert_true(purified != null and purified.temporary_card,
        "明确豁免虚无仍生成战斗临时实例")
    _assert_true(not purified.has_anomaly("mark", "void"),
        "明确豁免不会写入虚无")
    var discarded: Dictionary = engine.effect_ports.move_card(
        engine.player, "hand", engine.player, "discard_pile", purified,
        "explicit_discard", "top", "rule")
    _assert_true(discarded.get("success", false), "净化后临时牌按普通明确弃牌入堆")
    _assert_true(engine.player.discard_pile.has(purified),
        "无虚无临时牌暂存于弃牌堆")

    var ended: Dictionary = engine.timing_system.emit_timing("battle_end", {
        "actors": [engine.player, engine.enemy],
        "winner": engine.player,
        "round_number": 1,
    })
    _assert_true(ended.get("success", false), "战斗结束清理时点成功")
    _assert_true(engine.effect_ports.locate_active_card(
        str(purified.id)).get("success", false) == false,
        "移除虚无的战斗临时牌仍在战斗结束时清除")
    _assert_true(not engine.player.permanently_removed_card_ids.has(str(purified.id)),
        "战斗临时牌清除不写入永久牌组移除记录")


func _test_shared_template_generation_and_victory_solidification() -> void:
    var engine = _engine_with_cards([])
    _assert_true(engine.player.configure_inner_skills([
        SOLIDIFY_INNER_SKILL_ID]).get("success", false),
        "化虚为实通过正式内功来源装配")
    _assert_true(engine.player.configure_items([NURTURE_ITEM_ID]).get(
        "success", false), "纳气养命通过正式物品来源装配")
    engine.battle_passive_timing_bridge.close_battle()
    _assert_true(engine.battle_passive_timing_bridge.assemble([
        engine.player, engine.enemy]).get("success", false),
        "新增内功后重新建立生命周期绑定")

    var started: Dictionary = engine.timing_system.emit_timing("battle_start", {
        "round_number": 0,
        "actors": [engine.player, engine.enemy],
    })
    _assert_true(started.get("success", false),
        "化虚为实在起始手牌形成前完成生成")
    var generated: Array = engine.player.draw_pile.duplicate()
    _assert_equal(generated.size(), 3, "开战生成三张临时真气")
    _assert_equal(generated.map(func(card): return str(card.attribute)).duplicate(),
        [str(generated[0].attribute), str(generated[0].attribute),
            str(generated[0].attribute)],
        "三张临时真气共享同一随机基础属性")
    _assert_equal(generated.map(func(card): return str(card.rank_name)).duplicate(),
        [str(generated[0].rank_name), str(generated[0].rank_name),
            str(generated[0].rank_name)],
        "三张临时真气共享同一随机基础牌阶")
    _assert_equal(generated.map(func(card): return str(card.id)).duplicate() \
        .reduce(func(unique: Array, card_id: String):
            if not unique.has(card_id):
                unique.append(card_id)
            return unique, []).size(), 3,
        "三张临时真气仍是三个独立实例")
    _assert_true(generated.all(func(card):
        return bool(card.temporary_card) \
            and card.has_anomaly("mark", "void") \
            and str(card.reshape_origin.get("id", "")) == "awakening" \
            and str(card.reshape_origin.get(
                "payload", {}).get("attribute", "")) == str(card.attribute) \
            and engine.content_catalog.has_id(
                "card", str(card.definition_id))),
        "三张生成牌均带临时、虚无和对应属性的觉醒，且基础身份有效")

    var kept = generated[0]
    _assert_true(engine.effect_ports.move_card(
        engine.player, "draw_pile", engine.player, "hand", kept,
        "effect", "top", "rule").get("success", false),
        "将一张生成牌保留到胜利手牌")
    var other_temporary = engine.effect_ports.generate_temporary_normal_card(
        engine.player, "forest", {
            "destination": "hand",
            "add_void": false,
            "source_kind": "rule",
            "source_id": "solidify-other-temporary",
            "source_name": "其他临时真气",
            "source_instance_key": "rule:solidify-other-temporary",
        })
    _assert_true(other_temporary != null,
        "化虚为实固化范围可包含其他来源的临时真气")
    engine.effect_ports.apply_card_anomaly(
        kept, "state", "poison", {}, "固化清理专项")
    engine.effect_ports.apply_temporary_attribute(kept, "mountain")
    kept.temporary_blazing_layers["solidify-probe"] = 2
    var permanent_add_facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "run_qi_permanently_added":
                permanent_add_facts.append(values.duplicate(true)))

    var ended: Dictionary = engine.timing_system.emit_timing("battle_end", {
        "round_number": 1,
        "actors": [engine.player, engine.enemy],
        "winner": engine.player,
        "battle_state": "player_victory",
    })
    _assert_true(ended.get("success", false),
        "胜利固化与后续战斗状态清理在同一生命周期完成")
    for card in [kept, other_temporary]:
        _assert_true(not bool(card.temporary_card),
            "胜利时手牌临时真气转为永久真气")
        _assert_equal(card.anomaly_snapshot(), {
            "buffs": {}, "debuffs": {}, "state": {}, "marks": {}},
            "固化牌不保留战斗异状")
        _assert_equal(card.temporary_reshapes, {
            "enhancement": "", "attribute": "", "rank": {}},
            "固化牌不保留临时重塑")
        _assert_true(card.temporary_blazing_layers.is_empty(),
            "固化牌不保留来源级临时炽气")
    _assert_equal(str(kept.reshape_origin.get("id", "")), "awakening",
        "固化保留生成牌已有的永久觉醒重塑")
    _assert_true(not engine.effect_ports.locate_active_card(
        str(generated[1].id)).get("success", false),
        "未留在手牌的临时真气仍按战斗结束规则清除")
    _assert_equal(permanent_add_facts.size(), 2,
        "每张实际固化牌各提交一份永久新增真气事实")
    _assert_true(permanent_add_facts.all(func(fact):
        return str(fact.get("scope", "")) == "battle" \
            and str(fact.get("persistence", "")) == "permanent" \
            and not bool(fact.get(
                "persistent_card_snapshot", {}).get("temporary_card", true))),
        "固化事实公开战斗永久语义和清理后的持久快照")
    var nurture_entries: Array = engine.player.source_marker_store.entries({
        "source_kind": "item",
        "content_id": NURTURE_ITEM_ID,
        "marker_id": "permanent_qi_growth",
        "scope": "run",
    })
    _assert_equal(nurture_entries.map(func(entry):
        return int(entry.get("value", 0))).reduce(
            func(total: int, value: int): return total + value, 0), 2,
        "纳气养命对两张固化牌累计两层最大生命标识")
    _assert_equal(engine.player.max_life,
        engine.player.base_max_life + 2,
        "战斗固化实时增加纳气养命的最大生命贡献")

    var run_deck = RunDeckScript.new(
        engine.content_catalog,
        engine.content_catalog.definition("base_deck"))
    var synchronized: Dictionary = run_deck.sync_from_battle_cards(
        engine.player.all_cards_for_run_sync())
    _assert_equal(synchronized.get("added"), 2,
        "现有 RunDeck 同步自然接入两张固化牌")
    _assert_true(run_deck.has_card(str(kept.id)) \
        and run_deck.has_card(str(other_temporary.id)),
        "固化实例以原稳定 ID 进入本局牌组")


func _test_defeat_does_not_solidify_temporary_cards() -> void:
    var engine = _engine_with_cards([])
    _assert_true(engine.player.configure_inner_skills([
        SOLIDIFY_INNER_SKILL_ID]).get("success", false),
        "战败边界装配化虚为实")
    engine.battle_passive_timing_bridge.close_battle()
    _assert_true(engine.battle_passive_timing_bridge.assemble([
        engine.player, engine.enemy]).get("success", false),
        "战败边界重新建立生命周期绑定")
    var permanent_add_facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "run_qi_permanently_added":
                permanent_add_facts.append(values.duplicate(true)))
    _assert_true(engine.timing_system.emit_timing("battle_start", {
        "round_number": 0,
        "actors": [engine.player, engine.enemy],
    }).get("success", false), "战败边界先生成三张临时真气")
    var generated: Array = engine.player.draw_pile.duplicate()
    _assert_equal(generated.size(), 3, "战败前存在三张生成牌")
    _assert_true(engine.effect_ports.move_card(
        engine.player, "draw_pile", engine.player, "hand", generated[0],
        "effect", "top", "rule").get("success", false),
        "战败前把一张临时真气留在手牌")

    _assert_true(engine.timing_system.emit_timing("battle_end", {
        "round_number": 1,
        "actors": [engine.player, engine.enemy],
        "winner": engine.enemy,
        "battle_state": "enemy_victory",
    }).get("success", false), "战败仍完成统一战斗结束清理")
    _assert_equal(permanent_add_facts.size(), 0,
        "战败不提交永久新增真气事实")
    _assert_true(engine.player.permanent_qi_mutation_receipts.is_empty(),
        "战败不留下固化回执")
    _assert_true(generated.all(func(card):
        return not engine.effect_ports.locate_active_card(
            str(card.id)).get("success", false)),
        "战败后手牌和牌库中的临时真气全部按普通规则移除")


func _test_shared_template_generation_failure_rolls_back() -> void:
    var engine = _engine_with_cards([])
    var rng_state_before := int(engine.rng.state)
    var event_state_before: Dictionary = engine.battle_passive_event_service \
        .capture_transaction_state()
    var failed: Dictionary = engine.effect_ports \
        .generate_shared_template_temporary_normal_cards(
            engine.player, 3, {
                "destination": "invalid_zone",
                "add_void": true,
                "origin_id": "awakening",
                "source_kind": "inner_skill",
                "source_id": SOLIDIFY_INNER_SKILL_ID,
                "source_name": "化虚为实",
                "source_instance_key": "inner_skill:solidify-rollback",
            })
    _assert_true(not failed.get("success", true) \
        and failed.get("rolled_back", false),
        "批量中任一步失败时整批返回回滚结果")
    _assert_true(engine.player.hand.is_empty() \
        and engine.player.draw_pile.is_empty() \
        and engine.player.discard_pile.is_empty(),
        "失败批次不泄漏任何临时真气到牌区")
    _assert_equal(engine.rng.state, rng_state_before,
        "失败批次恢复战斗随机源")
    _assert_equal(engine.battle_passive_event_service.capture_transaction_state(),
        event_state_before, "失败批次恢复 committed 事件和回执状态")


func _test_anomaly_and_temporary_reshape_facade() -> void:
    var engine = _engine_with_cards([])
    var source = _card("4", "forest")
    var target = _card("5", "fire")

    var permission: Dictionary = engine.effect_ports.can_apply_card_anomaly(
        source, "state", "poison")
    _assert_true(permission.get("allowed", false), "异状施加继续经过合法性查询")
    var applied: Dictionary = engine.effect_ports.apply_card_anomaly(
        source, "state", "poison", {}, "专项测试")
    _assert_true(applied.get("success", false), "异状通过 Facade 正式写入")
    var transferred: Dictionary = engine.effect_ports.transfer_card_anomaly(
        source, target, "state", "poison", "专项测试")
    _assert_true(transferred.get("success", false), "异状转移通过统一状态生命周期")
    _assert_true(not source.has_anomaly("state", "poison"), "异状转移移除来源状态")
    _assert_true(target.has_anomaly("state", "poison"), "异状转移写入目标状态")
    var removed: Dictionary = engine.effect_ports.remove_card_anomaly(
        target, "state", "poison", "专项测试")
    _assert_true(removed.get("changed", false), "异状移除通过 Facade 提交")

    engine.effect_ports.apply_card_anomaly(
        source, "buff", "growth", {}, "专项测试", 2)
    var layered: Dictionary = engine.effect_ports.set_card_anomaly_layers(
        source, "buff", "growth", 5, "专项测试")
    _assert_true(layered.get("success", false), "异状层数设置成功")
    _assert_equal(source.anomaly_layers("buff", "growth"), 5,
        "异状层数保持正式状态规则")

    var rank: Dictionary = engine.effect_ports.apply_temporary_rank(
        source, "9", 9, 9)
    _assert_true(rank.get("success", false), "临时牌阶写入独立槽位")
    _assert_equal(source.current_rank_name(), "9", "临时牌阶参与当前身份读取")
    _assert_equal(engine.effect_ports.current_effective_qi(engine.player, source), 9,
        "有效真气值读取临时牌阶")
    _assert_equal(source.rank_name, "4", "临时牌阶不修改基础身份")

    _assert_true(engine.effect_ports.apply_temporary_attribute(
        source, "mountain").get("success", false), "临时属性写入独立槽位")
    _assert_true(engine.effect_ports.apply_temporary_enhancement(
        source, "flawless").get("success", false), "临时强化写入独立槽位")
    _assert_equal(source.attribute, "forest", "临时属性不修改基础属性")
    var cleared_rank: Dictionary = engine.effect_ports.clear_temporary_reshape(
        source, "rank")
    _assert_true(cleared_rank.get("success", false), "可按子槽清理临时重塑")
    _assert_equal(source.current_rank_name(), "4", "清理牌阶槽后恢复基础牌阶")
    var cleared_all: Dictionary = engine.effect_ports.clear_all_temporary_reshapes(source)
    _assert_true(cleared_all.get("success", false), "可统一清理剩余临时重塑")
    _assert_equal(source.temporary_reshapes, {
        "enhancement": "", "attribute": "", "rank": {},
    }, "所有临时重塑槽均已清空")


func _test_played_anomaly_bridge_keeps_poison_pipeline() -> void:
    var engine = _engine_with_cards([])
    var poisoned = _card("6", "wind")
    engine.player.hand = [poisoned]
    engine.effect_ports.apply_card_anomaly(
        poisoned, "state", "poison", {}, "专项测试")
    var life_before: int = int(engine.player.life)
    var resolutions: Array = engine.effect_ports.resolve_played_card_anomalies(
        engine.player, [poisoned], {
            "action_token": "battle-card-poison",
        })
    _assert_true(not resolutions.is_empty(), "打出异状结算仍由状态生命周期触发")
    _assert_equal(engine.player.life, life_before - 6,
        "毒异状继续调用唯一毒伤结算流水线")
    _assert_true(not poisoned.has_anomaly("state", "poison"),
        "毒伤完成后按原时点清除毒状态")
