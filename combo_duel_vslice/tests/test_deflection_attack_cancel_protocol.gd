extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveRuleSourceScript = preload(
    "res://core/passives/passive_rule_source.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const AiBattleStateProjectorScript = preload(
    "res://core/ai/ai_battle_state_projector.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")


class PreLifeLossProbeHandler:
    extends "res://core/passives/passive_rule_handler.gd"

    var calls := 0

    func behavior_id() -> String:
        return "deflection_pre_life_loss_probe"

    func supported_hooks() -> Array[String]:
        return ["pre_life_loss_query"] as Array[String]

    func handle(_hook: String, context, _configuration: Dictionary) -> Dictionary:
        calls += 1
        var request = context.payload.get("int_query")
        return {"success": true, "value": int(request.current_value)}


class StaticSourceResolver:
    extends RefCounted

    var _catalog = null
    var sources: Array = []

    func _init(values: Array) -> void:
        sources = values.duplicate()

    func collect_sources(context) -> Array:
        if context != null and context.has_source_snapshot:
            return context.source_snapshot.map(func(value):
                return PassiveRuleSourceScript.new().configure(value))
        return sources.duplicate()

    func capture_source_snapshot(context) -> Array:
        return collect_sources(context).map(func(source): return source.to_dict())

    func equipped_inner_skill_entries(_context) -> Array:
        return []


class FailingAttackCancelEventService:
    extends RefCounted

    var serial := 0
    var attack_cancel_calls := 0
    var fail_on_attack_cancel := 1
    var receipts: Array[String] = []
    var publications: Array[Dictionary] = []

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
        return "fake|%s|%s|%s" % [
            event_kind, str(semantic_serial), action_token]

    func commit(event_kind: String, values: Dictionary) -> Dictionary:
        if event_kind == "attack_canceled":
            attack_cancel_calls += 1
            if attack_cancel_calls == fail_on_attack_cancel:
                return {"success": false, "reason": "Fake attack cancel failure"}
        var token := str(values.get("event_token", ""))
        receipts.append(token)
        publications.append({"kind": event_kind, "values": values.duplicate(true)})
        return {"success": true, "receipt": {"event_token": token}}

    func capture_transaction_state() -> Dictionary:
        return {
            "serial": serial,
            "attack_cancel_calls": attack_cancel_calls,
            "receipts": receipts.duplicate(),
            "publications": publications.duplicate(true),
        }

    func restore_transaction_state(state: Dictionary) -> void:
        serial = int(state.get("serial", 0))
        attack_cancel_calls = int(state.get("attack_cancel_calls", 0))
        receipts.assign(state.get("receipts", []))
        publications.assign(state.get("publications", []))

    func begin_publication_transaction() -> void:
        pass

    func commit_publication_transaction() -> void:
        pass

    func rollback_publication_transaction() -> void:
        pass


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_threshold_boundaries_and_order()
    _test_deflection_then_block_and_damage_pipeline()
    _test_ineligible_damage_and_blockable_false()
    _test_events_and_pre_life_loss_skip()
    _test_synchronized_preview_flush_and_rollback()
    _test_snapshot_lifecycle_and_public_projection()
    _test_effect_op_and_technique_summary()
    _finish("DEFLECTION ATTACK CANCEL PROTOCOL TEST")


func _test_threshold_boundaries_and_order() -> void:
    var engine = _engine(140001)
    _begin_window(engine)
    _grant(engine, 6, "n-less")
    var hit := _attack(engine, 5, "less")
    _assert_true(hit.get("canceled", false), "A<N时卸力取消攻击")
    _assert_equal(hit.get("cancel_kind"), "deflection", "取消类型为deflection")
    _assert_equal(engine.enemy.block_sources.size(), 0, "卸力成功后来源已消费")

    engine = _engine(140002)
    _begin_window(engine)
    _grant(engine, 5, "n-equal")
    hit = _attack(engine, 5, "equal")
    _assert_true(hit.get("canceled", false), "A=N时卸力成功")

    engine = _engine(140003)
    _begin_window(engine)
    _grant(engine, 4, "pierced")
    hit = _attack(engine, 5, "pierced")
    _assert_true(not hit.get("canceled", false), "A>N时卸力被击穿")
    _assert_equal(engine.enemy.block_sources.size(), 0, "击穿仍消费卸力")
    _assert_equal(engine.enemy.life, 95, "击穿后伤害继续结算")

    engine = _engine(140004)
    _begin_window(engine)
    var first := _grant(engine, 2, "first")
    var second := _grant(engine, 8, "second")
    hit = _attack(engine, 5, "ordered")
    var receipt: Dictionary = hit.get("attack_cancellation", {})
    _assert_equal(receipt.get("checked_source_tokens"), [
        first.get("source_token"), second.get("source_token")],
        "多个卸力按建立顺序而非阈值排序")
    _assert_true(hit.get("canceled", false), "首个击穿后第二个可以成功")
    _assert_equal(engine.enemy.block_sources.size(), 0, "已检查的两个卸力均消费")

    engine = _engine(140005)
    _begin_window(engine)
    _grant(engine, 8, "first-success")
    second = _grant(engine, 9, "later-kept")
    hit = _attack(engine, 5, "short-circuit")
    _assert_true(hit.get("canceled", false), "首个卸力成功立即取消")
    _assert_equal(engine.enemy.block_sources.size(), 1, "成功后的卸力来源保留")
    _assert_equal(str(engine.enemy.block_sources[0].get("source_token", "")),
        str(second.get("source_token", "")), "保留的正是后续来源")


func _test_deflection_then_block_and_damage_pipeline() -> void:
    var engine = _engine(140010)
    _begin_window(engine)
    _grant(engine, 2, "pierce-before-block")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "后续格挡")
    var hit := _attack(engine, 5, "block-after-deflection")
    _assert_true(hit.get("blocked", false), "全部卸力击穿后格挡继续取消")
    _assert_equal(hit.get("cancel_kind"), "block", "兼容blocked结果区分格挡")
    _assert_equal(engine.enemy.block_sources.size(), 0, "击穿卸力和成功格挡均消费")

    engine = _engine(140011)
    _begin_window(engine)
    _grant(engine, 9, "deflect-before-block")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "应保留格挡")
    hit = _attack(engine, 5, "deflect-first")
    _assert_equal(hit.get("cancel_kind"), "deflection", "卸力优先于格挡")
    _assert_equal(engine.enemy.public_block_sources().size(), 1,
        "卸力成功不检查也不消费格挡")

    engine = _engine(140012)
    engine.enemy.defense = 4
    engine.enemy.add_reflection_source(100, "pipeline-reflect", 1)
    _begin_window(engine)
    _grant(engine, 1, "pipeline-pierce")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player,
        {"block_damage_at_most_defense": true}, "条件失败格挡")
    var player_life: int = int(engine.player.life)
    hit = _attack(engine, 6, "full-pipeline")
    _assert_true(not hit.get("canceled", false), "卸力和格挡都失败时继续伤害")
    _assert_equal(hit.get("defense_lost"), 4, "伤害进入防御吸收")
    _assert_equal(hit.get("life_lost"), 2, "溢出继续写入生命")
    _assert_equal(player_life - engine.player.life, 4, "最后按实际防御损失反震")
    _assert_equal(engine.enemy.public_block_sources().size(), 1,
        "条件不成立的格挡不消费")

    engine = _engine(140013)
    _begin_window(engine)
    _grant(engine, 5, "true-deflect")
    hit = _attack(engine, 5, "true", "true")
    _assert_true(hit.get("canceled", false), "可取消真伤支持卸力")
    _assert_equal(engine.enemy.life, 100, "真伤取消后不写生命")


func _test_ineligible_damage_and_blockable_false() -> void:
    var engine = _engine(140020)
    _begin_window(engine)
    _grant(engine, 99, "ineligible")
    var poison: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 3, "rule", false,
        "poison", "poison", {"direct_attack": true})
    var self_poison: Dictionary = engine.effect_ports.deal_damage(
        engine.enemy, engine.enemy, 1, "rule", false,
        "self-poison", "poison", {"direct_attack": false})
    var reflection: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 2, "rule", false,
        "reflection", "normal", {
            "direct_attack": false, "reflection_damage": true})
    var cost: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 2, "rule", true,
        "cost", "true", {"direct_attack": true, "cause": "cost"})
    _assert_true(poison.get("success", false) and self_poison.get(
        "success", false) and reflection.get("success", false)
        and cost.get("success", false), "毒、自毒、反震与生命代价正常结算")
    _assert_equal(engine.enemy.block_sources.size(), 1,
        "非敌方直接攻击不查询也不消费卸力")

    engine = _engine(140021)
    engine.enemy.defense = 3
    engine.enemy.add_reflection_source(100, "unblockable-reflect", 1)
    _begin_window(engine)
    _grant(engine, 99, "unblockable-deflection")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "unblockable-block")
    var player_life: int = int(engine.player.life)
    var hit: Dictionary = engine.effect_ports.deal_damage(
        engine.player, engine.enemy, 5, "technique", false,
        "unblockable", "normal", {
            "direct_attack": true, "blockable": false})
    _assert_true(not hit.get("canceled", false), "blockable=false跳过两类取消")
    _assert_equal(engine.enemy.block_sources.size(), 2, "两类来源均未消费")
    _assert_equal(hit.get("defense_lost"), 3, "不可取消攻击仍吸收防御")
    _assert_equal(hit.get("life_lost"), 2, "不可取消攻击仍写入生命")
    _assert_equal(player_life - engine.player.life, 3, "不可取消攻击仍触发反震")


func _test_events_and_pre_life_loss_skip() -> void:
    var fixture := _install_pre_life_probe(_engine(140030))
    var engine = fixture["engine"]
    var events: Array[Dictionary] = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind in ["deflection_resolved", "attack_canceled",
                    "damage_blocked", "damage_resolved", "reflection_resolved"]:
                events.append({"kind": kind, "values": values.duplicate(true)}))
    engine.enemy.defense = 7
    engine.enemy.add_reflection_source(100, "must-not-reflect", 1)
    _begin_window(engine)
    _grant(engine, 5, "event-source")
    var hit := _attack(engine, 5, "event-deflect")
    _assert_true(hit.get("canceled", false), "卸力成功取消完整攻击段")
    _assert_equal(engine.enemy.defense, 7, "取消后不减少防御")
    _assert_equal(engine.enemy.life, 100, "取消后不减少生命")
    _assert_equal(fixture["handler"].calls, 0, "取消后不执行pre_life_loss_query")
    _assert_equal(_events(events, "deflection_resolved").size(), 1,
        "每个消费卸力提交deflection_resolved")
    _assert_equal(_events(events, "attack_canceled").size(), 1,
        "成功卸力提交canonical attack_canceled")
    _assert_equal(_events(events, "damage_blocked").size(), 0,
        "卸力成功不伪装damage_blocked")
    _assert_equal(_events(events, "damage_resolved").size(), 0,
        "取消攻击不产生damage_resolved")
    _assert_equal(_events(events, "reflection_resolved").size(), 0,
        "取消攻击不触发反震")
    var resolved: Dictionary = _events(events, "deflection_resolved")[0]
    _assert_equal([
        resolved.get("threshold"), resolved.get("attack_amount"),
        resolved.get("consumed"), resolved.get("succeeded"),
        resolved.get("pierced"), resolved.get("damage_type")],
        [5, 5, true, true, false, "normal"],
        "卸力事件公开冻结阈值、攻击值、消费和结果")
    _assert_true(str(resolved.get("damage_segment_token", "")) != ""
        and str(resolved.get("source_token", "")) != "",
        "卸力事件公开稳定段令牌和来源令牌")
    _assert_true(engine.player.condition_spec_registry.event_matches({
        "cancel_kind": "deflection", "succeeded": true,
        "threshold": 5,
    }, resolved, engine.player), "ConditionSpec可读取canonical卸力字段")
    var value_context: Variant = BattleEffectContextScript.new().configure({
        "actor": engine.player, "target": engine.enemy,
        "captures": {"event": [resolved]},
    })
    _assert_equal(EffectValueResolverScript.new().resolve({
        "kind": "event_field", "capture": "event", "field": "threshold",
    }, value_context), 5, "ValueSpec可读取canonical卸力字段")

    events.clear()
    _grant(engine, 1, "event-pierce")
    _attack(engine, 3, "event-pierce")
    var pierced: Dictionary = _events(events, "deflection_resolved")[0]
    _assert_true(pierced.get("pierced", false)
        and not pierced.get("succeeded", true), "击穿事件字段准确")
    _assert_equal(_events(events, "attack_canceled").size(), 0,
        "卸力击穿不提交attack_canceled")

    events.clear()
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "event-block")
    _attack(engine, 3, "event-block")
    _assert_equal(_events(events, "damage_blocked").size(), 1,
        "格挡继续发送兼容damage_blocked")
    var canonical: Dictionary = _events(events, "attack_canceled")[0]
    _assert_equal(canonical.get("cancel_kind"), "block",
        "格挡同时发送canonical attack_canceled(block)")


func _test_synchronized_preview_flush_and_rollback() -> void:
    var engine = _engine(140040)
    _begin_window(engine)
    _grant(engine, 9, "sync")
    engine.effect_ports.begin_synchronized_damage([{"actor": engine.player}])
    var buffered := _attack(engine, 5, "sync-buffer")
    _assert_true(buffered.get("buffered", false), "同步shadow只形成预览")
    _assert_true(buffered.get("attack_cancellation_preview", {}).get(
        "canceled", false), "同步shadow读取卸力公开投影")
    _assert_equal(engine.enemy.block_sources.size(), 1, "shadow不消费卸力")
    _assert_equal(engine.enemy.life, 100, "shadow不写真实生命")
    var flushed: Dictionary = engine.effect_ports.flush_synchronized_damage()
    _assert_true(flushed.get("success", false), "真实flush结构化成功")
    _assert_equal(engine.enemy.block_sources.size(), 0, "真实flush才消费卸力")

    engine = _engine(140042)
    engine.enemy.defense = 4
    _begin_window(engine)
    _grant(engine, 9, "single-event-rollback")
    var single_fake := FailingAttackCancelEventService.new()
    engine.effect_ports.use_passive_battle_services(null, single_fake)
    var single_history: Array = engine.trigger_queue.history.duplicate(true)
    var failed_hit := _attack(engine, 5, "single-event-failure")
    _assert_true(not failed_hit.get("success", true) and failed_hit.get(
        "rolled_back", false), "普通伤害取消事件失败也返回结构化回滚")
    _assert_equal(engine.enemy.block_sources.size(), 1,
        "普通事件失败恢复已消费卸力")
    _assert_equal([engine.enemy.defense, engine.enemy.life], [4, 100],
        "普通事件失败不留下防御或生命写入")
    _assert_equal(engine.trigger_queue.history, single_history,
        "普通事件失败恢复日志")
    _assert_equal(single_fake.receipts, [], "普通事件失败恢复receipt")

    engine = _engine(140041)
    _begin_window(engine)
    _grant(engine, 9, "rollback-first")
    _grant(engine, 9, "rollback-second")
    var fake := FailingAttackCancelEventService.new()
    fake.fail_on_attack_cancel = 2
    engine.effect_ports.use_passive_battle_services(null, fake)
    engine.effect_ports.begin_synchronized_damage([{"actor": engine.player}])
    _attack(engine, 5, "rollback-a")
    _attack(engine, 5, "rollback-b")
    var history_before: Array = engine.trigger_queue.history.duplicate(true)
    flushed = engine.effect_ports.flush_synchronized_damage()
    _assert_true(not flushed.get("success", true) and flushed.get(
        "rolled_back", false), "后段事件失败使整个flush失败并回滚")
    _assert_equal(engine.enemy.block_sources.size(), 2, "flush回滚全部卸力来源")
    _assert_equal(engine.enemy.life, 100, "flush回滚生命和防御")
    _assert_equal(engine.trigger_queue.history, history_before,
        "flush回滚日志与触发队列")
    _assert_equal(fake.receipts, [], "flush回滚committed receipt状态")


func _test_snapshot_lifecycle_and_public_projection() -> void:
    var engine = _engine(140050)
    _begin_window(engine)
    _grant(engine, 3, "snapshot-first")
    _grant(engine, 7, "snapshot-second")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "snapshot-block")
    var state: Dictionary = engine.enemy.capture_passive_query_state()
    var window_id := str(engine.enemy.block_sources[0].get("window_id", ""))
    engine.enemy.clear_combat_sources()
    engine.enemy.replace_passive_query_state(state)
    var public_deflections: Array = engine.enemy.public_deflection_sources()
    _assert_equal(public_deflections.map(func(source): return source.get("threshold")),
        [3, 7], "快照恢复卸力顺序与冻结阈值")
    _assert_equal(public_deflections.map(func(source): return source.get("window_id")),
        [window_id, window_id], "快照恢复行动窗口")
    _assert_equal(engine.enemy.public_block_sources().size(), 1,
        "公开投影不把卸力误计为格挡")
    var ai := AiBattleStateProjectorScript.new().project_self(
        engine.enemy, engine.enemy_sequence_book, engine.battle_flow)
    _assert_equal(ai.get("block_sources", []).size(), 1,
        "AI状态保留格挡数量")
    _assert_equal(ai.get("deflection_sources", []).map(
        func(source): return source.get("threshold")), [3, 7],
        "AI状态公开卸力阈值与顺序")
    var finished: Dictionary = engine.action_resolver.finish_action_resolution()
    _assert_true(finished.get("success", false), "行动窗口正常收尾")
    _assert_equal(engine.enemy.block_sources.size(), 0,
        "行动窗口到期统一清理格挡和卸力")
    _grant(engine, 5, "battle-end")
    engine.enemy.clear_combat_sources()
    _assert_equal(engine.enemy.public_deflection_sources(), [],
        "战斗结束清理公开卸力来源")


func _test_effect_op_and_technique_summary() -> void:
    var engine = _engine(140060)
    _begin_window(engine)
    var context: Variant = _execution_context(engine, "deflection-summary")
    var granted: Dictionary = engine.effect_executor.execute_all([{
        "op": "grant_deflection", "threshold": 5, "capture": "granted",
    }], BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.enemy,
        "target": engine.player,
        "source_kind": "item",
        "source_id": "fake_item",
        "source_name": "测试卸力",
        "source_instance_key": "item:test:deflection",
        "trigger_mode": "direct",
        "captures": {},
    }))
    _assert_true(granted.get("success", false), "通用grant_deflection效果op可建立来源")
    _assert_equal(engine.enemy.public_deflection_sources()[0].get("threshold"), 5,
        "效果op在建立时冻结阈值")
    _assert_true(not engine.effect_ports.grant_deflection_source(
        engine.enemy, engine.player, -1, "非法卸力").get("success", true),
        "公共端口拒绝负阈值")

    engine.enemy.block_sources.clear()
    engine.technique_resolution_service._begin_execution(
        engine.technique_resolution_service._execution_info_from_context(context))
    _grant(engine, 5, "summary-deflection")
    _attack_with_source(engine, 5, context, "summary-deflection")
    engine.effect_ports.grant_block_source(
        engine.enemy, engine.player, {}, "summary-block")
    _attack_with_source(engine, 5, context, "summary-block")
    var completed: Dictionary = engine.technique_resolution_service \
        .finish_execution(context)
    var summary: Dictionary = completed.get("summary", {})
    _assert_equal(summary.get("block_canceled_segment_count"), 1,
        "功法汇总单独统计格挡取消段")
    _assert_equal(summary.get("deflection_canceled_segment_count"), 1,
        "功法汇总单独统计卸力取消段")
    _assert_equal(summary.get("total_canceled_segment_count"), 2,
        "功法汇总提供总取消段数")
    _assert_equal(summary.get("damage_segment_count"), 2,
        "格挡和卸力取消段各只汇总一次")


func _begin_window(engine) -> void:
    engine.effect_ports.begin_action_resolution(
        [engine.player, engine.enemy], {
            "acting_owner_ids": [str(engine.player.owner_id)],
        })


func _grant(engine, threshold: int, label: String) -> Dictionary:
    return engine.effect_ports.grant_deflection_source(
        engine.enemy, engine.player, threshold, label, "", {
            "source_kind": "inner_skill",
            "source_id": "fake_deflection",
            "source_name": label,
            "source_instance_key": "inner_skill:test:%s" % label,
            "trigger_mode": "response",
        })


func _attack(
        engine, amount: int, token: String,
        damage_type: String = "normal") -> Dictionary:
    return engine.effect_ports.deal_damage(
        engine.player, engine.enemy, amount, "technique",
        damage_type == "true", token, damage_type, {"direct_attack": true})


func _attack_with_source(engine, amount: int, context, token: String) -> Dictionary:
    return engine.effect_ports.deal_damage(
        engine.player, engine.enemy, amount, context.source_metadata(), false,
        context.action_token, "normal", {
            "direct_attack": true,
            "technique_execution_token": context.technique_execution_token,
            "segment_label": token,
        })


func _events(events: Array, kind: String) -> Array:
    return events.filter(func(entry): return str(entry.get("kind", "")) == kind) \
        .map(func(entry): return entry.get("values", {}))


func _install_pre_life_probe(engine) -> Dictionary:
    var handler := PreLifeLossProbeHandler.new()
    var registry = PassiveRuleHandlerRegistryScript.new(false)
    registry.register_handler(handler)
    var source = PassiveRuleSourceScript.new().configure({
        "source_kind": "item",
        "content_id": "fake_pre_life_probe",
        "source_instance_key": "item:test:pre-life-probe",
        "definition": {
            "id": "fake_pre_life_probe", "name": "生命查询探针",
            "behaviors": [{
                "id": "deflection_pre_life_loss_probe",
                "configuration": {},
            }],
        },
        "behavior_id": "deflection_pre_life_loss_probe",
        "behavior_index": 0,
        "configuration": {},
        "source_order": 0,
    })
    var runtime = PassiveRuleRuntimeScript.new(
        registry, null, null, null, StaticSourceResolver.new([source]))
    var service = BattleRuleQueryServiceScript.new(runtime)
    service.use_rng(engine.rng)
    service.use_committed_event_service(engine.battle_passive_event_service)
    engine.player.use_battle_rule_query_service(service)
    engine.enemy.use_battle_rule_query_service(service)
    engine.effect_ports.use_passive_battle_services(
        service, engine.battle_passive_event_service)
    return {"engine": engine, "handler": handler, "runtime": runtime}


func _execution_context(engine, token: String):
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "power": 5,
        "technique_id": "deflection_summary_probe",
        "technique_name": "卸力汇总探针",
        "technique_pool": "high",
        "action_token": token,
        "technique_execution_token": token,
        "technique_execution_state": {
            "pending_echo_plans": [], "next_echo_index": 0,
        },
        "root_action_token": token,
        "slot_instance_id": "summary-slot",
        "source_kind": "technique",
        "source_id": "deflection_summary_probe",
        "source_name": "卸力汇总探针",
        "source_instance_key": "summary-slot",
        "trigger_mode": "manual",
        "captures": {},
        "sequence_book": engine.sequence_book,
        "card_identity_policy": engine.player.card_identity_policy,
    })
