extends SceneTree

const RuntimeProfileScript = preload("res://core/runtime_profile.gd")
const ContentCatalogScript = preload("res://core/content_catalog.gd")
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const PracticeServiceScript = preload("res://core/practice_service.gd")
const PassiveRuleRuntimeScript = preload(
    "res://core/passives/passive_rule_runtime.gd")
const PassiveIntPolicyResolverScript = preload(
    "res://core/passives/passive_int_policy_resolver.gd")
const RunMutationServiceScript = preload(
    "res://core/run_effects/run_mutation_service.gd")
const RunPassiveEventServiceScript = preload(
    "res://core/passives/run_passive_event_service.gd")
const RunStateScript = preload("res://core/run_state.gd")
const InsightGrowthServiceScript = preload("res://core/insight_growth_service.gd")

var failures: Array[String] = []
var assertions := 0
var catalog


func _initialize() -> void:
    if not RuntimeProfileScript.current().is_test():
        push_error("自动化测试必须显式指定 --launch-mode=test")
        quit(2)
        return
    catalog = ContentCatalogScript.new(RuntimeProfileScript.test())
    _assert_true(catalog.load_all(),
        "正式内容目录通过修习策略内容校验：%s" % "；".join(catalog.errors))
    if catalog.loaded:
        _test_queries_and_frozen_shop()
        _test_weights_unlock_and_dynamic_offer()
        _test_dynamic_purchase_transaction()
        _test_telescope_pack_plan()
        _test_insight_growth_and_migration()
        _test_formal_content_contract()
    _finish()


func _test_queries_and_frozen_shop() -> void:
    var plain: Dictionary = _environment([])
    var growth = plain.growth
    var service = plain.service
    var state_before: Dictionary = growth.capture_mutation_state()
    var slot_query: Dictionary = service.resolve_normal_slot_count(
        growth, 2, {"group": "normal", "operation": "generate_shop"})
    _assert_equal(slot_query.get("effective_value"), 2,
        "无来源时普通商品槽位保持2")
    _assert_equal(growth.capture_mutation_state(), state_before,
        "普通槽位查询纯读且不修改Run状态")
    var first: Dictionary = service.start_new_shop(growth, 71001, 1, 1)
    _assert_equal(first.get("normal_slot_count"), 2,
        "新商店冻结普通槽位数")
    _assert_equal(first.get("normal", []).size(), 2,
        "无库存过剩时normal数组保持2格")
    _assert_true(str(first.get("strategy_source_fingerprint", "")) != "",
        "商店保存策略来源指纹")

    var repeated_env: Dictionary = _environment([])
    var repeated: Dictionary = repeated_env.service.start_new_shop(
        repeated_env.growth, 71001, 1, 1)
    _assert_equal(repeated.get("normal"), first.get("normal"),
        "同seed同来源普通候选完全一致")
    _assert_equal(repeated.get("packs"), first.get("packs"),
        "同seed同来源补充包候选完全一致")

    var legacy_definition: Dictionary = catalog.definition("practice_shop")
    legacy_definition["normal"]["categories"] = \
        legacy_definition["normal"]["categories"].filter(
            func(value): return str(value.get("id", "")) != "awakened_qi")
    var legacy_env: Dictionary = _environment([])
    legacy_env.service.configure(legacy_definition)
    var legacy: Dictionary = legacy_env.service.start_new_shop(
        legacy_env.growth, 71001, 1, 1)
    _assert_equal(legacy.get("normal"), first.get("normal"),
        "默认锁定的动态类别不改变改造前普通候选")
    _assert_equal(legacy.get("packs"), first.get("packs"),
        "默认锁定类别不消费RNG或改变后续补充包")

    var overstock_env: Dictionary = _environment(["overstock_plus_two"])
    var overstock: Dictionary = overstock_env.service.start_new_shop(
        overstock_env.growth, 71001, 1, 1)
    _assert_equal(overstock.get("normal_slot_count"), 4,
        "库存过剩使新商店冻结为4槽")
    _assert_equal(overstock.get("normal", []).size(), 4,
        "库存过剩只扩充normal数组")
    _assert_equal(overstock.get("packs", []).size(), 2,
        "库存过剩不增加补充包槽")
    _assert_equal(overstock.get("items", []).size(), 1,
        "库存过剩不增加物品槽")

    var late_env: Dictionary = _environment([])
    late_env.service.start_new_shop(late_env.growth, 71002, 1, 1)
    late_env.growth.item_ids.append("overstock_plus_two")
    _assert_equal(late_env.service.snapshot(late_env.growth).get(
        "normal", []).size(), 2,
        "当前商店获得库存过剩不追溯扩容")
    var next_shop: Dictionary = late_env.service.start_new_shop(
        late_env.growth, 71002, 1, 2)
    _assert_equal(next_shop.get("normal", []).size(), 4,
        "库存过剩从下一批新商店开始生效")

    next_shop["normal"][1] = {}
    late_env.growth.practice_shop_state = next_shop
    var copied = GrowthInventoryScript.new(catalog, false)
    _assert_true(copied.replace_mutation_state(
        late_env.growth.capture_mutation_state()).is_empty(),
        "四槽商店通过Run事务快照恢复")
    _assert_equal(copied.practice_shop_state, late_env.growth.practice_shop_state,
        "恢复保持4槽、空位、候选和策略指纹")


func _test_weights_unlock_and_dynamic_offer() -> void:
    var categories: Dictionary = _categories_by_id()
    var pill_env: Dictionary = _environment(["pill_shop_weight_x4"])
    var pill_before: Dictionary = pill_env.growth.capture_mutation_state()
    var pill_query: Dictionary = pill_env.service.resolve_offer_weight(
        pill_env.growth, categories.pills, {"operation": "test"})
    var insight_query: Dictionary = pill_env.service.resolve_offer_weight(
        pill_env.growth, categories.insights, {"operation": "test"})
    _assert_equal(pill_query.get("effective_value"), 100,
        "塔罗大亨只把单份丹药权重乘4")
    _assert_equal(insight_query.get("effective_value"), 15,
        "塔罗大亨不修改单份心得权重")
    _assert_equal(pill_env.growth.capture_mutation_state(), pill_before,
        "权重查询不修改状态或商店快照")

    var insight_env: Dictionary = _environment(["insight_shop_weight_x4"])
    _assert_equal(insight_env.service.resolve_offer_weight(
        insight_env.growth, categories.insights).get("effective_value"), 60,
        "星球牌商人只把单份心得权重乘4")
    _assert_equal(insight_env.service.resolve_offer_weight(
        insight_env.growth, categories.pills).get("effective_value"), 25,
        "星球牌商人不修改单份丹药")

    var color_env: Dictionary = _environment(["awakened_qi_weight_x4"])
    _assert_equal(color_env.service.resolve_offer_category_enabled(
        color_env.growth, categories.awakened_qi).get("effective_value"), 0,
        "焕彩不自行开放觉醒类别")
    _assert_equal(color_env.service.resolve_offer_weight(
        color_env.growth, categories.awakened_qi).get("effective_value"), 20,
        "焕彩独立修改觉醒类别权重")
    var color_shop: Dictionary = color_env.service.start_new_shop(
        color_env.growth, 72001, 1, 1)
    _assert_true(not _contains_kind(color_shop.get("normal", []), "qi_card"),
        "仅持有焕彩不会生成觉醒真气")

    var illusion_env: Dictionary = _environment(["awakened_qi_in_normal_shop"])
    _assert_equal(illusion_env.service.resolve_offer_category_enabled(
        illusion_env.growth, categories.awakened_qi).get("effective_value"), 1,
        "幻象通过类别查询开放觉醒真气")
    _assert_equal(illusion_env.service.resolve_offer_weight(
        illusion_env.growth, categories.awakened_qi).get("effective_value"), 5,
        "幻象不直接修改觉醒类别权重")

    var combined: Dictionary = _environment([
        "overstock_plus_two", "awakened_qi_in_normal_shop",
        "awakened_qi_weight_x4"])
    _assert_equal(combined.service.resolve_offer_weight(
        combined.growth, categories.awakened_qi).get("effective_value"), 20,
        "幻象与焕彩通过资格和权重查询自然联动")
    var found: Dictionary = {}
    for seed in range(72001, 72201):
        var candidate: Dictionary = combined.service.start_new_shop(
            combined.growth, seed, 1, seed - 72000)
        var dynamic: Dictionary = _first_kind(
            candidate.get("normal", []), "qi_card")
        if not dynamic.is_empty():
            found = {"seed": seed, "state": candidate, "offer": dynamic}
            break
    _assert_true(not found.is_empty(), "稳定种子范围内生成永久觉醒真气候选")
    if found.is_empty():
        return
    var offer: Dictionary = found.offer
    _assert_equal(offer.get("price"), 4, "动态觉醒真气基础价格为4")
    _assert_true(str(offer.get("offer_instance_id", "")) != "" \
        and str(offer.get("purchase_key", "")) == str(
            offer.get("offer_instance_id", "")),
        "动态offer使用独立稳定购买键")
    _assert_equal(offer.get("origin"), "awakening",
        "动态真气冻结awakening本源")
    _assert_equal(offer.get("origin_payload", {}).get("attribute"),
        offer.get("attribute"), "觉醒payload与基础属性一致")
    _assert_true(not bool(offer.get("temporary", true)) \
        and str(offer.get("original_owner_id", "x")) == "",
        "动态真气是永久且无原持有者")
    _assert_true(offer.get("card_instance", {}).get(
        "reshapes", {}).get("origin", {}).get("id") == "awakening",
        "冻结实例保存正式本源结构")
    var reopened: Dictionary = combined.service.snapshot(combined.growth)
    _assert_equal(reopened, found.state,
        "关闭并重新读取修习不会重掷动态offer")
    var restored = GrowthInventoryScript.new(catalog, false)
    _assert_true(restored.replace_mutation_state(
        combined.growth.capture_mutation_state()).is_empty(),
        "动态offer通过Run事务快照恢复")
    _assert_equal(restored.practice_shop_state, found.state,
        "恢复保持动态卡牌完整实例数据")


func _test_dynamic_purchase_transaction() -> void:
    var env: Dictionary = _environment([
        "overstock_plus_two", "awakened_qi_in_normal_shop",
        "awakened_qi_weight_x4"])
    env.growth.experience = 20
    var located: Dictionary = _find_dynamic_shop(env, 73001)
    _assert_true(not located.is_empty(), "动态购买夹具找到觉醒真气")
    if located.is_empty():
        return
    var slot_index: int = int(located.slot_index)
    var offer: Dictionary = located.offer.duplicate(true)
    var count_before: int = env.growth.run_deck.card_count()
    var purchase: Dictionary = env.service.purchase(
        env.growth, "normal", slot_index, true)
    _assert_true(purchase.get("success", false),
        "动态觉醒真气通过统一普通商品购买成功")
    _assert_equal(env.growth.experience, 16, "动态购买原子扣除4点历练")
    _assert_equal(env.growth.run_deck.card_count(), count_before + 1,
        "动态购买通过RunDeck正式入口新增一张")
    _assert_equal(env.growth.run_deck.card_data(str(offer.instance_id)),
        offer.card_instance, "购买加入精确冻结实例而不重新随机")
    _assert_equal(env.growth.practice_shop_state.get(
        "normal", [])[slot_index], {}, "成功购买只清空对应冻结槽位")
    _assert_true(env.growth.practice_purchases.has(str(offer.purchase_key)),
        "动态购买记录offer_instance购买键而非definition_id")
    _assert_equal(purchase.get("added_card_instance_id"), offer.instance_id,
        "购买结果公开实际新增instance_id")
    _assert_equal(purchase.get("frozen_offer", {}).get("offer_instance_id"),
        offer.offer_instance_id, "购买事件结果携带冻结offer摘要")

    var failed: Dictionary = _environment(["awakened_qi_in_normal_shop"])
    failed.growth.experience = 20
    failed.growth.practice_shop_state = {
        "shop_index": 9, "act": 1,
        "normal": [offer.duplicate(true)], "packs": [], "items": [],
        "normal_slot_count": 1, "pack_open_sequence": 0,
    }
    var invalid_offer: Dictionary = failed.growth.practice_shop_state.normal[0]
    invalid_offer["card_instance"]["definition_id"] = "missing_definition"
    failed.growth.practice_shop_state.normal[0] = invalid_offer
    var before: Dictionary = failed.growth.capture_mutation_state()
    var rejected: Dictionary = failed.service.purchase(
        failed.growth, "normal", 0, true)
    _assert_true(not rejected.get("success", false),
        "非法冻结实例使动态购买明确失败")
    _assert_equal(failed.growth.capture_mutation_state(), before,
        "动态购买失败完整恢复历练、牌组、槽位、购买键与事件状态")


func _test_telescope_pack_plan() -> void:
    var env: Dictionary = _environment(["telescope_insight_focus"])
    env.growth.experience = 30
    env.growth.run_combat_history.record_hand_success("pair")
    env.growth.run_combat_history.record_hand_success("pair")
    env.growth.run_combat_history.record_hand_success("straight")
    _install_pack(env.growth, "insight_pack_basic")
    var before: Dictionary = env.growth.capture_mutation_state()
    var preview: Dictionary = env.service.open_pack(
        env.growth, "packs", 0, [], true, 74001, 1)
    _assert_true(preview.get("success", false), "望远镜心得包准备成功")
    _assert_equal(preview.get("guaranteed_candidate_id"), "pair_insight",
        "望远镜读取RunCombatHistory唯一最高牌型")
    _assert_equal(preview.get("preview", [])[0], "pair_insight",
        "保证心得固定占据第一个展示位")
    _assert_equal(preview.get("preview", []).count("pair_insight"), 1,
        "保证心得与普通候选去重")
    _assert_equal(env.growth.capture_mutation_state(), before,
        "补充包准备不扣费、不发内容且不修改历史")
    var repeated: Dictionary = env.service.open_pack(
        env.growth, "packs", 0, [], true, 74001, 1)
    _assert_equal(repeated.get("preview"), preview.get("preview"),
        "重复预览不重掷望远镜保证候选")
    _assert_equal(repeated.get("preparation_token"), preview.get(
        "preparation_token"), "相同准备结果令牌稳定")
    var confirmed: Dictionary = env.service.open_pack(
        env.growth, "packs", 0, ["pair_insight"], true, 74001, 1,
        str(preview.get("preparation_token", "")))
    _assert_true(confirmed.get("success", false),
        "正式确认只消费冻结的心得包准备结果")
    _assert_equal(env.growth.consumable_ids, ["pair_insight"],
        "确认发放玩家选择的冻结心得")

    var tie_a: Dictionary = _environment(["telescope_insight_focus"])
    tie_a.growth.experience = 30
    tie_a.growth.run_combat_history.record_hand_success("pair")
    tie_a.growth.run_combat_history.record_hand_success("straight")
    _install_pack(tie_a.growth, "insight_pack_basic")
    var tie_preview_a: Dictionary = tie_a.service.open_pack(
        tie_a.growth, "packs", 0, [], true, 74002, 1)
    var tie_b: Dictionary = _environment(["telescope_insight_focus"])
    tie_b.growth.experience = 30
    tie_b.growth.run_combat_history.record_hand_success("pair")
    tie_b.growth.run_combat_history.record_hand_success("straight")
    _install_pack(tie_b.growth, "insight_pack_basic")
    var tie_preview_b: Dictionary = tie_b.service.open_pack(
        tie_b.growth, "packs", 0, [], true, 74002, 1)
    _assert_equal(tie_preview_a.get("guaranteed_candidate_id"),
        tie_preview_b.get("guaranteed_candidate_id"),
        "最高牌型并列时由pack RNG稳定选择")
    _assert_true(tie_preview_a.get("guaranteed_candidate_id") in [
        "pair_insight", "straight_insight"],
        "并列保证候选只来自最高牌型集合")

    var empty_a: Dictionary = _environment(["telescope_insight_focus"])
    empty_a.growth.experience = 30
    _install_pack(empty_a.growth, "insight_pack_basic", 1)
    var empty_preview_a: Dictionary = empty_a.service.open_pack(
        empty_a.growth, "packs", 0, [], true, 74003, 1)
    var empty_b: Dictionary = _environment(["telescope_insight_focus"])
    empty_b.growth.experience = 30
    _install_pack(empty_b.growth, "insight_pack_basic", 1)
    var empty_preview_b: Dictionary = empty_b.service.open_pack(
        empty_b.growth, "packs", 0, [], true, 74003, 1)
    _assert_equal(empty_preview_a.get("preview"), empty_preview_b.get("preview"),
        "无历史时在八牌型中稳定随机")
    _assert_true(str(empty_preview_a.get(
        "guaranteed_candidate_id", "")) != "" \
        and str(empty_preview_a.get("guaranteed_candidate_id", "")) \
            == str(empty_preview_a.get("preview", [""])[0]),
        "无历史时仍冻结一个随机牌型为保证候选")
    _assert_equal(empty_preview_a.get("preview", []).size(), 1,
        "offer_count为1时只展示保证候选")

    var stale: Dictionary = _environment(["telescope_insight_focus"])
    stale.growth.experience = 30
    _install_pack(stale.growth, "insight_pack_basic")
    var stale_preview: Dictionary = stale.service.open_pack(
        stale.growth, "packs", 0, [], true, 74004, 1)
    stale.growth.run_combat_history.record_hand_success("pair")
    var stale_before: Dictionary = stale.growth.capture_mutation_state()
    var stale_confirm: Dictionary = stale.service.open_pack(
        stale.growth, "packs", 0,
        [stale_preview.get("preview", [])[0]], true, 74004, 1,
        str(stale_preview.get("preparation_token", "")))
    _assert_true(not stale_confirm.get("success", false),
        "历史快照变化令正式准备令牌明确失效")
    _assert_equal(stale.growth.capture_mutation_state(), stale_before,
        "准备失效不扣费、不发放也不消费槽位")


func _test_insight_growth_and_migration() -> void:
    var env: Dictionary = _environment(["telescope_insight_focus"])
    var gain: Dictionary = env.growth.technique_loadout_policy \
        .resolve_insight_slot_gain(
        env.growth, "pair", 1)
    _assert_equal(gain.get("effective_value"), 2,
        "望远镜复用insight_slot_gain_query把+1改为+2")
    var capped: Dictionary = InsightGrowthServiceScript.resolve(
        env.growth, env.growth.technique_loadout_policy, "pair",
        {"slot_count": 8, "sequence": []},
        env.growth.hand_technique_progression,
        env.growth.learned_technique_ids, [], null, false)
    _assert_true(capped.get("success", false), "心得增长计划在上限附近仍成功")
    _assert_equal(capped.get("slot_gain_requested"), 2,
        "心得计划保留查询请求增量2")
    _assert_equal(capped.get("slot_count_after"), 9,
        "超过容量9时只截断实际增长")
    _assert_equal(capped.get("slot_gain"), 1,
        "上限截断不把整个心得效果取消")

    var legacy: Dictionary = GrowthInventoryScript.normalized_practice_shop_state({
        "shop_index": 2,
        "normal": [{"id": "zengyuan_pill", "kind": "consumable"}, {}],
        "packs": [],
        "coupons": [],
    })
    _assert_equal(legacy.get("normal_slot_count"), 2,
        "旧practice_shop_state从数组长度迁移冻结槽位数")
    _assert_true(not legacy.get("normal", [])[0].has("purchase_key"),
        "旧固定offer保持原样并由购买边界回退content_id")
    _assert_true(legacy.has("items") and not legacy.has("coupons"),
        "旧coupons字段继续迁移为items")
    _assert_equal(GrowthInventoryScript.normalized_practice_shop_state({}), {},
        "空旧状态仍保持空以便首次进入时生成商店")


func _test_formal_content_contract() -> void:
    var items: Array = catalog.definition("items").get("items", [])
    var formal: Array[String] = []
    for item in items:
        if str(item.get("status", "")) == "formal":
            formal.append(str(item.get("id", "")))
            _assert_equal(item.get("price"), 8,
                "%s 首版基础价格统一为8" % str(item.get("id", "")))
            _assert_equal(item.get("kind"), "item",
                "%s 使用正式item kind" % str(item.get("id", "")))
            _assert_true(bool(item.get("unique", false)),
                "%s 保持本局唯一" % str(item.get("id", "")))
    formal.sort()
    var expected := [
        "awakened_qi_in_normal_shop", "awakened_qi_weight_x4",
        "deck_growth_and_reshape_vitality",
        "insight_shop_weight_x4", "overstock_plus_two",
        "pill_shop_weight_x4", "telescope_insight_focus",
    ]
    _assert_equal(formal, expected, "七件物品正式接入且其他物品仍design_only")
    var candidates: Array = catalog.definition("practice_shop").get(
        "items", {}).get("candidate_ids", []).duplicate()
    candidates.sort()
    _assert_equal(candidates, expected,
        "物品商店候选池覆盖全部且仅覆盖正式有价物品")
    for hook in [
            "practice_normal_slot_count_query", "practice_offer_weight_query",
            "practice_offer_category_enabled_query",
            "practice_pack_candidate_priority_query"]:
        _assert_true(catalog.passive_rule_registry.has_hook(hook),
            "Registry登记正式查询键%s" % hook)


func _environment(item_ids: Array) -> Dictionary:
    var growth = GrowthInventoryScript.new(catalog, false)
    growth.item_ids.assign(item_ids)
    var runtime = PassiveRuleRuntimeScript.new(
        catalog.passive_rule_registry, catalog)
    var resolver = PassiveIntPolicyResolverScript.new(runtime)
    var mutation = RunMutationServiceScript.new(
        catalog.run_effect_registry, catalog)
    var events = RunPassiveEventServiceScript.new(runtime, mutation)
    var event_state = RunStateScript.new(null, growth)
    var service = PracticeServiceScript.new(catalog, mutation)
    service.use_passive_services(resolver, events, event_state)
    growth.use_technique_loadout_policy_resolver(resolver)
    return {
        "growth": growth,
        "runtime": runtime,
        "resolver": resolver,
        "mutation": mutation,
        "events": events,
        "event_state": event_state,
        "service": service,
    }


func _categories_by_id() -> Dictionary:
    var result: Dictionary = {}
    for category in catalog.definition("practice_shop").get(
            "normal", {}).get("categories", []):
        result[str(category.get("id", ""))] = category.duplicate(true)
    return result


func _contains_kind(values: Array, kind: String) -> bool:
    return not _first_kind(values, kind).is_empty()


func _first_kind(values: Array, kind: String) -> Dictionary:
    for value in values:
        if value is Dictionary and str(value.get("kind", "")) == kind:
            return value.duplicate(true)
    return {}


func _find_dynamic_shop(env: Dictionary, first_seed: int) -> Dictionary:
    for seed in range(first_seed, first_seed + 300):
        var state: Dictionary = env.service.start_new_shop(
            env.growth, seed, 1, seed - first_seed + 1)
        var normal: Array = state.get("normal", [])
        for index in range(normal.size()):
            if normal[index] is Dictionary \
                    and str(normal[index].get("kind", "")) == "qi_card":
                return {
                    "state": state,
                    "slot_index": index,
                    "offer": normal[index].duplicate(true),
                }
    return {}


func _install_pack(growth, pack_id: String, offer_count: int = -1) -> void:
    var selected: Dictionary = {}
    for pack in catalog.definition("practice_shop").get(
            "packs", {}).get("candidates", []):
        if str(pack.get("id", "")) == pack_id:
            selected = pack.duplicate(true)
            break
    if offer_count >= 0:
        selected["offer_count"] = offer_count
        selected["choose_count"] = mini(
            int(selected.get("choose_count", 1)), offer_count)
    growth.practice_shop_state = {
        "shop_index": 1,
        "act": 1,
        "normal_slot_count": 0,
        "normal": [],
        "packs": [selected],
        "items": [],
        "meditation_count": 0,
        "next_meditation_cost": 5,
        "pack_open_sequence": 0,
        "strategy_source_fingerprint": "fixture",
        "strategy_source_snapshot_fingerprint": "fixture",
        "strategy_operation": "fixture",
    }


func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append(label)


func _assert_equal(actual, expected, label: String) -> void:
    assertions += 1
    if actual != expected:
        failures.append("%s：期望 %s，实际 %s" % [label, str(expected), str(actual)])


func _finish() -> void:
    if failures.is_empty():
        print("PRACTICE STRATEGY QUERY PASS: %d assertions" % assertions)
        quit(0)
        return
    for failure in failures:
        push_error("PRACTICE STRATEGY QUERY FAIL: %s" % failure)
    print("PRACTICE STRATEGY QUERY FAILURES: %d / %d assertions" % [
        failures.size(), assertions])
    quit(1)
