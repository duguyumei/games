extends "res://tests/support/expanded_technique_test_base.gd"

const BattleIntQueryCatalogScript = preload(
    "res://core/passives/battle_int_query_catalog.gd")
const BattleRuleQueryServiceScript = preload(
    "res://core/passives/battle_rule_query_service.gd")
const BattleIntQueryModifierHandlerScript = preload(
    "res://core/passives/battle_int_query_modifier_passive_handler.gd")
const PassiveRuleHandlerRegistryScript = preload(
    "res://core/passives/passive_rule_handler_registry.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const BattleSideScript = preload("res://core/battle_side.gd")
const BattleQueryResultScript = preload(
    "res://core/passives/battle_passive_int_query_result.gd")
const BattleSessionScript = preload("res://core/battle_session.gd")
const AiProjectorScript = preload("res://core/ai/ai_battle_state_projector.gd")
const BattleUiMapperScript = preload("res://ui/battle_ui_mapper.gd")


class FakeCatalog:
    extends RefCounted

    var definitions: Dictionary = {}

    func _init(values: Dictionary) -> void:
        definitions = values.duplicate(true)

    func get_by_id(source_kind: String, content_id: String) -> Dictionary:
        return definitions.get(
            "%s:%s" % [source_kind, content_id], {}).duplicate(true)

    func has_id(source_kind: String, content_id: String) -> bool:
        return definitions.has("%s:%s" % [source_kind, content_id])


class FailingMomentumCapQueryService:
    extends RefCounted

    var report_count: int = 0

    func resolve_values(values: Dictionary):
        return BattleQueryResultScript.new().configure({
            "success": false,
            "hook": str(values.get("hook", "")),
            "subject_kind": str(values.get("subject_kind", "")),
            "subject_id": str(values.get("subject_id", "")),
            "base_value": int(values.get("base_value", 0)),
            "effective_value": int(values.get("base_value", 0)),
            "errors": ["合成上限查询失败"],
        })

    func report_failure(_result, _boundary: String) -> void:
        report_count += 1


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_unique_catalog_and_generic_handler()
    _test_synthetic_sources_isolation_and_suppression()
    _test_initialization_freeze_and_writes()
    _test_query_purity_failure_and_rollback()
    _test_snapshot_ai_ui_and_preview_projection()
    _finish("MOMENTUM RESOURCE POLICY TEST")


func _test_unique_catalog_and_generic_handler() -> void:
    _assert_true("momentum_cap_query" in BattleIntQueryCatalogScript.HOOKS,
        "唯一战斗整数目录登记 momentum_cap_query")
    _assert_equal(
        BattleRuleQueryServiceScript.QUERY_HOOKS,
        BattleIntQueryCatalogScript.HOOKS,
        "查询服务复用唯一整数 Hook 目录")
    _assert_equal(
        PassiveRuleHandlerRegistryScript.BATTLE_INT_QUERY_HOOKS,
        BattleIntQueryCatalogScript.HOOKS,
        "Handler Registry 复用同一整数 Hook 目录")
    var handler = BattleIntQueryModifierHandlerScript.new()
    _assert_true(handler.supported_hooks().has("momentum_cap_query"),
        "既有来源中立 Handler 自动支持连势上限查询")
    _assert_true(handler.validate_configuration({"rules": [{
        "hook": "momentum_cap_query",
        "operation": "add",
        "operand": 20,
    }]}).is_empty(), "通用 Handler 接受合成上限 +20 配置")


func _test_synthetic_sources_isolation_and_suppression() -> void:
    var definitions := {
        "inner_skill:fixture_cap_a": _cap_definition("fixture_cap_a", 20),
        "inner_skill:fixture_cap_b": _cap_definition("fixture_cap_b", 20),
        "inner_skill:fixture_cap_negative": _cap_definition(
            "fixture_cap_negative", -40),
        "item:fixture_cap_item": _cap_definition("fixture_cap_item", 20),
    }
    var catalog = FakeCatalog.new(definitions)
    var registry = PassiveRuleHandlerRegistryScript.new()
    var runtime = PassiveRuleRuntimeScript.new(registry, catalog)
    var query_service = BattleRuleQueryServiceScript.new(runtime)
    var player = BattleSideScript.new("测试玩家", "player")
    var enemy = BattleSideScript.new("测试敌人", "enemy")
    for side in [player, enemy]:
        side.use_passive_rule_runtime(runtime)
        side.use_battle_rule_query_service(query_service)
        side.initialize_base_momentum_cap(10)

    player.equipped_inner_skill_ids.assign(["fixture_cap_a"])
    var one: Dictionary = player.effective_momentum_cap_result({
        "round_number": 2, "action_token": "cap-action"})
    _assert_true(one.get("success", false), "一个合成来源上限查询成功")
    _assert_equal(one.get("effective_value"), 30, "一个合成来源令上限 +20")
    _assert_equal(one.get("source_breakdown", []).size(), 1,
        "一个来源公开一条稳定 breakdown")
    _assert_equal(
        one["source_breakdown"][0]["source_instance_key"],
        "inner:player:0:fixture_cap_a",
        "breakdown 公开稳定来源实例")

    player.equipped_inner_skill_ids.assign([
        "fixture_cap_a", "fixture_cap_b"])
    var two: Dictionary = player.effective_momentum_cap_result({
        "round_number": 2, "action_token": "cap-action"})
    _assert_equal(two.get("effective_value"), 50, "两个来源稳定合计 +40")
    _assert_equal(two.get("source_breakdown", []).size(), 2,
        "两个来源各自产生通用 Invocation")
    var repeated: Dictionary = player.effective_momentum_cap_result({
        "round_number": 2, "action_token": "cap-action"})
    _assert_equal(two.get("source_fingerprint"),
        repeated.get("source_fingerprint"), "相同来源顺序的指纹稳定")
    _assert_equal(two.get("request_fingerprint"),
        repeated.get("request_fingerprint"), "相同请求的指纹稳定")

    enemy.item_ids.assign(["fixture_cap_item"])
    _assert_equal(enemy.effective_momentum_cap_result().get("effective_value"),
        30, "敌人物品来源只修改敌人上限")
    _assert_equal(player.effective_momentum_cap_result().get("effective_value"),
        50, "玩家来源不受敌人物品影响")
    _assert_true(runtime.suppression_service.apply({
        "suppression_id": "fixture-cap-suppressed",
        "target_source_kind": "inner_skill",
        "target_instance_key": "inner:player:0:fixture_cap_a",
        "blocked_hooks": ["momentum_cap_query"],
        "reason": "合成压制",
    }).get("success", false), "合成来源可按统一压制协议暂停")
    _assert_equal(player.effective_momentum_cap_result().get("effective_value"),
        30, "压制一个来源后只保留另一个 +20")
    _assert_true(runtime.suppression_service.remove("fixture-cap-suppressed"),
        "解除合成来源压制成功")
    _assert_equal(player.effective_momentum_cap_result().get("effective_value"),
        50, "解除压制后上限贡献恢复")
    player.equipped_inner_skill_ids.assign(["fixture_cap_negative"])
    _assert_equal(player.effective_momentum_cap_result().get("effective_value"),
        0, "全部来源完成后有效上限统一限制为不小于0")


func _test_initialization_freeze_and_writes() -> void:
    var cards := [_card("2"), _card("3"), _card("4")]
    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(52001, false, cards)
    _assert_true(engine.player.momentum_cap_initialized,
        "普通战斗牌库装配后初始化基础上限")
    _assert_equal(engine.player.base_momentum_cap, 3,
        "自定义战斗使用最终三张牌库数量")
    var replacement := [
        _card("5"), _card("6"), _card("7"), _card("8"), _card("9")]
    engine.replace_player_deck(replacement, false)
    _assert_true(not engine.player.momentum_cap_initialized,
        "战斗开始前替换牌库使旧初始化失效")
    engine.start_player_turn()
    _assert_equal(engine.player.base_momentum_cap, 5,
        "battle_start 与正常抽牌前按最终替换牌库冻结上限")
    var frozen: int = engine.player.base_momentum_cap
    engine.player.draw(1)
    engine.player.discard_all()
    engine.player.add_generated_card(_card("10"), "draw_pile", true)
    _assert_equal(engine.player.base_momentum_cap, frozen,
        "抽牌、弃牌和临时生成不追溯修改基础上限")

    var side = engine.player
    side.momentum_value = 0
    var added: Dictionary = side.write_momentum(
        "add", 8, "fixture", "write-add", "fixture")
    _assert_equal(added.get("after"), 5, "add 统一截断到有效上限")
    _assert_equal(added.get("capped_amount"), 3, "add 回执记录截断数量")
    _assert_equal(added.get("base_momentum_cap"), 5,
        "写入回执公开基础上限")
    _assert_equal(added.get("effective_momentum_cap"), 5,
        "写入回执公开有效上限")
    var capped: Dictionary = side.write_momentum(
        "add", 4, "fixture", "write-capped", "fixture")
    _assert_true(capped.get("success", false), "已达上限继续 add 仍成功")
    _assert_equal(capped.get("after"), 5, "已达上限 add 后数值不变")
    _assert_equal(capped.get("delta"), 0, "无效增加 delta 为0")
    _assert_true(not capped.get("changed", true), "无效增加不算实际改变")
    _assert_equal(capped.get("capped_amount"), 4,
        "无效增加全部记录为 capped_amount")
    var set_result: Dictionary = side.write_momentum(
        "set", 12, "fixture", "write-set", "fixture")
    _assert_equal(set_result.get("after"), 5, "set 同样限制在有效上限")
    _assert_equal(set_result.get("capped_amount"), 7,
        "set 回执记录超限截断量")
    var insufficient: Dictionary = side.write_momentum(
        "consume", 6, "fixture", "write-consume-fail", "fixture")
    _assert_true(not insufficient.get("success", true), "consume 不足明确失败")
    _assert_equal(side.momentum_value, 5, "consume 不足不修改连势")
    var consumed: Dictionary = side.write_momentum(
        "consume", 3, "fixture", "write-consume", "fixture")
    _assert_equal(consumed.get("paid"), 3, "consume 成功保留 paid 语义")
    _assert_equal(side.momentum_value, 2, "consume 成功扣除请求值")
    _assert_true(side.write_momentum(
        "clear", 99, "fixture", "write-clear", "fixture").get(
            "success", false), "clear 仍通过统一入口成功")
    _assert_equal(side.momentum_value, 0, "clear 清为0")
    var unknown: Dictionary = side.write_momentum(
        "unknown", 3, "fixture", "write-unknown", "fixture")
    _assert_true(not unknown.get("success", true), "未知 operation 失败")
    _assert_equal(side.momentum_value, 0, "未知 operation 不修改状态")
    side.momentum_value = 2
    var cleanup: Dictionary = engine.status_system \
        .combat_source_lifecycle_service.clear_battle_sources(side)
    _assert_true(cleanup.get("success", false),
        "战斗结束清理也经过统一连势写入口")
    _assert_equal(side.momentum_value, 0, "战斗结束统一 clear 归零连势")
    _assert_equal(cleanup.get("momentum_receipt", {}).get("operation"),
        "clear", "战斗结束返回正式 clear 回执")


func _test_query_purity_failure_and_rollback() -> void:
    var side = BattleSideScript.new("纯查询方", "pure-side")
    side.initialize_base_momentum_cap(7)
    var before := side.capture_passive_query_state()
    var peek := side.peek_effective_momentum_cap_result({
        "source_kind": "ui", "action_token": "preview-token"})
    _assert_true(peek.get("success", false), "peek 上限查询成功")
    _assert_equal(side.capture_passive_query_state(), before,
        "peek 不覆盖正式查询回执或修改 BattleSide")

    side.momentum_value = 2
    var formal := side.effective_momentum_cap_result({
        "action_token": "formal-before"})
    var formal_receipt: Dictionary = \
        side.last_momentum_cap_query_result.duplicate(true)
    _assert_equal(formal.get("effective_value"), 7, "无来源时有效上限等于基础上限")
    var receipt := side.write_momentum(
        "add", 3, "fixture", "rollback-write", "fixture")
    _assert_equal(side.momentum_value, 5, "回滚前写入正常提交")
    _assert_true(side.rollback_momentum_receipt(receipt),
        "统一连势回执可以逆转最近写入")
    _assert_equal(side.momentum_value, 2, "回滚恢复原连势值")
    _assert_equal(side.last_momentum_cap_query_result, formal_receipt,
        "回滚恢复原正式上限查询回执且不重新查询")
    _assert_true(side.momentum_write_receipts[
        int(receipt["receipt_index"])].get("rolled_back", false),
        "存储回执标记 rolled_back")

    var transaction_state := side.capture_passive_query_state()
    side.base_momentum_cap = 99
    side.momentum_cap_initialized = false
    side.last_momentum_cap_query_result.clear()
    side.momentum_write_receipts.clear()
    side.replace_passive_query_state(transaction_state)
    _assert_equal(side.capture_passive_query_state(), transaction_state,
        "行动状态恢复基础上限、初始化标志、查询回执和写入回执")

    var failing = FailingMomentumCapQueryService.new()
    side.use_battle_rule_query_service(failing)
    side.momentum_value = 2
    var receipts_before: int = side.momentum_write_receipts.size()
    var failed := side.write_momentum(
        "add", 1, "fixture", "failed-write", "fixture")
    _assert_true(not failed.get("success", true), "上限查询失败使写入失败")
    _assert_equal(side.momentum_value, 2, "查询失败不修改连势")
    _assert_equal(side.momentum_write_receipts.size(), receipts_before + 1,
        "查询失败只留下明确失败回执，不伪造成功")
    _assert_true(not side.momentum_write_receipts[-1].get("success", true),
        "失败回执明确 success=false")
    _assert_equal(failing.report_count, 1, "查询失败经过正式 failure 报告边界")

    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(52003, false, [_card("2"), _card("3")])
    var flow_failure = FailingMomentumCapQueryService.new()
    engine.player.use_battle_rule_query_service(flow_failure)
    var effect_result: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_momentum", "operation": "add", "amount": 1,
    }], EffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "source_kind": "inner_skill",
        "source_id": "fixture_flow_failure",
        "action_token": "fixture-flow-failure",
        "captures": {},
    }))
    _assert_true(not effect_result.get("success", true),
        "FlowEffectHandler 传播连势上限查询失败")
    _assert_equal(engine.player.momentum_value, 0,
        "效果链失败不伪造连势成功写入")


func _test_snapshot_ai_ui_and_preview_projection() -> void:
    var engine = CombatEngineScript.new()
    tracked_engines.append(engine)
    engine.setup(52002, false)
    var expected_cap: int = engine.player.all_zone_cards().size()
    var session = BattleSessionScript.new(engine)
    var snapshot = session.snapshot()
    _assert_equal(snapshot.player.momentum_cap, expected_cap,
        "BattleSideSnapshot 公开有效连势上限")
    _assert_equal(snapshot.player.SCHEMA_VERSION, 12,
        "参战方快照升级连势上限 schema version")
    _assert_equal(snapshot.player.to_dict().get("momentum_cap"), expected_cap,
        "参战方序列化保留 momentum_cap")
    var ai := AiProjectorScript.new().project_self(
        engine.player, engine.sequence_book, engine.battle_flow)
    _assert_equal(ai.get("momentum_cap"), expected_cap,
        "AI 自身投影公开有效上限")
    var opponent := AiProjectorScript.new().project_opponent(
        engine.enemy, engine.enemy_sequence_book, engine.battle_flow)
    _assert_equal(opponent.get("momentum_cap"),
        engine.enemy.base_momentum_cap, "AI 对手投影公开有效上限")
    var ui: Dictionary = BattleUiMapperScript.map(snapshot)
    _assert_equal(ui["player"]["resources"].get("momentum_cap"), expected_cap,
        "BattleUiMapper 资源结构公开上限")
    _assert_true(ui["player"]["statuses"].any(func(entry):
        return str(entry.get("text", "")) == "连势 0/%d" % expected_cap),
        "UI 按当前值/有效上限显示连势")

    var preview_card = engine.player.draw_pile.pop_front()
    engine.player.hand.append(preview_card)
    var last_formal: Dictionary = \
        engine.player.last_momentum_cap_query_result.duplicate(true)
    var preview: Dictionary = engine.preview([str(preview_card.id)])
    _assert_true(preview.get("valid", false), "行动预览仍可建立")
    _assert_equal(preview.get("momentum_cap"), expected_cap,
        "行动预览投影公开有效连势上限")
    _assert_equal(engine.player.last_momentum_cap_query_result, last_formal,
        "行动预览使用 peek 且不覆盖正式查询回执")

    var failing = FailingMomentumCapQueryService.new()
    engine.player.use_battle_rule_query_service(failing)
    var failed_preview: Dictionary = engine.preview([str(preview_card.id)])
    _assert_true(not failed_preview.get("valid", true),
        "预览边界不在上限查询失败后伪造成功")


func _cap_definition(content_id: String, operand: int) -> Dictionary:
    return {
        "id": content_id,
        "name": content_id,
        "behaviors": [{
            "id": "battle_int_query_modifier",
            "configuration": {"rules": [{
                "hook": "momentum_cap_query",
                "operation": "add",
                "operand": operand,
            }]},
        }],
    }
