class_name RunEffectContext
extends RefCounted

## 单次本局事务的运行上下文。
##
## growth 始终是独立工作副本；metadata 只携带来源、奖励包等编排信息。

var growth
var metadata: Dictionary
var content_catalog
var committed_events: Array = []
var command_requests: Array = []
var mutation_service = null
var staged_passive_event_tokens: Array = []

func _init(
        growth_override,
        metadata_override: Dictionary = {},
        content_catalog_override = null,
        mutation_service_override = null,
        staged_tokens_override: Array = []) -> void:
    growth = growth_override
    metadata = metadata_override.duplicate(true)
    content_catalog = content_catalog_override
    mutation_service = mutation_service_override
    staged_passive_event_tokens = staged_tokens_override

func record_committed_events(values: Array) -> void:
    for value in values:
        if value is Dictionary:
            var event: Dictionary = value.duplicate(true)
            var serial := committed_events.size() + 1
            var transaction_token := str(metadata.get(
                "transaction_token", "run_mutation"))
            event["event_serial"] = serial
            # 逐牌 canonical 事实已经持有由 transaction/operation/card 构成的
            # 稳定 token；来源标识等既有事件则继续在这里取得事务内序号。
            if str(event.get("event_token", "")) == "":
                event["event_token"] = "%s:%s:%s:%s:%s:%d" % [
                    str(event.get("event_type", "source_marker_changed")),
                    transaction_token,
                    str(event.get("source_kind", "")),
                    str(event.get("source_instance_key", "")),
                    str(event.get("marker_id", "")),
                    serial,
                ]
            committed_events.append(event)

func record_command_requests(values: Array) -> void:
    var seen: Dictionary = {}
    for existing in command_requests:
        if existing is Dictionary:
            seen[str(existing.get("request_token", ""))] = true
    for value in values:
        if not value is Dictionary:
            continue
        var request: Dictionary = value.duplicate(true)
        var token := str(request.get("request_token", ""))
        if token == "" or seen.has(token):
            continue
        seen[token] = true
        command_requests.append(request)

func change_experience(requested_delta: int, values: Dictionary = {}) -> Dictionary:
    if mutation_service == null:
        return {"success": false, "reason": "Run 历练修改缺少 RunMutationService"}
    var context := metadata.duplicate(true)
    context.merge(values, true)
    var result: Dictionary = mutation_service.change_experience_in_place(
        growth, requested_delta, context, staged_passive_event_tokens)
    if result.get("success", false):
        record_committed_events(result.get("committed_events", []))
        record_command_requests(result.get("command_requests", []))
    return result
