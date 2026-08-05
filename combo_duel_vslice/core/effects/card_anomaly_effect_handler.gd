class_name CardAnomalyEffectHandler
extends RefCounted

const CardStateLifecycleScript = preload("res://core/card_state_lifecycle.gd")

var value_resolver
var rng: RandomNumberGenerator
var lifecycle

func _init(resolver, random_source: RandomNumberGenerator, content_catalog = null) -> void:
    value_resolver = resolver
    rng = random_source
    if content_catalog != null:
        lifecycle = CardStateLifecycleScript.new(content_catalog)

func operation_ids() -> Array[String]:
    return ["apply_random_card_anomaly"]

func group_name() -> String:
    return "card_anomaly"

func execute(effect: Dictionary, context: Dictionary) -> Dictionary:
    if lifecycle == null:
        return {"success": false, "detail": "异状处理器缺少内容目录"}
    var target = context["target"]
    var zone: String = effect.get("zone", "hand")
    var category: String = effect.get("category", "")
    var anomaly_id: String = effect.get("anomaly", "")
    var source_cards: Array = []
    match zone:
        "hand": source_cards = target.hand
        "draw_pile": source_cards = target.draw_pile
        "discard_pile": source_cards = target.discard_pile
    var candidates: Array = []
    for card in source_cards:
        if card.reshape_enhancement != "stone":
            candidates.append(card)
    var applied: Array = []
    var wanted := mini(value_resolver.resolve(effect.get("count", 1), context), candidates.size())
    for _index in range(wanted):
        var chosen_index := rng.randi_range(0, candidates.size() - 1)
        var chosen = candidates.pop_at(chosen_index)
        var status_system = context.get("engine").status_system \
            if context.get("engine") != null else null
        var result: Dictionary = (
            status_system.apply_card_anomaly(
                chosen,
                category,
                anomaly_id,
                {},
                context.get("technique_name", "功法"))
            if status_system != null
            else lifecycle.apply_anomaly(chosen, category, anomaly_id))
        if not result.get("success", false):
            return {"success": false, "detail": str(result.get("reason", "异状施加失败"))}
        applied.append(chosen)
    if effect.has("capture"):
        context["captures"][effect["capture"]] = applied
    return {"success": true, "detail": "%s获得%s：%d 张" % [zone, anomaly_id, applied.size()]}

func summarize(_effect: Dictionary, _context: Dictionary, _intent: Dictionary, _state: Dictionary) -> void:
    pass
