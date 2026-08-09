class_name PracticeService
extends RefCounted

## 正式修习商店的纯规则服务。商店状态存放在 GrowthInventory，
## 本服务只负责候选生成、确定性刷新与商品事务。

const NORMAL_GROUP := "normal"
const PACK_GROUP := "packs"
const COUPON_GROUP := "coupons"
const GROUPS := [NORMAL_GROUP, PACK_GROUP, COUPON_GROUP]
const GrowthInventoryScript = preload("res://core/growth_inventory.gd")

var _definition: Dictionary = {}
var _content_catalog

func _init(content_catalog = null) -> void:
    _content_catalog = content_catalog
    if content_catalog != null and content_catalog.loaded:
        _definition = content_catalog.definition("practice_shop")

func configure(definition: Dictionary) -> void:
    _definition = definition.duplicate(true)

func start_new_shop(growth, run_seed: int, act: int, shop_index: int) -> Dictionary:
    var state := _generate_state(growth, run_seed, act, shop_index)
    growth.practice_shop_state = state
    return state.duplicate(true)

func ensure_shop(growth, run_seed: int, act: int) -> Dictionary:
    if growth.practice_shop_state.is_empty():
        return start_new_shop(growth, run_seed, act, 1)
    return growth.practice_shop_state.duplicate(true)

func snapshot(growth, run_seed: int = 0, act: int = 1) -> Dictionary:
    ensure_shop(growth, run_seed, act)
    return growth.practice_shop_state.duplicate(true)

func purchase(growth, group: String, slot_index: int, can_open: bool) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能修习"}
    var slot := _slot(growth.practice_shop_state, group, slot_index)
    if slot.is_empty():
        return {"success": false, "reason": "修习槽位为空或已购买"}
    var price := int(slot.get("price", 0))
    if growth.experience < price:
        return {"success": false, "reason": "历练不足"}
    var content_id := str(slot.get("id", ""))
    var kind := str(slot.get("kind", ""))
    var result: Dictionary
    if kind == "technique":
        if growth.learned_technique_ids.has(content_id):
            return {"success": false, "reason": "该功法已经获得"}
        growth.experience -= price
        growth.learned_technique_ids.append(content_id)
        result = {"success": true, "content_id": content_id, "kind": kind}
    elif kind == "consumable":
        result = growth.purchase_consumable(content_id, price, can_open)
        if not result.get("success", false):
            return result
    elif kind == "coupon":
        growth.experience -= price
        result = {"success": true, "content_id": content_id, "kind": kind}
    else:
        return {"success": false, "reason": "不支持的修习商品类型：%s" % kind}
    _clear_slot(growth.practice_shop_state, group, slot_index)
    result["price"] = price
    result["group"] = group
    result["slot_index"] = slot_index
    return result

func open_pack(
        growth,
        group: String,
        slot_index: int,
        selected_ids: Array,
        can_open: bool,
        rng: RandomNumberGenerator = null) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能修习"}
    if group != PACK_GROUP:
        return {"success": false, "reason": "只有补充包栏可以打开补充包"}
    var slot := _slot(growth.practice_shop_state, group, slot_index)
    if slot.is_empty() or str(slot.get("kind", "")) != "insight_pack":
        return {"success": false, "reason": "补充包槽位为空或已打开"}
    var price := int(slot.get("price", 0))
    if growth.experience < price:
        return {"success": false, "reason": "历练不足"}
    var candidate_ids: Array = slot.get("candidate_ids", []).duplicate()
    var offered: Array[String] = _sample_ids(candidate_ids, int(slot.get("offer_count", 0)), rng)
    if selected_ids.is_empty():
        return {
            "success": true,
            "preview": offered,
            "choose_count": int(slot.get("choose_count", 1)),
            "price": price,
            "group": group,
            "slot_index": slot_index,
        }
    var choose_count := int(slot.get("choose_count", 1))
    if selected_ids.size() > choose_count:
        return {"success": false, "reason": "补充包选择数量超过上限"}
    for value in selected_ids:
        if not offered.has(str(value)):
            return {"success": false, "reason": "补充包选择不在展示候选中"}
    if growth.consumable_ids.size() + selected_ids.size() > GrowthInventoryScript.CONSUMABLE_LIMIT:
        return {"success": false, "reason": "共享消耗品栏不足"}
    growth.experience -= price
    for value in selected_ids:
        growth.consumable_ids.append(str(value))
    _clear_slot(growth.practice_shop_state, group, slot_index)
    return {
        "success": true,
        "offered": offered,
        "selected_ids": selected_ids.duplicate(),
        "price": price,
        "group": group,
        "slot_index": slot_index,
    }

func meditate(growth, run_seed: int, act: int, can_open: bool) -> Dictionary:
    if not can_open:
        return {"success": false, "reason": "当前节点进行中不能冥想"}
    var state: Dictionary = growth.practice_shop_state
    var cost := int(state.get("next_meditation_cost", 5))
    if growth.experience < cost:
        return {"success": false, "reason": "历练不足"}
    var old_state := state.duplicate(true)
    growth.experience -= cost
    var count := int(state.get("meditation_count", 0)) + 1
    state["meditation_count"] = count
    state["next_meditation_cost"] = cost + 1
    var rng := _rng_for(run_seed, act, int(state.get("shop_index", 1)), count)
    var normal: Array = state.get(NORMAL_GROUP, [])
    for index in range(normal.size()):
        if not normal[index] is Dictionary or normal[index].is_empty():
            continue
        var candidates := _normal_candidates(growth)
        var current_id := str(normal[index].get("id", ""))
        var occupied: Dictionary = {}
        for occupied_value in normal:
            if occupied_value is Dictionary:
                var occupied_id := str(occupied_value.get("id", ""))
                if occupied_id != "" and occupied_id != current_id:
                    occupied[occupied_id] = true
        candidates = candidates.filter(func(value):
            var candidate_id := str(value.get("id", ""))
            return candidate_id != current_id and not occupied.has(candidate_id))
        if candidates.is_empty():
            continue
        var chosen: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
        normal[index] = chosen
    state[NORMAL_GROUP] = normal
    growth.practice_shop_state = state
    return {
        "success": true,
        "cost": cost,
        "meditation_count": count,
        "experience": growth.experience,
        "previous_state": old_state,
    }

func _generate_state(growth, run_seed: int, act: int, shop_index: int) -> Dictionary:
    var rng := _rng_for(run_seed, act, shop_index, 0)
    var candidates := _normal_candidates(growth)
    var normal: Array = []
    for _index in range(int(_definition.get("normal_slots", 2))):
        normal.append(_take_candidate(candidates, rng))
    var packs: Array = []
    var pack_candidates: Array = _definition.get("pack_candidates", []).duplicate(true)
    for _index in range(int(_definition.get("pack_slots", 2))):
        packs.append(_take_candidate(pack_candidates, rng))
    var coupons: Array = []
    var coupon_candidates: Array = _definition.get("coupon_candidates", []).duplicate(true)
    for _index in range(int(_definition.get("coupon_slots", 1))):
        coupons.append(_take_candidate(coupon_candidates, rng))
    return {
        "shop_index": shop_index,
        "act": act,
        "normal": normal,
        "packs": packs,
        "coupons": coupons,
        "meditation_count": 0,
        "next_meditation_cost": 5,
    }

func _normal_candidates(growth = null) -> Array:
    var result: Array = _definition.get("normal_candidates", []).duplicate(true)
    if growth == null:
        return result
    return result.filter(func(value):
        return (
            str(value.get("kind", "")) != "technique"
            or not _growth_has_technique(growth, str(value.get("id", ""))))
    )

func _growth_has_technique(growth, technique_id: String) -> bool:
    if growth.learned_technique_ids.has(technique_id):
        return true
    for progression in growth.hand_technique_progression.values():
        if progression is Dictionary and progression.get("sequence", []).has(technique_id):
            return true
    return false

func _take_candidate(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
    if candidates.is_empty():
        return {}
    var index := rng.randi_range(0, candidates.size() - 1)
    var value: Dictionary = candidates[index].duplicate(true)
    candidates.remove_at(index)
    return value

func _sample_ids(values: Array, count: int, rng: RandomNumberGenerator) -> Array[String]:
    var pool: Array = values.duplicate()
    var result: Array[String] = []
    for _index in range(mini(count, pool.size())):
        var chosen := 0 if rng == null else rng.randi_range(0, pool.size() - 1)
        result.append(str(pool[chosen]))
        pool.remove_at(chosen)
    return result

func _slot(state: Dictionary, group: String, slot_index: int) -> Dictionary:
    if not GROUPS.has(group):
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
