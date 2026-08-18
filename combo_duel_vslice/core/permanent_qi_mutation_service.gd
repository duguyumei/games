class_name PermanentQiMutationService
extends RefCounted

## RunDeck 与 BattleSide 共用的永久真气状态转换算法。
##
## 本服务只接收和返回持久真气快照，不持有牌组、战斗或事件服务，也不修改
## QiCard。调用边界负责在自己的事务工作副本中应用返回的 after 快照。

const ADVANCE_RANK_CYCLE := "advance_rank_cycle"


func advance_rank_cycle(
        before_value: Dictionary,
        base_deck_definition: Dictionary,
        reshape_id: String,
        reshape_payload: Dictionary = {}) -> Dictionary:
    if before_value.is_empty():
        return _failure("永久真气变更缺少 before 快照")
    if reshape_id == "":
        return _failure("永久真气牌阶前进缺少重塑·其他 ID")
    var attribute := str(before_value.get("attribute", ""))
    if attribute == "":
        return _failure("永久真气牌阶前进缺少基础属性")
    var ranks_result := _ordered_ranks(base_deck_definition)
    if not ranks_result.get("success", false):
        return ranks_result
    var ranks: Array = ranks_result["ranks"]
    var current_index := _rank_index(
        ranks,
        int(before_value.get("rank_order", 0)),
        str(before_value.get("rank_name", "")))
    if current_index < 0:
        return _failure("永久真气当前牌阶不属于基础牌阶序列")
    var next_rank: Dictionary = ranks[(current_index + 1) % ranks.size()]
    var after := before_value.duplicate(true)
    after["definition_id"] = "%s_%s" % [attribute, str(next_rank["id"])]
    after["rank_name"] = str(next_rank["id"])
    after["rank_order"] = int(next_rank["order"])
    after["qi_value"] = int(next_rank["qi"])
    var reshapes: Dictionary = after.get("reshapes", {}).duplicate(true)
    var others: Dictionary = reshapes.get("others", {}).duplicate(true)
    others[reshape_id] = reshape_payload.duplicate(true)
    reshapes["others"] = others
    after["reshapes"] = reshapes
    var changes := _rank_cycle_changes(before_value, after, reshape_id)
    return {
        "success": true,
        "changed": not changes.is_empty(),
        "mutation_kind": ADVANCE_RANK_CYCLE,
        "before": before_value.duplicate(true),
        "after": after,
        "changes": changes,
    }


func stable_fingerprint(value) -> String:
    return JSON.stringify(_stable_value(value)).sha256_text()


func _ordered_ranks(base_deck_definition: Dictionary) -> Dictionary:
    var rank_values = base_deck_definition.get("ranks")
    if not rank_values is Array or rank_values.is_empty():
        return _failure("基础牌阶序列缺失")
    var ranks: Array = []
    var seen_ids: Dictionary = {}
    var seen_orders: Dictionary = {}
    for rank_value in rank_values:
        if not rank_value is Dictionary:
            return _failure("基础牌阶定义必须是对象")
        var rank: Dictionary = rank_value
        var rank_id := str(rank.get("id", ""))
        var rank_order := int(rank.get("order", 0))
        if rank_id == "" or rank_order <= 0 or int(rank.get("qi", -1)) < 0:
            return _failure("基础牌阶定义缺少稳定 id/order/qi")
        if seen_ids.has(rank_id) or seen_orders.has(rank_order):
            return _failure("基础牌阶序列包含重复 id 或 order")
        seen_ids[rank_id] = true
        seen_orders[rank_order] = true
        ranks.append(rank.duplicate(true))
    ranks.sort_custom(func(left, right):
        return int(left.get("order", 0)) < int(right.get("order", 0)))
    return {"success": true, "ranks": ranks}


func _rank_index(ranks: Array, rank_order: int, rank_name: String) -> int:
    for index in range(ranks.size()):
        var rank: Dictionary = ranks[index]
        if int(rank.get("order", 0)) == rank_order \
                and str(rank.get("id", "")) == rank_name:
            return index
    return -1


func _rank_cycle_changes(
        before: Dictionary,
        after: Dictionary,
        reshape_id: String) -> Array:
    var changes: Array = []
    for field in ["definition_id", "rank_name", "rank_order", "qi_value"]:
        if before.get(field) == after.get(field):
            continue
        changes.append({
            "domain": "base_identity",
            "field": field,
            "change_kind": "updated",
            "before": _duplicate_value(before.get(field)),
            "after": _duplicate_value(after.get(field)),
        })
    var before_others: Dictionary = before.get(
        "reshapes", {}).get("others", {})
    var after_others: Dictionary = after.get(
        "reshapes", {}).get("others", {})
    var before_has := before_others.has(reshape_id)
    var after_has := after_others.has(reshape_id)
    var before_reshape = before_others.get(reshape_id)
    var after_reshape = after_others.get(reshape_id)
    if before_has != after_has or before_reshape != after_reshape:
        changes.append({
            "domain": "permanent_reshape",
            "category": "other",
            "field": "reshapes.others.%s" % reshape_id,
            "content_id": reshape_id,
            "change_kind": "added" if not before_has else "updated",
            "before": _duplicate_value(before_reshape) if before_has else null,
            "after": _duplicate_value(after_reshape) if after_has else null,
        })
    return changes


func _stable_value(value):
    if value is Dictionary:
        var result: Array = []
        var keys: Array = value.keys()
        keys.sort_custom(func(left, right): return str(left) < str(right))
        for key in keys:
            result.append([str(key), _stable_value(value[key])])
        return result
    if value is Array:
        return value.map(func(entry): return _stable_value(entry))
    return value


func _duplicate_value(value):
    return value.duplicate(true) if value is Dictionary or value is Array else value


func _failure(reason: String) -> Dictionary:
    return {"success": false, "reason": reason}
