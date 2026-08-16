class_name EffectTargetQuery
extends RefCounted

const TargetQueryFieldRegistryScript = preload(
    "res://core/effects/target_query_field_registry.gd")

const SIDE_IDS := ["actor", "target", "owner", "opponent"]
const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const ORDER_IDS := [
    "zone", "left", "right", "top", "bottom", "random",
    "highest_rank", "lowest_rank", "highest_effective_qi",
    "highest_effective_qi_random_ties"]
var side_id: String = "actor"
var zone_id: String = "hand"
var order_id: String = "zone"
var limit: int = -1
var filters: Dictionary = {}
var _filters_type_valid: bool = true
var card_identity_policy = null
var field_registry = TargetQueryFieldRegistryScript.new()

func configure(spec: Dictionary):
    side_id = str(spec.get("side", "actor"))
    zone_id = str(spec.get("zone", "hand"))
    order_id = str(spec.get("order", "zone"))
    limit = int(spec.get("limit", -1))
    var filter_values = spec.get("filters", {})
    _filters_type_valid = filter_values is Dictionary
    filters = filter_values.duplicate(true) if _filters_type_valid else {}
    card_identity_policy = spec.get("card_identity_policy")
    field_registry = spec.get(
        "target_query_field_registry", TargetQueryFieldRegistryScript.new())
    return self

func validate() -> Dictionary:
    if side_id not in SIDE_IDS:
        return _invalid("未知目标阵营：%s" % side_id)
    if zone_id not in ZONE_IDS:
        return _invalid("未知目标牌区：%s" % zone_id)
    if order_id not in ORDER_IDS:
        return _invalid("未知目标顺序：%s" % order_id)
    if limit == 0 or limit < -1:
        return _invalid("目标查询 limit 必须为 -1 或正整数")
    if not _filters_type_valid:
        return _invalid("目标筛选必须是对象")
    var validation_errors: Array[String] = []
    field_registry.validate_filters(
        filters,
        func(scope: String, message: String) -> void:
            validation_errors.append("%s：%s" % [scope, message]),
        "filters")
    if not validation_errors.is_empty():
        return _invalid(validation_errors[0])
    return {"ok": true, "reason": ""}

func resolve(context, rng: RandomNumberGenerator = null) -> Dictionary:
    var check := validate()
    if not check["ok"]:
        return {"success": false, "reason": check["reason"], "cards": []}
    var side = context.resolve_side(side_id) \
        if context.has_method("resolve_side") \
        else context.actor if side_id == "actor" else context.target
    if side == null:
        return {"success": false, "reason": "目标查询缺少%s" % side_id, "cards": []}
    var cards: Array = _zone_cards(context, side)
    var matches: Array = []
    for card in cards:
        var facts = null
        if card_identity_policy != null and card_identity_policy.has_method("resolve"):
            var identity: Dictionary = card_identity_policy.resolve(card, {
                "owner": context.actor, "actor": context.actor, "target": context.target,
            })
            if not identity.get("success", false):
                return {"success": false, "reason": identity.get("reason", "卡牌身份查询失败"), "cards": []}
            facts = identity.get("facts")
        if field_registry.matches(filters, card, facts, {
                "query": self, "context": context, "side": side}):
            matches.append(card)
    matches = field_registry.apply_post_filters(
        filters, matches, {"query": self, "context": context, "side": side})
    if order_id in ["top", "right"]:
        matches.reverse()
    elif order_id == "random":
        if rng == null:
            return {"success": false, "reason": "随机目标查询缺少随机源", "cards": []}
        _shuffle(matches, rng)
    elif order_id in ["highest_rank", "lowest_rank", "highest_effective_qi",
            "highest_effective_qi_random_ties"]:
        var zone_positions: Dictionary = {}
        for index in range(cards.size()):
            zone_positions[str(cards[index].id)] = index
        matches.sort_custom(func(left, right):
            var left_value := _sort_value(left, context, side)
            var right_value := _sort_value(right, context, side)
            if left_value != right_value:
                return left_value < right_value if order_id == "lowest_rank" \
                    else left_value > right_value
            return int(zone_positions.get(str(left.id), -1)) \
                > int(zone_positions.get(str(right.id), -1)))
        if order_id == "highest_effective_qi_random_ties":
            if rng == null:
                return {"success": false, "reason": "随机并列目标查询缺少随机源", "cards": []}
            var reordered: Array = []
            var index := 0
            while index < matches.size():
                var value := _sort_value(matches[index], context, side)
                var tied: Array = []
                while index < matches.size() \
                        and _sort_value(matches[index], context, side) == value:
                    tied.append(matches[index])
                    index += 1
                _shuffle(tied, rng)
                reordered.append_array(tied)
            matches = reordered
    if limit > 0 and matches.size() > limit:
        matches = matches.slice(0, limit)
    return {
        "success": true,
        "reason": "",
        "cards": matches,
        "side": side,
        "side_id": side_id,
        "zone": zone_id,
    }

func snapshot() -> Dictionary:
    return {
        "side": side_id,
        "zone": zone_id,
        "order": order_id,
        "limit": limit,
        "filters": filters.duplicate(true),
    }

func _zone_cards(context, side) -> Array:
    if context.ports != null:
        return context.ports.zone_cards(side, zone_id)
    match zone_id:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []

func _current_effective_qi(card, context, side) -> int:
    return field_registry.current_effective_qi(
        card, {"query": self, "context": context, "side": side})

func _sort_value(card, context, side) -> int:
    if order_id in ["highest_effective_qi", "highest_effective_qi_random_ties"]:
        return _current_effective_qi(card, context, side)
    return int(card.current_rank_order()) \
        if card.has_method("current_rank_order") else int(card.rank_order)

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary

func _invalid(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}
