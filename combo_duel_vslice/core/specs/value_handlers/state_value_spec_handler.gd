class_name StateValueSpecHandler
extends RefCounted

const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

const REGISTERED_KINDS := [
    "card_contribution", "current_defense", "missing_life", "target_missing_life",
    "max_life", "target_max_life", "played_poison_amount", "played_poison_count",
    "zone_anomaly_count", "zone_anomaly_qi_sum", "group_base_qi_sum",
    "extra_effective_qi_sum", "action_same_qi_gain", "action_same_qi_trigger_count",
    "momentum_value", "base_attribute_count", "active_temporary_reshape_base_qi_sum",
    "extra_count", "extra_attribute_count", "hand_count", "target_hand_count",
    "occupied_meridian_count", "deck_count", "bomb_constituent_count", "hand_limit",
    "base_hand_limit",
]

func kind_ids() -> Array[String]:
    return REGISTERED_KINDS.duplicate()

func validate(kind: String, spec: Dictionary, registry, report_error: Callable, scope: String) -> bool:
    var valid := true
    if spec.has("side") and str(spec["side"]) not in [
            "actor", "target", "owner", "opponent"]:
        report_error.call(scope + ".side", "必须为 actor、target、owner 或 opponent")
        valid = false
    if kind in ["zone_anomaly_count", "zone_anomaly_qi_sum"]:
        if spec.has("category") \
                and str(spec["category"]) not in registry.anomaly_category_ids():
            report_error.call(scope + ".category", "引用未知异状类别")
            valid = false
        if spec.has("zones") and not spec["zones"] is Array:
            report_error.call(scope + ".zones", "必须是数组")
            valid = false
        if spec.has("zone") and not spec["zone"] is String:
            report_error.call(scope + ".zone", "必须是字符串")
            valid = false
        if spec.has("anomaly") and not spec["anomaly"] is String:
            report_error.call(scope + ".anomaly", "必须是字符串")
            valid = false
    if kind == "extra_attribute_count" \
            and str(spec.get("attribute", "")) not in registry.attribute_ids():
        report_error.call(scope + ".attribute", "引用未知属性")
        valid = false
    return valid

func resolve(kind: String, spec: Dictionary, runtime, resolver, _registry) -> int:
    match kind:
        "card_contribution":
            return int(runtime.group_snapshot.get("card_contribution", 0))
        "current_defense":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            return int(side.defense) if side != null else 0
        "missing_life":
            return maxi(0, int(runtime.actor.max_life) - int(runtime.actor.life)) \
                if runtime.actor != null else 0
        "target_missing_life":
            return maxi(0, int(runtime.target.max_life) - int(runtime.target.life)) \
                if runtime.target != null else 0
        "max_life":
            return int(runtime.actor.max_life) if runtime.actor != null else 0
        "target_max_life":
            return int(runtime.target.max_life) if runtime.target != null else 0
        "played_poison_amount":
            return int(runtime.group_snapshot.get("played_poison_amount", 0))
        "played_poison_count":
            return int(runtime.group_snapshot.get("played_poison_count", 0))
        "zone_anomaly_count", "zone_anomaly_qi_sum":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            if side == null:
                return 0
            var cards: Array = []
            for zone in spec.get("zones", [spec.get("zone", "hand")]):
                cards.append_array(runtime.ports.zone_cards(side, str(zone)))
            cards = cards.filter(func(card): return card.is_card_kind("normal") \
                and card.has_anomaly(str(spec.get("category", "state")), \
                    str(spec.get("anomaly", "poison"))))
            if kind == "zone_anomaly_count":
                return cards.size()
            var total := 0
            for card in cards:
                total += runtime.ports.current_effective_qi(
                    side, card,
                    resolver.effective_qi_context(runtime, "effect_value"))
            return total
        "group_base_qi_sum":
            return HandGroupSnapshotScript.base_qi_sum(
                runtime.group_snapshot,
                runtime.group_snapshot.get("played_cards", runtime.played_cards))
        "extra_effective_qi_sum":
            var total := 0
            for card in runtime.group_snapshot.get("extra_cards", []):
                total += HandGroupSnapshotScript.frozen_effective_qi(
                    runtime.group_snapshot, card)
            return total
        "action_same_qi_gain":
            return int(runtime.group_snapshot.get("action_same_qi_gain", 0))
        "action_same_qi_trigger_count":
            return int(runtime.group_snapshot.get("action_same_qi_trigger_count", 0))
        "momentum_value":
            return int(runtime.actor.momentum_value) if runtime.actor != null else 0
        "base_attribute_count":
            var attributes: Dictionary = {}
            for card in runtime.group_snapshot.get("played_cards", runtime.played_cards):
                var facts: Dictionary = runtime.group_snapshot.get(
                    "facts_by_id", {}).get(str(card.id), {})
                attributes[str(facts.get(
                    "base_attribute_at_freeze",
                    card.current_attribute() if card.has_method("current_attribute") else card.attribute))] = true
            attributes.erase("")
            return attributes.size()
        "active_temporary_reshape_base_qi_sum":
            var total := 0
            for card in runtime.group_snapshot.get("played_cards", runtime.played_cards):
                if resolver.has_active_temporary_reshape(card):
                    total += int(card.current_base_qi_value())
            return total
        "extra_count":
            return runtime.group_snapshot.get("extra_cards", []).size()
        "extra_attribute_count":
            var count := 0
            for card in runtime.group_snapshot.get("extra_cards", []):
                if resolver.card_is_attribute(card, str(spec.get("attribute", "")), runtime):
                    count += 1
            return count
        "hand_count":
            return runtime.actor.hand.size() if runtime.actor != null else 0
        "target_hand_count":
            return runtime.target.hand.size() if runtime.target != null else 0
        "occupied_meridian_count":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            return side.occupied_meridian_count() if side != null else 0
        "deck_count":
            var side = resolver.side(runtime, str(spec.get("side", "actor")))
            return side.draw_pile.size() if side != null else 0
        "bomb_constituent_count":
            if runtime.actual_hand_id == "four_kind":
                return 4
            if runtime.actual_hand_id == "five_kind":
                return 5
            return 0
        "hand_limit":
            return runtime.actor.current_hand_limit() if runtime.actor != null else 0
        "base_hand_limit":
            return runtime.actor.base_hand_limit() if runtime.actor != null else 0
    return 0
