extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEventCatalogScript = preload(
    "res://core/battle_event_catalog.gd")
const BattleFinalResultDTOScript = preload(
    "res://core/battle_final_result_dto.gd")
const DeckFactoryScript = preload("res://core/deck_factory.gd")
const GameCompositionRootScript = preload(
    "res://core/game_composition_root.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const QiCardInstanceDataScript = preload(
    "res://core/qi_card_instance_data.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

const ITEM_ID := "deck_growth_and_reshape_vitality"
const INNER_SKILL_ID := "fortune_rank_cycle"
const RESHAPE_ID := "fortune_rank_advance"
const MARKER_ID := "permanent_qi_growth"
const FORTUNE_HOOK := "technique_execution_resolved"


func _initialize() -> void:
    if not _require_test_mode():
        return
    var composition = GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(composition.initialize(),
        "永久真气专项组合根加载正式内容")
    if not composition.initialized or not composition.content_catalog.loaded:
        _finish("RUN CARD MUTATION FACT TEST")
        return
    _test_formal_content_and_registry_contract(composition)
    _test_run_addition_facts(composition)
    _test_practice_purchase_and_consumable_generation(composition)
    _test_run_reshape_noop_and_failure_rollback(composition)
    _test_nurture_item_run_growth_and_save_roundtrip(composition)
    _test_battle_permanent_mutation_port()
    _test_fortune_frozen_results_and_idempotency()
    _test_nurture_item_battle_reshape_bridge()
    _test_battle_victory_defeat_and_restart_boundaries(composition)
    _finish("RUN CARD MUTATION FACT TEST")


func _test_formal_content_and_registry_contract(composition) -> void:
    var catalog = composition.content_catalog
    var inner: Dictionary = catalog.get_by_id(
        "inner_skill", INNER_SKILL_ID)
    var item: Dictionary = catalog.get_by_id("item", ITEM_ID)
    var reshape: Dictionary = catalog.get_by_id("other_reshape", RESHAPE_ID)
    _assert_equal(inner.get("name"), "机缘不空",
        "机缘不空使用正式内功 ID 与名称")
    _assert_equal(inner.get("status"), "formal",
        "机缘不空状态为 formal")
    _assert_equal(inner.get("rarity"), "rare",
        "机缘不空稀有度为 rare")
    _assert_equal(inner.get("forget_value"), 0,
        "机缘不空遗忘值遵循权威正文")
    _assert_equal(item.get("name"), "纳气养命",
        "纳气养命使用正式物品 ID 与名称")
    _assert_equal(item.get("status"), "formal",
        "纳气养命状态为 formal")
    _assert_true(bool(item.get("unique", false)),
        "纳气养命是唯一物品")
    _assert_equal(item.get("price"), 8,
        "纳气养命正式价格为8")
    _assert_equal(item.get("description"),
        "每向本局牌组中永久新增1张真气，最大生命+1。每成功重塑1张我方真气，恢复1点生命。",
        "纳气养命描述严格使用权威正文")
    _assert_equal(reshape.get("name"), "机缘升阶",
        "机缘升阶登记为通用重塑·其他定义")
    _assert_true(composition.run_effect_registry.has_handler(
        "write_source_marker"),
        "Run 来源标识写入由正式 Handler Registry 承载")
    _assert_true(composition.passive_rule_registry.has_handler(
        "run_fact_effects"),
        "Run canonical 事实由来源中立被动 Handler 消费")
    var engine = _engine(510001)
    _assert_true(engine.effect_executor.registry.has_handler(
        "advance_permanent_qi_rank"),
        "战斗永久改牌操作登记进统一 Effect Handler Registry")
    _assert_true(BattleEventCatalogScript.is_committed(
        "qi_reshape_committed"),
        "永久战斗重塑复用 qi_reshape_committed")
    _assert_true(BattleEventCatalogScript.is_committed(FORTUNE_HOOK),
        "机缘消费事务内功法执行汇总事实")
    var implementation_text: String = "\n".join([
        FileAccess.get_file_as_string(
            "res://core/run_effects/run_mutation_service.gd"),
        FileAccess.get_file_as_string(
            "res://core/passives/run_fact_effects_passive_handler.gd"),
        FileAccess.get_file_as_string(
            "res://core/effects/battle_card_effect_service.gd"),
        FileAccess.get_file_as_string(
            "res://core/effects/permanent_qi_mutation_effect_handler.gd"),
        FileAccess.get_file_as_string(
            "res://core/permanent_qi_mutation_service.gd"),
    ])
    _assert_true(not implementation_text.contains(INNER_SKILL_ID)
        and not implementation_text.contains(ITEM_ID),
        "公共实现不按机缘不空或纳气养命 content_id 分支")


func _test_run_addition_facts(composition) -> void:
    var growth = GrowthInventoryScript.new(
        composition.content_catalog, false)
    var metadata: Dictionary = _run_source(
        "run-addition-facts", "node_reward")
    var added: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "add_run_cards",
        "definition_ids": ["wind_2", "forest_3"],
    }], growth, metadata)
    _assert_true(added.get("success", false),
        "add_run_cards 通过 RunMutationService 提交")
    var add_facts: Array = _events(added, "run_qi_permanently_added")
    _assert_equal(add_facts.size(), 2,
        "add_run_cards 按实际新增实例逐张发送 canonical 事实")
    _assert_equal(add_facts.map(func(fact):
        return str(fact.get("definition_id", ""))),
        ["wind_2", "forest_3"],
        "新增事实保持调用方稳定卡牌顺序")
    _assert_true(add_facts.all(func(fact):
        return (
            str(fact.get("transaction_token", ""))
                == "run-addition-facts"
            and str(fact.get("operation_token", ""))
                == "run-addition-facts:operation:0:add_run_cards"
            and str(fact.get("source_kind", "")) == "node_reward"
            and str(fact.get("source_id", "")) == "addition_probe"
            and str(fact.get("holder_id", "")) == "player"
            and fact.get("card_snapshot")
                == fact.get("persistent_card_snapshot")
        )),
        "新增事实公开稳定 token、来源、持有者与完整永久快照")
    _assert_equal(add_facts.map(func(fact):
        return str(fact.get("event_token", ""))),
        add_facts.map(func(fact):
            return "run_qi_permanently_added:%s:%s" % [
                fact.get("operation_token"), fact.get("instance_id")]),
        "逐实例 event token 由事务、操作与实例身份稳定构成")

    var full_instance: Dictionary = growth.run_deck.card_data(
        str(add_facts[0]["instance_id"])).duplicate(true)
    full_instance["instance_id"] = "full-instance-addition-probe"
    full_instance["reshapes"]["others"][RESHAPE_ID] = {
        "fixture": "complete_snapshot",
    }
    var full: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "add_run_card_instances",
        "instances": [full_instance],
    }], growth, _run_source("full-instance-add", "practice"))
    _assert_true(full.get("success", false),
        "完整冻结实例通过统一新增入口提交")
    var full_facts: Array = _events(full, "run_qi_permanently_added")
    _assert_equal(full_facts.size(), 1,
        "完整实例新增仍只发送一份 added 事实")
    _assert_equal(full_facts[0].get("card_snapshot"), full_instance,
        "完整实例事实保留全部持久重塑状态")
    _assert_true(_events(full, "qi_reshape_committed").is_empty(),
        "完整实例新增优先归类为 added 而不重复算 reshape")

    var copied: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "copy_run_card",
        "source_instance_id": str(add_facts[0]["instance_id"]),
        "count": 2,
    }], growth, _run_source("copy-addition", "consumable"))
    _assert_true(copied.get("success", false),
        "永久复制通过 RunMutationService 提交")
    var copy_facts: Array = _events(copied, "run_qi_permanently_added")
    _assert_equal(copy_facts.size(), 2,
        "永久复制两张逐实例发送两份 added 事实")
    _assert_equal(_unique_card_ids(copy_facts).size(), 2,
        "复制事实携带互不重复的稳定实例 ID")
    _assert_true(copy_facts.all(func(fact):
        return str(fact.get("operation_id", "")) == "copy_run_card"),
        "复制事实保留 canonical operation_id")

    var snapshot: Array = growth.run_deck.cards_snapshot()
    _assert_true(composition.run_mutation_service.derive_card_mutation_facts(
        "restore_snapshot", [], snapshot, growth, metadata).is_empty(),
        "存档恢复不属于永久新增事实")
    _assert_true(composition.run_mutation_service.derive_card_mutation_facts(
        "battle_temporary_generation", [], snapshot,
        growth, metadata).is_empty(),
        "战斗临时生成不进入 Run canonical 事实")
    _assert_true(composition.run_mutation_service.derive_card_mutation_facts(
        "add_run_cards", snapshot, snapshot,
        growth, metadata).is_empty(),
        "牌区移动或无牌组变化不会伪造永久新增事实")


func _test_practice_purchase_and_consumable_generation(composition) -> void:
    var catalog = composition.content_catalog
    var purchase_growth = GrowthInventoryScript.new(catalog, false)
    purchase_growth.experience = 20
    var purchase_card: Dictionary = _persistent_card(
        catalog, "fire_6", "practice-card-fact-probe")
    purchase_growth.practice_shop_state = {
        "shop_index": 3,
        "act": 1,
        "normal": [{
            "id": "fire_6",
            "kind": "qi_card",
            "content_kind": "awakened_qi",
            "candidate_provider": "generated_awakened_qi",
            "price": 4,
            "instance_id": "practice-card-fact-probe",
            "offer_instance_id": "practice-offer:card-fact-probe",
            "purchase_key": "practice-offer:card-fact-probe",
            "card_instance": purchase_card,
        }],
        "packs": [],
        "items": [],
        "normal_slot_count": 1,
        "pack_open_sequence": 0,
    }
    var practice = PracticeServiceScript.new(
        catalog, composition.run_mutation_service)
    var purchase: Dictionary = practice.purchase(
        purchase_growth, "normal", 0, true)
    _assert_true(purchase.get("success", false),
        "永久真气商品购买成功")
    _assert_equal(purchase_growth.run_deck.card_data(
        "practice-card-fact-probe"), purchase_card,
        "购买提交冻结完整实例而不重新生成")
    var purchase_facts: Array = _events(
        purchase.get("run_mutation", {}),
        "run_qi_permanently_added")
    _assert_equal(purchase_facts.size(), 1,
        "购买复用 add_run_card_instances canonical 事实")
    _assert_equal(purchase_facts[0].get("operation_id"),
        "add_run_card_instances",
        "购买事实不建立 purchase 专用牌组算法")
    _assert_equal(purchase_facts[0].get("card_snapshot"), purchase_card,
        "购买事实公开购买时冻结的完整卡牌快照")

    var generated_growth = GrowthInventoryScript.new(catalog)
    var granted: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "grant_items", "item_ids": [ITEM_ID],
    }], generated_growth, _run_source(
        "grant-nurture-before-generation", "reward"))
    _assert_true(granted.get("success", false),
        "生成专项先正式获得纳气养命")
    generated_growth.life = 60
    generated_growth.consumable_ids.append("zhenyuan_huasheng")
    var deck_count_before: int = generated_growth.run_deck.card_count()
    var generation: Dictionary = composition.consumable_use_service.use(
        generated_growth,
        0,
        [],
        510002,
        catalog.get_by_id("consumable", "zhenyuan_huasheng"))
    _assert_true(generation.get("success", false),
        "永久随机生成奇珍通过统一消耗品事务成功")
    var generation_facts: Array = _events(
        generation, "run_qi_permanently_added")
    _assert_equal(generation_facts.size(), 3,
        "永久随机生成三张逐实例发送三份 added 事实")
    _assert_equal(generated_growth.run_deck.card_count(),
        deck_count_before + 2,
        "移出一张并生成三张后牌组净增加两张")
    _assert_equal(_unique_card_ids(generation_facts).size(), 3,
        "随机生成事实逐张携带唯一实例 ID")
    _assert_true(generation_facts.all(func(fact):
        return (
            str(fact.get("operation_id", ""))
                == "generate_random_base_cards"
            and str(fact.get("card_snapshot", {}).get(
                "reshapes", {}).get("enhancement", "")) != ""
        )),
        "生成在同一 effect 完成随机强化后才冻结完整 added 快照")
    _assert_equal(_nurture_marker_value(generated_growth), 3,
        "生成三张由同一事实协议令纳气养命 marker 累计3")
    _assert_equal(generated_growth.max_life, 103,
        "生成三张令来源贡献后的最大生命增加3")
    _assert_equal(generated_growth.life, 60,
        "永久新增只提高最大生命而不恢复当前生命")


func _test_run_reshape_noop_and_failure_rollback(composition) -> void:
    var growth = GrowthInventoryScript.new(
        composition.content_catalog, false)
    var setup: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "add_run_cards", "definition_ids": ["wind_4", "fire_7"],
    }], growth, _run_source("reshape-setup", "test_fixture"))
    _assert_true(setup.get("success", false),
        "Run 重塑专项建立两张永久真气")
    var card_ids: Array = _events(
        setup, "run_qi_permanently_added").map(
        func(fact): return str(fact.get("card_instance_id", "")))
    var reshape: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "apply_run_card_reshape",
        "instance_ids": [card_ids[0], card_ids[1]],
        "category": "enhancement",
        "reshape_id": "qi_boost",
    }], growth, _run_source("reshape-two-cards", "consumable"))
    _assert_true(reshape.get("success", false),
        "永久重塑两张通过 RunMutationService 提交")
    var reshape_facts: Array = _events(reshape, "qi_reshape_committed")
    _assert_equal(reshape_facts.size(), 2,
        "永久重塑按实际变化真气逐张发送")
    _assert_equal(reshape_facts.map(func(fact):
        return str(fact.get("card_instance_id", ""))), card_ids,
        "永久重塑事实保持目标稳定顺序")
    _assert_true(reshape_facts.all(func(fact):
        return (
            str(fact.get("scope", "")) == "run"
            and str(fact.get("persistence", "")) == "permanent"
            and int(fact.get("actual_change_count", 0)) > 0
            and not fact.get("before", {}).is_empty()
            and not fact.get("after", {}).is_empty()
        )),
        "Run 重塑事实公开 scope、persistence、before/after 与实际变化")

    var no_op: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "apply_run_card_reshape",
        "instance_ids": [card_ids[0]],
        "category": "enhancement",
        "reshape_id": "qi_boost",
    }], growth, _run_source("reshape-no-op", "consumable"))
    _assert_true(no_op.get("success", false),
        "设置已有永久强化是成功 no-op")
    _assert_true(_events(no_op, "qi_reshape_committed").is_empty(),
        "没有实际变化时不发送重塑事实")

    var multi_field: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "transform_run_card",
        "instance_id": card_ids[0],
        "definition_id": "mountain_K",
        "preserve_reshapes": true,
    }], growth, _run_source("reshape-multi-field", "event"))
    _assert_true(multi_field.get("success", false),
        "永久基础身份转换通过统一事务")
    var multi_facts: Array = _events(multi_field, "qi_reshape_committed")
    _assert_equal(multi_facts.size(), 1,
        "同牌多个持久字段变化聚合为一份重塑事实")
    _assert_true(multi_facts[0].get("changes", []).size() >= 4,
        "聚合事实仍逐字段公开完整变化摘要")
    _assert_equal(multi_facts[0].get("actual_change_count"),
        multi_facts[0].get("changes", []).size(),
        "actual_change_count 与实际字段差异数量一致")

    _assert_true(composition.run_mutation_service.apply_effects([{
        "op": "grant_items", "item_ids": [ITEM_ID],
    }], growth, _run_source(
        "rollback-item-grant", "reward")).get("success", false),
        "回滚专项正式获得纳气养命")
    var rollback_instance: Dictionary = _persistent_card(
        composition.content_catalog, "forest_8", "rollback-addition-probe")
    var before: Dictionary = growth.capture_mutation_state()
    var failed: Dictionary = composition.run_mutation_service.apply_effects([{
        "op": "add_run_card_instances",
        "instances": [rollback_instance],
    }, {
        "op": "add_run_card_instances",
        "instances": [rollback_instance],
    }], growth, _run_source("rollback-after-fact", "event"))
    _assert_true(not failed.get("success", true),
        "canonical 事实派生后后续重复实例令整批失败")
    _assert_equal(growth.capture_mutation_state(), before,
        "失败丢弃牌组、marker、生命与全部工作副本变化")
    _assert_true(failed.get("committed_events", []).is_empty(),
        "失败结果不泄漏 canonical 或派生 marker 事实")


func _test_nurture_item_run_growth_and_save_roundtrip(composition) -> void:
    var session = composition.create_run_session()
    _assert_true(session.execute({
        "type": "setup_run",
        "seed": 510003,
        "starter_build_id": "standard_52",
    }).success, "纳气养命存档专项建立本局")
    var mutation = composition.run_mutation_service
    _assert_true(mutation.apply_effects([{
        "op": "grant_items", "item_ids": [ITEM_ID],
    }], session.growth, _run_source(
        "nurture-save-grant", "reward")).get("success", false),
        "纳气养命通过正式 Run 事务获得")
    session.growth.life = 90
    var addition: Dictionary = mutation.apply_effects([{
        "op": "add_run_cards", "definition_ids": ["forest_9"],
    }], session.growth, _run_source(
        "nurture-single-add", "node_reward"))
    _assert_true(addition.get("success", false),
        "持有纳气养命后永久新增一张成功")
    _assert_equal(_nurture_marker_value(session.growth), 1,
        "每个实际新增实例使物品自己的 run marker +1")
    _assert_equal(session.growth.max_life, 101,
        "marker 通过 SourceContributedStatService 贡献最大生命")
    _assert_equal(session.growth.base_max_life, 100,
        "来源贡献不反写 base_max_life")
    _assert_equal(session.growth.life, 90,
        "最大生命增加不恢复当前生命")
    var added_id: String = str(_events(
        addition, "run_qi_permanently_added")[0]["card_instance_id"])
    var copies: Dictionary = mutation.apply_effects([{
        "op": "copy_run_card",
        "source_instance_id": added_id,
        "count": 2,
    }], session.growth, _run_source(
        "nurture-copy-two", "consumable"))
    _assert_true(copies.get("success", false),
        "纳气养命永久复制两张成功")
    _assert_equal(_nurture_marker_value(session.growth), 3,
        "永久复制两张逐张累计 marker")
    _assert_equal(session.growth.max_life, 103,
        "三张累计使最大生命增加3")
    _assert_equal(session.growth.life, 90,
        "复制导致的上限增长同样不回血")

    var reshape: Dictionary = mutation.apply_effects([{
        "op": "apply_run_card_reshape",
        "instance_ids": [added_id],
        "category": "enhancement",
        "reshape_id": "qi_boost",
    }], session.growth, _run_source(
        "nurture-run-reshape", "consumable"))
    _assert_true(reshape.get("success", false),
        "纳气养命监听 Run 永久重塑事实")
    _assert_equal(_events(reshape, "qi_reshape_committed").size(), 1,
        "Run 永久重塑只产生一份 canonical 事实")
    _assert_equal(session.growth.life, 91,
        "每张成功永久重塑恢复1点生命")
    var no_op: Dictionary = mutation.apply_effects([{
        "op": "apply_run_card_reshape",
        "instance_ids": [added_id],
        "category": "enhancement",
        "reshape_id": "qi_boost",
    }], session.growth, _run_source(
        "nurture-run-no-op", "consumable"))
    _assert_true(no_op.get("success", false),
        "纳气养命 no-op 重塑仍明确成功")
    _assert_equal(session.growth.life, 91,
        "无实际变化不触发重塑回血")

    var saved = RunSaveDataScript.new().capture(session)
    _assert_true(saved.validate(composition.content_catalog).is_empty(),
        "包含永久牌组与物品 marker 的存档通过校验")
    var restored: Dictionary = saved.restore_session(
        composition.content_catalog,
        Callable(composition, "create_run_session"))
    _assert_true(restored.get("success", false),
        "永久牌组、marker 与生命可以存档恢复")
    if restored.get("success", false):
        var restored_growth = restored["run_session"].growth
        _assert_equal(_nurture_marker_value(restored_growth), 3,
            "存档恢复 marker 状态而不重放三次新增事实")
        _assert_equal(restored_growth.max_life, 103,
            "恢复后统一重算得到同一最大生命")
        _assert_equal(restored_growth.base_max_life, 100,
            "恢复后 base_max_life 仍不受来源贡献反写")
        _assert_equal(restored_growth.life, 91,
            "恢复不重放重塑回血")
        _assert_equal(restored_growth.run_deck.card_data(
            added_id).get("reshapes", {}).get("enhancement"), "qi_boost",
            "存档往返保留永久真气完整重塑状态")


func _test_battle_permanent_mutation_port() -> void:
    var engine = _engine(510004)
    var rank_two = _card("2", "wind")
    var rank_king = _card("K", "forest")
    var rank_ace = _card("A", "fire")
    var temporary = _card("5", "mountain")
    var enemy_card = _card("6", "wind")
    temporary.temporary_card = true
    engine.player.hand = [rank_two, rank_king, rank_ace, temporary]
    engine.enemy.hand = [enemy_card]
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "qi_reshape_committed":
                facts.append(values.duplicate(true)))

    var two_to_three: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(rank_two.id), RESHAPE_ID, {},
            _battle_source("rank-cycle-two", INNER_SKILL_ID))
    _assert_true(two_to_three.get("success", false),
        "战斗永久改牌端口完成2到3")
    _assert_equal([rank_two.rank_name, rank_two.rank_order,
        rank_two.qi_value, rank_two.definition_id],
        ["3", 3, 3, "wind_3"],
        "2到3同步基础牌阶、真气值与 definition_id")
    _assert_true(rank_two.reshape_others.has(RESHAPE_ID),
        "机缘升阶记录为不占本源槽的重塑·其他")
    var replay: Dictionary = engine.effect_ports.advance_permanent_qi_rank(
        engine.player, str(rank_two.id), RESHAPE_ID, {},
        _battle_source("rank-cycle-two", INNER_SKILL_ID))
    _assert_true(replay.get("success", false)
        and replay.get("reused", false),
        "同 root action 与同牌请求复用永久改牌回执")
    _assert_equal(rank_two.rank_name, "3",
        "回响或等待恢复不会重复推进牌阶")

    var king_to_ace: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(rank_king.id), RESHAPE_ID, {},
            _battle_source("rank-cycle-king", INNER_SKILL_ID))
    _assert_true(king_to_ace.get("success", false),
        "战斗永久改牌端口完成K到A")
    _assert_equal([rank_king.rank_name, rank_king.rank_order,
        rank_king.qi_value, rank_king.definition_id],
        ["A", 14, 12, "forest_A"],
        "K到A同步A的基础真气值12")
    var ace_to_two: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(rank_ace.id), RESHAPE_ID, {},
            _battle_source("rank-cycle-ace", INNER_SKILL_ID))
    _assert_true(ace_to_two.get("success", false),
        "战斗永久改牌端口完成A循环到2")
    _assert_equal([rank_ace.rank_name, rank_ace.rank_order,
        rank_ace.qi_value, rank_ace.definition_id],
        ["2", 2, 2, "fire_2"],
        "A到2同步循环后的完整基础身份")
    _assert_equal(facts.size(), 3,
        "三次实际永久变化各发布一次 canonical 事实")
    _assert_true(facts.all(func(fact):
        return (
            str(fact.get("scope", "")) == "battle"
            and str(fact.get("persistence", "")) == "permanent"
            and str(fact.get("source_kind", "")) == "inner_skill"
            and int(fact.get("actual_change_count", 0)) > 0
            and not str(fact.get("request_fingerprint", "")).is_empty()
        )),
        "战斗事实公开永久 scope、来源、变化数与稳定指纹")

    var temporary_before: Dictionary = QiCardInstanceDataScript.capture(
        temporary)
    var temporary_rejected: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(temporary.id), RESHAPE_ID, {},
            _battle_source("temporary-rejected", INNER_SKILL_ID))
    _assert_true(not temporary_rejected.get("success", true),
        "战斗临时真气不能永久改牌")
    _assert_equal(QiCardInstanceDataScript.capture(temporary),
        temporary_before,
        "临时真气拒绝后状态不变")
    var enemy_before: Dictionary = QiCardInstanceDataScript.capture(enemy_card)
    var foreign_rejected: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(enemy_card.id), RESHAPE_ID, {},
            _battle_source("foreign-rejected", INNER_SKILL_ID))
    _assert_true(not foreign_rejected.get("success", true),
        "不能以我方 owner 修改敌方持有的永久真气")
    _assert_equal(QiCardInstanceDataScript.capture(enemy_card), enemy_before,
        "错误 owner 拒绝后敌方真气不变")

    var forged_source: Dictionary = {
        "source_kind": "inner_skill",
        "source_id": INNER_SKILL_ID,
        "source_instance_key": "inner_skill:player:%s:0" % INNER_SKILL_ID,
        "operation_token": "forged-operation-without-root",
    }
    var no_root_before: Dictionary = QiCardInstanceDataScript.capture(rank_two)
    var no_root: Dictionary = engine.effect_ports.advance_permanent_qi_rank(
        engine.player, str(rank_two.id), RESHAPE_ID, {}, forged_source)
    _assert_true(not no_root.get("success", true),
        "仅伪造 operation_token 而缺少 root/action/event token 时拒绝")
    _assert_equal(QiCardInstanceDataScript.capture(rank_two), no_root_before,
        "缺 root token 的拒绝不改牌")
    var noncanonical_source: Dictionary = _battle_source(
        "explicit-token-rejected", INNER_SKILL_ID)
    noncanonical_source["operation_token"] = "noncanonical-explicit-token"
    var explicit_before: Dictionary = QiCardInstanceDataScript.capture(rank_two)
    var noncanonical: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(rank_two.id), RESHAPE_ID, {},
            noncanonical_source)
    _assert_true(not noncanonical.get("success", true),
        "显式非 canonical operation token 被拒绝")
    _assert_equal(QiCardInstanceDataScript.capture(rank_two), explicit_before,
        "非 canonical token 失败不修改状态或新增事实")
    _assert_equal(facts.size(), 3,
        "所有拒绝路径均不泄漏 qi_reshape_committed")


func _test_fortune_frozen_results_and_idempotency() -> void:
    var engine = _engine(510005)
    _assert_true(engine.player.configure_inner_skills([
        INNER_SKILL_ID]).get("success", false),
        "机缘不空通过正式 inner_skill 来源装配")
    var double_failed = _card("2", "wind")
    var array_failed = _card("K", "forest")
    var multiplier_succeeded = _card("7", "fire")
    var experience_succeeded = _card("8", "mountain")
    for card in [double_failed, array_failed,
            multiplier_succeeded, experience_succeeded]:
        card.set_enhancement("opportunity")
    engine.player.hand = [double_failed, array_failed,
        multiplier_succeeded, experience_succeeded]
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "qi_reshape_committed":
                facts.append(values.duplicate(true)))
    var frozen: Dictionary = {
        str(double_failed.id): {
            "multiplier_success": false,
            "experience_success": false,
        },
        str(array_failed.id): [{
            "multiplier_success": false,
            "experience_success": true,
        }, {
            "multiplier_success": false,
            "experience_success": false,
        }],
        str(multiplier_succeeded.id): {
            "multiplier_success": true,
            "experience_success": false,
        },
        str(experience_succeeded.id): {
            "multiplier_success": false,
            "experience_success": true,
        },
    }
    var committed: Dictionary = _commit_fortune_execution(
        engine, "fortune-frozen-root", frozen,
        [double_failed, array_failed,
            multiplier_succeeded, experience_succeeded])
    _assert_true(committed.get("success", false),
        "机缘不空消费功法确认阶段冻结结果")
    _assert_equal([double_failed.rank_name, array_failed.rank_name],
        ["3", "A"],
        "双判定均失败的多张机缘真气分别升阶")
    _assert_equal([multiplier_succeeded.rank_name,
        experience_succeeded.rank_name], ["7", "8"],
        "倍率或历练任一成功均不升阶")
    _assert_equal(facts.size(), 2,
        "标量与数组冻结结果各只触发一次永久重塑")
    _assert_equal(facts.map(func(fact):
        return str(fact.get("card_instance_id", ""))),
        [str(double_failed.id), str(array_failed.id)],
        "多卡机缘按参与牌集合稳定顺序提交")

    var same_event: Dictionary = engine.battle_passive_event_service.commit(
        FORTUNE_HOOK, committed["event_values"])
    _assert_true(same_event.get("success", false)
        and same_event.get("reused", false),
        "同 execution event token 重放复用 committed 回执")
    _assert_equal([double_failed.rank_name, array_failed.rank_name],
        ["3", "A"],
        "同事实回执重放不重复升阶")
    var same_root_new_event: Dictionary = _commit_fortune_execution(
        engine, "fortune-frozen-root", frozen,
        [double_failed, array_failed,
            multiplier_succeeded, experience_succeeded],
        "fortune-frozen-root-replayed-event")
    _assert_true(same_root_new_event.get("success", false),
        "功法回响可复用同一 root 的冻结结果")
    _assert_equal([double_failed.rank_name, array_failed.rank_name],
        ["3", "A"],
        "新事件 token 但同 root action 仍由永久改牌回执幂等")
    _assert_equal(facts.size(), 2,
        "等待恢复或回响不重复发送永久重塑事实")

    var next_action: Dictionary = _commit_fortune_execution(
        engine, "fortune-next-action", {
            str(double_failed.id): {
                "multiplier_success": false,
                "experience_success": false,
            },
        }, [double_failed])
    _assert_true(next_action.get("success", false),
        "下一次独立行动可再次消费新的冻结结果")
    _assert_equal(double_failed.rank_name, "4",
        "下一独立行动再次双失败时继续升阶")
    _assert_equal(facts.size(), 3,
        "下一独立行动产生新的 canonical 重塑事实")


func _test_nurture_item_battle_reshape_bridge() -> void:
    var engine = _engine(510006)
    _assert_true(engine.player.configure_items([ITEM_ID]).get(
        "success", false),
        "纳气养命通过正式 item 来源装配")
    var temporary = _card("6", "wind")
    var permanent = _card("9", "forest")
    var enemy_card = _card("10", "fire")
    engine.player.hand = [temporary, permanent]
    engine.enemy.hand = [enemy_card]
    engine.player.life = 50
    var metadata: Dictionary = _battle_source(
        "temporary-reshape-heal", "probe")
    metadata["source_actor"] = engine.player
    metadata["actor"] = engine.player
    metadata["target"] = engine.enemy
    var temporary_applied: Dictionary = engine.status_system \
        .apply_temporary_rank(
            temporary, "7", 7, 7,
            "纳气养命临时重塑专项", metadata)
    _assert_true(temporary_applied.get("success", false),
        "临时牌阶重塑通过现有 card_state_changed")
    _assert_equal(engine.player.life, 51,
        "每张我方临时重塑恢复1点生命")
    engine.status_system.apply_temporary_rank(
        temporary, "7", 7, 7,
        "纳气养命临时重塑 no-op", metadata)
    _assert_equal(engine.player.life, 51,
        "临时重塑无实际变化不回血")

    engine.status_system.apply_temporary_enhancement(
        temporary, "momentum", "聚合清除准备", metadata)
    engine.status_system.apply_temporary_attribute(
        temporary, "mountain", "聚合清除准备", metadata)
    engine.player.life = 50
    var cleared: Dictionary = engine.status_system \
        .clear_all_temporary_reshapes(
            temporary, "纳气养命多槽聚合清除", metadata)
    _assert_true(cleared.get("success", false),
        "同牌多个临时重塑槽由一个 canonical 事实清除")
    _assert_equal(cleared.get("state_event", {}).get(
        "actual_change_count"), 3,
        "同牌同 operation 多槽清除聚合为一份三字段事实")
    _assert_equal(engine.player.life, 50,
        "清除临时重塑不是成功施加重塑，不触发回血")

    var enemy_metadata: Dictionary = _battle_source("enemy-reshape", "probe")
    enemy_metadata["source_actor"] = engine.enemy
    enemy_metadata["actor"] = engine.enemy
    enemy_metadata["target"] = engine.player
    engine.status_system.apply_temporary_rank(
        enemy_card, "J", 11, 11,
        "非我方重塑专项", enemy_metadata)
    _assert_equal(engine.player.life, 50,
        "非我方真气重塑不触发纳气养命")

    var permanent_result: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(permanent.id), RESHAPE_ID, {},
            _battle_source("item-permanent-reshape", "probe"))
    _assert_true(permanent_result.get("success", false),
        "战斗永久重塑走统一 BattleCardEffectService 端口")
    _assert_equal(engine.player.life, 51,
        "战斗永久重塑通过 qi_reshape_committed 恢复1生命")
    var repeated: Dictionary = engine.effect_ports \
        .advance_permanent_qi_rank(
            engine.player, str(permanent.id), RESHAPE_ID, {},
            _battle_source("item-permanent-reshape", "probe"))
    _assert_true(repeated.get("reused", false),
        "战斗永久重塑重复请求复用回执")
    _assert_equal(engine.player.life, 51,
        "重复永久改牌事实不会让物品重复回血")

    var bridge = _engine(510007)
    _assert_true(bridge.player.configure_inner_skills([
        INNER_SKILL_ID]).get("success", false)
        and bridge.player.configure_items([ITEM_ID]).get("success", false),
        "机缘不空与纳气养命使用统一来源运行时共同装配")
    var opportunity = _card("2", "mountain")
    opportunity.set_enhancement("opportunity")
    bridge.player.hand = [opportunity]
    bridge.player.life = 40
    var bridge_facts: Array = []
    bridge.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "qi_reshape_committed":
                bridge_facts.append(values.duplicate(true)))
    var bridged: Dictionary = _commit_fortune_execution(
        bridge, "fortune-item-bridge", {
            str(opportunity.id): {
                "multiplier_success": false,
                "experience_success": false,
            },
        }, [opportunity])
    _assert_true(bridged.get("success", false),
        "机缘双失败经数据化被动请求通用永久改牌")
    _assert_equal(opportunity.rank_name, "3",
        "机缘桥接在当前战斗立即可见")
    _assert_equal(bridge.player.life, 41,
        "机缘升阶的唯一重塑事实让纳气养命恰好回血1")
    _assert_equal(bridge_facts.size(), 1,
        "机缘与纳气养命桥接不重复发布永久重塑事实")
    _commit_fortune_execution(
        bridge, "fortune-item-bridge", {
            str(opportunity.id): {
                "multiplier_success": false,
                "experience_success": false,
            },
        }, [opportunity], "fortune-item-bridge-replay")
    _assert_equal([opportunity.rank_name, bridge.player.life,
        bridge_facts.size()], ["3", 41, 1],
        "同 root 的回响重放不重复改牌、回血或发布事实")


func _test_battle_victory_defeat_and_restart_boundaries(composition) -> void:
    var restart_session = composition.create_run_session()
    _assert_true(restart_session.execute({
        "type": "setup_run", "seed": 510008,
        "starter_build_id": "standard_52",
    }).success, "战斗重开专项建立本局")
    var restart_battle = restart_session.create_battle_session()
    _assert_true(restart_battle.setup_battle({
        "content_seed": 510008,
        "battle": {"use_enemy_ai": false},
    }, restart_session.progress_snapshot()),
        "从正式 RunDeck 建立第一场战斗工作副本")
    var restart_card = _battle_card(restart_battle.engine.player, "wind_2")
    var restart_mutation: Dictionary = restart_battle.engine.effect_ports \
        .advance_permanent_qi_rank(
            restart_battle.engine.player, str(restart_card.id),
            RESHAPE_ID, {},
            _battle_source("restart-discarded", INNER_SKILL_ID))
    _assert_true(restart_mutation.get("success", false)
        and restart_card.rank_name == "3",
        "战斗工作副本永久变化在当前战斗立即可见")
    restart_battle.close_battle()
    var reopened = restart_session.create_battle_session()
    _assert_true(reopened.setup_battle({
        "content_seed": 510008,
        "battle": {"use_enemy_ai": false},
    }, restart_session.progress_snapshot()),
        "退出后从未提交 Run 状态重新建立战斗")
    _assert_equal(_battle_card(
        reopened.engine.player, "wind_2").rank_name, "2",
        "退出或重开丢弃未胜利同步的战斗永久改牌")
    reopened.close_battle()

    var victory = _prepared_run_battle(composition, 510009)
    _assert_true(victory.get("success", false),
        "胜利同步专项建立正式节点战斗")
    if victory.get("success", false):
        var victory_card = _battle_card(
            victory["battle"].engine.player, "wind_2")
        _assert_true(victory["battle"].engine.effect_ports \
            .advance_permanent_qi_rank(
                victory["battle"].engine.player,
                str(victory_card.id), RESHAPE_ID, {},
                _battle_source("victory-sync", INNER_SKILL_ID)) \
            .get("success", false),
            "胜利专项在 BattleSide 工作牌上永久升阶")
        var victory_result = victory["session"].execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_result(
                victory["dispatch"], "player_victory"),
            "progress_snapshot": victory["battle"] \
                .player_progress_snapshot(),
        })
        _assert_true(victory_result.success,
            "胜利通过既有绝对进度同步边界提交")
        _assert_equal(victory["session"].growth.run_deck.card_data(
            "wind_2").get("rank_name"), "3",
            "胜利同步把战斗永久改牌写回正式 RunDeck")

    var defeat = _prepared_run_battle(composition, 510010)
    _assert_true(defeat.get("success", false),
        "战败同步专项建立正式节点战斗")
    if defeat.get("success", false):
        var defeat_card = _battle_card(
            defeat["battle"].engine.player, "wind_2")
        _assert_true(defeat["battle"].engine.effect_ports \
            .advance_permanent_qi_rank(
                defeat["battle"].engine.player,
                str(defeat_card.id), RESHAPE_ID, {},
                _battle_source("defeat-discarded", INNER_SKILL_ID)) \
            .get("success", false),
            "战败专项先在 BattleSide 工作牌上产生变化")
        var defeat_result = defeat["session"].execute({
            "type": "resolve_battle_result",
            "battle_result": _battle_result(
                defeat["dispatch"], "player_defeat"),
            "progress_snapshot": defeat["battle"] \
                .player_progress_snapshot(),
        })
        _assert_true(defeat_result.success,
            "战败仍通过既有聚合结果事务完成终局")
        _assert_equal(defeat["session"].growth.run_deck.card_data(
            "wind_2").get("rank_name"), "2",
            "战败事务恢复战前 RunDeck 而不提交战斗永久改牌")


func _run_source(transaction_token: String, source_kind: String) -> Dictionary:
    return {
        "transaction_token": transaction_token,
        "source_kind": source_kind,
        "source_id": "addition_probe",
        "source_name": "永久真气专项来源",
        "source_instance_key": "%s:addition_probe" % source_kind,
        "trigger_mode": "direct",
        "reason": "永久真气专项",
    }


func _battle_source(root_action_token: String, source_id: String) -> Dictionary:
    return {
        "source_kind": "inner_skill" if source_id == INNER_SKILL_ID \
            else "rule",
        "source_id": source_id,
        "source_name": source_id,
        "source_instance_key": "inner_skill:player:%s:0" % source_id \
            if source_id == INNER_SKILL_ID else "rule:%s" % source_id,
        "trigger_mode": "direct",
        "action_token": root_action_token,
        "root_action_token": root_action_token,
        "reason": "永久真气专项",
    }


func _persistent_card(
        catalog, definition_id: String, instance_id: String) -> Dictionary:
    var card = DeckFactoryScript.create_card_instance(
        catalog.get_by_id("card", definition_id),
        instance_id,
        catalog.card_reshape_rules)
    return QiCardInstanceDataScript.capture(card)


func _events(result: Dictionary, event_type: String) -> Array:
    return result.get("committed_events", []).filter(func(value):
        return (
            value is Dictionary
            and str(value.get("event_type", "")) == event_type
        ))


func _unique_card_ids(facts: Array) -> Dictionary:
    var result: Dictionary = {}
    for fact in facts:
        result[str(fact.get("card_instance_id", ""))] = true
    return result


func _nurture_marker_value(growth) -> int:
    var key: String = SourceMarkerAddressResolverScript.new() \
        .item_source_instance_key(growth, ITEM_ID)
    return growth.source_marker_store.value(
        "item", key, MARKER_ID, "run")


func _commit_fortune_execution(
        engine,
        root_action_token: String,
        frozen_results: Dictionary,
        contributing_cards: Array,
        event_semantic_token: String = "") -> Dictionary:
    var serial: int = int(engine.battle_passive_event_service.next_serial())
    var semantic_token: String = event_semantic_token \
        if event_semantic_token != "" else root_action_token
    var values: Dictionary = {
        "event_token": engine.battle_passive_event_service.make_token(
            FORTUNE_HOOK,
            engine.player,
            serial,
            semantic_token),
        "event_serial": serial,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "action_token": semantic_token,
        "root_action_token": root_action_token,
        "source_kind": "technique",
        "source_id": "fortune_execution_probe",
        "source_name": "机缘冻结专项功法",
        "source_instance_key": "technique:fortune_execution_probe",
        "hand_id": "high_card",
        "technique_id": "fortune_execution_probe",
        "technique_pool": "high",
        "initial_power": 10,
        "technique_power": 10,
        "trigger_mode": "manual",
        "technique_triggered": true,
        "action_succeeded": true,
        "metadata": {
            "root_action_token": root_action_token,
            "effect_context_values": {
                "actor": engine.player,
                "target": engine.enemy,
                "owner": engine.player,
                "played_cards": contributing_cards.duplicate(),
                "hand_result": {
                    "id": "high_card",
                    "contributing": contributing_cards.duplicate(),
                },
                "group_snapshot": {
                    "played_cards": contributing_cards.duplicate(),
                    "contributing_cards": contributing_cards.duplicate(),
                    "extra_cards": [],
                    "reshape_action_results": frozen_results.duplicate(true),
                },
                "reshape_action_results": frozen_results.duplicate(true),
                "values": {
                    "initial_power": 10,
                    "technique_value": 10,
                },
                "power": 10,
                "initial_power": 10,
                "technique_id": "fortune_execution_probe",
                "technique_name": "机缘冻结专项功法",
                "action_token": semantic_token,
                "root_action_token": root_action_token,
                "trigger_mode": "manual",
            },
        },
    }
    var committed: Dictionary = engine.battle_passive_event_service.commit(
        FORTUNE_HOOK, values)
    committed["event_values"] = values
    return committed


func _battle_card(side, instance_id: String):
    for card in side.all_zone_cards():
        if str(card.id) == instance_id:
            return card
    return null


func _prepared_run_battle(composition, seed_value: int) -> Dictionary:
    var session = composition.create_run_session()
    var setup = session.execute({
        "type": "setup_run",
        "seed": seed_value,
        "starter_build_id": "standard_52",
    })
    if not setup.success:
        return {"success": false, "reason": "本局建立失败"}
    var node_ids: Array = session.snapshot().available_node_ids
    if node_ids.is_empty():
        return {"success": false, "reason": "没有可进入节点"}
    var begun = session.execute({
        "type": "begin_node", "node_id": str(node_ids[0]),
    })
    if not begun.success:
        return {"success": false, "reason": "节点进入失败"}
    var dispatch: Dictionary = begun.payload_value("dispatch", {})
    if str(dispatch.get("route", "")) != "battle":
        return {"success": false, "reason": "首个节点不是战斗路由"}
    var battle = session.create_battle_session()
    if not battle.setup_battle(dispatch, session.progress_snapshot()):
        return {"success": false, "reason": "战斗建立失败"}
    return {
        "success": true,
        "session": session,
        "battle": battle,
        "dispatch": dispatch,
    }


func _battle_result(dispatch: Dictionary, battle_state: String):
    return BattleFinalResultDTOScript.from_dict({
        "schema_version": 1,
        "battle_state": battle_state,
        "detail": "永久真气专项结果",
        "node_id": str(dispatch.get("node_id", "")),
        "act": int(dispatch.get("act", 1)),
        "node_type": str(dispatch.get("node_type", "")),
        "content_id": str(dispatch.get("content_id", "")),
        "content_seed": int(dispatch.get("content_seed", 0)),
        "turn_number": 1,
    })
