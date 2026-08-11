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
        "clear_temporary_reshape_from_captured",
    ]

func group_name() -> String:
    return "card_anomaly"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if lifecycle == null:
        return EffectResultScript.failed("异状处理器缺少内容目录")
    if str(effect.get("op", "")) == "apply_temporary_reshape_to_captured":
        return _apply_temporary_reshape(effect, runtime)
    if str(effect.get("op", "")) == "clear_temporary_reshape_from_captured":
        return _clear_temporary_reshape(effect, runtime)
    if str(effect.get("op", "")) == "apply_card_anomaly_to_captured":
        return _apply_to_captured(effect, runtime)
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
                runtime.technique_name if runtime.technique_name != "" else "功法",
                _layers(effect, runtime),
                replace_state)
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
            "clear_temporary_reshape_from_captured"]:
        return
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
            runtime.technique_name if runtime.technique_name != "" else "功法",
            _layers(effect, runtime),
            bool(effect.get("replace_state", false)))
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
        var result: Dictionary = (
            runtime.ports.apply_temporary_enhancement(card, reshape_id)
            if subslot == "enhancement"
            else runtime.ports.apply_temporary_attribute(card, reshape_id)
            if subslot == "attribute" else {"success": false})
        if result.get("success", false):
            applied += 1
    return EffectResultScript.succeeded("施加临时重塑 %d 张" % applied)

func _clear_temporary_reshape(effect: Dictionary, runtime):
    if runtime.ports == null:
        return EffectResultScript.failed("临时重塑清除缺少战斗端口")
    var cleared := 0
    for card in runtime.captures.get(str(effect.get("capture", "")), []):
        if runtime.ports.clear_temporary_reshape(
                card, str(effect.get("subslot", ""))).get("success", false):
            cleared += 1
    return EffectResultScript.succeeded("清除临时重塑 %d 张" % cleared)

func _layers(effect: Dictionary, runtime) -> int:
    var value = effect.get("layers", effect.get("amount", 1))
    return maxi(1, value_resolver.resolve(value, runtime)) \
        if value is Dictionary else maxi(1, int(value))

func _zone_cards(side, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []
