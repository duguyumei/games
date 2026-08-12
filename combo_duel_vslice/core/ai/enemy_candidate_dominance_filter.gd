class_name EnemyCandidateDominanceFilter
extends RefCounted

const EPSILON := 0.0001
const DIMENSION_NAMES := [
    "damage", "defense", "lethal", "avoids_immediate_death",
    "expected_next_normal_draw", "retained_hand_value",
    "next_hand_potential", "negative_card_cleanup_value",
    "positive_retention_value", "negative_retention_inverse",
    "passive_immediate_value", "passive_progress_value",
    "control_value", "sequence_progress_value", "combo",
]

func filter(records: Array) -> Array:
    return analyze(records)["kept"]

func analyze(records: Array) -> Dictionary:
    var result: Array = []
    var dominated: Array = []
    for candidate in records:
        var dominator = null
        for other in records:
            if candidate == other:
                continue
            if _dominates(other["features"], candidate["features"]):
                dominator = other
                break
        if dominator == null:
            result.append(candidate)
        else:
            dominated.append({
                "candidate": candidate,
                "dominated_by": dominator,
                "dimension_comparison": _dimension_comparison(
                    dominator["features"], candidate["features"]),
            })
    return {"kept": result, "dominated": dominated}

func _dominates(left: Dictionary, right: Dictionary) -> bool:
    var left_values := _dimensions(left)
    var right_values := _dimensions(right)
    var strictly_better := false
    for index in range(left_values.size()):
        if float(left_values[index]) + EPSILON < float(right_values[index]):
            return false
        if float(left_values[index]) > float(right_values[index]) + EPSILON:
            strictly_better = true
    return strictly_better

func _dimensions(features: Dictionary) -> Array:
    return [
        float(features["immediate"]["damage"]),
        float(features["immediate"]["defense"]),
        1.0 if features["immediate"]["lethal"] else 0.0,
        1.0 if features["immediate"]["avoids_immediate_death"] else 0.0,
        float(features["card_flow"]["expected_next_normal_draw"]),
        float(features["future"]["retained_hand_value"]),
        float(features["future"]["next_hand_potential"]),
        float(features["card_state"]["negative_card_cleanup_value"]),
        float(features["card_state"]["positive_retention_value"]),
        -float(features["card_state"]["negative_retention_cost"]),
        float(features["passives"]["immediate_value"]),
        float(features["passives"]["progress_value"]),
        float(features["passives"]["control_value"]),
        float(features["future"]["sequence_progress_value"]),
        1.0 if features["immediate"]["combo"] else 0.0,
    ]

func dimension_values(features: Dictionary) -> Dictionary:
    var values := _dimensions(features)
    var result: Dictionary = {}
    for index in range(DIMENSION_NAMES.size()):
        result[DIMENSION_NAMES[index]] = float(values[index])
    return result

func _dimension_comparison(dominator: Dictionary, dominated: Dictionary) -> Array:
    var left := _dimensions(dominator)
    var right := _dimensions(dominated)
    var result: Array = []
    for index in range(DIMENSION_NAMES.size()):
        result.append({
            "dimension": DIMENSION_NAMES[index],
            "dominator_value": float(left[index]),
            "dominated_value": float(right[index]),
            "delta": float(left[index]) - float(right[index]),
            "strictly_better": float(left[index]) > float(right[index]) + EPSILON,
        })
    return result
