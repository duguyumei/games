class_name PassiveSuppression
extends RefCounted

var suppression_id: String = ""
var target_source_kind: String = ""
var target_content_id: String = ""
var target_instance_key: String = ""
var blocked_hooks: Array[String] = []
var reason: String = ""
var source_id: String = ""
var expiry: Dictionary = {}

func configure(values: Dictionary):
    suppression_id = str(values.get("suppression_id", ""))
    target_source_kind = str(values.get("target_source_kind", ""))
    target_content_id = str(values.get("target_content_id", ""))
    target_instance_key = str(values.get("target_instance_key", ""))
    blocked_hooks.clear()
    for hook in values.get("blocked_hooks", []):
        blocked_hooks.append(str(hook))
    reason = str(values.get("reason", "被动来源暂时失效"))
    source_id = str(values.get("source_id", ""))
    expiry = values.get("expiry", {}).duplicate(true)
    return self

func blocks(source, hook: String, round_number: int) -> bool:
    if is_expired(round_number):
        return false
    if target_source_kind != "" and target_source_kind != source.source_kind:
        return false
    if target_instance_key != "" and target_instance_key != source.source_instance_key:
        return false
    if target_content_id != "" and target_content_id != source.content_id:
        return false
    return blocked_hooks.is_empty() or blocked_hooks.has(hook)

func is_expired(round_number: int) -> bool:
    if expiry.is_empty() or not expiry.has("through_round"):
        return false
    return round_number > int(expiry.get("through_round", round_number))
