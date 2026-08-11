class_name PassiveRuleContext
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/technique_effect_context.gd")

var actor = null
var target = null
var owner = null
var hook: String = ""
var round_number: int = 0
var proposed_equipped_inner_skill_ids: Array = []
var has_proposed_inner_skill_ids: bool = false
var payload: Dictionary = {}
var source = null
var invocation = null
var plan_target_source = null

func configure(values: Dictionary):
    actor = values.get("actor", values.get("owner"))
    target = values.get("target")
    owner = values.get("owner", actor)
    hook = str(values.get("hook", ""))
    round_number = int(values.get("round_number", 0))
    has_proposed_inner_skill_ids = values.has("proposed_equipped_inner_skill_ids")
    proposed_equipped_inner_skill_ids = values.get(
        "proposed_equipped_inner_skill_ids", []).duplicate()
    payload = values.get("payload", {}).duplicate(false)
    source = values.get("source")
    invocation = values.get("invocation")
    plan_target_source = values.get("plan_target_source")
    return self

func for_invocation(current_invocation):
    return get_script().new().configure({
        "actor": actor,
        "target": target,
        "owner": owner,
        "hook": hook,
        "round_number": round_number,
        "proposed_equipped_inner_skill_ids": proposed_equipped_inner_skill_ids,
        "payload": payload,
        "source": current_invocation.source,
        "invocation": current_invocation,
    })

func for_plan_target(target_source):
    var result = get_script().new().configure({
        "actor": actor,
        "target": target,
        "owner": owner,
        "hook": "passive_invocation_plan_query",
        "round_number": round_number,
        "payload": payload,
        "plan_target_source": target_source,
    })
    result.has_proposed_inner_skill_ids = has_proposed_inner_skill_ids
    result.proposed_equipped_inner_skill_ids = proposed_equipped_inner_skill_ids.duplicate()
    return result

func effect_context_for(current_source = null):
    var resolved_source = current_source if current_source != null else source
    var values: Dictionary = payload.get("effect_context_values", {}).duplicate(false)
    if resolved_source != null:
        values["technique_id"] = resolved_source.content_id
        values["technique_name"] = str(resolved_source.definition.get("name", ""))
        values["source_kind"] = resolved_source.source_kind
        var captures_by_source: Dictionary = payload.get("captures_by_source", {})
        if not captures_by_source.has(resolved_source.source_instance_key):
            captures_by_source[resolved_source.source_instance_key] = {}
        values["captures"] = captures_by_source[resolved_source.source_instance_key]
    return EffectContextScript.new().configure(values)
