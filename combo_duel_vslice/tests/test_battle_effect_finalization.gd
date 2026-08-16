extends "res://tests/support/technique_test_group.gd"


func _initialize() -> void:
    _run_group("battle-effect-finalization", [
        "_test_poison_trigger_immediate_replay_and_source_metadata",
        "_test_synchronized_poison_completion_waits_for_flush",
        "_test_played_anomalies_resolve_before_card_responses",
        "_test_action_experience_consumable_and_history_resources",
        "_test_source_compatibility_keeps_draw_reason_independent",
    ])


func _test_poison_trigger_immediate_replay_and_source_metadata() -> void:
    var engine = _engine_with_cards([])
    var card = _card("6", "forest")
    engine.player.hand = [card]
    engine.effect_ports.apply_card_anomaly(
        card, "state", "poison", {}, "第五批专项")
    engine.player.grant_poison_damage_modifier(
        2, 0, 1, "battle_end", "final-poison-modifier")
    var poison_events: Array[Dictionary] = []
    var poison_present_when_committed: Array[bool] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "poison_trigger_completed":
                poison_events.append(values.duplicate(true))
                poison_present_when_committed.append(
                    card.has_anomaly("state", "poison")))

    var life_before: int = engine.player.life
    var first: Dictionary = engine.effect_ports.trigger_poison_card(
        engine.player, card, "final-poison-action")
    _assert_true(first.get("success", false),
        "立即毒触发通过最终 Facade 委托成功")
    _assert_equal(first.get("frozen_amount", 0), 6,
        "毒触发冻结当前有效真气值")
    _assert_equal(engine.player.life, life_before - 8,
        "毒伤继续使用生存服务的正式修正后写入")
    _assert_true(not card.has_anomaly("state", "poison"),
        "毒伤成功后才通过真气服务清除毒")
    _assert_equal(poison_events.size(), 1,
        "非同步毒伤成功后立即发送一次完成事件")
    _assert_equal(poison_present_when_committed, [false],
        "完成事件提交时毒状态已经成功清除")
    _assert_equal(poison_events[0].get("source_kind"), "card_status",
        "毒完成事件保留 card_status 来源类型")
    _assert_equal(poison_events[0].get("source_instance_key"),
        "card_status:%s:poison" % str(card.id),
        "毒来源继续绑定具体真气实例")

    engine.effect_ports.apply_card_anomaly(
        card, "state", "poison", {}, "第五批重演")
    engine.player.grant_poison_damage_modifier(
        10, 0, 1, "battle_end", "final-later-modifier")
    life_before = engine.player.life
    var replayed: Dictionary = engine.effect_ports.trigger_poison_card(
        engine.player, card, "final-poison-action", true)
    _assert_equal(engine.player.life, life_before - 8,
        "相同 receipt token 的重演复用冻结毒伤修正")
    _assert_equal(engine.player.poison_damage_modifier_sources.size(), 1,
        "重演不重复消费后来建立的毒伤修正来源")
    _assert_true(bool(poison_events.back().get("replayed", false)),
        "重演完成事件保留 replayed 元数据")
    _assert_true(replayed.get("success", false),
        "毒重演仍返回原有成功结果结构")


func _test_synchronized_poison_completion_waits_for_flush() -> void:
    var engine = _engine_with_cards([])
    var card = _card("9", "forest")
    engine.player.hand = [card]
    engine.effect_ports.apply_card_anomaly(
        card, "state", "poison", {}, "同步毒专项")
    var poison_events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "poison_trigger_completed":
                poison_events.append(values.duplicate(true)))
    engine.effect_ports.begin_synchronized_damage([{"actor": engine.player}])
    var life_before: int = engine.player.life
    var buffered: Dictionary = engine.effect_ports.trigger_poison_card(
        engine.player, card, "final-sync-poison", false, 3)
    _assert_true(buffered.get("buffered", false),
        "同步毒伤先进入既有冻结缓冲")
    _assert_equal(buffered.get("frozen_amount", 0), 3,
        "显式冻结值继续覆盖当前真气值")
    _assert_equal(engine.player.life, life_before,
        "flush 前不正式写入同步毒伤")
    _assert_true(poison_events.is_empty(),
        "同步毒完成事件不会在 flush 前提前发送")
    _assert_true(not card.has_anomaly("state", "poison"),
        "同步请求成功进入缓冲后保持既有清毒时点")

    var resolutions: Array = engine.effect_ports.flush_synchronized_damage()
    _assert_equal(resolutions.size(), 1,
        "同步毒伤继续由唯一生存流水线 flush 一次")
    _assert_equal(engine.player.life, life_before - 3,
        "flush 后按冻结值正式写入生命损失")
    _assert_equal(poison_events.size(), 1,
        "同步真实写入后发送一次毒完成事件")
    _assert_equal(poison_events[0].get("actual_life_loss", 0), 3,
        "同步毒完成事件携带实际生命损失")


func _test_played_anomalies_resolve_before_card_responses() -> void:
    var engine = _engine_with_cards([])
    var card = _card("5", "wind")
    engine.player.hand = [card]
    engine.effect_ports.apply_card_anomaly(
        card, "state", "poison", {}, "打出后顺序专项")
    var poison_seen_by_listener: Array[bool] = []
    var listener: Callable = func(values: Dictionary) -> Dictionary:
        if str(values.get("source_trigger", "")) == "card_played":
            poison_seen_by_listener.append(
                values.get("card").has_anomaly("state", "poison"))
            return {"success": true, "applied": true}
        return {"success": true, "applied": false}
    _assert_true(engine.effect_ports.register_direct_card_trigger_listener(
        "final-played-order", listener),
        "打出响应监听继续通过 BattleResponseEffectService 窄入口注册")

    var life_before: int = engine.player.life
    var results: Array = engine.effect_ports.resolve_played_card_anomalies(
        engine.player, [card], {"action_token": "final-played-action"})
    _assert_true(not results.is_empty(),
        "打出后的真气异状仍先通过 StatusSystem 结算")
    _assert_equal(engine.player.life, life_before - 5,
        "打出毒异状继续复用唯一毒触发事务")
    _assert_equal(poison_seen_by_listener, [false],
        "真气打出响应只在异状结算和清毒之后收到通知")
    _assert_equal(engine.effect_ports.successful_on_play_ids(
        "final-played-action"), [str(card.id)],
        "成功打出记录仍由 CardReshapeBattleRuntime 保存")
    _assert_true(engine.effect_ports.unregister_direct_card_trigger_listener(
        "final-played-order"),
        "打出响应监听可经同一 Facade 注销")


func _test_action_experience_consumable_and_history_resources() -> void:
    var engine = _engine_with_cards([])
    engine.actions_available = 0
    var hand_count_before: int = engine.player.hand.size()
    var gained_actions: int = engine.effect_ports.gain_extra_actions(
        engine.player, 2, "第五批行动来源", "combo", "final-extra-action")
    _assert_equal(gained_actions, 2,
        "额外行动按 BattleFlowCoordinator 实际写入量返回")
    _assert_equal(engine.actions_available, 2,
        "额外行动写入正式行动资源")
    _assert_equal(engine.player.hand.size(), hand_count_before,
        "普通额外行动不会自动补牌")
    var next_source: Dictionary = engine.battle_flow.next_action_source(
        engine.player)
    _assert_equal(next_source.get("category"), "combo",
        "额外行动来源类别保持独立")
    _assert_equal(next_source.get("action_token"), "final-extra-action",
        "额外行动保留 action_token")
    var action_history: Dictionary = engine.trigger_queue.history.back()
    _assert_equal(action_history.get("source"), "第五批行动来源",
        "实际获得数量写入统一历史并保留来源")
    _assert_true(str(action_history.get("detail", "")).contains("+2"),
        "额外行动历史记录实际获得数量")

    engine.player.experience = 7
    _assert_equal(engine.effect_ports.gain_battle_experience(
        engine.player, -4), 0,
        "战斗历练继续拒绝负数收益")
    _assert_equal(engine.effect_ports.gain_battle_experience(
        engine.player, 5), 5,
        "战斗历练返回实际增加量")
    _assert_equal(engine.player.experience, 12,
        "战斗历练只写入当前 BattleSide 临时收益")

    var rng_state_before: int = engine.rng.state
    var candidates: Array[String] = engine.effect_ports.consumable_ids_by_kind(
        "pill")
    _assert_true(candidates.size() >= engine.player.consumable_limit,
        "消耗品候选来自已装配统一内容目录")
    _assert_equal(engine.rng.state, rng_state_before,
        "候选查询不推进战斗统一 RNG")
    for index in range(engine.player.consumable_limit):
        _assert_true(engine.effect_ports.grant_battle_consumable(
            engine.player, candidates[index]),
            "空余共享栏位允许发放战斗消耗品")
    _assert_true(not engine.effect_ports.can_grant_battle_consumable(
        engine.player),
        "共享消耗品栏满后公开能力查询返回 false")
    _assert_true(not engine.effect_ports.grant_battle_consumable(
        engine.player, candidates[engine.player.consumable_limit]),
        "没有空余栏位时保持发放失败")

    engine.effect_ports.add_history(
        "final_probe", "第五批历史探针", "结构化来源", "成功", "窄写入口")
    var history: Dictionary = engine.trigger_queue.history.back()
    _assert_equal(history.get("timing"), "final_probe",
        "通用历史兼容入口仍写入统一 VisibleTriggerQueue")
    _assert_equal(history.get("source"), "结构化来源",
        "通用历史不成为规则事实源但完整保留来源")


func _test_source_compatibility_keeps_draw_reason_independent() -> void:
    var engine = _engine_with_cards([])
    var item_card = _card("3", "fire")
    var technique_card = _card("4", "fire")
    engine.player.draw_pile = [technique_card, item_card]
    var item_draw: Array = engine.effect_ports.draw(engine.player, 1, {
        "source_kind": "item",
        "source_id": "final-item",
        "source_name": "第五批物品来源",
        "source_instance_key": "item:final-item",
        "trigger_mode": "direct",
        "draw_reason": "technique_named_reason",
    })
    _assert_equal(item_draw, [item_card],
        "结构化来源抽牌保持牌堆顶语义")
    _assert_equal(engine.effect_ports.technique_draw_count(engine.player), 0,
        "draw_reason 不会反推 item 来源为功法抽牌")

    var technique_draw: Array = engine.effect_ports.draw(
        engine.player, 1, "technique")
    _assert_equal(technique_draw, [technique_card],
        "旧字符串来源兼容值仍立即转换并完成抽牌")
    _assert_equal(engine.effect_ports.technique_draw_count(engine.player), 1,
        "旧 technique 来源兼容入口保持既有统计语义")
