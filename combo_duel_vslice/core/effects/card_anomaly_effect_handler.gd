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
    return ["apply_random_card_anomaly", "apply_card_anomaly_to_captured"]

func group_name() -> String:
    return "card_anomaly"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if lifecycle == null:
        return EffectResultScript.failed("异状处理器缺少内容目录")
    if str(effect.get("op", "")) == "apply_card_anomaly_to_captured":
        return _apply_to_captured(effect, runtime)
    var target = runtime.target
    if target == null:
        return EffectResultScript.failed("异状处理器缺少目标")
    var zone: String = effect.get("zone", "hand")
    var category: String = effect.get("category", "")
    var anomaly_id: String = effect.get("anomaly", "")
    var source_cards: Array = (
        runtime.ports.zone_cards(target, zone)
        if runtime.ports != null
        else _zone_cards(target, zone))
    var candidates: Array = []
    for card in source_cards:
        if card.reshape_enhancement != "stone":
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
                {},
                runtime.technique_name if runtime.technique_name != "" else "功法")
            if runtime.ports != null
            else lifecycle.apply_anomaly(chosen, category, anomaly_id))
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
    if not effect.has("random_options"):
        validator.validate_anomaly_reference(effect, scope)

func _apply_to_captured(effect: Dictionary, runtime):
    var cards: Array = runtime.captures.get(str(effect.get("capture", "")), [])
    var applied: Array = []
    for card in cards:
        if card.reshape_enhancement == "stone":
            continue
        var anomaly_id := str(effect.get("anomaly", ""))
        var category := str(effect.get("category", ""))
        if effect.has("random_options"):
            var options: Array = effect["random_options"]
            if options.is_empty():
                continue
            var option: Dictionary = options[rng.randi_range(0, options.size() - 1)]
            anomaly_id = str(option.get("anomaly", ""))
            category = str(option.get("category", category))
        var result: Dictionary = runtime.ports.apply_card_anomaly(
            card,
            category,
            anomaly_id,
            {},
            runtime.technique_name if runtime.technique_name != "" else "功法")
        if result.get("success", false):
            applied.append(card)
    if effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = applied
    return EffectResultScript.succeeded("施加异状 %d 张" % applied.size())

func _zone_cards(side, zone: String) -> Array:
    match zone:
        "hand": return side.hand.duplicate()
        "draw_pile": return side.draw_pile.duplicate()
        "staging": return side.staging.duplicate()
        "discard_pile": return side.discard_pile.duplicate()
    return []
