class_name CardZoneEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const TargetQueryScript = preload("res://core/effects/effect_target_query.gd")

var value_resolver
var rng: RandomNumberGenerator

func _init(resolver, random_source: RandomNumberGenerator) -> void:
    value_resolver = resolver
    rng = random_source

func operation_ids() -> Array[String]:
    return [
        "draw", "draw_if_captured_attribute", "discard_random", "discard_all_hand",
        "move_captured", "move_query", "draw_filtered", "draw_to_limit",
        "capture_metadata",
        "capture_query", "reorder_captured_draw_pile",
        "move_captured_to_hand", "atomic_exchange_captured",
        "synchronous_discard_queries", "discard_duplicate_ranks",
        "discard_by_visible_attribute", "draw_common_attribute_or_fallback",
        "discard_captured_by_selected_base_attribute", "dissipate_captured",
        "consume_captured",
        "atomic_transfer_captures", "draw_rank_different_replacements",
    ]

func group_name() -> String:
    return "card_zone"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    var actor = runtime.actor
    if actor == null:
        return EffectResultScript.failed("牌区处理器缺少行动方")
    match str(effect.get("op", "")):
        "draw":
            var count: int = value_resolver.resolve(effect.get("count", {}), runtime)
            var draw_side = _resolve_side(runtime, str(effect.get("side", "actor")))
            if draw_side == null:
                return EffectResultScript.failed("抽牌目标不存在")
            var drawn: Array = (
                runtime.ports.draw(draw_side, count, runtime.source_metadata())
                if runtime.ports != null
                else draw_side.draw(count, "effect_draw", runtime.source_metadata()))
            if effect.has("capture"):
                runtime.captures[effect["capture"]] = drawn
            return EffectResultScript.succeeded("抽 %d 张" % drawn.size())
        "draw_if_captured_attribute":
            var captured: Array = runtime.captures.get(effect.get("capture", ""), [])
            var matches := false
            for card in captured:
                if card.is_attribute(str(effect.get("attribute", ""))):
                    matches = true
                    break
            var drawn: Array = []
            if matches:
                var draw_side = _resolve_side(
                    runtime, str(effect.get("side", "actor")))
                if draw_side == null:
                    return EffectResultScript.failed("属性追加抽牌目标不存在")
                drawn = (
                    runtime.ports.draw(
                        draw_side, int(effect.get("count", 1)),
                        runtime.source_metadata())
                    if runtime.ports != null
                    else draw_side.draw(
                        int(effect.get("count", 1)), "effect_draw",
                        runtime.source_metadata()))
            return EffectResultScript.succeeded(
                "属性追加抽 %d 张" % drawn.size() if matches else "")
        "discard_random":
            var count: int = value_resolver.resolve(effect.get("count", {}), runtime)
            var discard_side = _resolve_side(runtime, str(effect.get("side", "actor")))
            var discarded: Array = (
                runtime.ports.discard_random(
                    discard_side, count, rng, runtime.source_metadata())
                if runtime.ports != null else discard_side.random_discard(count, rng))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = discarded
            return EffectResultScript.succeeded("随机弃 %d 张" % discarded.size())
        "discard_all_hand":
            var discard_side = _resolve_side(runtime, str(effect.get("side", "actor")))
            var discarded: Array = (
                runtime.ports.discard_all(
                    discard_side, runtime.source_metadata())
                if runtime.ports != null else discard_side.discard_all())
            runtime.captures[effect.get("capture", "discarded")] = discarded
            return EffectResultScript.succeeded(
                "弃掉全部剩余手牌 %d 张" % discarded.size())
        "move_captured":
            return _move_captured(effect, runtime)
        "move_captured_to_hand":
            var moved_effect := effect.duplicate(true)
            moved_effect["op"] = "move_captured"
            moved_effect["to_zone"] = "hand"
            return _move_captured(moved_effect, runtime)
        "move_query":
            return _move_query(effect, runtime)
        "draw_filtered":
            return _draw_filtered(effect, runtime)
        "draw_to_limit":
            var side = _resolve_side(runtime, str(effect.get("side", "actor")))
            var drawn: Array = side.draw_to_limit(
                "effect_draw", runtime.source_metadata()) if side != null else []
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = drawn
            return EffectResultScript.succeeded("补至手牌上限：%d 张" % drawn.size())
        "capture_metadata":
            var snapshots: Array = []
            for card in runtime.captures.get(str(effect.get("capture", "")), []):
                var attributes: Array = []
                for attribute in ["wind", "forest", "fire", "mountain"]:
                    if card.is_attribute(attribute):
                        attributes.append(attribute)
                snapshots.append({
                    "card": card,
                    "id": str(card.id),
                    "qi_value": runtime.ports.current_effective_qi(runtime.actor, card),
                    "effective_qi": runtime.ports.current_effective_qi(runtime.actor, card),
                    "base_qi": int(card.current_base_qi_value()) \
                        if card.has_method("current_base_qi_value") else int(card.qi_value),
                    "card_base_qi": int(card.qi_value),
                    "rank_name": str(card.current_rank_name()),
                    "rank_order": int(card.current_rank_order()),
                    "base_attribute": str(card.attribute),
                    "growth_layers": card.anomaly_layers("buff", "growth"),
                    "heat_layers": card.anomaly_layers("buff", "qi_heat"),
                    "had_poison": card.has_anomaly("state", "poison"),
                    "attributes": attributes,
                    "state": card.current_state() \
                        if card.has_method("current_state") else {},
                })
            runtime.captures[str(effect.get("result_capture", "card_metadata"))] = snapshots
            return EffectResultScript.succeeded("记录真气快照 %d 张" % snapshots.size())
        "capture_query":
            var query_result := _query(effect, runtime)
            if not query_result.get("success", false):
                return EffectResultScript.failed(str(query_result.get("reason", "牌区查询失败")))
            runtime.captures[str(effect.get("capture", "queried_cards"))] = query_result["cards"]
            return EffectResultScript.succeeded("捕获牌区真气 %d 张" % query_result["cards"].size())
        "reorder_captured_draw_pile":
            return _reorder_captured_draw_pile(effect, runtime)
        "atomic_exchange_captured":
            return _atomic_exchange_captured(effect, runtime)
        "synchronous_discard_queries":
            return _synchronous_discard_queries(effect, runtime)
        "discard_duplicate_ranks":
            return _discard_duplicate_ranks(effect, runtime)
        "discard_by_visible_attribute":
            return _discard_by_visible_attribute(effect, runtime)
        "draw_common_attribute_or_fallback":
            return _draw_common_attribute_or_fallback(effect, runtime)
        "discard_captured_by_selected_base_attribute":
            return _discard_captured_by_selected_base_attribute(effect, runtime)
        "dissipate_captured":
            var dissipated: Array = []
            for card in runtime.captures.get(str(effect.get("capture", "")), []).duplicate():
                var location: Dictionary = runtime.ports.locate_active_card(str(card.id))
                if not location.get("success", false):
                    continue
                var result: Dictionary = runtime.ports.temporarily_remove_card(
                    location["side"], str(card.id),
                    str(effect.get("reason", "effect_dissipate")),
                    runtime.source_metadata())
                if result.get("success", false):
                    dissipated.append(card)
            runtime.captures[str(effect.get("result_capture", "dissipated"))] = dissipated
            return EffectResultScript.succeeded("消散真气 %d 张" % dissipated.size())
        "consume_captured":
            return _consume_captured(effect, runtime)
        "atomic_transfer_captures":
            return _atomic_transfer_captures(effect, runtime)
        "draw_rank_different_replacements":
            return _draw_rank_different_replacements(effect, runtime)
    return EffectResultScript.failed("牌区处理器不支持：%s" % str(effect.get("op", "")))

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

func _resolve_side(runtime, side_key: String):
    return runtime.resolve_side(side_key)

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) in ["move_query", "draw_filtered", "capture_query"]:
        var query = effect.get("query")
        if not query is Dictionary:
            validator.report_error(scope + ".query", "必须是对象")
        else:
            validator.validate_target_query(query, scope + ".query")
    if str(effect.get("op", "")) == "synchronous_discard_queries":
        for index in range(effect.get("queries", []).size()):
            validator.validate_target_query(
                effect.get("queries", [])[index], "%s.queries[%d]" % [scope, index])
    if str(effect.get("op", "")) == "draw_rank_different_replacements" \
            and str(effect.get("metadata_capture", "")) == "":
        validator.report_error(scope + ".metadata_capture", "必须提供冻结牌阶元数据capture")
    if str(effect.get("op", "")) == "consume_captured":
        if str(effect.get("capture", "")) == "":
            validator.report_error(scope + ".capture", "必须提供待消耗真气capture")
        for field in ["minimum_count", "exact_count"]:
            if effect.has(field) and (not effect[field] is int or int(effect[field]) < 0):
                validator.report_error(scope + "." + field, "必须为非负整数")
        if effect.has("require_all") and not effect["require_all"] is bool:
            validator.report_error(scope + ".require_all", "必须为布尔值")


func _consume_captured(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("真气消耗缺少战斗端口")
    var side = _resolve_side(runtime, str(effect.get("side", "actor")))
    if side == null:
        return EffectResultScript.failed("真气消耗持有者不存在")
    var capture_id := str(effect.get("capture", ""))
    var cards: Array = runtime.captures.get(capture_id, []).duplicate()
    var minimum_count := int(effect.get("minimum_count", 0))
    var exact_count := int(effect.get("exact_count", -1))
    if bool(effect.get("require_all", false)):
        exact_count = cards.size()
        minimum_count = cards.size()
    var operation_token := str(effect.get("operation_token", ""))
    if operation_token == "":
        operation_token = "%s:consume:%s:%s" % [
            runtime.action_token if runtime.action_token != "" else "effect",
            runtime.source_instance_key,
            capture_id]
    var metadata: Dictionary = runtime.source_metadata()
    metadata.merge({
        "operation_token": operation_token,
        "minimum_count": minimum_count,
        "exact_count": exact_count,
        "action_token": runtime.action_token,
        "root_action_token": runtime.root_action_token,
        "execution_token": runtime.technique_execution_token,
        "technique_execution_token": runtime.technique_execution_token,
        "invocation_token": runtime.invocation_token,
    }, true)
    var prepared: Dictionary = runtime.ports.prepare_qi_consumption(
        side, cards, metadata)
    if not prepared.get("success", false):
        return EffectResultScript.failed(str(prepared.get(
            "reason", "真气消耗准备失败")))
    var committed: Dictionary = runtime.ports.commit_qi_consumption(
        prepared, metadata)
    if not committed.get("success", false):
        return EffectResultScript.failed(str(committed.get(
            "reason", "真气消耗提交失败")))
    runtime.captures[str(effect.get(
        "result_capture", "consumed_qi"))] = committed.get(
            "cards", []).duplicate()
    return EffectResultScript.succeeded(
        "消耗真气 %d 张" % int(committed.get("consumption_batch_size", 0)))

func _move_captured(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("牌区移动缺少战斗端口")
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), []).duplicate()
    var source_side = _resolve_side(runtime, str(effect.get("from_side", "actor")))
    var target_side = _resolve_side(runtime, str(effect.get("to_side", "actor")))
    var source_zone := str(effect.get("from_zone", "hand"))
    var destination_zone := str(effect.get("to_zone", "discard_pile"))
    var moved: Array = []
    var ordered_cards := cards.duplicate()
    if str(effect.get("order", "zone")) == "random":
        for index in range(ordered_cards.size() - 1, 0, -1):
            var other := rng.randi_range(0, index)
            var temporary = ordered_cards[index]
            ordered_cards[index] = ordered_cards[other]
            ordered_cards[other] = temporary
    var limit_value = effect.get("limit", -1)
    var limit: int = value_resolver.resolve(limit_value, runtime) if limit_value is Dictionary else int(limit_value)
    if limit >= 0 and ordered_cards.size() > limit:
        ordered_cards = ordered_cards.slice(0, limit)
    if destination_zone == "draw_pile" and str(effect.get("placement", "top")) == "top" \
            and bool(effect.get("preserve_selection_order", false)):
        ordered_cards.reverse()
    for card in ordered_cards:
        if str(effect.get("reason", "effect")) == "explicit_discard" \
                and not runtime.ports.can_explicit_discard(
                    source_side, card).get("allowed", false):
            continue
        var result: Dictionary = runtime.ports.move_card(
            source_side,
            source_zone,
            target_side,
            destination_zone,
            card,
            str(effect.get("reason", "effect")),
            str(effect.get("placement", "top")),
            runtime.source_metadata())
        if result.get("success", false):
            moved.append(card)
    if effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = moved
    if bool(effect.get("shuffle_destination", false)) and destination_zone == "draw_pile":
        target_side.card_zone_service.shuffle(target_side.draw_pile, rng)
    return EffectResultScript.succeeded("移动真气 %d 张" % moved.size())

func _move_query(effect: Dictionary, runtime):
    var query_result := _query(effect, runtime)
    if not query_result.get("success", false):
        return EffectResultScript.failed(str(query_result.get("reason", "牌区查询失败")))
    var capture_key := str(effect.get("capture", "queried_cards"))
    runtime.captures[capture_key] = query_result["cards"]
    var move_effect := effect.duplicate(true)
    move_effect["capture"] = capture_key
    move_effect["from_side"] = str(effect.get("query", {}).get("side", "actor"))
    move_effect["from_zone"] = str(effect.get("query", {}).get("zone", "hand"))
    return _move_captured(move_effect, runtime)

func _draw_filtered(effect: Dictionary, runtime):
    var query_effect := effect.duplicate(true)
    var query: Dictionary = query_effect.get("query", {}).duplicate(true)
    query["zone"] = "draw_pile"
    query_effect["query"] = query
    query_effect["to_side"] = str(query.get("side", "actor"))
    query_effect["to_zone"] = "hand"
    query_effect["reason"] = "draw"
    return _move_query(query_effect, runtime)

func _draw_rank_different_replacements(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("替换抽牌缺少战斗端口")
    var side = _resolve_side(runtime, str(effect.get("side", "actor")))
    if side == null:
        return EffectResultScript.failed("替换抽牌目标不存在")
    var drawn: Array = []
    for frozen_value in runtime.captures.get(
            str(effect.get("metadata_capture", "")), []):
        if not frozen_value is Dictionary:
            continue
        var query_result := _query({"query": {
            "side": str(effect.get("side", "actor")),
            "zone": "draw_pile", "order": "random", "limit": 1,
            "filters": {
                "card_kind": "normal",
                "exclude_rank_orders": [int(frozen_value.get("rank_order", -1))],
            },
        }}, runtime)
        if not query_result.get("success", false):
            return EffectResultScript.failed(str(
                query_result.get("reason", "替换抽牌查询失败")))
        if query_result.get("cards", []).is_empty():
            continue
        var card = query_result["cards"][0]
        var moved: Dictionary = runtime.ports.move_card(
            side, "draw_pile", side, "hand", card, "draw", "top",
            runtime.source_metadata())
        if moved.get("success", false):
            drawn.append(card)
    runtime.captures[str(effect.get("capture", "drawn"))] = drawn
    return EffectResultScript.succeeded("逐张替换抽牌 %d 张" % drawn.size())

func _reorder_captured_draw_pile(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("重排牌库缺少战斗端口")
    var inspected: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var ordered: Array = runtime.captures.get(str(effect.get("ordered_capture", "")), [])
    var side = _resolve_side(runtime, str(effect.get("side", "actor")))
    if side == null:
        return EffectResultScript.failed("重排牌库缺少持有者")
    var before: Array = runtime.ports.zone_cards(side, "draw_pile").duplicate()
    var replacement: Array = before.duplicate()
    if not ordered.is_empty():
        var valid := ordered.size() == inspected.size()
        for card in inspected:
            valid = valid and ordered.has(card) and replacement.has(card)
        if not valid:
            return EffectResultScript.failed("重排选择与展示集合不一致")
        for card in inspected:
            replacement.erase(card)
        for index in range(ordered.size() - 1, -1, -1):
            replacement.append(ordered[index])
        var reordered: Dictionary = runtime.ports.reorder_draw_pile(
            side, before, replacement)
        if not reordered.get("success", false):
            return EffectResultScript.failed(str(reordered.get(
                "reason", "牌库重排失败")))
        return EffectResultScript.succeeded("重排牌库顶 %d 张" % inspected.size())
    var top_cards: Array = runtime.captures.get(str(effect.get("top_capture", "")), [])
    var bottom_first: Array = runtime.captures.get(
        str(effect.get("bottom_first_capture", "")), [])
    if inspected.is_empty() or top_cards.is_empty():
        return EffectResultScript.succeeded()
    for card in inspected:
        if not replacement.has(card):
            return EffectResultScript.failed("展示牌已离开牌库")
        replacement.erase(card)
    var top_card = top_cards[0]
    if not inspected.has(top_card):
        return EffectResultScript.failed("置顶选择不属于展示集合")
    var remaining := inspected.filter(func(card): return card != top_card)
    if not bottom_first.is_empty() and remaining.has(bottom_first[0]):
        remaining.erase(bottom_first[0])
        remaining.push_front(bottom_first[0])
    for card in remaining:
        replacement.push_front(card)
    replacement.append(top_card)
    var reordered: Dictionary = runtime.ports.reorder_draw_pile(
        side, before, replacement)
    if not reordered.get("success", false):
        return EffectResultScript.failed(str(reordered.get(
            "reason", "牌库重排失败")))
    return EffectResultScript.succeeded("检视并重排 %d 张" % inspected.size())

func _query(effect: Dictionary, runtime) -> Dictionary:
    var query_spec: Dictionary = effect.get("query", {}).duplicate(true)
    var excluded_capture := str(query_spec.get("exclude_capture", ""))
    query_spec.erase("exclude_capture")
    if query_spec.get("limit") is Dictionary:
        query_spec["limit"] = value_resolver.resolve(query_spec["limit"], runtime)
    var filters: Dictionary = query_spec.get("filters", {}).duplicate(true)
    for value_field in ["effective_qi_at_most", "effective_qi_at_least"]:
        if filters.get(value_field) is Dictionary:
            filters[value_field] = value_resolver.resolve(filters[value_field], runtime)
    query_spec["filters"] = filters
    query_spec["card_identity_policy"] = runtime.card_identity_policy
    var result: Dictionary = TargetQueryScript.new().configure(query_spec).resolve(runtime, rng)
    if result.get("success", false) and excluded_capture != "":
        var excluded_ids: Dictionary = {}
        for card in runtime.captures.get(excluded_capture, []):
            excluded_ids[str(card.id if not card is Dictionary else card.get("id", ""))] = true
        result["cards"] = result["cards"].filter(
            func(card): return not excluded_ids.has(str(card.id)))
    return result

func _atomic_exchange_captured(effect: Dictionary, runtime):
    var actor_cards: Array = runtime.captures.get(str(effect.get("actor_capture", "")), [])
    var target_cards: Array = runtime.captures.get(str(effect.get("target_capture", "")), [])
    if actor_cards.is_empty() or target_cards.is_empty():
        return EffectResultScript.succeeded()
    var result: Dictionary = runtime.ports.atomic_exchange_cards(
        runtime.actor, str(effect.get("actor_zone", "hand")), actor_cards[0],
        runtime.target, str(effect.get("target_zone", "draw_pile")), target_cards[0],
        runtime.source_metadata())
    if effect.has("actor_received_capture"):
        runtime.captures[str(effect["actor_received_capture"])] = \
            [target_cards[0]] if result.get("success", false) else []
    if effect.has("target_received_capture"):
        runtime.captures[str(effect["target_received_capture"])] = \
            [actor_cards[0]] if result.get("success", false) else []
    return EffectResultScript.succeeded("原子交换1张真气") \
        if result.get("success", false) else EffectResultScript.failed(
            str(result.get("reason", "原子交换失败")))

func _atomic_transfer_captures(effect: Dictionary, runtime):
    var source_side = _resolve_side(runtime, str(effect.get("from_side", "actor")))
    var target_side = _resolve_side(runtime, str(effect.get("to_side", "target")))
    if source_side == null or target_side == null or source_side == target_side:
        return EffectResultScript.failed("原子跨阵营转移缺少不同的双方")
    var records: Array = []
    var seen: Dictionary = {}
    for source_value in effect.get("sources", []):
        var source: Dictionary = source_value
        var source_zone := str(source.get("zone", "hand"))
        for card in runtime.captures.get(str(source.get("capture", "")), []):
            if seen.has(str(card.id)):
                continue
            seen[str(card.id)] = true
            records.append({
                "source_side": source_side, "target_side": target_side,
                "source_zone": source_zone,
                "destination_zone": str(effect.get("to_zone", "draw_pile")),
                "card": card,
                "reason": str(effect.get("reason", "temporary_transfer")),
            })
    var moved: Array = runtime.ports.transfer_cards_atomically(
        records, runtime.source_metadata())
    if bool(effect.get("shuffle_destination", false)) \
            and str(effect.get("to_zone", "draw_pile")) == "draw_pile" \
            and not moved.is_empty():
        runtime.ports.shuffle_zone(target_side, "draw_pile", rng)
    runtime.captures[str(effect.get("result_capture", "transferred"))] = moved
    return EffectResultScript.succeeded("原子转移真气 %d 张" % moved.size())

func _synchronous_discard_queries(effect: Dictionary, runtime):
    var records: Array = []
    var frozen: Array = []
    for query_value in effect.get("queries", []):
        var query_effect := {"query": query_value}
        var resolved := _query(query_effect, runtime)
        if not resolved.get("success", false):
            return EffectResultScript.failed(str(resolved.get("reason", "同步弃置查询失败")))
        for card in resolved.get("cards", []):
            if frozen.has(card) or not runtime.ports.can_explicit_discard(
                    resolved["side"], card).get("allowed", false):
                continue
            frozen.append(card)
            records.append({
                "side": resolved["side"], "source_zone": str(query_value.get("zone", "hand")),
                "destination_zone": "discard_pile", "card": card,
                "reason": "explicit_discard",
            })
    var moved: Array = runtime.ports.move_cards_synchronously(
        records, runtime.source_metadata())
    runtime.captures[str(effect.get("capture", "synchronously_discarded"))] = moved
    return EffectResultScript.succeeded("同步弃置%d张真气" % moved.size())

func _discard_duplicate_ranks(effect: Dictionary, runtime):
    var side = _resolve_side(runtime, str(effect.get("side", "target")))
    var groups: Dictionary = {}
    for card in side.hand:
        var rank := int(card.current_rank_order())
        if not groups.has(rank):
            groups[rank] = []
        groups[rank].append(card)
    var records: Array = []
    for cards_value in groups.values():
        var cards: Array = cards_value
        if cards.size() < 2:
            continue
        var keep = cards[rng.randi_range(0, cards.size() - 1)]
        for card in cards:
            if card != keep and runtime.ports.can_explicit_discard(side, card).get("allowed", false):
                records.append({"side": side, "source_zone": "hand",
                    "destination_zone": "discard_pile", "card": card,
                    "reason": "explicit_discard"})
    var moved: Array = runtime.ports.move_cards_synchronously(
        records, runtime.source_metadata())
    runtime.captures[str(effect.get("capture", "discarded"))] = moved
    return EffectResultScript.succeeded("重复牌阶弃置%d张" % moved.size())

func _discard_by_visible_attribute(effect: Dictionary, runtime):
    var side = _resolve_side(runtime, str(effect.get("side", "target")))
    var attributes := ["wind", "forest", "fire", "mountain"]
    var selected := ""
    var mode := str(effect.get("mode", "random"))
    if mode == "most_common":
        var counts: Dictionary = {}
        var maximum := -1
        for attribute in attributes:
            var count := 0
            for card in side.hand:
                if card.is_attribute(attribute):
                    count += 1
            counts[attribute] = count
            maximum = maxi(maximum, count)
        var tied: Array = attributes.filter(func(attribute): return counts[attribute] == maximum)
        selected = str(tied[rng.randi_range(0, tied.size() - 1)]) if not tied.is_empty() else ""
    else:
        selected = str(attributes[rng.randi_range(0, attributes.size() - 1)])
    var records: Array = []
    for card in side.hand.duplicate():
        if selected != "" and card.is_attribute(selected) \
                and runtime.ports.can_explicit_discard(side, card).get("allowed", false):
            records.append({"side": side, "source_zone": "hand",
                "destination_zone": "discard_pile", "card": card,
                "reason": "explicit_discard"})
    var moved: Array = runtime.ports.move_cards_synchronously(
        records, runtime.source_metadata())
    runtime.captures[str(effect.get("capture", "discarded"))] = moved
    runtime.captures[str(effect.get("attribute_capture", "selected_attribute"))] = \
        [{"attribute": selected}]
    return EffectResultScript.succeeded("按%s属性弃置%d张" % [selected, moved.size()])

func _draw_common_attribute_or_fallback(effect: Dictionary, runtime):
    var common := ["wind", "forest", "fire", "mountain"]
    var played: Array = runtime.group_snapshot.get("played_cards", runtime.played_cards)
    for card in played:
        common = common.filter(func(attribute): return card.is_attribute(attribute))
    var candidates: Array = runtime.actor.draw_pile.filter(func(card):
        if not card.is_card_kind("normal"):
            return false
        for attribute in common:
            if card.is_attribute(attribute):
                return true
        return false)
    var selected = null
    if not candidates.is_empty():
        selected = candidates[rng.randi_range(0, candidates.size() - 1)]
    elif not runtime.actor.draw_pile.is_empty():
        selected = runtime.actor.draw_pile.back()
    var moved: Array = []
    if selected != null:
        var result: Dictionary = runtime.ports.move_card(
            runtime.actor, "draw_pile", runtime.actor, "hand", selected,
            "draw", "top", runtime.source_metadata())
        if result.get("success", false):
            moved.append(selected)
    runtime.captures[str(effect.get("capture", "drawn"))] = moved
    return EffectResultScript.succeeded("同属性定向抽牌%d张" % moved.size())

func _discard_captured_by_selected_base_attribute(effect: Dictionary, runtime):
    var candidates: Array = runtime.captures.get(
        str(effect.get("capture", "")), []).duplicate()
    var selected_cards: Array = runtime.captures.get(
        str(effect.get("selected_capture", "")), [])
    var source_side = _resolve_side(runtime, str(effect.get("side", "target")))
    if source_side == null or selected_cards.is_empty():
        runtime.captures[str(effect.get("result_capture", "discarded"))] = []
        return EffectResultScript.succeeded()
    var selected_attribute := str(selected_cards[0].attribute)
    var records: Array = []
    for card in candidates:
        if str(card.attribute) != selected_attribute \
                or not source_side.draw_pile.has(card) \
                or not runtime.ports.can_explicit_discard(
                    source_side, card).get("allowed", false):
            continue
        records.append({
            "side": source_side,
            "source_zone": "draw_pile",
            "destination_zone": "discard_pile",
            "card": card,
            "reason": "explicit_discard",
        })
    var moved: Array = runtime.ports.move_cards_synchronously(
        records, runtime.source_metadata())
    runtime.captures[str(effect.get("result_capture", "discarded"))] = moved
    runtime.captures[str(effect.get("attribute_capture", "selected_attribute"))] = [{
        "attribute": selected_attribute,
    }]
    return EffectResultScript.succeeded(
        "展示牌按%s基础属性弃置%d张" % [selected_attribute, moved.size()])
