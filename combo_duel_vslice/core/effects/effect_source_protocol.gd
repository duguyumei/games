class_name EffectSourceProtocol
extends RefCounted

## 统一战斗效果来源协议。
##
## source_kind 只描述内容/领域来源；执行方式由 trigger_mode 独立表达。

const SOURCE_KINDS := [
    "technique", "inner_skill", "item",
    "card_status", "card_reshape", "rule",
]

const TRIGGER_MODES := [
    "manual", "automatic", "invoked", "echo", "retrigger",
    "delayed", "response", "response_expiry", "direct",
]

const LEGACY_SOURCE_MODES := {
    "technique_echo": ["technique", "echo"],
    "technique_retrigger": ["technique", "retrigger"],
    "delayed_technique": ["technique", "delayed"],
}

static func from_values(values: Dictionary) -> Dictionary:
    var technique_id := str(values.get("technique_id", ""))
    var technique_name := str(values.get("technique_name", ""))
    var legacy_slot_instance_id := str(values.get("slot_instance_id", ""))
    var source_kind := str(values.get("source_kind", ""))
    var trigger_mode := str(values.get("trigger_mode", "manual"))
    if LEGACY_SOURCE_MODES.has(source_kind):
        var legacy: Array = LEGACY_SOURCE_MODES[source_kind]
        source_kind = str(legacy[0])
        if not values.has("trigger_mode") or trigger_mode == "manual":
            trigger_mode = str(legacy[1])
    if source_kind == "" and (technique_id != "" or legacy_slot_instance_id != ""):
        source_kind = "technique"
    if source_kind == "":
        source_kind = "rule"

    var source_id := str(values.get("source_id", technique_id))
    var source_name := str(values.get("source_name", technique_name))
    var source_instance_key := str(values.get("source_instance_key", ""))
    if source_instance_key == "":
        source_instance_key = legacy_slot_instance_id
    if source_instance_key == "" and source_id != "":
        source_instance_key = "%s:%s" % [source_kind, source_id]
    if source_instance_key == "":
        source_instance_key = source_kind
    return {
        "source_kind": source_kind,
        "source_id": source_id,
        "source_name": source_name,
        "source_instance_key": source_instance_key,
        "trigger_mode": trigger_mode,
    }

static func from_context(context) -> Dictionary:
    if context == null:
        return from_values({})
    if context is Dictionary:
        return from_values(context)
    return from_values({
        "source_kind": context.source_kind,
        "source_id": context.source_id,
        "source_name": context.source_name,
        "source_instance_key": context.source_instance_key,
        "trigger_mode": context.trigger_mode,
        "technique_id": context.technique_id,
        "technique_name": context.technique_name,
        "slot_instance_id": context.slot_instance_id,
    })

static func with_trigger_mode(source: Dictionary, trigger_mode: String) -> Dictionary:
    var result := from_values(source)
    result["trigger_mode"] = trigger_mode
    return result

static func merge_into(target: Dictionary, source_value) -> Dictionary:
    var result := target.duplicate(true)
    var source := (
        from_values(source_value)
        if source_value is Dictionary else from_context(source_value))
    for field in [
            "source_kind", "source_id", "source_name",
            "source_instance_key", "trigger_mode"]:
        result[field] = source[field]
    return result
