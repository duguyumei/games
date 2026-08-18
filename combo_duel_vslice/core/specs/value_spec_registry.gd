class_name ValueSpecRegistry
extends RefCounted

const ArithmeticHandlerScript = preload(
    "res://core/specs/value_handlers/arithmetic_value_spec_handler.gd")
const CaptureHandlerScript = preload(
    "res://core/specs/value_handlers/capture_value_spec_handler.gd")
const StateHandlerScript = preload(
    "res://core/specs/value_handlers/state_value_spec_handler.gd")
const MarkerHandlerScript = preload(
    "res://core/specs/value_handlers/marker_value_spec_handler.gd")
const RunCombatHistoryHandlerScript = preload(
    "res://core/specs/value_handlers/run_combat_history_value_spec_handler.gd")

## ValueSpec 的注册、结构校验与运行解析入口。
##
## 每个处理器同时声明自己支持的 kind、字段校验和运行解析。这里不再保存
## KIND_IDS，也不再维护与解析器平行的 kind switch；新增 kind 只需加入一个
## 处理器模块的定义与实现。
const BUILTIN_HANDLER_SCRIPTS := [
    ArithmeticHandlerScript,
    CaptureHandlerScript,
    StateHandlerScript,
    MarkerHandlerScript,
    RunCombatHistoryHandlerScript,
]

var _handlers: Array = []
var _handlers_by_kind: Dictionary = {}
var _registration_errors: Array[String] = []
var _attribute_ids: Array = ["wind", "forest", "fire", "mountain"]
var _anomaly_category_ids: Array = ["buff", "debuff", "state", "mark"]
var _hand_ids: Array = [
    "high_card", "pair", "two_pair", "three_kind", "straight",
    "full_house", "four_kind", "five_kind",
]
var _validate_condition: Callable

func _init() -> void:
    for handler_script in BUILTIN_HANDLER_SCRIPTS:
        register_handler(handler_script.new())

## Registers one handler. A handler owns its complete kind group.
func register_handler(handler) -> bool:
    if handler == null or not handler.has_method("kind_ids") \
            or not handler.has_method("validate") \
            or not handler.has_method("resolve"):
        _registration_errors.append("ValueSpec 处理器接口不完整")
        return false
    var local_ids: Dictionary = {}
    var valid := true
    for kind_value in handler.kind_ids():
        var kind := str(kind_value)
        if kind == "" or not _is_stable_id(kind):
            _registration_errors.append("ValueSpec kind 必须是稳定 snake_case：%s" % kind)
            valid = false
            continue
        if local_ids.has(kind) or _handlers_by_kind.has(kind):
            _registration_errors.append("ValueSpec kind 重复注册：%s" % kind)
            valid = false
            continue
        local_ids[kind] = true
    if not valid:
        return false
    _handlers.append(handler)
    for kind in local_ids:
        _handlers_by_kind[kind] = handler
    return true

func configure_validation(vocabulary: Dictionary, validate_condition: Callable = Callable()) -> void:
    _attribute_ids = vocabulary.get("attribute_ids", _attribute_ids).duplicate()
    _anomaly_category_ids = vocabulary.get(
        "anomaly_category_ids", _anomaly_category_ids).duplicate()
    _hand_ids = vocabulary.get("hand_ids", _hand_ids).duplicate()
    _validate_condition = validate_condition

func kind_ids() -> Array[String]:
    var result: Array[String] = []
    result.assign(_handlers_by_kind.keys())
    result.sort()
    return result

func has_kind(kind: String) -> bool:
    return _handlers_by_kind.has(kind)

func registration_errors() -> Array[String]:
    return _registration_errors.duplicate()

func handler_for_kind(kind: String):
    return _handlers_by_kind.get(kind)

func validate_amount_spec(spec, report_error: Callable, scope: String) -> bool:
    if spec is int or spec is float:
        return true
    if not spec is Dictionary:
        report_error.call(scope, "必须是数值或数值规格对象")
        return false
    var kind := str(spec.get("kind", ""))
    if not _handlers_by_kind.has(kind):
        report_error.call(scope, "未知数值规格 kind %s" % kind)
        return false
    return _handlers_by_kind[kind].validate(
        kind, spec, self, report_error, scope) == true

func resolve(spec, context, resolver) -> int:
    if spec is int or spec is float:
        return int(spec)
    if not spec is Dictionary:
        return _runtime_reject("ValueSpec 必须是数值或对象")
    var kind := str(spec.get("kind", "constant"))
    if not _handlers_by_kind.has(kind):
        return _runtime_reject("未知数值规格 kind %s" % kind)
    return int(_handlers_by_kind[kind].resolve(
        kind, spec, context, resolver, self))

func validate_nested_value(value, report_error: Callable, scope: String) -> bool:
    if value is Dictionary:
        return validate_amount_spec(value, report_error, scope)
    if value is int or value is float:
        return true
    report_error.call(scope, "必须是数值或数值规格对象")
    return false

func validate_nested_fields(
        spec: Dictionary, fields: Array, report_error: Callable, scope: String) -> bool:
    var valid := true
    for field_value in fields:
        var field := str(field_value)
        if not spec.has(field):
            report_error.call(scope + "." + field, "缺少必填字段")
            valid = false
            continue
        valid = validate_nested_value(
            spec[field], report_error, scope + "." + field) and valid
    return valid

func validate_value_list(
        spec: Dictionary, report_error: Callable, scope: String) -> bool:
    var values = spec.get("values")
    if not values is Array or values.is_empty():
        report_error.call(scope + ".values", "必须是非空数组")
        return false
    var valid := true
    for index in range(values.size()):
        valid = validate_nested_value(
            values[index], report_error, "%s.values[%d]" % [scope, index]) and valid
    return valid

func validate_capture(
        spec: Dictionary, report_error: Callable, scope: String,
        attribute_required: bool = false) -> bool:
    var valid := true
    if not spec.get("capture") is String or str(spec.get("capture", "")) == "":
        report_error.call(scope + ".capture", "必须是非空捕获键")
        valid = false
    if attribute_required and not _attribute_ids.has(str(spec.get("attribute", ""))):
        report_error.call(scope + ".attribute", "引用未知属性")
        valid = false
    return valid

func validate_condition(condition, report_error: Callable, scope: String) -> bool:
    if not condition is Dictionary:
        report_error.call(scope, "必须是对象")
        return false
    if not _validate_condition.is_valid():
        report_error.call(scope, "缺少 ConditionSpec 校验器")
        return false
    return _validate_condition.call(condition, scope) == true

func is_number(value) -> bool:
    return value is int or value is float

func is_integer(value) -> bool:
    return is_number(value) and float(value) == floor(float(value))

func attribute_ids() -> Array:
    return _attribute_ids.duplicate()

func anomaly_category_ids() -> Array:
    return _anomaly_category_ids.duplicate()

func hand_ids() -> Array:
    return _hand_ids.duplicate()

func _runtime_reject(message: String) -> int:
    # 内容加载阶段已经拒绝未知 kind；该诊断保留给直接运行入口，避免再次静默为 0。
    push_error("ValueSpec runtime rejected: " + message)
    return 0

func _is_stable_id(value: String) -> bool:
    var pattern := RegEx.new()
    pattern.compile("^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$")
    return pattern.search(value) != null
