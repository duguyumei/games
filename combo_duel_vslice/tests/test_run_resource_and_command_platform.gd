extends "res://tests/support/expanded_technique_test_base.gd"

const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const MapGeneratorScript = preload("res://core/map_generator.gd")
const MapNavigationServiceScript = preload("res://core/map_navigation_service.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const RunSaveDataScript = preload("res://core/run_save_data.gd")
const GameCompositionRootScript = preload("res://core/game_composition_root.gd")
const RunAggregateTransactionScript = preload(
    "res://core/run_aggregate_transaction.gd")

const COMMAND_ITEM := "synthetic_map_regenerator"
const SECOND_COMMAND_ITEM := "synthetic_map_regenerator_second"
const QUERY_ITEM := "synthetic_run_resource_query"
const BLOCK_ITEM := "synthetic_experience_gain_block"
const REACTOR_A := "synthetic_experience_reactor_a"
const REACTOR_B := "synthetic_experience_reactor_b"


class SyntheticIntResult:
    extends RefCounted

    var values: Dictionary

    func _init(values_override: Dictionary) -> void:
        values = values_override.duplicate(true)

    func to_dict() -> Dictionary:
        return values.duplicate(true)


class SyntheticIntResolver:
    extends RefCounted

    var calls: Dictionary = {}
    var zero_meditation_cost: bool = false
    var fail_hook: String = ""

    func resolve(request) -> SyntheticIntResult:
        var hook := str(request.hook)
        calls[hook] = int(calls.get(hook, 0)) + 1
        if hook == fail_hook:
            return SyntheticIntResult.new({
                "success": false,
                "hook": hook,
                "subject_kind": request.subject_kind,
                "subject_id": request.subject_id,
                "base_value": request.base_value,
                "effective_value": request.base_value,
                "modifier_breakdown": [],
                "source_fingerprint": "synthetic-failed-%s" % hook,
                "errors": ["synthetic query failure"],
            })
        var value := int(request.base_value)
        var breakdown: Array = []
        var after := value
        if hook == "meditation_cost_query" and zero_meditation_cost:
            after = 0
            breakdown.append({"source_kind": "item", "content_id": "synthetic_zero_cost", "source_instance_key": "item:player:synthetic_zero_cost", "before": value, "after": after})
        return SyntheticIntResult.new({
            "success": true,
            "hook": hook,
            "subject_kind": request.subject_kind,
            "subject_id": request.subject_id,
            "base_value": value,
            "effective_value": after,
            "modifier_breakdown": breakdown,
            "source_fingerprint": "synthetic-%s-%d" % [hook, after],
            "errors": [],
        })


class CountingResolver:
    extends RefCounted

    var delegate
    var calls: Dictionary = {}

    func _init(delegate_override) -> void:
        delegate = delegate_override

    func resolve(request):
        var hook := str(request.hook)
        calls[hook] = int(calls.get(hook, 0)) + 1
        return delegate.resolve(request)


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_experience_fact_and_idempotency()
    _test_battle_experience_fact_boundary()
    _test_free_meditation_and_paid_zero_cost()
    _test_capacity_query_and_overflow_migration()
    _test_interest_cap_single_query_and_rollback()
    _test_deterministic_map_generation_and_regeneration()
    _test_run_command_atomicity_receipt_and_save()
    _finish("RUN RESOURCE AND COMMAND PLATFORM TEST")


func _catalog():
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(), "Run 资源平台测试目录加载成功")
    return catalog


func _growth(catalog):
    return GrowthInventoryScript.new(catalog, false)


func _test_experience_fact_and_idempotency() -> void:
    var root = _resource_root()
    var growth = _growth(root.content_catalog)
    growth.item_ids.assign([BLOCK_ITEM])
    growth.use_int_policy_resolver(root.passive_int_policy_resolver)
    var mutation = root.run_mutation_service
    var prevented: Dictionary = mutation.change_experience_in_place(
        growth, 8, {"transaction_token": "experience-probe", "operation_token": "experience-probe:1", "source_kind": "item", "source_id": "synthetic_gate"})
    _assert_true(prevented.get("success", false), "历练获得阻止仍提交 resolved 事实")
    _assert_equal(growth.experience, 0, "被阻止的历练不改变余额")
    _assert_equal(prevented.get("actual_delta"), 0, "历练事实公开 actual_delta=0")
    _assert_equal(prevented.get("prevented_amount"), 8, "历练事实公开 prevented_amount")
    _assert_equal(prevented.get("committed_events", []).size(), 1, "历练操作只产生一条 canonical 事实")
    var duplicate: Dictionary = mutation.change_experience_in_place(
        growth, 8, {"transaction_token": "experience-probe", "operation_token": "experience-probe:1"})
    _assert_true(duplicate.get("duplicate", false), "相同 operation token 的历练修改幂等")
    _assert_equal(duplicate.get("committed_events", []).size(), 0, "幂等历练重放不重复发布事实")
    var spent: Dictionary = mutation.change_experience_in_place(
        growth, -1, {"transaction_token": "experience-probe", "operation_token": "experience-probe:spend"})
    _assert_true(not spent.get("success", true), "历练不足明确失败且不产生负余额")
    _assert_equal(growth.experience, 0, "历练失败保持余额")
    var recursive_growth = _growth(root.content_catalog)
    recursive_growth.item_ids.assign([REACTOR_A, REACTOR_B])
    recursive_growth.use_int_policy_resolver(root.passive_int_policy_resolver)
    var recursive: Dictionary = mutation.change_experience_in_place(
        recursive_growth, 1, {
            "transaction_token": "experience-recursion",
            "operation_token": "experience-recursion:root",
            "source_kind": "rule",
            "source_id": "recursion_probe",
        })
    _assert_true(recursive.get("success", false), "canonical 历练写入口派发响应链")
    _assert_equal(recursive_growth.experience, 5, "每个响应来源禁入自身后代，但另一个来源在各独立分支仍可响应")
    _assert_equal(recursive.get("committed_events", []).size(), 5, "根事实和四条有界后代事实各发布一次且没有无限递归")


func _test_battle_experience_fact_boundary() -> void:
    var engine = _engine(72001)
    var events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "experience_change_resolved":
                events.append(values.duplicate(true)))
    var first: Dictionary = engine.effect_ports.gain_battle_experience(
        engine.player, 3, {"action_token": "battle-experience-probe", "source_kind": "technique", "source_id": "probe"})
    _assert_true(first.get("success", false), "Battle 历练使用统一写入口")
    _assert_equal(first.get("actual_delta"), 3, "Battle 历练实际变化正确")
    _assert_equal(events.size(), 1, "Battle 历练只发布一条 resolved 事实")
    var duplicate: Dictionary = engine.effect_ports.gain_battle_experience(
        engine.player, 3, {"action_token": "battle-experience-probe", "source_kind": "technique", "source_id": "probe", "operation_token": first.get("operation_token", "")})
    _assert_true(duplicate.get("duplicate", false), "Battle 历练重复 token 幂等")
    _assert_equal(events.size(), 1, "Battle 历练幂等重放不重复发布事实")


func _test_free_meditation_and_paid_zero_cost() -> void:
    var catalog = _catalog()
    var mutation = RunMutationServiceScript.new(null, catalog)
    var practice := PracticeServiceScript.new(catalog, mutation)
    var growth = _growth(catalog)
    growth.experience = 50
    _assert_true(practice.start_new_shop(growth, 72002, 1, 1).get("success", true), "冥想测试建立修习商店")
    _assert_true(mutation.apply_effects([{"op": "grant_free_meditation_charge"}], growth).get("success", false), "合成效果发放免费冥想机会")
    _assert_true(mutation.apply_effects([{"op": "grant_free_meditation_charge"}], growth).get("success", false), "重复发放免费冥想机会安全成功")
    _assert_equal(growth.free_meditation_charge, 1, "免费冥想机会不可叠加")
    var before_shop: Dictionary = growth.practice_shop_snapshot()
    var free_result: Dictionary = practice.meditate(growth, 72002, 1, true)
    _assert_true(free_result.get("success", false), "免费冥想成功")
    _assert_equal(free_result.get("effective_cost"), 0, "免费冥想实际费用为零")
    _assert_equal(growth.experience, 50, "免费冥想不扣历练")
    _assert_equal(growth.free_meditation_charge, 0, "免费冥想成功消费机会")
    _assert_equal(growth.practice_shop_state.get("meditation_count"), before_shop.get("meditation_count", 0), "免费冥想不增加付费次数")
    _assert_equal(growth.practice_shop_state.get("next_meditation_cost"), before_shop.get("next_meditation_cost", 5), "免费冥想不增加下一次基础费用")
    _assert_equal(growth.practice_shop_state.get("meditation_operation_sequence"), int(before_shop.get("meditation_operation_sequence", 0)) + 1, "免费冥想推进总操作序号")
    var paid_growth = _growth(catalog)
    paid_growth.experience = 0
    practice.start_new_shop(paid_growth, 72003, 1, 1)
    var zero_resolver := SyntheticIntResolver.new()
    zero_resolver.zero_meditation_cost = true
    paid_growth.use_int_policy_resolver(zero_resolver)
    practice.use_passive_services(zero_resolver)
    var paid_zero: Dictionary = practice.meditate(paid_growth, 72003, 1, true)
    _assert_true(paid_zero.get("success", false), "价格修正为零的普通冥想成功")
    _assert_equal(paid_growth.practice_shop_state.get("meditation_count"), 1, "零元普通冥想仍增加付费次数")
    _assert_equal(paid_growth.practice_shop_state.get("next_meditation_cost"), 6, "零元普通冥想仍增加下一次基础费用")
    var failed_growth = _growth(catalog)
    failed_growth.experience = 0
    failed_growth.free_meditation_charge = 1
    practice.start_new_shop(failed_growth, 72004, 1, 1)
    var fail_resolver := SyntheticIntResolver.new()
    fail_resolver.fail_hook = "practice_offer_weight_query"
    failed_growth.use_int_policy_resolver(fail_resolver)
    practice.use_passive_services(fail_resolver)
    var before_failure: Dictionary = failed_growth.capture_mutation_state()
    var failed: Dictionary = practice.meditate(failed_growth, 72004, 1, true)
    _assert_true(not failed.get("success", true), "冥想查询失败明确返回失败")
    _assert_equal(failed_growth.capture_mutation_state(), before_failure, "冥想失败恢复机会、商店、序号和资源")


func _test_capacity_query_and_overflow_migration() -> void:
    var root = _resource_root()
    var catalog = root.content_catalog
    var growth = _growth(catalog)
    growth.consumable_ids.assign(["a", "b"])
    var base: Dictionary = growth.effective_consumable_capacity_result()
    _assert_equal(base.get("base_capacity"), 2, "消耗品基础容量统一为2")
    _assert_equal(base.get("effective_capacity"), 2, "无来源时有效容量为2")
    growth.item_ids.assign([QUERY_ITEM])
    growth.use_int_policy_resolver(root.passive_int_policy_resolver)
    var expanded: Dictionary = growth.effective_consumable_capacity_result({"metadata": {"probe": "shared-query"}})
    _assert_equal(expanded.get("effective_capacity"), 4, "合成来源将有效容量提高至4")
    _assert_equal(expanded.get("available_slots"), 2, "容量查询同时公开可用槽位")
    _assert_equal(expanded.get("modifier_breakdown", [])[0].get("source_instance_key"), "item:player:%s" % QUERY_ITEM, "容量 breakdown 公开稳定来源实例")
    _assert_true(root.passive_rule_runtime.suppression_service.apply({"suppression_id": "capacity-probe-suppression", "target_source_kind": "item", "target_content_id": QUERY_ITEM, "blocked_hooks": ["consumable_capacity_query"], "reason": "synthetic"}).get("success", false), "容量来源可以被统一被动压制")
    _assert_equal(growth.effective_consumable_capacity_result().get("effective_capacity"), 2, "来源压制时容量修正暂停")
    _assert_true(root.passive_rule_runtime.suppression_service.remove("capacity-probe-suppression"), "解除容量来源压制")
    _assert_equal(growth.effective_consumable_capacity_result().get("effective_capacity"), 4, "解除压制后容量修正恢复")
    growth.consumable_ids.assign(["a", "b", "c", "d", "e"])
    var overflow: Dictionary = growth.effective_consumable_capacity_result()
    _assert_equal(overflow.get("overflow_count"), 1, "容量下降时保留已有消耗品并记录 overflow")
    var overflow_grant: Dictionary = RunMutationServiceScript.new(
        null, catalog).apply_effects([{
            "op": "grant_consumables", "consumable_ids": ["zengyuan_pill"],
        }], growth)
    _assert_true(not overflow_grant.get("success", true), "超容量库存禁止继续获得消耗品")
    var legacy_growth = _growth(catalog)
    var old_save_values := {
        "schema_version": RunSaveDataScript.SCHEMA_VERSION,
        "content_version": RunSaveDataScript.CONTENT_VERSION,
        "run": {"seed": 72005, "starter_build_id": ""},
        "map_state": {"act": 1, "generation_serial": 0, "graph": MapGeneratorScript.new().generate(72005, 1, 0)},
        "node_state": {"phase": "awaiting_node", "current_node_id": "", "completed_node_ids": [], "pending_reward": {}, "pending_node_interaction": {}, "terminal_result": {}, "resume_policy": "resume_boundary", "practice_is_open": false, "practice_open_sequence": 0, "committed_passive_event_tokens": [], "run_command_receipts": {}},
        "growth": {"experience": 0, "consumable_ids": ["zengyuan_pill", "suyi_pill", "jiyuan_pill"], "item_ids": [], "consumable_capacity": 3, "life": 100, "max_life": 100, "base_max_life": 100, "run_deck": legacy_growth.run_deck.to_snapshot(), "practice_shop_state": {}, "learned_technique_ids": [], "learned_inner_skill_ids": [], "equipped_inner_skill_ids": [], "technique_slot_index": 0, "forgotten_inner_skill_count": 0, "source_marker_state": {"schema_version": 1, "entries": []}, "hand_technique_progression": legacy_growth.hand_technique_progression.duplicate(true), "practice_purchase_ids": [], "passive_counter_state": {"version": 1, "entries": []}, "run_combat_history_state": {"schema_version": 1, "successful_technique_ids": [], "successful_hand_counts": {"high_card": 0, "pair": 0, "two_pair": 0, "three_kind": 0, "straight": 0, "full_house": 0, "four_kind": 0, "five_kind": 0}}},
    }
    var old_save = RunSaveDataScript.new(old_save_values)
    var old_errors: Array[String] = old_save.validate(catalog)
    _assert_true(old_errors.is_empty(), "旧容量3存档结构可迁移")
    _assert_equal(old_save.to_dict()["growth"]["consumable_ids"].size(), 3, "旧容量存档迁移不丢弃库存")


func _test_interest_cap_single_query_and_rollback() -> void:
    var root = _resource_root()
    var catalog = root.content_catalog
    var resolver := CountingResolver.new(root.passive_int_policy_resolver)
    var growth = _growth(catalog)
    growth.experience = 100
    growth.item_ids.assign([QUERY_ITEM])
    growth.use_int_policy_resolver(resolver)
    var mutation = root.run_mutation_service
    var settlement: Dictionary = mutation.settle_experience_interest_in_place(
        growth, {"settlement_token": "interest-probe", "transaction_token": "interest-probe"})
    _assert_true(settlement.get("success", false), "功行生息使用统一结算入口")
    _assert_equal(settlement.get("effective_cap"), 20, "合成来源将功行生息上限提高至20")
    _assert_equal(settlement.get("actual_amount"), 20, "功行生息按冻结上限结算20")
    _assert_equal(resolver.calls.get("experience_interest_cap_query"), 1, "同一结算只查询一次上限")
    var duplicate: Dictionary = mutation.settle_experience_interest_in_place(
        growth, {"settlement_token": "interest-probe", "transaction_token": "interest-probe"})
    _assert_true(duplicate.get("success", false), "重复 settlement token 可安全重放")
    _assert_equal(growth.experience, 120, "重复结算不会再次增加历练")
    _assert_equal(resolver.calls.get("experience_interest_cap_query"), 1, "重复结算复用回执且不重新查询上限")


func _resource_root():
    var root := GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(root.initialize(), "合成 Run 资源来源组合根加载成功")
    root.content_catalog._indexes["item"][QUERY_ITEM] = {
        "id": QUERY_ITEM,
        "name": "合成 Run 资源查询",
        "kind": "item",
        "status": "formal",
        "unique": true,
        "price": 0,
        "description": "只用于底层专项",
        "marker_definitions": [],
        "behaviors": [{
            "id": "run_int_query_modifier",
            "configuration": {"rules": [
                {"hook": "consumable_capacity_query", "operation": "add", "operand": 2, "filters": {}},
                {"hook": "experience_interest_cap_query", "operation": "maximum", "operand": 20, "filters": {}},
            ]},
        }],
    }
    root.content_catalog._indexes["item"][BLOCK_ITEM] = {
        "id": BLOCK_ITEM,
        "name": "合成历练获得阻止",
        "kind": "item",
        "status": "formal",
        "unique": true,
        "price": 0,
        "description": "只用于底层专项",
        "marker_definitions": [],
        "behaviors": [{
            "id": "run_int_query_modifier",
            "configuration": {"rules": [{
                "hook": "experience_gain_query",
                "operation": "multiply",
                "operand": 0,
                "filters": {},
            }]},
        }],
    }
    for reactor_id in [REACTOR_A, REACTOR_B]:
        root.content_catalog._indexes["item"][reactor_id] = {
            "id": reactor_id,
            "name": reactor_id,
            "kind": "item",
            "status": "formal",
            "unique": true,
            "price": 0,
            "description": "只用于历练递归门禁专项",
            "marker_definitions": [],
            "behaviors": [{
                "id": "run_fact_effects",
                "configuration": {"rules": [{
                    "hook": "experience_change_resolved",
                    "filters": {"scope": "run"},
                    "effects": [{"op": "gain_experience", "amount": 1}],
                }]},
            }],
        }
    return root


func _test_deterministic_map_generation_and_regeneration() -> void:
    var generator := MapGeneratorScript.new()
    var first: Dictionary = generator.generate(72006, 1, 0)
    var same: Dictionary = generator.generate(72006, 1, 0)
    var next: Dictionary = generator.generate(72006, 1, 1)
    _assert_equal(first, same, "相同 seed、act、generation_serial 地图完全一致")
    _assert_true(first != next, "generation_serial 变化产生新的当前层地图")
    var navigation := MapNavigationServiceScript.new(generator)
    navigation.setup(72006)
    navigation.current_node_id = ""
    navigation.phase = "awaiting_node"
    navigation.completed_node_ids["old"] = true
    var old_graph: Dictionary = navigation.graph.duplicate(true)
    var regenerated: Dictionary = navigation.regenerate_current_act_map()
    _assert_true(regenerated.get("success", false), "当前层地图重建成功")
    _assert_equal(navigation.generation_serial, 1, "地图重建递增 generation_serial")
    _assert_equal(navigation.current_node_id, "", "地图重建清空旧 current_node_id")
    _assert_true(navigation.completed_node_ids.is_empty(), "地图重建废弃旧完成节点集合")
    _assert_equal(navigation.act, 1, "地图重建保持当前 act")
    _assert_true(navigation.graph != old_graph, "地图重建废弃旧 graph")


func _test_run_command_atomicity_receipt_and_save() -> void:
    var root := GameCompositionRootScript.new(RuntimeProfileScript.test())
    _assert_true(root.initialize(), "Run command 测试组合根加载成功")
    var definition := {
        "id": COMMAND_ITEM,
        "name": "合成地图重建物品",
        "kind": "item",
        "status": "formal",
        "unique": true,
        "description": "测试 Run command",
        "behaviors": [],
        "marker_definitions": [],
        "on_acquire_run_commands": [{"command": "regenerate_current_act_map"}],
        "price": 0,
    }
    root.content_catalog._indexes["item"][COMMAND_ITEM] = definition.duplicate(true)
    var second_definition: Dictionary = definition.duplicate(true)
    second_definition["id"] = SECOND_COMMAND_ITEM
    root.content_catalog._indexes["item"][SECOND_COMMAND_ITEM] = second_definition
    var session = root.create_run_session()
    _assert_true(session.execute({"type": "setup_run", "seed": 72007}).success, "Run command 测试建立本局")
    var aggregate := RunAggregateTransactionScript.new()
    _assert_true(aggregate.begin(session).get("success", false), "Run command 成功路径开始聚合事务")
    var granted: Dictionary = root.run_mutation_service.apply_effects(
        [{"op": "grant_items", "item_ids": [COMMAND_ITEM]}], session.growth,
        {"transaction_token": "command-success"})
    _assert_true(granted.get("success", false), "获得物品并产生类型化 command request")
    var command_result: Dictionary = session._execute_run_command_requests(
        session._collect_command_requests(granted))
    _assert_true(command_result.get("success", false), "RunSession 执行白名单地图重建 command")
    _assert_equal(session.navigation.generation_serial, 1, "成功 command 只重建一次地图")
    _assert_true(aggregate.commit().get("success", false), "物品与地图在同一聚合事务提交")
    var receipt_token := str(command_result.get("results", [])[0].get("request_token", ""))
    var repeated: Dictionary = session._execute_run_command_requests(
        session._collect_command_requests(granted))
    _assert_true(repeated.get("success", false), "重复 command request 可重放")
    _assert_equal(session.navigation.generation_serial, 1, "重复 command 不再次增加 generation_serial")
    _assert_true(session._run_state.run_command_receipts.has(receipt_token), "command receipt 进入 Run 状态")
    var failure_aggregate := RunAggregateTransactionScript.new()
    _assert_true(failure_aggregate.begin(session).get("success", false), "Run command 失败路径开始聚合事务")
    var old_graph: Dictionary = session.navigation.graph.duplicate(true)
    session.navigation.phase = "node_in_progress"
    var failed_grant: Dictionary = root.run_mutation_service.apply_effects(
        [{"op": "grant_items", "item_ids": [SECOND_COMMAND_ITEM]}], session.growth,
        {"transaction_token": "command-failure"})
    var failed_command := session._execute_run_command_requests(
        session._collect_command_requests(failed_grant))
    _assert_true(not failed_command.get("success", true), "不合法阶段拒绝地图 command")
    _assert_true(failure_aggregate.rollback().get("success", false), "command 失败回滚聚合事务")
    _assert_true(not session.growth.item_ids.has(SECOND_COMMAND_ITEM), "command 失败不留下物品")
    _assert_equal(session.navigation.graph, old_graph, "command 失败恢复旧地图")
    session.navigation.phase = "awaiting_node"
    var save = RunSaveDataScript.new().capture(session)
    _assert_true(save.validate(root.content_catalog).is_empty(), "包含 generation_serial 和 command receipt 的存档通过校验")
    var restored: Dictionary = save.restore_session(root.content_catalog, Callable(root, "create_run_session"))
    _assert_true(restored.get("success", false), "Run command 存档往返成功")
    if restored.get("success", false):
        _assert_equal(restored["run_session"].navigation.generation_serial, session.navigation.generation_serial, "存档恢复 generation_serial")
        _assert_equal(restored["run_session"]._run_state.run_command_receipts, session._run_state.run_command_receipts, "存档恢复 command receipt")
