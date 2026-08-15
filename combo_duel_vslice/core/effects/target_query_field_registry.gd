class_name TargetQueryFieldRegistry
extends RefCounted

const IdentityHandlerScript = preload(
    "res://core/effects/target_query_handlers/identity_target_query_field_handler.gd")
const RankHandlerScript = preload(
    "res://core/effects/target_query_handlers/rank_target_query_field_handler.gd")
const StateHandlerScript = preload(
    "res://core/effects/target_query_handlers/state_target_query_field_handler.gd")
const RuntimeHandlerScript = preload(
    "res://core/effects/target_query_handlers/runtime_target_query_field_handler.gd")

## TargetQuery filters 的字段注册、参数校验和运行匹配唯一入口。
##
## 每个处理器在同一份字段定义中登记名称与校验规则，并负责对应 matches／后处理。
## 新筛选字段不再需要同步修改字段目录、EffectSpecValidator 和 EffectTargetQuery。
const BUILTIN_HANDLER_SCRIPTS := [
    IdentityHandlerScript,
    RankHandlerScript,
    StateHandlerScript,
    RuntimeHandlerScript,
]

var _handlers: Array = []
var _handlers_by_field: Dictionary = {}
var _definitions_by_field: Dictionary = {}
var _ordered_fields: Array[String] = []
var _registration_errors: Array[String] = []
var _attribute_ids: Array = ["wind", "forest", "fire", "mountain"]
var _anomaly_category_ids: Array = ["buff", "debuff", "state", "mark"]
var _reshape_category_ids: Array = [
    "origin", "enhancement", "imprint", "other",
    "temporary_enhancement", "temporary_attribute", "temporary_rank",
]
var _anomalies_by_id: Dictionary = {}
var _validate_value_spec: Callable

func _init() -> void:
    for handler_script in BUILTIN_HANDLER_SCRIPTS:
        register_handler(handler_script.new())

func register_handler(handler) -> bool:
    if handler == null or not handler.has_method("field_definitions") \
            or not handler.has_method("validate") \
            or not handler.has_method("matches"):
        _registration_errors.append("TargetQuery 字段处理器接口不完整")
        return false
    var definitions = handler.field_definitions()
    if not definitions is Dictionary or definitions.is_empty():
        _registration_errors.append("TargetQuery 字段处理器必须登记非空字段定义")
        return false
    var local_fields: Dictionary = {}
    var valid := true
    for field_value in definitions:
        var field := str(field_value)
        var definition = definitions[field_value]
        if field == "" or not _is_stable_id(field):
            _registration_errors.append(
                "TargetQuery 字段必须是稳定 snake_case：%s" % field)
            valid = false
            continue
        if not definition is Dictionary \
                or str(definition.get("validation", "")) == "":
            _registration_errors.append(
                "TargetQuery 字段缺少校验定义：%s" % field)
            valid = false
            continue
        if local_fields.has(field) or _handlers_by_field.has(field):
            _registration_errors.append("TargetQuery 字段重复注册：%s" % field)
            valid = false
            continue
        local_fields[field] = definition.duplicate(true)
    if not valid:
        return false
    _handlers.append(handler)
    for field in local_fields:
        _handlers_by_field[field] = handler
        _definitions_by_field[field] = local_fields[field]
        _ordered_fields.append(field)
    return true

func configure_validation(
        vocabulary: Dictionary,
        validate_value_spec: Callable = Callable()) -> void:
    _attribute_ids = vocabulary.get("attribute_ids", _attribute_ids).duplicate()
    _anomaly_category_ids = vocabulary.get(
        "anomaly_category_ids", _anomaly_category_ids).duplicate()
    _reshape_category_ids = vocabulary.get(
        "reshape_category_ids", _reshape_category_ids).duplicate()
    _validate_value_spec = validate_value_spec

func use_indexes(anomalies_by_id: Dictionary) -> void:
    _anomalies_by_id = anomalies_by_id

func field_ids() -> Array[String]:
    var result := _ordered_fields.duplicate()
    result.sort()
    return result

func has_field(field: String) -> bool:
    return _handlers_by_field.has(field)

func handler_for_field(field: String):
    return _handlers_by_field.get(field)

func registration_errors() -> Array[String]:
    return _registration_errors.duplicate()

func validate_filters(
        filters: Dictionary, report_error: Callable, scope: String) -> bool:
    var valid := true
    for field_value in filters:
        var field := str(field_value)
        if not _handlers_by_field.has(field):
            report_error.call(scope + "." + field, "未知目标查询筛选字段")
            valid = false
            continue
        valid = _handlers_by_field[field].validate(
            field, filters[field_value], _definitions_by_field[field], self,
            report_error, scope + "." + field) and valid
    return valid

func matches(filters: Dictionary, card, facts, match_context: Dictionary) -> bool:
    for field in _ordered_fields:
        if not filters.has(field):
            continue
        if not _handlers_by_field[field].matches(
                field, filters[field], card, facts, match_context, self):
            return false
    return true

func apply_post_filters(
        filters: Dictionary, cards: Array, match_context: Dictionary) -> Array:
    var result := cards
    for field in _ordered_fields:
        if not filters.has(field):
            continue
        var handler = _handlers_by_field[field]
        if handler.has_method("apply_post_filter"):
            result = handler.apply_post_filter(
                field, filters[field], result, match_context, self)
    return result

func validate_value(
        value, definition: Dictionary, report_error: Callable,
        scope: String) -> bool:
    var validation := str(definition.get("validation", ""))
    match validation:
        "bool":
            return _validate_scalar(value is bool, report_error, scope, "必须是布尔值")
        "attribute":
            return _validate_scalar(
                value is String and _attribute_ids.has(str(value)),
                report_error, scope, "引用未知属性")
        "nonempty_string", "capture_id":
            return _validate_scalar(
                value is String and str(value) != "",
                report_error, scope, "必须是非空字符串")
        "enum":
            return _validate_scalar(
                definition.get("values", []).has(str(value)),
                report_error, scope, "引用未知取值")
        "array":
            return _validate_array(value, "", report_error, scope)
        "array_attribute":
            return _validate_array(value, "attribute", report_error, scope)
        "array_integer":
            return _validate_array(value, "integer", report_error, scope)
        "array_string":
            return _validate_array(value, "string", report_error, scope)
        "integer_or_value_spec":
            if is_integer(value):
                return true
            if value is Dictionary:
                if _validate_value_spec.is_valid():
                    _validate_value_spec.call(value, scope)
                return true
            report_error.call(scope, "必须是整数或数值规格")
            return false
        "anomaly":
            return _validate_state_filter(
                value, _anomaly_category_ids, report_error, scope)
        "anomalies":
            if not value is Array:
                report_error.call(scope, "必须是数组")
                return false
            var valid := true
            for index in range(value.size()):
                valid = _validate_state_filter(
                    value[index], _anomaly_category_ids, report_error,
                    "%s[%d]" % [scope, index]) and valid
            return valid
        "reshape":
            return _validate_state_filter(
                value, _reshape_category_ids, report_error, scope)
        "anomaly_layers":
            return _validate_anomaly_layers(value, report_error, scope)
        "can_apply_anomaly":
            var valid := _validate_state_filter(
                value, _anomaly_category_ids, report_error, scope)
            if not value is Dictionary:
                return false
            var anomaly_id := str(value.get("id", ""))
            var category := str(value.get("category", ""))
            if not _anomalies_by_id.is_empty():
                if not _anomalies_by_id.has(anomaly_id):
                    report_error.call(scope, "引用未知真气异状 %s" % anomaly_id)
                    valid = false
                elif str(_anomalies_by_id[anomaly_id].get("category", "")) != category:
                    report_error.call(
                        scope, "异状 %s 不属于类别 %s" % [anomaly_id, category])
                    valid = false
            return valid
    report_error.call(scope, "TargetQuery 字段使用未知校验规则 %s" % validation)
    return false

func card_has_attribute(card, attribute: String, facts, match_context: Dictionary) -> bool:
    if facts != null:
        return bool(facts.has_attribute(attribute))
    var query = match_context.get("query")
    if query != null and query.card_identity_policy != null \
            and query.card_identity_policy.has_method("resolve"):
        var resolved: Dictionary = query.card_identity_policy.resolve(card, {})
        if resolved.get("success", false):
            return bool(resolved["facts"].has_attribute(attribute))
    return card.is_attribute(attribute)

func current_effective_qi(card, match_context: Dictionary) -> int:
    var context = match_context.get("context")
    var side = match_context.get("side")
    if context != null and context.ports != null and side != null:
        return int(context.ports.current_effective_qi(side, card))
    return int(card.effective_qi_value()) \
        if card.has_method("effective_qi_value") else int(card.qi_value)

func matches_anomaly(card, spec: Dictionary) -> bool:
    var actual: bool = card.has_anomaly(
        str(spec.get("category", "")), str(spec.get("id", "")))
    return actual == bool(spec.get("present", true))

func matches_reshape(card, spec: Dictionary) -> bool:
    var category := str(spec.get("category", ""))
    var reshape_id := str(spec.get("id", ""))
    var actual := false
    match category:
        "origin":
            actual = not card.reshape_origin.is_empty() \
                and (reshape_id == "" \
                    or str(card.reshape_origin.get("id", "")) == reshape_id)
        "enhancement":
            actual = card.reshape_enhancement != "" \
                and (reshape_id == "" or card.reshape_enhancement == reshape_id)
        "imprint":
            actual = card.reshape_imprint != "" \
                and (reshape_id == "" or card.reshape_imprint == reshape_id)
        "other":
            actual = not card.reshape_others.is_empty() \
                if reshape_id == "" else card.reshape_others.has(reshape_id)
        "temporary_enhancement":
            var temporary_enhancement := str(
                card.temporary_reshapes.get("enhancement", ""))
            actual = temporary_enhancement != "" \
                and (reshape_id == "" or temporary_enhancement == reshape_id)
        "temporary_attribute":
            var temporary_attribute := str(
                card.temporary_reshapes.get("attribute", ""))
            actual = temporary_attribute != "" \
                and (reshape_id == "" or temporary_attribute == reshape_id)
        "temporary_rank":
            var temporary_rank = card.temporary_reshapes.get("rank", {})
            actual = not temporary_rank.is_empty() \
                and (reshape_id == "" \
                    or str(temporary_rank.get("rank_name", "")) == reshape_id)
    return actual == bool(spec.get("present", true))

func capture_entries(capture_id: String, match_context: Dictionary) -> Array:
    var context = match_context.get("context")
    if context == null:
        return []
    return context.captures.get(capture_id, [])

func is_integer(value) -> bool:
    return (value is int or value is float) and float(value) == floor(float(value))

func _validate_array(
        value, item_type: String, report_error: Callable, scope: String) -> bool:
    if not value is Array:
        report_error.call(scope, "必须是数组")
        return false
    var valid := true
    for index in range(value.size()):
        var item = value[index]
        var item_valid := true
        match item_type:
            "attribute": item_valid = item is String and _attribute_ids.has(str(item))
            "integer": item_valid = is_integer(item)
            "string": item_valid = item is String
        if not item_valid:
            report_error.call("%s[%d]" % [scope, index], "包含非法项")
            valid = false
    return valid

func _validate_state_filter(
        value, category_ids: Array, report_error: Callable,
        scope: String) -> bool:
    if not value is Dictionary:
        report_error.call(scope, "必须是对象")
        return false
    var valid := true
    if str(value.get("category", "")) not in category_ids:
        report_error.call(scope + ".category", "引用未知类别")
        valid = false
    if value.has("id") and not value["id"] is String:
        report_error.call(scope + ".id", "必须是字符串")
        valid = false
    if value.has("present") and not value["present"] is bool:
        report_error.call(scope + ".present", "必须是布尔值")
        valid = false
    if value.has("replace_state") and not value["replace_state"] is bool:
        report_error.call(scope + ".replace_state", "必须是布尔值")
        valid = false
    return valid

func _validate_anomaly_layers(
        value, report_error: Callable, scope: String) -> bool:
    if not value is Dictionary:
        report_error.call(scope, "必须是对象")
        return false
    var valid := true
    if str(value.get("category", "")) not in _anomaly_category_ids:
        report_error.call(scope + ".category", "引用未知异状类别")
        valid = false
    if value.has("id") and not value["id"] is String:
        report_error.call(scope + ".id", "必须是字符串")
        valid = false
    if not is_integer(value.get("value", 1)) or int(value.get("value", 1)) <= 0:
        report_error.call(scope + ".value", "必须是正整数")
        valid = false
    return valid

func _validate_scalar(
        valid: bool, report_error: Callable, scope: String,
        message: String) -> bool:
    if not valid:
        report_error.call(scope, message)
    return valid

func _is_stable_id(value: String) -> bool:
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
    return pattern.search(value) != null
