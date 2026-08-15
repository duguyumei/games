class_name EffectSpecValidator
extends RefCounted

const ValueSpecRegistryScript = preload("res://core/specs/value_spec_registry.gd")
const ConditionSpecRegistryScript = preload("res://core/specs/condition_spec_registry.gd")
const TargetQueryFieldCatalogScript = preload(
    "res://core/effects/target_query_field_catalog.gd")
const BattleEventCatalogScript = preload("res://core/battle_event_catalog.gd")

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

const ZONE_IDS := ["hand", "draw_pile", "staging", "discard_pile"]
const QUERY_ORDERS := [
    "zone", "left", "right", "top", "bottom", "random",
    "highest_rank", "lowest_rank", "highest_effective_qi",
    "highest_effective_qi_random_ties"]
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
var _value_spec_registry
var _condition_spec_registry

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
    _value_spec_registry = (
        effect_registry.value_resolver.spec_registry
        if effect_registry != null and effect_registry.value_resolver != null
        else ValueSpecRegistryScript.new())
    _condition_spec_registry = (
        effect_registry.value_resolver.condition_registry
        if effect_registry != null and effect_registry.value_resolver != null
        else ConditionSpecRegistryScript.new())
    _condition_spec_registry.configure_validation(
        vocabulary, Callable(self, "validate_amount_spec"))
    _value_spec_registry.configure_validation(
        vocabulary, Callable(self, "validate_condition"))

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
        validate_condition(condition, effect_scope + ".when")
    if registered and operation_source is String and operation_source == "battle":
        _effect_registry.validate_effect(effect, self, effect_scope)

func validate_anomaly_reference(effect: Dictionary, effect_scope: String) -> void:
    var anomaly_id := str(effect.get("anomaly", ""))
    var category := str(effect.get("category", ""))
    if not _anomalies_by_id.has(anomaly_id):
        _error(effect_scope, "引用未知真气异状 %s" % anomaly_id)
    elif str(_anomalies_by_id[anomaly_id].get("category", "")) != category:
        _error(effect_scope, "异状 %s 不属于类别 %s" % [anomaly_id, category])

func validate_condition(condition: Dictionary, scope: String) -> bool:
    return _condition_spec_registry.validate_condition(
        condition, Callable(self, "_error"), scope)

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

func value_spec_registration_errors() -> Array[String]:
    return _value_spec_registry.registration_errors()

func validate_response_event(event_id: String, scope: String) -> void:
    if not BattleEventCatalogScript.forwards_dynamic_response(event_id):
        _error(scope, "引用未知动态响应事件")

func validate_event_filters(filters, scope: String) -> void:
    if not filters is Dictionary:
        _error(scope, "必须是对象")
        return
    _condition_spec_registry.validate_event_filters(
        filters, Callable(self, "_error"), scope)

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
    for field in TargetQueryFieldCatalogScript.unknown_fields(filters):
        _error(scope + "." + field, "未知目标查询筛选字段")
    if str(filters.get("card_kind", "any")) not in CARD_KINDS:
        _error(scope + ".card_kind", "必须为 any 或 normal")
    for field in [
            "attributes", "exclude_attributes", "base_attributes",
            "exclude_base_attributes", "rank_names", "rank_orders",
            "exclude_rank_orders", "definition_ids"]:
        if filters.has(field) and not filters[field] is Array:
            _error(scope + "." + field, "必须是数组")
    for attribute_field in [
            "attributes", "exclude_attributes", "base_attributes",
            "exclude_base_attributes"]:
        if not filters.has(attribute_field):
            continue
        for attribute in filters[attribute_field]:
            if str(attribute) not in _attribute_ids:
                _error(scope + "." + attribute_field, "引用未知属性 %s" % str(attribute))
    for boolean_field in [
            "temporary", "has_any_reshape", "has_permanent_reshape",
            "has_active_permanent_reshape", "has_active_any_reshape",
            "has_any_anomaly", "duplicate_rank", "effective_above_base",
            "explicit_discard_allowed"]:
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
    _value_spec_registry.validate_amount_spec(
        spec, Callable(self, "_error"), scope)

func _error(scope: String, message: String) -> void:
    _report_error.call(scope, message)

func _is_number(value) -> bool:
    return value is int or value is float

func _is_integer(value) -> bool:
    return _is_number(value) and float(value) == floor(float(value))
