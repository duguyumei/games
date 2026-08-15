class_name EffectTargetQuery
extends RefCounted

const TargetQueryFieldCatalogScript = preload(
    "res://core/effects/target_query_field_catalog.gd")

const SIDE_IDS := ["actor", "target"]
const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const ORDER_IDS := [
    "zone", "left", "right", "top", "bottom", "random",
    "highest_rank", "lowest_rank", "highest_effective_qi",
    "highest_effective_qi_random_ties"]
const CARD_KIND_IDS := ["any", "normal"]

var side_id: String = "actor"
var zone_id: String = "hand"
var order_id: String = "zone"
var limit: int = -1
var filters: Dictionary = {}
var _filters_type_valid: bool = true
var card_identity_policy = null

func configure(spec: Dictionary):
    side_id = str(spec.get("side", "actor"))
    zone_id = str(spec.get("zone", "hand"))
    order_id = str(spec.get("order", "zone"))
    limit = int(spec.get("limit", -1))
    var filter_values = spec.get("filters", {})
    _filters_type_valid = filter_values is Dictionary
    filters = filter_values.duplicate(true) if _filters_type_valid else {}
    card_identity_policy = spec.get("card_identity_policy")
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
    var unknown_fields := TargetQueryFieldCatalogScript.unknown_fields(filters)
    if not unknown_fields.is_empty():
        return _invalid("未知目标筛选字段：%s" % ",".join(unknown_fields))
    var card_kind := str(filters.get("card_kind", "any"))
    if card_kind not in CARD_KIND_IDS:
        return _invalid("未知真气种类筛选：%s" % card_kind)
    for field in [
            "attributes", "exclude_attributes", "base_attributes",
            "exclude_base_attributes", "rank_names", "rank_orders",
            "exclude_rank_orders", "definition_ids"]:
        if filters.has(field) and not filters[field] is Array:
            return _invalid("目标筛选 %s 必须是数组" % field)
    if filters.has("anomaly"):
        var anomaly = filters["anomaly"]
        if not anomaly is Dictionary:
            return _invalid("异状筛选必须是对象")
        if str(anomaly.get("category", "")) not in ["buff", "debuff", "state", "mark"]:
            return _invalid("异状筛选缺少合法 category")
    if filters.has("anomalies"):
        if not filters["anomalies"] is Array:
            return _invalid("多异状筛选必须是数组")
        for anomaly in filters["anomalies"]:
            if not anomaly is Dictionary \
                    or str(anomaly.get("category", "")) not in ["buff", "debuff", "state", "mark"]:
                return _invalid("多异状筛选包含非法项")
    if filters.has("reshape"):
        var reshape = filters["reshape"]
        if not reshape is Dictionary:
            return _invalid("重塑筛选必须是对象")
        if str(reshape.get("category", "")) not in [
                "origin", "enhancement", "imprint", "other",
                "temporary_enhancement", "temporary_attribute", "temporary_rank"]:
            return _invalid("重塑筛选缺少合法 category")
    return {"ok": true, "reason": ""}

func resolve(context, rng: RandomNumberGenerator = null) -> Dictionary:
    var check := validate()
    if not check["ok"]:
        return {"success": false, "reason": check["reason"], "cards": []}
    var side = context.actor if side_id == "actor" else context.target
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
        if _matches(card, facts, context, side):
            matches.append(card)
    if bool(filters.get("duplicate_rank", false)):
        var rank_counts: Dictionary = {}
        for card in matches:
            var order := int(card.current_rank_order())
            rank_counts[order] = int(rank_counts.get(order, 0)) + 1
        matches = matches.filter(func(card):
            return int(rank_counts.get(card.current_rank_order(), 0)) > 1)
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

func _matches(card, facts = null, context = null, side = null) -> bool:
    var card_kind := str(filters.get("card_kind", "any"))
    if card_kind == "normal" and not (facts.is_card_kind("normal") if facts != null else card.is_card_kind("normal")):
        return false
    if filters.has("attributes"):
        var matches_attribute := false
        for attribute in filters["attributes"]:
            if _card_has_attribute(card, str(attribute), facts):
                matches_attribute = true
                break
        if not matches_attribute:
            return false
    if filters.has("exclude_attributes"):
        for attribute in filters["exclude_attributes"]:
            if _card_has_attribute(card, str(attribute), facts):
                return false
    var base_attribute := str(card.attribute)
    if filters.has("base_attributes") \
            and not filters["base_attributes"].has(base_attribute):
        return false
    if filters.has("exclude_base_attributes") \
            and filters["exclude_base_attributes"].has(base_attribute):
        return false
    var rank_name: String = str(facts.rank_name) if facts != null else card.current_rank_name() \
        if card.has_method("current_rank_name") else str(card.rank_name)
    var rank_order: int = int(facts.rank_order) if facts != null else card.current_rank_order() \
        if card.has_method("current_rank_order") else int(card.rank_order)
    var definition_id: String = card.current_definition_id() \
        if card.has_method("current_definition_id") else str(card.definition_id)
    if filters.has("rank_names") and not filters["rank_names"].has(rank_name):
        return false
    if filters.has("rank_orders") and not filters["rank_orders"].has(rank_order):
        return false
    if filters.has("exclude_rank_orders") and filters["exclude_rank_orders"].has(rank_order):
        return false
    if filters.has("definition_ids") and not filters["definition_ids"].has(definition_id):
        return false
    if filters.has("temporary") and bool(filters["temporary"]) != bool(card.temporary_card):
        return false
    if filters.has("has_any_anomaly"):
        var anomaly_snapshot: Dictionary = card.anomaly_snapshot()
        var has_any_anomaly := false
        for values in anomaly_snapshot.values():
            has_any_anomaly = has_any_anomaly or not values.is_empty()
        if has_any_anomaly != bool(filters["has_any_anomaly"]):
            return false
    if filters.has("has_any_reshape"):
        var has_reshape: bool = card.has_any_reshape_storage() \
            if card.has_method("has_any_reshape_storage") else (
                not card.reshape_origin.is_empty()
                or card.reshape_enhancement != ""
                or card.reshape_imprint != ""
                or not card.reshape_others.is_empty())
        if has_reshape != bool(filters["has_any_reshape"]):
            return false
    if filters.has("has_permanent_reshape"):
        var permanent: bool = (
            not card.reshape_origin.is_empty()
            or card.reshape_enhancement != ""
            or card.reshape_imprint != ""
            or not card.reshape_others.is_empty())
        if permanent != bool(filters["has_permanent_reshape"]):
            return false
    if filters.has("has_active_permanent_reshape"):
        var active_permanent: bool = not card.return_to_origin_active() and (
            not card.reshape_origin.is_empty()
            or card.reshape_enhancement != ""
            or card.reshape_imprint != ""
            or not card.reshape_others.is_empty())
        if active_permanent != bool(filters["has_active_permanent_reshape"]):
            return false
    if filters.has("has_active_any_reshape"):
        var active_any: bool = not card.return_to_origin_active() and (
            not card.reshape_origin.is_empty()
            or card.reshape_enhancement != ""
            or card.reshape_imprint != ""
            or not card.reshape_others.is_empty()
            or str(card.temporary_reshapes.get("enhancement", "")) != ""
            or str(card.temporary_reshapes.get("attribute", "")) != ""
            or not card.temporary_reshapes.get("rank", {}).is_empty())
        if active_any != bool(filters["has_active_any_reshape"]):
            return false
    if filters.has("effective_qi_at_most"):
        var effective := _current_effective_qi(card, context, side)
        if effective > int(filters["effective_qi_at_most"]):
            return false
    if filters.has("effective_above_base"):
        var effective := _current_effective_qi(card, context, side)
        var base := int(card.current_base_qi_value()) \
            if card.has_method("current_base_qi_value") else int(card.qi_value)
        if (effective > base) != bool(filters["effective_above_base"]):
            return false
    if filters.has("effective_qi_at_least"):
        if _current_effective_qi(card, context, side) < int(filters["effective_qi_at_least"]):
            return false
    if filters.has("anomaly_layers_at_least"):
        var layer_spec: Dictionary = filters["anomaly_layers_at_least"]
        if card.anomaly_layers(str(layer_spec.get("category", "buff")), \
                str(layer_spec.get("id", ""))) < int(layer_spec.get("value", 1)):
            return false
    if filters.has("has_non_attribute_identity"):
        var excluded := str(filters["has_non_attribute_identity"])
        var found_other := false
        for attribute in ["wind", "forest", "fire", "mountain"]:
            if attribute != excluded and _card_has_attribute(card, attribute, facts):
                found_other = true
                break
        if not found_other:
            return false
    if bool(filters.get("explicit_discard_allowed", false)) \
            and (context == null or context.ports == null or side == null \
            or not context.ports.can_explicit_discard(
                side, card).get("allowed", false)):
        return false
    if filters.has("can_apply_anomaly"):
        var apply_spec: Dictionary = filters["can_apply_anomaly"]
        if context == null or context.ports == null \
                or not context.ports.can_apply_card_anomaly(
                    card,
                    str(apply_spec.get("category", "")),
                    str(apply_spec.get("id", "")),
                    bool(apply_spec.get("replace_state", false))).get(
                        "allowed", false):
            return false
    if filters.has("anomaly") and not _matches_anomaly(card, filters["anomaly"]):
        return false
    for anomaly in filters.get("anomalies", []):
        if not _matches_anomaly(card, anomaly):
            return false
    if filters.has("reshape") and not _matches_reshape(card, filters["reshape"]):
        return false
    return true

func _current_effective_qi(card, context, side) -> int:
    if context != null and context.ports != null and side != null:
        return int(context.ports.current_effective_qi(side, card))
    return int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value)

func _sort_value(card, context, side) -> int:
    if order_id in ["highest_effective_qi", "highest_effective_qi_random_ties"]:
        return _current_effective_qi(card, context, side)
    return int(card.current_rank_order()) \
        if card.has_method("current_rank_order") else int(card.rank_order)

func _card_has_attribute(card, attribute: String, facts = null) -> bool:
    if facts != null:
        return bool(facts.has_attribute(attribute))
    if card_identity_policy != null and card_identity_policy.has_method("resolve"):
        var resolved: Dictionary = card_identity_policy.resolve(card, {})
        if resolved.get("success", false):
            return bool(resolved["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func _matches_anomaly(card, spec: Dictionary) -> bool:
    var present: bool = bool(spec.get("present", true))
    var actual: bool = card.has_anomaly(
        str(spec.get("category", "")),
        str(spec.get("id", "")))
    return actual == present

func _matches_reshape(card, spec: Dictionary) -> bool:
    var category: String = str(spec.get("category", ""))
    var reshape_id: String = str(spec.get("id", ""))
    var actual: bool = false
    match category:
        "origin":
            actual = not card.reshape_origin.is_empty() \
                and (reshape_id == "" or str(card.reshape_origin.get("id", "")) == reshape_id)
        "enhancement":
            actual = card.reshape_enhancement != "" \
                and (reshape_id == "" or card.reshape_enhancement == reshape_id)
        "imprint":
            actual = card.reshape_imprint != "" \
                and (reshape_id == "" or card.reshape_imprint == reshape_id)
        "other":
            actual = not card.reshape_others.is_empty() \
                if reshape_id == "" else card.reshape_others.has(reshape_id)
        "temporary_enhancement":
            var temporary_enhancement := str(card.temporary_reshapes.get("enhancement", ""))
            actual = temporary_enhancement != "" \
                and (reshape_id == "" or temporary_enhancement == reshape_id)
        "temporary_attribute":
            var temporary_attribute := str(card.temporary_reshapes.get("attribute", ""))
            actual = temporary_attribute != "" \
                and (reshape_id == "" or temporary_attribute == reshape_id)
        "temporary_rank":
            var temporary_rank = card.temporary_reshapes.get("rank", {})
            actual = not temporary_rank.is_empty() \
                and (reshape_id == "" \
                    or str(temporary_rank.get("rank_name", "")) == reshape_id)
    return actual == bool(spec.get("present", true))

func _shuffle(cards: Array, rng: RandomNumberGenerator) -> void:
    for index in range(cards.size() - 1, 0, -1):
        var other := rng.randi_range(0, index)
        var temporary = cards[index]
        cards[index] = cards[other]
        cards[other] = temporary

func _invalid(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}
