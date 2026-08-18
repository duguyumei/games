class_name SourceMarkerEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const AddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")
const SourceMarkerStoreScript = preload("res://core/source_marker_store.gd")

var value_resolver
var address_resolver = AddressResolverScript.new()

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "write_source_marker", "capture_source_marker",
        "transfer_source_marker",
        "append_source_marker_records", "consume_matching_source_marker_records",
        "begin_technique_charging", "write_charging_primary",
        "write_all_charging_primary", "capture_charging_techniques",
        "end_technique_charging",
    ]

func group_name() -> String:
    return "source_marker"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.actor == null or runtime.ports == null:
        return EffectResultScript.failed("来源标识处理器缺少战斗端口")
    match str(effect.get("op", "")):
        "write_source_marker":
            return _write(effect, runtime)
        "capture_source_marker":
            return _capture(effect, runtime)
        "transfer_source_marker":
            return _transfer(effect, runtime)
        "append_source_marker_records":
            return _append_records(effect, runtime)
        "consume_matching_source_marker_records":
            return _consume_matching_records(effect, runtime)
        "begin_technique_charging":
            return _begin_charging(effect, runtime)
        "write_charging_primary":
            return _write_charging(effect, runtime, false)
        "write_all_charging_primary":
            return _write_charging(effect, runtime, true)
        "capture_charging_techniques":
            return _capture_charging(effect, runtime)
        "end_technique_charging":
            return _end_charging(effect, runtime)
    return EffectResultScript.failed("来源标识处理器不支持此操作")

func _write(effect: Dictionary, runtime):
    var source := _source(effect, runtime)
    if not source.get("success", false):
        return EffectResultScript.failed(str(source.get("reason", "来源标识地址无效")))
    var amount: int = int(value_resolver.resolve(effect.get("amount", 0), runtime))
    var result: Dictionary = runtime.ports.write_source_marker(
        runtime.actor, source, str(effect.get("operation", "add")), amount,
        runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get("reason", "来源标识写入失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = [{
            "amount": int(result.get("after", 0)),
            "before": int(result.get("before", 0)),
            "delta": int(result.get("delta", 0)),
            "consumed": int(result.get("consumed", 0)),
        }]
    runtime.consumed_marker_value = int(result.get("consumed", 0))
    return EffectResultScript.succeeded(
        "%s %s：%d→%d" % [
            source["display_name"], str(effect.get("operation", "add")),
            int(result.get("before", 0)), int(result.get("after", 0)),
        ])

func _capture(effect: Dictionary, runtime):
    var source := _source(effect, runtime)
    if not source.get("success", false):
        return EffectResultScript.failed(str(source.get("reason", "来源标识地址无效")))
    var amount: int = int(runtime.actor.source_marker_store.value(
        str(source["source_kind"]), str(source["source_instance_key"]),
        str(source["marker_id"]), str(source.get("scope", ""))))
    runtime.captures[str(effect.get("capture", "source_marker"))] = [{"amount": amount}]
    return EffectResultScript.succeeded("捕获%s %d" % [source["display_name"], amount])

func _transfer(effect: Dictionary, runtime):
    var source := _source(effect.get("from", effect), runtime)
    var target_spec: Dictionary = effect.get("to", {})
    var target := _source(target_spec, runtime)
    if not source.get("success", false) or not target.get("success", false):
        return EffectResultScript.failed(str(
            source.get("reason", target.get("reason", "来源标识地址无效"))))
    var amount := maxi(0, value_resolver.resolve(effect.get("amount", 0), runtime))
    var result: Dictionary = runtime.ports.transfer_source_marker(
        runtime.actor, source, target, amount, runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get("reason", "来源标识转移失败")))
    runtime.captures[str(effect.get("capture", "transferred_marker"))] = [{
        "amount": int(result.get("transferred", 0))}]
    return EffectResultScript.succeeded("转移标识 %d" % int(result.get("transferred", 0)))

func _append_records(effect: Dictionary, runtime):
    var source := _source(effect, runtime)
    if not source.get("success", false):
        return EffectResultScript.failed(str(source.get("reason", "来源标识地址无效")))
    var records: Array = effect.get("records", [])
    if records.is_empty():
        return EffectResultScript.succeeded("没有追加来源标识记录")
    var result: Dictionary = runtime.ports.append_source_marker_records(
        runtime.actor, source, records.duplicate(true), runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "来源标识记录写入失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = result.get(
            "appended_records", []).duplicate(true)
    return EffectResultScript.succeeded("追加来源标识记录%d条" % records.size())

func _consume_matching_records(effect: Dictionary, runtime):
    var source := _source(effect, runtime)
    if not source.get("success", false):
        return EffectResultScript.failed(str(source.get("reason", "来源标识地址无效")))
    var result: Dictionary = runtime.ports.consume_matching_source_marker_records(
        runtime.actor, source,
        effect.get("record_filters", {}).duplicate(true),
        int(effect.get("count", -1)), runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "来源标识记录过滤消费失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = result.get(
            "consumed_records", []).duplicate(true)
    return EffectResultScript.succeeded("过滤消费来源标识记录%d条" % int(result.get("consumed", 0)))

func _begin_charging(effect: Dictionary, runtime):
    var slot_ids := _charging_target_slot_ids(effect, runtime, true)
    if slot_ids.is_empty():
        return EffectResultScript.failed("开始蓄力缺少真实功法槽位")
    var initial_value := int(value_resolver.resolve(
        effect.get("initial_value", effect.get("amount", 0)), runtime))
    var results: Array = []
    for slot_id_value in slot_ids:
        var result: Dictionary = runtime.ports.begin_technique_charging(
            runtime.actor, str(slot_id_value), initial_value,
            runtime.action_token)
        if not result.get("success", false):
            return EffectResultScript.failed(str(result.get(
                "reason", "开始功法蓄力失败")))
        results.append(result.duplicate(true))
    _capture_charging_results(effect, runtime, results)
    return EffectResultScript.succeeded("开始%d个功法实例蓄力" % results.size())

func _write_charging(effect: Dictionary, runtime, force_all: bool):
    var operation := str(effect.get("operation", "add"))
    var amount := int(value_resolver.resolve(effect.get("amount", 0), runtime))
    var frozen_ids: Array = []
    var target_capture := str(effect.get("target_capture", ""))
    if target_capture != "":
        frozen_ids = _slot_ids_from_capture(runtime, target_capture)
        if frozen_ids.is_empty():
            return EffectResultScript.failed("已捕获蓄力槽位为空")
    var result: Dictionary
    if force_all or target_capture != "" \
            or str(effect.get("target", "")) == "all_charging":
        result = runtime.ports.write_all_charging_primary_values(
            runtime.actor, operation, amount, runtime.action_token, frozen_ids)
    else:
        var slot_ids := _charging_target_slot_ids(effect, runtime, false)
        if slot_ids.size() != 1:
            return EffectResultScript.failed("主要蓄力值写入必须解析到一个实际槽位")
        result = runtime.ports.write_charging_primary_value(
            runtime.actor, str(slot_ids[0]), operation, amount,
            runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "主要蓄力值写入失败")))
    var results: Array = result.get("results", [result]).duplicate(true)
    _capture_charging_results(effect, runtime, results)
    return EffectResultScript.succeeded("写入%d个功法实例主要蓄力值" % results.size())

func _capture_charging(effect: Dictionary, runtime):
    var instances: Array = runtime.ports.charging_technique_instances(
        runtime.actor, false)
    runtime.captures[str(effect.get(
        "capture", "charging_techniques"))] = instances.duplicate(true)
    return EffectResultScript.succeeded("捕获%d个蓄力功法实例" % instances.size())

func _end_charging(effect: Dictionary, runtime):
    var target_capture := str(effect.get("target_capture", ""))
    if target_capture != "" or str(effect.get("target", "")) == "all_charging":
        var frozen_ids := _slot_ids_from_capture(runtime, target_capture) \
            if target_capture != "" else []
        if target_capture != "" and frozen_ids.is_empty():
            return EffectResultScript.failed("已捕获蓄力槽位为空")
        var batch: Dictionary = runtime.ports.write_all_charging_primary_values(
            runtime.actor, "clear", 0, runtime.action_token, frozen_ids)
        if not batch.get("success", false):
            return EffectResultScript.failed(str(batch.get(
                "reason", "结束功法蓄力失败")))
        _capture_charging_results(
            effect, runtime, batch.get("results", []).duplicate(true))
        return EffectResultScript.succeeded(
            "结束%d个功法实例蓄力" % int(batch.get("target_count", 0)))
    var slot_ids := _charging_target_slot_ids(effect, runtime, false)
    if slot_ids.size() != 1:
        return EffectResultScript.failed("结束蓄力必须解析到一个实际槽位")
    var result: Dictionary = runtime.ports.end_technique_charging(
        runtime.actor, str(slot_ids[0]), runtime.action_token)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "结束功法蓄力失败")))
    _capture_charging_results(effect, runtime, [result])
    return EffectResultScript.succeeded("结束功法实例蓄力")

func _charging_target_slot_ids(
        effect: Dictionary, runtime, allow_all: bool) -> Array:
    var target_capture := str(effect.get("target_capture", ""))
    if target_capture != "":
        return _slot_ids_from_capture(runtime, target_capture)
    if allow_all and str(effect.get("target", "")) == "all_charging":
        return runtime.ports.charging_technique_instances(
            runtime.actor, false).map(
                func(entry): return str(entry.get("slot_instance_id", "")))
    var explicit := str(effect.get("slot_instance_id", ""))
    if explicit != "":
        return [explicit]
    return [runtime.slot_instance_id] if runtime.slot_instance_id != "" else []

func _slot_ids_from_capture(runtime, capture_id: String) -> Array:
    var result: Array = []
    for entry in runtime.captures.get(capture_id, []):
        var slot_id := str(entry.get("slot_instance_id", "")) \
            if entry is Dictionary else ""
        if slot_id != "" and not result.has(slot_id):
            result.append(slot_id)
    return result

func _capture_charging_results(
        effect: Dictionary, runtime, results: Array) -> void:
    var capture_id := str(effect.get("capture", effect.get(
        "result_capture", "")))
    if capture_id != "":
        runtime.captures[capture_id] = results.duplicate(true)

func _source(effect: Dictionary, runtime) -> Dictionary:
    var result := address_resolver.resolve(effect, runtime)
    if result.get("success", false):
        for field in ["marker_role", "slot_instance_id", "technique_id", "hand_id"]:
            if effect.has(field):
                result[field] = effect[field]
    return result

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var op := str(effect.get("op", ""))
    if op in ["append_source_marker_records", "consume_matching_source_marker_records"]:
        if op == "append_source_marker_records" and not effect.get(
                "records", []) is Array:
            validator.report_error(scope + ".records", "必须是数组")
        if op == "consume_matching_source_marker_records" \
                and not effect.get("record_filters", {}) is Dictionary:
            validator.report_error(scope + ".record_filters", "必须是对象")
        if effect.has("count") and not effect["count"] is int:
            validator.report_error(scope + ".count", "必须是整数")
        return
    if op in [
            "begin_technique_charging", "write_charging_primary",
            "write_all_charging_primary", "capture_charging_techniques",
            "end_technique_charging"]:
        if op in ["write_charging_primary", "write_all_charging_primary"] \
                and str(effect.get("operation", "add")) not in [
                    "add", "subtract", "set", "clear"]:
            validator.report_error(scope + ".operation",
                "引用未知主要蓄力值操作")
        if effect.has("amount"):
            validator.validate_amount_spec(effect["amount"], scope + ".amount")
        if effect.has("initial_value"):
            validator.validate_amount_spec(
                effect["initial_value"], scope + ".initial_value")
        if str(effect.get("target", "current_source")) not in [
                "current_source", "all_charging"]:
            validator.report_error(scope + ".target", "引用未知蓄力功法目标")
        return
    if op == "write_source_marker" \
            and str(effect.get("operation", "")) not in [
                "add", "set", "subtract", "consume", "clear"]:
        validator.report_error(scope + ".operation", "引用未知来源标识操作")
    if str(effect.get("marker_id", "")) == "":
        validator.report_error(scope + ".marker_id", "必须提供 marker_id")
    elif not _is_snake_case(str(effect.get("marker_id", ""))):
        validator.report_error(scope + ".marker_id", "必须使用 snake_case")
    if effect.has("source_kind") \
            and str(effect["source_kind"]) not in [
                "technique", "inner_skill", "item"]:
        validator.report_error(
            scope + ".source_kind", "必须为 technique、inner_skill 或 item")
    if str(effect.get("scope", "battle")) not in ["battle", "run"]:
        validator.report_error(scope + ".scope", "必须为 battle 或 run")
    if str(effect.get("forget_policy", "clear")) not in ["clear", "retain"]:
        validator.report_error(
            scope + ".forget_policy", "必须为 clear 或 retain")
    if effect.has("public") and not effect["public"] is bool:
        validator.report_error(scope + ".public", "必须是布尔值")
    if not SourceMarkerStoreScript.is_registered_contribution(str(
            effect.get("contributes_to", ""))):
        validator.report_error(scope + ".contributes_to", "引用未注册的来源统计项")

func _is_snake_case(value: String) -> bool:
    if value == "" or value.to_lower() != value \
            or value.begins_with("_") or value.ends_with("_"):
        return false
    for character in value:
        if character != "_" and not character.is_valid_identifier() \
                and not character.is_valid_int():
            return false
    return not "__" in value
