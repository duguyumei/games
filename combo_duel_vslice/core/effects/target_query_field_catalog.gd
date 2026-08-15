class_name TargetQueryFieldCatalog
extends RefCounted

const FILTER_FIELDS := [
    "card_kind", "attributes", "exclude_attributes", "base_attributes",
    "exclude_base_attributes", "rank_names", "rank_orders",
    "exclude_rank_orders", "definition_ids", "temporary", "has_any_reshape",
    "has_permanent_reshape", "has_active_permanent_reshape",
    "has_active_any_reshape", "has_any_anomaly", "duplicate_rank",
    "effective_above_base", "explicit_discard_allowed", "effective_qi_at_most",
    "effective_qi_at_least", "anomaly_layers_at_least",
    "has_non_attribute_identity", "anomaly", "anomalies", "reshape",
    "can_apply_anomaly", "exclude_base_attributes_from_capture",
    "exclude_rank_orders_from_capture",
]

static func filter_fields() -> Array[String]:
    return FILTER_FIELDS.duplicate()

static func unknown_fields(filters: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for field in filters:
        if str(field) not in FILTER_FIELDS:
            result.append(str(field))
    result.sort()
    return result
