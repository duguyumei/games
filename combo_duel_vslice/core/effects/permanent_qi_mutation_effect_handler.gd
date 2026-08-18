class_name PermanentQiMutationEffectHandler
extends EffectHandler

const EffectContextScript = preload(
    "res://core/effects/battle_effect_context.gd")
const EffectResultScript = preload(
    "res://core/effects/technique_effect_result.gd")

const TARGET_SOURCES := ["capture", "frozen_reshape_results"]


func operation_ids() -> Array[String]:
    return ["advance_permanent_qi_rank"]


func group_name() -> String:
    return "permanent_qi_mutation"


func execute(effect: Dictionary, context):
    var runtime = EffectContextScript.coerce(context)
    if runtime.ports == null:
        return EffectResultScript.failed("永久真气变更缺少战斗端口")
    var owner = runtime.owner if runtime.owner != null else runtime.actor
    if owner == null:
        return EffectResultScript.failed("永久真气变更缺少持有者")
    var target_ids := _target_ids(effect, runtime)
    var reshape_id := str(effect.get("reshape_id", ""))
    var metadata: Dictionary = runtime.source_metadata()
    metadata.merge({
        "source_actor": runtime.actor,
        "target": runtime.target,
        "action_token": runtime.action_token,
        "event_token": runtime.event_token,
        "root_action_token": runtime.root_action_token,
        "invocation_token": runtime.invocation_token,
        "technique_execution_token": runtime.technique_execution_token,
        "reason": runtime.source_name,
    }, true)
    var receipts: Array = []
    for card_instance_id in target_ids:
        var result: Dictionary = runtime.ports.advance_permanent_qi_rank(
            owner,
            str(card_instance_id),
            reshape_id,
            effect.get("reshape_payload", {}),
            metadata)
        if not result.get("success", false):
            return EffectResultScript.failed(str(result.get(
                "reason", "永久真气牌阶前进失败")), {
                    "receipts": receipts.duplicate(true),
                    "failed_card_instance_id": str(card_instance_id),
                })
        receipts.append(result.duplicate(true))
    if effect.has("result_capture"):
        runtime.captures[str(effect["result_capture"])] = receipts.duplicate(true)
    return EffectResultScript.succeeded(
        "永久牌阶前进 %d 张" % target_ids.size(), {
            "mutation_count": receipts.filter(func(receipt):
                return bool(receipt.get("changed", false)) \
                    and not bool(receipt.get("reused", false))).size(),
            "reused_count": receipts.filter(func(receipt):
                return bool(receipt.get("reused", false))).size(),
            "receipts": receipts,
        })


func summarize(
        _effect: Dictionary,
        _context,
        _intent: Dictionary,
        _state: Dictionary) -> void:
    pass


func validate_effect(effect: Dictionary, validator, scope: String) -> void:
    var targets_from := str(effect.get("targets_from", "capture"))
    if targets_from not in TARGET_SOURCES:
        validator.report_error(
            scope + ".targets_from",
            "必须为 capture 或 frozen_reshape_results")
    if targets_from == "capture" and str(effect.get("capture", "")) == "":
        validator.report_error(scope + ".capture", "必须提供目标 capture")
    if str(effect.get("reshape_id", "")) == "":
        validator.report_error(scope + ".reshape_id", "必须是非空字符串")
    if effect.has("reshape_payload") \
            and not effect.get("reshape_payload") is Dictionary:
        validator.report_error(scope + ".reshape_payload", "必须是对象")
    var flags = effect.get("required_false_flags", [])
    if not flags is Array:
        validator.report_error(scope + ".required_false_flags", "必须是数组")
    else:
        var seen: Dictionary = {}
        for index in range(flags.size()):
            var flag := str(flags[index])
            if flag == "" or seen.has(flag):
                validator.report_error(
                    "%s.required_false_flags[%d]" % [scope, index],
                    "必须为非空且不重复的冻结字段")
            seen[flag] = true
        if targets_from == "frozen_reshape_results" and flags.is_empty():
            validator.report_error(
                scope + ".required_false_flags",
                "冻结结果目标必须声明失败字段")
    if effect.has("result_capture") \
            and str(effect.get("result_capture", "")) == "":
        validator.report_error(scope + ".result_capture", "必须是非空字符串")


func _target_ids(effect: Dictionary, runtime) -> Array[String]:
    if str(effect.get("targets_from", "capture")) == \
            "frozen_reshape_results":
        return _frozen_target_ids(effect, runtime)
    var result: Array[String] = []
    var seen: Dictionary = {}
    for value in runtime.captures.get(str(effect.get("capture", "")), []):
        var card_instance_id := _card_instance_id(value)
        if card_instance_id == "" or seen.has(card_instance_id):
            continue
        seen[card_instance_id] = true
        result.append(card_instance_id)
    return result


func _frozen_target_ids(effect: Dictionary, runtime) -> Array[String]:
    var frozen = runtime.group_snapshot.get("reshape_action_results", {})
    if not frozen is Dictionary:
        return []
    var frozen_results: Dictionary = frozen
    var flags_value = effect.get("required_false_flags", [])
    var required_flags: Array = flags_value.duplicate() \
        if flags_value is Array else []
    var ordered_ids: Array[String] = []
    for card in runtime.group_snapshot.get("contributing_cards", []):
        var card_instance_id := _card_instance_id(card)
        if card_instance_id != "" and frozen_results.has(card_instance_id) \
                and not ordered_ids.has(card_instance_id):
            ordered_ids.append(card_instance_id)
    var remaining_ids: Array = frozen_results.keys()
    remaining_ids.sort_custom(func(left, right): return str(left) < str(right))
    for card_instance_id_value in remaining_ids:
        var card_instance_id := str(card_instance_id_value)
        if not ordered_ids.has(card_instance_id):
            ordered_ids.append(card_instance_id)
    return ordered_ids.filter(func(card_instance_id):
        return _any_frozen_result_matches(
            frozen_results.get(card_instance_id), required_flags))


func _any_frozen_result_matches(value, required_flags: Array) -> bool:
    var results: Array = value if value is Array else [value]
    for result_value in results:
        if not result_value is Dictionary:
            continue
        var result: Dictionary = result_value
        var matches := true
        for flag_value in required_flags:
            var flag := str(flag_value)
            if not result.has(flag) or bool(result[flag]):
                matches = false
                break
        if matches:
            return true
    return false


func _card_instance_id(value) -> String:
    if value is Object:
        return str(value.id)
    if value is Dictionary:
        var card = value.get("card")
        if card is Object:
            return str(card.id)
        return str(value.get(
            "card_instance_id", value.get("instance_id", value.get("id", ""))))
    return str(value)
