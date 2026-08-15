class_name TechniqueSequenceEffectHandler
extends EffectHandler

const EffectContextScript = preload("res://core/effects/technique_effect_context.gd")
const EffectResultScript = preload("res://core/effects/technique_effect_result.gd")

var value_resolver
var random_source: RandomNumberGenerator
const HAND_IDS := [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]

func _init(resolver, rng: RandomNumberGenerator) -> void:
    value_resolver = resolver
    random_source = rng

func operation_ids() -> Array[String]:
    return ["insert_technique_slots", "invoke_sequence_technique"]

func group_name() -> String:
    return "technique_sequence"

func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.sequence_book == null:
        return EffectResultScript.failed("功法序列处理器缺少序列簿")
    if str(effect.get("op", "")) == "insert_technique_slots":
        return _insert(effect, runtime)
    if runtime.ports == null:
        return EffectResultScript.failed("功法调用缺少战斗端口")
    var result: Dictionary = runtime.ports.invoke_sequence_technique(effect, runtime)
    if result.get("pending_choice", false):
        return EffectResultScript.pending_choice(
            str(result.get("detail", "等待调用功法目标选择")),
            result.get("_choice_request_object", result.get("choice_request", {})))
    if not result.get("success", false):
        return EffectResultScript.failed(str(result.get("reason", "功法调用失败")))
    return EffectResultScript.succeeded(str(result.get("detail", "功法调用完成")))

func _insert(effect: Dictionary, runtime):
    if not bool(effect.get("temporary", true)):
        return EffectResultScript.failed("战斗插入当前只允许 temporary=true")
    var copies := maxi(0, value_resolver.resolve(effect.get("copies", 1), runtime))
    var source := str(effect.get("source", "self"))
    var technique_id: String = runtime.technique_id if source == "self" else str(
        effect.get("technique_id", source))
    var hand_ids := _target_hands(effect.get("target_hands", "current"), runtime)
    var all_inserted: Array = []
    for hand_id_value in hand_ids:
        var hand_id := str(hand_id_value)
        var frozen_indices: Array = []
        if str(effect.get("position", "after_current")) == "random":
            var slot_count: int = runtime.sequence_book.ordered_slots(hand_id).size()
            for _copy in range(copies):
                frozen_indices.append(random_source.randi_range(0, slot_count))
                slot_count += 1
        all_inserted.append_array(runtime.sequence_book.insert_temporary_slots(
            hand_id, technique_id, copies, {
                "position": str(effect.get("position", "after_current")),
                "frozen_indices": frozen_indices,
                "origin_slot_instance_id": runtime.slot_instance_id,
                "origin_technique_id": runtime.technique_id,
                "marker_mode": str(effect.get("marker_mode", "independent")),
            }))
    var capture_id := str(effect.get("capture", ""))
    if capture_id != "":
        runtime.captures[capture_id] = all_inserted.duplicate(true)
    if runtime.ports != null and not all_inserted.is_empty():
        runtime.ports.emit_technique_sequence_changed(
            runtime.actor, runtime.action_token, "insert", all_inserted)
    return EffectResultScript.succeeded("临时插入 %d 个功法槽位" % all_inserted.size())

func _target_hands(spec, runtime) -> Array:
    if spec is Array:
        return spec.duplicate()
    if str(spec) == "all_other":
        var result: Array = []
        for hand_id in runtime.sequence_book.sequences:
            if str(hand_id) != runtime.actual_hand_id:
                result.append(str(hand_id))
        result.sort()
        return result
    return [runtime.actual_hand_id]

func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    if str(effect.get("op", "")) == "insert_technique_slots":
        var source := str(effect.get("source", "self"))
        if source == "" or (source != "self" and str(
                effect.get("technique_id", source)) == ""):
            validator.report_error(scope + ".source", "必须为 self 或功法 ID")
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
        if effect.has("temporary") and not bool(effect.get("temporary", true)):
            validator.report_error(scope + ".temporary", "当前阶段必须为 true")
        if str(effect.get("position", "after_current")) not in [
                "random", "before_current", "after_current"]:
            validator.report_error(scope + ".position", "引用未知插入位置")
        if str(effect.get("marker_mode", "independent")) not in [
                "independent", "share_origin"]:
            validator.report_error(scope + ".marker_mode", "引用未知标识模式")
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
