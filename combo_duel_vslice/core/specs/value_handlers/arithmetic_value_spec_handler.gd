class_name ArithmeticValueSpecHandler
extends RefCounted

const REGISTERED_KINDS := [
    "constant", "power", "initial_power", "power_fraction",
    "initial_power_fraction", "n60", "hand_map", "max", "add",
    "subtract", "multiply", "divide_floor", "divide_ceil", "modulo",
    "conditional", "power_scaled_by_zone_anomaly",
]

func kind_ids() -> Array[String]:
    return REGISTERED_KINDS.duplicate()

func validate(kind: String, spec: Dictionary, registry, report_error: Callable, scope: String) -> bool:
    match kind:
        "constant":
            if not registry.is_number(spec.get("value")):
                report_error.call(scope, "constant.value 必须是数值")
                return false
        "power_fraction", "initial_power_fraction":
            return _validate_power_fraction(spec, registry, report_error, scope)
        "hand_map":
            return _validate_hand_map(spec, registry, report_error, scope)
        "max", "add", "multiply":
            return registry.validate_value_list(spec, report_error, scope)
        "subtract":
            return registry.validate_nested_fields(
                spec, ["left", "right"], report_error, scope)
        "divide_floor", "divide_ceil", "modulo":
            return registry.validate_nested_fields(
                spec, ["value", "divisor"], report_error, scope)
        "conditional":
            var valid: bool = registry.validate_nested_fields(
                spec, ["then", "else"], report_error, scope)
            if not spec.has("when"):
                report_error.call(scope + ".when", "缺少必填字段")
                return false
            return registry.validate_condition(
                spec["when"], report_error, scope + ".when") and valid
        "power_scaled_by_zone_anomaly":
            if str(spec.get("category", "")) not in registry.anomaly_category_ids():
                report_error.call(scope + ".category", "引用未知异状类别")
                return false
    return true

func resolve(kind: String, spec: Dictionary, runtime, resolver, _registry) -> int:
    match kind:
        "constant":
            return int(spec.get("value", 0))
        "power":
            return runtime.power
        "initial_power":
            return runtime.initial_power
        "power_fraction", "initial_power_fraction":
            var base: int = runtime.power if kind == "power_fraction" else runtime.initial_power
            var value := int(floor(
                base * int(spec.get("numerator", 1))
                / float(maxi(1, int(spec.get("denominator", 1))))))
            return maxi(int(spec.get("minimum", 0)), value)
        "n60":
            return maxi(1, int(floor(runtime.power / 60.0)))
        "hand_map":
            var values: Dictionary = spec.get("values", {})
            if values.has(runtime.actual_hand_id):
                return int(values[runtime.actual_hand_id])
            if values.has(runtime.branch_hand_id):
                return int(values[runtime.branch_hand_id])
            return 0
        "max":
            var maximum := 0
            for child in spec.get("values", []):
                maximum = maxi(maximum, resolver.resolve(child, runtime))
            return maximum
        "add":
            var total := 0
            for child in spec.get("values", []):
                total += resolver.resolve(child, runtime)
            return total
        "subtract":
            return resolver.resolve(spec.get("left", 0), runtime) \
                - resolver.resolve(spec.get("right", 0), runtime)
        "multiply":
            var product := 1
            for child in spec.get("values", []):
                product *= resolver.resolve(child, runtime)
            return product
        "divide_floor":
            return int(floor(
                resolver.resolve(spec.get("value", {}), runtime)
                / float(maxi(1, resolver.resolve(spec.get("divisor", 1), runtime)))))
        "divide_ceil":
            return int(ceil(
                resolver.resolve(spec.get("value", {}), runtime)
                / float(maxi(1, resolver.resolve(spec.get("divisor", 1), runtime)))))
        "modulo":
            return resolver.resolve(spec.get("value", 0), runtime) \
                % maxi(1, resolver.resolve(spec.get("divisor", 1), runtime))
        "conditional":
            return resolver.resolve(
                spec.get("then", {}) if resolver.condition_met(spec.get("when", {}), runtime) \
                else spec.get("else", {}), runtime)
        "power_scaled_by_zone_anomaly":
            var side = runtime.actor if str(spec.get("side", "actor")) == "actor" else runtime.target
            if side == null:
                return 0
            var count: int = side.count_anomaly_in_zone(
                str(spec.get("zone", "draw_pile")),
                str(spec.get("category", "mark")), str(spec.get("anomaly", "")))
            var percent := int(spec.get("percent_per_card", 0))
            if spec.has("pure_attribute_percent") and resolver.condition_met({
                    "pure_attribute": str(spec.get("attribute", "wind"))}, runtime):
                percent = int(spec["pure_attribute_percent"])
            return int(floor(runtime.power * (100 + count * percent) / 100.0))
    return 0

func _validate_power_fraction(spec, registry, report_error: Callable, scope: String) -> bool:
    var valid := true
    if not registry.is_number(spec.get("numerator")):
        report_error.call(scope, "power_fraction.numerator 必须是数值")
        valid = false
    if not registry.is_number(spec.get("denominator")) \
            or float(spec.get("denominator", 0)) <= 0:
        report_error.call(scope, "power_fraction.denominator 必须是正数")
        valid = false
    if spec.has("minimum") and not registry.is_number(spec["minimum"]):
        report_error.call(scope, "power_fraction.minimum 必须是数值")
        valid = false
    return valid

func _validate_hand_map(spec, registry, report_error: Callable, scope: String) -> bool:
    var values = spec.get("values")
    if not values is Dictionary:
        report_error.call(scope, "hand_map.values 必须是对象")
        return false
    var valid := true
    for hand_id in values:
        if not registry.hand_ids().has(str(hand_id)):
            report_error.call(scope, "hand_map 引用未知精确牌型 %s" % str(hand_id))
            valid = false
        if not registry.is_number(values[hand_id]):
            report_error.call(scope, "hand_map.%s 必须是数值" % str(hand_id))
            valid = false
    return valid
