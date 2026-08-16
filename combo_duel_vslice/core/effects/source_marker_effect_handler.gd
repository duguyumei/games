class_name SourceMarkerEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")
const AddressResolverScript = preload(
    "res://core/source_marker_address_resolver.gd")

var value_resolver
var address_resolver = AddressResolverScript.new()

func _init(resolver) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return [
        "write_source_marker", "capture_source_marker",
        "transfer_source_marker",
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

func _source(effect: Dictionary, runtime) -> Dictionary:
    return address_resolver.resolve(effect, runtime)

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) == "write_source_marker" \
            and str(effect.get("operation", "")) not in [
                "add", "set", "subtract", "consume", "clear"]:
        validator.report_error(scope + ".operation", "引用未知来源标识操作")
    if str(effect.get("marker_id", "")) == "":
        validator.report_error(scope + ".marker_id", "必须提供 marker_id")
    elif not _is_snake_case(str(effect.get("marker_id", ""))):
        validator.report_error(scope + ".marker_id", "必须使用 snake_case")
    if effect.has("source_kind") \
            and str(effect["source_kind"]) not in ["technique", "inner_skill"]:
        validator.report_error(scope + ".source_kind", "必须为 technique 或 inner_skill")
    if str(effect.get("scope", "battle")) not in ["battle", "run"]:
        validator.report_error(scope + ".scope", "必须为 battle 或 run")

func _is_snake_case(value: String) -> bool:
    if value == "" or value.to_lower() != value \
            or value.begins_with("_") or value.ends_with("_"):
        return false
    for character in value:
        if character != "_" and not character.is_valid_identifier() \
                and not character.is_valid_int():
            return false
    return not "__" in value
