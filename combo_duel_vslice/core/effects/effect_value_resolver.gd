class_name EffectValueResolver
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const ValueSpecRegistryScript = preload("res://core/specs/value_spec_registry.gd")
const ConditionSpecRegistryScript = preload("res://core/specs/condition_spec_registry.gd")

var spec_registry = ValueSpecRegistryScript.new()
var condition_registry = ConditionSpecRegistryScript.new()

## Public entry point. Kind-specific parsing belongs to ValueSpec handlers.
func resolve(spec, context) -> int:
    var runtime = EffectContextScript.coerce(context)
    return spec_registry.resolve(spec, runtime, self)

func condition_met(condition: Dictionary, context) -> bool:
    return condition_registry.evaluate(
        condition, context, Callable(self, "resolve"))

## Common context helpers shared by ValueSpec handlers.
func side(runtime, side_id: String):
    return runtime.target if side_id == "target" else runtime.actor

func capture_cards(runtime, spec: Dictionary) -> Array:
    return runtime.captures.get(str(spec.get("capture", "")), [])

func card_is_attribute(card, attribute: String, runtime = null) -> bool:
    if card is Dictionary:
        return card.get("attributes", []).has(attribute)
    if runtime != null and runtime.card_identity_policy != null \
            and runtime.card_identity_policy.has_method("resolve"):
        var result: Dictionary = runtime.card_identity_policy.resolve(card, {
            "owner": runtime.actor, "actor": runtime.actor, "target": runtime.target,
        })
        if result.get("success", false):
            return bool(result["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func has_active_temporary_reshape(card) -> bool:
    if card == null or card.return_to_origin_active():
        return false
    return str(card.temporary_reshapes.get("enhancement", "")) != "" \
        or str(card.temporary_reshapes.get("attribute", "")) != "" \
        or not card.temporary_reshapes.get("rank", {}).is_empty()

func noncontributing_qi_total(context) -> int:
    var runtime = EffectContextScript.coerce(context)
    var contributing: Array = runtime.hand_result.get("contributing", [])
    var total := 0
    for card in runtime.played_cards:
        if not contributing.has(card):
            total += int(card.qi_value)
    return maxi(0, total)
