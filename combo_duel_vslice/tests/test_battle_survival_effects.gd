extends "res://tests/support/technique_test_group.gd"


class FailingChaseEventService:
    extends RefCounted

    var serial := 0
    var receipts: Array[String] = []

    func next_serial() -> int:
        var value := serial
        serial += 1
        return value

    func make_token(
            event_kind: String,
            _actor,
            semantic_serial,
            action_token: String = "",
            _card_instance_id: String = "") -> String:
        return "failing-chase|%s|%s|%s" % [
            event_kind, str(semantic_serial), action_token]

    func commit(event_kind: String, values: Dictionary) -> Dictionary:
        if event_kind == "chase_resolved":
            return {"success": false, "reason": "Fake chase event failure"}
        var token := str(values.get("event_token", ""))
        receipts.append(token)
        return {"success": true, "receipt": {"event_token": token}}

    func capture_transaction_state() -> Dictionary:
        return {"serial": serial, "receipts": receipts.duplicate()}

    func restore_transaction_state(state: Dictionary) -> void:
        serial = int(state.get("serial", 0))
        receipts.assign(state.get("receipts", []))

    func begin_publication_transaction() -> void:
        pass

    func commit_publication_transaction() -> void:
        pass

    func rollback_publication_transaction() -> void:
        pass


func _initialize() -> void:
    _run_group("battle-survival-effects", [
        "_test_damage_type_defense_life_and_block_facade",
        "_test_source_markers_life_and_defense_ports",
        "_test_poison_damage_modifiers_apply_per_segment",
        "_test_action_resolution_results_and_no_life_loss_disruption",
        "_test_reflection_override_sources_and_recursion_guard",
        "_test_synchronized_reflection_matches_normal_damage",
        "_test_unblockable_damage_still_absorbs_and_reflects",
        "_test_chase_resolved_normal_cancel_and_payload",
        "_test_chase_resolved_synchronized_dedup_and_rollback",
    ])


func _test_damage_type_defense_life_and_block_facade() -> void:
    var engine = _engine_with_cards([])
    engine.enemy.life = 100
    engine.enemy.defense = 4
    var normal: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test")
    _assert_equal(normal.get("defense_lost", 0), 4,
        "普通伤害先由防御吸收")
    _assert_equal(normal.get("life_lost", 0), 2,
        "普通伤害余量写入生命")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    var true_hit: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test", true,
        "survival-true", "true")
    _assert_equal(true_hit.get("defense_lost", 0), 0,
        "真伤不消耗防御")
    _assert_equal(engine.enemy.defense, 4,
        "真伤写入后保留原防御")
    _assert_equal(true_hit.get("life_lost", 0), 6,
        "真伤直接写入生命")

    engine.enemy.life = 100
    engine.enemy.defense = 4
    engine.enemy.set_reflection_percent(100)
    var player_life_before: int = int(engine.player.life)
    var poison: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 6, "survival-test", false,
        "survival-poison", "poison")
    _assert_equal(poison.get("defense_lost", 0), 0,
        "毒伤默认绕过普通防御")
    _assert_equal(engine.enemy.defense, 4,
        "毒伤默认不改写普通防御")
    _assert_equal(poison.get("life_lost", 0), 6,
        "毒伤默认直接写入生命")
    _assert_equal(engine.player.life, player_life_before,
        "毒伤不会触发反震")

    var defense_before: int = int(engine.player.defense)
    var gained: Dictionary = engine.effect_ports.add_defense_result(
        engine.player, 5, "survival-test", "survival-defense")
    _assert_true(gained.get("success", false), "防御增加通过Facade成功")
    _assert_equal(gained.get("gained", 0), 5, "防御增加写入实际增加量")
    _assert_equal(engine.player.defense, defense_before + 5,
        "防御增加写入BattleSide")

    engine.player.life = 95
    engine.player.max_life = 100
    var recovered: Dictionary = engine.effect_ports.recover_life(
        engine.player, 10, "survival-test", "survival-recovery",
        engine.player)
    _assert_equal(recovered.get("recovered", 0), 5,
        "生命恢复受最大生命限制")
    _assert_equal(engine.player.life, 100, "生命恢复正式写入BattleSide")

    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.enemy.owner_id)],
        })
    engine.effect_ports.grant_block_source(
        engine.player, engine.enemy, "unconditional", "专项格挡")
    var life_before_block: int = int(engine.player.life)
    var defense_before_block: int = int(engine.player.defense)
    var blocked: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.player, 7, "survival-test", false,
        "survival-block", "normal", {"direct_attack": true})
    _assert_true(blocked.get("blocked", false), "合格直接伤害被格挡")
    _assert_equal(engine.player.life, life_before_block,
        "格挡只免疫当前伤害的生命写入")
    _assert_equal(engine.player.defense, defense_before_block,
        "格挡只免疫当前伤害的防御写入")
    _assert_equal(engine.player.block_sources.size(), 0,
        "成功格挡消费一个来源")
    engine.effect_ports.abort_action_resolution()


func _test_chase_resolved_normal_cancel_and_payload() -> void:
    var engine = _engine_with_cards([])
    var facts: Array = []
    var kinds: Array[String] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            kinds.append(str(kind))
            if str(kind) == "chase_resolved":
                facts.append(values.duplicate(false)))
    engine.enemy.defense = 3
    engine.enemy.life = 20
    var hit := _chase_damage(engine, 5, "chase-normal")
    _assert_true(hit.get("success", false), "普通追击伤害事务成功")
    _assert_equal(facts.size(), 1, "普通追击发布一次chase_resolved")
    var fact: Dictionary = facts[0]
    for field in [
            "event_token", "event_serial", "chase_token", "action_token",
            "damage_segment_token", "actor", "attacker", "target", "defender",
            "source_kind", "source_id", "source_name", "source_instance_key",
            "trigger_mode", "damage_type", "requested_damage", "final_damage",
            "defense_before", "defense_loss", "defense_after", "life_before",
            "life_loss", "life_after", "blocked", "deflected", "cancelled",
            "cancel_kind", "round_number"]:
        _assert_true(fact.has(field), "chase_resolved公开字段：%s" % field)
    _assert_equal(fact.get("requested_damage"), 5, "追击事实记录请求伤害")
    _assert_equal(fact.get("final_damage"), 5, "追击事实记录最终伤害")
    _assert_equal([fact.get("defense_before"), fact.get("defense_loss"),
        fact.get("defense_after")], [3, 3, 0],
        "追击事实防御字段与实际结果一致")
    _assert_equal([fact.get("life_before"), fact.get("life_loss"),
        fact.get("life_after")], [20, 2, 18],
        "追击事实生命字段与实际结果一致")
    _assert_equal(fact.get("damage_segment_token"), fact.get("chase_token"),
        "追击稳定身份复用damage_segment_token")
    _assert_true(not fact.get("blocked", false)
        and not fact.get("deflected", false)
        and not fact.get("cancelled", false),
        "普通追击明确公开未取消结果")

    facts.clear()
    engine.enemy.defense = 10
    engine.enemy.life = 20
    hit = _chase_damage(engine, 4, "chase-no-life")
    _assert_equal(hit.get("life_lost"), 0, "防御完全吸收的追击没有生命损失")
    _assert_equal(facts.size(), 1, "生命损失为0的追击仍发布")
    _assert_equal(facts[0].get("life_loss"), 0, "零生命损失进入追击事实")

    facts.clear()
    engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 1, {
            "source_kind": "technique", "source_id": "ordinary",
            "source_name": "普通伤害", "source_instance_key": "slot:ordinary",
            "trigger_mode": "manual",
        }, false, "ordinary-damage", "normal", {"direct_attack": true})
    _assert_true(facts.is_empty(), "普通非追击伤害不发布chase_resolved")
    engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 1, "chase", false,
        "legacy-chase-damage", "normal", {"direct_attack": true})
    _assert_equal(facts.size(), 1, "旧source_kind=chase仍被兼容识别")
    _assert_equal(facts[0].get("chase_token"),
        facts[0].get("damage_segment_token"),
        "旧追击路径同样复用伤害段稳定身份")

    engine = _engine_with_cards([])
    facts = []
    kinds = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            kinds.append(str(kind))
            if str(kind) == "chase_resolved":
                facts.append(values.duplicate(false)))
    _begin_chase_window(engine, "chase-block")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "追击格挡", "chase-block-source")
    var defense_before := int(engine.enemy.defense)
    var life_before := int(engine.enemy.life)
    hit = _chase_damage(engine, 6, "chase-block")
    _assert_true(hit.get("blocked", false), "追击可以被格挡完全取消")
    _assert_equal(facts.size(), 1, "完全格挡的追击仍发布chase_resolved")
    _assert_true(facts[0].get("blocked", false)
        and facts[0].get("cancelled", false)
        and facts[0].get("cancel_kind") == "block",
        "格挡追击公开完整取消字段")
    _assert_equal([engine.enemy.defense, engine.enemy.life],
        [defense_before, life_before], "格挡追击不写防御或生命")
    engine.effect_ports.abort_action_resolution()

    engine = _engine_with_cards([])
    facts = []
    kinds = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            kinds.append(str(kind))
            if str(kind) == "chase_resolved":
                facts.append(values.duplicate(false)))
    _begin_chase_window(engine, "chase-deflection")
    engine.effect_ports.grant_deflection_source(
        engine.enemy, engine.player, 9, "追击卸力", "chase-deflection-source")
    hit = _chase_damage(engine, 6, "chase-deflection")
    _assert_true(hit.get("canceled", false), "卸力取消追击攻击段")
    _assert_equal(facts.size(), 1, "卸力追击仍发布chase_resolved")
    _assert_true(facts[0].get("deflected", false)
        and facts[0].get("cancelled", false)
        and facts[0].get("cancel_kind") == "deflection",
        "卸力和通用攻击取消字段同时进入追击事实")
    _assert_equal(kinds.count("attack_canceled"), 1,
        "取消追击仍沿用canonical attack_canceled")
    engine.effect_ports.abort_action_resolution()


func _test_chase_resolved_synchronized_dedup_and_rollback() -> void:
    var engine = _engine_with_cards([])
    var facts: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind, values, _receipt):
            if str(kind) == "chase_resolved":
                facts.append(values.duplicate(false)))
    engine.enemy.defense = 2
    engine.enemy.life = 20
    engine.effect_ports.begin_synchronized_damage([{"actor": engine.player}])
    var buffered := _chase_damage(engine, 5, "chase-sync")
    _assert_true(buffered.get("buffered", false), "同步追击shadow阶段只形成预览")
    _assert_true(facts.is_empty(), "同步追击预览不发布committed事实")
    var flushed: Dictionary = engine.effect_ports.flush_synchronized_damage()
    _assert_true(flushed.get("success", false), "同步追击flush成功")
    _assert_equal(facts.size(), 1, "同步真实flush发布chase_resolved")
    _assert_equal([facts[0].get("defense_loss"), facts[0].get("life_loss")],
        [2, 3], "同步追击事实与flush实际结果一致")

    facts.clear()
    engine.enemy.defense = 0
    engine.enemy.life = 20
    var stable_metadata := {
        "direct_attack": true,
        "damage_segment_kind": "chase",
        "is_chase": true,
        "damage_segment_token": "stable-chase-token",
    }
    var chase_source := _chase_source()
    engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 1, chase_source, false,
        "stable-chase-action", "normal", stable_metadata)
    engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 1, chase_source, false,
        "stable-chase-action", "normal", stable_metadata)
    _assert_equal(facts.size(), 1, "同一chase_token重复提交只发布一次")
    _assert_equal(facts[0].get("chase_token"), "stable-chase-token",
        "显式稳定damage_segment_token成为chase_token")

    engine = _engine_with_cards([])
    engine.enemy.defense = 3
    engine.enemy.life = 20
    var fake := FailingChaseEventService.new()
    engine.effect_ports.use_passive_battle_services(null, fake)
    var history_before: Array = engine.trigger_queue.history.duplicate(true)
    var failed := _chase_damage(engine, 5, "chase-failure")
    _assert_true(not failed.get("success", true)
        and failed.get("rolled_back", false),
        "chase_resolved失败沿用原伤害事务回滚")
    _assert_equal([engine.enemy.defense, engine.enemy.life], [3, 20],
        "追击事件失败恢复防御和生命")
    _assert_equal(engine.trigger_queue.history, history_before,
        "追击事件失败恢复伤害日志")
    _assert_true(fake.receipts.is_empty(),
        "追击事件失败不遗留damage_resolved或chase receipt")


func _chase_source() -> Dictionary:
    return {
        "source_kind": "technique",
        "source_id": "fixture_chase",
        "source_name": "合成追击",
        "source_instance_key": "slot:fixture_chase",
        "trigger_mode": "response",
    }


func _chase_damage(engine, amount: int, action_token: String) -> Dictionary:
    return engine.effect_ports.deal_damage(
        engine.player, engine.enemy, amount, _chase_source(), false,
        action_token, "normal", {
            "direct_attack": true,
            "damage_segment_kind": "chase",
            "is_chase": true,
        })


func _begin_chase_window(engine, action_token: String) -> void:
    engine.action_resolver.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.player.owner_id)],
            "action_tokens": [action_token],
        })
