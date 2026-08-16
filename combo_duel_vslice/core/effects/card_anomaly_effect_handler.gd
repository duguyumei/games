class_name CardAnomalyEffectHandler
extends EffectHandler

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")
const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver
var rng: RandomNumberGenerator
var lifecycle

func _init(resolver, random_source: RandomNumberGenerator, content_catalog = null) -> void:
    value_resolver = resolver
    rng = random_source
    if content_catalog != null:
        lifecycle = CardStateLifecycleScript.new(content_catalog)

func operation_ids() -> Array[String]:
    return [
        "apply_random_card_anomaly", "apply_card_anomaly_to_captured",
        "apply_temporary_reshape_to_captured",
        "apply_temporary_rank_from_capture",
        "clear_temporary_reshape_from_captured",
        "apply_anomaly_from_query",
        "transfer_card_anomaly",
    ]

func group_name() -> String:
    return "card_anomaly"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if lifecycle == null:
        return EffectResultScript.failed("异状处理器缺少内容目录")
    if str(effect.get("op", "")) == "apply_temporary_reshape_to_captured":
        return _apply_temporary_reshape(effect, runtime)
    if str(effect.get("op", "")) == "apply_temporary_rank_from_capture":
        return _apply_temporary_rank_from_capture(effect, runtime)
    if str(effect.get("op", "")) == "clear_temporary_reshape_from_captured":
        return _clear_temporary_reshape(effect, runtime)
    if str(effect.get("op", "")) == "apply_card_anomaly_to_captured":
        return _apply_to_captured(effect, runtime)
    if str(effect.get("op", "")) == "apply_anomaly_from_query":
        var resolved_query := _resolved_query(effect.get("query", {}), runtime)
        if int(resolved_query.get("limit", -1)) == 0:
            runtime.captures[str(effect.get("capture", "anomaly_targets"))] = []
            return EffectResultScript.succeeded()
        var query_result: Dictionary = runtime.ports.query_effect_targets(
            runtime, resolved_query, rng)
        if not query_result.get("success", false):
            return EffectResultScript.failed(str(query_result.get("reason", "异状目标查询失败")))
        runtime.captures[str(effect.get("capture", "anomaly_targets"))] = query_result["cards"]
        var apply_effect := effect.duplicate(true)
        apply_effect["op"] = "apply_card_anomaly_to_captured"
        apply_effect["capture"] = str(effect.get("capture", "anomaly_targets"))
        return _apply_to_captured(apply_effect, runtime)
    if str(effect.get("op", "")) == "transfer_card_anomaly":
        var sources: Array = runtime.captures.get(
            str(effect.get("source_capture", "")), [])
        var targets: Array = runtime.captures.get(
            str(effect.get("target_capture", "")), [])
        if sources.is_empty() or targets.is_empty():
            if effect.has("result_capture"):
                runtime.captures[str(effect["result_capture"])] = []
            return EffectResultScript.succeeded()
        var transferred: Dictionary = runtime.ports.transfer_card_anomaly(
            sources[0], targets[0], str(effect.get("category", "")),
            str(effect.get("anomaly", "")),
            runtime.source_name if runtime.source_name != "" else "效果", {
                "source_actor": runtime.actor,
                "target": runtime.target,
                "action_token": runtime.action_token,
                "technique_id": runtime.technique_id,
                "source_kind": runtime.source_kind,
                "source_id": runtime.source_id,
                "source_name": runtime.source_name,
                "source_instance_key": runtime.source_instance_key,
                "trigger_mode": runtime.trigger_mode,
            })
        if effect.has("result_capture"):
            runtime.captures[str(effect["result_capture"])] = \
                [targets[0]] if transferred.get("success", false) else []
        return EffectResultScript.succeeded("转移异状") \
            if transferred.get("success", false) \
            else EffectResultScript.failed(str(transferred.get("reason", "异状转移失败")))
    var target = runtime.target
    if target == null:
        return EffectResultScript.failed("异状处理器缺少目标")
    var zone: String = effect.get("zone", "hand")
    var category: String = effect.get("category", "")
    var anomaly_id: String = effect.get("anomaly", "")
    var replace_state := bool(effect.get("replace_state", false))
    var source_cards: Array = (
        runtime.ports.zone_cards(target, zone)
        if runtime.ports != null
        else _zone_cards(target, zone))
    var candidates: Array = []
    for card in source_cards:
        var permission: Dictionary = runtime.ports.can_apply_card_anomaly(
            card, category, anomaly_id, replace_state) \
            if runtime.ports != null else lifecycle.can_apply_anomaly(
                card, category, anomaly_id, replace_state)
        if permission.get("allowed", true):
            candidates.append(card)
    var applied: Array = []
    var wanted := mini(value_resolver.resolve(effect.get("count", 1), runtime), candidates.size())
    for _index in range(wanted):
        var chosen_index := rng.randi_range(0, candidates.size() - 1)
        var chosen = candidates.pop_at(chosen_index)
        var result: Dictionary = (
            runtime.ports.apply_card_anomaly(
                chosen,
                category,
                anomaly_id,
                effect.get("payload", {}),
                runtime.source_name if runtime.source_name != "" else "效果",
                _layers(effect, runtime),
                replace_state, {
                    "source_actor": runtime.actor,
                    "target": runtime.target,
                    "action_token": runtime.action_token,
                    "technique_id": runtime.technique_id,
                    "source_kind": runtime.source_kind,
                    "source_id": runtime.source_id,
                    "source_name": runtime.source_name,
                    "source_instance_key": runtime.source_instance_key,
                    "trigger_mode": runtime.trigger_mode,
                })
            if runtime.ports != null
            else lifecycle.apply_anomaly(
                chosen, category, anomaly_id, effect.get("payload", {}),
                _layers(effect, runtime), replace_state))
        if not result.get("success", false):
            return EffectResultScript.failed(str(result.get("reason", "异状施加失败")))
        applied.append(chosen)
    if effect.has("capture"):
        runtime.captures[effect["capture"]] = applied
    return EffectResultScript.succeeded(
        "%s获得%s：%d 张" % [zone, anomaly_id, applied.size()])

func summarize(_effect: Dictionary, _context, _intent: Dictionary, _state: Dictionary) -> void:
    pass

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if effect.has("replace_state") and not effect["replace_state"] is bool:
        validator.report_error(scope + ".replace_state", "必须是布尔值")
    if effect.has("payload") and not effect["payload"] is Dictionary:
        validator.report_error(scope + ".payload", "必须是对象")
    if effect.has("layers"):
        if effect["layers"] is Dictionary:
            validator.validate_amount_spec(effect["layers"], scope + ".layers")
        else:
            validator.validate_positive_integer(effect["layers"], scope + ".layers", "layers")
    if str(effect.get("op", "")) in [
            "apply_temporary_reshape_to_captured",
            "apply_temporary_rank_from_capture",
            "clear_temporary_reshape_from_captured"]:
        return
    if str(effect.get("op", "")) == "transfer_card_anomaly":
        validator.validate_anomaly_reference(effect, scope)
        return
    if str(effect.get("op", "")) == "apply_anomaly_from_query":
        if not effect.get("query") is Dictionary:
            validator.report_error(scope + ".query", "必须是对象")
        else:
            validator.validate_target_query(effect["query"], scope + ".query")
    if not effect.has("random_options"):
        validator.validate_anomaly_reference(effect, scope)

func _apply_to_captured(effect: Dictionary, runtime):
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var applied: Array = []
    for card in cards:
        var anomaly_id := str(effect.get("anomaly", ""))
        var category := str(effect.get("category", ""))
        if effect.has("random_options"):
            var options: Array = []
            for option_value in effect["random_options"]:
                var option: Dictionary = option_value
                var option_category := str(option.get("category", category))
                var option_id := str(option.get("anomaly", ""))
                if runtime.ports.can_apply_card_anomaly(
                        card, option_category, option_id,
                        bool(effect.get("replace_state", false))).get("allowed", true):
                    options.append(option)
            if options.is_empty():
                continue
            var option: Dictionary = options[rng.randi_range(0, options.size() - 1)]
            anomaly_id = str(option.get("anomaly", ""))
            category = str(option.get("category", category))
        elif not runtime.ports.can_apply_card_anomaly(
                card, category, anomaly_id,
                bool(effect.get("replace_state", false))).get("allowed", true):
            continue
        var result: Dictionary = runtime.ports.apply_card_anomaly(
            card,
            category,
            anomaly_id,
            effect.get("payload", {}),
            runtime.source_name if runtime.source_name != "" else "效果",
            _layers(effect, runtime),
            bool(effect.get("replace_state", false)), {
                "source_actor": runtime.actor,
                "target": runtime.target,
                "action_token": runtime.action_token,
                "technique_id": runtime.technique_id,
                "source_kind": runtime.source_kind,
                "source_id": runtime.source_id,
                "source_name": runtime.source_name,
                "source_instance_key": runtime.source_instance_key,
                "trigger_mode": runtime.trigger_mode,
            })
        if result.get("success", false):
            applied.append(card)
    if effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = applied
    return EffectResultScript.succeeded("施加异状 %d 张" % applied.size())

func _apply_temporary_reshape(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("临时重塑缺少战斗端口")
    var subslot := str(effect.get("subslot", ""))
    var reshape_id := str(effect.get("reshape", ""))
    var applied := 0
    for card in runtime.captures.get(str(effect.get("capture", "")), []):
        var resolved_reshape_id := reshape_id
        if subslot == "attribute" and reshape_id == "random_other_base":
            var candidates := ["wind", "forest", "fire", "mountain"]
            candidates.erase(str(card.attribute))
            resolved_reshape_id = candidates[rng.randi_range(0, candidates.size() - 1)]
        var result: Dictionary = (
            runtime.ports.apply_temporary_enhancement(card, resolved_reshape_id)
            if subslot == "enhancement"
            else runtime.ports.apply_temporary_attribute(card, resolved_reshape_id)
            if subslot == "attribute" else {"success": false})
        if result.get("success", false):
            applied += 1
    return EffectResultScript.succeeded("施加临时重塑 %d 张" % applied)

func _apply_temporary_rank_from_capture(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("临时牌阶缺少战斗端口")
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var source_cards: Array = runtime.captures.get(
        str(effect.get("source_capture", "")), [])
    var target = cards[0] if not cards.is_empty() else null
    var source = source_cards[0] if not source_cards.is_empty() else null
    if bool(effect.get("ordered_pair", false)) and cards.size() >= 2:
        target = cards[0]
        source = cards[1]
    if target == null:
        return EffectResultScript.succeeded()
    var rank_name := ""
    var rank_order := 0
    var base_qi := 0
    if str(effect.get("mode", "copy_current")) == "random_adjacent":
        var wanted_order := int(target.current_rank_order())
        wanted_order += 1 if wanted_order <= 2 else -1 if wanted_order >= 14 \
            else [-1, 1][rng.randi_range(0, 1)]
        var base_deck = JSON.parse_string(FileAccess.get_file_as_string(
            "res://data/base_deck.json"))
        for value in base_deck.get("ranks", []) if base_deck is Dictionary else []:
            if int(value.get("order", 0)) == wanted_order:
                rank_name = str(value.get("id", ""))
                rank_order = wanted_order
                base_qi = int(value.get("qi", 0))
                break
    elif source != null:
        rank_name = str(source.current_rank_name())
        rank_order = int(source.current_rank_order())
        base_qi = int(source.current_base_qi_value())
    var result: Dictionary = runtime.ports.apply_temporary_rank(
        target, rank_name, rank_order, base_qi)
    if result.get("success", false) and effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = [target]
    return EffectResultScript.succeeded("施加临时牌阶" \
        if result.get("success", false) else "")

func _clear_temporary_reshape(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("临时重塑清除缺少战斗端口")
    var cleared := 0
    var cleared_cards: Array = []
    for card in runtime.captures.get(str(effect.get("capture", "")), []):
        var subslot := str(effect.get("subslot", ""))
        var result: Dictionary = runtime.ports.clear_all_temporary_reshapes(card) \
            if subslot == "all" else runtime.ports.clear_temporary_reshape(card, subslot)
        var removed = result.get("removed")
        var changed := false
        if removed is Dictionary:
            for value in removed.values():
                changed = changed or str(value) != ""
        else:
            changed = str(removed) != ""
        if result.get("success", false) and changed:
            cleared += 1
            cleared_cards.append(card)
    if effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = cleared_cards
    return EffectResultScript.succeeded("清除临时重塑 %d 张" % cleared)

func _layers(effect: Dictionary, runtime) -> int:
    var value = effect.get("layers", effect.get("amount", 1))
    return maxi(1, value_resolver.resolve(value, runtime)) \
        if value is Dictionary else maxi(1, int(value))

func _resolved_query(value: Dictionary, runtime) -> Dictionary:
    var query := value.duplicate(true)
    if query.get("limit") is Dictionary:
        query["limit"] = value_resolver.resolve(query["limit"], runtime)
    var filters: Dictionary = query.get("filters", {}).duplicate(true)
    for value_field in ["effective_qi_at_most", "effective_qi_at_least"]:
        if filters.get(value_field) is Dictionary:
            filters[value_field] = value_resolver.resolve(filters[value_field], runtime)
    query["filters"] = filters
    return query

func _zone_cards(side, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []
