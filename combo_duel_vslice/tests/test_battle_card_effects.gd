extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("battle-card-effects", [
        "_test_zone_moves_queries_and_atomic_operations",
        "_test_temporary_card_void_and_battle_cleanup",
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
