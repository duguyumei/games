class_name ValueSpecRegistry
extends RefCounted

const KIND_IDS := [
    "constant", "power", "power_fraction", "initial_power",
    "initial_power_fraction", "n60", "hand_map", "max", "add",
    "subtract", "multiply", "divide_floor", "divide_ceil", "modulo",
    "capture_count", "capture_qi_sum", "capture_attribute_qi_sum",
    "capture_attribute_count", "capture_non_attribute_count",
    "capture_base_qi_sum", "capture_card_base_qi_sum",
    "capture_current_effective_qi", "group_base_qi_sum", "extra_count",
    "card_contribution", "extra_effective_qi_sum", "action_same_qi_gain",
    "action_same_qi_trigger_count", "base_attribute_count", "event_field",
    "momentum_value", "active_temporary_reshape_base_qi_sum",
    "capture_effective_qi_sum", "capture_effective_qi_max", "capture_r_sum",
    "capture_r_max", "capture_anomaly_layers_sum", "capture_anomaly_layers_max",
    "capture_result_count", "capture_actual_life_loss", "current_defense",
    "played_poison_amount", "played_poison_count", "zone_anomaly_count",
    "zone_anomaly_qi_sum", "capture_field_sum", "capture_field_max",
    "capture_field_first", "extra_attribute_count", "hand_count",
    "target_hand_count", "occupied_meridian_count", "deck_count",
    "bomb_constituent_count", "hand_limit", "base_hand_limit", "conditional",
    "power_scaled_by_zone_anomaly", "source_marker_value", "source_marker_sum",
    "consumed_marker_value", "equipped_source_marker_sum", "missing_life",
    "target_missing_life", "max_life", "target_max_life",
]

func kind_ids() -> Array[String]:
    return KIND_IDS.duplicate()

func has_kind(kind: String) -> bool:
    return kind in KIND_IDS

func resolve(spec, context, evaluator: Callable) -> int:
    if spec is int or spec is float:
        return int(spec)
    if not spec is Dictionary or not has_kind(str(spec.get("kind", "constant"))):
        return 0
    return int(evaluator.call(spec, context))
