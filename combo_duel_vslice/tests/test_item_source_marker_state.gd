extends "res://tests/support/expanded_technique_test_base.gd"

const BattleEffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const ContentValidatorScript = preload("res://core/content_validator.gd")
const EffectValueResolverScript = preload(
    "res://core/effects/effect_value_resolver.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const SourceMarkerAddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")

const LIFE_ITEM := "item_marker_life_probe"
const RETAIN_ITEM := "item_marker_retain_probe"
const PRIVATE_ITEM := "item_marker_private_probe"
const ORDER_A := "item_marker_order_a"
const ORDER_B := "item_marker_order_b"
const BROKEN_ITEM := "item_marker_broken_probe"


func _initialize() -> void:
    if not _require_test_mode():
        return
    _test_content_contract_and_store_roundtrip()
    _test_stable_item_addresses_and_source_isolation()
    _test_run_grant_remove_and_max_life_transactions()
    _test_battle_marker_events_and_authorization()
    _test_battle_setup_sync_save_restore_and_rollback()
    _test_public_projection_preview_and_suppression()
    _finish("ITEM SOURCE MARKER STATE TEST")


func _test_content_contract_and_store_roundtrip() -> void:
    _assert_true("item" in SourceMarkerStoreScript.SOURCE_KINDS,
        "SourceMarkerStore 正式登记 item source_kind")
    var valid_item := {
        "version": 2,
        "items": [{
            "id": "valid_item_marker_probe",
            "name": "合法物品标识探针",
            "kind": "item",
            "status": "candidate",
            "unique": true,
            "description": "测试物品来源标识内容校验。",
            "marker_definitions": [{
                "id": "life_bonus",
                "scope": "run",
                "public": true,
                "display_name": "命元",
                "contributes_to": "max_life",
                "forget_policy": "clear",
                "initial_value": 20,
            }],
            "behaviors": [{
                "id": "battle_effects",
                "configuration": {
                    "hook": "action_resolve",
                    "effects": [{
                        "op": "write_source_marker",
                        "operation": "add",
                        "marker_id": "life_bonus",
                        "scope": "run",
                        "contributes_to": "max_life",
                        "amount": 1,
                    }],
                },
            }],
        }],
    }
    _assert_item_validation(valid_item, true,
        "物品可以声明并经 battle_effects 写入自己的 run marker")
    var invalid_marker := valid_item.duplicate(true)
    invalid_marker["items"][0]["marker_definitions"][0]["id"] = "Bad-Marker"
    _assert_item_validation(invalid_marker, false, "marker_id 必须是 snake_case")
    var invalid_scope := valid_item.duplicate(true)
    invalid_scope["items"][0]["marker_definitions"][0]["scope"] = "save"
    _assert_item_validation(invalid_scope, false, "marker scope 只允许 battle/run")
    var invalid_forget := valid_item.duplicate(true)
    invalid_forget["items"][0]["marker_definitions"][0]["forget_policy"] = "keep"
    _assert_item_validation(invalid_forget, false, "forget_policy 只允许 clear/retain")
    var invalid_stat := valid_item.duplicate(true)
    invalid_stat["items"][0]["marker_definitions"][0]["contributes_to"] = "unknown_stat"
    _assert_item_validation(invalid_stat, false, "contributes_to 拒绝未注册统计项")
    var invalid_initial := valid_item.duplicate(true)
    invalid_initial["items"][0]["marker_definitions"][0]["scope"] = "battle"
    _assert_item_validation(invalid_initial, false, "获得时初始值只能写 run marker")
    var disguised := valid_item.duplicate(true)
    disguised["items"][0]["behaviors"][0]["configuration"]["effects"][0][
        "source_kind"] = "technique"
    _assert_item_validation(disguised, false, "物品内容不能伪装 source_kind")

    var store = SourceMarkerStoreScript.new()
    _assert_true(store.write(
        "item", "item:player:snapshot_probe", "snapshot_probe",
        "run_charge", "run", "set", 4, {
            "public": true, "forget_policy": "clear",
        }).get("success", false), "item run marker 可写入")
    _assert_true(store.write(
        "item", "item:player:snapshot_probe", "snapshot_probe",
        "battle_charge", "battle", "set", 2).get("success", false),
        "item battle marker 可写入")
    var restored = SourceMarkerStoreScript.new()
    _assert_true(restored.restore_snapshot(store.snapshot()).is_empty(),
        "item battle/run marker 完整快照往返")
    _assert_equal(restored.value(
        "item", "item:player:snapshot_probe", "run_charge", "run"), 4,
        "恢复后读取同一 item run marker")
    restored.clear_scope("battle")
    _assert_equal(restored.value(
        "item", "item:player:snapshot_probe", "battle_charge", "battle"), 0,
        "既有 clear_scope 清理 item battle marker")
    _assert_equal(restored.value(
        "item", "item:player:snapshot_probe", "run_charge", "run"), 4,
        "battle 清理不污染 item run marker")


func _test_stable_item_addresses_and_source_isolation() -> void:
    var engine = _engine(20001)
    _install_item_fixtures(engine.content_catalog)
    _assert_true(engine.player.configure_items([ORDER_A, ORDER_B]).get(
        "success", false), "两个唯一物品装配成功")
    var first_snapshot: Array = engine.passive_rule_runtime.capture_source_snapshot({
        "owner": engine.player})
    var first_keys: Dictionary = _item_source_keys(first_snapshot)
    _assert_true(engine.player.configure_items([ORDER_B, ORDER_A]).get(
        "success", false), "库存顺序可重排")
    var reordered_keys: Dictionary = _item_source_keys(
        engine.passive_rule_runtime.capture_source_snapshot({
            "owner": engine.player}))
    _assert_equal(reordered_keys, first_keys,
        "item_ids 顺序变化不改变物品来源地址")
    _assert_true(engine.player.configure_items([ORDER_B]).get("success", false),
        "移除前一个物品成功")
    var after_remove: Dictionary = _item_source_keys(
        engine.passive_rule_runtime.capture_source_snapshot({
            "owner": engine.player}))
    _assert_equal(after_remove[ORDER_B], first_keys[ORDER_B],
        "移除前一个物品不改变后一个物品地址")
    _assert_true(not engine.player.configure_items([ORDER_B, ORDER_B]).get(
        "success", true), "同一持有者仍拒绝重复 item_id")

    var catalog = _catalog()
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.item_ids.assign([ORDER_B])
    var resolver = SourceMarkerAddressResolverScript.new()
    _assert_equal(
        resolver.item_source_instance_key(growth, ORDER_B),
        resolver.item_source_instance_key(engine.player, ORDER_B),
        "GrowthInventory 与玩家 BattleSide 使用同一稳定 owner 地址")
    _assert_equal(first_keys[ORDER_A], "item:player:%s" % ORDER_A,
        "最终 item 地址只由 source_kind、稳定 owner 与 content_id 构成")

    var store = SourceMarkerStoreScript.new()
    for source in [
            ["item", "item:player:shared", "shared"],
            ["inner_skill", "inner:player:0:shared", "shared"],
            ["technique", "technique:shared", "shared"]]:
        _assert_true(store.write(
            source[0], source[1], source[2], "same_marker", "run",
            "set", 3).get("success", false),
            "%s 执行相同 marker op" % source[0])
    _assert_equal(store.entries({"marker_id": "same_marker"}).size(), 3,
        "item/inner_skill/technique 同名 marker_id 互不冲突")


func _test_run_grant_remove_and_max_life_transactions() -> void:
    var catalog = _catalog()
    var mutation = RunMutationServiceScript.new(null, catalog)
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.base_max_life = 100
    growth.max_life = 100
    growth.life = 50
    var granted: Dictionary = mutation.apply_effects([{
        "op": "grant_items", "item_ids": [LIFE_ITEM],
    }], growth)
    _assert_true(granted.get("success", false),
        "RunMutationService 原子获得物品：%s" % str(granted))
    _assert_equal(growth.item_ids, [LIFE_ITEM], "item_id 在初始 marker 前正式写入工作副本")
    _assert_equal(growth.max_life, 120, "物品 max_life marker 获得后立即贡献")
    _assert_equal(growth.life, 50, "最大生命增加不恢复当前生命")
    _assert_equal(growth.base_max_life, 100, "来源贡献不反写 base_max_life")
    _assert_equal(granted.get("committed_events", []).size(), 1,
        "事务成功后只公开一条 canonical marker 事实")
    _assert_equal(granted["committed_events"][0]["event_type"],
        "source_marker_changed", "Run marker 变化沿用 source_marker_changed")
    var address: Dictionary = SourceMarkerAddressResolverScript.new().resolve_item(
        growth, LIFE_ITEM, _item_definition(LIFE_ITEM)["marker_definitions"][0])
    _assert_equal(address["source_instance_key"], "item:player:%s" % LIFE_ITEM,
        "获得物品使用权威 item 来源地址")

    growth.source_marker_store.write(
        "item", address["source_instance_key"], LIFE_ITEM,
        "life_bonus", "run", "set", 31, address)
    growth.recalculate_effective_max_life()
    growth.life = 125
    var removed: Dictionary = mutation.apply_effects([{
        "op": "remove_items", "item_ids": [LIFE_ITEM],
    }], growth)
    _assert_true(removed.get("success", false), "物品移除使用同一 Run 事务")
    _assert_equal(growth.max_life, 100, "clear marker 移除后最大生命立即下降")
    _assert_equal(growth.life, 100, "最大生命下降立即截断当前生命")
    _assert_equal(growth.base_max_life, 100, "移除来源仍不修改 base_max_life")
    _assert_true(growth.source_marker_store.entries({
        "source_kind": "item", "content_id": LIFE_ITEM}).is_empty(),
        "clear 遗失策略删除该物品 run marker")
    _assert_true(mutation.apply_effects([{
        "op": "grant_items", "item_ids": [LIFE_ITEM],
    }], growth).get("success", false), "clear 物品可以重新获得")
    _assert_equal(growth.source_marker_store.value(
        "item", address["source_instance_key"], "life_bonus", "run"), 20,
        "重新获得不会恢复 clear 前的旧 marker 值")

    var retained = GrowthInventoryScript.new(catalog, false)
    _assert_true(mutation.apply_effects([{
        "op": "grant_items", "item_ids": [RETAIN_ITEM],
    }], retained).get("success", false), "retain 测试物品获得成功")
    var retained_address: Dictionary = SourceMarkerAddressResolverScript.new().resolve_item(
        retained, RETAIN_ITEM,
        _item_definition(RETAIN_ITEM)["marker_definitions"][0])
    retained.source_marker_store.write(
        "item", retained_address["source_instance_key"], RETAIN_ITEM,
        "life_bonus", "run", "set", 9, retained_address)
    retained.recalculate_effective_max_life()
    _assert_equal(retained.max_life, 109, "retain marker 持有时贡献最大生命")
    _assert_true(mutation.apply_effects([{
        "op": "remove_items", "item_ids": [RETAIN_ITEM],
    }], retained).get("success", false), "retain 物品移除成功")
    _assert_equal(retained.max_life, 100,
        "retain 数据在失去物品后不再贡献最大生命")
    _assert_equal(retained.source_marker_store.value(
        "item", retained_address["source_instance_key"],
        "life_bonus", "run"), 9, "retain 遗失策略保留 marker 数据")
    _assert_true(mutation.apply_effects([{
        "op": "grant_items", "item_ids": [RETAIN_ITEM],
    }], retained).get("success", false), "retain 物品重新获得成功")
    _assert_equal(retained.max_life, 109,
        "重新获得 retain 物品后使用原 marker 恢复贡献")

    var failure_growth = GrowthInventoryScript.new(catalog, false)
    failure_growth.life = 73
    var before: Dictionary = failure_growth.capture_mutation_state()
    var failed: Dictionary = mutation.apply_effects([{
        "op": "grant_items", "item_ids": [LIFE_ITEM],
    }, {
        "op": "grant_items", "item_ids": [BROKEN_ITEM],
    }], failure_growth)
    _assert_true(not failed.get("success", true), "后续 marker 失败令整批事务失败")
    _assert_equal(failure_growth.capture_mutation_state(), before,
        "事务失败恢复物品、marker、生命与 Run 持久快照")
    _assert_true(failed.get("committed_events", []).is_empty(),
        "失败事务不发布已回滚 source_marker_changed")


func _test_battle_marker_events_and_authorization() -> void:
    var engine = _engine(20002)
    _install_item_fixtures(engine.content_catalog)
    _assert_true(engine.player.configure_items([LIFE_ITEM]).get("success", false),
        "战斗物品来源装配成功")
    var events: Array = []
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, values: Dictionary, _receipt: Dictionary):
            if kind == "source_marker_changed":
                events.append(values.duplicate(true)))
    var context = _item_context(engine, LIFE_ITEM)
    var run_written: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_source_marker",
        "operation": "set",
        "marker_id": "life_bonus",
        "scope": "run",
        "contributes_to": "max_life",
        "amount": 25,
    }], context)
    _assert_true(run_written.get("success", false),
        "item 经统一 EffectExecutor 写自己的 run marker")
    _assert_equal(engine.player.max_life, 125,
        "战斗中 item run marker 复用最大生命重算入口")
    _assert_equal(events.size(), 1, "item marker 变化提交 source_marker_changed")
    _assert_equal(events[0]["source_instance_key"],
        "item:player:%s" % LIFE_ITEM, "事件公开稳定物品来源地址")
    var battle_written: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_source_marker",
        "operation": "set",
        "marker_id": "battle_charge",
        "scope": "battle",
        "amount": 3,
    }], context)
    _assert_true(battle_written.get("success", false),
        "item battle marker 走同一写入与事件协议")
    _assert_equal(engine.player.source_marker_store.value(
        "item", "item:player:%s" % LIFE_ITEM,
        "battle_charge", "battle"), 3, "item battle marker 可读取")
    _assert_equal(EffectValueResolverScript.new().resolve({
        "kind": "equipped_source_marker_sum",
        "marker_id": "battle_charge",
        "scope": "battle",
        "filters": {"source_kind": "item"},
    }, context), 3, "ValueSpec 按活跃 item 来源读取统一 marker 状态")
    _assert_true(engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "clear",
        "marker_id": "battle_charge", "scope": "battle", "amount": 0,
    }], context).get("success", false), "item battle marker 使用通用 clear")

    engine.player.configure_items([])
    var non_owned: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "set",
        "marker_id": "life_bonus", "scope": "run", "amount": 99,
    }], context)
    _assert_true(not non_owned.get("success", true),
        "非持有 item 来源不能写 marker")
    engine.player.configure_items([LIFE_ITEM])
    var forged: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "set",
        "source_kind": "technique", "marker_id": "life_bonus",
        "scope": "run", "amount": 99,
    }], _item_context(engine, LIFE_ITEM))
    _assert_true(not forged.get("success", true),
        "item runtime 拒绝伪装为 technique 来源")
    var forged_key_context = _item_context(engine, LIFE_ITEM)
    forged_key_context.source_instance_key = "item:player:forged"
    var forged_key: Dictionary = engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "set",
        "marker_id": "life_bonus", "scope": "run", "amount": 99,
    }], forged_key_context)
    _assert_true(not forged_key.get("success", true),
        "伪造 item source_instance_key 被权威地址解析拒绝")


func _test_battle_setup_sync_save_restore_and_rollback() -> void:
    var catalog = _catalog()
    var mutation = RunMutationServiceScript.new(null, catalog)
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.base_max_life = 100
    growth.max_life = 100
    growth.life = 80
    mutation.apply_effects([{"op": "grant_items", "item_ids": [LIFE_ITEM]}], growth)
    var snapshot = growth.to_progress_snapshot()
    var restored = GrowthInventoryScript.new(catalog, false)
    restored.apply_progress_snapshot(snapshot)
    _assert_equal(restored.max_life, 120,
        "存档恢复从 item marker 与活跃 item 统一重算最大生命")
    _assert_equal(restored.source_marker_store.snapshot("run"),
        growth.source_marker_store.snapshot("run"),
        "存档恢复只恢复 marker 状态而不重新执行获得效果")

    var engine = _engine(20003)
    _install_item_fixtures(engine.content_catalog)
    growth.apply_to_battle_side(engine.player)
    _assert_equal(engine.player.max_life, 120,
        "战斗建立恢复 item marker 并统一重算最大生命")
    _assert_equal(engine.player.source_marker_store.entries({
        "source_kind": "item", "content_id": LIFE_ITEM,
    })[0]["source_instance_key"], "item:player:%s" % LIFE_ITEM,
        "Growth/Battle marker 快照地址保持一致")
    var context = _item_context(engine, LIFE_ITEM)
    _assert_true(engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "add",
        "marker_id": "life_bonus", "scope": "run",
        "contributes_to": "max_life", "amount": 5,
    }], context).get("success", false), "战斗工作副本修改 item run marker")
    growth.sync_from_battle_side(engine.player)
    _assert_equal(growth.max_life, 125,
        "战后同步通过同一 Run marker 地址带回最大生命贡献")

    var rollback_growth = GrowthInventoryScript.new(catalog, false)
    mutation.apply_effects([{
        "op": "grant_items", "item_ids": [LIFE_ITEM],
    }], rollback_growth)
    var rollback_before: Dictionary = rollback_growth.capture_mutation_state()
    var rollback_engine = _engine(20004)
    _install_item_fixtures(rollback_engine.content_catalog)
    rollback_growth.apply_to_battle_side(rollback_engine.player)
    rollback_engine.effect_executor.execute_all([{
        "op": "write_source_marker", "operation": "add",
        "marker_id": "life_bonus", "scope": "run",
        "contributes_to": "max_life", "amount": 40,
    }], _item_context(rollback_engine, LIFE_ITEM))
    _assert_equal(rollback_growth.capture_mutation_state(), rollback_before,
        "退出战斗不提交时 GrowthInventory 保持原 Run 状态")


func _test_public_projection_preview_and_suppression() -> void:
    var catalog = _catalog()
    var mutation = RunMutationServiceScript.new(null, catalog)
    var growth = GrowthInventoryScript.new(catalog, false)
    mutation.apply_effects([{
        "op": "grant_items", "item_ids": [PRIVATE_ITEM],
    }], growth)
    _assert_true(growth.source_marker_store.public_projection().is_empty(),
        "public=false item marker 不进入公开投影")

    var engine = _engine(20005)
    _install_item_fixtures(engine.content_catalog)
    var life_growth = GrowthInventoryScript.new(catalog, false)
    life_growth.life = 110
    mutation.apply_effects([{
        "op": "grant_items", "item_ids": [LIFE_ITEM],
    }], life_growth)
    life_growth.apply_to_battle_side(engine.player)
    var marker_before: Dictionary = engine.player.source_marker_store.snapshot()
    var life_before: int = engine.player.life
    var max_before: int = engine.player.max_life
    var rng_before := int(engine.rng.state)
    var event_count := 0
    engine.battle_passive_event_service.event_committed.connect(
        func(kind: String, _values: Dictionary, _receipt: Dictionary):
            if kind == "source_marker_changed":
                event_count += 1)
    engine.effect_executor.summarize_intent([{
        "op": "write_source_marker", "operation": "add",
        "marker_id": "life_bonus", "scope": "run",
        "contributes_to": "max_life", "amount": 7,
    }], _item_context(engine, LIFE_ITEM), 0)
    _assert_equal(engine.player.source_marker_store.snapshot(), marker_before,
        "preview 只读，不修改 item marker")
    _assert_equal(engine.player.life, life_before, "preview 不修改生命")
    _assert_equal(engine.player.max_life, max_before, "preview 不修改最大生命")
    _assert_equal(int(engine.rng.state), rng_before, "preview 不推进 RNG")
    _assert_equal(event_count, 0, "preview 不发送 source_marker_changed")

    _assert_true(engine.apply_passive_suppression({
        "suppression_id": "item-source-contribution",
        "target_source_kind": "item",
        "target_content_id": LIFE_ITEM,
        "blocked_hooks": [],
        "reason": "测试物品失效",
    }).get("success", false), "既有被动压制可以命中 item 来源")
    _assert_equal(engine.player.max_life, 100,
        "全局压制暂停 item marker 的最大生命贡献")
    _assert_equal(engine.player.life, 100,
        "压制导致上限下降时当前生命立即截断")
    _assert_equal(engine.player.source_marker_store.snapshot(), marker_before,
        "压制不删除持久 item marker")
    _assert_true(engine.remove_passive_suppression(
        "item-source-contribution"), "解除物品压制成功")
    _assert_equal(engine.player.max_life, 120,
        "解除压制后使用原 marker 恢复贡献")
    _assert_equal(engine.player.life, 100,
        "解除压制恢复上限但不恢复当前生命")


func _catalog():
    var catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(), "载入 item marker 测试内容目录")
    _install_item_fixtures(catalog)
    return catalog


func _install_item_fixtures(catalog) -> void:
    for definition in _item_definitions():
        catalog._indexes["item"][str(definition["id"])] = definition.duplicate(true)


func _item_definitions() -> Array:
    return [
        _item_definition(LIFE_ITEM),
        _item_definition(RETAIN_ITEM),
        _item_definition(PRIVATE_ITEM),
        _item_definition(ORDER_A),
        _item_definition(ORDER_B),
        _item_definition(BROKEN_ITEM),
    ]


func _item_definition(item_id: String) -> Dictionary:
    var marker_definitions: Array = []
    match item_id:
        LIFE_ITEM:
            marker_definitions = [{
                "id": "life_bonus", "scope": "run", "public": true,
                "display_name": "生命上限", "contributes_to": "max_life",
                "forget_policy": "clear", "initial_value": 20,
            }, {
                "id": "battle_charge", "scope": "battle", "public": true,
                "display_name": "战斗计数", "forget_policy": "clear",
            }]
        RETAIN_ITEM:
            marker_definitions = [{
                "id": "life_bonus", "scope": "run", "public": true,
                "display_name": "保留生命上限", "contributes_to": "max_life",
                "forget_policy": "retain", "initial_value": 7,
            }]
        PRIVATE_ITEM:
            marker_definitions = [{
                "id": "private_charge", "scope": "run", "public": false,
                "display_name": "私有计数", "forget_policy": "clear",
                "initial_value": 3,
            }]
        ORDER_A, ORDER_B:
            marker_definitions = []
        BROKEN_ITEM:
            marker_definitions = [{
                "id": "broken_bonus", "scope": "run", "public": true,
                "display_name": "非法贡献", "contributes_to": "not_registered",
                "forget_policy": "clear", "initial_value": 9,
            }]
    return {
        "id": item_id,
        "name": item_id,
        "kind": "item",
        "status": "formal",
        "unique": true,
        "price": 0,
        "description": "item_source_marker_state 测试夹具。",
        "marker_definitions": marker_definitions,
        # 地址稳定性专项需要 PassiveRuleSourceResolver 产出实际 source；夹具
        # 只进入测试 catalog，不是正式物品内容。
        "behaviors": [{
            "id": "battle_effects",
            "configuration": {
                "hook": "action_resolve",
                "effects": [{"op": "defense", "amount": 0}],
            },
        }],
    }


func _item_context(engine, item_id: String):
    return BattleEffectContextScript.new().configure({
        "ports": engine.effect_ports,
        "actor": engine.player,
        "target": engine.enemy,
        "owner": engine.player,
        "source_kind": "item",
        "source_id": item_id,
        "source_name": item_id,
        "source_instance_key": "item:player:%s" % item_id,
        "source_marker_definitions": _item_definition(item_id).get(
            "marker_definitions", []),
        "trigger_mode": "direct",
        "action_token": "item-source-marker:%s" % item_id,
    })


func _item_source_keys(snapshot: Array) -> Dictionary:
    var result: Dictionary = {}
    for value in snapshot:
        if value is Dictionary and str(value.get("source_kind", "")) == "item":
            result[str(value.get("content_id", ""))] = str(
                value.get("source_instance_key", ""))
    return result


func _assert_item_validation(
        definition: Dictionary, expected_valid: bool, label: String) -> void:
    var validator = ContentValidatorScript.new()
    validator.errors.clear()
    validator._validate_items(definition.duplicate(true))
    _assert_equal(validator.errors.is_empty(), expected_valid, label)
