class_name EffectSpecValidator
extends RefCounted

## 效果规格校验。
##
## 只判断「一条效果规格是否结构合法」：操作码是否已注册、数值规格是否自洽、
## 目标查询与选择协议字段是否完整、引用的真气异状是否存在。
##
## 不判断内容定义的整体形状（那属于 ContentValidator），也不知道自己在校验哪份
## 内容文件。战斗操作码与专有参数规则来自 EffectHandlerRegistry；消耗品仍使用
## 自己的轻量允许集合。
##
## 从 ContentValidator 拆出的原因：效果操作码随功法内容持续增长，而内容定义的
## 形状规则基本稳定，两者的变更频率相差很大。

## 数值规格的可用 kind。只有效果规格会用到，因此不放在内容词表里。
const AMOUNT_KINDS := [
    "constant", "power", "power_fraction", "initial_power", "initial_power_fraction", "n60", "hand_map", "max",
    "add", "subtract", "multiply", "divide_floor", "divide_ceil", "modulo", "capture_count", "capture_qi_sum", "capture_attribute_qi_sum",
    "capture_attribute_count", "capture_non_attribute_count", "capture_base_qi_sum",
    "capture_current_effective_qi", "group_base_qi_sum", "extra_count",
    "capture_effective_qi_sum", "capture_effective_qi_max",
    "capture_r_sum", "capture_r_max", "capture_anomaly_layers_sum",
    "capture_anomaly_layers_max", "capture_result_count",
    "capture_actual_life_loss", "current_defense", "played_poison_amount",
    "played_poison_count", "zone_anomaly_count", "zone_anomaly_qi_sum",
    "capture_field_sum", "capture_field_max", "capture_field_first",
    "extra_attribute_count", "hand_count",
    "target_hand_count", "hand_limit",
    "conditional",
    "power_scaled_by_zone_anomaly",
]

const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const QUERY_ORDERS := ["zone", "top", "bottom", "random"]
const QUERY_SIDES := ["actor", "target"]
const CARD_KINDS := ["any", "normal"]
const INSUFFICIENT_POLICIES := ["use_available", "skip", "fail"]
const SELECTION_PURPOSES := ["", "explicit_discard"]

var _report_error: Callable
var _attribute_ids: Array
var _anomaly_category_ids: Array
var _reshape_category_ids: Array
var _hand_ids: Array
var _effect_registry
var _anomalies_by_id: Dictionary = {}

## `report_error` 接收 (scope, message)，由调用方决定错误如何汇总。
## `vocabulary` 提供跨内容共用的 ID 集合，避免在这里复制一份常量。
func _init(
        report_error: Callable,
        vocabulary: Dictionary,
        effect_registry) -> void:
    _report_error = report_error
    _attribute_ids = vocabulary["attribute_ids"]
    _anomaly_category_ids = vocabulary["anomaly_category_ids"]
    _reshape_category_ids = vocabulary["reshape_category_ids"]
    _hand_ids = vocabulary["hand_ids"]
    _effect_registry = effect_registry

## 提供引用检查所需的索引。索引在内容校验过程中增量建立，因此单独设置。
func use_indexes(anomalies_by_id: Dictionary) -> void:
    _anomalies_by_id = anomalies_by_id

## 校验一条效果链。战斗效果传入 `battle`，其他轻量场景可传入允许操作码数组。
func validate_effects(values, operation_source, scope: String) -> void:
    if not values is Array or values.is_empty():
        _error(scope, "必须是非空效果数组")
        return
    var choice_ids: Dictionary = {}
    for index in range(values.size()):
        var effect = values[index]
        var effect_scope := "%s[%d]" % [scope, index]
        if not effect is Dictionary:
            _error(effect_scope, "必须是对象")
            continue
        _validate_single_effect(effect, operation_source, effect_scope, choice_ids)

func _validate_single_effect(
        effect: Dictionary,
        operation_source,
        effect_scope: String,
        choice_ids: Dictionary) -> void:
    var op := str(effect.get("op", ""))
    var registered: bool = false
    if operation_source is String and operation_source == "battle":
        registered = _effect_registry != null and _effect_registry.has_handler(op)
    elif operation_source is Array:
        registered = operation_source.has(op)
    if not registered:
        _error(effect_scope, "未知效果操作码 %s" % op)
    if effect.has("choice_id"):
        var choice_id := str(effect.get("choice_id", ""))
        if choice_id != "" and choice_ids.has(choice_id):
            _error(effect_scope + ".choice_id", "同一效果链中的 choice_id 不能重复")
        choice_ids[choice_id] = true
    for field in ["amount", "count", "damage"]:
        if effect.has(field) and effect[field] is Dictionary:
            validate_amount_spec(effect[field], effect_scope + "." + field)
    for field in ["side", "from_side", "to_side", "chooser"]:
        if effect.has(field) and str(effect[field]) not in QUERY_SIDES:
            _error(effect_scope + "." + field, "必须为 actor 或 target")
    for field in ["zone", "from_zone", "to_zone"]:
        if effect.has(field) and str(effect[field]) not in ZONE_IDS:
            _error(effect_scope + "." + field, "引用未知牌区")
    var condition = effect.get("when", {})
    if not condition is Dictionary:
        _error(effect_scope + ".when", "必须是对象")
    else:
        _validate_condition(condition, effect_scope + ".when")
    if registered and operation_source is String and operation_source == "battle":
        _effect_registry.validate_effect(effect, self, effect_scope)

func validate_anomaly_reference(effect: Dictionary, effect_scope: String) -> void:
    var anomaly_id := str(effect.get("anomaly", ""))
    var category := str(effect.get("category", ""))
    if not _anomalies_by_id.has(anomaly_id):
        _error(effect_scope, "引用未知真气异状 %s" % anomaly_id)
    elif str(_anomalies_by_id[anomaly_id].get("category", "")) != category:
        _error(effect_scope, "异状 %s 不属于类别 %s" % [anomaly_id, category])

func _validate_condition(condition: Dictionary, scope: String) -> void:
    for list_field in ["all", "any"]:
        if not condition.has(list_field):
            continue
        if not condition[list_field] is Array:
            _error(scope + "." + list_field, "必须是数组")
            continue
        for index in range(condition[list_field].size()):
            var child = condition[list_field][index]
            var child_scope := "%s.%s[%d]" % [scope, list_field, index]
            if not child is Dictionary:
                _error(child_scope, "必须是对象")
            else:
                _validate_condition(child, child_scope)
    if condition.has("not"):
        if not condition["not"] is Dictionary:
            _error(scope + ".not", "必须是对象")
        else:
            _validate_condition(condition["not"], scope + ".not")
    if condition.has("pure_attribute") \
            and not _attribute_ids.has(str(condition["pure_attribute"])):
        _error(scope + ".pure_attribute", "引用未知属性 %s" % str(condition["pure_attribute"]))
    if condition.has("hand_id") \
            and not _hand_ids.has(str(condition["hand_id"])):
        _error(scope + ".hand_id", "引用未知精确牌型 %s" % str(condition["hand_id"]))
    if condition.has("actor_defense_equals") \
            and (not _is_integer(condition["actor_defense_equals"]) \
            or int(condition["actor_defense_equals"]) < 0):
        _error(scope + ".actor_defense_equals", "必须是非负整数")

func validate_choice_effect(effect: Dictionary, scope: String) -> void:
    if not effect.get("choice_id") is String or str(effect.get("choice_id", "")) == "":
        _error(scope + ".choice_id", "必须是非空字符串")
    if not effect.get("query") is Dictionary:
        _error(scope + ".query", "必须是对象")
    else:
        validate_target_query(effect["query"], scope + ".query")
    for field in ["minimum", "maximum"]:
        var value = effect.get(field)
        if value is Dictionary:
            validate_amount_spec(value, scope + "." + field)
        elif not _is_integer(value) or int(value) < 0:
            _error(scope + "." + field, "必须是非负整数或数值规格")
    if _is_integer(effect.get("minimum")) and _is_integer(effect.get("maximum")) \
            and int(effect.get("maximum")) < int(effect.get("minimum")):
        _error(scope, "maximum 不能小于 minimum")
    if str(effect.get("insufficient_policy", "")) not in INSUFFICIENT_POLICIES:
        _error(scope + ".insufficient_policy", "必须明确为 use_available、skip 或 fail")
    if effect.has("chooser") and str(effect.get("chooser")) not in QUERY_SIDES:
        _error(scope + ".chooser", "必须为 actor 或 target")
    if str(effect.get("selection_purpose", "")) not in SELECTION_PURPOSES:
        _error(scope + ".selection_purpose", "必须为空或 explicit_discard")

func validate_nested_battle_effects(values, scope: String) -> void:
    validate_effects(values, "battle", scope)

func validate_positive_integer(value, scope: String, label: String) -> void:
    if not _is_integer(value) or int(value) <= 0:
        _error(scope, "%s 必须是正整数" % label)

func validate_non_negative_integer(value, scope: String, label: String) -> void:
    if not _is_integer(value) or int(value) < 0:
        _error(scope, "%s 必须是非负整数" % label)

func report_error(scope: String, message: String) -> void:
    _error(scope, message)

## 校验通用目标查询。
func validate_target_query(query: Dictionary, scope: String) -> void:
    if str(query.get("side", "actor")) not in QUERY_SIDES:
        _error(scope + ".side", "必须为 actor 或 target")
    if str(query.get("zone", "hand")) not in ZONE_IDS:
        _error(scope + ".zone", "引用未知牌区")
    if str(query.get("order", "zone")) not in QUERY_ORDERS:
        _error(scope + ".order", "必须为 zone、top、bottom 或 random")
    if query.has("limit"):
        if query["limit"] is Dictionary:
            validate_amount_spec(query["limit"], scope + ".limit")
        elif not _is_integer(query["limit"]) \
                or int(query["limit"]) == 0 \
                or int(query["limit"]) < -1:
            _error(scope + ".limit", "必须为 -1、正整数或数值规格")
    var filters = query.get("filters", {})
    if not filters is Dictionary:
        _error(scope + ".filters", "必须是对象")
        return
    _validate_query_filters(filters, scope + ".filters")

func _validate_query_filters(filters: Dictionary, scope: String) -> void:
    if str(filters.get("card_kind", "any")) not in CARD_KINDS:
        _error(scope + ".card_kind", "必须为 any 或 normal")
    for field in [
            "attributes", "exclude_attributes", "rank_names",
            "rank_orders", "definition_ids"]:
        if filters.has(field) and not filters[field] is Array:
            _error(scope + "." + field, "必须是数组")
    for attribute_field in ["attributes", "exclude_attributes"]:
        if not filters.has(attribute_field):
            continue
        for attribute in filters[attribute_field]:
            if str(attribute) not in _attribute_ids:
                _error(scope + "." + attribute_field, "引用未知属性 %s" % str(attribute))
    for boolean_field in ["temporary", "has_any_reshape", "has_permanent_reshape", "effective_above_base", "explicit_discard_allowed"]:
        if filters.has(boolean_field) and not filters[boolean_field] is bool:
            _error(scope + "." + boolean_field, "必须是布尔值")
    for value_field in ["effective_qi_at_most", "effective_qi_at_least"]:
        if not filters.has(value_field):
            continue
        if filters[value_field] is Dictionary:
            validate_amount_spec(filters[value_field], scope + "." + value_field)
        elif not _is_integer(filters[value_field]):
            _error(scope + "." + value_field, "必须是整数或数值规格")
    if filters.has("anomaly_layers_at_least"):
        var layer_filter = filters["anomaly_layers_at_least"]
        if not layer_filter is Dictionary:
            _error(scope + ".anomaly_layers_at_least", "必须是对象")
        else:
            if str(layer_filter.get("category", "")) not in _anomaly_category_ids:
                _error(scope + ".anomaly_layers_at_least.category", "引用未知异状类别")
            if not _is_integer(layer_filter.get("value", 1)) or int(layer_filter.get("value", 1)) <= 0:
                _error(scope + ".anomaly_layers_at_least.value", "必须是正整数")
    if filters.has("has_non_attribute_identity") \
            and str(filters["has_non_attribute_identity"]) not in _attribute_ids:
        _error(scope + ".has_non_attribute_identity", "引用未知属性")
    if filters.has("anomaly"):
        _validate_target_state_filter(
            filters["anomaly"], _anomaly_category_ids, scope + ".anomaly")
    if filters.has("anomalies"):
        if not filters["anomalies"] is Array:
            _error(scope + ".anomalies", "必须是数组")
        else:
            for index in range(filters["anomalies"].size()):
                _validate_target_state_filter(
                    filters["anomalies"][index], _anomaly_category_ids,
                    "%s.anomalies[%d]" % [scope, index])
    if filters.has("reshape"):
        _validate_target_state_filter(
            filters["reshape"], _reshape_category_ids, scope + ".reshape")
    if filters.has("can_apply_anomaly"):
        _validate_target_state_filter(
            filters["can_apply_anomaly"], _anomaly_category_ids,
            scope + ".can_apply_anomaly")
        var anomaly_filter: Dictionary = filters["can_apply_anomaly"] \
            if filters["can_apply_anomaly"] is Dictionary else {}
        var anomaly_id := str(anomaly_filter.get("id", ""))
        var anomaly_category := str(anomaly_filter.get("category", ""))
        if not _anomalies_by_id.has(anomaly_id):
            _error(scope + ".can_apply_anomaly", "引用未知真气异状 %s" % anomaly_id)
        elif str(_anomalies_by_id[anomaly_id].get("category", "")) != anomaly_category:
            _error(scope + ".can_apply_anomaly", "异状 %s 不属于类别 %s" % [
                anomaly_id, anomaly_category])

func _validate_target_state_filter(value, category_ids: Array, scope: String) -> void:
    if not value is Dictionary:
        _error(scope, "必须是对象")
        return
    if str(value.get("category", "")) not in category_ids:
        _error(scope + ".category", "引用未知类别")
    if value.has("present") and not value["present"] is bool:
        _error(scope + ".present", "必须是布尔值")

## 校验数值规格。递归结构，因此对外公开供嵌套场景复用。
func validate_amount_spec(spec: Dictionary, scope: String) -> void:
    var kind := str(spec.get("kind", ""))
    if not AMOUNT_KINDS.has(kind):
        _error(scope, "未知数值规格 kind %s" % kind)
        return
    match kind:
        "constant":
            if not _is_number(spec.get("value")):
                _error(scope, "constant.value 必须是数值")
        "power_fraction", "initial_power_fraction":
            _validate_power_fraction(spec, scope)
        "hand_map":
            _validate_hand_map(spec, scope)
        "max", "add", "multiply":
            _validate_spec_list(spec, scope)
        "subtract":
            _validate_nested_specs(spec, ["left", "right"], scope)
        "divide_floor", "divide_ceil", "modulo":
            _validate_nested_specs(spec, ["value", "divisor"], scope)
        "capture_count", "capture_qi_sum", "capture_attribute_qi_sum", \
        "capture_attribute_count", "capture_non_attribute_count", \
        "capture_base_qi_sum", "capture_current_effective_qi":
            _validate_capture_spec(spec, kind, scope)
        "capture_effective_qi_sum", "capture_effective_qi_max", \
        "capture_r_sum", "capture_r_max", "capture_anomaly_layers_sum", \
        "capture_anomaly_layers_max", "capture_result_count", \
        "capture_actual_life_loss":
            _validate_capture_spec(spec, kind, scope)
        "capture_field_sum", "capture_field_max", "capture_field_first":
            _validate_capture_spec(spec, kind, scope)
        "conditional":
            _validate_nested_specs(spec, ["then", "else"], scope)
        "power_scaled_by_zone_anomaly":
            if str(spec.get("category", "")) not in _anomaly_category_ids:
                _error(scope + ".category", "引用未知异状类别")

func _validate_power_fraction(spec: Dictionary, scope: String) -> void:
    if not _is_number(spec.get("numerator")):
        _error(scope, "power_fraction.numerator 必须是数值")
    if not _is_number(spec.get("denominator")) or float(spec.get("denominator", 0)) <= 0:
        _error(scope, "power_fraction.denominator 必须是正数")
    if spec.has("minimum") and not _is_number(spec["minimum"]):
        _error(scope, "power_fraction.minimum 必须是数值")

func _validate_hand_map(spec: Dictionary, scope: String) -> void:
    var values = spec.get("values")
    if not values is Dictionary:
        _error(scope, "hand_map.values 必须是对象")
        return
    for hand_id in values:
        if not _hand_ids.has(str(hand_id)):
            _error(scope, "hand_map 引用未知精确牌型 %s" % str(hand_id))
        if not _is_number(values[hand_id]):
            _error(scope, "hand_map.%s 必须是数值" % str(hand_id))

func _validate_spec_list(spec: Dictionary, scope: String) -> void:
    var values = spec.get("values")
    if not values is Array or values.is_empty():
        _error(scope, "max.values 必须是非空数组")
        return
    for index in range(values.size()):
        var nested_scope := "%s.values[%d]" % [scope, index]
        if values[index] is Dictionary:
            validate_amount_spec(values[index], nested_scope)
        elif not _is_number(values[index]):
            _error(nested_scope, "必须是数值或数值规格对象")

func _validate_nested_specs(spec: Dictionary, fields: Array, scope: String) -> void:
    for field in fields:
        if spec.get(field) is Dictionary:
            validate_amount_spec(spec[field], scope + "." + str(field))
        elif not _is_number(spec.get(field)):
            _error(scope + "." + str(field), "必须是数值或数值规格对象")

func _validate_capture_spec(spec: Dictionary, kind: String, scope: String) -> void:
    if not spec.get("capture") is String or str(spec.get("capture", "")) == "":
        _error(scope + ".capture", "必须是非空捕获键")
    if kind in [
            "capture_attribute_qi_sum", "capture_attribute_count",
            "capture_non_attribute_count"] \
            and str(spec.get("attribute", "")) not in _attribute_ids:
        _error(scope + ".attribute", "引用未知属性")

func _error(scope: String, message: String) -> void:
    _report_error.call(scope, message)

func _is_number(value) -> bool:
    return value is int or value is float

func _is_integer(value) -> bool:
    return _is_number(value) and float(value) == floor(float(value))
