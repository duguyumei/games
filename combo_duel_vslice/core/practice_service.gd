class_name PracticeService
extends RefCounted

## 正式修习商店的纯规则服务。商店状态存放在 GrowthInventory，
## 本服务只负责数据白名单解析、确定性生成、冻结补充包与购买事务。

const NORMAL_GROUP := "normal"
const PACK_GROUP := "packs"
const ITEM_GROUP := "items"
const GROUPS := [NORMAL_GROUP, PACK_GROUP, ITEM_GROUP]
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")
const IntQueryRequestScript = preload(
    "res://core/passives/passive_int_query_request.gd")
const EventContextScript = preload(
    "res://core/passives/run_passive_event_context.gd")

var _definition: Dictionary = {}
var _content_catalog
var _int_policy_resolver
var _event_service
var _event_state
var _pack_preparations: Dictionary = {}

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog
    if content_catalog != null and content_catalog.loaded:
        _definition = content_catalog.definition("practice_shop")

func configure(definition: Dictionary) -> void:
    _definition = definition.duplicate(true)

func use_passive_services(
        int_policy_resolver,
        event_service = null,
        event_state = null) -> void:
    _int_policy_resolver = int_policy_resolver
    _event_service = event_service
    _event_state = event_state

func start_new_shop(growth, run_seed: int, act: int, shop_index: int) -> Dictionary:
    _pack_preparations.clear()
    var state := _generate_state(growth, run_seed, act, shop_index)
    growth.practice_shop_state = state
    return state.duplicate(true)

func ensure_shop(growth, run_seed: int, act: int) -> Dictionary:
    if growth.has_method("migrate_legacy_practice_shop_state"):
        growth.migrate_legacy_practice_shop_state()
    if growth.practice_shop_state.is_empty():
        return start_new_shop(growth, run_seed, act, 1)
    return growth.practice_shop_state.duplicate(true)

func snapshot(growth, run_seed: int = 0, act: int = 1) -> Dictionary:
    ensure_shop(growth, run_seed, act)
    return growth.practice_shop_state.duplicate(true)

func purchase(
        growth,
        group: String,
        slot_index: int,
        can_open: bool,
        event_values: Dictionary = {}) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能修习"}
    if group not in [NORMAL_GROUP, ITEM_GROUP]:
        return {"success": false, "reason": "该区域不能直接购买"}
    var slot := _slot(growth.practice_shop_state, group, slot_index)
    if slot.is_empty():
        return {"success": false, "reason": "修习槽位为空或已购买"}
    var base_price := int(slot.get("price", -1))
    if base_price < 0:
        return {"success": false, "reason": "商品缺少正式价格"}
    var content_id := str(slot.get("id", ""))
    var kind := str(slot.get("kind", ""))
    var source_snapshot := _capture_sources(growth)
    var price_query := resolve_price(
        growth, kind, content_id, base_price, {
            "group": group,
            "slot_index": slot_index,
        }, source_snapshot)
    if not price_query.get("success", false):
        return price_query
    var price := int(price_query["effective_price"])
    if growth.experience < price:
        return {"success": false, "reason": "历练不足"}
    if content_id == "" or growth.practice_purchases.has(content_id):
        return {"success": false, "reason": "该商品已经购买"}
    if group == ITEM_GROUP and kind != "item":
        return {"success": false, "reason": "物品栏包含非物品内容"}
    if group == NORMAL_GROUP and kind not in ["technique", "inner_skill", "consumable"]:
        return {"success": false, "reason": "普通商品类型无效"}

    if kind == "technique":
        if _growth_has_technique(growth, content_id):
            return {"success": false, "reason": "该功法已经获得"}
    elif kind == "inner_skill":
        if growth.learned_inner_skill_ids.has(content_id):
            return {"success": false, "reason": "该内功已经获得"}
    elif kind == "consumable":
        if growth.consumable_ids.size() >= GrowthInventoryScript.CONSUMABLE_LIMIT:
            return {"success": false, "reason": "共享消耗品栏已满"}
        if _is_unique_consumable_unavailable(growth, content_id):
            return {"success": false, "reason": "该唯一奇珍已经获得或使用"}
    elif kind == "item":
        if growth.item_ids.has(content_id):
            return {"success": false, "reason": "该物品已经获得"}
    else:
        return {"success": false, "reason": "不支持的修习商品类型：%s" % kind}

    var working = growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立购买事务工作副本"}
    working.experience -= price
    if kind == "technique":
        working.learned_technique_ids.append(content_id)
    elif kind == "inner_skill":
        working.learned_inner_skill_ids.append(content_id)
    elif kind == "consumable":
        working.consumable_ids.append(content_id)
    elif kind == "item":
        working.item_ids.append(content_id)
    working.practice_purchases[content_id] = true
    _clear_slot(working.practice_shop_state, group, slot_index)
    var event_result := _dispatch_event(
        "practice_purchase_committed", working, event_values, source_snapshot, {
            "content_id": content_id,
            "content_kind": kind,
            "shop_index": int(working.practice_shop_state.get("shop_index", 0)),
            "transaction_token": "practice_purchase:%d:%s:%d:%s" % [
                int(working.practice_shop_state.get("shop_index", 0)),
                group, slot_index, content_id],
            "payload": {
                "group": group,
                "slot_index": slot_index,
                "base_price": base_price,
                "effective_price": price,
            },
        })
    if not event_result.get("success", false):
        return event_result
    var commit_errors: Array[String] = growth.replace_mutation_state(
        working.capture_mutation_state())
    if not commit_errors.is_empty():
        _rollback_event_token(event_result)
        return {"success": false, "reason": "；".join(commit_errors)}
    return {
        "success": true,
        "content_id": content_id,
        "kind": kind,
        "price": price,
        "base_price": base_price,
        "effective_price": price,
        "price_modifiers": price_query["price_modifiers"],
        "group": group,
        "slot_index": slot_index,
        "remaining_experience": growth.experience,
        "passive_event": event_result,
    }

func open_pack(
        growth,
        group: String,
        slot_index: int,
        selected_ids: Array,
        can_open: bool,
        run_seed: int,
        act: int,
        preparation_token: String = "",
        event_values: Dictionary = {}) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能修习"}
    if group != PACK_GROUP:
        return {"success": false, "reason": "只有补充包栏可以打开补充包"}
    var slot := _slot(growth.practice_shop_state, group, slot_index)
    if slot.is_empty() or str(slot.get("kind", "")) != "consumable_pack":
        return {"success": false, "reason": "补充包槽位为空或已打开"}
    var pack_id := str(slot.get("id", ""))
    var base_price := int(slot.get("price", -1))
    if base_price < 0:
        return {"success": false, "reason": "补充包缺少正式价格"}
    if preparation_token != "":
        return _confirm_prepared_pack(
            growth, group, slot_index, selected_ids, slot,
            can_open, run_seed, act, preparation_token, event_values)
    if not selected_ids.is_empty():
        return {"success": false, "reason": "补充包确认缺少 preparation_token"}
    var source_snapshot := _capture_sources(growth)
    var price_query := resolve_price(
        growth, "consumable_pack", pack_id, base_price, {
            "group": group, "slot_index": slot_index,
        }, source_snapshot)
    if not price_query.get("success", false):
        return price_query
    var price := int(price_query["effective_price"])
    if growth.experience < price:
        return {"success": false, "reason": "历练不足"}
    var candidate_ids := _eligible_pack_candidate_ids(growth, slot)
    var base_offer_count := int(slot.get("offer_count", 0))
    var base_choose_count := int(slot.get("choose_count", 1))
    var offer_query := resolve_pack_count(
        "pack_offer_count_query", growth, pack_id,
        base_offer_count, {"group": group, "slot_index": slot_index},
        source_snapshot)
    if not offer_query.get("success", false):
        return offer_query
    var choose_query := resolve_pack_count(
        "pack_choose_count_query", growth, pack_id,
        base_choose_count, {"group": group, "slot_index": slot_index},
        source_snapshot)
    if not choose_query.get("success", false):
        return choose_query
    var offer_count := int(offer_query["effective_value"])
    var choose_count := int(choose_query["effective_value"])
    var sequence := int(growth.practice_shop_state.get("pack_open_sequence", 0))
    var rng := _pack_rng_for(
        run_seed, act, int(growth.practice_shop_state.get("shop_index", 1)),
        slot_index, sequence)
    var offered: Array[String] = _sample_ids(candidate_ids, offer_count, rng)
    if offered.is_empty():
        return {"success": false, "reason": "补充包当前没有合格候选"}
    var free_slots := maxi(
        GrowthInventoryScript.CONSUMABLE_LIMIT - growth.consumable_ids.size(), 0)
    var max_choose_count := mini(mini(choose_count, free_slots), offered.size())
    var source_fingerprint := _combined_fingerprint([
        price_query.get("source_fingerprint", ""),
        offer_query.get("source_fingerprint", ""),
        choose_query.get("source_fingerprint", ""),
    ])
    var expected_token := _pack_preparation_token(
        growth, group, slot_index, slot, offered, run_seed, act, {
            "base_price": base_price,
            "effective_price": price,
            "base_offer_count": base_offer_count,
            "effective_offer_count": offer_count,
            "base_choose_count": base_choose_count,
            "effective_choose_count": choose_count,
            "passive_source_fingerprint": source_fingerprint,
        })
    if selected_ids.is_empty() and preparation_token == "":
        _pack_preparations[expected_token] = {
            "pack_id": pack_id,
            "group": group,
            "slot_index": slot_index,
            "slot": slot.duplicate(true),
            "offered": offered.duplicate(),
            "base_price": base_price,
            "effective_price": price,
            "price_modifiers": price_query["price_modifiers"].duplicate(true),
            "base_offer_count": base_offer_count,
            "effective_offer_count": offer_count,
            "offer_count_modifiers": offer_query["modifier_breakdown"].duplicate(true),
            "base_choose_count": base_choose_count,
            "effective_choose_count": choose_count,
            "choose_count_modifiers": choose_query["modifier_breakdown"].duplicate(true),
            "passive_source_fingerprint": source_fingerprint,
            "source_snapshot": source_snapshot.duplicate(true),
            "sequence": sequence,
            "free_slots": free_slots,
            "max_choose_count": max_choose_count,
            "run_seed": run_seed,
            "act": act,
        }
        return {
            "success": true,
            "preview": offered,
            "choose_count": choose_count,
            "pack_id": pack_id,
            "base_offer_count": base_offer_count,
            "effective_offer_count": offer_count,
            "base_choose_count": base_choose_count,
            "effective_choose_count": choose_count,
            "minimum_choose_count": 1,
            "max_choose_count": max_choose_count,
            "free_consumable_slots": free_slots,
            "preparation_token": expected_token,
            "price": price,
            "base_price": base_price,
            "effective_price": price,
            "price_modifiers": price_query["price_modifiers"],
            "offer_count_modifiers": offer_query["modifier_breakdown"],
            "choose_count_modifiers": choose_query["modifier_breakdown"],
            "passive_source_fingerprint": source_fingerprint,
            "group": group,
            "slot_index": slot_index,
        }
    return {"success": false, "reason": "补充包预览参数无效"}

func _confirm_prepared_pack(
        growth,
        group: String,
        slot_index: int,
        selected_ids: Array,
        slot: Dictionary,
        _can_open: bool,
        run_seed: int,
        act: int,
        preparation_token: String,
        event_values: Dictionary) -> Dictionary:
    if not _pack_preparations.has(preparation_token):
        return {"success": false, "reason": "补充包预览已失效，请重新预览"}
    var prepared: Dictionary = _pack_preparations[preparation_token]
    if str(prepared.get("group", "")) != group \
            or int(prepared.get("slot_index", -1)) != slot_index \
            or str(prepared.get("pack_id", "")) != str(slot.get("id", "")):
        return {"success": false, "reason": "补充包预览与当前槽位不匹配"}
    var frozen_source_snapshot: Array = prepared.get("source_snapshot", [])
    var current_fingerprint: Dictionary = _current_pack_source_fingerprint(growth)
    if not current_fingerprint.get("success", false) \
            or str(current_fingerprint.get("fingerprint", "")) \
            != str(prepared.get("passive_source_fingerprint", "")):
        return {"success": false, "reason": "补充包被动来源已变化，请重新预览"}
    var frozen_token := _pack_preparation_token(
        growth, group, slot_index, prepared["slot"], prepared["offered"],
        run_seed, act, {
            "base_price": prepared["base_price"],
            "effective_price": prepared["effective_price"],
            "base_offer_count": prepared["base_offer_count"],
            "effective_offer_count": prepared["effective_offer_count"],
            "base_choose_count": prepared["base_choose_count"],
            "effective_choose_count": prepared["effective_choose_count"],
            "passive_source_fingerprint": prepared["passive_source_fingerprint"],
        })
    if preparation_token != frozen_token:
        return {"success": false, "reason": "补充包预览已失效，请重新预览"}
    # 候选与数量只读冻结结果；价格按正式提交前状态重新执行同一纯查询。
    var committed_price_query := resolve_price(
        growth, "consumable_pack", str(prepared["pack_id"]),
        int(prepared["base_price"]), {
            "group": group, "slot_index": slot_index,
        }, frozen_source_snapshot)
    if not committed_price_query.get("success", false):
        return committed_price_query
    var price := int(committed_price_query["effective_price"])
    if price != int(prepared["effective_price"]):
        return {"success": false, "reason": "补充包有效价格已变化，请重新预览"}
    if growth.experience < price:
        return {"success": false, "reason": "历练不足"}
    var offered: Array[String] = []
    offered.assign(prepared["offered"])
    var choose_count := int(prepared["effective_choose_count"])
    var free_slots := maxi(
        GrowthInventoryScript.CONSUMABLE_LIMIT - growth.consumable_ids.size(), 0)
    if selected_ids.size() < 1 or selected_ids.size() > choose_count:
        return {"success": false, "reason": "补充包选择数量必须在 1～%d 之间" % choose_count}
    if selected_ids.size() > free_slots:
        return {"success": false, "reason": "共享消耗品栏不足"}
    var normalized: Array[String] = []
    for value in selected_ids:
        var content_id := str(value)
        if content_id == "" or normalized.has(content_id):
            return {"success": false, "reason": "补充包选择包含空值或重复内容"}
        if not offered.has(content_id):
            return {"success": false, "reason": "补充包选择不在冻结展示候选中"}
        normalized.append(content_id)
    var working = growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立补充包事务工作副本"}
    working.experience -= price
    for content_id in normalized:
        working.consumable_ids.append(content_id)
    _clear_slot(working.practice_shop_state, group, slot_index)
    working.practice_shop_state["pack_open_sequence"] = int(prepared["sequence"]) + 1
    var event_result := _dispatch_event(
        "practice_pack_opened", working, event_values,
        frozen_source_snapshot, {
            "content_id": str(prepared["pack_id"]),
            "content_kind": "consumable_pack",
            "shop_index": int(working.practice_shop_state.get("shop_index", 0)),
            "transaction_token": "practice_pack:%d:%s:%d:%d" % [
                int(working.practice_shop_state.get("shop_index", 0)),
                str(prepared["pack_id"]), slot_index, int(prepared["sequence"])],
            "payload": {
                "selected_ids": normalized.duplicate(),
                "offered": offered.duplicate(),
                "base_price": prepared["base_price"],
                "effective_price": price,
                "base_offer_count": prepared["base_offer_count"],
                "effective_offer_count": prepared["effective_offer_count"],
                "base_choose_count": prepared["base_choose_count"],
                "effective_choose_count": prepared["effective_choose_count"],
            },
        })
    if not event_result.get("success", false):
        return event_result
    var commit_errors: Array[String] = growth.replace_mutation_state(
        working.capture_mutation_state())
    if not commit_errors.is_empty():
        _rollback_event_token(event_result)
        return {"success": false, "reason": "；".join(commit_errors)}
    _pack_preparations.erase(preparation_token)
    return {
        "success": true,
        "offered": offered,
        "selected_ids": normalized,
        "price": price,
        "base_price": prepared["base_price"],
        "effective_price": price,
        "base_offer_count": prepared["base_offer_count"],
        "effective_offer_count": prepared["effective_offer_count"],
        "base_choose_count": prepared["base_choose_count"],
        "effective_choose_count": prepared["effective_choose_count"],
        "group": group,
        "slot_index": slot_index,
        "remaining_experience": growth.experience,
        "passive_event": event_result,
    }

func meditate(
        growth,
        run_seed: int,
        act: int,
        can_open: bool,
        event_values: Dictionary = {}) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能冥想"}
    var state: Dictionary = growth.practice_shop_state
    var base_cost := int(state.get("next_meditation_cost", 5))
    var source_snapshot := _capture_sources(growth)
    var cost_query := resolve_meditation_cost(
        growth, base_cost, source_snapshot)
    if not cost_query.get("success", false):
        return cost_query
    var cost := int(cost_query["effective_cost"])
    if growth.experience < cost:
        return {"success": false, "reason": "历练不足"}
    var old_state := state.duplicate(true)
    var working = growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立冥想事务工作副本"}
    state = working.practice_shop_state
    var count := int(state.get("meditation_count", 0)) + 1
    var rng := _rng_for(run_seed, act, int(state.get("shop_index", 1)), count)
    var normal: Array = state.get(NORMAL_GROUP, []).duplicate(true)
    for index in range(normal.size()):
        if not normal[index] is Dictionary or normal[index].is_empty():
            continue
        var current_id := str(normal[index].get("id", ""))
        var excluded: Dictionary = {current_id: true}
        for occupied_value in normal:
            if occupied_value is Dictionary and not occupied_value.is_empty():
                var occupied_id := str(occupied_value.get("id", ""))
                if occupied_id != "":
                    excluded[occupied_id] = true
        var pools := _normal_category_pools(working, excluded)
        var chosen := _take_weighted_normal_candidate(pools, rng)
        if not chosen.is_empty():
            normal[index] = chosen
    working.experience -= cost
    state["meditation_count"] = count
    state["next_meditation_cost"] = base_cost + 1
    state[NORMAL_GROUP] = normal
    working.practice_shop_state = state
    var refreshed_slot_indices: Array[int] = []
    for index in range(normal.size()):
        if index < old_state.get(NORMAL_GROUP, []).size() \
                and normal[index] != old_state.get(NORMAL_GROUP, [])[index]:
            refreshed_slot_indices.append(index)
    var event_result := _dispatch_event(
        "meditation_committed", working, event_values, source_snapshot, {
            "shop_index": int(state.get("shop_index", 0)),
            "transaction_token": "meditation:%d:%d" % [
                int(state.get("shop_index", 0)), count],
            "payload": {
                "base_cost": base_cost,
                "effective_cost": cost,
                "meditation_count": count,
                "refreshed_slot_indices": refreshed_slot_indices.duplicate(),
            },
        })
    if not event_result.get("success", false):
        return event_result
    var commit_errors: Array[String] = growth.replace_mutation_state(
        working.capture_mutation_state())
    if not commit_errors.is_empty():
        _rollback_event_token(event_result)
        return {"success": false, "reason": "；".join(commit_errors)}
    return {
        "success": true,
        "cost": cost,
        "base_cost": base_cost,
        "effective_cost": cost,
        "modifier_breakdown": cost_query["modifier_breakdown"],
        "meditation_count": count,
        "experience": growth.experience,
        "previous_state": old_state,
        "refreshed_slot_indices": refreshed_slot_indices,
        "passive_event": event_result,
    }

func purchase_standalone_consumable(
        growth,
        definition: Dictionary,
        can_open: bool,
        event_values: Dictionary = {}) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能修习"}
    var content_id := str(definition.get("id", ""))
    var base_price := int(definition.get("price", -1))
    if content_id == "" or base_price < 0:
        return {"success": false, "reason": "修习商品定义无效"}
    var source_snapshot := _capture_sources(growth)
    var price_query := resolve_price(
        growth, "consumable", content_id, base_price,
        {"group": "standalone"}, source_snapshot)
    if not price_query.get("success", false):
        return price_query
    var price := int(price_query["effective_price"])
    var working = growth.create_mutation_copy()
    if working == null:
        return {"success": false, "reason": "无法建立购买事务工作副本"}
    var purchase_result: Dictionary = working.purchase_consumable(
        content_id, price, can_open)
    if not purchase_result.get("success", false):
        return purchase_result
    var event_result := _dispatch_event(
        "practice_purchase_committed", working, event_values, source_snapshot, {
            "content_id": content_id,
            "content_kind": "consumable",
            "shop_index": int(working.practice_shop_state.get("shop_index", 0)),
            "transaction_token": "practice_purchase:%d:standalone:%s" % [
                int(working.practice_shop_state.get("shop_index", 0)), content_id],
            "payload": {
                "group": "standalone",
                "base_price": base_price,
                "effective_price": price,
            },
        })
    if not event_result.get("success", false):
        return event_result
    var commit_errors: Array[String] = growth.replace_mutation_state(
        working.capture_mutation_state())
    if not commit_errors.is_empty():
        _rollback_event_token(event_result)
        return {"success": false, "reason": "；".join(commit_errors)}
    return {
        "success": true,
        "content_id": content_id,
        "kind": "consumable",
        "price": price,
        "base_price": base_price,
        "effective_price": price,
        "price_modifiers": price_query["price_modifiers"],
        "remaining_experience": growth.experience,
        "passive_event": event_result,
    }

func resolve_price(
        growth,
        subject_kind: String,
        subject_id: String,
        base_price: int,
        metadata: Dictionary = {},
        source_snapshot: Array = []) -> Dictionary:
    var resolved := _resolve_int_query(
        "practice_price_query", growth, subject_kind, subject_id,
        base_price, metadata, source_snapshot)
    if not resolved.get("success", false):
        return resolved
    if int(resolved["effective_value"]) < 0:
        return {"success": false, "reason": "修习有效价格必须是非负整数"}
    return {
        "success": true,
        "base_price": base_price,
        "effective_price": int(resolved["effective_value"]),
        "price_modifiers": resolved["modifier_breakdown"],
        "source_fingerprint": resolved["source_fingerprint"],
    }

func resolve_meditation_cost(
        growth,
        base_cost: int,
        source_snapshot: Array = []) -> Dictionary:
    var resolved := _resolve_int_query(
        "meditation_cost_query", growth, "meditation", "meditation",
        base_cost, {
            "shop_index": int(growth.practice_shop_state.get("shop_index", 0)),
            "meditation_count": int(growth.practice_shop_state.get(
                "meditation_count", 0)),
        }, source_snapshot)
    if not resolved.get("success", false):
        return resolved
    if int(resolved["effective_value"]) < 0:
        return {"success": false, "reason": "冥想有效费用必须是非负整数"}
    return {
        "success": true,
        "base_cost": base_cost,
        "effective_cost": int(resolved["effective_value"]),
        "modifier_breakdown": resolved["modifier_breakdown"],
        "source_fingerprint": resolved["source_fingerprint"],
    }

func resolve_pack_count(
        hook: String,
        growth,
        pack_id: String,
        base_value: int,
        metadata: Dictionary = {},
        source_snapshot: Array = []) -> Dictionary:
    var resolved := _resolve_int_query(
        hook, growth, "consumable_pack", pack_id,
        base_value, metadata, source_snapshot)
    if not resolved.get("success", false):
        return resolved
    if int(resolved["effective_value"]) < 0:
        return {"success": false, "reason": "补充包有效数量必须是非负整数"}
    return resolved

func _resolve_int_query(
        hook: String,
        growth,
        subject_kind: String,
        subject_id: String,
        base_value: int,
        metadata: Dictionary,
        source_snapshot: Array) -> Dictionary:
    if base_value < 0:
        return {"success": false, "reason": "%s 基础值必须是非负整数" % hook}
    if _int_policy_resolver == null:
        return {
            "success": true,
            "hook": hook,
            "base_value": base_value,
            "effective_value": base_value,
            "modifier_breakdown": [],
            "source_fingerprint": "no_runtime",
        }
    var values := {
        "hook": hook,
        "owner": growth,
        "subject_kind": subject_kind,
        "subject_id": subject_id,
        "base_value": base_value,
        "metadata": metadata,
    }
    if not source_snapshot.is_empty():
        values["source_snapshot"] = source_snapshot
    var result = _int_policy_resolver.resolve(
        IntQueryRequestScript.new().configure(values))
    var result_values: Dictionary = result.to_dict()
    if not result_values.get("success", false):
        return {
            "success": false,
            "reason": "；".join(result_values.get("errors", [])),
            "query": result_values,
        }
    return result_values

func _capture_sources(growth) -> Array:
    if _event_service == null:
        return []
    return _event_service.capture_source_snapshot(growth)

func _dispatch_event(
        hook: String,
        growth,
        event_values: Dictionary,
        source_snapshot: Array,
        specific_values: Dictionary) -> Dictionary:
    if _event_service == null or _event_state == null:
        return {
            "success": true,
            "skipped": true,
            "hook": hook,
            "transaction_token": str(specific_values.get("transaction_token", "")),
        }
    var values := event_values.duplicate(true)
    for key in specific_values:
        if key == "payload":
            var payload: Dictionary = values.get("payload", {}).duplicate(true)
            payload.merge(specific_values["payload"], true)
            values["payload"] = payload
        else:
            values[key] = specific_values[key]
    values["hook"] = hook
    values["owner"] = growth
    values["source_snapshot"] = source_snapshot
    return _event_service.dispatch(
        EventContextScript.new().configure(values), growth, _event_state)

func _rollback_event_token(event_result: Dictionary) -> void:
    if _event_state == null or bool(event_result.get("skipped", false)):
        return
    _event_state.committed_passive_event_tokens.erase(
        str(event_result.get("transaction_token", "")))

func _combined_fingerprint(values: Array) -> String:
    return JSON.stringify(values).sha256_text()

func _current_pack_source_fingerprint(
        growth,
        _frozen_snapshot: Array = []) -> Dictionary:
    if _event_service == null:
        return {"success": true, "fingerprint": _combined_fingerprint([
            "no_runtime", "no_runtime", "no_runtime"])}
    var current_values: Array = []
    for hook in [
            "practice_price_query",
            "pack_offer_count_query",
            "pack_choose_count_query"]:
        var fingerprint: Dictionary = _event_service.source_fingerprint(
            growth, [hook])
        if not fingerprint.get("success", false):
            return fingerprint
        current_values.append(str(fingerprint["fingerprint"]))
    return {"success": true, "fingerprint": _combined_fingerprint(current_values)}

func _generate_state(growth, run_seed: int, act: int, shop_index: int) -> Dictionary:
    var rng := _rng_for(run_seed, act, shop_index, 0)
    var normal_definition: Dictionary = _definition.get("normal", {})
    var normal: Array = []
    var normal_excluded: Dictionary = {}
    for _index in range(int(normal_definition.get("slot_count", 2))):
        var pools := _normal_category_pools(growth, normal_excluded)
        var chosen := _take_weighted_normal_candidate(pools, rng)
        normal.append(chosen)
        if not chosen.is_empty():
            normal_excluded[str(chosen.get("id", ""))] = true

    var pack_definition: Dictionary = _definition.get("packs", {})
    var packs: Array = []
    var pack_candidates: Array = pack_definition.get("candidates", []).duplicate(true)
    for _index in range(int(pack_definition.get("slot_count", 2))):
        packs.append(_normalized_pack_offer(_take_candidate(pack_candidates, rng)))

    var item_definition: Dictionary = _definition.get("items", {})
    var items: Array = []
    var item_candidates := _item_candidates(growth)
    for _index in range(int(item_definition.get("slot_count", 1))):
        items.append(_take_candidate(item_candidates, rng))
    return {
        "shop_index": shop_index,
        "act": act,
        "normal": normal,
        "packs": packs,
        "items": items,
        "meditation_count": 0,
        "next_meditation_cost": 5,
        "pack_open_sequence": 0,
    }

func _normal_category_pools(growth, excluded: Dictionary = {}) -> Array:
    var result: Array = []
    for category_value in _definition.get("normal", {}).get("categories", []):
        if not category_value is Dictionary:
            continue
        var category: Dictionary = category_value
        var offers: Array = []
        for candidate_value in category.get("candidate_ids", []):
            var content_id := str(candidate_value)
            if content_id == "" or excluded.has(content_id):
                continue
            var offer := _resolve_normal_offer(category, content_id)
            if offer.is_empty() or not _normal_offer_available(growth, offer):
                continue
            offers.append(offer)
        if not offers.is_empty():
            result.append({
                "weight": int(category.get("weight", 0)),
                "offers": offers,
            })
    return result

func _resolve_normal_offer(category: Dictionary, content_id: String) -> Dictionary:
    if _content_catalog == null:
        return {}
    var offer_kind := str(category.get("offer_kind", ""))
    var definition: Dictionary = _content_catalog.get_by_id(offer_kind, content_id)
    if offer_kind == "consumable":
        definition = _content_catalog.get_by_id("consumable", content_id)
    if definition.is_empty():
        return {}
    var offer := definition.duplicate(true)
    offer["kind"] = offer_kind
    if offer_kind == "consumable":
        offer["content_kind"] = str(definition.get("kind", ""))
    if offer_kind == "technique":
        offer["price"] = int(category.get("fixed_price", -1))
    else:
        offer["price"] = int(definition.get("price", -1))
    return offer

func _normal_offer_available(growth, offer: Dictionary) -> bool:
    var content_id := str(offer.get("id", ""))
    if content_id == "" or growth.practice_purchases.has(content_id):
        return false
    match str(offer.get("kind", "")):
        "technique":
            return not _growth_has_technique(growth, content_id)
        "inner_skill":
            return not growth.learned_inner_skill_ids.has(content_id)
        "consumable":
            return not _is_unique_consumable_unavailable(growth, content_id)
    return false

func _item_candidates(growth) -> Array:
    var result: Array = []
    if _content_catalog == null:
        return result
    for item_value in _definition.get("items", {}).get("candidate_ids", []):
        var item_id := str(item_value)
        var definition: Dictionary = _content_catalog.get_by_id("item", item_id)
        if definition.is_empty() or growth.practice_purchases.has(item_id):
            continue
        if bool(definition.get("unique", true)) and growth.item_ids.has(item_id):
            continue
        definition["kind"] = "item"
        definition["price"] = int(definition.get("price", -1))
        result.append(definition)
    return result

func _normalized_pack_offer(value: Dictionary) -> Dictionary:
    var result := value.duplicate(true)
    if result.is_empty():
        return result
    for field in ["price", "offer_count", "choose_count"]:
        result[field] = int(result.get(field, 0))
    return result

func _eligible_pack_candidate_ids(growth, slot: Dictionary) -> Array:
    var result: Array = []
    for candidate_value in slot.get("candidate_ids", []):
        var content_id := str(candidate_value)
        if content_id == "" or _is_unique_consumable_unavailable(growth, content_id):
            continue
        result.append(content_id)
    result.sort()
    return result

func _is_unique_consumable_unavailable(growth, content_id: String) -> bool:
    if _content_catalog == null:
        return false
    var definition: Dictionary = _content_catalog.get_by_id("consumable", content_id)
    if not bool(definition.get("unique", false)):
        return false
    return growth.consumable_ids.has(content_id) \
        or growth.used_unique_consumable_ids.has(content_id)

func _growth_has_technique(growth, technique_id: String) -> bool:
    if growth.learned_technique_ids.has(technique_id):
        return true
    for progression in growth.hand_technique_progression.values():
        if progression is Dictionary and progression.get("sequence", []).has(technique_id):
            return true
    return false

func _take_weighted_normal_candidate(
        pools: Array,
        rng: RandomNumberGenerator) -> Dictionary:
    var total_weight := 0
    for pool_value in pools:
        if pool_value is Dictionary and not pool_value.get("offers", []).is_empty():
            total_weight += maxi(int(pool_value.get("weight", 0)), 0)
    if total_weight <= 0:
        return {}
    var roll := rng.randi_range(1, total_weight)
    var chosen_pool: Dictionary = {}
    for pool_value in pools:
        if not pool_value is Dictionary or pool_value.get("offers", []).is_empty():
            continue
        roll -= maxi(int(pool_value.get("weight", 0)), 0)
        if roll <= 0:
            chosen_pool = pool_value
            break
    if chosen_pool.is_empty():
        return {}
    var offers: Array = chosen_pool.get("offers", [])
    return offers[rng.randi_range(0, offers.size() - 1)].duplicate(true)

func _take_candidate(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
    if candidates.is_empty():
        return {}
    var index := rng.randi_range(0, candidates.size() - 1)
    var value: Dictionary = candidates[index].duplicate(true)
    candidates.remove_at(index)
    return value

func _sample_ids(
        values: Array,
        count: int,
        rng: RandomNumberGenerator) -> Array[String]:
    var pool: Array = values.duplicate()
    var result: Array[String] = []
    for _index in range(mini(count, pool.size())):
        var chosen := rng.randi_range(0, pool.size() - 1)
        result.append(str(pool[chosen]))
        pool.remove_at(chosen)
    return result

func _pack_preparation_token(
        growth,
        group: String,
        slot_index: int,
        slot: Dictionary,
        offered: Array[String],
        run_seed: int,
        act: int,
        frozen_values: Dictionary = {}) -> String:
    return JSON.stringify({
        "run_seed": run_seed,
        "act": act,
        "group": group,
        "slot_index": slot_index,
        "slot": slot,
        "offered": offered,
        "experience": growth.experience,
        "consumable_ids": growth.consumable_ids,
        "item_ids": growth.item_ids,
        "learned_technique_ids": growth.learned_technique_ids,
        "learned_inner_skill_ids": growth.learned_inner_skill_ids,
        "used_unique_consumable_ids": growth.used_unique_consumable_ids,
        "practice_shop_state": growth.practice_shop_state,
        "frozen_values": frozen_values,
    }).sha256_text()

func _slot(state: Dictionary, group: String, slot_index: int) -> Dictionary:
    if group not in GROUPS:
        return {}
    var slots: Array = state.get(group, [])
    if slot_index < 0 or slot_index >= slots.size() or not slots[slot_index] is Dictionary:
        return {}
    return slots[slot_index].duplicate(true)

func _clear_slot(state: Dictionary, group: String, slot_index: int) -> void:
    var slots: Array = state.get(group, [])
    if slot_index >= 0 and slot_index < slots.size():
        slots[slot_index] = {}
        state[group] = slots

func _rng_for(
        run_seed: int,
        act: int,
        shop_index: int,
        operation_index: int) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = int(run_seed) * 1000003 \
        + int(act) * 7919 \
        + int(shop_index) * 9176 \
        + int(operation_index) * 131
    return rng

func _pack_rng_for(
        run_seed: int,
        act: int,
        shop_index: int,
        slot_index: int,
        sequence: int) -> RandomNumberGenerator:
    return _rng_for(
        run_seed, act, shop_index,
        1000 + slot_index * 37 + sequence * 101)
