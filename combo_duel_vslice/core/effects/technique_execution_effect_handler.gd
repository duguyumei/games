class_name TechniqueExecutionEffectHandler
extends EffectHandler

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload(
    "res://core/effects/technique_effect_result.gd")

const TARGET_CURRENT := "current_slot"
const TARGET_RANDOM_OTHER := "random_other_slot"
const TARGET_NEXT_NON_ECHO := "next_non_echo"
const TARGET_MODES := [
    TARGET_CURRENT, TARGET_RANDOM_OTHER, TARGET_NEXT_NON_ECHO,
]

var _value_resolver
var _rng: RandomNumberGenerator


func _init(value_resolver, rng: RandomNumberGenerator) -> void:
    _value_resolver = value_resolver
    _rng = rng


func operation_ids() -> Array[String]:
    return [
        "append_current_technique_echo",
        "grant_pending_slot_echo",
        "request_extra_sequence_advance",
    ]


func group_name() -> String:
    return "technique_execution"


func default_phase(_operation_id: String) -> String:
    return "post_commit"


func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("功法执行计划效果缺少战斗端口")
    var count: int = maxi(0, int(_value_resolver.resolve(
        effect.get("count", 1), runtime)))
    match str(effect.get("op", "")):
        "append_current_technique_echo":
            return _append_current_echo(effect, runtime, count)
        "grant_pending_slot_echo":
            return _grant_pending_echo(effect, runtime, count)
        "request_extra_sequence_advance":
            return _request_extra_advance(runtime, count)
    return EffectResultScript.failed("功法执行计划处理器不支持此操作")


func summarize(
        _effect: Dictionary,
        _context,
        _intent: Dictionary,
        _state: Dictionary) -> void:
    # 这些操作只修改已经确认的 execution 计划；预览不得建立计划或推进 RNG。
    pass


func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var count = effect.get("count", 1)
    if count is Dictionary:
        validator.validate_amount_spec(count, scope + ".count")
    elif not count is int or int(count) < 0:
        validator.report_error(scope + ".count", "必须为非负整数或 ValueSpec")
    var op := str(effect.get("op", ""))
    if op == "append_current_technique_echo":
        if effect.has("only_if_current_count_zero") \
                and not effect["only_if_current_count_zero"] is bool:
            validator.report_error(
                scope + ".only_if_current_count_zero", "必须是布尔值")
        return
    if op == "grant_pending_slot_echo":
        var target_mode := str(effect.get("target_mode", TARGET_CURRENT))
        if target_mode not in TARGET_MODES:
            validator.report_error(scope + ".target_mode", "引用未知待用回响目标模式")
        if effect.has("target_slot_instance_id") and (
                not effect["target_slot_instance_id"] is String \
                or str(effect["target_slot_instance_id"]) == ""):
            validator.report_error(
                scope + ".target_slot_instance_id", "必须是非空字符串")


func _append_current_echo(effect: Dictionary, runtime, count: int):
    if bool(effect.get("only_if_current_count_zero", false)) \
            and runtime.ports.current_technique_echo_count(runtime) != 0:
        return EffectResultScript.succeeded("当前功法已有回响，未重复登记")
    var result: Dictionary = runtime.ports.append_current_technique_echo(
        runtime, count, effect.get("effects", []))
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "当前功法回响登记失败")))
    return EffectResultScript.succeeded("当前功法追加回响%d次" % count)


func _grant_pending_echo(effect: Dictionary, runtime, count: int):
    if count <= 0:
        return EffectResultScript.succeeded("待用回响次数为0")
    var target_slot_id := str(effect.get("target_slot_instance_id", ""))
    var target_mode := str(effect.get("target_mode", TARGET_CURRENT))
    var rng_state := int(_rng.state) if _rng != null else 0
    if target_slot_id == "":
        match target_mode:
            TARGET_CURRENT:
                target_slot_id = str(runtime.slot_instance_id)
            TARGET_NEXT_NON_ECHO:
                target_slot_id = "*"
            TARGET_RANDOM_OTHER:
                var candidates := _other_slots(runtime)
                if candidates.is_empty():
                    return EffectResultScript.succeeded("没有其他实际功法槽位")
                if _rng == null:
                    return EffectResultScript.failed("随机待用回响缺少战斗随机源")
                var selected: Dictionary = candidates[
                    _rng.randi_range(0, candidates.size() - 1)]
                target_slot_id = str(selected.get("slot_instance_id", ""))
    if target_slot_id == "":
        if _rng != null:
            _rng.state = rng_state
        return EffectResultScript.failed("待用回响缺少实际功法槽位")
    var result: Dictionary = runtime.ports.grant_pending_slot_echo(
        runtime, target_slot_id, count,
        str(effect.get("grant_event_token", runtime.event_token)))
    if not result.get("success", false):
        if _rng != null:
            _rng.state = rng_state
        return EffectResultScript.failed(str(result.get(
            "reason", "待用回响写入失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = [{
            "target_slot_instance_id": target_slot_id,
            "granted_count": count,
        }]
    return EffectResultScript.succeeded(
        "槽位%s获得待用回响%d次" % [target_slot_id, count])


func _request_extra_advance(runtime, count: int):
    var source_record := {
        "source_kind": str(runtime.source_kind),
        "source_id": str(runtime.source_id),
        "source_instance_key": str(runtime.source_instance_key),
        "trigger_mode": str(runtime.trigger_mode),
        "event_token": str(runtime.event_token),
        "count": count,
    }
    var result: Dictionary = runtime.ports.request_extra_sequence_advance(
        runtime, count, source_record)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "额外序列推进请求失败")))
    return EffectResultScript.succeeded("请求额外推进%d格" % count)


func _other_slots(runtime) -> Array:
    if runtime.sequence_book == null:
        return []
    var current_slot_id := str(runtime.slot_instance_id)
    return runtime.sequence_book.find_slots({}).filter(func(slot):
        return str(slot.get("slot_instance_id", "")) != "" \
            and str(slot.get("slot_instance_id", "")) != current_slot_id)
