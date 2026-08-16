class_name ConditionSpecRegistry
extends RefCounted

const EffectContextScript = preload(
    "res://core/effects/technique_effect_context.gd")
const EffectSourceProtocolScript = preload(
    "res://core/effects/effect_source_protocol.gd")
const HandGroupSnapshotScript = preload("res://core/hand_group_snapshot.gd")

## ConditionSpec 的字段、结构规则与运行处理器只在这里登记一次。
## 新字段若能复用既有 validation/runtime 类型，只需要增加一条定义。
const CONDITION_DEFINITIONS := {
    "all": {"validation": "condition_list", "runtime": "all"},
    "any": {"validation": "condition_list", "runtime": "any"},
    "not": {"validation": "condition", "runtime": "not"},
    "attribute": {"validation": "attribute", "runtime": "attribute_minimum"},
    "minimum": {"validation": "positive_int", "runtime": "modifier"},
    "pure_attribute": {"validation": "attribute", "runtime": "pure_attribute"},
    "capture_nonempty": {"validation": "capture_id", "runtime": "capture_nonempty"},
    "capture_empty": {"validation": "capture_id", "runtime": "capture_empty"},
    "hand_id": {"validation": "hand_id", "runtime": "hand_id"},
    "exact_hand_id": {"validation": "hand_id", "runtime": "exact_hand_id"},
    "trigger_mode": {"validation": "trigger_mode", "runtime": "trigger_mode"},
    "capture_count_equals": {"validation": "capture_count", "runtime": "capture_count_equals"},
    "capture_count_at_least": {"validation": "capture_count", "runtime": "capture_count_at_least"},
    "capture_all_attribute": {"validation": "capture_attribute", "runtime": "capture_all_attribute"},
    "capture_any_anomaly": {"validation": "capture_anomaly", "runtime": "capture_any_anomaly"},
    "same_qi": {"validation": "attribute", "runtime": "same_qi"},
    "action_same_qi_attribute": {"validation": "attribute", "runtime": "action_same_qi_attribute"},
    "action_is_extra": {"validation": "bool", "runtime": "snapshot_bool", "key": "action_is_extra"},
    "action_from_same_qi": {"validation": "bool", "runtime": "snapshot_bool", "key": "action_from_same_qi"},
    "group_snapshot_flag": {"validation": "nonempty_string", "runtime": "snapshot_named_flag"},
    "group_snapshot_flag_value": {"validation": "bool", "runtime": "modifier"},
    "group_played_count": {"validation": "non_negative_int", "runtime": "group_played_count"},
    "group_has_common_attribute": {"validation": "attribute_or_any", "runtime": "common_attribute", "key": "common_attributes"},
    "group_has_no_common_attribute": {"validation": "bool", "runtime": "no_common_attribute", "key": "common_attributes"},
    "contributing_has_common_attribute": {"validation": "attribute_or_any", "runtime": "common_attribute", "key": "contributing_common_attributes"},
    "contributing_has_no_common_attribute": {"validation": "bool", "runtime": "no_common_attribute", "key": "contributing_common_attributes"},
    "base_attribute_count_at_least": {"validation": "non_negative_int", "runtime": "base_attribute_count_at_least"},
    "capture_result_life_lost": {"validation": "capture_id", "runtime": "capture_result_life_lost"},
    "capture_card_effective_above_base": {"validation": "capture_id", "runtime": "capture_card_effective_above_base"},
    "capture_card_in_zone": {"validation": "capture_zone", "runtime": "capture_card_in_zone"},
    "initial_power_greater_than_group_base_qi": {"validation": "bool", "runtime": "initial_power_greater_than_group_base_qi"},
    "actor_defense_equals": {"validation": "non_negative_int", "runtime": "actor_defense_equals"},
    "actor_hand_less_than_target": {"validation": "bool", "runtime": "actor_hand_less_than_target"},
    "actor_alive": {"validation": "bool", "runtime": "actor_alive"},
    "value_at_least": {"validation": "value_at_least", "runtime": "value_at_least"},
    "value_at_most": {"validation": "value_at_most", "runtime": "value_at_most"},
    "value_greater_than": {"validation": "value_greater_than", "runtime": "value_greater_than"},
    "action_has_cooperation": {"validation": "bool", "runtime": "snapshot_bool", "key": "has_cooperation_group"},
    "group_all_active_permanent_reshape": {"validation": "bool", "runtime": "group_all_active_reshape", "reshape_kind": "permanent"},
    "group_all_active_any_reshape": {"validation": "bool", "runtime": "group_all_active_reshape", "reshape_kind": "any"},
    "hand_differs_from_previous_success": {"validation": "bool", "runtime": "hand_differs_from_previous_success"},
    "hand_stronger_than_opposing": {"validation": "bool", "runtime": "hand_stronger_than_opposing"},
    "opposing_has_normal_attack": {"validation": "bool", "runtime": "snapshot_bool", "key": "opposing_has_normal_attack"},
}

## 事件 filters 与 ConditionSpec 使用同一注册机制：定义同时声明结构、取值和匹配方式。
const EVENT_FILTER_DEFINITIONS := {
    "event_actor_is_owner": {"validation": "bool", "value": "relation", "left": "actor", "right": "owner"},
    "event_actor_is_opponent": {"validation": "bool", "value": "relation", "left": "actor", "right": "opponent"},
    "event_target_is_owner": {"validation": "bool", "value": "relation", "left": "target", "right": "owner"},
    "holder_is_actor": {"validation": "bool", "value": "record_relation", "left": "holder", "right": "actor"},
    "attacker_is_actor": {"validation": "bool", "value": "record_relation", "left": "attacker", "right": "actor"},
    "attacker_is_target": {"validation": "bool", "value": "record_relation", "left": "attacker", "right": "target"},
    "defender_is_actor": {"validation": "bool", "value": "record_relation", "left": "defender", "right": "actor"},
    "defense_lost_positive": {"validation": "bool", "value": "positive", "key": "defense_lost"},
    "requested_amount_positive": {"validation": "bool", "value": "positive", "key": "requested_amount"},
    "actual_life_loss_positive": {"validation": "bool", "value": "positive", "key": "actual_life_loss", "fallback": "life_lost"},
    "life_lost_equals": {"validation": "non_negative_int", "value": "direct", "key": "life_lost"},
    "defense_after_equals": {"validation": "non_negative_int", "value": "direct", "key": "defense_after"},
    "same_qi_gain_at_least": {"validation": "non_negative_int", "value": "same_qi_gain", "match": "at_least"},
    "conversion_count_at_least": {"validation": "non_negative_int", "value": "conversion_count", "match": "at_least"},
    "challenge_difference_at_least": {"validation": "non_negative_int", "value": "challenge_difference", "match": "at_least"},
    "action_token_is_record": {"validation": "bool", "value": "record_action_token"},
    "owner": {"validation": "owner_role", "value": "role", "event_key": "actor"},
    "holder": {"validation": "holder_role", "value": "role", "event_key": "holder"},
    "source_kind_in": {"validation": "string_array", "value": "direct", "key": "source_kind", "match": "contains"},
    "draw_reason_not_in": {"validation": "string_array", "value": "direct", "key": "draw_reason", "match": "excludes"},
    "is_extra_action": {"validation": "bool", "value": "direct", "key": "is_extra_action"},
    "from_same_qi": {"validation": "bool", "value": "direct", "key": "from_same_qi"},
    "became_burned_out": {"validation": "bool", "value": "direct", "key": "became_burned_out"},
    "had_burned_out": {"validation": "bool", "value": "snapshot_bool", "key": "had_burned_out", "direct_fallback": true},
    "had_poison": {"validation": "bool", "value": "snapshot_bool", "key": "had_poison"},
    "challenge_met": {"validation": "bool", "value": "payload", "key": "met", "direct_key": "challenge_met"},
    "same_action_window": {"validation": "bool", "value": "same_action_window"},
    "block_damage_at_most_defense": {"validation": "bool", "value": "amount_at_most_defense"},
    "block_defender_hand_more_than_attacker": {"validation": "bool", "value": "defender_hand_more"},
    "next_round": {"validation": "bool", "value": "next_round"},
    "card_instance_ids": {"validation": "string_array", "value": "card_instance_id", "match": "contains"},
    "source_card_instance_ids": {"validation": "string_array", "value": "card_instance_id", "match": "contains"},
    "source_tokens": {"validation": "string_array", "value": "direct", "key": "source_token", "match": "contains"},
    "card_instance_ids_from_capture": {"validation": "capture_id", "value": "registration_only", "resolve_to": "card_instance_ids", "capture_projection": "card_id"},
    "source_card_instance_ids_from_capture": {"validation": "capture_id", "value": "registration_only", "resolve_to": "source_card_instance_ids", "capture_projection": "card_id"},
    "source_tokens_from_capture": {"validation": "capture_id", "value": "registration_only", "resolve_to": "source_tokens", "capture_projection": "source_token"},
    "max_triggers": {"validation": "positive_int", "value": "registration_only"},
    "source_kind": {"validation": "nonempty_string", "value": "direct", "key": "source_kind"},
    "draw_reason": {"validation": "nonempty_string", "value": "direct", "key": "draw_reason"},
    "damage_type": {"validation": "damage_type", "value": "direct", "key": "damage_type"},
    "hand_id": {"validation": "hand_id", "value": "direct", "key": "hand_id"},
    "technique_pool": {"validation": "nonempty_string", "value": "direct", "key": "technique_pool"},
    "technique_id_not_in": {"validation": "string_array", "value": "direct", "key": "technique_id", "match": "excludes"},
    "technique_power": {"validation": "integer", "value": "direct", "key": "technique_power"},
    "requested_amount": {"validation": "integer", "value": "direct", "key": "requested_amount"},
    "final_amount": {"validation": "integer", "value": "direct", "key": "final_amount"},
    "effective_amount": {"validation": "integer", "value": "direct", "key": "effective_amount"},
    "defense_lost": {"validation": "non_negative_int", "value": "direct", "key": "defense_lost"},
    "life_lost": {"validation": "non_negative_int", "value": "direct", "key": "life_lost"},
    "actual_life_loss": {"validation": "non_negative_int", "value": "direct", "key": "actual_life_loss"},
    "frozen_amount": {"validation": "integer", "value": "direct", "key": "frozen_amount"},
    "defense_before": {"validation": "non_negative_int", "value": "direct", "key": "defense_before"},
    "defense_after": {"validation": "non_negative_int", "value": "direct", "key": "defense_after"},
    "reason": {"validation": "nonempty_string", "value": "direct", "key": "reason"},
    "from_zone": {"validation": "zone", "value": "direct", "key": "from_zone"},
    "to_zone": {"validation": "zone", "value": "direct", "key": "to_zone"},
    "explicit_discard": {"validation": "bool", "value": "direct", "key": "explicit_discard"},
    "normal_play": {"validation": "bool", "value": "direct", "key": "normal_play"},
    "technique_triggered": {"validation": "bool", "value": "direct", "key": "technique_triggered"},
    "action_succeeded": {"validation": "bool", "value": "direct", "key": "action_succeeded"},
    "source_category": {"validation": "nonempty_string", "value": "direct", "key": "source_category"},
}

const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const DAMAGE_TYPES := ["normal", "true", "poison"]

var _attribute_ids: Array = ["wind", "forest", "fire", "mountain"]
var _anomaly_category_ids: Array = ["buff", "debuff", "state", "mark"]
var _hand_ids: Array = [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
var _validate_value_spec: Callable

func configure_validation(vocabulary: Dictionary, validate_value_spec: Callable = Callable()) -> void:
    _attribute_ids = vocabulary.get("attribute_ids", _attribute_ids).duplicate()
    _anomaly_category_ids = vocabulary.get(
        "anomaly_category_ids", _anomaly_category_ids).duplicate()
    _hand_ids = vocabulary.get("hand_ids", _hand_ids).duplicate()
    _validate_value_spec = validate_value_spec

func condition_fields() -> Array[String]:
    var result: Array[String] = []
    result.assign(CONDITION_DEFINITIONS.keys())
    result.sort()
    return result

func event_fields() -> Array[String]:
    var result: Array[String] = []
    result.assign(EVENT_FILTER_DEFINITIONS.keys())
    result.sort()
    return result

func validate_condition(condition: Dictionary, report_error: Callable, scope: String) -> bool:
    return _validate_condition_node(condition, report_error, scope)

func validate_event_filters(filters: Dictionary, report_error: Callable, scope: String) -> bool:
    var valid := true
    for field_value in filters:
        var field := str(field_value)
        if not EVENT_FILTER_DEFINITIONS.has(field):
            report_error.call(scope + "." + field, "未知事件筛选字段")
            valid = false
            continue
        valid = _validate_scalar(
            filters[field], str(EVENT_FILTER_DEFINITIONS[field]["validation"]),
            report_error, scope + "." + field) and valid
    return valid

func evaluate(condition: Dictionary, context, resolve_value: Callable = Callable()) -> bool:
    if not _condition_keys_known(condition):
        return false
    var runtime = EffectContextScript.coerce(context)
    for field_value in condition:
        var field := str(field_value)
        var definition: Dictionary = CONDITION_DEFINITIONS[field]
        if not _evaluate_condition_field(
                field, condition[field], definition, condition, runtime,
                resolve_value):
            return false
    return true

func event_matches(filters: Dictionary, values: Dictionary, owner, opponent = null,
        record: Dictionary = {}) -> bool:
    for field_value in filters:
        var field := str(field_value)
        if not EVENT_FILTER_DEFINITIONS.has(field):
            return false
        var definition: Dictionary = EVENT_FILTER_DEFINITIONS[field]
        var expected = filters[field]
        if not _scalar_valid(expected, str(definition["validation"])):
            return false
        if str(definition["value"]) == "registration_only":
            continue
        var actual = _event_value(
            definition, expected, values, owner, opponent, record)
        match str(definition.get("match", "equals")):
            "at_least":
                if int(actual) < int(expected):
                    return false
            "contains":
                if not expected is Array or not expected.has(str(actual)):
                    return false
            "excludes":
                if not expected is Array or expected.has(str(actual)):
                    return false
            _:
                if actual != expected:
                    return false
    return true

func resolve_event_filters(filters: Dictionary, captures: Dictionary) -> Dictionary:
    var resolved := filters.duplicate(true)
    for field_value in filters:
        var field := str(field_value)
        if not EVENT_FILTER_DEFINITIONS.has(field):
            continue
        var definition: Dictionary = EVENT_FILTER_DEFINITIONS[field]
        var resolve_to := str(definition.get("resolve_to", ""))
        if resolve_to == "":
            continue
        var projected: Array[String] = []
        for entry in captures.get(str(filters[field]), []):
            match str(definition.get("capture_projection", "")):
                "card_id":
                    if entry is Dictionary:
                        projected.append(str(entry.get("id", "")))
                    elif entry != null:
                        projected.append(str(entry.id))
                "source_token":
                    projected.append(str(
                        entry.get("source_token", "")
                        if entry is Dictionary else ""))
        resolved[resolve_to] = projected
        resolved.erase(field)
    return resolved

func _validate_condition_node(
        condition: Dictionary, report_error: Callable, scope: String) -> bool:
    var valid := true
    for field_value in condition:
        var field := str(field_value)
        if not CONDITION_DEFINITIONS.has(field):
            report_error.call(scope + "." + field, "未知条件字段")
            valid = false
            continue
        var definition: Dictionary = CONDITION_DEFINITIONS[field]
        valid = _validate_condition_value(
            condition[field], str(definition["validation"]), report_error,
            scope + "." + field) and valid
    if condition.has("attribute") != condition.has("minimum"):
        report_error.call(scope, "attribute 与 minimum 必须同时声明")
        valid = false
    if condition.has("group_snapshot_flag_value") \
            and not condition.has("group_snapshot_flag"):
        report_error.call(
            scope + ".group_snapshot_flag_value",
            "必须与 group_snapshot_flag 同时声明")
        valid = false
    return valid

func _validate_condition_value(
        value, validation: String, report_error: Callable, scope: String) -> bool:
    match validation:
        "condition_list":
            if not value is Array:
                report_error.call(scope, "必须是数组")
                return false
            var valid := true
            for index in range(value.size()):
                if not value[index] is Dictionary:
                    report_error.call("%s[%d]" % [scope, index], "必须是对象")
                    valid = false
                else:
                    valid = _validate_condition_node(
                        value[index], report_error,
                        "%s[%d]" % [scope, index]) and valid
            return valid
        "condition":
            if not value is Dictionary:
                report_error.call(scope, "必须是对象")
                return false
            return _validate_condition_node(value, report_error, scope)
        "capture_count":
            return _validate_object(
                value, {"capture": "capture_id", "value": "non_negative_int"},
                report_error, scope)
        "capture_attribute":
            return _validate_object(
                value, {"capture": "capture_id", "attribute": "attribute"},
                report_error, scope)
        "capture_anomaly":
            return _validate_object(
                value, {"capture": "capture_id", "category": "anomaly_category",
                    "id": "nonempty_string"}, report_error, scope)
        "capture_zone":
            return _validate_object(
                value, {"capture": "capture_id", "side": "side", "zone": "zone"},
                report_error, scope)
        "value_at_least":
            return _validate_value_comparison(
                value, "minimum", report_error, scope)
        "value_at_most":
            return _validate_value_comparison(
                value, "maximum", report_error, scope)
        "value_greater_than":
            return _validate_value_comparison(
                value, "threshold", report_error, scope)
    return _validate_scalar(value, validation, report_error, scope)

func _validate_object(
        value, fields: Dictionary, report_error: Callable, scope: String) -> bool:
    if not value is Dictionary:
        report_error.call(scope, "必须是对象")
        return false
    var valid := true
    for field in value:
        if not fields.has(str(field)):
            report_error.call(scope + "." + str(field), "未知结构字段")
            valid = false
    for field in fields:
        if not value.has(field):
            report_error.call(scope + "." + field, "缺少必填字段")
            valid = false
        else:
            valid = _validate_scalar(
                value[field], str(fields[field]), report_error,
                scope + "." + field) and valid
    return valid

func _validate_value_comparison(
        value, boundary_field: String, report_error: Callable,
        scope: String) -> bool:
    if not value is Dictionary:
        report_error.call(scope, "必须是对象")
        return false
    var valid := true
    for field in value:
        if str(field) not in ["value", boundary_field]:
            report_error.call(scope + "." + str(field), "未知结构字段")
            valid = false
    for field in ["value", boundary_field]:
        if not value.has(field):
            report_error.call(scope + "." + field, "缺少必填字段")
            valid = false
            continue
        var child = value[field]
        if child is Dictionary:
            if _validate_value_spec.is_valid():
                _validate_value_spec.call(child, scope + "." + field)
        elif not _is_number(child):
            report_error.call(scope + "." + field, "必须是数值或 ValueSpec")
            valid = false
    return valid

func _validate_scalar(
        value, validation: String, report_error: Callable, scope: String) -> bool:
    var valid := _scalar_valid(value, validation)
    if not valid:
        report_error.call(scope, _validation_message(validation))
    return valid

func _scalar_valid(value, validation: String) -> bool:
    match validation:
        "bool": return value is bool
        "integer": return _is_integer(value)
        "non_negative_int": return _is_integer(value) and int(value) >= 0
        "positive_int": return _is_integer(value) and int(value) > 0
        "nonempty_string", "capture_id":
            return value is String and str(value) != ""
        "attribute": return value is String and _attribute_ids.has(str(value))
        "attribute_or_any": return value is String \
            and (_attribute_ids.has(str(value)) or str(value) == "any")
        "anomaly_category": return value is String \
            and _anomaly_category_ids.has(str(value))
        "hand_id": return value is String and _hand_ids.has(str(value))
        "side": return value is String and str(value) in ["actor", "target"]
        "zone": return value is String and ZONE_IDS.has(str(value))
        "damage_type": return value is String and DAMAGE_TYPES.has(str(value))
        "trigger_mode": return value is String \
            and str(value) in EffectSourceProtocolScript.TRIGGER_MODES
        "owner_role", "holder_role":
            return value is String and str(value) in ["actor", "target"]
        "string_array":
            if not value is Array or value.is_empty():
                return false
            for entry in value:
                if not entry is String or str(entry) == "":
                    return false
            return true
    return false

func _validation_message(validation: String) -> String:
    match validation:
        "bool": return "必须是布尔值"
        "integer": return "必须是整数"
        "non_negative_int": return "必须是非负整数"
        "positive_int": return "必须是正整数"
        "attribute": return "引用未知属性"
        "attribute_or_any": return "必须为 any 或已登记属性"
        "anomaly_category": return "引用未知异状类别"
        "hand_id": return "引用未知精确牌型"
        "side": return "必须为 actor 或 target"
        "zone": return "引用未知牌区"
        "damage_type": return "引用未知伤害类型"
        "trigger_mode": return "引用未知 trigger_mode"
        "owner_role", "holder_role": return "必须为 actor 或 target"
        "string_array": return "必须是非空字符串数组"
    return "必须是非空字符串"

func _condition_keys_known(condition: Dictionary) -> bool:
    if condition.has("attribute") != condition.has("minimum"):
        return false
    if condition.has("group_snapshot_flag_value") \
            and not condition.has("group_snapshot_flag"):
        return false
    for field_value in condition:
        var field := str(field_value)
        if not CONDITION_DEFINITIONS.has(field):
            return false
        var validation := str(CONDITION_DEFINITIONS[field]["validation"])
        match validation:
            "condition_list":
                if not condition[field] is Array:
                    return false
                for child in condition[field]:
                    if not child is Dictionary or not _condition_keys_known(child):
                        return false
            "condition":
                if not condition[field] is Dictionary \
                        or not _condition_keys_known(condition[field]):
                    return false
            _:
                if not _runtime_condition_value_valid(condition[field], validation):
                    return false
    return true

func _runtime_condition_value_valid(value, validation: String) -> bool:
    match validation:
        "capture_count":
            return _runtime_object_valid(value, {
                "capture": "capture_id", "value": "non_negative_int"})
        "capture_attribute":
            return _runtime_object_valid(value, {
                "capture": "capture_id", "attribute": "attribute"})
        "capture_anomaly":
            return _runtime_object_valid(value, {
                "capture": "capture_id", "category": "anomaly_category",
                "id": "nonempty_string"})
        "capture_zone":
            return _runtime_object_valid(value, {
                "capture": "capture_id", "side": "side", "zone": "zone"})
        "value_at_least":
            return _runtime_value_comparison_valid(value, "minimum")
        "value_at_most":
            return _runtime_value_comparison_valid(value, "maximum")
        "value_greater_than":
            return _runtime_value_comparison_valid(value, "threshold")
    return _scalar_valid(value, validation)

func _runtime_object_valid(value, fields: Dictionary) -> bool:
    if not value is Dictionary or value.size() != fields.size():
        return false
    for field in fields:
        if not value.has(field) \
                or not _scalar_valid(value[field], str(fields[field])):
            return false
    return true

func _runtime_value_comparison_valid(value, boundary_field: String) -> bool:
    if not value is Dictionary or value.size() != 2 \
            or not value.has("value") or not value.has(boundary_field):
        return false
    for field in ["value", boundary_field]:
        if not value[field] is Dictionary and not _is_number(value[field]):
            return false
    return true

func _evaluate_condition_field(
        field: String, expected, definition: Dictionary,
        whole_condition: Dictionary, runtime, resolve_value: Callable) -> bool:
    match str(definition["runtime"]):
        "modifier":
            return true
        "all":
            for child in expected:
                if not evaluate(child, runtime, resolve_value):
                    return false
            return true
        "any":
            for child in expected:
                if evaluate(child, runtime, resolve_value):
                    return true
            return false
        "not":
            return not evaluate(expected, runtime, resolve_value)
        "attribute_minimum":
            var count := 0
            for card in _contributing_cards(runtime):
                if _card_is_attribute(card, str(expected), runtime):
                    count += 1
            return count >= int(whole_condition.get("minimum", 1))
        "pure_attribute":
            var contributing := _contributing_cards(runtime)
            if contributing.is_empty():
                return false
            for card in contributing:
                if not _card_is_attribute(card, str(expected), runtime):
                    return false
            return true
        "capture_nonempty":
            return not runtime.captures.get(str(expected), []).is_empty()
        "capture_empty":
            return runtime.captures.get(str(expected), []).is_empty()
        "hand_id":
            return runtime.actual_hand_id == str(expected) \
                or runtime.branch_hand_id == str(expected)
        "exact_hand_id":
            return runtime.actual_hand_id == str(expected)
        "trigger_mode":
            return runtime.trigger_mode == str(expected)
        "capture_count_equals", "capture_count_at_least":
            var count_spec: Dictionary = expected
            var count: int = runtime.captures.get(
                str(count_spec.get("capture", "")), []).size()
            return count == int(count_spec.get("value", 0)) \
                if str(definition["runtime"]) == "capture_count_equals" \
                else count >= int(count_spec.get("value", 0))
        "capture_all_attribute":
            var attribute_spec: Dictionary = expected
            var cards: Array = runtime.captures.get(
                str(attribute_spec.get("capture", "")), [])
            if cards.is_empty():
                return false
            for card in cards:
                if not _card_is_attribute(
                        card, str(attribute_spec.get("attribute", "")), runtime):
                    return false
            return true
        "capture_any_anomaly":
            var anomaly_spec: Dictionary = expected
            for card in runtime.captures.get(
                    str(anomaly_spec.get("capture", "")), []):
                if not card is Dictionary and card.has_anomaly(
                        str(anomaly_spec.get("category", "")),
                        str(anomaly_spec.get("id", ""))):
                    return true
            return false
        "same_qi":
            return HandGroupSnapshotScript.is_same_qi(
                runtime.group_snapshot, str(expected))
        "action_same_qi_attribute":
            return runtime.group_snapshot.get(
                "action_same_qi_common_attributes", []).has(str(expected))
        "snapshot_bool":
            return bool(runtime.group_snapshot.get(
                str(definition["key"]), false)) == bool(expected)
        "snapshot_named_flag":
            return bool(runtime.group_snapshot.get(str(expected), false)) \
                == bool(whole_condition.get("group_snapshot_flag_value", true))
        "group_played_count":
            return _played_cards(runtime).size() == int(expected)
        "common_attribute":
            var common: Array = runtime.group_snapshot.get(
                str(definition["key"]), [])
            return not common.is_empty() if str(expected) == "any" \
                else common.has(str(expected))
        "no_common_attribute":
            var no_common: bool = runtime.group_snapshot.get(
                str(definition["key"]), []).is_empty()
            return no_common == bool(expected)
        "base_attribute_count_at_least":
            return _base_attribute_count(runtime) >= int(expected)
        "capture_result_life_lost":
            var results: Array = runtime.captures.get(str(expected), [])
            return not results.is_empty() \
                and int(results[0].get("life_lost", 0)) > 0
        "capture_card_effective_above_base":
            return _capture_card_effective_above_base(runtime, str(expected))
        "capture_card_in_zone":
            var zone_spec: Dictionary = expected
            var zone_cards: Array = runtime.captures.get(
                str(zone_spec.get("capture", "")), [])
            var side = _side(runtime, str(zone_spec.get("side", "actor")))
            return not zone_cards.is_empty() and side != null \
                and runtime.ports != null \
                and runtime.ports.zone_cards(
                    side, str(zone_spec.get("zone", "hand"))).has(zone_cards[0])
        "initial_power_greater_than_group_base_qi":
            var greater: bool = runtime.initial_power > HandGroupSnapshotScript.base_qi_sum(
                runtime.group_snapshot, _played_cards(runtime))
            return greater == bool(expected)
        "actor_defense_equals":
            return runtime.actor != null and int(runtime.actor.defense) == int(expected)
        "actor_hand_less_than_target":
            var less: bool = runtime.actor != null and runtime.target != null \
                and runtime.actor.hand.size() < runtime.target.hand.size()
            return less == bool(expected)
        "actor_alive":
            var alive := runtime.actor != null and int(runtime.actor.life) > 0
            return alive == bool(expected)
        "value_at_least", "value_at_most", "value_greater_than":
            return _evaluate_value_comparison(
                str(definition["runtime"]), expected, runtime, resolve_value)
        "group_all_active_reshape":
            return _group_all_active_reshape(
                runtime, str(definition.get("reshape_kind", "any"))) \
                == bool(expected)
        "hand_differs_from_previous_success":
            var differs: bool = runtime.actor != null \
                and runtime.actor.last_successful_technique_hand_id != "" \
                and runtime.actor.last_successful_technique_hand_id \
                    != runtime.actual_hand_id
            return differs == bool(expected)
        "hand_stronger_than_opposing":
            var opposing := str(runtime.group_snapshot.get("opposing_hand_id", ""))
            var stronger := opposing != "" \
                and _hand_strength(runtime.actual_hand_id) > _hand_strength(opposing)
            return stronger == bool(expected)
    return false

func _evaluate_value_comparison(
        kind: String, comparison: Dictionary, runtime,
        resolve_value: Callable) -> bool:
    var boundary_field: String = {
        "value_at_least": "minimum",
        "value_at_most": "maximum",
        "value_greater_than": "threshold",
    }[kind]
    var actual := _resolve_condition_value(
        comparison.get("value", 0), runtime, resolve_value)
    var boundary := _resolve_condition_value(
        comparison.get(boundary_field, 0), runtime, resolve_value)
    match kind:
        "value_at_least": return actual >= boundary
        "value_at_most": return actual <= boundary
        _: return actual > boundary

func _resolve_condition_value(value, runtime, resolve_value: Callable) -> int:
    if value is Dictionary:
        return int(resolve_value.call(value, runtime)) if resolve_value.is_valid() else 0
    return int(value)

func _event_value(
        definition: Dictionary, expected, values: Dictionary, owner, opponent,
        record: Dictionary):
    var metadata: Dictionary = values.get("metadata", {})
    match str(definition["value"]):
        "registration_only": return true
        "relation":
            var right = owner if str(definition["right"]) == "owner" else opponent
            return values.get(str(definition["left"])) == right
        "record_relation":
            var fallback = owner if str(definition["right"]) == "actor" else opponent
            return values.get(str(definition["left"])) \
                == record.get(str(definition["right"]), fallback)
        "positive":
            return int(values.get(
                str(definition["key"]),
                values.get(str(definition.get("fallback", "")), 0))) > 0
        "same_qi_gain":
            return int(values.get("same_qi_gain", values.get(
                "gained", values.get("actual_gain", values.get(
                    "effective_amount", 0)))))
        "conversion_count":
            return int(values.get(
                "conversion_count", values.get("same_qi_trigger_count", 0)))
        "challenge_difference":
            return int(values.get(
                "difference", values.get("payload", {}).get("difference", 0)))
        "record_action_token":
            return str(values.get("action_token", "")) \
                == str(record.get("action_token", ""))
        "role":
            return str(expected) if _event_role_matches(
                str(expected), str(definition["event_key"]), values,
                owner, opponent, record) else ""
        "snapshot_bool":
            var snapshot: Dictionary = values.get("pre_move_snapshot", {})
            if bool(definition.get("direct_fallback", false)) \
                    and values.has(str(definition["key"])):
                return bool(values[str(definition["key"])])
            return bool(snapshot.get(str(definition["key"]), false))
        "payload":
            return bool(values.get(
                str(definition.get("direct_key", "")),
                values.get("payload", {}).get(str(definition["key"]), false)))
        "same_action_window":
            return values.get("action_tokens", []).has(
                str(record.get("action_token", "")))
        "amount_at_most_defense":
            return int(values.get("amount", 0)) <= int(values.get("defense", 0))
        "defender_hand_more":
            return int(values.get("defender_hand_count", -1)) \
                > int(values.get("attacker_hand_count", -1))
        "next_round":
            return int(values.get("round_number", -1)) \
                == int(record.get("source_round", -2)) + 1
        "card_instance_id":
            return str(values.get(
                "source_card_instance_id", values.get("card_instance_id", "")))
    var key := str(definition.get("key", ""))
    return values.get(key, metadata.get(key))

func _event_role_matches(
        expected_role: String, event_key: String, values: Dictionary,
        owner, opponent, record: Dictionary) -> bool:
    var expected_object = record.get(
        expected_role, owner if expected_role == "actor" else opponent)
    return values.get(event_key) == expected_object

func _contributing_cards(runtime) -> Array:
    return runtime.hand_result.get("contributing", [])

func _played_cards(runtime) -> Array:
    return runtime.group_snapshot.get("played_cards", runtime.played_cards)

func _side(runtime, side_id: String):
    return runtime.target if side_id == "target" else runtime.actor

func _card_is_attribute(card, attribute: String, runtime) -> bool:
    if card is Dictionary:
        return card.get("attributes", []).has(attribute)
    if runtime.card_identity_policy != null \
            and runtime.card_identity_policy.has_method("resolve"):
        var result: Dictionary = runtime.card_identity_policy.resolve(card, {
            "owner": runtime.actor, "actor": runtime.actor,
            "target": runtime.target,
        })
        if result.get("success", false):
            return bool(result["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func _capture_card_effective_above_base(runtime, capture_id: String) -> bool:
    var cards: Array = runtime.captures.get(capture_id, [])
    if cards.is_empty() or runtime.actor == null:
        return false
    var card = cards[0]
    if card is Dictionary:
        return int(card.get("effective_qi", 0)) > int(card.get("base_qi", 0))
    var base := int(runtime.group_snapshot.get("facts_by_id", {}).get(
        str(card.id), {}).get("base_qi_at_freeze", card.current_base_qi_value()))
    return HandGroupSnapshotScript.current_effective_qi(
        runtime.group_snapshot, card, runtime.actor) > base

func _base_attribute_count(runtime) -> int:
    var attributes: Dictionary = {}
    for card in _played_cards(runtime):
        var facts: Dictionary = runtime.group_snapshot.get(
            "facts_by_id", {}).get(str(card.id), {}) if not card is Dictionary else card
        var attribute := str(facts.get(
            "base_attribute_at_freeze",
            card.current_attribute() if not card is Dictionary else card.get("attribute", "")))
        if attribute != "":
            attributes[attribute] = true
    return attributes.size()

func _group_all_active_reshape(runtime, reshape_kind: String) -> bool:
    var cards := _played_cards(runtime)
    if cards.is_empty():
        return false
    for card in cards:
        var permanent := _has_active_permanent_reshape(card)
        if reshape_kind == "permanent" and not permanent:
            return false
        if reshape_kind == "any" \
                and not permanent and not _has_active_temporary_reshape(card):
            return false
    return true

func _has_active_permanent_reshape(card) -> bool:
    if card == null or card.return_to_origin_active():
        return false
    return not card.reshape_origin.is_empty() \
        or str(card.reshape_enhancement) != "" \
        or str(card.reshape_imprint) != "" \
        or not card.reshape_others.is_empty()

func _has_active_temporary_reshape(card) -> bool:
    if card == null or card.return_to_origin_active():
        return false
    return str(card.temporary_reshapes.get("enhancement", "")) != "" \
        or str(card.temporary_reshapes.get("attribute", "")) != "" \
        or not card.temporary_reshapes.get("rank", {}).is_empty()

func _hand_strength(hand_id: String) -> int:
    return [
        "high_card", "pair", "two_pair", "three_kind", "straight",
        "full_house", "four_kind", "five_kind",
    ].find(hand_id)

func _is_number(value) -> bool:
    return value is int or value is float

func _is_integer(value) -> bool:
    return value is int or (value is float and float(value) == floor(float(value)))
