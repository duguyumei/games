class_name TechniqueAutoTriggerService
extends RefCounted

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const ConditionSpecRegistryScript = preload(
    "res://core/specs/condition_spec_registry.gd")
const AddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

var _repository
var _invocation_service_ref: WeakRef
var _ports_ref: WeakRef
var _event_service_ref: WeakRef
var _side_refs: Array[WeakRef]
var _books: Array
var _value_resolver
var _processed: Dictionary = {}
var _condition_registry = ConditionSpecRegistryScript.new()
var _address_resolver = AddressResolverScript.new()

func _init(repository, invocation_service, ports, event_service, sides: Array, books: Array) -> void:
    _repository = repository
    _invocation_service_ref = weakref(invocation_service)
    _ports_ref = weakref(ports)
    _event_service_ref = weakref(event_service)
    for side in sides:
        _side_refs.append(weakref(side))
    _books = books
    _value_resolver = invocation_service._value_resolver
    if not event_service.event_committed.is_connected(_on_event_committed):
        event_service.event_committed.connect(_on_event_committed)

func reset() -> void:
    _processed.clear()

func _on_event_committed(event_kind: String, values: Dictionary, receipt: Dictionary) -> void:
    if not BattleEventCatalogScript.can_automatic_listen(event_kind):
        return
    var event_token := str(receipt.get("event_token", values.get("event_token", "")))
    if event_token == "":
        return
    for side_index in range(_side_refs.size()):
        var owner = _side_refs[side_index].get_ref()
        if owner == null:
            continue
        _process_owner_event(
            event_kind, values, event_token, owner, _books[side_index])

func _process_owner_event(event_kind: String, values: Dictionary,
        event_token: String, owner, book) -> void:
    var runtime = _runtime_for_event(values, owner, book)
    if runtime == null:
        return
    var frozen: Array = []
    var hand_ids: Array = book.sequences.keys()
    hand_ids.sort()
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        for slot_value in book.ordered_slots(hand_id):
            var slot: Dictionary = slot_value
            var definition = _repository.get_definition(str(slot.get("technique_id", "")))
            if definition == null:
                continue
            for trigger_value in definition.automatic_triggers:
                var trigger: Dictionary = trigger_value
                if str(trigger.get("event", "")) != event_kind \
                        or not _condition_registry.event_matches(
                            trigger.get("filters", {}), values, owner,
                            _opponent_of(owner)):
                    continue
                var key := "%s|%s|%s" % [
                    event_token, str(slot.get("slot_instance_id", "")),
                    str(trigger.get("id", "")),
                ]
                if _processed.has(key):
                    continue
                _processed[key] = true
                frozen.append_array(_freeze_trigger_instances(
                    runtime, owner, book, hand_id, slot, definition,
                    trigger, values))
    for request_value in frozen:
        _invoke_frozen(runtime, request_value)

func _invoke_frozen(runtime, request: Dictionary) -> void:
    var effect := {
        "selection": {
            "mode": "by_slot", "hand_id": str(request["hand_id"]),
            "slot_instance_id": str(request["slot_instance_id"]),
        },
        "timing": str(request.get("timing", "immediate")),
        "p0": {"mode": "fixed", "value": int(request["p0"])},
        "_p0_override": int(request["p0"]), "_trigger_mode": "automatic",
        "_hand_result_override": request["hand_result"],
        "_consumed_marker_value": int(request.get(
            "consumed_marker_value", 0)),
        "_captures_override": request.get("captures", {}).duplicate(true),
        "advance_sequence": true, "gain_same_qi": true,
        "use_momentum": true, "check_condition": true,
    }
    var ports = _ports()
    if str(request.get("timing", "immediate")) == "immediate" \
            and ports != null and ports.current_effect_context() == runtime:
        ports.schedule_immediate_effect(runtime, {
            "op": "invoke_sequence_technique",
            "selection": effect["selection"],
            "timing": effect["timing"],
            "p0": effect["p0"],
            "_p0_override": effect["_p0_override"],
            "_trigger_mode": effect["_trigger_mode"],
            "_hand_result_override": effect["_hand_result_override"],
            "_consumed_marker_value": effect["_consumed_marker_value"],
            "_captures_override": effect["_captures_override"],
            "advance_sequence": true, "gain_same_qi": true,
            "use_momentum": true, "check_condition": true,
        })
        return
    var previous_hand_result: Dictionary = runtime.hand_result
    var previous_actual_hand_id: String = runtime.actual_hand_id
    var previous_slot_instance_id: String = runtime.slot_instance_id
    var previous_consumed_marker_value: int = runtime.consumed_marker_value
    runtime.hand_result = request["hand_result"]
    runtime.actual_hand_id = str(request["hand_id"])
    runtime.slot_instance_id = str(request["slot_instance_id"])
    runtime.consumed_marker_value = int(request.get("consumed_marker_value", 0))
    var invocation_service = _invocation_service()
    if invocation_service != null:
        invocation_service.invoke(effect, runtime)
    runtime.hand_result = previous_hand_result
    runtime.actual_hand_id = previous_actual_hand_id
    runtime.slot_instance_id = previous_slot_instance_id
    runtime.consumed_marker_value = previous_consumed_marker_value

func _freeze_trigger_instances(
        runtime,
        actor,
        _book,
        hand_id: String,
        slot: Dictionary,
        definition,
        trigger: Dictionary,
        values: Dictionary) -> Array:
    runtime.captures["event"] = [values.duplicate(false)]
    var count := 1
    var consumed_values: Array[int] = [0]
    var progress_groups: Array = []
    if trigger.has("progress"):
        var progress: Dictionary = trigger["progress"]
        var primary_marker_id := str(progress.get("marker_id", ""))
        var marker_definition := _marker_definition(
            definition.marker_definitions, primary_marker_id)
        var source := _address_resolver.resolve_for_slot({
            "source_kind": "technique",
            "content_id": definition.id,
            "marker_id": primary_marker_id,
            "scope": str(marker_definition.get("scope", "battle")),
            "public": bool(marker_definition.get("public", true)),
            "display_name": str(marker_definition.get(
                "display_name", progress.get("marker_id", ""))),
            "contributes_to": str(marker_definition.get("contributes_to", "")),
        }, slot)
        if not source.get("success", false):
            return []
        var ports = _ports()
        if ports == null:
            return []
        var ordered_fields = progress.get("ordered_fields", [])
        if ordered_fields is Array and not ordered_fields.is_empty():
            var record: Dictionary = {}
            for field_value in ordered_fields:
                var field: Dictionary = field_value
                var event_field := str(field.get("field", ""))
                record[str(field.get("id", event_field))] = values.get(
                    event_field)
            var appended: Dictionary = ports.append_source_marker_records(
                actor, source, [record], runtime.action_token)
            if not appended.get("success", false):
                return []
            var threshold := maxi(1, _resolve_value(
                progress.get("threshold", 1), runtime))
            count = int(appended.get("after", 0)) / threshold
            if count <= 0:
                return []
            var primary_consume := maxi(1, _resolve_value(
                progress.get("consume", threshold), runtime))
            var total_consume := primary_consume * count
            if not bool(progress.get("retain_overflow", true)):
                total_consume = int(appended.get("after", 0))
            var consumed: Dictionary = ports.consume_source_marker_records(
                actor, source, total_consume, runtime.action_token)
            if not consumed.get("success", false):
                return []
            progress_groups = _split_consumed_records(
                consumed.get("consumed_records", []), count,
                primary_consume)
        else:
            var add := _resolve_value(progress.get("add", 1), runtime)
            var added: Dictionary = ports.write_source_marker(
                actor, source, "add", add, runtime.action_token)
            if not added.get("success", false):
                return []
            var additional_sources: Array = []
            for additional_value in progress.get("additional", []):
                var additional: Dictionary = additional_value
                var additional_marker_id := str(additional.get("marker_id", ""))
                var additional_definition := _marker_definition(
                    definition.marker_definitions, additional_marker_id)
                var additional_source := _address_resolver.resolve_for_slot({
                    "source_kind": "technique",
                    "content_id": definition.id,
                    "marker_id": additional_marker_id,
                    "scope": str(additional_definition.get("scope", "battle")),
                    "public": bool(additional_definition.get("public", true)),
                    "display_name": str(additional_definition.get(
                        "display_name", additional_marker_id)),
                    "contributes_to": str(additional_definition.get(
                        "contributes_to", "")),
                }, slot)
                if not additional_source.get("success", false):
                    return []
                var additional_added: Dictionary = ports.write_source_marker(
                    actor, additional_source, "add",
                    _resolve_value(additional.get("add", 0), runtime),
                    runtime.action_token)
                if not additional_added.get("success", false):
                    return []
                additional_sources.append({
                    "spec": additional,
                    "source": additional_source,
                    "after": int(additional_added.get("after", 0)),
                })
            var threshold := maxi(1, _resolve_value(progress.get("threshold", 1), runtime))
            count = int(added.get("after", 0)) / threshold
            var primary_consume := maxi(0, _resolve_value(
                progress.get("consume", threshold), runtime))
            if count <= 0:
                return []
            var total_consume := primary_consume * count
            if not bool(progress.get("retain_overflow", true)):
                total_consume = int(added.get("after", 0))
            var primary_consumed: Dictionary = ports.write_source_marker(
                actor, source, "consume", total_consume, runtime.action_token)
            var consumed_by_marker: Dictionary = {}
            consumed_by_marker[primary_marker_id] = int(
                primary_consumed.get("consumed", 0))
            for entry_value in additional_sources:
                var entry: Dictionary = entry_value
                var additional: Dictionary = entry["spec"]
                var consume_value = additional.get("consume", "all")
                var additional_consume := int(entry.get("after", 0)) \
                    if consume_value is String and str(consume_value) == "all" \
                    else maxi(0, _resolve_value(consume_value, runtime))
                if not bool(additional.get("retain_overflow", true)):
                    additional_consume = int(entry.get("after", 0))
                var additional_consumed: Dictionary = ports.write_source_marker(
                    actor, entry["source"], "consume", additional_consume,
                    runtime.action_token)
                consumed_by_marker[str(additional.get("marker_id", ""))] = int(
                    additional_consumed.get("consumed", 0))
            var consumed_marker_id := str(progress.get(
                "consumed_marker_id", primary_marker_id))
            consumed_values = _split_consumed_value(
                int(consumed_by_marker.get(consumed_marker_id, 0)), count)
    var result: Array = []
    for index in range(count):
        runtime.consumed_marker_value = int(consumed_values[index]) \
            if index < consumed_values.size() else 0
        var frozen_captures: Dictionary = {}
        if index < progress_groups.size():
            frozen_captures["automatic_progress_group"] = \
                progress_groups[index].duplicate(true)
            runtime.captures["automatic_progress_group"] = \
                progress_groups[index].duplicate(true)
        result.append({
            "hand_id": hand_id,
            "hand_result": _automatic_hand_result(runtime, hand_id),
            "slot_instance_id": str(slot.get("slot_instance_id", "")),
            "consumed_marker_value": runtime.consumed_marker_value,
            "captures": frozen_captures,
            "p0": _resolve_value(trigger.get("p0", {
                "kind": "consumed_marker_value"}), runtime),
            "timing": str(trigger.get("timing", "immediate")),
        })
    runtime.captures.erase("automatic_progress_group")
    return result

func _split_consumed_records(
        records: Array, count: int, group_size: int) -> Array:
    var result: Array = []
    var offset := 0
    for index in range(count):
        var remaining_groups := count - index
        var remaining_records := records.size() - offset
        var size := group_size
        if remaining_groups == 1:
            size = remaining_records
        result.append(records.slice(offset, offset + size).duplicate(true))
        offset += size
    return result

func _split_consumed_value(total: int, count: int) -> Array[int]:
    var result: Array[int] = []
    if count <= 0:
        return result
    var base := total / count
    var remainder := total % count
    for index in range(count):
        result.append(base + (1 if index < remainder else 0))
    return result

func _runtime_for_event(values: Dictionary, actor, book):
    var ports = _ports()
    if ports == null:
        return null
    var active = ports.current_effect_context()
    if active != null and EffectContextScript.coerce(active).actor == actor:
        return EffectContextScript.coerce(active)
    return EffectContextScript.new().configure({
        "ports": ports, "actor": actor,
        "target": _opponent_of(actor),
        "action_token": str(values.get("action_token", "")),
        "root_action_token": str(values.get("action_token", "")),
        "source_kind": "rule",
        "source_id": "automatic_event",
        "source_name": "自动事件",
        "source_instance_key": "rule:automatic_event",
        "captures": {"event": [values.duplicate(false)]},
        "sequence_book": book, "trigger_mode": "automatic",
        "card_identity_policy": actor.card_identity_policy,
    })

func _automatic_hand_result(runtime, hand_id: String) -> Dictionary:
    var result: Dictionary = runtime.hand_result.duplicate(false)
    result["id"] = hand_id
    if not result.has("contributing"):
        result["contributing"] = runtime.played_cards.duplicate()
    return result

func _resolve_value(value, runtime) -> int:
    return int(_value_resolver.resolve(value, runtime)) if value is Dictionary else int(value)

func _marker_definition(definitions: Array, marker_id: String) -> Dictionary:
    for value in definitions:
        if value is Dictionary and str(value.get("id", "")) == marker_id:
            return value
    return {}

func _side_index(side) -> int:
    for index in range(_side_refs.size()):
        if _side_refs[index].get_ref() == side:
            return index
    return -1

func _opponent_of(side):
    for side_ref in _side_refs:
        var candidate = side_ref.get_ref()
        if candidate != null and candidate != side:
            return candidate
    return null

func _ports():
    return _ports_ref.get_ref() if _ports_ref != null else null

func _invocation_service():
    return _invocation_service_ref.get_ref() \
        if _invocation_service_ref != null else null
