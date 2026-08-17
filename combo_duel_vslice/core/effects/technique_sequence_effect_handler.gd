class_name TechniqueSequenceEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver
const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

func _init(resolver, rng: RandomNumberGenerator) -> void:
    value_resolver = resolver

func operation_ids() -> Array[String]:
    return ["generate_temporary_techniques", "invoke_sequence_technique"]

func group_name() -> String:
    return "technique_sequence"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("功法序列效果缺少战斗端口")
    if str(effect.get("op", "")) == "generate_temporary_techniques":
        return _generate(effect, runtime)
    var result: Dictionary = runtime.ports.invoke_sequence_technique(effect, runtime)
    if result.get("pending_choice", false):
        return EffectResultScript.pending_choice(
            str(result.get("detail", "等待调用功法目标选择")),
            result.get("_choice_request_object", result.get("choice_request", {})))
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get("reason", "功法调用失败")))
    return EffectResultScript.succeeded(str(result.get("detail", "功法调用完成")))

func _generate(effect: Dictionary, runtime):
    var copies := maxi(0, value_resolver.resolve(effect.get("copies", 1), runtime))
    var request := effect.duplicate(true)
    request["copies"] = copies
    var result: Dictionary = runtime.ports.generate_temporary_techniques(
        request, runtime)
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get(
            "reason", "临时功法生成失败")))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = [result.duplicate(true)]
    return EffectResultScript.succeeded(
        "生成 %d/%d 门临时功法" % [
            int(result.get("generated_count", 0)),
            int(result.get("requested_count", 0)),
        ])

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) == "generate_temporary_techniques":
        _validate_generation_source(effect, validator, scope)
        var target_hands = effect.get("target_hands", "current")
        if target_hands is String:
            if str(target_hands) not in ["current", "all_other"] \
                    and str(target_hands) not in HAND_IDS:
                validator.report_error(scope + ".target_hands", "引用未知目标牌型")
        elif target_hands is Array:
            for hand_id in target_hands:
                if str(hand_id) not in HAND_IDS:
                    validator.report_error(scope + ".target_hands", "引用未知目标牌型 %s" % str(hand_id))
        else:
            validator.report_error(scope + ".target_hands", "必须为字符串或牌型数组")
        if effect.get("copies", 1) is Dictionary:
            validator.validate_amount_spec(effect["copies"], scope + ".copies")
        elif not effect.get("copies", 1) is int or int(effect.get("copies", 1)) < 0:
            validator.report_error(scope + ".copies", "必须为非负整数或 ValueSpec")
        if str(effect.get("position", "after_current")) not in [
                "random", "before_current", "after_current"]:
            validator.report_error(scope + ".position", "引用未知插入位置")
        if str(effect.get("marker_mode", "independent")) not in [
                "independent", "share_origin"]:
            validator.report_error(scope + ".marker_mode", "引用未知标识模式")
        if str(effect.get("batch_mode", "partial")) not in [
                "partial", "atomic"]:
            validator.report_error(scope + ".batch_mode", "引用未知批次模式")
        if effect.has("capture") and (
                not effect["capture"] is String \
                or str(effect["capture"]) == ""):
            validator.report_error(scope + ".capture", "必须是非空字符串")
        return
    var selection = effect.get("selection", {})
    if not selection is Dictionary:
        validator.report_error(scope + ".selection", "必须是对象")
        return
    var mode := str(selection.get("mode", "next"))
    if mode not in ["self", "next", "by_id", "random"]:
        validator.report_error(scope + ".selection.mode", "引用未知调用选择模式")
    if mode == "by_id" and str(selection.get("technique_id", "")) == "":
        validator.report_error(scope + ".selection.technique_id", "by_id 必须提供功法 ID")
    var hand_id := str(selection.get("hand_id", "current"))
    if hand_id != "current" and hand_id not in HAND_IDS:
        validator.report_error(scope + ".selection.hand_id", "引用未知精确牌型")
    if not selection.get("filters", {}) is Dictionary:
        validator.report_error(scope + ".selection.filters", "必须是对象")
    if str(effect.get("timing", "immediate")) not in [
            "immediate", "after_caller_advance"]:
        validator.report_error(scope + ".timing", "调用效果只允许 immediate 或 after_caller_advance")
    var p0 = effect.get("p0", {})
    if not p0 is Dictionary:
        validator.report_error(scope + ".p0", "必须是对象")
    else:
        var p0_mode := str(p0.get("mode", "reuse_caller"))
        if p0_mode not in ["reuse_caller", "fixed", "value_spec", "recalculate"]:
            validator.report_error(scope + ".p0.mode", "引用未知 P0 来源")
        if p0_mode == "fixed" and not p0.get("value", 0) is int:
            validator.report_error(scope + ".p0.value", "fixed 必须提供整数")
        if p0_mode == "value_spec":
            if not p0.get("value", {}) is Dictionary:
                validator.report_error(scope + ".p0.value", "value_spec 必须提供 ValueSpec")
            else:
                validator.validate_amount_spec(p0["value"], scope + ".p0.value")
    for field in ["advance_sequence", "gain_same_qi", "use_momentum", "check_condition"]:
        if effect.has(field) and not effect[field] is bool:
            validator.report_error(scope + "." + field, "必须是布尔值")

func _validate_generation_source(
        effect: Dictionary,
        validator,
        scope: String) -> void:
    var source = effect.get("technique_source", effect.get(
        "source", "current_source"))
    if effect.has("technique_id") and not effect.has("technique_source") \
            and not effect.has("source"):
        source = {"mode": "by_id", "technique_id": effect["technique_id"]}
    if source is String:
        if str(source) == "":
            validator.report_error(scope + ".technique_source", "不能为空")
        return
    if not source is Dictionary:
        validator.report_error(scope + ".technique_source", "必须是字符串或对象")
        return
    var mode := str(source.get("mode", "current_source"))
    if mode not in ["current_source", "current_slot", "by_slot", "by_id"]:
        validator.report_error(scope + ".technique_source.mode", "引用未知来源模式")
    if mode == "by_id" and str(source.get("technique_id", "")) == "":
        validator.report_error(
            scope + ".technique_source.technique_id", "by_id 必须提供功法 ID")
    if mode == "by_slot" and str(source.get("slot_instance_id", "")) == "":
        validator.report_error(
            scope + ".technique_source.slot_instance_id",
            "by_slot 必须提供槽位实例 ID")
    var hand_id := str(source.get("hand_id", "current"))
    if hand_id != "current" and hand_id not in HAND_IDS:
        validator.report_error(
            scope + ".technique_source.hand_id", "引用未知精确牌型")
