class_name PassiveRuleContext
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")

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
var source_snapshot: Array = []
var has_source_snapshot: bool = false
var counter_read_port = null
var counter_mutation_port = null
var persistent_counter_read_port = null
var persistent_counter_mutation_port = null
var battle_counter_read_port = null
var battle_counter_mutation_port = null
## 仅 Run committed mutation Invocation 注入；Handler 不直接扫描配装或写
## 持久替换状态。
var source_behavior_transformation_port = null
## 仅真实战斗 mutation Hook 在执行 Invocation 时注入。
var battle_effect_ports = null
## 作用域快照只供窄端口解析；Handler 不从这里取得完整 BattleSide。
var battle_effect_scope: Dictionary = {}

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
    has_source_snapshot = values.has("source_snapshot")
    source_snapshot = values.get("source_snapshot", []).duplicate(true)
    counter_read_port = values.get("counter_read_port")
    counter_mutation_port = values.get("counter_mutation_port")
    persistent_counter_read_port = values.get(
        "persistent_counter_read_port", counter_read_port)
    persistent_counter_mutation_port = values.get(
        "persistent_counter_mutation_port", counter_mutation_port)
    battle_counter_read_port = values.get("battle_counter_read_port")
    battle_counter_mutation_port = values.get("battle_counter_mutation_port")
    source_behavior_transformation_port = values.get(
        "source_behavior_transformation_port")
    battle_effect_ports = values.get("battle_effect_ports")
    battle_effect_scope = values.get("battle_effect_scope", {}).duplicate(false)
    if battle_effect_scope.is_empty():
        battle_effect_scope = {
            "action_token": str(values.get("action_token", "")),
            "event_token": str(values.get("event_token", "")),
            "event_serial": int(values.get("event_serial", -1)),
            "timing_serial": int(values.get("timing_serial", -1)),
            "card": values.get("card"),
            "card_instance_id": str(values.get("card_instance_id", "")),
        }
    return self

func use_battle_effect_ports(ports, scope: Dictionary) -> void:
    battle_effect_ports = ports
    battle_effect_scope = scope.duplicate(false)

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
        "source_snapshot": source_snapshot,
        "persistent_counter_read_port": persistent_counter_read_port,
        "persistent_counter_mutation_port": persistent_counter_mutation_port,
        "battle_counter_read_port": battle_counter_read_port,
        "battle_counter_mutation_port": battle_counter_mutation_port,
        "source_behavior_transformation_port": (
            source_behavior_transformation_port),
        "battle_effect_ports": battle_effect_ports,
        "battle_effect_scope": battle_effect_scope,
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
    result.has_source_snapshot = has_source_snapshot
    result.source_snapshot = source_snapshot.duplicate(true)
    return result

func effect_context_for(current_source = null):
    var resolved_source = current_source if current_source != null else source
    var values: Dictionary = payload.get("effect_context_values", {}).duplicate(false)
    values["actor"] = values.get("actor", actor if actor != null else owner)
    values["target"] = values.get("target", target)
    values["owner"] = owner
    values["opponent"] = _opponent_for(owner)
    values["action_token"] = str(values.get(
        "action_token", battle_effect_scope.get(
            "action_token", payload.get("action_token", ""))))
    values["event_token"] = str(battle_effect_scope.get(
        "event_token", payload.get("event_token", "")))
    values["card_identity_policy"] = values.get(
        "card_identity_policy", _property_value(owner, "card_identity_policy"))
    values["sequence_book"] = values.get(
        "sequence_book", _property_value(owner, "technique_sequence_book"))
    values["effect_command_limit"] = 64
    values["effect_transaction"] = payload.get("effect_transaction", {})
    if resolved_source != null:
        var source_name := str(resolved_source.definition.get("name", ""))
        values["source_kind"] = resolved_source.source_kind
        values["source_id"] = resolved_source.content_id
        values["source_name"] = source_name
        values["source_instance_key"] = resolved_source.source_instance_key
        values["source_marker_definitions"] = (
            resolved_source.source_marker_definitions.duplicate(true))
        values["trigger_mode"] = str(values.get(
            "trigger_mode", "manual" if hook == "action_resolve" else "direct"))
        var captures_by_source: Dictionary = payload.get("captures_by_source", {})
        if not captures_by_source.has(resolved_source.source_instance_key):
            captures_by_source[resolved_source.source_instance_key] = {}
        values["captures"] = captures_by_source[resolved_source.source_instance_key]
        var public_event := public_effect_values()
        if not public_event.is_empty() \
                and not values["captures"].has("event"):
            values["captures"]["event"] = [public_event]
    return EffectContextScript.new().configure(values)

func public_effect_values() -> Dictionary:
    ## Plain lifecycle/query contexts keep their public fields in payload.
    ## Timing and committed-event subclasses still provide stricter
    ## projections by overriding this method.
    return payload.duplicate(true)

func _opponent_for(origin):
    if origin == null:
        return null
    if actor != null and actor != origin:
        return actor
    if target != null and target != origin:
        return target
    return null

func _property_value(object, property_name: String):
    if object == null or not object.has_method("get_property_list"):
        return null
    for property in object.get_property_list():
        if str(property.get("name", "")) == property_name:
            return object.get(property_name)
    return null

func effect_source_metadata() -> Dictionary:
    if source == null:
        return {
            "source_kind": "rule", "source_id": hook,
            "source_name": hook, "source_instance_key": "rule:%s" % hook,
            "trigger_mode": "direct",
        }
    return {
        "source_kind": str(source.source_kind),
        "source_id": str(source.content_id),
        "source_name": str(source.definition.get("name", "")),
        "source_instance_key": str(source.source_instance_key),
        "trigger_mode": "direct",
    }
