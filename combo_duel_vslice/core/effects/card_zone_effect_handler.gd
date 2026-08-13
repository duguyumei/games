class_name CardZoneEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
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
        "capture_query", "swap_hands", "reorder_captured_draw_pile",
        "move_captured_to_hand",
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
            var drawn: Array = (
                runtime.ports.draw(actor, count, "technique")
                if runtime.ports != null else actor.draw(count))
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
                drawn = (
                    runtime.ports.draw(actor, int(effect.get("count", 1)), "technique")
                    if runtime.ports != null
                    else actor.draw(int(effect.get("count", 1))))
            return EffectResultScript.succeeded(
                "属性追加抽 %d 张" % drawn.size() if matches else "")
        "discard_random":
            var count: int = value_resolver.resolve(effect.get("count", {}), runtime)
            var discard_side = runtime.actor if str(effect.get("side", "actor")) == "actor" else runtime.target
            var discarded: Array = (
                runtime.ports.discard_random(discard_side, count, rng)
                if runtime.ports != null else discard_side.random_discard(count, rng))
            if effect.has("capture"):
                runtime.captures[str(effect["capture"])] = discarded
            return EffectResultScript.succeeded("随机弃 %d 张" % discarded.size())
        "discard_all_hand":
            var discard_side = runtime.actor if str(effect.get("side", "actor")) == "actor" else runtime.target
            var discarded: Array = (
                runtime.ports.discard_all(discard_side)
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
            var side = runtime.actor if str(effect.get("side", "actor")) == "actor" else runtime.target
            var hand_limit_result: Dictionary = (
                side.effective_hand_limit_result() if side != null else {"success": false})
            if not hand_limit_result.get("success", false):
                return EffectResultScript.failed("有效手牌上限查询失败")
            var wanted: int = maxi(
                0, int(hand_limit_result["effective_value"]) - side.hand.size())
            var drawn: Array = (
                runtime.ports.draw(side, wanted, "technique")
                if runtime.ports != null and side != null
                else side.draw(wanted) if side != null else [])
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
                    "qi_value": int(card.current_base_qi_value()) \
                        if card.has_method("current_base_qi_value") else int(card.qi_value),
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
        "swap_hands":
            if runtime.actor == null or runtime.target == null:
                return EffectResultScript.failed("交换手牌缺少敌我双方")
            var actor_hand: Array = runtime.actor.hand
            runtime.actor.hand = runtime.target.hand
            runtime.target.hand = actor_hand
            return EffectResultScript.succeeded("交换双方当前手牌")
        "reorder_captured_draw_pile":
            return _reorder_captured_draw_pile(effect, runtime)
    return EffectResultScript.failed("牌区处理器不支持：%s" % str(effect.get("op", "")))

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) in ["move_query", "draw_filtered", "capture_query"]:
        var query = effect.get("query")
        if not query is Dictionary:
            validator.report_error(scope + ".query", "必须是对象")
        else:
            validator.validate_target_query(query, scope + ".query")

func _move_captured(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("牌区移动缺少战斗端口")
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), []).duplicate()
    var source_side = runtime.actor if str(effect.get("from_side", "actor")) == "actor" else runtime.target
    var target_side = runtime.actor if str(effect.get("to_side", "actor")) == "actor" else runtime.target
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
        var result: Dictionary = runtime.ports.move_card(
            source_side,
            source_zone,
            target_side,
            destination_zone,
            card,
            str(effect.get("reason", "effect")),
            str(effect.get("placement", "top")),
            "technique")
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

func _reorder_captured_draw_pile(effect: Dictionary, runtime):
    var inspected: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var top_cards: Array = runtime.captures.get(str(effect.get("top_capture", "")), [])
    var bottom_first: Array = runtime.captures.get(
        str(effect.get("bottom_first_capture", "")), [])
    if inspected.is_empty() or top_cards.is_empty():
        return EffectResultScript.succeeded()
    for card in inspected:
        runtime.actor.draw_pile.erase(card)
    var top_card = top_cards[0]
    var remaining := inspected.filter(func(card): return card != top_card)
    if not bottom_first.is_empty() and remaining.has(bottom_first[0]):
        remaining.erase(bottom_first[0])
        remaining.push_front(bottom_first[0])
    for card in remaining:
        runtime.actor.draw_pile.push_front(card)
    runtime.actor.draw_pile.append(top_card)
    return EffectResultScript.succeeded("检视并重排 %d 张" % inspected.size())

func _query(effect: Dictionary, runtime) -> Dictionary:
    var query_spec: Dictionary = effect.get("query", {}).duplicate(true)
    var excluded_capture := str(query_spec.get("exclude_capture", ""))
    query_spec.erase("exclude_capture")
    if query_spec.get("limit") is Dictionary:
        query_spec["limit"] = value_resolver.resolve(query_spec["limit"], runtime)
    var filters: Dictionary = query_spec.get("filters", {}).duplicate(true)
    if filters.get("effective_qi_at_most") is Dictionary:
        filters["effective_qi_at_most"] = value_resolver.resolve(
            filters["effective_qi_at_most"], runtime)
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
